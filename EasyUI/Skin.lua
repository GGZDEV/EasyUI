--[[
	EasyUI - Skin
	Bibliothèque de widgets : fond sombre légèrement chaud, bordures blanches
	très transparentes, textes blancs atténués, interrupteurs en pilule,
	police condensée.
]]
local _, ns = ...

local MEDIA = "Interface\\AddOns\\EasyUI\\Media\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"

ns.media = {
	white = WHITE,
	pill = MEDIA .. "Textures\\pill",
	circle = MEDIA .. "Textures\\circle",
	ring = MEDIA .. "Textures\\ring",
	rounded = MEDIA .. "Textures\\rounded",
	font = MEDIA .. "Fonts\\BarlowCondensed.ttf",
	fontAlt = MEDIA .. "Fonts\\BarlowCondensed.ttf",
}

-- Polices proposées (licences libres, voir Media\Fonts\LICENCES.txt)
-- boost : points ajoutés pour compenser les polices étroites
ns.fonts = {
	{ key = "barlow", name = "Barlow Condensed", path = MEDIA .. "Fonts\\BarlowCondensed.ttf", boost = 2 },
	{ key = "fira", name = "Fira Sans", path = MEDIA .. "Fonts\\FiraSansMedium.ttf", boost = 0 },
	{ key = "poppins", name = "Poppins", path = MEDIA .. "Fonts\\Poppins.ttf", boost = 0 },
	{ key = "ubuntu", name = "Ubuntu", path = MEDIA .. "Fonts\\Ubuntu.ttf", boost = 0 },
	{ key = "changa", name = "Changa", path = MEDIA .. "Fonts\\Changa.ttf", boost = 0 },
	{ key = "russo", name = "Russo One", path = MEDIA .. "Fonts\\RussoOne.ttf", boost = -1 },
	{ key = "friz", name = "Friz Quadrata (Blizzard)", path = "Fonts\\FRIZQT__.TTF", boost = 0 },
	{ key = "arialn", name = "Arial Narrow (Blizzard)", path = "Fonts\\ARIALN.TTF", boost = 2 },
}
-- police étroite par défaut, comme la maquette
ns.DEFAULT_FONT = "arialn"
ns.media.font, ns.media.fontAlt = "Fonts\\ARIALN.TTF", "Fonts\\ARIALN.TTF"
ns.fontBoost = 2

function ns:ApplyFontChoice()
	local key = self.db and self.db.font or ns.DEFAULT_FONT
	for _, f in ipairs(self.fonts) do
		if f.key == key then
			self.media.font, self.media.fontAlt, self.fontBoost = f.path, f.path, f.boost
			return
		end
	end
end
ns:On("ADDON_LOADED", function(name) if name == ns.name then ns:ApplyFontChoice() end end)

-- Applique la police EasyUI à une FontString
function ns:Font(fs, size, flags)
	if not fs:SetFont(self.media.font, (size or 12) + self.fontBoost, flags or "") then
		fs:SetFont("Fonts\\FRIZQT__.TTF", size or 12, flags or "")
	end
end

-- Palette : gris très sombres, bordures nettes, texte clair, accent or
ns.colors = {
	bg      = { 0.059, 0.059, 0.063, 0.98 }, -- fond de fenêtre
	sidebar = { 0.059, 0.059, 0.063, 1 },
	footer  = { 0.043, 0.043, 0.047, 1 },
	inset   = { 0.039, 0.039, 0.043, 1 },    -- encart (aperçu)
	insetBorder = { 0.122, 0.122, 0.133, 1 },
	panel   = { 0.000, 0.000, 0.000, 0.18 },
	panel2  = { 0.020, 0.020, 0.020, 1 },    -- champs (fond quasi noir)
	field   = { 0.020, 0.020, 0.020, 1 },
	fieldBorder = { 0.231, 0.231, 0.243, 1 },
	button  = { 0.106, 0.106, 0.114, 1 },
	border  = { 0.231, 0.231, 0.243, 1 },
	frameEdge = { 0.169, 0.169, 0.176, 1 }, -- liseré intérieur de la fenêtre
	line    = { 0.133, 0.133, 0.145, 1 },   -- séparateurs de la fenêtre
	rule    = { 0.165, 0.165, 0.176, 1 },   -- sous les titres de section
	hover   = { 0.094, 0.094, 0.102, 1 },
	subSel  = { 0.114, 0.114, 0.125, 1 },
	text    = { 0.90, 0.90, 0.90, 1 },
	bright  = { 0.94, 0.94, 0.94, 1 },
	nav     = { 0.84, 0.84, 0.84, 1 },
	soft    = { 0.74, 0.74, 0.74, 1 },
	muted   = { 0.55, 0.55, 0.55, 1 },
	dim     = { 0.49, 0.49, 0.49, 1 },
	section = { 0.49, 0.49, 0.49, 1 },
	checkBorder = { 0.314, 0.314, 0.329, 1 },
	good    = { 0.30, 0.85, 0.40, 1 },
	warn    = { 1.00, 0.75, 0.25, 1 },
	bad     = { 0.95, 0.30, 0.30, 1 },
	toggleOff = { 0.267, 0.267, 0.267, 0.65 },
}
local C = ns.colors

-- teinte d'accent mêlée au fond (sélection, bordures dorées discrètes)
function ns:AccentMix(k)
	local r, g, b = self:GetAccent()
	return 0.06 + r * k, 0.06 + g * k, 0.06 + b * k
end

local function SetTextColor(fs, c, a)
	fs:SetTextColor(c[1], c[2], c[3], a or c[4] or 1)
end
ns.SetTextColorC = SetTextColor

----------------------------------------------------------------
-- Couleur d'accent : registre d'objets à recolorer
----------------------------------------------------------------
local accentObjects = {}

function ns:RegisterAccent(obj, kind, alpha)
	table.insert(accentObjects, { obj = obj, kind = kind, alpha = alpha or 1 })
	self:ApplyAccentTo(accentObjects[#accentObjects])
end

function ns:ApplyAccentTo(entry)
	local r, g, b = self:GetAccent()
	local obj, a = entry.obj, entry.alpha
	if entry.kind == "tex" then
		obj:SetVertexColor(r, g, b, a)
	elseif entry.kind == "text" then
		obj:SetTextColor(r, g, b, a)
	elseif entry.kind == "border" then
		obj:SetBackdropBorderColor(r, g, b, a)
	elseif entry.kind == "bg" then
		obj:SetBackdropColor(r, g, b, a)
	elseif entry.kind == "gradient" then
		-- dégradé horizontal : accent -> transparent
		obj:SetGradientAlpha("HORIZONTAL", r, g, b, a, r, g, b, 0)
	elseif type(entry.kind) == "function" then
		entry.kind(obj, r, g, b)
	end
end

function ns:UpdateAccent()
	for _, entry in ipairs(accentObjects) do
		self:ApplyAccentTo(entry)
	end
	self:Fire("ACCENT_CHANGED")
end

function ns:AccentHex()
	local r, g, b = self:GetAccent()
	return ("%02x%02x%02x"):format(r * 255, g * 255, b * 255)
end

----------------------------------------------------------------
-- Bases
----------------------------------------------------------------
function ns:SetBackdrop(frame, bg, border)
	frame:SetBackdrop({
		bgFile = WHITE, edgeFile = WHITE, edgeSize = 1,
		insets = { left = 0, right = 0, top = 0, bottom = 0 },
	})
	bg = bg or C.panel
	border = border or C.border
	frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
	frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
end

function ns:CreateTex(parent, layer, color, texture)
	local t = parent:CreateTexture(nil, layer or "ARTWORK")
	t:SetTexture(texture or WHITE)
	if color then t:SetVertexColor(color[1], color[2], color[3], color[4] or 1) end
	return t
end

-- font : chemin facultatif (sinon police EasyUI)
function ns:CreateText(parent, size, color, font, justify, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	if font and font ~= self.media.font and font ~= self.media.fontAlt then
		fs:SetFont(font, size or 12)
	else
		self:Font(fs, size or 12)
	end
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, 0.6)
	SetTextColor(fs, color or C.text)
	fs:SetJustifyH(justify or "LEFT")
	return fs
end

function ns:CreatePanel(parent, bg)
	local f = CreateFrame("Frame", nil, parent)
	self:SetBackdrop(f, bg or C.panel)
	return f
end

-- Ligne de séparation horizontale
function ns:CreateLine(parent)
	local l = self:CreateTex(parent, "ARTWORK", C.line)
	l:SetHeight(1)
	return l
end

-- Titre de section : texte doré + filet en dessous
-- note (facultatif) : petit texte gris aligné à droite
function ns:CreateHeader(parent, text, size)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetHeight(30)
	local fs = self:CreateText(holder, size or 14, C.text)
	fs:SetPoint("BOTTOMLEFT", 0, 7)
	fs:SetText(text or "")
	self:RegisterAccent(fs, "text")
	holder.text = fs
	local note = self:CreateText(holder, 12, C.muted, nil, "RIGHT")
	note:SetPoint("BOTTOMRIGHT", 0, 8)
	holder.note = note
	local line = self:CreateTex(holder, "ARTWORK", C.rule)
	line:SetHeight(1)
	line:SetPoint("BOTTOMLEFT", 0, 0)
	line:SetPoint("BOTTOMRIGHT", 0, 0)
	return holder
end

----------------------------------------------------------------
-- Infobulle
----------------------------------------------------------------
function ns:AttachTooltip(frame, title, body)
	frame:HookScript("OnEnter", function(self)
		if not title then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(type(title) == "function" and title() or title, 1, 1, 1)
		local text = type(body) == "function" and body() or body
		if text then GameTooltip:AddLine(text, nil, nil, nil, true) end
		GameTooltip:Show()
	end)
	frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

----------------------------------------------------------------
-- Bouton
----------------------------------------------------------------
-- style : "normal" | "accent" | "danger" | "ghost"
-- fond gris foncé, bordure grise ; survol = bordure dorée sombre ;
-- "accent" = texte doré et bordure dorée sombre (action principale)
local function ButtonColors(b, hover)
	local s = b.style
	if not b:IsEnabled() or b:IsEnabled() == 0 then
		b:SetBackdropColor(C.button[1], C.button[2], C.button[3], 0.6)
		b:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.5)
		b.text:SetTextColor(1, 1, 1, 0.25)
		return
	end
	local hr, hg, hb = ns:AccentMix(0.48)
	if s == "accent" then
		local r, g, bb = ns:GetAccent()
		local br, bg, bbb = ns:AccentMix(0.36)
		b:SetBackdropColor(C.button[1], C.button[2], C.button[3], 1)
		if hover then b:SetBackdropBorderColor(hr, hg, hb, 1) else b:SetBackdropBorderColor(br, bg, bbb, 1) end
		b.text:SetTextColor(r, g, bb, 1)
	elseif s == "danger" then
		b:SetBackdropColor(C.button[1], C.button[2], C.button[3], 1)
		b:SetBackdropBorderColor(0.55, 0.18, 0.18, hover and 1 or 0.8)
		b.text:SetTextColor(1, 0.45, 0.45, 1)
	elseif s == "ghost" then
		b:SetBackdropColor(C.button[1], C.button[2], C.button[3], hover and 1 or 0)
		if hover then b:SetBackdropBorderColor(hr, hg, hb, 1) else b:SetBackdropBorderColor(0, 0, 0, 0) end
		b.text:SetTextColor(0.74, 0.74, 0.74, 1)
	else
		b:SetBackdropColor(C.button[1], C.button[2], C.button[3], 1)
		if hover then b:SetBackdropBorderColor(hr, hg, hb, 1) else b:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1) end
		if hover then b.text:SetTextColor(1, 1, 1, 1) else ns.SetTextColorC(b.text, C.text) end
	end
end

-- largeur nil = ajustée au texte
function ns:CreateButton(parent, text, width, height, onClick, style)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width or 120, height or 28)
	b.style = style or "normal"
	self:SetBackdrop(b, C.button, C.border)

	local fs = self:CreateText(b, (height or 28) <= 24 and 12 or 13, C.text, nil, "CENTER")
	fs:SetShadowColor(0, 0, 0, 0)
	fs:SetPoint("CENTER", 0, 0)
	fs:SetText(text)
	b.text = fs
	b.autoWidth = not width
	if not width then b:SetWidth(math.floor(fs:GetStringWidth() + 30)) end

	b:SetScript("OnEnter", function(self) self.hover = true ButtonColors(self, true) end)
	b:SetScript("OnLeave", function(self) self.hover = nil ButtonColors(self, false) end)
	b:SetScript("OnMouseDown", function(self) if self:IsEnabled() == 1 then self.text:SetPoint("CENTER", 1, -1) end end)
	b:SetScript("OnMouseUp", function(self) self.text:SetPoint("CENTER", 0, 0) end)
	if onClick then b:SetScript("OnClick", onClick) end

	local baseEnable, baseDisable = b.Enable, b.Disable
	function b:Enable() baseEnable(self) ButtonColors(self, self.hover) end
	function b:Disable() baseDisable(self) ButtonColors(self, false) end
	function b:SetLabel(t)
		self.text:SetText(t)
		if self.autoWidth then self:SetWidth(math.floor(self.text:GetStringWidth() + 30)) end
	end
	function b:SetStyle(s) self.style = s ButtonColors(self, self.hover) end

	ButtonColors(b, false)
	ns:On("ACCENT_CHANGED", function() ButtonColors(b, b.hover) end)
	return b
end

----------------------------------------------------------------
-- Interrupteur (pilule)
----------------------------------------------------------------
-- Case à cocher carrée : fond noir, bordure grise, coche dorée
-- (nom CreateSwitch gardé : le moteur d'options l'utilise)
local CHECK = "Interface\\Buttons\\UI-CheckBox-Check"
function ns:CreateSwitch(parent)
	local sw = CreateFrame("Frame", nil, parent)
	sw:SetSize(16, 16)
	ns:SetBackdrop(sw, C.field, C.checkBorder)
	sw.mark = sw:CreateTexture(nil, "OVERLAY")
	sw.mark:SetTexture(CHECK)
	sw.mark:SetSize(22, 22)
	sw.mark:SetPoint("CENTER", 1, 1)
	sw.mark:SetDesaturated(1)
	sw.half = self:CreateTex(sw, "ARTWORK")
	sw.half:SetPoint("TOPLEFT", 4, -4)
	sw.half:SetPoint("BOTTOMRIGHT", -4, 4)
	function sw:SetValue(on, middle)
		local r, g, b = ns:GetAccent()
		-- la coche désaturée est grise : on la ramène vers l'accent
		self.mark:SetVertexColor(math.min(1, r * 1.25), math.min(1, g * 1.25), math.min(1, b * 1.25), 1)
		self.half:SetVertexColor(r, g, b, 0.8)
		ns.SetShown(self.mark, on)
		ns.SetShown(self.half, not on and middle)
	end
	sw:SetValue(false)
	return sw
end

function ns:CreateCheck(parent, label, get, set, tooltip)
	local f = CreateFrame("Button", nil, parent)
	f:SetHeight(26)

	local sw = self:CreateSwitch(f)
	sw:SetPoint("LEFT", 0, 0)
	f.box = sw

	local fs = self:CreateText(f, 13, C.text)
	fs:SetPoint("LEFT", sw, "RIGHT", 8, 0)
	fs:SetText(label)
	f.text = fs
	f:SetWidth(math.max(40, 26 + (fs:GetStringWidth() or 100)))
	f:SetScript("OnEnter", function() sw:SetBackdropBorderColor(ns:AccentMix(0.48)) end)
	f:SetScript("OnLeave", function() sw:SetBackdropBorderColor(C.checkBorder[1], C.checkBorder[2], C.checkBorder[3], 1) end)

	function f:Refresh()
		local on = get and get()
		self.checked = on and true or false
		sw:SetValue(self.checked)
	end

	f:SetScript("OnClick", function(self)
		PlaySound("igMainMenuOptionCheckBoxOn")
		if set then set(not self.checked) end
		self:Refresh()
	end)
	f:SetScript("OnShow", f.Refresh)
	ns:On("ACCENT_CHANGED", function() if f:IsVisible() then f:Refresh() end end)
	if tooltip then self:AttachTooltip(f, label, tooltip) end
	f:Refresh()
	return f
end

----------------------------------------------------------------
-- Curseur (piste fine + remplissage accent + pastille)
----------------------------------------------------------------
-- Construit la partie curseur (réutilisée par le moteur d'options)
function ns:StyleSlider(s)
	s:SetOrientation("HORIZONTAL")
	s:EnableMouse(true)
	s:SetHeight(14)
	s:SetBackdrop(nil)
	s:SetHitRectInsets(0, 0, -6, -6)
	-- piste : filet sombre de 4 px cerné de noir
	local edge = self:CreateTex(s, "BACKGROUND", { 0, 0, 0, 1 })
	edge:SetHeight(6)
	edge:SetPoint("LEFT")
	edge:SetPoint("RIGHT")
	local track = self:CreateTex(s, "BORDER", { 0.149, 0.149, 0.165, 1 })
	track:SetHeight(4)
	track:SetPoint("LEFT", 1, 0)
	track:SetPoint("RIGHT", -1, 0)
	s.track = track
	-- remplissage discret (accent très sombre)
	local fill = self:CreateTex(s, "ARTWORK")
	fill:SetHeight(4)
	fill:SetPoint("LEFT", 1, 0)
	self:RegisterAccent(fill, "tex", 0.35)
	s.fill = fill
	-- curseur : petit rectangle gris clair, bord noir
	s:SetThumbTexture(WHITE)
	local thumb = s:GetThumbTexture()
	thumb:SetSize(9, 17)
	thumb:SetVertexColor(0.81, 0.81, 0.81, 1)
	local thumbEdge = s:CreateTexture(nil, "ARTWORK")
	thumbEdge:SetTexture(WHITE)
	thumbEdge:SetVertexColor(0, 0, 0, 1)
	thumbEdge:SetPoint("TOPLEFT", thumb, "TOPLEFT", -1, 1)
	thumbEdge:SetPoint("BOTTOMRIGHT", thumb, "BOTTOMRIGHT", 1, -1)
	thumb:SetDrawLayer("OVERLAY")
	function s:UpdateFill()
		local lo, hi = self:GetMinMaxValues()
		local w = self:GetWidth()
		if hi > lo and w > 2 then
			fill:SetWidth(math.max(0.01, (self:GetValue() - lo) / (hi - lo) * (w - 2)))
		end
	end
	s:HookScript("OnValueChanged", s.UpdateFill)
	s:HookScript("OnSizeChanged", s.UpdateFill)
	return s
end

local sliderCount = 0
function ns:CreateSlider(parent, label, minV, maxV, step, get, set, fmt)
	sliderCount = sliderCount + 1
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(220, 40)

	local fs = self:CreateText(f, 12, C.text)
	fs:SetPoint("TOPLEFT", 0, 0)
	fs:SetText(label)

	local val = self:CreateText(f, 12, C.muted, nil, "RIGHT")
	val:SetPoint("TOPRIGHT", 0, 0)

	local s = CreateFrame("Slider", "EasyUISlider" .. sliderCount, f)
	self:StyleSlider(s)
	s:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -8)
	s:SetPoint("RIGHT", f, "RIGHT", 0, 0)
	s:SetMinMaxValues(minV, maxV)
	s:SetValueStep(step or 1)

	fmt = fmt or function(v) return tostring(v) end
	local updating
	s:SetScript("OnValueChanged", function(self, v)
		if step then v = math.floor(v / step + 0.5) * step end
		val:SetText(fmt(v))
		self:UpdateFill()
		if not updating and set then set(v) end
	end)
	s:EnableMouseWheel(true)
	s:SetScript("OnMouseWheel", function(self, d)
		self:SetValue(self:GetValue() + d * (step or 1))
	end)

	function f:Refresh()
		updating = true
		local v = get and get() or minV
		s:SetValue(v)
		val:SetText(fmt(v))
		s:UpdateFill()
		updating = false
	end
	f:SetScript("OnShow", f.Refresh)
	f.slider = s
	f:Refresh()
	return f
end

----------------------------------------------------------------
-- Zone de texte
----------------------------------------------------------------
function ns:CreateEditBox(parent, width, height)
	local e = CreateFrame("EditBox", nil, parent)
	e:SetSize(width or 160, height or 26)
	e:SetAutoFocus(false)
	self:Font(e, 12)
	e:SetTextColor(1, 1, 1, 0.9)
	e:SetTextInsets(8, 8, 0, 0)
	self:SetBackdrop(e, C.field, C.fieldBorder)
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	e:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(ns:AccentMix(0.48)) end)
	e:SetScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(C.fieldBorder[1], C.fieldBorder[2], C.fieldBorder[3], 1) end)
	return e
end

-- petite flèche vers le bas des listes déroulantes
function ns:CreateArrow(parent)
	local a = parent:CreateTexture(nil, "OVERLAY")
	a:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
	a:SetSize(12, 12)
	a:SetVertexColor(0.74, 0.74, 0.74, 1)
	return a
end

----------------------------------------------------------------
-- Liste déroulante simple (le moteur d'options a la sienne)
----------------------------------------------------------------
function ns:CreateDropdown(parent, width, getItems, get, set)
	local d = CreateFrame("Button", nil, parent)
	d:SetSize(width or 180, 26)
	self:SetBackdrop(d, C.field, C.fieldBorder)
	d.text = self:CreateText(d, 13, C.text)
	d.text:SetPoint("LEFT", 8, 0)
	d.text:SetPoint("RIGHT", -22, 0)
	local arrow = self:CreateArrow(d)
	arrow:SetPoint("RIGHT", -6, 0)
	d:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(ns:AccentMix(0.48)) end)
	d:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(C.fieldBorder[1], C.fieldBorder[2], C.fieldBorder[3], 1) end)

	function d:Refresh()
		local cur = get and get()
		local label = cur
		for _, item in ipairs(getItems() or {}) do
			if item.value == cur then label = item.text break end
		end
		self.text:SetText(label or "-")
	end
	function d:SetLabel(t) self.text:SetText(t) end
	d:SetScript("OnClick", function(self)
		ns:ShowMenu(self, getItems() or {}, get and get(), function(v)
			if set then set(v) end
			d:Refresh()
		end)
	end)
	d:HookScript("OnShow", d.Refresh)
	d:Refresh()
	return d
end

-- SetShown n'existe pas en 3.3.5
local function SetShown(self, show)
	if show then self:Show() else self:Hide() end
end
ns.SetShown = SetShown

----------------------------------------------------------------
-- Carte (bloc de contenu)
----------------------------------------------------------------
function ns:CreateCard(parent, width, height)
	local f = self:CreatePanel(parent, C.inset)
	f:SetBackdropBorderColor(C.insetBorder[1], C.insetBorder[2], C.insetBorder[3], 1)
	f:SetSize(width or 200, height or 100)
	return f
end

-- Icône avec bordure
function ns:CreateIcon(parent, size, texture)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(size, size)
	self:SetBackdrop(holder, { 0, 0, 0, 1 }, { 0, 0, 0, 1 })
	local t = holder:CreateTexture(nil, "ARTWORK")
	t:SetPoint("TOPLEFT", 1, -1)
	t:SetPoint("BOTTOMRIGHT", -1, 1)
	t:SetTexture(texture)
	t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	holder.tex = t
	return holder
end
