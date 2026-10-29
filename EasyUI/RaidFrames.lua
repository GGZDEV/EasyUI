--[[
	EasyUI - Cadres de raid
	Cadres de groupe / raid modernes pour le client 3.3.5 :
	- un en-tête sécurisé par groupe (positions fixes), mode groupe et solo
	- vie (couleur de classe, sombre ou dégradé), ressource, nom, texte de vie
	- débuffs (surbrillance des dissipables), soins sur la durée posés par soi
	- aggro, cible, portée, rôle, chef, marqueur, appel « prêt »
	- compatible click-casting, aperçu factice, placement en mode édition
]]
local _, ns = ...
local C = ns.colors
local WHITE = ns.media.white

local RF = {}
ns.RF = RF

local MAX_GROUPS = 8
local headers, buttons, previews = {}, {}, {}
local byUnit = {}
local anchor, pending

local DEBUFF_COLORS = {
	Magic = { 0.2, 0.6, 1.0 }, Curse = { 0.6, 0.0, 1.0 },
	Disease = { 0.6, 0.4, 0.0 }, Poison = { 0.0, 0.6, 0.0 },
}

local function DB() return ns.db.raid end

----------------------------------------------------------------
-- Couleurs
----------------------------------------------------------------
local function ClassColor(unit, classToken)
	local class = classToken or (unit and select(2, UnitClass(unit)))
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then return c.r, c.g, c.b end
	return 0.6, 0.6, 0.6
end

local function HealthColor(db, pct, unit, classToken)
	if db.colorMode == "dark" then
		return 0.16, 0.16, 0.18
	elseif db.colorMode == "gradient" then
		if pct > 0.5 then return (1 - pct) * 2, 1, 0 end
		return 1, pct * 2, 0
	end
	return ClassColor(unit, classToken)
end

local function ShortName(name, len)
	if not name then return "" end
	-- coupe proprement les caractères UTF-8
	local out, n = "", 0
	for ch in name:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		n = n + 1
		if n > len then break end
		out = out .. ch
	end
	return out
end

----------------------------------------------------------------
-- Construction visuelle d'un bouton (vrai ou aperçu)
----------------------------------------------------------------
local function CreateAuraIcon(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(16, 16)
	ns:SetBackdrop(f, { 0, 0, 0, 1 }, { 0, 0, 0, 1 })
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetPoint("TOPLEFT", 1, -1)
	f.icon:SetPoint("BOTTOMRIGHT", -1, 1)
	f.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
	f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
	f.cd:SetAllPoints(f.icon)
	f.cd:SetReverse(true)
	f.count = f:CreateFontString(nil, "OVERLAY")
	f.count:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
	f.count:SetPoint("BOTTOMRIGHT", 1, 0)
	f:Hide()
	return f
end

function RF:Build(b)
	if b.arduiBuilt then return end
	b.arduiBuilt = true

	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetTexture(WHITE)
	b.bg:SetAllPoints()

	b.health = CreateFrame("StatusBar", nil, b)
	b.health:SetStatusBarTexture(WHITE)
	b.health:SetMinMaxValues(0, 1)
	b.healthBg = b.health:CreateTexture(nil, "BACKGROUND")
	b.healthBg:SetTexture(WHITE)
	b.healthBg:SetAllPoints()

	b.power = CreateFrame("StatusBar", nil, b)
	b.power:SetStatusBarTexture(WHITE)
	b.power:SetMinMaxValues(0, 1)

	local over = CreateFrame("Frame", nil, b)
	over:SetAllPoints()
	over:SetFrameLevel(b.health:GetFrameLevel() + 5)
	b.over = over

	b.name = over:CreateFontString(nil, "OVERLAY")
	b.name:SetShadowOffset(1, -1)
	b.status = over:CreateFontString(nil, "OVERLAY")
	b.status:SetShadowOffset(1, -1)

	-- bordure d'état (cible, aggro, dissipation)
	b.border = CreateFrame("Frame", nil, b)
	b.border:SetPoint("TOPLEFT", -1, 1)
	b.border:SetPoint("BOTTOMRIGHT", 1, -1)
	b.border:SetBackdrop({ edgeFile = WHITE, edgeSize = 1 })
	b.border:SetFrameLevel(over:GetFrameLevel() + 1)
	b.glow = CreateFrame("Frame", nil, b)
	b.glow:SetPoint("TOPLEFT", 1, -1)
	b.glow:SetPoint("BOTTOMRIGHT", -1, 1)
	b.glow:SetBackdrop({ edgeFile = WHITE, edgeSize = 2 })
	b.glow:SetFrameLevel(over:GetFrameLevel() + 2)
	b.glow:Hide()

	b.role = over:CreateTexture(nil, "OVERLAY")
	b.leader = over:CreateTexture(nil, "OVERLAY")
	b.leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
	b.raidIcon = over:CreateTexture(nil, "OVERLAY")
	b.raidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
	b.ready = over:CreateTexture(nil, "OVERLAY")

	b.debuffs, b.buffs = {}, {}
	for i = 1, 4 do
		b.debuffs[i] = CreateAuraIcon(over)
		b.buffs[i] = CreateAuraIcon(over)
	end
	self:Style(b)
end

-- applique taille, polices et positions selon les réglages
function RF:Style(b)
	local db = DB()
	local font = ns.media.font
	local boost = ns.fontBoost or 0

	b.bg:SetVertexColor(0, 0, 0, db.bgAlpha)
	local ph = (db.powerHeight > 0) and db.powerHeight or 0
	b.health:ClearAllPoints()
	b.health:SetPoint("TOPLEFT", 1, -1)
	b.health:SetPoint("BOTTOMRIGHT", -1, 1 + (ph > 0 and ph + 1 or 0))
	b.power:ClearAllPoints()
	b.power:SetPoint("BOTTOMLEFT", 1, 1)
	b.power:SetPoint("BOTTOMRIGHT", -1, 1)
	b.power:SetHeight(math.max(ph, 1))
	ns.SetShown(b.power, ph > 0)

	b.name:SetFont(font, db.fontSize + boost, "OUTLINE")
	b.status:SetFont(font, db.fontSize - 1 + boost, "OUTLINE")
	b.name:ClearAllPoints()
	b.status:ClearAllPoints()
	if db.healthText == "none" then
		b.name:SetPoint("CENTER", 0, ph > 0 and 1 or 0)
	else
		b.name:SetPoint("CENTER", 0, 6)
		b.status:SetPoint("TOP", b.name, "BOTTOM", 0, -2)
	end

	local r, g, bb = ns:GetAccent()
	b.border:SetBackdropBorderColor(0, 0, 0, 1)

	b.role:SetSize(12, 12)
	b.role:ClearAllPoints()
	b.role:SetPoint("TOPLEFT", 3, -3)
	b.leader:SetSize(11, 11)
	b.leader:ClearAllPoints()
	b.leader:SetPoint("TOPLEFT", db.roleIcon and 15 or 3, -2)
	b.raidIcon:SetSize(14, 14)
	b.raidIcon:ClearAllPoints()
	b.raidIcon:SetPoint("TOP", 0, 6)
	b.ready:SetSize(18, 18)
	b.ready:ClearAllPoints()
	b.ready:SetPoint("CENTER")

	for i = 1, 4 do
		local d = b.debuffs[i]
		d:SetSize(db.debuffSize, db.debuffSize)
		d:ClearAllPoints()
		if i == 1 then d:SetPoint("BOTTOMLEFT", b.health, "BOTTOMLEFT", 2, 2)
		else d:SetPoint("LEFT", b.debuffs[i - 1], "RIGHT", 1, 0) end
		local h = b.buffs[i]
		h:SetSize(db.buffSize, db.buffSize)
		h:ClearAllPoints()
		if i == 1 then h:SetPoint("TOPRIGHT", b.health, "TOPRIGHT", -2, -2)
		else h:SetPoint("RIGHT", b.buffs[i - 1], "LEFT", -1, 0) end
	end
end

----------------------------------------------------------------
-- Mise à jour d'un bouton réel
----------------------------------------------------------------
local function SetAura(icon, tex, count, duration, expires)
	icon.icon:SetTexture(tex)
	icon.count:SetText((count and count > 1) and count or "")
	if duration and duration > 0 and expires then
		icon.cd:SetCooldown(expires - duration, duration)
		icon.cd:Show()
	else
		icon.cd:Hide()
	end
	icon:Show()
end

function RF:UpdateAuras(b, unit)
	local db = DB()
	local dispelType
	local n = 0
	for i = 1, 40 do
		local name, _, tex, count, dtype, duration, expires = UnitDebuff(unit, i)
		if not name then break end
		if dtype and DEBUFF_COLORS[dtype] and not dispelType then dispelType = dtype end
		if n < db.debuffs then
			n = n + 1
			SetAura(b.debuffs[n], tex, count, duration, expires)
		end
	end
	for i = n + 1, 4 do b.debuffs[i]:Hide() end

	n = 0
	if db.buffs > 0 then
		for i = 1, 40 do
			local name, _, tex, count, _, duration, expires = UnitAura(unit, i, "HELPFUL|PLAYER")
			if not name then break end
			n = n + 1
			SetAura(b.buffs[n], tex, count, duration, expires)
			if n >= db.buffs then break end
		end
	end
	for i = n + 1, 4 do b.buffs[i]:Hide() end
	b.dispelType = dispelType
end

function RF:UpdateBorder(b, unit)
	local db = DB()
	local c
	if db.dispelHighlight and b.dispelType then
		c = DEBUFF_COLORS[b.dispelType]
	elseif db.aggro and UnitThreatSituation and (UnitThreatSituation(unit) or 0) >= 2 then
		c = { 0.95, 0.2, 0.2 }
	end
	if c then
		b.glow:SetBackdropBorderColor(c[1], c[2], c[3], 1)
		b.glow:Show()
	else
		b.glow:Hide()
	end
	if db.targetHighlight and UnitIsUnit(unit, "target") then
		b.border:SetBackdropBorderColor(1, 1, 1, 1)
	else
		b.border:SetBackdropBorderColor(0, 0, 0, 1)
	end
end

function RF:UpdateHealth(b, unit)
	local db = DB()
	local cur, max = UnitHealth(unit), UnitHealthMax(unit)
	local pct = (max and max > 0) and cur / max or 0
	local dead = UnitIsDeadOrGhost(unit)
	local offline = not UnitIsConnected(unit)
	if dead or offline then pct = 0 end
	b.health:SetValue(pct)
	local r, g, bb = HealthColor(db, pct, unit)
	b.health:SetStatusBarColor(r, g, bb, 1)
	if db.colorMode == "dark" then
		b.healthBg:SetVertexColor(0.45, 0.08, 0.08, 0.6)
	else
		b.healthBg:SetVertexColor(r * 0.25, g * 0.25, bb * 0.25, 1)
	end

	local text = ""
	if offline then
		text = "|cff999999Hors ligne|r"
	elseif UnitIsGhost(unit) then
		text = "|cffaaaaaaFantôme|r"
	elseif dead then
		text = "|cffff5555Mort|r"
	elseif db.healthText == "deficit" and cur < max then
		local d = max - cur
		text = "-" .. (d >= 10000 and ("%.1fk"):format(d / 1000) or d)
	elseif db.healthText == "percent" and cur < max then
		text = ("%d%%"):format(pct * 100)
	elseif db.healthText == "current" then
		text = cur >= 10000 and ("%.1fk"):format(cur / 1000) or tostring(cur)
	end
	b.status:SetText(text)
end

function RF:UpdatePower(b, unit)
	local db = DB()
	if db.powerHeight <= 0 then return end
	local ptype = UnitPowerType(unit)
	if db.powerManaOnly and ptype ~= 0 then
		b.power:SetValue(0)
		b.power:SetAlpha(0)
		return
	end
	b.power:SetAlpha(1)
	local max = UnitPowerMax(unit)
	b.power:SetValue(max > 0 and UnitPower(unit) / max or 0)
	local c = PowerBarColor and PowerBarColor[ptype]
	if c then b.power:SetStatusBarColor(c.r, c.g, c.b) else b.power:SetStatusBarColor(0.3, 0.5, 1) end
end

function RF:UpdateName(b, unit)
	local db = DB()
	b.name:SetText(ShortName(UnitName(unit), db.nameLength))
	if db.colorMode == "dark" then
		b.name:SetTextColor(ClassColor(unit))
	else
		b.name:SetTextColor(1, 1, 1)
	end
end

function RF:UpdateIcons(b, unit)
	local db = DB()
	-- rôle (3.3 : UnitGroupRolesAssigned renvoie trois booléens)
	local shown = false
	if db.roleIcon and UnitGroupRolesAssigned then
		local isTank, isHeal, isDps = UnitGroupRolesAssigned(unit)
		local role = (isTank == true or isTank == "TANK") and "TANK"
			or (isHeal == true or isTank == "HEALER") and "HEALER"
			or (isDps == true or isTank == "DAMAGER") and "DAMAGER" or nil
		if role and GetTexCoordsForRoleSmallCircle then
			b.role:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
			b.role:SetTexCoord(GetTexCoordsForRoleSmallCircle(role))
			shown = true
		end
	end
	ns.SetShown(b.role, shown)
	ns.SetShown(b.leader, db.leaderIcon and UnitIsPartyLeader(unit))
	local idx = db.raidIcon and GetRaidTargetIndex(unit)
	if idx then
		SetRaidTargetIconTexture(b.raidIcon, idx)
		b.raidIcon:Show()
	else
		b.raidIcon:Hide()
	end
end

function RF:UpdateReady(b, unit)
	local status = DB().readyCheck and GetReadyCheckStatus and GetReadyCheckStatus(unit)
	if status == "ready" then
		b.ready:SetTexture(READY_CHECK_READY_TEXTURE)
	elseif status == "notready" then
		b.ready:SetTexture(READY_CHECK_NOT_READY_TEXTURE)
	elseif status == "waiting" then
		b.ready:SetTexture(READY_CHECK_WAITING_TEXTURE)
	else
		b.ready:Hide()
		return
	end
	b.ready:Show()
end

function RF:UpdateRange(b, unit)
	local inRange = true
	if not UnitIsUnit(unit, "player") and (UnitInRaid(unit) or UnitInParty(unit)) then
		inRange = UnitInRange(unit) and true or false
	end
	if not UnitIsConnected(unit) then inRange = false end
	b:SetAlpha(inRange and 1 or DB().rangeAlpha)
end

function RF:UpdateAll(b)
	local unit = b.unit
	if not unit or not UnitExists(unit) then return end
	self:UpdateName(b, unit)
	self:UpdateHealth(b, unit)
	self:UpdatePower(b, unit)
	self:UpdateAuras(b, unit)
	self:UpdateBorder(b, unit)
	self:UpdateIcons(b, unit)
	self:UpdateReady(b, unit)
	self:UpdateRange(b, unit)
end

----------------------------------------------------------------
-- Menu au clic droit
----------------------------------------------------------------
local dropdown
local function ShowMenu(self)
	if not dropdown then
		dropdown = CreateFrame("Frame", "EasyUIRaidDropDown", UIParent, "UIDropDownMenuTemplate")
		UIDropDownMenu_Initialize(dropdown, function(dd)
			local unit = dd.unit
			if not unit then return end
			local which
			if UnitIsUnit(unit, "player") then which = "SELF"
			elseif UnitInRaid(unit) then which = "RAID_PLAYER"
			elseif UnitInParty(unit) then which = "PARTY"
			else which = "PLAYER" end
			local raidIndex = UnitInRaid(unit)
			UnitPopup_ShowMenu(dd, which, unit, nil, raidIndex)
		end, "MENU")
	end
	dropdown.unit = self:GetAttribute("unit")
	ToggleDropDownMenu(1, nil, dropdown, "cursor", 0, 0)
end

----------------------------------------------------------------
-- Boutons sécurisés
----------------------------------------------------------------
local function OnAttributeChanged(self, name, value)
	if name ~= "unit" then return end
	if self.unit and byUnit[self.unit] == self then byUnit[self.unit] = nil end
	self.unit = value
	if value then
		byUnit[value] = self
		RF:UpdateAll(self)
	end
end

local function InitButton(a, b2)
	-- selon la version, l'en-tête passe (bouton) ou (en-tête, bouton)
	local b = (type(b2) == "table" and b2.GetAttribute) and b2 or a
	if b.arduiInit then return end
	b.arduiInit = true
	buttons[#buttons + 1] = b
	b:RegisterForClicks("AnyUp")
	b:SetAttribute("*type1", "target")
	b:SetAttribute("*type2", "menu")
	b.menu = ShowMenu
	b:HookScript("OnAttributeChanged", OnAttributeChanged)
	b:HookScript("OnEnter", function(self)
		if self.unit and not InCombatLockdown() then
			GameTooltip_SetDefaultAnchor(GameTooltip, self)
			GameTooltip:SetUnit(self.unit)
			GameTooltip:Show()
		end
	end)
	b:HookScript("OnLeave", function() GameTooltip:Hide() end)
	RF:Build(b)
	if not InCombatLockdown() then
		local l = RF:Layout()
		b:SetWidth(l.width)
		b:SetHeight(l.height)
	end
	-- click-casting
	ClickCastFrames = ClickCastFrames or {}
	ClickCastFrames[b] = true
end

----------------------------------------------------------------
-- Dispositions par taille de groupe
-- Chaque taille (groupe, raid 10, 25, 40) a sa propre disposition :
-- taille des cadres, espacements, sens des joueurs, sens des groupes, position.
----------------------------------------------------------------
local BRACKETS = { "party", "raid10", "raid25", "raid40" }
local BRACKET_GROUPS = { party = 1, raid10 = 2, raid25 = 5, raid40 = 8 }
local BRACKET_SIZE = { party = 5, raid10 = 10, raid25 = 25, raid40 = 40 }
local BRACKET_LABEL = { party = "Groupe (5)", raid10 = "Raid 10", raid25 = "Raid 25", raid40 = "Raid 40" }
local LAYOUT_KEYS = { "width", "height", "spacing", "groupSpacing", "groupsPerRow", "growth", "groupGrowth" }
RF.BRACKETS, RF.BRACKET_LABEL, RF.BRACKET_SIZE = BRACKETS, BRACKET_LABEL, BRACKET_SIZE
RF.DEFAULT_POINT = { "TOPLEFT", "TOPLEFT", 30, -280 }

local function CopyLayout(src)
	local t = {}
	for _, k in ipairs(LAYOUT_KEYS) do t[k] = src[k] end
	local p = src.point or RF.DEFAULT_POINT
	t.point = { p[1], p[2], p[3], p[4] }
	return t
end
RF.CopyLayout = CopyLayout

-- crée les dispositions à partir des anciens réglages uniques
local function EnsureLayouts()
	local db = DB()
	if not db.layouts then
		local base = {
			width = db.width or 88, height = db.height or 46, spacing = db.spacing or 3,
			groupSpacing = db.groupSpacing or 10, groupsPerRow = db.groupsPerRow or 8,
			growth = db.growth or "DOWN", point = db.point,
		}
		base.groupGrowth = (base.growth == "DOWN" or base.growth == "UP") and "RIGHT" or "DOWN"
		db.layouts = {}
		for _, b in ipairs(BRACKETS) do db.layouts[b] = CopyLayout(base) end
	end
	for _, b in ipairs(BRACKETS) do
		local l = db.layouts[b]
		if not l then l = CopyLayout(db.layouts.raid25 or db) db.layouts[b] = l end
		l.groupGrowth = l.groupGrowth or "RIGHT"
		l.point = l.point or { unpack(RF.DEFAULT_POINT) }
	end
	return db.layouts
end

-- taille réelle du groupe
local function RealBracket()
	local n = GetNumRaidMembers()
	if n == 0 then return "party" end
	if n <= 10 then return "raid10" end
	if n <= 25 then return "raid25" end
	return "raid40"
end

local function PreviewBracket(count)
	if count <= 5 then return "party" end
	if count <= 10 then return "raid10" end
	if count <= 25 then return "raid25" end
	return "raid40"
end

-- disposition affichée : celle de l'aperçu s'il est visible, sinon celle du groupe réel
function RF:Bracket()
	if self.previewShown then return PreviewBracket(DB().previewCount) end
	return RealBracket()
end

function RF:Layout(bracket)
	return EnsureLayouts()[bracket or self:Bracket()]
end
local function L() return RF:Layout() end

-- nombre de groupes à placer (ceux de la taille, ou plus si un joueur est dans un groupe plus loin)
local function GroupCount(bracket)
	local n = BRACKET_GROUPS[bracket]
	if RF.previewShown then
		return math.max(1, math.ceil(DB().previewCount / 5))
	end
	for i = 1, GetNumRaidMembers() do
		local _, _, sub = GetRaidRosterInfo(i)
		if sub and sub > n then n = sub end
	end
	return math.min(MAX_GROUPS, n)
end

local function HeaderPoint(l)
	local s = l.spacing
	if l.growth == "UP" then return "BOTTOM", 0, s
	elseif l.growth == "RIGHT" then return "LEFT", s, 0
	elseif l.growth == "LEFT" then return "RIGHT", -s, 0 end
	return "TOP", 0, -s
end

-- taille d'un groupe de 5
local function GroupGeometry(l)
	local vertical = (l.growth == "DOWN" or l.growth == "UP")
	local gw = vertical and l.width or (l.width * 5 + l.spacing * 4)
	local gh = vertical and (l.height * 5 + l.spacing * 4) or l.height
	return gw, gh, vertical
end

-- disposition des groupes : par ligne de « groupsPerRow », dans le sens choisi
local function GroupGrid(l, n)
	local perLine = math.max(1, math.min(n, l.groupsPerRow))
	local lines = math.ceil(n / perLine)
	local gw, gh = GroupGeometry(l)
	local gs = l.groupSpacing
	local horizontal = (l.groupGrowth == "RIGHT" or l.groupGrowth == "LEFT")
	local W, H
	if horizontal then
		W, H = perLine * gw + (perLine - 1) * gs, lines * gh + (lines - 1) * gs
	else
		W, H = lines * gw + (lines - 1) * gs, perLine * gh + (perLine - 1) * gs
	end
	return perLine, W, H, horizontal
end

-- coin haut-gauche du groupe g, relatif au coin haut-gauche de l'ancre
local function GroupOffset(l, g, n)
	local perLine, _, _, horizontal = GroupGrid(l, n)
	local gw, gh = GroupGeometry(l)
	local gs = l.groupSpacing
	local i, j = (g - 1) % perLine, math.floor((g - 1) / perLine)
	local col, row
	if horizontal then
		col = (l.groupGrowth == "LEFT") and (perLine - 1 - i) or i
		row = j
	else
		row = (l.groupGrowth == "UP") and (perLine - 1 - i) or i
		col = j
	end
	return col * (gw + gs), -row * (gh + gs)
end

function RF:LayoutAnchor()
	local bracket = self:Bracket()
	local l = self:Layout(bracket)
	local n = GroupCount(bracket)
	local _, W, H = GroupGrid(l, n)
	anchor:SetSize(W, H)
	anchor:ClearAllPoints()
	local p = l.point
	anchor:SetPoint(p[1], UIParent, p[2], p[3], p[4])
	self.shownBracket, self.shownGroups = bracket, n
	if self.mover then
		self.mover.text:SetText("Cadres de raid\n|cff999999" .. BRACKET_LABEL[bracket] .. " - molette pour changer|r")
	end
end

function RF:ConfigureHeaders()
	local db = DB()
	local l = L()
	local n = self.shownGroups or MAX_GROUPS
	local point, xo, yo = HeaderPoint(l)
	local gw, gh = GroupGeometry(l)
	for g = 1, MAX_GROUPS do
		local h = headers[g]
		h:SetAttribute("point", point)
		h:SetAttribute("xOffset", xo)
		h:SetAttribute("yOffset", yo)
		h:SetAttribute("sortMethod", db.sortByName and "NAME" or "INDEX")
		h:SetAttribute("groupFilter", tostring(g))
		h:SetAttribute("showRaid", true)
		h:SetAttribute("showParty", g == 1 and db.showParty)
		h:SetAttribute("showPlayer", g == 1 and db.showPlayer)
		h:SetAttribute("showSolo", g == 1 and db.showSolo)
		h:SetAttribute("unitsPerColumn", 5)
		h:SetAttribute("maxColumns", 1)
		h:ClearAllPoints()
		-- un groupe au-delà de la taille prévue va à la suite des autres
		local x, y = GroupOffset(l, g, math.max(n, g))
		if l.growth == "UP" then
			h:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", x, y - gh)
		elseif l.growth == "LEFT" then
			h:SetPoint("TOPRIGHT", anchor, "TOPLEFT", x + gw, y)
		else
			h:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, y)
		end
		if db.enabled then h:Show() else h:Hide() end
	end
end

-- applique tous les réglages (hors combat uniquement)
function RF:Apply()
	if not anchor then return end
	if InCombatLockdown() then pending = true return end
	pending = nil
	self:LayoutAnchor()
	local l = L()
	for _, b in ipairs(buttons) do
		b:SetWidth(l.width)
		b:SetHeight(l.height)
		self:Style(b)
	end
	self:ConfigureHeaders()
	for _, b in ipairs(buttons) do self:UpdateAll(b) end
	self:HideBlizzard()
	if self.previewShown then self:DrawPreview() end
	if ns.ShowMovers and ns.editMode then ns:ShowMovers() end
end

-- la taille du groupe a changé : nouvelle disposition
function RF:CheckBracket()
	if not anchor or self.previewShown then return end
	local b = RealBracket()
	if b ~= self.shownBracket or GroupCount(b) ~= self.shownGroups then self:Apply() end
end

----------------------------------------------------------------
-- Cadres Blizzard
----------------------------------------------------------------
local hiddenParty
function RF:HideBlizzard()
	local db = DB()
	if InCombatLockdown() then return end
	if db.enabled and db.hideBlizzParty and not hiddenParty then
		hiddenParty = true
		for i = 1, 4 do
			local f = _G["PartyMemberFrame" .. i]
			if f then
				f:UnregisterAllEvents()
				f:Hide()
				hooksecurefunc(f, "Show", function(self) if not InCombatLockdown() then self:Hide() end end)
			end
		end
		if PartyMemberBackground then PartyMemberBackground:Hide() end
	end
	if db.enabled and db.hideBlizzRaid then
		for _, name in ipairs({ "CompactRaidFrameManager", "CompactRaidFrameContainer" }) do
			local f = _G[name]
			if f and not f.arduiHidden then
				f.arduiHidden = true
				f:UnregisterAllEvents()
				f:Hide()
				hooksecurefunc(f, "Show", function(self) if not InCombatLockdown() then self:Hide() end end)
			end
		end
	end
end

----------------------------------------------------------------
-- Aperçu (cadres factices pour régler la disposition en solo)
----------------------------------------------------------------
local FAKE_NAMES = { "Arthas", "Jaina", "Thrall", "Sylvanas", "Uther", "Varian", "Tyrande", "Malfurion",
	"Illidan", "Garrosh", "Anduin", "Velen", "Khadgar", "Medivh", "Bolvar", "Tirion", "Rexxar", "Valeera",
	"Muradin", "Brann", "Magni", "Cairne", "Vol'jin", "Rokhan", "Lor'themar", "Kael", "Alleria", "Vereesa",
	"Rhonin", "Modera", "Aethas", "Liadrin", "Nobundo", "Akama", "Maiev", "Shandris", "Fandral", "Broll",
	"Hamuul", "Mekkatorque" }

function RF:ShowPreview(on)
	self.previewShown = on and true or false
	for _, p in ipairs(previews) do p:Hide() end
	if not anchor then return end
	-- l'aperçu change la disposition affichée (taille de raid de l'aperçu)
	if InCombatLockdown() then
		pending = true
		if on then self:DrawPreview() end
	else
		self:Apply()
	end
end

-- taille d'aperçu suivante / précédente (molette sur la poignée en mode édition)
function RF:CyclePreview(delta)
	local sizes = { 5, 10, 25, 40 }
	local cur = DB().previewCount
	local idx = 1
	for i, v in ipairs(sizes) do if v == cur then idx = i end end
	idx = math.max(1, math.min(#sizes, idx + (delta > 0 and 1 or -1)))
	DB().previewCount = sizes[idx]
	if not self.previewShown then self.previewByEdit = true end
	self:ShowPreview(true)
	if self.page and self.page.view and self.page.view.Refresh then self.page.view:Refresh() end
end

function RF:DrawPreview()
	for _, p in ipairs(previews) do p:Hide() end
	if not anchor then return end
	local db = DB()
	local l = L()
	local count = db.previewCount
	local n = math.max(1, math.ceil(count / 5))
	local classes = {}
	for class in pairs(RAID_CLASS_COLORS or {}) do classes[#classes + 1] = class end
	table.sort(classes)
	for i = 1, count do
		local p = previews[i]
		if not p then
			p = CreateFrame("Frame", nil, anchor)
			RF:Build(p)
			previews[i] = p
		end
		RF:Style(p)
		p:SetSize(l.width, l.height)
		local g = math.floor((i - 1) / 5) + 1
		local idx = (i - 1) % 5
		local gx, gy = GroupOffset(l, g, n)
		p:ClearAllPoints()
		if l.growth == "DOWN" then
			p:SetPoint("TOPLEFT", anchor, "TOPLEFT", gx, gy - idx * (l.height + l.spacing))
		elseif l.growth == "UP" then
			p:SetPoint("TOPLEFT", anchor, "TOPLEFT", gx, gy - (4 - idx) * (l.height + l.spacing))
		elseif l.growth == "RIGHT" then
			p:SetPoint("TOPLEFT", anchor, "TOPLEFT", gx + idx * (l.width + l.spacing), gy)
		else
			p:SetPoint("TOPLEFT", anchor, "TOPLEFT", gx + (4 - idx) * (l.width + l.spacing), gy)
		end
		local class = classes[((i * 7) % math.max(1, #classes)) + 1]
		local pct = ((i * 37) % 100) / 100
		if i % 6 == 0 then pct = 1 end
		p.health:SetValue(pct)
		local r, g2, b2 = HealthColor(db, pct, nil, class)
		p.health:SetStatusBarColor(r, g2, b2)
		if db.colorMode == "dark" then
			p.healthBg:SetVertexColor(0.45, 0.08, 0.08, 0.6)
			p.name:SetTextColor(ClassColor(nil, class))
		else
			p.healthBg:SetVertexColor(r * 0.25, g2 * 0.25, b2 * 0.25, 1)
			p.name:SetTextColor(1, 1, 1)
		end
		p.name:SetText(ShortName(FAKE_NAMES[i] or ("Joueur " .. i), db.nameLength))
		local text = ""
		if i == 9 then text = "|cffff5555Mort|r" p.health:SetValue(0)
		elseif db.healthText == "deficit" and pct < 1 then text = "-" .. math.floor((1 - pct) * 18000)
		elseif db.healthText == "percent" and pct < 1 then text = ("%d%%"):format(pct * 100)
		elseif db.healthText == "current" then text = tostring(math.floor(pct * 18000)) end
		p.status:SetText(text)
		p.power:SetValue(0.7)
		p.power:SetStatusBarColor(0.25, 0.45, 1)
		p.power:SetAlpha((db.powerManaOnly and i % 3 == 0) and 0 or 1)
		p.role:Hide() p.leader:Hide() p.raidIcon:Hide() p.ready:Hide()
		for k = 1, 4 do p.debuffs[k]:Hide() p.buffs[k]:Hide() end
		if i % 4 == 1 and db.debuffs > 0 then
			p.debuffs[1].icon:SetTexture("Interface\\Icons\\Spell_Shadow_ShadowWordPain")
			p.debuffs[1].count:SetText("")
			p.debuffs[1].cd:Hide()
			p.debuffs[1]:Show()
			if db.dispelHighlight then
				p.glow:SetBackdropBorderColor(0.2, 0.6, 1, 1)
				p.glow:Show()
			end
		else
			p.glow:Hide()
		end
		if i % 3 == 0 and db.buffs > 0 then
			p.buffs[1].icon:SetTexture("Interface\\Icons\\Spell_Nature_Rejuvenation")
			p.buffs[1].count:SetText("")
			p.buffs[1].cd:Hide()
			p.buffs[1]:Show()
		end
		p.border:SetBackdropBorderColor(0, 0, 0, 1)
		p:SetAlpha(i % 7 == 0 and db.rangeAlpha or 1)
		p:Show()
	end
end

----------------------------------------------------------------
-- Événements
----------------------------------------------------------------
local events = CreateFrame("Frame")
local POWER_EVENTS = { UNIT_MANA = 1, UNIT_RAGE = 1, UNIT_ENERGY = 1, UNIT_RUNIC_POWER = 1, UNIT_FOCUS = 1,
	UNIT_MAXMANA = 1, UNIT_MAXRAGE = 1, UNIT_MAXENERGY = 1, UNIT_MAXRUNIC_POWER = 1, UNIT_MAXFOCUS = 1, UNIT_DISPLAYPOWER = 1 }

events:SetScript("OnEvent", function(_, event, unit)
	if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
		local b = byUnit[unit] if b then RF:UpdateHealth(b, unit) end
	elseif POWER_EVENTS[event] then
		local b = byUnit[unit] if b then RF:UpdatePower(b, unit) end
	elseif event == "UNIT_AURA" then
		local b = byUnit[unit] if b then RF:UpdateAuras(b, unit) RF:UpdateBorder(b, unit) end
	elseif event == "UNIT_NAME_UPDATE" then
		local b = byUnit[unit] if b then RF:UpdateName(b, unit) end
	elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
		local b = byUnit[unit] if b then RF:UpdateBorder(b, unit) end
	elseif event == "PLAYER_TARGET_CHANGED" then
		for u, b in pairs(byUnit) do RF:UpdateBorder(b, u) end
	elseif event == "RAID_TARGET_UPDATE" or event == "PARTY_LEADER_CHANGED" or event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
		if event ~= "RAID_TARGET_UPDATE" then RF:CheckBracket() end
		for _, b in ipairs(buttons) do RF:UpdateAll(b) end
	elseif event == "READY_CHECK" or event == "READY_CHECK_CONFIRM" or event == "READY_CHECK_FINISHED" then
		for u, b in pairs(byUnit) do RF:UpdateReady(b, u) end
		if event == "READY_CHECK_FINISHED" then
			ns:After(6, function() for _, b in ipairs(buttons) do b.ready:Hide() end end)
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if pending then RF:Apply() else RF:CheckBracket() end
	end
end)

-- portée et états lents (hors ligne...) : vérification régulière
local acc = 0
events:SetScript("OnUpdate", function(_, el)
	acc = acc + el
	if acc < 0.25 then return end
	acc = 0
	for u, b in pairs(byUnit) do
		if b:IsVisible() then
			RF:UpdateRange(b, u)
			if not UnitIsConnected(u) or UnitIsDeadOrGhost(u) then RF:UpdateHealth(b, u) end
		end
	end
end)

----------------------------------------------------------------
-- Démarrage
----------------------------------------------------------------
function RF:Init()
	if not ns:ModuleEnabled("raid") then return end
	if anchor then return end
	local db = DB()
	EnsureLayouts()
	anchor = CreateFrame("Frame", "EasyUIRaidAnchor", UIParent)
	anchor:SetFrameStrata("LOW")
	self:LayoutAnchor()

	for g = 1, MAX_GROUPS do
		local h = CreateFrame("Frame", "EasyUIRaidGroup" .. g, anchor, "SecureGroupHeaderTemplate")
		h:SetAttribute("template", "EasyUIRaidButtonTemplate")
		h.initialConfigFunction = InitButton
		headers[g] = h
	end
	self:ConfigureHeaders()
	-- crée les 5 boutons de chaque groupe maintenant (hors combat)
	for g = 1, MAX_GROUPS do
		local h = headers[g]
		h:SetAttribute("startingIndex", -4)
		h:Show()
		h:SetAttribute("startingIndex", 1)
		if not db.enabled then h:Hide() end
	end

	for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_AURA", "UNIT_NAME_UPDATE", "UNIT_THREAT_SITUATION_UPDATE",
		"PLAYER_TARGET_CHANGED", "RAID_TARGET_UPDATE", "PARTY_LEADER_CHANGED", "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE",
		"READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED", "PLAYER_REGEN_ENABLED" }) do
		events:RegisterEvent(e)
	end
	for e in pairs(POWER_EVENTS) do pcall(events.RegisterEvent, events, e) end

	self:HideBlizzard()
	for _, b in ipairs(buttons) do self:UpdateAll(b) end

	-- déplaçable en mode édition
	-- position enregistrée dans la disposition affichée (groupe, raid 10, 25 ou 40)
	local m = ns:RegisterMover("raid", anchor, "Cadres de raid",
		function(point, relPoint, x, y)
			L().point = { point, relPoint, x, y }
		end, { page = "raid", keys = { "layout" } })
	self.mover = m
	m.text:SetJustifyH("CENTER")
	m:EnableMouseWheel(true)
	m:SetScript("OnMouseWheel", function(_, delta) RF:CyclePreview(delta) end)
	self:LayoutAnchor()
end

ns:On("LOGIN", function()
	if InCombatLockdown() then
		ns:On("COMBAT_END", function() RF:Init() end)
	else
		RF:Init()
	end
end)

-- en mode édition, l'aperçu montre la place occupée
ns:On("EDITMODE_CHANGED", function(on)
	if not anchor then return end
	if on and DB().enabled then
		RF.previewByEdit = not RF.previewShown
		if RF.previewByEdit then
			-- on part de la taille actuelle du groupe
			if GetNumRaidMembers() > 0 then DB().previewCount = BRACKET_SIZE[RealBracket()] end
			RF:ShowPreview(true)
		end
	elseif RF.previewByEdit then
		RF.previewByEdit = nil
		RF:ShowPreview(false)
	end
end)
