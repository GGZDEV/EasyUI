--[[
	EasyUI - Déplacement et aimantation (mode édition)
	Un seul moteur de glisser-déposer pour toutes les poignées : barres d'action,
	barres d'incantation, cadres Blizzard, cadres de raid...
	- aimantation aux bords et aux centres des autres éléments (bord à bord,
	  alignement à gauche / droite / haut / bas / centre)
	- aimantation au centre et aux bords de l'écran
	- lignes-guides pendant le déplacement (comme sur Canva)
	- grille en dernier recours ; Maj maintenue = déplacement libre
]]
local _, ns = ...

local Snap = {}
ns.Snap = Snap

local THRESHOLD = 10       -- distance d'aimantation (unités d'interface)
local items = {}           -- poignées connues : [handle] = item
local drag                 -- déplacement en cours

-- conversion vers le repère de UIParent
local function Rect(f)
	if not f or not f:IsVisible() then return end
	local l, b, w, h = f:GetLeft(), f:GetBottom(), f:GetWidth(), f:GetHeight()
	if not l then return end
	local k = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return l * k, b * k, w * k, h * k
end
Snap.Rect = Rect

-- place le coin bas-gauche d'un cadre aux coordonnées (x, y) de UIParent
function Snap.PlaceFrame(f, x, y, point)
	local k = UIParent:GetEffectiveScale() / f:GetEffectiveScale()
	f:ClearAllPoints()
	f:SetPoint(point or "BOTTOMLEFT", UIParent, "BOTTOMLEFT", x * k, y * k)
end

----------------------------------------------------------------
-- Lignes-guides
----------------------------------------------------------------
local guides
local function Guides()
	if guides then return guides end
	guides = CreateFrame("Frame", "EasyUISnapGuides", UIParent)
	guides:SetAllPoints(UIParent)
	guides:SetFrameStrata("TOOLTIP")
	guides:EnableMouse(false)
	local function line()
		local t = guides:CreateTexture(nil, "OVERLAY")
		t:SetTexture(ns.media.white)
		t:Hide()
		return t
	end
	guides.v, guides.h = line(), line()
	guides.label = ns:CreateText(guides, 12, ns.colors.text, nil, "LEFT")
	guides.label:SetFont(ns.media.font, 12 + (ns.fontBoost or 0), "OUTLINE")
	return guides
end

local function ShowGuide(t, vertical, pos)
	local r, g, b = ns:GetAccent()
	t:SetVertexColor(r, g, b, 0.9)
	t:ClearAllPoints()
	if vertical then
		t:SetWidth(1)
		t:SetPoint("TOP", guides, "TOPLEFT", pos, 0)
		t:SetPoint("BOTTOM", guides, "BOTTOMLEFT", pos, 0)
	else
		t:SetHeight(1)
		t:SetPoint("LEFT", guides, "BOTTOMLEFT", 0, pos)
		t:SetPoint("RIGHT", guides, "BOTTOMRIGHT", 0, pos)
	end
	t:Show()
end

----------------------------------------------------------------
-- Calcul de l'aimantation
----------------------------------------------------------------
-- cherche le meilleur décalage pour un axe
-- mine = { début, centre, fin } ; cibles = liste de { début, centre, fin }
local function BestOnAxis(mine, targets, screenSize)
	local bestD, bestShift, bestLine = THRESHOLD + 1
	local function try(myPos, targetPos)
		local d = math.abs(targetPos - myPos)
		if d < bestD then bestD, bestShift, bestLine = d, targetPos - myPos, targetPos end
	end
	for _, t in ipairs(targets) do
		local s, c, e = t[1], t[2], t[3]
		-- alignements (début, centre, fin)
		try(mine[1], s) try(mine[3], e) try(mine[2], c)
		try(mine[1], e) try(mine[3], s) -- bord à bord
	end
	-- écran : bords et centre
	try(mine[1], 0) try(mine[3], screenSize) try(mine[2], screenSize / 2)
	return bestShift, bestLine
end

local function Others(except)
	local xs, ys = {}, {}
	for handle, item in pairs(items) do
		if handle ~= except and handle:IsVisible() then
			local l, b, w, h = Rect(item.rect or handle)
			if l then
				xs[#xs + 1] = { l, l + w / 2, l + w }
				ys[#ys + 1] = { b, b + h / 2, b + h }
			end
		end
	end
	return xs, ys
end

local function GridSnap(v, center)
	local size = ns.db.grid.size or 32
	return center + math.floor((v - center) / size + 0.5) * size
end

----------------------------------------------------------------
-- Déplacement
----------------------------------------------------------------
local controller = CreateFrame("Frame")
controller:Hide()

local function CursorUI()
	local x, y = GetCursorPosition()
	local s = UIParent:GetEffectiveScale()
	return x / s, y / s
end

controller:SetScript("OnUpdate", function()
	if not drag then controller:Hide() return end
	if not IsMouseButtonDown("LeftButton") then Snap:Stop() return end
	local cx, cy = CursorUI()
	local x, y = cx - drag.dx, cy - drag.dy
	local w, h = drag.w, drag.h
	local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
	local g = Guides()
	g.v:Hide() g.h:Hide()

	if ns.db.editMode.snap ~= false and not IsShiftKeyDown() then
		local sx, lx = BestOnAxis({ x, x + w / 2, x + w }, drag.xs, sw)
		local sy, ly = BestOnAxis({ y, y + h / 2, y + h }, drag.ys, sh)
		if sx then x = x + sx ShowGuide(g.v, true, lx)
		elseif ns.db.grid.show then x = GridSnap(x, sw / 2) end
		if sy then y = y + sy ShowGuide(g.h, false, ly)
		elseif ns.db.grid.show then y = GridSnap(y, sh / 2) end
	end

	-- garde l'élément dans l'écran
	x = math.max(0, math.min(sw - w, x))
	y = math.max(0, math.min(sh - h, y))
	drag.x, drag.y = x, y
	drag.item.apply(x, y)

	g.label:ClearAllPoints()
	g.label:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", x, y + h + 4)
	g.label:SetText(("%d , %d"):format(x, y))
	g.label:Show()
	g:Show()
end)

function Snap:Start(handle)
	local item = items[handle]
	if not item or InCombatLockdown() then return false end
	if drag then self:Stop() end
	local l, b, w, h = Rect(item.rect or handle)
	if not l then return false end
	local cx, cy = CursorUI()
	drag = { item = item, handle = handle, dx = cx - l, dy = cy - b, w = w, h = h, x = l, y = b }
	drag.xs, drag.ys = Others(handle)
	if item.begin then item.begin() end
	controller:Show()
	return true
end

function Snap:Stop()
	local d = drag
	drag = nil
	controller:Hide()
	if guides then guides.v:Hide() guides.h:Hide() guides.label:Hide() end
	if d and d.item.finish then d.item.finish(d.x, d.y) end
	if d then Snap:Select(d.handle) end
end

function Snap:IsDragging(handle) return drag and drag.handle == handle end

-- item = { rect = cadre mesuré (défaut : la poignée), apply(x, y), finish(x, y), begin() }
function Snap:Register(handle, item)
	items[handle] = item
end

function Snap:Unregister(handle) items[handle] = nil end

----------------------------------------------------------------
-- Branchement sur les modules
----------------------------------------------------------------
-- Barres d'action : la poignée (overlay) est accrochée au coin d'ancrage de la barre
local function HookBartender()
	local bt = ns:GetAceAddon("Bartender4")
	if not (bt and bt.Bar and bt.Bar.barregistry) then return end
	for _, bar in pairs(bt.Bar.barregistry) do
		local o = bar.overlay
		if o and not o.arduiSnap then
			o.arduiSnap = true
			Snap:Register(o, {
				apply = function(x, y)
					local anchor = bar:GetAnchor()
					local _, _, w, h = Rect(o)
					local ax = anchor:find("RIGHT") and (x + w) or x
					local ay = anchor:find("TOP") and (y + h) or y
					Snap.PlaceFrame(bar, ax, ay, anchor)
				end,
				finish = function()
					bar:SavePosition()
					bar.isMoving = nil
				end,
				begin = function() bar.isMoving = true end,
			})
			o:SetScript("OnDragStart", function(self) Snap:Start(self) end)
			o:SetScript("OnDragStop", function(self) if Snap:IsDragging(self) then Snap:Stop() end end)
			-- clic droit : réglages de cette barre
			o:RegisterForClicks("AnyUp")
			o:SetScript("OnClick", function(_, button)
				if button == "RightButton" and bar.id then
					ns:OpenOptionsAt("bartender", { "bars", tostring(bar.id) })
				end
			end)
		end
	end
end

-- Barres d'incantation (joueur, cible, focus, familier)
local function HookQuartz()
	local q = ns:GetAceAddon("Quartz3")
	if not q then return end
	for _, mod in q:IterateModules() do
		local b = mod.Bar
		if b and b.config and b:IsShown() then
			if not b.arduiSnap then
				b.arduiSnap = true
				Snap:Register(b, {
					apply = function(x, y) Snap.PlaceFrame(b, x, y) end,
					finish = function()
						b.config.x = b:GetLeft()
						b.config.y = b:GetBottom()
					end,
				})
				-- clic droit : réglages de cette barre d'incantation
				local key = mod.moduleName or mod:GetName()
				b:HookScript("OnMouseUp", function(_, button)
					if button == "RightButton" and q.unlock then ns:OpenOptionsAt("quartz", { key }) end
				end)
			end
			-- Quartz remet ses propres scripts à chaque déverrouillage
			b:SetScript("OnDragStart", function(self) Snap:Start(self) end)
			b:SetScript("OnDragStop", function(self) if Snap:IsDragging(self) then Snap:Stop() end end)
		end
	end
end

-- Poignées des cadres Blizzard : on garde leur logique, on remplace le suivi de la souris
function Snap:HookMover(mover)
	if not mover or mover.arduiSnap then return end
	mover.arduiSnap = true
	Snap:Register(mover, {
		apply = function(x, y) Snap.PlaceFrame(mover, x, y) end,
	})
	local down, up = mover:GetScript("OnMouseDown"), mover:GetScript("OnMouseUp")
	mover:SetScript("OnMouseDown", function(self, button)
		if down then down(self, button) end
		if (button or GetMouseButtonClicked()) == "LeftButton" and self.tagged then
			self:StopMovingOrSizing()
			Snap:Start(self)
		end
	end)
	mover:SetScript("OnMouseUp", function(self, button)
		if Snap:IsDragging(self) then Snap:Stop() end
		-- en mode édition, clic droit = réglages du cadre (taille, transparence, masquage)
		if (button or GetMouseButtonClicked()) == "RightButton" and ns.editMode and self.tagged
			and not IsShiftKeyDown() and not IsControlKeyDown() and MovAny and MovAny.FrameEditor then
			ns.allowMAWindows = true
			MovAny:FrameEditor(self.tagged:GetName())
			return
		end
		if up then up(self, button) end
	end)
end

local function HookMovers()
	if MovAny and MovAny.movers then
		for _, m in pairs(MovAny.movers) do
			if m.tagged then Snap:HookMover(m) end
		end
	end
end

function Snap:HookAll()
	HookBartender()
	HookQuartz()
	HookMovers()
end

ns:On("EDITMODE_CHANGED", function(on)
	if on then
		-- après le déverrouillage des modules
		ns:After(0.1, function() Snap:HookAll() end)
	elseif drag then
		Snap:Stop()
	end
end)

ns:On("LOGIN", function()
	if MovAny and MovAny.AttachMoverToFrame then
		hooksecurefunc(MovAny, "AttachMoverToFrame", function(_, mover)
			if ns.editMode then Snap:HookMover(mover) end
		end)
	end
end)

----------------------------------------------------------------
-- Sélection : cadre doré, coordonnées au-dessus, panneau d'ajustement
-- (flèches : 1 px, Maj + flèche : 10 px ; X / Y saisissables)
----------------------------------------------------------------
local sel, nudge

local function Selected() return Snap.selected and items[Snap.selected] end

local function HandleRect(handle)
	local item = items[handle]
	if not item then return end
	return Rect(item.rect or handle)
end

-- déplace l'élément sélectionné à (x, y), comme à la fin d'un glisser
function Snap:MoveSelectedTo(x, y)
	local item = Selected()
	if not item or InCombatLockdown() then return end
	local l, b, w, h = HandleRect(self.selected)
	if not l then return end
	x = math.max(0, math.min(UIParent:GetWidth() - w, x))
	y = math.max(0, math.min(UIParent:GetHeight() - h, y))
	if item.begin then item.begin() end
	item.apply(x, y)
	if item.finish then item.finish(x, y) end
	self:UpdateSelection()
end

function Snap:Nudge(dx, dy)
	local l, b = HandleRect(self.selected or {})
	if not l then return end
	local step = IsShiftKeyDown() and 10 or 1
	self:MoveSelectedTo(math.floor(l + 0.5) + dx * step, math.floor(b + 0.5) + dy * step)
end

local function ArrowButton(parent, rot, label, dx, dy)
	local b = ns:CreateButton(parent, "", 22, 22, function() Snap:Nudge(dx, dy) end)
	local t = b:CreateTexture(nil, "OVERLAY")
	t:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
	t:SetSize(12, 12)
	t:SetPoint("CENTER", 0, -1)
	t:SetDesaturated(1)
	t:SetVertexColor(0.87, 0.87, 0.87, 1)
	if rot == "up" then t:SetTexCoord(0, 1, 1, 0)
	elseif rot == "left" then t:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
	elseif rot == "right" then t:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1) end
	ns:AttachTooltip(b, label, "Maj + clic : 10 px")
	return b
end

local function CoordBox(parent, label, axis)
	local fs = ns:CreateText(parent, 12, ns.colors.muted)
	fs:SetText(label)
	local e = ns:CreateEditBox(parent, 46, 22)
	ns:Font(e, 12)
	e:SetJustifyH("CENTER")
	e:SetTextInsets(2, 2, 0, 0)
	e:SetPoint("LEFT", fs, "RIGHT", 5, 0)
	e:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
		local v = tonumber((self:GetText() or ""):gsub(",", "."))
		local l, b = HandleRect(Snap.selected or {})
		if v and l then
			if axis == "x" then Snap:MoveSelectedTo(v, b) else Snap:MoveSelectedTo(l, v) end
		else
			Snap:UpdateSelection()
		end
	end)
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() Snap:UpdateSelection() end)
	fs.box = e
	return fs
end

local function BuildSelection()
	if sel then return end
	sel = CreateFrame("Frame", "EasyUISnapSelection", UIParent)
	sel:SetFrameStrata("FULLSCREEN")
	sel:EnableMouse(false)
	sel:SetBackdrop({ edgeFile = ns.media.white, edgeSize = 1 })
	sel.coords = sel:CreateFontString(nil, "OVERLAY")
	sel.coords:SetFont(ns.media.font, 12 + (ns.fontBoost or 0), "OUTLINE")
	sel.coords:SetPoint("BOTTOMLEFT", sel, "TOPLEFT", 0, 4)
	sel:Hide()

	local C = ns.colors
	nudge = CreateFrame("Frame", "EasyUINudge", UIParent)
	nudge:SetFrameStrata("FULLSCREEN_DIALOG")
	nudge:SetClampedToScreen(true)
	nudge:EnableMouse(true)
	nudge:SetSize(150, 62)
	ns:SetBackdrop(nudge, { C.bg[1], C.bg[2], C.bg[3], 1 }, { 0, 0, 0, 1 })
	local edge = CreateFrame("Frame", nil, nudge)
	edge:SetPoint("TOPLEFT", 1, -1)
	edge:SetPoint("BOTTOMRIGHT", -1, 1)
	edge:SetBackdrop({ edgeFile = ns.media.white, edgeSize = 1 })
	edge:SetBackdropBorderColor(C.frameEdge[1], C.frameEdge[2], C.frameEdge[3], 1)

	local up = ArrowButton(nudge, "up", "Monter", 0, 1)
	up:SetPoint("TOPLEFT", 32, -7)
	local left = ArrowButton(nudge, "left", "Gauche", -1, 0)
	left:SetPoint("TOPRIGHT", up, "BOTTOMLEFT", -2, -2)
	local down = ArrowButton(nudge, "down", "Descendre", 0, -1)
	down:SetPoint("TOP", up, "BOTTOM", 0, -2)
	local right = ArrowButton(nudge, "right", "Droite", 1, 0)
	right:SetPoint("TOPLEFT", up, "BOTTOMRIGHT", 2, -2)

	local x = CoordBox(nudge, "X", "x")
	x:SetPoint("TOPLEFT", 90, -12)
	local y = CoordBox(nudge, "Y", "y")
	y:SetPoint("TOPLEFT", x, "BOTTOMLEFT", 0, -15)
	nudge.x, nudge.y = x.box, y.box
	nudge:Hide()

	-- l'élément sélectionné peut bouger (glisser, molette...) : on suit
	sel:SetScript("OnUpdate", function(self, el)
		self.t = (self.t or 0) + el
		if self.t > 0.2 then self.t = 0 Snap:UpdateSelection() end
	end)
end

function Snap:UpdateSelection()
	local handle = self.selected
	local item = handle and items[handle]
	if not (item and ns.editMode and handle:IsVisible()) then
		if sel then sel:Hide() nudge:Hide() end
		return
	end
	BuildSelection()
	local l, b, w, h = Rect(item.rect or handle)
	if not l then sel:Hide() nudge:Hide() return end
	local r, g, bb = ns:GetAccent()
	sel:SetBackdropBorderColor(r, g, bb, 1)
	sel.coords:SetTextColor(r, g, bb, 1)
	sel:ClearAllPoints()
	sel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b)
	sel:SetSize(w, h)
	local cx, cy = math.floor(l + 0.5), math.floor(b + 0.5)
	sel.coords:SetText(("%d, %d"):format(cx, cy))
	sel:Show()
	if not nudge.x:HasFocus() then nudge.x:SetText(cx) end
	if not nudge.y:HasFocus() then nudge.y:SetText(cy) end
	nudge:ClearAllPoints()
	if l + w + 170 < UIParent:GetWidth() then
		nudge:SetPoint("LEFT", sel, "RIGHT", 10, 0)
	else
		nudge:SetPoint("RIGHT", sel, "LEFT", -10, 0)
	end
	nudge:Show()
end

function Snap:Select(handle)
	self.selected = handle
	self:UpdateSelection()
end

ns:On("EDITMODE_CHANGED", function(on) if not on then Snap:Select(nil) end end)
ns:On("COMBAT_START", function() Snap:Select(nil) end)
