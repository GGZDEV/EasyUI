--[[
	EasyUI - Mode édition
	Déverrouille d'un coup Bartender4, Quartz (et tout addon qui supporte
	CONFIGMODE_CALLBACKS), affiche une grille d'alignement et une barre d'outils.
]]
local _, ns = ...
local C = ns.colors

local grid, bar
local reopenHub, openedMoveAnything

----------------------------------------------------------------
-- Grille
----------------------------------------------------------------
local function BuildGrid()
	if not grid then
		grid = CreateFrame("Frame", "EasyUIGrid", UIParent)
		grid:SetAllPoints(UIParent)
		grid:SetFrameStrata("BACKGROUND")
		grid:EnableMouse(false)
		grid.lines = {}
		grid:Hide()
	end
	for _, l in ipairs(grid.lines) do l:Hide() end

	local size = ns.db.grid.size or 32
	local w, h = UIParent:GetWidth(), UIParent:GetHeight()
	local cx, cy = w / 2, h / 2
	local r, g, b = ns:GetAccent()
	local n = 0
	local function line(vertical, offset, center)
		n = n + 1
		local l = grid.lines[n]
		if not l then
			l = grid:CreateTexture(nil, "BACKGROUND")
			l:SetTexture(ns.media.white)
			grid.lines[n] = l
		end
		l:ClearAllPoints()
		if vertical then
			l:SetWidth(1)
			l:SetPoint("TOP", grid, "TOPLEFT", offset, 0)
			l:SetPoint("BOTTOM", grid, "BOTTOMLEFT", offset, 0)
		else
			l:SetHeight(1)
			l:SetPoint("LEFT", grid, "BOTTOMLEFT", 0, offset)
			l:SetPoint("RIGHT", grid, "BOTTOMRIGHT", 0, offset)
		end
		if center then
			l:SetVertexColor(r, g, b, 0.45)
		else
			l:SetVertexColor(1, 1, 1, 0.06)
		end
		l:Show()
	end

	line(true, cx, true)
	line(false, cy, true)
	local i = 1
	while cx + i * size < w do
		line(true, cx + i * size)
		line(true, cx - i * size)
		i = i + 1
	end
	i = 1
	while cy + i * size < h do
		line(false, cy + i * size)
		line(false, cy - i * size)
		i = i + 1
	end
end

-- voile sombre sous l'interface pendant le mode édition
local dim
local function Dim(show)
	if not dim then
		if not show then return end
		dim = CreateFrame("Frame", "EasyUIEditDim", UIParent)
		dim:SetAllPoints(UIParent)
		dim:SetFrameStrata("BACKGROUND")
		dim:SetFrameLevel(0)
		dim:EnableMouse(false)
		local t = dim:CreateTexture(nil, "BACKGROUND")
		t:SetAllPoints()
		t:SetTexture(ns.media.white)
		t:SetVertexColor(0, 0, 0, 0.4)
	end
	ns.SetShown(dim, show)
end

function ns:UpdateGrid()
	Dim(self.editMode)
	if not self.editMode then
		if grid then grid:Hide() end
		return
	end
	if self.db.grid.show then
		BuildGrid()
		grid:Show()
	elseif grid then
		grid:Hide()
	end
end

----------------------------------------------------------------
-- Cadres Blizzard rendus déplaçables en mode édition
-- (poignées de MoveAnything : glisser = déplacer, molette = transparence,
--  Ctrl + clic droit = options du cadre)
----------------------------------------------------------------
ns.editFrames = {
	{ "TargetFrameToT", "Cible de la cible" },
	{ "PartyMemberFrame1", "Groupe" },
	{ "MinimapCluster", "Minimap" },
	{ "WatchFrame", "Suivi des quêtes" },
	{ "PlayerBuffsMover", "Buffs" },
	{ "PlayerDebuffsMover", "Débuffs" },
	{ "TooltipMover", "Infobulle" },
	{ "DurabilityFrame", "Durabilité" },
	{ "VehicleSeatIndicator", "Siège de véhicule" },
	{ "WorldStateCaptureBar1", "Barre de capture" },
}

local attached = {}

local function CanAttach(fn)
	if not (MovAny and MovAny.AttachMover) then return false end
	if MovAny:GetMoverByFrameName(fn) then return false end
	if MovAny.NoMove and MovAny.NoMove[fn] then return false end
	local f = _G[fn]
	if not f and not (MovAny.lCreateBeforeInteract and MovAny.lCreateBeforeInteract[fn]) then return false end
	if MovAny.MoveOnlyWhenVisible and MovAny.MoveOnlyWhenVisible[fn] and not (f and f:IsShown()) then return false end
	-- pas de poignée sur un cadre caché (focus absent, pas de groupe...), sauf zones virtuelles (buffs, infobulle)
	local virtual = fn:find("Mover$") or (MovAny.lCreateBeforeInteract and MovAny.lCreateBeforeInteract[fn])
	if not virtual and not (f and f:IsShown()) then return false end
	if f and f.IsProtected and f:IsProtected() and InCombatLockdown() then return false end
	return true
end

local function AttachBlizzardMovers()
	local skip = ns.db.editMode.skipFrames
	for _, entry in ipairs(ns.editFrames) do
		local fn = entry[1]
		if not skip[fn] and CanAttach(fn) then
			local ok = pcall(MovAny.AttachMover, MovAny, fn)
			if ok and MovAny:GetMoverByFrameName(fn) then
				attached[fn] = true
			end
		end
	end
end

local function DetachBlizzardMovers()
	if not MovAny then return end
	for fn in pairs(attached) do
		pcall(MovAny.StopMoving, MovAny, fn)
	end
	wipe(attached)
end

----------------------------------------------------------------
-- Sacs (Bagnon) : on les affiche pour pouvoir les placer
----------------------------------------------------------------
local shownBags

local function ShowBags()
	local bagnon = ns:GetAceAddon("Bagnon")
	if not (bagnon and bagnon.ShowFrame) then return end
	local inv = bagnon:GetFrame("inventory")
	if not (inv and inv:IsShown()) then
		if bagnon:ShowFrame("inventory") then shownBags = true end
	end
end

local function HideBags()
	local bagnon = ns:GetAceAddon("Bagnon")
	if shownBags and bagnon then bagnon:HideFrame("inventory") end
	shownBags = nil
end

----------------------------------------------------------------
-- Barre d'outils
----------------------------------------------------------------
local function BuildBar()
	if bar then return bar end
	bar = CreateFrame("Frame", "EasyUIEditBar", UIParent)
	bar:SetSize(580, 74)
	bar:SetPoint("TOP", UIParent, "TOP", 0, -10)
	bar:SetFrameStrata("DIALOG")
	bar:SetClampedToScreen(true)
	bar:SetMovable(true)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", bar.StartMoving)
	bar:SetScript("OnDragStop", bar.StopMovingOrSizing)
	ns:SetBackdrop(bar, { C.bg[1], C.bg[2], C.bg[3], 1 }, { 0, 0, 0, 1 })
	local edge = CreateFrame("Frame", nil, bar)
	edge:SetPoint("TOPLEFT", 1, -1)
	edge:SetPoint("BOTTOMRIGHT", -1, 1)
	edge:SetBackdrop({ edgeFile = ns.media.white, edgeSize = 1 })
	edge:SetBackdropBorderColor(C.frameEdge[1], C.frameEdge[2], C.frameEdge[3], 1)

	-- 1re ligne : titre, aide, Terminer
	local title = ns:CreateText(bar, 15, C.text)
	title:SetPoint("TOPLEFT", 12, -15)
	ns:RegisterAccent(title, "text")
	title:SetText("Mode édition")

	local done = ns:CreateButton(bar, "Terminer", nil, 26, function() ns:SetEditMode(false) end, "accent")
	done:SetPoint("TOPRIGHT", -12, -10)

	local sub = ns:CreateText(bar, 12, C.muted)
	sub:SetPoint("LEFT", title, "RIGHT", 12, 0)
	sub:SetPoint("RIGHT", done, "LEFT", -10, 0)
	sub:SetText("Glisser pour déplacer  ·  clic droit : réglages  ·  Maj : sans aimantation")

	-- 2e ligne : options
	local row = CreateFrame("Frame", nil, bar)
	row:SetPoint("TOPLEFT", 12, -40)
	row:SetPoint("BOTTOMRIGHT", -12, 8)

	local gridCheck = ns:CreateCheck(row, "Grille",
		function() return ns.db.grid.show end,
		function(v) ns.db.grid.show = v ns:UpdateGrid() end)
	gridCheck:SetPoint("LEFT", 0, 0)
	bar.grid = gridCheck

	local SIZES = { 8, 16, 32, 64 }
	local size = ns:CreateDropdown(row, 70,
		function()
			local t, cur, found = {}, ns.db.grid.size, false
			for _, v in ipairs(SIZES) do
				t[#t + 1] = { value = v, text = v .. " px" }
				if v == cur then found = true end
			end
			if cur and not found then table.insert(t, 1, { value = cur, text = cur .. " px" }) end
			return t
		end,
		function() return ns.db.grid.size end,
		function(v) ns.db.grid.size = v ns:UpdateGrid() end)
	size:SetPoint("LEFT", gridCheck, "RIGHT", 2, 0)
	ns:AttachTooltip(size, "Taille de la grille", "Écart entre les lignes de la grille d'alignement.")
	bar.size = size

	local snap = ns:CreateCheck(row, "Aimantation",
		function() return ns.db.editMode.snap ~= false end,
		function(v) ns.db.editMode.snap = v end,
		"Aimante tout ce que tu déplaces aux bords et aux centres des autres éléments, et au centre / aux bords de l'écran, avec des lignes-guides.\nMaintiens Maj pour déplacer librement.")
	snap:SetPoint("LEFT", size, "RIGHT", 16, 0)
	bar.snap = snap

	local blizz = ns:CreateCheck(row, "Cadres Blizzard",
		function() return ns.db.editMode.blizzard end,
		function(v)
			ns.db.editMode.blizzard = v
			if v then AttachBlizzardMovers() ns:StyleMovers() else DetachBlizzardMovers() end
		end,
		"Poignées sur le joueur, la cible, la minimap, les buffs, le suivi de quêtes...\nGlisser : déplacer  -  Coins : redimensionner  -  Molette : transparence\nCtrl + clic droit : options du cadre  -  Clic droit : retirer la poignée.")
	blizz:SetPoint("LEFT", snap, "RIGHT", 16, 0)
	bar.blizz = blizz

	local bags = ns:CreateCheck(row, "Sacs",
		function() return ns.db.editMode.bagnon end,
		function(v)
			ns.db.editMode.bagnon = v
			if v then ShowBags() else HideBags() end
		end,
		"Affiche les sacs pour les placer (glisser par le titre).")
	bags:SetPoint("LEFT", blizz, "RIGHT", 16, 0)
	bar.bags = bags

	local more = ns:CreateButton(row, "Autres cadres…", nil, 26, function()
		if MovAny and MovAny.ToggleGUI then
			ns.allowMAWindows = true
			MovAny:ToggleGUI()
		end
	end)
	more:SetPoint("RIGHT", 0, 0)
	ns:AttachTooltip(more, "Autres cadres", "La liste complète des cadres déplaçables : toute l'interface Blizzard y est.")
	return bar
end

----------------------------------------------------------------
-- Activation
----------------------------------------------------------------
local function CallConfigMode(action)
	if type(CONFIGMODE_CALLBACKS) ~= "table" then return end
	for name, func in pairs(CONFIGMODE_CALLBACKS) do
		-- Quartz est géré directement plus bas
		if name ~= "Quartz3" then
			pcall(func, action)
		end
	end
end

function ns:SetEditMode(on)
	on = on and true or false
	if on and InCombatLockdown() then
		self:Print("Impossible d'activer le mode édition en combat.")
		return
	end
	if on == (self.editMode or false) then return end
	self.editMode = on

	local opts = self.db.editMode
	local bt = self:GetAceAddon("Bartender4")
	local q = self:GetAceAddon("Quartz3")

	if on then
		reopenHub = self.frame and self.frame:IsShown()
		if reopenHub then self.frame:Hide() end

		if bt and opts.bartender and bt.Unlock then
			bt:Unlock()
			if bt.HideUnlockDialog then bt:HideUnlockDialog() end
		end
		if q and opts.quartz and q.Unlock then q:Unlock(false) end
		CallConfigMode("ON")
		if opts.blizzard then AttachBlizzardMovers() end
		if ns.StyleMovers then ns:StyleMovers() end
		if opts.bagnon then ShowBags() end
		if opts.moveanything and MovAny and MAOptions and not MAOptions:IsShown() then
			MovAny:ToggleGUI()
			openedMoveAnything = true
		end

		BuildBar()
		bar.grid:Refresh()
		bar.size:Refresh()
		bar.snap:Refresh()
		bar.blizz:Refresh()
		bar.bags:Refresh()
		bar:Show()
		self:UpdateGrid()
		self:Print("Mode édition activé. |cffaaaaaa/eui edit|r ou « Terminer » pour verrouiller.")
	else
		if bt and bt.Lock then bt:Lock() end
		if q and q.Lock then q:Lock() end
		CallConfigMode("OFF")
		DetachBlizzardMovers()
		HideBags()
		if openedMoveAnything and MAOptions and MAOptions:IsShown() then MovAny:ToggleGUI() end
		openedMoveAnything = nil

		if bar then bar:Hide() end
		self:UpdateGrid()
		if reopenHub and not InCombatLockdown() then self:Open() end
		reopenHub = nil
		self:Print("Interface verrouillée.")
	end
	self:Fire("EDITMODE_CHANGED", on)
end

function ns:ToggleEditMode()
	self:SetEditMode(not self.editMode)
end

ns:On("COMBAT_START", function()
	if ns.editMode then
		reopenHub = nil
		ns:SetEditMode(false)
	end
end)

ns:On("ACCENT_CHANGED", function() if ns.editMode then ns:UpdateGrid() end end)

----------------------------------------------------------------
-- Poignées génériques pour les cadres propres à EasyUI
-- ns:RegisterMover(clé, cadre, libellé, onMoved(point, relPoint, x, y))
----------------------------------------------------------------
local movers = {}

function ns:RegisterMover(key, frame, label, onMoved, settings)
	local m = CreateFrame("Button", "EasyUIMover_" .. key, UIParent)
	m:SetFrameStrata("DIALOG")
	m:SetMovable(true)
	m:SetClampedToScreen(true)
	m:EnableMouse(true)
	m:RegisterForDrag("LeftButton")
	ns:SetBackdrop(m, { 0, 0, 0, 0 }, { 1, 1, 1, 1 })
	m.text = ns:CreateText(m, 12, { 0.94, 0.94, 0.94, 1 }, nil, "CENTER")
	ns:Font(m.text, 12, "OUTLINE")
	m.text:SetPoint("CENTER")
	m.text:SetText(label)
	m.coords = ns:CreateText(m, 10, { 0.66, 0.66, 0.66, 1 }, nil, "CENTER")
	m.coords:SetPoint("TOP", m.text, "BOTTOM", 0, -3)
	m:Hide()
	m.frame, m.onMoved = frame, onMoved
	if settings then
		m.active = settings.active   -- function() : la poignée doit-elle exister ?
		m.always = settings.always   -- affichée même si le cadre est caché (cible, focus...)
		m.begin = settings.begin
	end

	local function Paint(self, hover)
		ns:PaintHandle(self, hover)
	end
	m.Paint = Paint
	m:SetScript("OnEnter", function(self) Paint(self, true) end)
	m:SetScript("OnLeave", function(self) Paint(self, false) end)

	-- la poignée reste collée au cadre (SetAllPoints) : c'est le cadre qu'on déplace
	ns.Snap:Register(m, {
		begin = function() if m.begin then m.begin() end end,
		apply = function(x, y)
			ns.Snap.PlaceFrame(frame, x, y)
			m.coords:SetText(("%d , %d"):format(x, y))
		end,
		finish = function(x, y)
			-- enregistré en coin haut-gauche, dans l'échelle du cadre (comme UF:Place / RF:LayoutAnchor)
			local k = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
			local top = y + frame:GetHeight() / k
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x * k, top * k)
			m:ClearAllPoints()
			m:SetAllPoints(frame)
			if m.onMoved then m.onMoved("TOPLEFT", "BOTTOMLEFT", x * k, top * k) end
		end,
	})
	-- clic droit : réglages de l'élément
	if settings and settings.page then
		m:RegisterForClicks("RightButtonUp")
		m:SetScript("OnClick", function() ns:OpenOptionsAt(settings.page, settings.keys) end)
	end
	m:SetScript("OnDragStart", function(self) ns.Snap:Start(self) end)
	m:SetScript("OnDragStop", function(self) if ns.Snap:IsDragging(self) then ns.Snap:Stop() end end)
	movers[key] = m
	return m
end

local function ShowMovers(on)
	for _, m in pairs(movers) do
		local active = not m.active or m.active()
		if on and active and (m.always or m.frame:IsShown()) then
			m:ClearAllPoints()
			m:SetAllPoints(m.frame)
			m:Paint(false)
			local x, y = m.frame:GetLeft(), m.frame:GetTop()
			m.coords:SetText(x and ("%d , %d"):format(x, y) or "")
			m:Show()
		else
			m:Hide()
		end
	end
end

ns.ShowMovers = function(_, on) ShowMovers(on == nil and ns.editMode or on) end

----------------------------------------------------------------
-- Cadres d'unité Blizzard (joueur, cible, focus, familier) :
-- déplaçables en mode édition quand les cadres EasyUI ne les remplacent pas.
-- La position est aussi donnée à MoveAnything (qui la verrouille), sinon
-- gardée dans EasyUIDB.movers et réappliquée au chargement.
----------------------------------------------------------------
local BLIZZ_UNITS = {
	{ "PlayerFrame", "Joueur", "player" },
	{ "TargetFrame", "Cible", "target" },
	{ "FocusFrame", "Focus", "focus" },
	{ "PetFrame", "Familier", "pet" },
}

local function ReplacedByEasyUI(unit)
	local uf = ns.db.uf
	return ns:ModuleEnabled("unitframes") and uf and uf.enabled and uf.hideBlizzard
		and uf.units[unit] and uf.units[unit].enabled
end

local function MAOptions(fn)
	if MovAny and MovAny.GetFrameOptions and MovAny.frameOptions then
		return MovAny:GetFrameOptions(fn, nil, true)
	end
end

local function ApplySaved(fn)
	local f, pos = _G[fn], ns.db.movers[fn]
	if not (f and pos) or (f:IsProtected() and InCombatLockdown()) then return end
	if MovAny and MovAny.frameOptions then return end -- MoveAnything s'en charge
	f:ClearAllPoints()
	f:SetPoint(pos[1], UIParent, pos[3], pos[4], pos[5])
	if f.SetUserPlaced and f:IsMovable() then pcall(f.SetUserPlaced, f, true) end
end

ns:On("LOGIN", function()
	for _, e in ipairs(BLIZZ_UNITS) do
		local fn, label, unit = e[1], e[2], e[3]
		local f = _G[fn]
		if f then
			ns:RegisterMover("blizz_" .. fn, f, label .. " (Blizzard)",
				function(point, relPoint, x, y)
					local pos = { point, "UIParent", relPoint, x, y }
					ns.db.movers[fn] = pos
					local opt = MAOptions(fn)
					if opt then
						opt.pos = { point, "UIParent", relPoint, x, y }
						pcall(MovAny.ApplyPosition, MovAny, f, opt)
					end
				end,
				{
					active = function() return not ReplacedByEasyUI(unit) end,
					always = unit ~= "pet",
					-- MoveAnything verrouille la position : on la libère le temps du déplacement
					begin = function() if MovAny and MovAny.UnlockPoint then MovAny:UnlockPoint(f) end end,
				})
			ApplySaved(fn)
		end
	end
	if ns.editMode then ShowMovers(true) end
end)

local pew = CreateFrame("Frame")
pew:RegisterEvent("PLAYER_ENTERING_WORLD")
pew:SetScript("OnEvent", function()
	if not ns.db then return end
	for _, e in ipairs(BLIZZ_UNITS) do ApplySaved(e[1]) end
end)
ns:On("EDITMODE_CHANGED", function(on) ShowMovers(on) end)
ns:On("ACCENT_CHANGED", function() for _, m in pairs(movers) do if m:IsShown() then m:Paint(false) end end end)

----------------------------------------------------------------
-- En mode édition, la liste des cadres et le panneau d'ajustement de
-- MoveAnything restent fermés (sauf via le bouton « Autres cadres »)
----------------------------------------------------------------
local function KeepClosed(frame)
	if frame and not frame.arduiKeepClosed then
		frame.arduiKeepClosed = true
		frame:HookScript("OnShow", function(self)
			if ns.editMode and not ns.allowMAWindows then self:Hide() end
		end)
	end
end

ns:On("EDITMODE_CHANGED", function(on)
	KeepClosed(MANudger)
	KeepClosed(MAOptions)
	if on then
		ns.allowMAWindows = ns.db.editMode.moveanything and true or nil
		if not ns.allowMAWindows then
			if MANudger then MANudger:Hide() end
			if MAOptions and MAOptions:IsShown() then MAOptions:Hide() end
		end
	else
		ns.allowMAWindows = nil
		if MANudger and not (MAOptions and MAOptions:IsShown()) then MANudger:Hide() end
	end
end)
