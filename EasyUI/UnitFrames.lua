--[[
	EasyUI - Cadres d'unité (joueur, cible, cible de la cible, focus, familier)
	Inspiré de Shadowed Unit Frames, écrit pour le client 3.3.5 :
	- vie / ressource / portrait, textes (nom, niveau, vie, ressource)
	- couleur de classe ou de réaction, unité déjà engagée grisée
	- effets sur la cible et le focus (les miens en évidence), points de combo
	- icônes : combat, repos, chef, marqueur ; contour sur aggro
	- clic = cibler, clic droit = menu, compatible click-casting
	- aperçu et placement dans le mode édition (aimantation commune)
]]
local _, ns = ...
local WHITE = ns.media.white

local UF = {}
ns.UF = UF

local UNITS = { "player", "target", "targettarget", "focus", "pet" }
local LABELS = { player = "Joueur", target = "Cible", targettarget = "Cible de la cible", focus = "Focus", pet = "Familier" }
local frames = {}
local pending

local function DB() return ns.db.uf end
local function UDB(unit) return ns.db.uf.units[unit] end

----------------------------------------------------------------
-- Couleurs et textes
----------------------------------------------------------------
local function Short(v)
	if v >= 1e6 then return ("%.1fM"):format(v / 1e6) end
	if v >= 1e4 then return ("%.1fk"):format(v / 1e3) end
	return tostring(v)
end

local function UnitColor(unit)
	if UnitIsPlayer(unit) then
		local _, class = UnitClass(unit)
		local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
		if c then return c.r, c.g, c.b end
	end
	if UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit) then return 0.5, 0.5, 0.5 end
	local reaction = UnitReaction(unit, "player")
	local c = reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
	if c then return c.r, c.g, c.b end
	return 0.6, 0.6, 0.6
end

local function HealthColor(unit, pct)
	local mode = DB().colorMode
	if mode == "dark" then return 0.16, 0.16, 0.18 end
	if mode == "gradient" then
		if pct > 0.5 then return (1 - pct) * 2, 1, 0 end
		return 1, pct * 2, 0
	end
	return UnitColor(unit)
end

local function HealthText(unit, cur, max, fmt)
	if fmt == "none" then return "" end
	local pct = max > 0 and math.floor(cur / max * 100 + 0.5) or 0
	if fmt == "percent" then return pct .. "%" end
	if fmt == "current" then return Short(cur) end
	if fmt == "deficit" then return cur < max and ("-" .. Short(max - cur)) or "" end
	return Short(cur) .. " / " .. Short(max) .. "  |cffbbbbbb" .. pct .. "%|r"
end

local function LevelText(unit)
	local lvl = UnitLevel(unit)
	local txt = (lvl and lvl > 0) and tostring(lvl) or "??"
	local cls = UnitClassification(unit)
	if cls == "worldboss" then txt = "Boss"
	elseif cls == "rareelite" then txt = txt .. "+ Rare"
	elseif cls == "elite" then txt = txt .. "+"
	elseif cls == "rare" then txt = txt .. " Rare" end
	local c = (lvl and lvl > 0) and GetQuestDifficultyColor and GetQuestDifficultyColor(lvl) or { r = 1, g = 0.3, b = 0.3 }
	return ("|cff%02x%02x%02x%s|r"):format(c.r * 255, c.g * 255, c.b * 255, txt)
end

----------------------------------------------------------------
-- Construction d'un cadre
----------------------------------------------------------------
local function CreateAura(parent)
	local f = CreateFrame("Frame", nil, parent)
	ns:SetBackdrop(f, { 0, 0, 0, 1 }, { 0, 0, 0, 1 })
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetPoint("TOPLEFT", 1, -1)
	f.icon:SetPoint("BOTTOMRIGHT", -1, 1)
	f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
	f.cd:SetAllPoints(f.icon)
	f.cd:SetReverse(true)
	f.count = f:CreateFontString(nil, "OVERLAY")
	f.count:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
	f.count:SetPoint("BOTTOMRIGHT", 1, 0)
	f:EnableMouse(true)
	f:SetScript("OnEnter", function(self)
		if not self.unit then return end
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
		if self.harmful then GameTooltip:SetUnitDebuff(self.unit, self.index)
		else GameTooltip:SetUnitBuff(self.unit, self.index) end
	end)
	f:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f:Hide()
	return f
end

local MENUS = { player = "PlayerFrameDropDown", target = "TargetFrameDropDown", focus = "FocusFrameDropDown", pet = "PetFrameDropDown" }

local function Build(unit)
	local f = CreateFrame("Button", "EasyUIUnit_" .. unit, UIParent, "SecureUnitButtonTemplate")
	f.unitKey = unit
	f:SetAttribute("unit", unit)
	f:RegisterForClicks("AnyUp")
	f:SetAttribute("*type1", "target")
	if MENUS[unit] then
		f:SetAttribute("*type2", "menu")
		f.menu = function(self)
			local dd = _G[MENUS[unit]]
			if dd then ToggleDropDownMenu(1, nil, dd, "cursor", 0, 0) end
		end
	end
	f:SetFrameStrata("LOW")
	ClickCastFrames = ClickCastFrames or {}
	ClickCastFrames[f] = true

	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetTexture(WHITE)
	f.bg:SetAllPoints()

	f.border = CreateFrame("Frame", nil, f)
	f.border:SetPoint("TOPLEFT", -1, 1)
	f.border:SetPoint("BOTTOMRIGHT", 1, -1)
	f.border:SetBackdrop({ edgeFile = WHITE, edgeSize = 1 })
	f.border:SetBackdropBorderColor(0, 0, 0, 1)

	f.portrait = f:CreateTexture(nil, "ARTWORK")
	f.portrait:SetTexCoord(0.12, 0.88, 0.12, 0.88)

	f.health = CreateFrame("StatusBar", nil, f)
	f.health:SetStatusBarTexture(WHITE)
	f.health:SetMinMaxValues(0, 1)
	f.healthBg = f.health:CreateTexture(nil, "BACKGROUND")
	f.healthBg:SetTexture(WHITE)
	f.healthBg:SetAllPoints()

	f.power = CreateFrame("StatusBar", nil, f)
	f.power:SetStatusBarTexture(WHITE)
	f.power:SetMinMaxValues(0, 1)
	f.powerBg = f.power:CreateTexture(nil, "BACKGROUND")
	f.powerBg:SetTexture(WHITE)
	f.powerBg:SetAllPoints()

	local over = CreateFrame("Frame", nil, f)
	over:SetAllPoints()
	over:SetFrameLevel(f.health:GetFrameLevel() + 5)
	f.over = over
	f.name = over:CreateFontString(nil, "OVERLAY")
	f.level = over:CreateFontString(nil, "OVERLAY")
	f.hp = over:CreateFontString(nil, "OVERLAY")
	f.pp = over:CreateFontString(nil, "OVERLAY")
	for _, fs in ipairs({ f.name, f.level, f.hp, f.pp }) do fs:SetShadowOffset(1, -1) end

	f.combat = over:CreateTexture(nil, "OVERLAY")
	f.combat:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
	f.combat:SetTexCoord(0.5, 1, 0, 0.49)
	f.combat:SetSize(18, 18)
	f.rest = over:CreateTexture(nil, "OVERLAY")
	f.rest:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
	f.rest:SetTexCoord(0, 0.5, 0, 0.42)
	f.rest:SetSize(18, 18)
	f.leader = over:CreateTexture(nil, "OVERLAY")
	f.leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
	f.leader:SetSize(13, 13)
	f.raidIcon = over:CreateTexture(nil, "OVERLAY")
	f.raidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
	f.raidIcon:SetSize(18, 18)

	-- points de combo (cible)
	f.combo = {}
	for i = 1, 5 do
		local p = over:CreateTexture(nil, "OVERLAY")
		p:SetTexture(WHITE)
		p:Hide()
		f.combo[i] = p
	end

	f.auras = {}
	for i = 1, 24 do f.auras[i] = CreateAura(f) end

	f:SetScript("OnEnter", function(self)
		if UnitExists(unit) then
			GameTooltip_SetDefaultAnchor(GameTooltip, self)
			GameTooltip:SetUnit(unit)
			GameTooltip:Show()
		end
	end)
	f:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return f
end

----------------------------------------------------------------
-- Mise en page (taille, portrait, textes) selon les réglages
----------------------------------------------------------------
function UF:Layout(f)
	local db, u = DB(), UDB(f.unitKey)
	local font, boost = ns.media.font, ns.fontBoost or 0
	f:SetSize(u.width, u.height)
	f.bg:SetVertexColor(0, 0, 0, db.bgAlpha)

	local pw = 0
	f.portrait:ClearAllPoints()
	if u.portrait ~= "none" then
		pw = u.height - 2
		f.portrait:SetSize(pw, pw)
		if u.portrait == "right" then f.portrait:SetPoint("TOPRIGHT", -1, -1) else f.portrait:SetPoint("TOPLEFT", 1, -1) end
		f.portrait:Show()
	else
		f.portrait:Hide()
	end
	local left = (u.portrait == "left") and pw + 2 or 1
	local right = (u.portrait == "right") and -(pw + 2) or -1
	local ph = u.powerHeight
	f.health:ClearAllPoints()
	f.health:SetPoint("TOPLEFT", left, -1)
	f.health:SetPoint("BOTTOMRIGHT", right, ph > 0 and ph + 2 or 1)
	f.power:ClearAllPoints()
	f.power:SetPoint("BOTTOMLEFT", left, 1)
	f.power:SetPoint("BOTTOMRIGHT", right, 1)
	f.power:SetHeight(math.max(ph, 1))
	ns.SetShown(f.power, ph > 0)

	local size = u.fontSize + boost
	f.name:SetFont(font, size, "OUTLINE")
	f.level:SetFont(font, size - 1, "OUTLINE")
	f.hp:SetFont(font, size - 1, "OUTLINE")
	f.pp:SetFont(font, size - 2, "OUTLINE")
	f.name:ClearAllPoints()
	f.level:ClearAllPoints()
	f.hp:ClearAllPoints()
	f.pp:ClearAllPoints()
	f.level:SetPoint("LEFT", f.health, "LEFT", 4, 0)
	if u.showLevel then
		f.name:SetPoint("LEFT", f.level, "RIGHT", 4, 0)
	else
		f.name:SetPoint("LEFT", f.health, "LEFT", 4, 0)
	end
	f.name:SetPoint("RIGHT", f.hp, "LEFT", -4, 0)
	f.name:SetJustifyH("LEFT")
	f.hp:SetPoint("RIGHT", f.health, "RIGHT", -4, 0)
	f.pp:SetPoint("CENTER", f.power, "CENTER", 0, 0)
	ns.SetShown(f.pp, u.powerText and ph >= 8)

	f.combat:ClearAllPoints()
	f.combat:SetPoint("CENTER", f, "BOTTOMLEFT", left + 4, 2)
	f.rest:ClearAllPoints()
	f.rest:SetPoint("CENTER", f, "TOPLEFT", left + 4, -2)
	f.leader:ClearAllPoints()
	f.leader:SetPoint("CENTER", f, "TOPLEFT", left + 22, 0)
	f.raidIcon:ClearAllPoints()
	f.raidIcon:SetPoint("CENTER", f, "TOP", 0, 2)

	local cw = (u.width - 8) / 5
	for i = 1, 5 do
		local p = f.combo[i]
		p:ClearAllPoints()
		p:SetSize(cw - 2, 4)
		p:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 4 + (i - 1) * cw, 2)
	end

	-- effets : sous le cadre, de gauche à droite, plusieurs rangées
	local s = u.auraSize
	local perRow = math.max(1, math.floor((u.width + 2) / (s + 2)))
	for i = 1, 24 do
		local a = f.auras[i]
		a:SetSize(s, s)
		a:ClearAllPoints()
		local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
		a:SetPoint("TOPLEFT", f, "BOTTOMLEFT", col * (s + 2), -4 - row * (s + 2))
	end
end

----------------------------------------------------------------
-- Mises à jour
----------------------------------------------------------------
function UF:UpdateHealth(f)
	local unit = f.unitKey
	local cur, max = UnitHealth(unit), UnitHealthMax(unit)
	local pct = max > 0 and cur / max or 0
	local dead, off = UnitIsDeadOrGhost(unit), (UnitIsPlayer(unit) and not UnitIsConnected(unit))
	f.health:SetValue((dead or off) and 0 or pct)
	local r, g, b = HealthColor(unit, pct)
	f.health:SetStatusBarColor(r, g, b)
	if DB().colorMode == "dark" then
		f.healthBg:SetVertexColor(0.45, 0.08, 0.08, 0.6)
	else
		f.healthBg:SetVertexColor(r * 0.25, g * 0.25, b * 0.25, 1)
	end
	if off then f.hp:SetText("|cff999999Hors ligne|r")
	elseif dead then f.hp:SetText("|cffff5555Mort|r")
	else f.hp:SetText(HealthText(unit, cur, max, UDB(unit).healthText)) end
end

function UF:UpdatePower(f)
	local unit = f.unitKey
	if UDB(unit).powerHeight <= 0 then return end
	local ptype = UnitPowerType(unit)
	local max = UnitPowerMax(unit)
	local cur = UnitPower(unit)
	f.power:SetValue(max > 0 and cur / max or 0)
	local c = PowerBarColor and PowerBarColor[ptype] or { r = 0.3, g = 0.5, b = 1 }
	f.power:SetStatusBarColor(c.r, c.g, c.b)
	f.powerBg:SetVertexColor(c.r * 0.25, c.g * 0.25, c.b * 0.25, 1)
	f.pp:SetText(max > 0 and Short(cur) or "")
end

function UF:UpdateName(f)
	local unit = f.unitKey
	f.name:SetText(UnitName(unit) or "")
	if DB().colorMode == "dark" or UDB(unit).colorName then
		f.name:SetTextColor(UnitColor(unit))
	else
		f.name:SetTextColor(1, 1, 1)
	end
	f.level:SetText(UDB(unit).showLevel and LevelText(unit) or "")
	if UDB(unit).portrait ~= "none" then SetPortraitTexture(f.portrait, unit) end
end

function UF:UpdateIcons(f)
	local unit = f.unitKey
	ns.SetShown(f.combat, unit == "player" and UnitAffectingCombat("player"))
	ns.SetShown(f.rest, unit == "player" and IsResting() and not UnitAffectingCombat("player"))
	ns.SetShown(f.leader, UnitIsPartyLeader(unit))
	local idx = GetRaidTargetIndex(unit)
	if idx then SetRaidTargetIconTexture(f.raidIcon, idx) f.raidIcon:Show() else f.raidIcon:Hide() end
	-- contour sur aggro (joueur / familier) ou cible qui me tape
	local threat = UnitThreatSituation and UnitThreatSituation(unit) or 0
	if (unit == "player" or unit == "pet") and threat and threat >= 2 then
		f.border:SetBackdropBorderColor(0.95, 0.2, 0.2, 1)
	else
		f.border:SetBackdropBorderColor(0, 0, 0, 1)
	end
end

function UF:UpdateCombo(f)
	if f.unitKey ~= "target" then return end
	local n = GetComboPoints("player", "target") or 0
	local r, g, b = ns:GetAccent()
	for i = 1, 5 do
		local p = f.combo[i]
		if i <= n and UDB("target").combo then
			p:SetVertexColor(r, g, b, 1)
			p:Show()
		else
			p:Hide()
		end
	end
end

function UF:UpdateAuras(f)
	local unit = f.unitKey
	local u = UDB(unit)
	local n = 0
	local function add(name, tex, count, duration, expires, caster, harmful, index)
		n = n + 1
		local a = f.auras[n]
		a.unit, a.index, a.harmful = unit, index, harmful
		a.icon:SetTexture(tex)
		a.count:SetText((count and count > 1) and count or "")
		if duration and duration > 0 and expires then a.cd:SetCooldown(expires - duration, duration) a.cd:Show() else a.cd:Hide() end
		local mine = caster == "player" or caster == "pet" or caster == "vehicle"
		if harmful then
			a:SetBackdropBorderColor(mine and 0.9 or 0.3, mine and 0.2 or 0.1, mine and 0.2 or 0.1, 1)
			a:SetAlpha((u.fadeOthers and not mine) and 0.5 or 1)
		else
			a:SetBackdropBorderColor(0, 0, 0, 1)
			a:SetAlpha(1)
		end
		a:Show()
	end
	if u.debuffs > 0 then
		local shown = 0
		for i = 1, 40 do
			local name, _, tex, count, _, duration, expires, caster = UnitDebuff(unit, i)
			if not name then break end
			local mine = caster == "player" or caster == "pet" or caster == "vehicle"
			if (not u.onlyMine or mine) and shown < u.debuffs and n < 24 then
				shown = shown + 1
				add(name, tex, count, duration, expires, caster, true, i)
			end
		end
	end
	if u.buffs > 0 then
		local shown = 0
		for i = 1, 40 do
			local name, _, tex, count, _, duration, expires, caster = UnitBuff(unit, i)
			if not name or shown >= u.buffs or n >= 24 then break end
			shown = shown + 1
			add(name, tex, count, duration, expires, caster, false, i)
		end
	end
	for i = n + 1, 24 do f.auras[i]:Hide() end
end

function UF:UpdateAll(f)
	if not UnitExists(f.unitKey) then return end
	self:UpdateName(f)
	self:UpdateHealth(f)
	self:UpdatePower(f)
	self:UpdateIcons(f)
	self:UpdateCombo(f)
	self:UpdateAuras(f)
end

----------------------------------------------------------------
-- Application des réglages (hors combat)
----------------------------------------------------------------
function UF:Place(f)
	local p = UDB(f.unitKey).point
	f:ClearAllPoints()
	f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

function UF:Apply()
	if not self.ready then return end
	if InCombatLockdown() then pending = true return end
	pending = nil
	for unit, f in pairs(frames) do
		local enabled = DB().enabled and UDB(unit).enabled
		self:Layout(f)
		self:Place(f)
		if enabled then
			if unit == "player" then f:Show() else RegisterUnitWatch(f) end
			f.watched = unit ~= "player"
		else
			if f.watched then UnregisterUnitWatch(f) f.watched = nil end
			f:Hide()
		end
		self:UpdateAll(f)
	end
	self:HideBlizzard()
	if self.previewOn then self:ShowPreview(true) end
end

local hidden = {}
local function HideBlizzardFrame(name)
	local f = _G[name]
	if not f or hidden[f] then return end
	hidden[f] = true
	f:UnregisterAllEvents()
	f:Hide()
	hooksecurefunc(f, "Show", function(self) if not InCombatLockdown() then self:Hide() end end)
end

function UF:HideBlizzard()
	if InCombatLockdown() or not DB().enabled or not DB().hideBlizzard then return end
	if UDB("player").enabled then
		-- les barres de classe (runes, totems) restent visibles
		for _, n in ipairs({ "RuneFrame", "TotemFrame" }) do
			local c = _G[n]
			if c and c:GetParent() == PlayerFrame then
				local x, y = c:GetCenter()
				c:SetParent(UIParent)
				if x then c:ClearAllPoints() c:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y) end
			end
		end
		HideBlizzardFrame("PlayerFrame")
	end
	if UDB("target").enabled then HideBlizzardFrame("TargetFrame") HideBlizzardFrame("ComboFrame") end
	if UDB("focus").enabled then HideBlizzardFrame("FocusFrame") end
	if UDB("pet").enabled then HideBlizzardFrame("PetFrame") end
end

----------------------------------------------------------------
-- Aperçu (place les cadres absents pour les régler)
----------------------------------------------------------------
function UF:ShowPreview(on)
	if InCombatLockdown() then return end
	self.previewOn = on and true or false
	for unit, f in pairs(frames) do
		local enabled = DB().enabled and UDB(unit).enabled
		if unit ~= "player" and enabled then
			if on then
				if f.watched then UnregisterUnitWatch(f) f.watched = nil end
				f:Show()
				if not UnitExists(unit) then
					f.name:SetText(LABELS[unit])
					f.name:SetTextColor(1, 1, 1)
					f.level:SetText(UDB(unit).showLevel and "80" or "")
					f.health:SetValue(0.72)
					local r, g, b = ns:GetAccent()
					f.health:SetStatusBarColor(r, g, b)
					f.healthBg:SetVertexColor(r * 0.25, g * 0.25, b * 0.25, 1)
					f.hp:SetText(HealthText(unit, 18000, 25000, UDB(unit).healthText))
					f.power:SetValue(0.6)
					f.power:SetStatusBarColor(0.3, 0.5, 1)
					f.pp:SetText("")
					f.portrait:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
					for i = 1, 24 do f.auras[i]:Hide() end
				end
			else
				RegisterUnitWatch(f)
				f.watched = true
				self:UpdateAll(f)
			end
		end
	end
	if ns.ShowMovers then ns:ShowMovers() end
end

function UF:TogglePreview() self:ShowPreview(not self.previewOn) end

----------------------------------------------------------------
-- Événements
----------------------------------------------------------------
local events = CreateFrame("Frame")
local POWER = { UNIT_MANA = 1, UNIT_RAGE = 1, UNIT_ENERGY = 1, UNIT_RUNIC_POWER = 1, UNIT_FOCUS = 1,
	UNIT_MAXMANA = 1, UNIT_MAXRAGE = 1, UNIT_MAXENERGY = 1, UNIT_MAXRUNIC_POWER = 1, UNIT_MAXFOCUS = 1, UNIT_DISPLAYPOWER = 1 }

local function ForUnit(unit, func)
	local f = frames[unit]
	if f and f:IsShown() and UnitExists(unit) then func(UF, f) end
	-- la cible de la cible suit la cible
	if unit == "target" and frames.targettarget then
		local t = frames.targettarget
		if t:IsShown() and UnitExists("targettarget") then func(UF, t) end
	end
end

events:SetScript("OnEvent", function(_, event, unit)
	if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then ForUnit(unit, UF.UpdateHealth)
	elseif POWER[event] then ForUnit(unit, UF.UpdatePower)
	elseif event == "UNIT_AURA" then ForUnit(unit, UF.UpdateAuras)
	elseif event == "UNIT_NAME_UPDATE" or event == "UNIT_LEVEL" or event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_FACTION" then
		ForUnit(unit, UF.UpdateName)
	elseif event == "UNIT_THREAT_SITUATION_UPDATE" then ForUnit(unit, UF.UpdateIcons)
	elseif event == "UNIT_COMBO_POINTS" or event == "PLAYER_COMBO_POINTS" then
		if frames.target then UF:UpdateCombo(frames.target) end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if pending then UF:Apply() end
		for _, f in pairs(frames) do if f:IsShown() then UF:UpdateIcons(f) end end
	else
		-- changement de cible / focus / familier, groupe, marqueurs, repos, combat
		for _, f in pairs(frames) do if f:IsShown() then UF:UpdateAll(f) end end
	end
end)

-- la cible de la cible n'a pas d'événement : petite vérification régulière
local acc = 0
events:SetScript("OnUpdate", function(_, el)
	acc = acc + el
	if acc < 0.2 then return end
	acc = 0
	local t = frames.targettarget
	if t and t:IsShown() and UnitExists("targettarget") then UF:UpdateAll(t) end
end)

----------------------------------------------------------------
-- Démarrage
----------------------------------------------------------------
function UF:Init()
	if self.ready or not ns:ModuleEnabled("unitframes") then return end
	for _, unit in ipairs(UNITS) do
		frames[unit] = Build(unit)
		local f = frames[unit]
		ns:RegisterMover("uf_" .. unit, f, LABELS[unit], function(point, relPoint, x, y)
			UDB(unit).point = { point, relPoint, x, y }
		end, { page = "unitframes", keys = { unit } })
	end
	self.ready = true
	for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_AURA", "UNIT_NAME_UPDATE", "UNIT_LEVEL",
		"UNIT_PORTRAIT_UPDATE", "UNIT_FACTION", "UNIT_THREAT_SITUATION_UPDATE", "UNIT_COMBO_POINTS",
		"PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UNIT_PET", "UNIT_TARGET", "PARTY_LEADER_CHANGED",
		"PARTY_MEMBERS_CHANGED", "RAID_TARGET_UPDATE", "PLAYER_UPDATE_RESTING", "PLAYER_REGEN_DISABLED",
		"PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }) do
		pcall(events.RegisterEvent, events, e)
	end
	for e in pairs(POWER) do pcall(events.RegisterEvent, events, e) end
	self:Apply()
end

ns:On("LOGIN", function()
	if InCombatLockdown() then ns:On("COMBAT_END", function() UF:Init() end) else UF:Init() end
end)

ns:On("EDITMODE_CHANGED", function(on)
	if not UF.ready then return end
	if on then
		UF.previewByEdit = not UF.previewOn
		if UF.previewByEdit then UF:ShowPreview(true) end
	elseif UF.previewByEdit then
		UF.previewByEdit = nil
		UF:ShowPreview(false)
	end
end)
