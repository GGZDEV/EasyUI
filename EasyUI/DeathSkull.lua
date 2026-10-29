--[[
	EasyUI - « Va-t-elle mourir ? »
	Affiche une tête de mort à gauche de la barre de vie de la barre de nom de la cible
	quand les dégâts restants de tes effets sur la durée suffisent à la tuer.

	- dégâts par tick et intervalle appris dans le journal de combat (par cible, avec
	  repli sur ce qu'on sait du sort en général : la prédiction marche dès la pose du sort)
	- ticks restants calculés à partir de l'heure du dernier tick, pas d'un arrondi
	- les coups critiques ne faussent pas la moyenne
	- anti-clignotement : apparaît dès que c'est sûr, ne disparaît que si la prédiction
	  retombe nettement pendant un moment (ou si la cible change)
	- barre de nom de la cible mémorisée, barre de vie retrouvée à l'intérieur
	- pas de barre de nom : à gauche du cadre de cible (option)
]]
local _, ns = ...

local Skull = {}
ns.Skull = Skull

local dots = {}          -- dots[GUID][clé sort] = { amount, last, interval }
local spells = {}        -- spells[clé sort] = { amount, interval } : repli toutes cibles confondues
local playerGUID, petGUID

local HIDE_RATIO = 0.9   -- en dessous de 90 % de la vie, on commence à cacher
local HIDE_DELAY = 0.6   -- ... seulement si ça dure (s)
local UPDATE = 0.1

local function DB() return ns.db.plates end

----------------------------------------------------------------
-- Apprentissage des ticks
----------------------------------------------------------------
local function Learn(d, amount, crit, now)
	if crit then amount = amount / 2 end -- ramène un critique à un tick normal
	if not d.amount then
		d.amount = amount
	else
		d.amount = d.amount * 0.5 + amount * 0.5
	end
	if d.last then
		local gap = now - d.last
		-- intervalle réel (hâte comprise) ; ignore deux ticks simultanés ou une longue coupure
		if gap > 0.5 and gap < 6 then
			d.interval = d.interval and (d.interval * 0.5 + gap * 0.5) or gap
		end
	end
	d.last = now
end

local log = CreateFrame("Frame")
log:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
log:RegisterEvent("PLAYER_ENTERING_WORLD")
log:RegisterEvent("UNIT_PET")
log:SetScript("OnEvent", function(_, event, ...)
	if event ~= "COMBAT_LOG_EVENT_UNFILTERED" then
		playerGUID = UnitGUID("player")
		petGUID = UnitGUID("pet")
		if event == "PLAYER_ENTERING_WORLD" then wipe(dots) end
		return
	end
	local _, sub, srcGUID, _, _, dstGUID, _, _, spellId, spellName, _, amount, _, _, _, _, _, crit = ...
	if sub == "UNIT_DIED" or sub == "UNIT_DESTROYED" then dots[dstGUID] = nil return end
	if sub ~= "SPELL_PERIODIC_DAMAGE" or not amount then return end
	if srcGUID ~= playerGUID and (not petGUID or srcGUID ~= petGUID) then return end
	local now = GetTime()
	local t = dots[dstGUID]
	if not t then t = {} dots[dstGUID] = t end
	local key = spellId or spellName
	local d = t[key]
	if not d then d = {} t[key] = d end
	Learn(d, amount, crit, now)
	if spellName and spellName ~= key then t[spellName] = d end
	-- savoir général sur le sort
	local g = spells[key]
	if not g then g = {} spells[key] = g if spellName then spells[spellName] = g end end
	g.amount = d.amount
	if d.interval then g.interval = d.interval end
end)

-- nombre de ticks encore à venir avant l'expiration
local function TicksLeft(d, interval, expires, duration, now)
	local last = d and d.last
	if not last or now - last > interval * 1.5 then
		-- pas encore de tick connu sur cette cible : on part de la pose du sort
		if duration and duration > 0 then
			local start = expires - duration
			local done = math.floor((now - start) / interval + 0.001)
			return math.max(0, math.floor(duration / interval + 0.5) - done)
		end
		return math.max(0, math.floor((expires - now) / interval + 0.5))
	end
	-- dernier tick vu : les suivants tombent à last + k * interval, jusqu'à l'expiration (+ petite tolérance)
	return math.max(0, math.floor((expires + 0.25 - last) / interval))
end

-- dégâts restants de mes effets sur la cible
function Skull:RemainingDamage(unit)
	local guid = UnitGUID(unit)
	local t = guid and dots[guid]
	local now, total, any = GetTime(), 0, false
	for i = 1, 40 do
		local name, _, _, count, _, duration, expires, caster, _, _, spellId = UnitDebuff(unit, i)
		if not name then break end
		if (caster == "player" or caster == "pet" or caster == "vehicle") and expires and expires > now then
			local d = t and ((spellId and t[spellId]) or t[name])
			local g = (spellId and spells[spellId]) or spells[name]
			local amount = (d and d.amount) or (g and g.amount)
			local interval = (d and d.interval) or (g and g.interval) or 3
			if amount then
				any = true
				total = total + TicksLeft(d, interval, expires, duration, now) * amount
			end
		end
	end
	return total, any
end

-- rapport dégâts prévus / vie restante (nil si rien de connu)
function Skull:Ratio(unit)
	if not UnitExists(unit) or UnitIsDeadOrGhost(unit) or not UnitCanAttack("player", unit) then return end
	local hp = UnitHealth(unit)
	if not hp or hp <= 0 then return end
	local dmg, any = self:RemainingDamage(unit)
	if not any then return end
	return dmg * (DB().skullMargin or 1) / hp
end

function Skull:WillDie(unit)
	local r = self:Ratio(unit)
	return r ~= nil and r >= 1
end

----------------------------------------------------------------
-- Barre de nom de la cible et sa barre de vie
----------------------------------------------------------------
local function PlateName(frame, depth)
	for _, r in ipairs({ frame:GetRegions() }) do
		if r:GetObjectType() == "FontString" and r:IsShown() then
			local txt = r:GetText()
			if txt and txt ~= "" and not txt:match("^[%d%s%%%.kKmM/]+$") then return txt end
		end
	end
	if (depth or 0) < 2 then
		for _, c in ipairs({ frame:GetChildren() }) do
			local n = PlateName(c, (depth or 0) + 1)
			if n then return n end
		end
	end
end

-- barre de vie : la StatusBar nommée « health » si elle existe, sinon la première visible
-- (dans une barre de nom 3.3.5 la barre de vie vient avant la barre d'incantation)
local function FindHealthBar(frame, depth, fallback)
	for _, c in ipairs({ frame:GetChildren() }) do
		if c:GetObjectType() == "StatusBar" and c:IsShown() and c:GetWidth() > 10 then
			local n = (c:GetName() or ""):lower()
			if n:find("health") or n:find("hp") then return c, true end
			fallback = fallback or c
		end
	end
	if (depth or 0) < 3 then
		for _, c in ipairs({ frame:GetChildren() }) do
			local hit, named = FindHealthBar(c, (depth or 0) + 1, nil)
			if named then return hit, true end
			fallback = fallback or hit
		end
	end
	return fallback, false
end

local cache = { guid = nil, plate = nil, bar = nil }

local function PlateIsTarget(plate, name)
	return plate:IsVisible() and PlateName(plate) == name
end

local function FindTargetPlate()
	if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
		local p = C_NamePlate.GetNamePlateForUnit("target")
		if p then return p end
	end
	local name = UnitName("target")
	if not name then return end
	-- la plaque mémorisée est encore la bonne : pas de nouvelle recherche
	if cache.plate and cache.guid == UnitGUID("target") and cache.plate:GetAlpha() > 0.95 and PlateIsTarget(cache.plate, name) then
		return cache.plate
	end
	local best, bestAlpha, count = nil, -1, 0
	for _, plate in ipairs({ WorldFrame:GetChildren() }) do
		if not plate:GetName() and PlateIsTarget(plate, name) then
			count = count + 1
			-- plusieurs barres du même nom : la cible est la seule à pleine opacité
			local a = plate:GetAlpha()
			if a > bestAlpha then best, bestAlpha = plate, a end
		end
	end
	if count > 1 and bestAlpha < 0.95 then return end -- impossible de savoir laquelle
	return best
end

local function TargetAnchor()
	local plate = FindTargetPlate()
	if plate then
		if cache.plate ~= plate or not (cache.bar and cache.bar:IsVisible()) then
			cache.plate = plate
			cache.bar = FindHealthBar(plate) or plate
		end
		cache.guid = UnitGUID("target")
		return cache.bar, true
	end
	cache.plate, cache.bar = nil, nil
	if DB().skullOnTarget then
		local uf = _G.EasyUIUnit_target
		local tf = (ns.UF and ns.UF.ready and uf and uf:IsShown() and uf)
			or (TargetFrame and TargetFrame:IsShown() and TargetFrame)
		if tf then return tf, false end
	end
end

----------------------------------------------------------------
-- Affichage
----------------------------------------------------------------
local icon = CreateFrame("Frame", "EasyUIDeathSkull", UIParent)
icon:SetFrameStrata("HIGH")
icon:SetFrameLevel(20)
icon.tex = icon:CreateTexture(nil, "OVERLAY")
icon.tex:SetAllPoints()
icon.tex:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
icon.shadow = icon:CreateTexture(nil, "BACKGROUND")
icon.shadow:SetPoint("TOPLEFT", -3, 3)
icon.shadow:SetPoint("BOTTOMRIGHT", 3, -3)
icon.shadow:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
icon.shadow:SetVertexColor(0, 0, 0, 0.6)
icon:SetAlpha(0)
icon:Hide()

local state = { on = false, lowSince = nil, anchor = nil, test = false }

local function Anchor(target, onPlate)
	local size = DB().skullSize or 26
	icon:SetSize(size, size)
	if state.anchor == target and state.size == size then return end
	state.anchor, state.size = target, size
	icon:ClearAllPoints()
	if onPlate then
		icon:SetPoint("RIGHT", target, "LEFT", -3 + (DB().skullX or 0), 0)
	else
		icon:SetPoint("RIGHT", target, "LEFT", -6 + (DB().skullX or 0), 0)
	end
end

local function SetOn(on)
	if state.on == on then return end
	state.on = on
	if on then icon:Show() end
end

function Skull:Reset()
	state.on, state.lowSince, state.anchor = false, nil, nil
	cache.plate, cache.bar, cache.guid = nil, nil, nil
	icon:SetAlpha(0)
	icon:Hide()
end

-- aperçu depuis le panneau : la tête de mort reste affichée 5 s sur la cible
function Skull:Test()
	state.test = GetTime() + 5
end

local acc = 0
local ticker = CreateFrame("Frame")
ticker:RegisterEvent("PLAYER_TARGET_CHANGED")
ticker:SetScript("OnEvent", function() Skull:Reset() end)
ticker:SetScript("OnUpdate", function(_, el)
	-- fondu (toujours fluide)
	local a = icon:GetAlpha()
	if state.on and a < 1 then
		icon:SetAlpha(math.min(1, a + el * 6))
	elseif not state.on and icon:IsShown() then
		a = a - el * 4
		if a <= 0 then icon:SetAlpha(0) icon:Hide() else icon:SetAlpha(a) end
	end

	acc = acc + el
	if acc < UPDATE then return end
	acc = 0
	if not (ns.db and DB().skull) then SetOn(false) return end

	local now = GetTime()
	local testing = state.test and state.test > now
	if not testing then state.test = nil end

	local ratio = Skull:Ratio("target")
	local want
	if testing and UnitExists("target") then
		want = true
	elseif not ratio then
		want = false
		state.lowSince = nil
	elseif ratio >= 1 then
		want = true
		state.lowSince = nil
	elseif state.on and ratio >= HIDE_RATIO then
		want = true -- zone grise : on garde l'état
	elseif state.on then
		state.lowSince = state.lowSince or now
		want = (now - state.lowSince) < HIDE_DELAY
	else
		want = false
	end

	if want then
		local target, onPlate = TargetAnchor()
		if target then
			Anchor(target, onPlate)
			SetOn(true)
			return
		end
	end
	SetOn(false)
end)

-- ancienne taille par défaut (18) : passe à la nouvelle, plus lisible
ns:On("ADDON_LOADED", function(name)
	if name ~= ns.name then return end
	local p = ns.db.plates
	if p and not p.skullV2 then
		if p.skullSize == 18 then p.skullSize = 26 end
		p.skullV2 = true
	end
end)
