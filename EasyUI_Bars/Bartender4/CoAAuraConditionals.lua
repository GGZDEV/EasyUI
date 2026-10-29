--[[
    CoA Bartender4 patch — translate [aura:Name] / [form:Name] /
    non-numeric [stance:Name] in paging conditionals into [stance:N].

    Why: Blizzard's secure macro parser (SecureCmdOptionParse) only
    accepts a numeric index for [stance:] / [form:] and has no [aura:]
    keyword at all. Addons cannot register new conditionals into the
    secure parser. So the only honest place to do this is *before* we
    hand the string to RegisterStateDriver — we resolve form names to
    indices via GetShapeshiftFormInfo() and rewrite the keyword.

    Scope: only shapeshift forms are resolvable this way. That covers
    Druid, Warrior stances, Death Knight presences, Priest Shadowform,
    and every CoA custom-class form (Venomancer, Wildkin, etc.) since
    those all live in the shapeshift bar. Non-form auras (regular
    buffs) cannot be expressed as a stance index and would need a
    synthetic state-driver attribute — out of scope here.

    Usage in Bartender4 paging:
        [aura:Beetle Form]6;1   -- equivalent to [stance:1]6;1 (if Beetle Form is form 1)
        [form:Beetle Form]6;1
        [stance:Beetle Form]6;1
        [stance:Beetle Form/Wasp Form]6;1   -- slash-list works too
        [noaura:Beetle Form]2

    All three keywords (aura, form, stance) are accepted equivalently
    when the value is a non-numeric form name. Numeric values pass
    through unchanged. Unresolvable names (form not currently learned)
    translate to stance index 99 — never matches for positive
    conditionals, always matches for negated ones — and are
    re-resolved automatically when the shapeshift form set changes.
]]

local Bartender4 = _G.Bartender4
if not Bartender4 then return end

local KEYWORDS = { "nostance", "noform", "noaura", "stance", "form", "aura" }
local KEYWORD_OUT = {
    stance   = "stance",  form   = "stance",  aura   = "stance",
    nostance = "nostance", noform = "nostance", noaura = "nostance",
}

local function shapeshiftIndexByName(name)
    if type(GetNumShapeshiftForms) ~= "function" or type(GetShapeshiftFormInfo) ~= "function" then
        return nil
    end
    local n = GetNumShapeshiftForms() or 0
    local lname = name:lower()
    for i = 1, n do
        local _, fname = GetShapeshiftFormInfo(i)
        if fname and fname:lower() == lname then
            return i
        end
    end
    return nil
end

local function translateValueList(values)
    local parts, anyTranslated = {}, false
    for v in values:gmatch("[^/]+") do
        local trimmed = v:match("^%s*(.-)%s*$") or v
        if trimmed:match("^%d+$") or trimmed == "" then
            parts[#parts + 1] = trimmed
        else
            -- Unresolvable form names (not learned yet, respec, etc.) map
            -- to stance index 99, which can never match: [aura:X] becomes
            -- always-false and [noaura:X] always-true, both semantically
            -- correct for a form you cannot have. UPDATE_SHAPESHIFT_FORMS
            -- re-runs the translation once the form is learned. Leaving the
            -- name untranslated instead spams "Unknown macro option" from
            -- the secure parser on every stance change.
            local idx = shapeshiftIndexByName(trimmed) or "99"
            parts[#parts + 1] = tostring(idx)
            anyTranslated = true
        end
    end
    return table.concat(parts, "/"), anyTranslated
end

function Bartender4:CoATranslateConditionals(s)
    if type(s) ~= "string" or s == "" then return s end
    for _, kw in ipairs(KEYWORDS) do
        local outKw = KEYWORD_OUT[kw]
        s = s:gsub(kw .. ":([^,%]]+)", function(value)
            local newValue, didTranslate = translateValueList(value)
            if didTranslate then
                return outKw .. ":" .. newValue
            end
            return nil
        end)
    end
    return s
end

-- Re-apply paging when shapeshift form set changes (new form learned,
-- spec respec, etc.) so freshly-resolvable names take effect without
-- a /reload. Skipped during combat lockdown — RegisterStateDriver is
-- secure and the SetAttribute calls inside UpdateStates would taint.
--
-- Triggers: UPDATE_SHAPESHIFT_FORMS (the form set actually changed)
-- and PLAYER_REGEN_ENABLED (drain a refresh queued during combat).
-- PLAYER_ENTERING_WORLD is deliberately NOT a trigger — Bartender's
-- own init handles the initial state, and firing UpdateStates on every
-- zone risked re-entering secure paths while Bartender was mid-flux,
-- producing "prevented the call of SecureStateDriverManager:SetAttribute".
local refresh = CreateFrame("Frame")
refresh:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
refresh:RegisterEvent("PLAYER_REGEN_ENABLED")

local lastFormSignature
local pendingRefresh = false

local function currentFormSignature()
    if type(GetNumShapeshiftForms) ~= "function" then return "" end
    local n = GetNumShapeshiftForms() or 0
    local parts = {}
    for i = 1, n do
        local _, fname = GetShapeshiftFormInfo(i)
        parts[#parts + 1] = fname or ""
    end
    return table.concat(parts, "|")
end

refresh:SetScript("OnEvent", function(self, event)
    if InCombatLockdown and InCombatLockdown() then
        pendingRefresh = true
        return
    end
    if event == "PLAYER_REGEN_ENABLED" and not pendingRefresh then return end
    pendingRefresh = false

    -- Skip the refresh entirely if the form set hasn't changed since
    -- last run. Avoids redundant RegisterStateDriver churn on routine
    -- UPDATE_SHAPESHIFT_FORMS spam.
    local sig = currentFormSignature()
    if sig == lastFormSignature then return end
    lastFormSignature = sig

    local mod = Bartender4 and Bartender4.GetModule and Bartender4:GetModule("ActionBars", true)
    if not mod or not mod.actionbars then return end
    for _, bar in pairs(mod.actionbars) do
        if bar and bar.UpdateStates then bar:UpdateStates() end
    end
end)
