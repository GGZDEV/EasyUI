--[[
	EasyUI - Thème
	- habillage moderne des boutons d'action, des fenêtres et des barres
	- styles prêts à l'emploi pour les barres d'incantation, les sacs et les temps de recharge
	- tout ce qui est visible porte le nom EasyUI (messages, raccourcis, fenêtres)
]]
local _, ns = ...
local C = ns.colors
local WHITE = ns.media.white

local LSM = ns:GetLib("LibSharedMedia-3.0")
if LSM then
	LSM:Register("statusbar", "EasyUI", WHITE)
	LSM:Register("border", "EasyUI", WHITE)
	LSM:Register("background", "EasyUI", WHITE)
	-- polices libres d'EasyUI, disponibles pour tous les modules
	for _, f in ipairs(ns.fonts) do
		if f.path:find("EasyUI", 1, true) then LSM:Register("font", f.name, f.path) end
	end
end

local function Flat(frame, bg, border)
	frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	if bg then frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1) end
	if border then frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1) end
end
ns.Flat = Flat

-- nom de la police EasyUI dans LibSharedMedia (pour les modules)
function ns:CurrentFontName()
	for _, f in ipairs(self.fonts) do
		if f.key == (self.db.font or ns.DEFAULT_FONT) and f.path:find("EasyUI", 1, true) then return f.name end
	end
	if (self.db.font or ns.DEFAULT_FONT) == "arialn" then return "Arial Narrow" end
	return "Friz Quadrata TT"
end

----------------------------------------------------------------
-- Styles prêts à l'emploi
----------------------------------------------------------------
function ns:ApplyQuartzTheme()
	local q = self:GetAceAddon("Quartz3")
	if not q then return end
	local p = q.db.profile
	p.bordercolor = { 0, 0, 0 }
	p.borderalpha = 1
	p.backgroundcolor = { 0.06, 0.06, 0.07 }
	p.backgroundalpha = 0.9
	for _, mod in q:IterateModules() do
		local mp = mod.db and mod.db.profile
		if mp then
			if mp.texture ~= nil then mp.texture = "EasyUI" end
			if mp.border ~= nil then mp.border = "EasyUI" end
			if mp.font ~= nil then mp.font = self:CurrentFontName() end
		end
	end
	q:ApplySettings()
	local ACR = self:GetLib("AceConfigRegistry-3.0")
	if ACR then ACR:NotifyChange("Quartz3") end
	self:Print("Style EasyUI appliqué aux barres d'incantation.")
end

function ns:ApplyBagnonTheme()
	local b = self:GetAceAddon("Bagnon")
	if not b then return end
	self.db.skin.bagnon = true
	for _, id in ipairs({ "inventory", "bank", "keys", "guildbank" }) do
		local fs = b.FrameSettings:Get(id)
		fs:SetColor(0.055, 0.058, 0.066, 0.95)
		fs:SetBorderColor(0, 0, 0, 1)
	end
	for _, frame in pairs(b.frames or {}) do self:SkinBagnonFrame(frame) end
	self:Print("Style EasyUI appliqué aux sacs.")
end

function ns:ApplyCooldownTheme()
	local o = _G.OmniCC
	if not o then return end
	o:SetFontFace(self.media.font)
	o:SetFontSize(18)
	o:SetFontOutline("OUTLINE")
	o:SetScaleText(true)
	o:SetPeriodColor("soon", 1, 0.32, 0.32, 1)
	o:SetPeriodScale("soon", 1.3)
	o:SetPeriodColor("seconds", 1, 0.86, 0.4, 1)
	o:SetPeriodColor("minutes", 1, 1, 1, 1)
	o:SetPeriodColor("hours", 0.7, 0.72, 0.78, 1)
	o:SetEffect("shine")
	self:Print("Style EasyUI appliqué aux temps de recharge.")
end

----------------------------------------------------------------
-- Fenêtres des sacs : fond plat et bordure fine
----------------------------------------------------------------
function ns:SkinBagnonFrame(frame)
	if not (frame and frame.SetBackdrop and self.db.skin.bagnon) then return end
	Flat(frame)
	if frame.UpdateBackdrop then frame:UpdateBackdrop() end
	if frame.UpdateBackdropBorder then frame:UpdateBackdropBorder() end
end

----------------------------------------------------------------
-- Boutons d'action : icônes rognées, bordure fine, états colorés
----------------------------------------------------------------
local skinned = {}

local function SkinButton(button)
	if not button or skinned[button] or InCombatLockdown() then return end
	local name = button:GetName()
	if not name then return end
	skinned[button] = true

	local icon = button.icon or _G[name .. "Icon"]
	if icon then
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", 1, -1)
		icon:SetPoint("BOTTOMRIGHT", -1, 1)
	end

	-- cadre d'origine invisible
	local nt = button.normalTexture or button:GetNormalTexture()
	if nt then nt:SetAlpha(0) end
	local nt2 = _G[name .. "NormalTexture"] or _G[name .. "NormalTexture2"]
	if nt2 then nt2:SetAlpha(0) end

	-- fond + bordure
	local bd = CreateFrame("Frame", nil, button)
	bd:SetPoint("TOPLEFT", -1, 1)
	bd:SetPoint("BOTTOMRIGHT", 1, -1)
	bd:SetFrameLevel(math.max(0, button:GetFrameLevel() - 1))
	Flat(bd, { 0.05, 0.05, 0.06, 0.85 }, { 0, 0, 0, 1 })
	button.arduiBackdrop = bd

	local r, g, b = ns:GetAccent()
	local function state(tex, cr, cg, cb, a)
		if not tex then return end
		tex:SetTexture(WHITE)
		tex:SetVertexColor(cr, cg, cb, a)
		tex:ClearAllPoints()
		tex:SetPoint("TOPLEFT", 1, -1)
		tex:SetPoint("BOTTOMRIGHT", -1, 1)
	end
	state(button:GetHighlightTexture(), 1, 1, 1, 0.15)
	state(button:GetPushedTexture(), r, g, b, 0.35)
	if button.GetCheckedTexture then state(button:GetCheckedTexture(), r, g, b, 0.3) end

	-- textes lisibles
	local hotkey = _G[name .. "HotKey"]
	if hotkey then
		hotkey:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
		hotkey:ClearAllPoints()
		hotkey:SetPoint("TOPRIGHT", -2, -3)
	end
	local count = _G[name .. "Count"]
	if count then
		count:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
		count:ClearAllPoints()
		count:SetPoint("BOTTOMRIGHT", -2, 3)
	end
	local macro = _G[name .. "Name"]
	if macro then macro:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE") end

	local border = _G[name .. "Border"]
	if border then border:SetAlpha(0) end
	local flash = _G[name .. "Flash"]
	if flash then
		flash:SetTexture(WHITE)
		flash:SetVertexColor(1, 0.2, 0.2, 0.35)
	end
end

local function Each(func)
	for i = 1, 120 do func(_G["BT4Button" .. i]) end
	for i = 1, 10 do func(_G["BT4PetButton" .. i]) end
	for i = 1, 10 do func(_G["BT4StanceButton" .. i]) end
end

-- la disposition des barres remet le cadrage d'origine des icônes : on le corrige
local function Recrop(button)
	if button and skinned[button] then
		local icon = button.icon or _G[button:GetName() .. "Icon"]
		if icon then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
	end
end

function ns:SkinActionButtons()
	if not self.db.skin.buttons then return end
	Each(SkinButton)
	Each(Recrop)
end

----------------------------------------------------------------
-- Fenêtres des modules (liste des cadres, click-casting...)
----------------------------------------------------------------
function ns:SkinWindow(frame, title)
	if not frame or frame.arduiSkinned then return end
	frame.arduiSkinned = true
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:GetObjectType() == "Texture" then
			local layer = region:GetDrawLayer()
			if layer == "BACKGROUND" or layer == "BORDER" or layer == "ARTWORK" or layer == "OVERLAY" then
				local tex = region:GetTexture()
				-- on garde les icônes / portraits
				if not (type(tex) == "string" and tex:lower():find("icons")) then
					region:SetAlpha(0)
				end
			end
		end
	end
	Flat(frame, C.bg, C.border)
	ns:RegisterAccent(frame, "border", 0.6)
	if title then
		local fs = ns:CreateText(frame, 13, C.text)
		fs:SetPoint("TOPLEFT", 12, -10)
		fs:SetText(("|cffffffffEasyUI|r  |cff8c8c8c%s|r"):format(title))
		frame.arduiTitle = fs
	end
end

----------------------------------------------------------------
-- Poignées du mode édition : même look partout
-- (fond sombre translucide, bordure blanche fine, bordure dorée au survol)
----------------------------------------------------------------
function ns:PaintHandle(frame, hover)
	frame:SetBackdropColor(0.03, 0.04, 0.03, 0.62)
	if hover then
		local r, g, b = ns:GetAccent()
		frame:SetBackdropBorderColor(r, g, b, 0.6)
	else
		frame:SetBackdropBorderColor(1, 1, 1, 0.22)
	end
end

local function AccentHandle(frame, label)
	Flat(frame)
	ns:PaintHandle(frame, false)
	if label then
		ns:Font(label, 12, "OUTLINE")
		label:SetTextColor(0.94, 0.94, 0.94, 1)
	end
end

function ns:StyleMovers()
	-- barres d'action
	local bt = self:GetAceAddon("Bartender4")
	if bt and bt.Bar and bt.Bar.barregistry then
		for _, bar in pairs(bt.Bar.barregistry) do
			local o = bar.overlay
			if o then
				AccentHandle(o, o.Text)
				if not o.arduiHooked then
					o.arduiHooked = true
					o:SetScript("OnEnter", function(self) ns:PaintHandle(self, true) end)
					o:SetScript("OnLeave", function(self) ns:PaintHandle(self, false) end)
				end
			end
		end
	end
	-- cadres Blizzard
	if MovAny and MovAny.movers then
		for _, mover in pairs(MovAny.movers) do self:StyleMover(mover) end
	end
end

function ns:StyleMover(mover)
	if not (mover and mover.GetName and mover:GetName()) then return end
	local bd = _G[mover:GetName() .. "Backdrop"]
	if bd then
		AccentHandle(bd, _G[bd:GetName() .. "MovingFrameName"])
		if not mover.arduiHooked then
			mover.arduiHooked = true
			-- MoveAnything recolore la poignée au survol : on réapplique notre style
			mover:HookScript("OnEnter", function() ns:PaintHandle(bd, true) end)
			mover:HookScript("OnLeave", function() ns:PaintHandle(bd, false) end)
		end
	end
end

----------------------------------------------------------------
-- Tout au nom d'EasyUI
----------------------------------------------------------------
-- en-têtes du menu des raccourcis clavier
BINDING_HEADER_Bartender4 = "EasyUI - Barres d'action"
BINDING_HEADER_BAGNON = "EasyUI - Sacs"
BINDING_HEADER_MOVEANYTHING = "EasyUI - Cadres"
BINDING_HEADER_SexyMap = "EasyUI - Minimap"
BINDING_NAME_TOGGLESEXYMAPGATHERMAP = "Carte HUD (récolte)"
_G["BINDING_NAME_Toggle MA window"] = "Liste des cadres"
_G["BINDING_NAME_Move frame - Safe"] = "Déplacer le cadre sous la souris"
_G["BINDING_NAME_Hide frame - Safe"] = "Masquer le cadre sous la souris"
_G["BINDING_NAME_Reset frame - Safe"] = "Réinitialiser le cadre sous la souris"
_G["BINDING_NAME_Move frame - Exact"] = "Déplacer le cadre exact sous la souris"
_G["BINDING_NAME_Hide frame - Exact"] = "Masquer le cadre exact sous la souris"
_G["BINDING_NAME_Reset frame - Exact"] = "Réinitialiser le cadre exact sous la souris"
_G["BINDING_NAME_Update positions"] = "Réappliquer les positions des cadres"
_G["BINDING_NAME_Show frame info"] = "Infos du cadre sous la souris"

-- messages dans le chat
local function Relay(_, ...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
	ns:Print(ns:Brand(table.concat(parts, " ")))
end

maPrint = function(msgKey, msgHighlight, msgAdditional)
	if msgKey == "" then return end
	local text = tostring(msgKey or "")
	if msgHighlight and msgHighlight ~= "" and msgHighlight ~= " " then text = text .. " |cffaaddff" .. msgHighlight .. "|r" end
	if msgAdditional and msgAdditional ~= " " then text = text .. tostring(msgAdditional) end
	ns:Print(ns:Brand(text))
end

ns:On("LOGIN", function()
	for _, name in ipairs({ "Bartender4", "Quartz3", "Bagnon", "Postal", "SexyMap" }) do
		local a = ns:GetAceAddon(name)
		if a then a.Print = Relay end
	end
	local cq = _G.EasyUI_CliqueAddon or _G.Clique
	if cq then
		cq.Print = Relay
		cq.Printf = function(_, msg, ...)
			local ok, txt = pcall(string.format, msg, ...)
			ns:Print(ns:Brand(ok and txt or tostring(msg)))
		end
	end

	-- compteur de dégâts : messages au nom d'EasyUI, pas d'icône minimap en double
	local details = _G.Details
	if details then
		details.Msg = function(_, str, ...)
			local parts = { tostring(str or "") }
			for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
			ns:Print(ns:Brand(table.concat(parts, " ")))
		end
		ns:After(6, function()
			if ns.db.hideAddonMinimapIcons and details.minimap then
				details.minimap.hide = true
				local LDBIcon = ns:GetLib("LibDBIcon-1.0")
				if LDBIcon then pcall(LDBIcon.Hide, LDBIcon, "Details") end
			end
		end)
	end

	-- pas de fenêtres de déverrouillage séparées : la barre du mode édition les remplace
	local bt = ns:GetAceAddon("Bartender4")
	if bt then bt.ShowUnlockDialog = function() end end
	local q = ns:GetAceAddon("Quartz3")
	if q then q.ShowUnlockDialog = function() end end

	-- sacs
	local bagnon = ns:GetAceAddon("Bagnon")
	if bagnon and bagnon.CreateFrame then
		hooksecurefunc(bagnon, "CreateFrame", function(self)
			ns:SkinBagnonFrame(self.frames[#self.frames])
		end)
	end

	-- boutons d'action (et ceux créés plus tard quand on change le nombre de boutons)
	ns:After(1, function() ns:SkinActionButtons() end)
	local proto = bt and bt.ButtonBar and bt.ButtonBar.prototype
	if proto and proto.UpdateButtonLayout then
		hooksecurefunc(proto, "UpdateButtonLayout", function() ns:After(0.1, function() ns:SkinActionButtons() end) end)
	end

	-- nouvelles poignées de cadres
	if MovAny and MovAny.AttachMoverToFrame then
		hooksecurefunc(MovAny, "AttachMoverToFrame", function(_, mover) ns:StyleMover(mover) end)
	end

	-- fenêtres des modules
	if not ns.db.skin.windows then return end
	if MAOptions then
		MAOptions:HookScript("OnShow", function(self) ns:SkinWindow(self) end)
		local cap = _G.MAOptionsCaption
		if cap then cap:SetText("EasyUI - Cadres") end
	end
	if MANudger then MANudger:HookScript("OnShow", function(self) ns:SkinWindow(self) end) end
	if CliqueConfig then CliqueConfig:HookScript("OnShow", function(self) ns:SkinWindow(self) end) end
end)

-- les boutons créés hors combat sont rattrapés à la sortie du combat
ns:On("COMBAT_END", function() ns:SkinActionButtons() end)
