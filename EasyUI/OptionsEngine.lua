--[[
	EasyUI - Moteur d'options
	Affiche n'importe quelle table d'options au format AceConfig-3.0 dans le
	style EasyUI : navigation à gauche, onglets, sections, réglages en lignes
	(libellé à gauche, contrôle à droite, fonds alternés, deux par ligne quand
	la place le permet).

	ns:CreateOptionsView(parent, source, settings)
	  source   : nom d'application AceConfig ("Bartender4") ou table / fonction
	  settings : { key = "id unique", notify = "appName à notifier", hide = { cléRacine = true } }
]]
local _, ns = ...
local C = ns.colors
local WHITE = ns.media.white

local NAV_W = 150     -- colonne de sous-navigation
local NAV_ITEM_H = 25
local SCROLL_W = 8
local COL_GAP = 28    -- écart entre les deux colonnes de réglages
local HALF_SMALL = 420 -- largeur mini pour 2 petits réglages par ligne
local HALF_LARGE = 600 -- largeur mini pour 2 grands réglages par ligne
-- hauteur d'une ligne selon le type de réglage
local KIND_H = { toggle = 28, color = 28, execute = 34, range = 52, select = 52, input = 52 }
local ROW_H = 28

local floor, max, min = math.floor, math.max, math.min
local tinsert, tsort = table.insert, table.sort

----------------------------------------------------------------
-- Texte : on retire les références aux addons d'origine
----------------------------------------------------------------
local BRAND = {
	{ "Bartender4", "EasyUI" }, { "Bartender3", "EasyUI" }, { "Bartender", "EasyUI" },
	{ "Quartz3", "EasyUI" }, { "Quartz", "EasyUI" },
	{ "ButtonFacade", "un module de skin" },
	{ "Bagnon", "EasyUI" }, { "OmniCC", "EasyUI" }, { "MoveAnything", "EasyUI" }, { "Clique", "EasyUI" },
	{ "SexyMap", "la minimap" }, { "Details!", "EasyUI" }, { "TexBrowser", "un navigateur de textures" },
}
function ns:Brand(text)
	if type(text) ~= "string" then return text end
	for _, r in ipairs(BRAND) do
		if text:find(r[1], 1, true) then text = text:gsub(r[1], r[2]) end
	end
	return text
end

----------------------------------------------------------------
-- Zone défilante (barre fine, molette)
----------------------------------------------------------------
local scrollCount = 0
function ns:CreateScrollArea(parent)
	scrollCount = scrollCount + 1
	local holder = CreateFrame("Frame", nil, parent)

	local sf = CreateFrame("ScrollFrame", "EasyUIScroll" .. scrollCount, holder)
	sf:SetPoint("TOPLEFT")
	sf:SetPoint("BOTTOMRIGHT", -(SCROLL_W + 4), 0)
	sf:EnableMouseWheel(true)

	local child = CreateFrame("Frame", nil, sf)
	child:SetSize(10, 10)
	sf:SetScrollChild(child)

	local track = ns:CreateTex(holder, "BACKGROUND", { 1, 1, 1, 0.05 })
	track:SetWidth(2)
	track:SetPoint("TOPRIGHT", -4, 0)
	track:SetPoint("BOTTOMRIGHT", -4, 0)

	local thumb = CreateFrame("Button", nil, holder)
	thumb:SetWidth(4)
	local tt = ns:CreateTex(thumb, "ARTWORK", { 1, 1, 1, 0.25 })
	tt:SetAllPoints()
	thumb:SetScript("OnEnter", function() tt:SetVertexColor(1, 1, 1, 0.45) end)
	thumb:SetScript("OnLeave", function() tt:SetVertexColor(1, 1, 1, 0.25) end)
	thumb:EnableMouse(true)
	thumb:RegisterForDrag("LeftButton")

	holder.scroll, holder.child = sf, child

	local function Update()
		local range = sf:GetVerticalScrollRange()
		local h = sf:GetHeight()
		if range <= 0 or h <= 0 then
			thumb:Hide()
			track:Hide()
			if sf:GetVerticalScroll() ~= 0 then sf:SetVerticalScroll(0) end
			return
		end
		track:Show()
		thumb:Show()
		local th = max(30, h * h / (h + range))
		thumb:SetHeight(th)
		local pos = sf:GetVerticalScroll() / range * (h - th)
		thumb:ClearAllPoints()
		thumb:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -3, -pos)
	end
	holder.Update = Update

	function holder:SetScrollValue(v)
		local range = sf:GetVerticalScrollRange()
		sf:SetVerticalScroll(max(0, min(range, v)))
		Update()
	end

	function holder:SetContentHeight(h)
		child:SetHeight(max(1, h))
		child:SetWidth(sf:GetWidth())
		sf:UpdateScrollChildRect()
		Update()
	end

	sf:SetScript("OnMouseWheel", function(_, d)
		holder:SetScrollValue(sf:GetVerticalScroll() - d * 60)
	end)
	sf:SetScript("OnScrollRangeChanged", Update)
	sf:SetScript("OnSizeChanged", function() child:SetWidth(sf:GetWidth()) Update() end)

	thumb:SetScript("OnDragStart", function(self)
		local _, cy = GetCursorPosition()
		self.startY = cy / self:GetEffectiveScale()
		self.startV = sf:GetVerticalScroll()
		self:SetScript("OnUpdate", function()
			local _, y = GetCursorPosition()
			y = y / self:GetEffectiveScale()
			local range = sf:GetVerticalScrollRange()
			local h = sf:GetHeight() - self:GetHeight()
			if h > 0 then holder:SetScrollValue(self.startV + (self.startY - y) / h * range) end
		end)
	end)
	thumb:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	return holder
end

----------------------------------------------------------------
-- Accès aux options (même sémantique qu'AceConfigDialog)
----------------------------------------------------------------
local INHERITED = { get = true, set = true, func = true, confirm = true, validate = true, disabled = true, hidden = true }

local function Inherited(chain, field)
	for i = #chain, 1, -1 do
		local v = chain[i][field]
		if v ~= nil then return v end
	end
end

local function MakeInfo(view, chain, keys)
	local info = {}
	for i = 1, #keys do info[i] = keys[i] end
	local opt = chain[#chain]
	info.options = chain[1]
	info.option = opt
	info.arg = opt.arg
	info.handler = Inherited(chain, "handler")
	info.type = opt.type
	info.uiType = "dialog"
	info.uiName = "EasyUI-1.0"
	info.appName = view.appName
	return info
end

local function Call(view, chain, keys, value, ...)
	if type(value) == "function" then
		return value(MakeInfo(view, chain, keys), ...)
	elseif type(value) == "string" then
		local handler = Inherited(chain, "handler")
		if handler and type(handler[value]) == "function" then
			return handler[value](handler, MakeInfo(view, chain, keys), ...)
		end
	end
	return value
end

local PLAIN = { name = true, desc = true, values = true, order = true, min = true, max = true, width = true, image = true }

local function Member(view, chain, keys, field, ...)
	local value
	if INHERITED[field] then
		value = Inherited(chain, field)
	else
		value = chain[#chain][field]
	end
	if PLAIN[field] then
		if type(value) == "function" then return value(MakeInfo(view, chain, keys), ...) end
		return value
	end
	return Call(view, chain, keys, value, ...)
end

local function Text(view, chain, keys, field)
	local ok, v = pcall(Member, view, chain, keys, field)
	if not ok then return "" end
	if type(v) ~= "string" then return v and tostring(v) or "" end
	return ns:Brand(v)
end

local function IsHidden(view, chain, keys)
	local opt = chain[#chain]
	if opt.dialogHidden or opt.guiHidden then return true end
	if #keys == 1 and view.hide and view.hide[keys[1]] then return true end
	local ok, h = pcall(Member, view, chain, keys, "hidden")
	return ok and h and true or false
end

local function IsDisabled(view, chain, keys)
	local ok, d = pcall(Member, view, chain, keys, "disabled")
	return ok and d and true or false
end

local function IsInline(opt)
	return opt.inline or opt.guiInline or opt.dialogInline
end

local function SortedArgs(view, chain, keys)
	local group = chain[#chain]
	local list = {}
	local function add(k, v)
		if type(v) == "table" then tinsert(list, { key = k, opt = v }) end
	end
	if group.args then for k, v in pairs(group.args) do add(k, v) end end
	if group.plugins then
		for _, p in pairs(group.plugins) do
			for k, v in pairs(p) do add(k, v) end
		end
	end
	for _, e in ipairs(list) do
		chain[#chain + 1] = e.opt
		keys[#keys + 1] = e.key
		local ok, o = pcall(Member, view, chain, keys, "order")
		e.order = ok and type(o) == "number" and o or 100
		e.name = Text(view, chain, keys, "name")
		if e.name == "" then e.name = tostring(e.key) end
		chain[#chain] = nil
		keys[#keys] = nil
	end
	tsort(list, function(a, b)
		if a.order ~= b.order then
			local ao = a.order < 0 and 1e9 + a.order or a.order
			local bo = b.order < 0 and 1e9 + b.order or b.order
			return ao < bo
		end
		return tostring(a.name) < tostring(b.name)
	end)
	return list
end

local function Copy(t) local c = {} for i = 1, #t do c[i] = t[i] end return c end

----------------------------------------------------------------
-- Widgets (réutilisables, chacun occupe un emplacement de ligne)
----------------------------------------------------------------
local pools = { nav = {} }
local factories = {}

local function Acquire(view, kind, parent)
	pools[kind] = pools[kind] or {}
	local w = tremove(pools[kind])
	if not w then w = factories[kind]() w.kind = kind end
	w:SetParent(parent)
	w:ClearAllPoints()
	w:SetFrameLevel(parent:GetFrameLevel() + (kind == "rowbg" and 1 or 4))
	w:Show()
	tinsert(view.used, w)
	return w
end

local function ReleaseAll(view)
	for _, w in ipairs(view.used) do
		w:Hide()
		w:ClearAllPoints()
		tinsert(pools[w.kind], w)
	end
	wipe(view.used)
end

local function Tooltip(frame)
	frame:HookScript("OnEnter", function(self)
		if not self.tipText or self.tipText == "" then return end
		GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
		GameTooltip:AddLine(self.tipTitle or "", 1, 1, 1)
		GameTooltip:AddLine(self.tipText, nil, nil, nil, true)
		GameTooltip:Show()
	end)
	frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- base commune : un emplacement avec libellé à gauche
-- les réglages à libellé au-dessus (curseur, liste, saisie) l'ancrent en haut
local ABOVE = { range = true, select = true, input = true }
local function Slot(kind)
	local f = CreateFrame((kind == "toggle" or kind == "color") and "Button" or "Frame", nil, UIParent)
	f:SetHeight(KIND_H[kind] or ROW_H)
	f:EnableMouse(true)
	local fs = ns:CreateText(f, 13, C.text)
	if ABOVE[kind] then
		fs:SetPoint("TOPLEFT", 0, -3)
		fs:SetPoint("RIGHT", 0, 0)
		fs:SetHeight(18)
	else
		fs:SetHeight(22)
	end
	fs:SetJustifyV("MIDDLE")
	f.text = fs
	Tooltip(f)
	function f:SetDisabled(d)
		self.disabled = d
		self:SetAlpha(d and 0.35 or 1)
	end
	return f
end

-- fond de ligne (alterné)
factories.rowbg = function()
	local f = CreateFrame("Frame", nil, UIParent)
	f.bg = ns:CreateTex(f, "BACKGROUND", { 0, 0, 0, 0 })
	f.bg:SetAllPoints()
	f.flash = ns:CreateTex(f, "BORDER")
	f.flash:SetAllPoints()
	f.flash:Hide()
	return f
end

-- Interrupteur
factories.toggle = function()
	local f = Slot("toggle")
	local sw = ns:CreateSwitch(f)
	sw:SetPoint("LEFT", 0, 0)
	f.switch = sw
	f.text:SetPoint("LEFT", sw, "RIGHT", 9, 0)
	f.text:SetPoint("RIGHT", 0, 0)
	f:HookScript("OnEnter", function() if not f.disabled then sw:SetBackdropBorderColor(ns:AccentMix(0.48)) end end)
	f:HookScript("OnLeave", function() sw:SetBackdropBorderColor(C.checkBorder[1], C.checkBorder[2], C.checkBorder[3], 1) end)
	f:SetScript("OnClick", function(self)
		if self.disabled or not self.onToggle then return end
		PlaySound("igMainMenuOptionCheckBoxOn")
		self.onToggle()
	end)
	function f:SetValue(on, tristate) self.switch:SetValue(on, on == nil and tristate) end
	return f
end

-- Curseur avec valeur modifiable
factories.range = function()
	local f = Slot("range")
	local eb = CreateFrame("EditBox", nil, f)
	eb:SetSize(58, 24)
	eb:SetPoint("BOTTOMRIGHT", 0, 3)
	eb:SetAutoFocus(false)
	ns:Font(eb, 13)
	eb:SetTextColor(1, 1, 1, 1)
	eb:SetJustifyH("CENTER")
	ns:SetBackdrop(eb, C.field, C.fieldBorder)
	eb:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(ns:AccentMix(0.48)) end)
	eb:SetScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(C.fieldBorder[1], C.fieldBorder[2], C.fieldBorder[3], 1) end)
	f.edit = eb

	local s = CreateFrame("Slider", nil, f)
	ns:StyleSlider(s)
	s:SetPoint("LEFT", f, "LEFT", 0, 0)
	s:SetPoint("RIGHT", eb, "LEFT", -10, 0)
	s:SetPoint("TOP", eb, "TOP", 0, -5)
	f.slider = s

	local function Fmt(v)
		if f.isPercent then return ("%d%%"):format(floor(v * 100 + 0.5)) end
		if f.step and f.step > 0 and f.step < 1 then
			local dec = f.step < 0.1 and 2 or 1
			return ("%." .. dec .. "f"):format(v)
		end
		return tostring(floor(v + 0.5))
	end

	s:SetScript("OnValueChanged", function(self, v)
		if f.step and f.step > 0 then v = floor(v / f.step + 0.5) * f.step end
		eb:SetText(Fmt(v))
		self:UpdateFill()
		if not f.updating and f.onChange then
			f.pending = v
			f.dirty = true
		end
	end)
	s:SetScript("OnMouseUp", function()
		if f.dirty and f.onChange then f.dirty = nil f.onChange(f.pending) end
	end)
	s:SetScript("OnUpdate", function(self, el)
		if f.dirty then
			f.acc = (f.acc or 0) + el
			if f.acc > 0.15 and not IsMouseButtonDown("LeftButton") then
				f.acc = 0
				f.dirty = nil
				f.onChange(f.pending)
			end
		end
	end)
	s:EnableMouseWheel(true)
	s:SetScript("OnMouseWheel", function(self, d)
		if f.disabled then return end
		local st = f.bigStep or f.step or 1
		self:SetValue(self:GetValue() + d * st)
		if f.dirty then f.dirty = nil f.onChange(f.pending) end
	end)

	eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() self:SetText(Fmt(s:GetValue())) end)
	eb:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
		local txt = self:GetText():gsub("%%", ""):gsub(",", ".")
		local v = tonumber(txt)
		if v and f.onChange then
			if f.isPercent then v = v / 100 end
			f.onChange(max(f.min, min(f.max, v)))
		else
			self:SetText(Fmt(s:GetValue()))
		end
	end)

	function f:Setup(lo, hi, softLo, softHi, step, bigStep, isPercent, value)
		self.updating = true
		self.min, self.max = lo, hi
		self.step, self.bigStep, self.isPercent = step, bigStep, isPercent
		s:SetMinMaxValues(softLo or lo, softHi or hi)
		s:SetValueStep(step and step > 0 and step or 0.0001)
		s:SetValue(value or lo)
		eb:SetText(Fmt(value or lo))
		s:UpdateFill()
		self.updating = false
	end
	local baseDisabled = f.SetDisabled
	function f:SetDisabled(d)
		baseDisabled(self, d)
		s:EnableMouse(not d)
		eb:EnableMouse(not d)
	end
	return f
end

-- Menu déroulant (défilement + aperçus de textures / polices)
local menu
local MENU_ROWS = 14
local function GetMenu()
	if menu then return menu end
	menu = CreateFrame("Frame", "EasyUIOptionsMenu", UIParent)
	menu:SetFrameStrata("FULLSCREEN_DIALOG")
	menu:SetClampedToScreen(true)
	ns:SetBackdrop(menu, { 0.035, 0.035, 0.04, 0.98 }, C.fieldBorder)
	menu:EnableMouse(true)
	menu:EnableMouseWheel(true)
	menu.rows = {}
	menu.offset = 0
	menu:Hide()
	for i = 1, MENU_ROWS do
		local b = CreateFrame("Button", nil, menu)
		b:SetHeight(24)
		b:SetPoint("TOPLEFT", 1, -1 - (i - 1) * 24)
		b:SetPoint("RIGHT", menu, "RIGHT", -1, 0)
		local hl = ns:CreateTex(b, "HIGHLIGHT", C.subSel)
		hl:SetAllPoints()
		b.selbg = ns:CreateTex(b, "BACKGROUND", C.hover)
		b.selbg:SetAllPoints()
		b.preview = b:CreateTexture(nil, "BORDER")
		b.preview:SetPoint("TOPLEFT", 1, -1)
		b.preview:SetPoint("BOTTOMRIGHT", -1, 1)
		b.text = ns:CreateText(b, 13, C.text)
		b.text:SetPoint("LEFT", 12, 0)
		b.text:SetPoint("RIGHT", -8, 0)
		b.mark = ns:CreateTex(b, "ARTWORK")
		b.mark:SetSize(2, 14)
		b.mark:SetPoint("LEFT", 3, 0)
		ns:RegisterAccent(b.mark, "tex")
		b:SetScript("OnClick", function(self)
			menu:Hide()
			if menu.onSelect then menu.onSelect(self.value) end
		end)
		menu.rows[i] = b
	end
	function menu:Refresh()
		local items = self.items
		for i = 1, MENU_ROWS do
			local b = self.rows[i]
			local item = items[i + self.offset]
			if item then
				b.value = item.value
				b.text:SetText(item.text)
				if self.preview == "font" and item.extra then
					b.text:SetFont(item.extra, 13)
				else
					ns:Font(b.text, 13)
				end
				if self.preview == "statusbar" and item.extra then
					b.preview:SetTexture(item.extra)
					b.preview:SetVertexColor(0.45, 0.47, 0.52, 0.6)
					b.preview:Show()
				else
					b.preview:Hide()
				end
				local sel = item.value == self.current
				ns.SetShown(b.mark, sel)
				ns.SetShown(b.selbg, sel)
				b:Show()
			else
				b:Hide()
			end
		end
	end
	menu:SetScript("OnMouseWheel", function(self, d)
		local maxOff = max(0, #self.items - MENU_ROWS)
		self.offset = max(0, min(maxOff, self.offset - d * 3))
		self:Refresh()
	end)
	menu:SetScript("OnUpdate", function(self, el)
		if not self:IsMouseOver() and not (self.owner and self.owner:IsMouseOver()) then
			self.elapsed = (self.elapsed or 0) + el
			if self.elapsed > 1.2 then self:Hide() end
		else
			self.elapsed = 0
		end
	end)
	tinsert(UISpecialFrames, "EasyUIOptionsMenu")
	return menu
end

function ns:ShowMenu(owner, items, current, onSelect, preview)
	local m = GetMenu()
	if m:IsShown() and m.owner == owner then m:Hide() return end
	m.owner, m.items, m.current, m.onSelect, m.preview = owner, items, current, onSelect, preview
	m.offset = 0
	for i, it in ipairs(items) do
		if it.value == current then m.offset = max(0, min(#items - MENU_ROWS, i - floor(MENU_ROWS / 2))) break end
	end
	m:SetScale(owner:GetEffectiveScale() / UIParent:GetEffectiveScale())
	m:SetSize(max(owner:GetWidth(), 160), min(#items, MENU_ROWS) * 24 + 2)
	m:ClearAllPoints()
	m:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
	m.elapsed = 0
	m:Refresh()
	m:Show()
end

-- Liste déroulante
factories.select = function()
	local f = Slot("select")
	local b = CreateFrame("Button", nil, f)
	b:SetSize(260, 26)
	b:SetPoint("BOTTOMLEFT", 0, 3)
	ns:SetBackdrop(b, C.field, C.fieldBorder)
	b.preview = b:CreateTexture(nil, "BORDER")
	b.preview:SetPoint("TOPLEFT", 1, -1)
	b.preview:SetPoint("BOTTOMRIGHT", -1, 1)
	b.label = ns:CreateText(b, 13, C.text)
	b.label:SetPoint("LEFT", 8, 0)
	b.label:SetPoint("RIGHT", -22, 0)
	local arrow = ns:CreateArrow(b)
	arrow:SetPoint("RIGHT", -6, 0)
	f.button = b
	f:SetScript("OnSizeChanged", function(self, w) b:SetWidth(math.min(w or 260, 280)) end)
	b:SetScript("OnEnter", function(self)
		self:SetBackdropBorderColor(ns:AccentMix(0.48))
		local s = f:GetScript("OnEnter") if s then s(f) end
	end)
	b:SetScript("OnLeave", function(self)
		self:SetBackdropBorderColor(C.fieldBorder[1], C.fieldBorder[2], C.fieldBorder[3], 1)
		GameTooltip:Hide()
	end)
	b:SetScript("OnClick", function(self)
		if f.disabled then return end
		ns:ShowMenu(self, f.items, f.current, f.onChange, f.preview)
	end)
	function f:SetCurrent(value)
		self.current = value
		local label = value ~= nil and tostring(value) or "-"
		local extra
		for _, it in ipairs(self.items) do
			if it.value == value then label, extra = it.text, it.extra break end
		end
		b.label:SetText(label)
		if self.preview == "font" and extra then b.label:SetFont(extra, 14) else ns:Font(b.label, 13) end
		if self.preview == "statusbar" and extra then
			b.preview:SetTexture(extra)
			b.preview:SetVertexColor(0.45, 0.47, 0.52, 0.55)
			b.preview:Show()
		else
			b.preview:Hide()
		end
	end
	return f
end

-- Couleur
factories.color = function()
	local f = Slot("color")
	local sw = CreateFrame("Button", nil, f)
	sw:SetSize(28, 16)
	sw:SetPoint("LEFT", 0, 0)
	ns:SetBackdrop(sw, { 1, 1, 1, 1 }, C.checkBorder)
	f.swatch = sw
	f.text:SetPoint("LEFT", sw, "RIGHT", 9, 0)
	f.text:SetPoint("RIGHT", 0, 0)
	function f:SetColor(r, g, b, a)
		self.r, self.g, self.b, self.a = r or 1, g or 1, b or 1, a or 1
		sw:SetBackdropColor(self.r, self.g, self.b, self.hasAlpha and self.a or 1)
	end
	local function open()
		if f.disabled then return end
		local r0, g0, b0, a0 = f.r, f.g, f.b, f.a
		local function apply()
			local r, g, b = ColorPickerFrame:GetColorRGB()
			local a = f.hasAlpha and (1 - OpacitySliderFrame:GetValue()) or 1
			f:SetColor(r, g, b, a)
			if f.onChange then f.onChange(r, g, b, a) end
		end
		ColorPickerFrame.func = apply
		ColorPickerFrame.opacityFunc = apply
		ColorPickerFrame.hasOpacity = f.hasAlpha
		ColorPickerFrame.opacity = 1 - (a0 or 1)
		ColorPickerFrame.previousValues = { r0, g0, b0, a0 }
		ColorPickerFrame.cancelFunc = function()
			f:SetColor(r0, g0, b0, a0)
			if f.onChange then f.onChange(r0, g0, b0, a0) end
		end
		ColorPickerFrame:SetColorRGB(r0, g0, b0)
		ColorPickerFrame:Hide()
		ColorPickerFrame:Show()
	end
	sw:SetScript("OnClick", open)
	f:SetScript("OnMouseUp", open)
	return f
end

-- Champ de saisie
factories.input = function()
	local f = Slot("input")
	local eb = CreateFrame("EditBox", nil, f)
	eb:SetSize(200, 26)
	eb:SetPoint("BOTTOMLEFT", 0, 3)
	eb:SetAutoFocus(false)
	ns:Font(eb, 13)
	eb:SetTextColor(1, 1, 1, 1)
	eb:SetTextInsets(8, 8, 0, 0)
	ns:SetBackdrop(eb, C.field, C.fieldBorder)
	f.edit = eb
	local ok = ns:CreateButton(f, "OK", 40, 26, nil, "accent")
	ok:SetPoint("LEFT", eb, "RIGHT", 6, 0)
	local function commit()
		eb:ClearFocus()
		if f.onChange then f.onChange(eb:GetText()) end
	end
	ok:SetScript("OnClick", commit)
	eb:SetScript("OnEnterPressed", commit)
	eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() self:SetText(f.value or "") end)
	eb:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(ns:AccentMix(0.48)) end)
	eb:SetScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(C.fieldBorder[1], C.fieldBorder[2], C.fieldBorder[3], 1) end)
	local baseDisabled = f.SetDisabled
	function f:SetDisabled(d)
		baseDisabled(self, d)
		eb:EnableMouse(not d)
		ok:EnableMouse(not d)
	end
	function f:SetFieldWidth(w) self.fieldW = w eb:SetWidth(math.min(w, math.max(80, (self:GetWidth() or w) - 46))) end
	f:SetScript("OnSizeChanged", function(self) if self.fieldW then self:SetFieldWidth(self.fieldW) end end)
	return f
end

-- Bouton d'action (occupe l'emplacement)
factories.execute = function()
	local f = CreateFrame("Frame", nil, UIParent)
	f:SetHeight(KIND_H.execute)
	local b = ns:CreateButton(f, "", 160, 26, nil, "normal")
	b:SetPoint("LEFT", 0, 0)
	f.button = b
	-- le bouton prend la largeur de son texte
	local baseLabel = b.SetLabel
	function b:SetLabel(t)
		baseLabel(self, t)
		self:SetWidth(math.min(math.floor(self.text:GetStringWidth() + 30), math.max(60, f:GetWidth() or 300)))
	end
	Tooltip(b)
	return f
end

-- Texte descriptif
factories.description = function()
	local f = CreateFrame("Frame", nil, UIParent)
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.text = ns:CreateText(f, 12, C.muted)
	f.text:SetJustifyV("TOP")
	f.text:SetNonSpaceWrap(true)
	return f
end

-- Titre de section
factories.header = function()
	local f = CreateFrame("Frame", nil, UIParent)
	f:SetHeight(32)
	f.text = ns:CreateText(f, 14, C.text)
	f.text:SetPoint("BOTTOMLEFT", 0, 7)
	ns:RegisterAccent(f.text, "text")
	f.line = ns:CreateTex(f, "ARTWORK", C.rule)
	f.line:SetHeight(1)
	f.line:SetPoint("BOTTOMLEFT")
	f.line:SetPoint("BOTTOMRIGHT")
	return f
end

-- Onglets internes
factories.tabs = function()
	local f = CreateFrame("Frame", nil, UIParent)
	f:SetHeight(30)
	f.line = ns:CreateTex(f, "BACKGROUND", C.rule)
	f.line:SetHeight(1)
	f.line:SetPoint("BOTTOMLEFT")
	f.line:SetPoint("BOTTOMRIGHT")
	f.buttons = {}
	function f:Build(tabs, selected, onSelect)
		for _, b in ipairs(self.buttons) do b:Hide() end
		-- les onglets reposent sur le filet ; s'il en faut plusieurs rangées, elles s'empilent
		local W = self:GetWidth()
		local placed, x, row = {}, 0, 0
		for i, t in ipairs(tabs) do
			local b = self.buttons[i]
			if not b then
				b = ns:CreateTabButton(self)
				self.buttons[i] = b
			end
			b.text:SetText(t.text)
			local w = b.text:GetStringWidth() + 28
			if x + w > W and x > 0 then x = 0 row = row + 1 end
			b:SetWidth(w)
			placed[i] = { b = b, x = x, row = row }
			x = x + w
			b:SetSelected(t.key == selected)
			b:SetScript("OnClick", function() onSelect(t.key) end)
			b:Show()
		end
		local rows = row + 1
		for _, p in ipairs(placed) do
			p.b:ClearAllPoints()
			p.b:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", p.x, (rows - 1 - p.row) * 30)
		end
		self:SetHeight(rows * 30)
		return rows * 30
	end
	return f
end

-- Navigation (colonne de gauche)
factories.nav = function()
	local b = CreateFrame("Button", nil, UIParent)
	b:SetHeight(NAV_ITEM_H)
	b.sel = ns:CreateTex(b, "BACKGROUND", C.subSel)
	b.sel:SetAllPoints()
	local hl = ns:CreateTex(b, "HIGHLIGHT", C.hover)
	hl:SetAllPoints()
	b.text = ns:CreateText(b, 13, C.soft)
	b.text:SetHeight(NAV_ITEM_H)
	function b:SetSelected(s)
		ns.SetShown(self.sel, s)
		if s then
			self.text:SetTextColor(1, 1, 1, 1)
		elseif self.depth > 1 then
			ns.SetTextColorC(self.text, C.muted)
		else
			ns.SetTextColorC(self.text, C.soft)
		end
	end
	return b
end

----------------------------------------------------------------
-- Mise en page en lignes
----------------------------------------------------------------
local Layout = {}
Layout.__index = Layout

local function NewLayout(parent, width, x0, y0)
	return setmetatable({ parent = parent, width = width, x0 = x0 or 0, y = y0 or 0,
		slot = 0, rowIndex = 0, rowH = 0, view = nil }, Layout)
end

-- termine la ligne en cours (sa hauteur = le plus haut de ses réglages)
function Layout:EndRow()
	if self.slot > 0 then
		if self.rowBg then self.rowBg:SetHeight(self.rowH) end
		self.y = self.y + self.rowH + 2
		self.slot = 0
		self.rowH = 0
	end
end

-- nouvelle section : la ligne suivante repart avec un fond clair
function Layout:Section()
	self:EndRow()
	self.rowIndex = 0
end

-- place un réglage ; half = peut partager la ligne
function Layout:PlaceItem(w, half)
	local W = self.width
	local span = half and 1 or 2
	if span == 2 or self.slot == 0 then self:EndRow() end
	if self.slot == 0 then
		-- fond de ligne
		self.rowIndex = self.rowIndex + 1
		local bg = Acquire(self.view, "rowbg", self.parent)
		bg:SetPoint("TOPLEFT", self.parent, "TOPLEFT", self.x0, -self.y)
		bg:SetSize(W, ROW_H)
		bg.flash:Hide()
		self.rowBg = bg
	end
	local colW = floor((W - COL_GAP) / 2)
	local x = (self.slot == 1) and (colW + COL_GAP) or 0
	local h = KIND_H[w.kind] or ROW_H
	w:SetPoint("TOPLEFT", self.parent, "TOPLEFT", self.x0 + x, -self.y)
	w:SetWidth(span == 2 and W or colW)
	w:SetHeight(h)
	if h > self.rowH then self.rowH = h end
	if span == 2 then
		self.slot = 2
		self:EndRow()
	else
		self.slot = self.slot + 1
		if self.slot >= 2 then self:EndRow() end
	end
	return self.rowBg
end

-- place un bloc libre (titre, texte, onglets) sur toute la largeur
function Layout:PlaceBlock(w, height, gapBefore, gapAfter)
	self:EndRow()
	self.y = self.y + (gapBefore or 0)
	w:SetPoint("TOPLEFT", self.parent, "TOPLEFT", self.x0, -self.y)
	w:SetWidth(self.width)
	if height then w:SetHeight(height) end
	self.y = self.y + (height or w:GetHeight()) + (gapAfter or 0)
end

function Layout:Height()
	return self.y + (self.slot > 0 and self.rowH or 0)
end

-- les petits contrôles se mettent à deux par ligne dès que possible
local SMALL = { toggle = true, color = true, execute = true }
local function IsHalf(layout, opt, widthValue)
	if widthValue == "full" or widthValue == "double" then return false end
	if SMALL[opt.type] then return layout.width >= HALF_SMALL end
	return layout.width >= HALF_LARGE
end

----------------------------------------------------------------
-- Vue d'options
----------------------------------------------------------------
local View = {}
View.__index = View

function ns:CreateOptionsView(parent, source, settings)
	settings = settings or {}
	local view = setmetatable({}, View)
	view.parent = parent
	view.source = source
	view.appName = type(source) == "string" and source or settings.notify
	view.hide = settings.hide
	view.key = settings.key or tostring(source)
	view.used = {}
	view.navUsed = {}

	-- vue posée directement dans le corps d'une page : la sous-navigation
	-- devient une colonne pleine hauteur collée à la barre latérale
	local page = parent.page
	view.page = page
	local nav, sep
	if page then
		nav = ns:CreateScrollArea(page)
		nav:SetPoint("TOPLEFT", page, "TOPLEFT", 6, -10)
		nav:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 6, 10)
		nav:SetWidth(NAV_W - 12)
		sep = ns:CreateTex(page, "ARTWORK", C.line)
		sep:SetWidth(1)
		sep:SetPoint("TOPLEFT", page, "TOPLEFT", NAV_W, 0)
		sep:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", NAV_W, 0)
	else
		nav = ns:CreateScrollArea(parent)
		nav:SetPoint("TOPLEFT")
		nav:SetPoint("BOTTOMLEFT")
		nav:SetWidth(NAV_W)
		sep = ns:CreateTex(parent, "ARTWORK", C.line)
		sep:SetWidth(1)
		sep:SetPoint("TOPLEFT", nav, "TOPRIGHT", 8, 0)
		sep:SetPoint("BOTTOMLEFT", nav, "BOTTOMRIGHT", 8, 0)
	end
	view.nav = nav
	view.sep = sep

	local content = ns:CreateScrollArea(parent)
	content:SetPoint("TOPLEFT", page and parent or nav, page and "TOPLEFT" or "TOPRIGHT", page and 0 or 20, 0)
	content:SetPoint("BOTTOMRIGHT")
	view.content = content

	local ACR = ns:GetLib("AceConfigRegistry-3.0")
	if ACR and view.appName then
		ACR.RegisterCallback(view, "ConfigTableChange", function(_, app)
			if app == view.appName and not view.selfNotify and parent:IsVisible() then view:Refresh(true) end
		end)
	end
	parent:HookScript("OnShow", function() view:Refresh() end)

	ns.optionViews = ns.optionViews or {}
	tinsert(ns.optionViews, view)
	return view
end

function View:GetRoot()
	local src = self.source
	if type(src) == "string" then
		local ACR = ns:GetLib("AceConfigRegistry-3.0")
		local fn = ACR and ACR:GetOptionsTable(src)
		if not fn then return end
		local ok, t = pcall(fn, "dialog", "EasyUI-1.0")
		return ok and t or nil
	elseif type(src) == "function" then
		return src()
	end
	return src
end

function View:Changed()
	if self.appName then
		local ACR = ns:GetLib("AceConfigRegistry-3.0")
		if ACR and ACR:GetOptionsTable(self.appName) then
			self.selfNotify = true
			ACR:NotifyChange(self.appName)
			self.selfNotify = nil
		end
	end
	if not self.pendingRefresh then
		self.pendingRefresh = true
		ns:After(0.05, function()
			self.pendingRefresh = nil
			if self.parent:IsVisible() then self:Refresh(true) end
		end)
	end
end

local function ChildGroups(view, chain, keys)
	local out = {}
	for _, e in ipairs(SortedArgs(view, chain, keys)) do
		if e.opt.type == "group" and not IsInline(e.opt) then
			chain[#chain + 1] = e.opt
			keys[#keys + 1] = e.key
			if not IsHidden(view, chain, keys) then tinsert(out, e) end
			chain[#chain] = nil
			keys[#keys] = nil
		end
	end
	return out
end

local function HasOwnOptions(view, chain, keys)
	for _, e in ipairs(SortedArgs(view, chain, keys)) do
		if e.opt.type ~= "group" or IsInline(e.opt) then return true end
	end
end

function View:BuildNavEntries(root)
	local entries = {}
	local chain, keys = { root }, {}
	if HasOwnOptions(self, chain, keys) then
		tinsert(entries, { name = "Général", keys = {}, depth = 1 })
	end
	local function walk(depth)
		local group = chain[#chain]
		local mode = group.childGroups or "tree"
		if depth > 1 and mode ~= "tree" then return end
		for _, e in ipairs(ChildGroups(self, chain, keys)) do
			chain[#chain + 1] = e.opt
			keys[#keys + 1] = e.key
			tinsert(entries, { name = e.name, keys = Copy(keys), depth = depth })
			if depth < 3 then walk(depth + 1) end
			chain[#chain] = nil
			keys[#keys] = nil
		end
	end
	if (root.childGroups or "tree") == "tree" then walk(1) end
	return entries
end

local function StartsWith(a, prefix)
	if #prefix > #a then return false end
	for i = 1, #prefix do if a[i] ~= prefix[i] then return false end end
	return true
end

function View:Refresh(keepScroll)
	local root = self:GetRoot()
	ReleaseAll(self)
	if not root then return end
	self.root = root
	self.positions = {}

	for _, b in ipairs(self.navUsed) do b:Hide() tinsert(pools.nav, b) end
	wipe(self.navUsed)
	local entries = self:BuildNavEntries(root)

	local showNav = #entries > 1 or (#entries == 1 and #entries[1].keys > 0)
	if showNav then
		self.nav:Show()
		self.sep:Show()
		if not self.page then self.content:SetPoint("TOPLEFT", self.nav, "TOPRIGHT", 20, 0) end
	else
		self.nav:Hide()
		self.sep:Hide()
		if not self.page then self.content:SetPoint("TOPLEFT", self.parent, "TOPLEFT", 0, 0) end
	end
	if self.page then ns:SetPageInset(self.page, showNav and NAV_W or 0) end

	ns.db.optionPaths = ns.db.optionPaths or {}
	local selected = ns.db.optionPaths[self.key] or {}
	local navSel
	for _, e in ipairs(entries) do
		if StartsWith(selected, e.keys) and (not navSel or #e.keys > #navSel.keys) then navSel = e end
	end
	navSel = navSel or entries[1]

	if showNav then
		local y = 0
		for _, e in ipairs(entries) do
			local b = tremove(pools.nav) or factories.nav()
			b.kind = "nav"
			b:SetParent(self.nav.child)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", 0, -y)
			b:SetPoint("RIGHT", self.nav.child, "RIGHT", 0, 0)
			b.depth = e.depth
			b.text:ClearAllPoints()
			b.text:SetPoint("LEFT", 10 + (e.depth - 1) * 12, 0)
			b.text:SetPoint("RIGHT", -6, 0)
			ns:Font(b.text, e.depth > 1 and 12 or 13)
			b.text:SetText(ns:Brand(e.name))
			b:SetSelected(navSel == e)
			b:SetScript("OnClick", function()
				ns.db.optionPaths[self.key] = Copy(e.keys)
				self:Refresh()
			end)
			b:Show()
			tinsert(self.navUsed, b)
			y = y + NAV_ITEM_H
		end
		self.nav:SetContentHeight(y)
	end
	-- le titre de la page indique la section ouverte (« Barres d'incantation · Joueur »)
	if self.page and self.page.SetTitleSuffix then
		self.page:SetTitleSuffix(showNav and navSel and #navSel.keys > 0 and ns:Brand(navSel.name) or nil)
	end

	local scroll = keepScroll and self.content.scroll:GetVerticalScroll() or 0
	local child = self.content.child
	local width = self.content.scroll:GetWidth()
	local expected
	if self.page then
		expected = self.page:GetWidth() - (showNav and NAV_W or 0) - (ns.PAGE_PAD or 22) * 2 - SCROLL_W - 4
	else
		expected = self.parent:GetWidth() - (showNav and NAV_W + 20 or 0) - SCROLL_W - 4
	end
	if width < 50 or math.abs(width - expected) > 2 then width = expected end
	child:SetWidth(width)
	local layout = NewLayout(child, width)
	layout.view = self

	local chain, keys = { root }, {}
	local ok = true
	for i = 1, #(navSel and navSel.keys or {}) do
		local k = navSel.keys[i]
		local g = chain[#chain]
		local nextOpt = (g.args and g.args[k])
		if not nextOpt and g.plugins then
			for _, p in pairs(g.plugins) do if p[k] then nextOpt = p[k] break end end
		end
		if not nextOpt then ok = false break end
		chain[#chain + 1] = nextOpt
		keys[#keys + 1] = k
	end
	if not ok then
		ns.db.optionPaths[self.key] = nil
		chain, keys = { root }, {}
	end

	local excludeChildren = (#keys == 0 and showNav and (root.childGroups or "tree") == "tree")
	self:RenderGroup(layout, chain, keys, excludeChildren, true)

	self.content:SetContentHeight(layout:Height() + 24)
	self.content:SetScrollValue(scroll)

	-- réglage à mettre en évidence (recherche)
	if self.highlight then
		local pos = self.positions[self.highlight]
		self.highlight = nil
		if pos then
			self.content:SetScrollValue(pos.y - 60)
			local bg = pos.bg
			if bg then
				local r, g, b = ns:GetAccent()
				bg.flash:SetVertexColor(r, g, b, 0.35)
				bg.flash:Show()
				local t = 0
				bg:SetScript("OnUpdate", function(f, el)
					t = t + el
					local a = 0.35 * (1 - t / 2)
					if a <= 0 then f.flash:Hide() f:SetScript("OnUpdate", nil) else f.flash:SetAlpha(a / 0.35) end
				end)
			end
		end
	end
	-- callback de la page (aperçu à mettre à jour)
	if self.onRefresh then
		local okr, errr = pcall(self.onRefresh, self)
		if not okr then geterrorhandler()(errr) end
	end
end

function View:RenderGroup(layout, chain, keys, excludeTreeChildren, top)
	local group = chain[#chain]
	local args = SortedArgs(self, chain, keys)
	local subgroups = {}

	if top and #keys > 0 then
		local d = Text(self, chain, keys, "desc")
		if d and d ~= "" then self:RenderDescription(layout, d, "medium") end
	end

	for _, e in ipairs(args) do
		chain[#chain + 1] = e.opt
		keys[#keys + 1] = e.key
		if not IsHidden(self, chain, keys) then
			if e.opt.type == "group" then
				if IsInline(e.opt) then
					self:RenderInline(layout, chain, keys, e)
				else
					tinsert(subgroups, e)
				end
			else
				local ok, err = pcall(self.RenderOption, self, layout, chain, keys, e)
				if not ok then geterrorhandler()(err) end
			end
		end
		chain[#chain] = nil
		keys[#keys] = nil
	end

	if #subgroups == 0 then return end
	local mode = group.childGroups or "tree"
	if mode == "tree" and (excludeTreeChildren or (#keys > 0 and #keys < 3 and top)) then return end

	local pathKey = table.concat(keys, ".")
	self.tabSel = self.tabSel or {}
	local selKey = self.tabSel[pathKey]
	local found
	for _, e in ipairs(subgroups) do if e.key == selKey then found = e end end
	found = found or subgroups[1]
	self.tabSel[pathKey] = found.key

	if mode == "select" then
		layout:Section()
		local sel = Acquire(self, "select", layout.parent)
		sel.text:SetText("Afficher")
		sel.tipText = nil
		sel.preview = nil
		sel.items = {}
		for _, e in ipairs(subgroups) do tinsert(sel.items, { value = e.key, text = ns:Brand(e.name) }) end
		sel.onChange = function(v) self.tabSel[pathKey] = v self:Refresh(true) end
		sel:SetCurrent(found.key)
		sel:SetDisabled(false)
		layout:PlaceItem(sel, false)
		layout:Section()
	else
		local tabs = Acquire(self, "tabs", layout.parent)
		local list = {}
		for _, e in ipairs(subgroups) do tinsert(list, { key = e.key, text = ns:Brand(e.name) }) end
		layout:EndRow()
		layout.y = layout.y + 14
		tabs:SetPoint("TOPLEFT", layout.parent, "TOPLEFT", layout.x0, -layout.y)
		tabs:SetWidth(layout.width)
		local h = tabs:Build(list, found.key, function(k) self.tabSel[pathKey] = k self:Refresh(true) end)
		layout.y = layout.y + h + 10
		layout:Section()
	end

	chain[#chain + 1] = found.opt
	keys[#keys + 1] = found.key
	self:RenderGroup(layout, chain, keys, false, false)
	chain[#chain] = nil
	keys[#keys] = nil
end

-- Groupe en ligne = section (titre + réglages)
function View:RenderInline(layout, chain, keys, e)
	local title = Text(self, chain, keys, "name")
	if title and title ~= "" then
		self:RenderHeader(layout, title)
	else
		layout:Section()
		layout.y = layout.y + 10
	end
	self:RenderGroup(layout, chain, keys, false, false)
	layout:Section()
end

function View:RenderHeader(layout, title)
	local h = Acquire(self, "header", layout.parent)
	h.text:SetText(title or "")
	layout:Section()
	layout:PlaceBlock(h, 32, layout.y > 0 and 16 or 0, 10)
end

function View:RenderDescription(layout, text, size, image, imgW, imgH, coords)
	local d = Acquire(self, "description", layout.parent)
	local fontSize = (size == "large" and 16) or (size == "medium" and 14) or 13
	ns:Font(d.text, fontSize)
	ns.SetTextColorC(d.text, (size == "large") and C.text or C.muted)
	local x = 0
	if image then
		d.icon:SetTexture(image)
		d.icon:SetSize(imgW or 24, imgH or 24)
		if coords then d.icon:SetTexCoord(unpack(coords)) else d.icon:SetTexCoord(0, 1, 0, 1) end
		d.icon:ClearAllPoints()
		d.icon:SetPoint("TOPLEFT")
		d.icon:Show()
		x = (imgW or 24) + 10
	else
		d.icon:Hide()
	end
	d.text:ClearAllPoints()
	d.text:SetPoint("TOPLEFT", x, 0)
	d.text:SetWidth(layout.width - x)
	d.text:SetText(text)
	local h = max(d.text:GetHeight(), image and (imgH or 24) or 0)
	layout:PlaceBlock(d, h + 2, 8, 10)
	return d
end

StaticPopupDialogs["EASYUI_OPTION_CONFIRM"] = {
	text = "%s",
	button1 = YES,
	button2 = NO,
	OnAccept = function(self, data) if data then data() end end,
	timeout = 0, whileDead = 1, hideOnEscape = 1, showAlert = 1,
}

local function WithConfirm(view, chain, keys, action)
	local confirm = Inherited(chain, "confirm")
	if confirm then
		local text = Call(view, chain, keys, confirm)
		if text then
			if type(text) ~= "string" then
				text = chain[#chain].confirmText or Text(view, chain, keys, "name")
			end
			local dlg = StaticPopup_Show("EASYUI_OPTION_CONFIRM", ns:Brand(text))
			if dlg then dlg.data = action end
			return
		end
	end
	action()
end

local function Validate(view, chain, keys, ...)
	local v = Inherited(chain, "validate")
	if not v then return true end
	local res = Call(view, chain, keys, v, ...)
	if type(res) == "string" then
		ns:Print("|cffff5555%s|r", ns:Brand(res))
		return false
	end
	return res ~= false
end

function View:RenderOption(layout, chain, keys, e)
	local opt = e.opt
	local t = opt.type
	local name = Text(self, chain, keys, "name")
	local desc = Text(self, chain, keys, "desc")
	local width = Member(self, chain, keys, "width")
	local disabled = IsDisabled(self, chain, keys)
	local ck, cc = Copy(keys), Copy(chain)
	local setter = Inherited(chain, "set")
	local pathKey = table.concat(keys, ".")

	local function Set(...)
		if not Validate(self, cc, ck, ...) then self:Changed() return end
		local args = { ... }
		local n = select("#", ...)
		WithConfirm(self, cc, ck, function()
			if setter then Call(self, cc, ck, setter, unpack(args, 1, n)) end
			self:Changed()
		end)
	end
	local function Get(...)
		local getter = Inherited(cc, "get")
		if getter == nil then return end
		return Call(self, cc, ck, getter, ...)
	end
	local function Remember(bg) self.positions[pathKey] = { y = layout.y, bg = bg } end

	if t == "header" then
		if name and name ~= "" then
			self:RenderHeader(layout, name)
		else
			layout:Section()
			layout.y = layout.y + 14
		end

	elseif t == "description" then
		local img, iw, ih, coords
		if opt.image then
			img, iw, ih = Member(self, chain, keys, "image")
			iw = iw or opt.imageWidth
			ih = ih or opt.imageHeight
			coords = opt.imageCoords
		end
		if name and name ~= "" then self:RenderDescription(layout, name, opt.fontSize, img, iw, ih, coords) end

	elseif t == "toggle" then
		local w = Acquire(self, "toggle", layout.parent)
		w.text:SetText(name)
		w.tipTitle, w.tipText = name, desc
		w:SetValue(Get(), opt.tristate)
		w:SetDisabled(disabled)
		w.onToggle = function()
			local cur = Get()
			local nv
			if opt.tristate then
				if cur then nv = nil elseif cur == nil then nv = false else nv = true end
			else
				nv = not cur
			end
			Set(nv)
		end
		Remember(layout:PlaceItem(w, IsHalf(layout, opt, width)))

	elseif t == "range" then
		local w = Acquire(self, "range", layout.parent)
		w.text:SetText(name)
		w.tipTitle, w.tipText = name, desc
		local lo = Member(self, chain, keys, "min") or 0
		local hi = Member(self, chain, keys, "max") or 100
		w:Setup(lo, hi, opt.softMin, opt.softMax, opt.step, opt.bigStep, opt.isPercent, tonumber(Get()) or lo)
		w:SetDisabled(disabled)
		w.onChange = function(v) Set(v) end
		Remember(layout:PlaceItem(w, IsHalf(layout, opt, width)))

	elseif t == "select" then
		local w = Acquire(self, "select", layout.parent)
		w.text:SetText(name)
		w.tipTitle, w.tipText = name, desc
		local values = Member(self, chain, keys, "values") or {}
		local dc = opt.dialogControl
		w.preview = (dc == "LSM30_Statusbar" and "statusbar") or (dc == "LSM30_Font" and "font") or nil
		local items = {}
		for k, v in pairs(values) do
			local label = type(v) == "string" and v or tostring(k)
			local extra
			if w.preview then extra = v label = tostring(k) end
			tinsert(items, { value = k, text = ns:Brand(label), extra = extra })
		end
		if opt.sorting then
			local order = {}
			for i, k in ipairs(type(opt.sorting) == "function" and opt.sorting() or opt.sorting) do order[k] = i end
			tsort(items, function(a, b) return (order[a.value] or 999) < (order[b.value] or 999) end)
		else
			tsort(items, function(a, b) return tostring(a.text) < tostring(b.text) end)
		end
		w.items = items
		w:SetCurrent(Get())
		w:SetDisabled(disabled)
		w.onChange = function(v) Set(v) end
		Remember(layout:PlaceItem(w, IsHalf(layout, opt, width)))

	elseif t == "multiselect" then
		self:RenderHeader(layout, name)
		local values = Member(self, chain, keys, "values") or {}
		local list = {}
		for k, v in pairs(values) do tinsert(list, { key = k, text = tostring(v) }) end
		tsort(list, function(a, b) return a.text < b.text end)
		for _, it in ipairs(list) do
			local w = Acquire(self, "toggle", layout.parent)
			w.text:SetText(ns:Brand(it.text))
			w.tipTitle, w.tipText = it.text, desc
			w:SetValue(Get(it.key), opt.tristate)
			w:SetDisabled(disabled)
			w.onToggle = function() Set(it.key, not Get(it.key)) end
			layout:PlaceItem(w, layout.width >= HALF_SMALL)
		end
		layout:Section()

	elseif t == "color" then
		local w = Acquire(self, "color", layout.parent)
		w.text:SetText(name)
		w.tipTitle, w.tipText = name, desc
		w.hasAlpha = opt.hasAlpha
		w:SetColor(Get())
		w:SetDisabled(disabled)
		w.onChange = function(r, g, b, a)
			if setter then Call(self, cc, ck, setter, r, g, b, a) end
			if self.appName then
				local ACR = ns:GetLib("AceConfigRegistry-3.0")
				if ACR and ACR:GetOptionsTable(self.appName) then
					self.selfNotify = true
					ACR:NotifyChange(self.appName)
					self.selfNotify = nil
				end
			end
		end
		Remember(layout:PlaceItem(w, IsHalf(layout, opt, width)))

	elseif t == "input" then
		local w = Acquire(self, "input", layout.parent)
		w.text:SetText(name)
		w.tipTitle, w.tipText = name, desc
		local v = Get()
		w.value = v ~= nil and tostring(v) or ""
		w.edit:SetText(w.value)
		w.edit:SetCursorPosition(0)
		w:SetDisabled(disabled)
		w.onChange = function(text) Set(text) end
		local half = IsHalf(layout, opt, width) and not opt.multiline
		w:SetFieldWidth(half and 150 or max(200, floor(layout.width * 0.5)))
		Remember(layout:PlaceItem(w, half))

	elseif t == "execute" then
		local f = Acquire(self, "execute", layout.parent)
		local b = f.button
		b:SetLabel(name)
		b.tipTitle, b.tipText = name, desc
		if disabled then b:Disable() else b:Enable() end
		local func = Inherited(chain, "func")
		b:SetScript("OnClick", function()
			WithConfirm(self, cc, ck, function()
				if func then Call(self, cc, ck, func) end
				self:Changed()
			end)
		end)
		Remember(layout:PlaceItem(f, IsHalf(layout, opt, width)))

	elseif t == "keybinding" then
		self:RenderDescription(layout, (name or "") .. " : |cffffffff" .. (Get() or "-") .. "|r")
	end
end

----------------------------------------------------------------
-- Recherche : index des réglages de la vue
----------------------------------------------------------------
function View:Index()
	local root = self:GetRoot()
	local out = {}
	if not root then return out end
	local chain, keys, trail, groupKeys = { root }, {}, {}, {}
	local function walk()
		for _, e in ipairs(SortedArgs(self, chain, keys)) do
			chain[#chain + 1] = e.opt
			keys[#keys + 1] = e.key
			if not IsHidden(self, chain, keys) then
				if e.opt.type == "group" then
					local inline = IsInline(e.opt)
					if not inline then
						tinsert(trail, e.name)
						tinsert(groupKeys, e.key)
					end
					walk()
					if not inline then
						tremove(trail)
						tremove(groupKeys)
					end
				elseif e.opt.type ~= "header" and e.opt.type ~= "description" and e.name ~= "" then
					tinsert(out, {
						name = e.name,
						desc = Text(self, chain, keys, "desc"),
						trail = table.concat(trail, "  >  "),
						keys = Copy(groupKeys),
						full = table.concat(keys, "."),
					})
				end
			end
			chain[#chain] = nil
			keys[#keys] = nil
		end
	end
	pcall(walk)
	return out
end

-- Ouvre le groupe d'un réglage et le met en évidence
function View:Reveal(groupKeys, fullKey)
	ns.db.optionPaths = ns.db.optionPaths or {}
	ns.db.optionPaths[self.key] = Copy(groupKeys)
	self.tabSel = self.tabSel or {}
	for i = 1, #groupKeys do
		local parent = {}
		for j = 1, i - 1 do parent[j] = groupKeys[j] end
		self.tabSel[table.concat(parent, ".")] = groupKeys[i]
	end
	self.highlight = fullKey
	self:Refresh()
end

ns:On("ACCENT_CHANGED", function()
	for _, v in ipairs(ns.optionViews or {}) do
		if v.parent:IsVisible() then v:Refresh(true) end
	end
end)
