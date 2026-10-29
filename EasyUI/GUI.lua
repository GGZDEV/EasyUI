--[[
	EasyUI - GUI
	Fenêtre principale :
	- bandeau du haut : nom, version, recherche, fermeture
	- colonne de navigation à gauche (icône + nom, sélection dorée)
	- page : titre, actions, aperçu facultatif, onglets, contenu
	- pied de page sur toute la largeur : aide, recharger, mode édition
]]
local _, ns = ...
local C = ns.colors

local WIDTH, HEIGHT = 1200, 780
local HEADER_H = 46
local FOOTER_H = 44
local SIDEBAR_W = 214
local PAD = 22       -- marges horizontales de la page
ns.PAGE_PAD = PAD
local PAD_TOP = 16
local NAV_H = 28

ns.pages = {}
ns.pageList = {}
ns.CONTENT_W = WIDTH - SIDEBAR_W - PAD * 2

local function Line(parent, color, layer)
	local t = ns:CreateTex(parent, layer or "BORDER", color or C.line)
	return t
end

----------------------------------------------------------------
-- Enregistrement des pages
----------------------------------------------------------------
-- def = { key, title, subtitle, icon, group, order, module, build(page), onShow(page), onHide(page) }
function ns:RegisterPage(def)
	def.order = def.order or (#self.pageList + 1) * 10
	self.pages[def.key] = def
	table.insert(self.pageList, def)
	table.sort(self.pageList, function(a, b) return a.order < b.order end)
end

-- le groupe « général » n'a pas de titre (le tableau de bord est seul en haut)
local GROUPS = {
	{ key = "general" },
	{ key = "modules", label = "Modules" },
	{ key = "system",  label = "Système" },
}

----------------------------------------------------------------
-- Barre d'onglets (sous le titre de page)
----------------------------------------------------------------
-- onglet actif : encadré, posé sur le filet ; les autres : texte gris
function ns:StyleTab(b, selected)
	if selected then
		b:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 1)
		b:SetBackdropBorderColor(C.rule[1], C.rule[2], C.rule[3], 1)
		b.cover:Show()
		b.text:SetTextColor(1, 1, 1, 1)
	else
		b:SetBackdropColor(0, 0, 0, 0)
		b:SetBackdropBorderColor(0, 0, 0, 0)
		b.cover:Hide()
		ns.SetTextColorC(b.text, C.soft)
	end
end

function ns:CreateTabButton(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(30)
	ns:SetBackdrop(b, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })
	b.text = ns:CreateText(b, 13, C.soft)
	b.text:SetPoint("CENTER", 0, 0)
	-- masque le filet sous l'onglet actif
	b.cover = ns:CreateTex(b, "OVERLAY", C.bg)
	b.cover:SetHeight(1)
	b.cover:SetPoint("BOTTOMLEFT", 1, 0)
	b.cover:SetPoint("BOTTOMRIGHT", -1, 0)
	b.cover:Hide()
	b:SetScript("OnEnter", function(self) if not self.isSelected then self.text:SetTextColor(1, 1, 1, 1) end end)
	b:SetScript("OnLeave", function(self) if not self.isSelected then ns.SetTextColorC(self.text, C.soft) end end)
	function b:SetSelected(s) self.isSelected = s ns:StyleTab(self, s) end
	return b
end

function ns:CreateTabs(page, tabs, onSelect)
	local bar = CreateFrame("Frame", nil, page)
	bar:SetHeight(30)
	local line = Line(bar, C.rule, "BACKGROUND")
	line:SetHeight(1)
	line:SetPoint("BOTTOMLEFT")
	line:SetPoint("BOTTOMRIGHT")

	bar.buttons = {}
	local prev
	for i, tab in ipairs(tabs) do
		local b = ns:CreateTabButton(bar)
		b.text:SetText(tab.text)
		b:SetWidth(b.text:GetStringWidth() + 28)
		if prev then b:SetPoint("LEFT", prev, "RIGHT", 0, 0) else b:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0) end
		b:SetScript("OnClick", function() bar:Select(i) end)
		b:SetSelected(false)
		bar.buttons[i] = b
		prev = b
	end

	function bar:Select(i)
		if self.selected == i then return end
		self.selected = i
		for j, b in ipairs(self.buttons) do b:SetSelected(j == i) end
		onSelect(i, tabs[i])
	end

	page.tabs = bar
	page:Relayout()
	return bar
end

----------------------------------------------------------------
-- Barre latérale
----------------------------------------------------------------
local function CreateNavButton(parent, def)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(NAV_H)
	ns:SetBackdrop(b, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })

	local icon = ns:CreateIcon(b, 20, def.icon)
	icon:SetPoint("LEFT", 9, 0)
	b.icon = icon

	local fs = ns:CreateText(b, 13, C.nav)
	fs:SetPoint("LEFT", icon, "RIGHT", 9, 0)
	fs:SetPoint("RIGHT", -8, 0)
	fs:SetText(def.title)
	b.text = fs

	local status = ns:CreateText(b, 10, C.dim, nil, "RIGHT")
	status:SetPoint("RIGHT", -8, 0)
	b.status = status

	b.def = def
	b:SetScript("OnClick", function() ns:ShowPage(def.key) end)
	b:SetScript("OnEnter", function(self) self.hover = true self:UpdateLook() end)
	b:SetScript("OnLeave", function(self) self.hover = nil self:UpdateLook() end)

	function b:UpdateState()
		local available = true
		if def.module then
			available = ns:ModuleReady(def.module)
			if not ns:ModuleEnabled(def.module) then
				self.status:SetText("désactivé")
			else
				self.status:SetText(available and "" or "|cffff5555erreur|r")
			end
		end
		self.available = available
		self:UpdateLook()
	end

	function b:UpdateLook()
		if self.selected then
			self:SetBackdropColor(ns:AccentMix(0.08))
			self:SetBackdropBorderColor(ns:AccentMix(0.18))
			local r, g, bb = ns:GetAccent()
			self.text:SetTextColor(r, g, bb, 1)
		else
			if self.hover then
				self:SetBackdropColor(C.hover[1], C.hover[2], C.hover[3], 1)
			else
				self:SetBackdropColor(0, 0, 0, 0)
			end
			self:SetBackdropBorderColor(0, 0, 0, 0)
			if self.available == false then
				ns.SetTextColorC(self.text, C.dim)
			elseif self.hover then
				self.text:SetTextColor(1, 1, 1, 1)
			else
				ns.SetTextColorC(self.text, C.nav)
			end
		end
		local off = self.available == false
		self.icon.tex:SetDesaturated(off and 1 or nil)
		self.icon:SetAlpha(off and 0.4 or 1)
	end

	function b:SetSelected(s)
		self.selected = s
		self:UpdateLook()
	end
	return b
end

----------------------------------------------------------------
-- Recherche globale (champ dans le bandeau, résultats sur la page)
----------------------------------------------------------------
local function BuildSearch(f, header)
	local box = ns:CreateEditBox(header, 220, 26)
	box:SetPoint("RIGHT", f.closeButton, "LEFT", -14, 0)
	ns:Font(box, 13)
	local hint = ns:CreateText(box, 13, C.dim)
	hint:SetPoint("LEFT", 8, 0)
	hint:SetText("Rechercher…")
	box.hint = hint
	f.searchBox = box

	-- panneau de résultats (par-dessus la page)
	local res = CreateFrame("Frame", nil, f.content)
	res:SetAllPoints()
	res:SetFrameLevel(f.content:GetFrameLevel() + 50)
	ns:SetBackdrop(res, { C.bg[1], C.bg[2], C.bg[3], 1 }, { 0, 0, 0, 0 })
	res:EnableMouse(true)
	res:Hide()
	f.searchResults = res

	local title = ns:CreateText(res, 19, C.text)
	title:SetPoint("TOPLEFT", PAD, -PAD_TOP - 4)
	res.title = title
	local sub = ns:CreateText(res, 12, C.muted)
	sub:SetPoint("LEFT", title, "RIGHT", 12, 0)
	res.sub = sub

	local area = ns:CreateScrollArea(res)
	area:SetPoint("TOPLEFT", PAD, -PAD_TOP - 44)
	area:SetPoint("BOTTOMRIGHT", -PAD, 14)
	res.area = area
	res.rows = {}

	local ROW = 40
	local function Render(text)
		local results = ns:Search(text)
		res.title:SetText(("Résultats pour « %s »"):format(text))
		res.sub:SetText(#results == 0 and "aucun réglage trouvé" or (#results .. " réglage(s)"))
		for _, r in ipairs(res.rows) do r:Hide() end
		for i, item in ipairs(results) do
			if i > 120 then break end
			local row = res.rows[i]
			if not row then
				row = CreateFrame("Button", nil, area.child)
				row:SetHeight(ROW)
				local line = Line(row, { 0.114, 0.114, 0.125, 1 })
				line:SetHeight(1)
				line:SetPoint("BOTTOMLEFT")
				line:SetPoint("BOTTOMRIGHT")
				local hl = ns:CreateTex(row, "HIGHLIGHT", C.hover)
				hl:SetAllPoints()
				row.icon = ns:CreateIcon(row, 20)
				row.icon:SetPoint("LEFT", 10, 0)
				row.name = ns:CreateText(row, 13, C.bright)
				row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 12, 3)
				row.path = ns:CreateText(row, 11, C.muted)
				row.path:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
				res.rows[i] = row
			end
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", area.child, "TOPLEFT", 0, -(i - 1) * ROW)
			row:SetPoint("RIGHT", area.child, "RIGHT", 0, 0)
			row.icon.tex:SetTexture(item.icon)
			row.name:SetText(item.name)
			row.path:SetText(item.path)
			row:SetScript("OnClick", function()
				box:SetText("")
				box:ClearFocus()
				ns:RevealSearchResult(item)
			end)
			row:Show()
		end
		area:SetContentHeight(math.min(#results, 120) * ROW)
		area:SetScrollValue(0)
	end

	box:SetScript("OnTextChanged", function(self)
		local text = (self:GetText() or ""):trim()
		ns.SetShown(self.hint, text == "" and not self:HasFocus())
		if #text >= 2 then
			Render(text)
			res:Show()
		else
			res:Hide()
		end
	end)
	box:HookScript("OnEditFocusGained", function(self) self.hint:Hide() end)
	box:HookScript("OnEditFocusLost", function(self) ns.SetShown(self.hint, (self:GetText() or "") == "") end)
	box:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() end)
end

----------------------------------------------------------------
-- Construction de la fenêtre
----------------------------------------------------------------
function ns:CreateMainFrame()
	if self.frame then return self.frame end

	local f = CreateFrame("Frame", "EasyUIFrame", UIParent)
	f:SetSize(WIDTH, HEIGHT)
	f:SetFrameStrata("HIGH")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", function()
		f:StopMovingOrSizing()
		local point, _, relPoint, x, y = f:GetPoint()
		ns.db.point = { point, relPoint, x, y }
	end)
	f:Hide()
	-- bord noir + liseré intérieur gris
	ns:SetBackdrop(f, C.bg, { 0, 0, 0, 1 })
	local edge = CreateFrame("Frame", nil, f)
	edge:SetPoint("TOPLEFT", 1, -1)
	edge:SetPoint("BOTTOMRIGHT", -1, 1)
	edge:SetBackdrop({ edgeFile = ns.media.white, edgeSize = 1 })
	edge:SetBackdropBorderColor(C.frameEdge[1], C.frameEdge[2], C.frameEdge[3], 1)
	tinsert(UISpecialFrames, "EasyUIFrame")
	self.frame = f

	-- ombre
	local shadow = CreateFrame("Frame", nil, f)
	shadow:SetPoint("TOPLEFT", -6, 6)
	shadow:SetPoint("BOTTOMRIGHT", 6, -6)
	shadow:SetFrameLevel(math.max(0, f:GetFrameLevel() - 1))
	shadow:SetBackdrop({ bgFile = ns.media.white })
	shadow:SetBackdropColor(0, 0, 0, 0.45)

	------------------------------------------------------------ bandeau du haut
	local header = CreateFrame("Frame", nil, f)
	header:SetPoint("TOPLEFT", 2, -2)
	header:SetPoint("TOPRIGHT", -2, -2)
	header:SetHeight(HEADER_H - 2)
	local hline = Line(header)
	hline:SetHeight(1)
	hline:SetPoint("BOTTOMLEFT")
	hline:SetPoint("BOTTOMRIGHT")
	f.header = header

	local logo = ns:CreateText(header, 18, { 1, 1, 1, 1 })
	logo:SetPoint("LEFT", 14, 0)
	logo:SetText("EasyUI")
	local ver = ns:CreateText(header, 11, C.dim)
	ver:SetPoint("BOTTOMLEFT", logo, "BOTTOMRIGHT", 8, 1)
	ver:SetText("v" .. ns.version)

	local close = ns:CreateButton(header, "×", 28, 28, function() f:Hide() end)
	close:SetPoint("RIGHT", -10, 0)
	ns:Font(close.text, 16)
	ns.SetTextColorC(close.text, C.soft)
	f.closeButton = close

	------------------------------------------------------------ pied de page
	local footer = CreateFrame("Frame", nil, f)
	footer:SetPoint("BOTTOMLEFT", 2, 2)
	footer:SetPoint("BOTTOMRIGHT", -2, 2)
	footer:SetHeight(FOOTER_H - 2)
	local fbg = ns:CreateTex(footer, "BACKGROUND", C.footer)
	fbg:SetAllPoints()
	local fline = Line(footer)
	fline:SetHeight(1)
	fline:SetPoint("TOPLEFT")
	fline:SetPoint("TOPRIGHT")
	f.footer = footer

	local edit = ns:CreateButton(footer, "Mode édition", nil, 28, function() ns:ToggleEditMode() end, "accent")
	edit:SetPoint("RIGHT", -10, 0)
	ns:AttachTooltip(edit, "Mode édition", "Rend toute l'interface déplaçable : barres, incantation, sacs, cadres Blizzard. Grille d'alignement incluse.")
	f.editButton = edit

	local reload = ns:CreateButton(footer, "Recharger l'interface", nil, 28, function() ReloadUI() end)
	reload:SetPoint("RIGHT", edit, "LEFT", -10, 0)

	local tip = ns:CreateText(footer, 12, C.dim)
	tip:SetPoint("LEFT", 14, 0)
	tip:SetText("|cffbdbdbd/eui|r ouvre cette fenêtre  ·  |cffbdbdbd/eui edit|r passe en mode édition")

	------------------------------------------------------------ barre latérale
	local side = CreateFrame("Frame", nil, f)
	side:SetWidth(SIDEBAR_W)
	side:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
	side:SetPoint("BOTTOMLEFT", footer, "TOPLEFT", 0, 0)
	local sline = Line(side)
	sline:SetWidth(1)
	sline:SetPoint("TOPRIGHT")
	sline:SetPoint("BOTTOMRIGHT")
	f.side = side

	------------------------------------------------------------ contenu
	local content = CreateFrame("Frame", nil, f)
	content:SetPoint("TOPLEFT", side, "TOPRIGHT", 0, 0)
	content:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 0)
	f.content = content

	BuildSearch(f, header)

	f.navButtons = {}
	local y = -6
	for _, group in ipairs(GROUPS) do
		local first = true
		for _, def in ipairs(self.pageList) do
			if (def.group or "modules") == group.key then
				if first and group.label then
					local gl = ns:CreateText(side, 11, C.text)
					gl:SetPoint("TOPLEFT", 18, y - 14)
					gl:SetText(group.label:upper())
					ns:RegisterAccent(gl, "text")
					y = y - 32
				end
				first = false
				local b = CreateNavButton(side, def)
				b:SetPoint("TOPLEFT", 8, y)
				b:SetPoint("TOPRIGHT", -9, y)
				f.navButtons[def.key] = b
				y = y - NAV_H - 1
			end
		end
	end

	f:SetScript("OnShow", function()
		PlaySound("igMainMenuOpen")
		for _, b in pairs(f.navButtons) do b:UpdateState() end
		local key = ns.pendingPage or ns.currentPage or ns.db.lastPage or "home"
		ns.pendingPage = nil
		ns:ShowPage(key, true)
	end)
	f:SetScript("OnHide", function()
		PlaySound("igMainMenuClose")
		if f.searchBox then f.searchBox:SetText("") f.searchBox:ClearFocus() end
		local page = ns.currentPage and ns.pages[ns.currentPage]
		if page and page.frame and page.onHide then pcall(page.onHide, page.frame) end
	end)
	ns:On("ACCENT_CHANGED", function() for _, b in pairs(f.navButtons) do b:UpdateLook() end end)

	self:RestorePosition()
	return f
end

function ns:RestorePosition()
	local f = self.frame
	f:SetScale(self.db.scale or 1)
	f:ClearAllPoints()
	local p = self.db.point
	if p then
		f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
	else
		f:SetPoint("CENTER")
	end
end

----------------------------------------------------------------
-- Pages
----------------------------------------------------------------
-- Disposition verticale : titre, onglets, aperçu, contenu.
-- inset = colonne de sous-navigation collée à la barre latérale.
local function Relayout(page)
	local x = PAD + (page.inset or 0)
	local ta = page.titleArea
	ta:ClearAllPoints()
	ta:SetPoint("TOPLEFT", page, "TOPLEFT", x, -PAD_TOP)
	ta:SetPoint("TOPRIGHT", page, "TOPRIGHT", -PAD, -PAD_TOP)
	local last, gap = ta, 14
	if page.tabs then
		page.tabs:ClearAllPoints()
		page.tabs:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -10)
		page.tabs:SetPoint("RIGHT", page, "RIGHT", -PAD, 0)
		last, gap = page.tabs, 14
	end
	if page.preview then
		page.preview:ClearAllPoints()
		page.preview:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -gap)
		page.preview:SetPoint("RIGHT", page, "RIGHT", -PAD, 0)
		last, gap = page.preview, 16
	end
	page.body:ClearAllPoints()
	page.body:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -gap)
	page.body:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -PAD, 12)
end

local function BuildPage(def)
	local content = ns.frame.content
	local page = CreateFrame("Frame", nil, content)
	page:SetAllPoints()
	page:Hide()
	page.def = def
	page.Relayout = Relayout

	local titleArea = CreateFrame("Frame", nil, page)
	titleArea:SetHeight(28)
	page.titleArea = titleArea

	local title = ns:CreateText(titleArea, 19, { 1, 1, 1, 1 })
	title:SetPoint("LEFT", 0, 0)
	page.title = title
	function page:SetTitleSuffix(suffix)
		self.titleSuffix = suffix
		if suffix and suffix ~= "" then
			title:SetText(("%s  |cff7d7d7d· %s|r"):format(def.title, suffix))
		else
			title:SetText(def.title)
		end
	end
	page:SetTitleSuffix(nil)
	-- la description complète reste en infobulle sur le titre
	if def.subtitle then
		titleArea:EnableMouse(true)
		titleArea:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT", 0, 0)
			GameTooltip:AddLine(def.title, 1, 1, 1)
			GameTooltip:AddLine(def.subtitle, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		titleArea:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end
	-- ancien champ, gardé pour compatibilité
	page.subtitle = ns:CreateText(titleArea, 12, C.muted)
	page.subtitle:Hide()

	-- actions rapides à droite du titre
	local actions = CreateFrame("Frame", nil, titleArea)
	actions:SetSize(10, 28)
	actions:SetPoint("RIGHT", 0, 0)
	page.actions = actions

	local body = CreateFrame("Frame", nil, page)
	body.page = page
	page.body = body
	page:Relayout()

	if def.module and not ns:ModuleReady(def.module) then
		ns:BuildModuleError(page, def)
		return page
	end

	if def.build then
		local ok, err = pcall(def.build, page)
		if not ok then
			local e = ns:CreateText(body, 13, C.bad)
			e:SetPoint("TOPLEFT")
			e:SetPoint("RIGHT")
			e:SetText("Erreur lors de la construction de la page :\n" .. tostring(err))
			geterrorhandler()(err)
		end
	end
	return page
end

function ns:EnsurePageBuilt(def)
	self:CreateMainFrame()
	if not def.frame then def.frame = BuildPage(def) end
	return def.frame
end

-- Bouton d'action en haut à droite d'une page (largeur ajustée au texte)
function ns:AddPageAction(page, text, width, onClick, style)
	local b = ns:CreateButton(page.actions, text, nil, 28, onClick, style)
	local last = page.actions.last
	if last then
		b:SetPoint("RIGHT", last, "LEFT", -10, 0)
	else
		b:SetPoint("RIGHT", page.actions, "RIGHT", 0, 0)
	end
	page.actions.last = b
	return b
end

-- Encart « Aperçu » entre le titre et le contenu
function ns:AddPagePreview(page, height)
	local p = ns:CreateCard(page, 100, height or 56)
	local label = ns:CreateText(p, 11, C.dim)
	label:SetPoint("LEFT", 16, 0)
	label:SetText("APERÇU")
	p.label = label
	p.area = CreateFrame("Frame", nil, p)
	p.area:SetPoint("TOPLEFT", 92, 0)
	p.area:SetPoint("BOTTOMRIGHT", 0, 0)
	page.preview = p
	page:Relayout()
	return p
end

-- Colonne de sous-navigation : la page se décale à droite de celle-ci
function ns:SetPageInset(page, w)
	if page.inset == w then return end
	page.inset = w
	page:Relayout()
end

function ns:BuildModuleError(page, def)
	if def.module and not ns:ModuleEnabled(def.module) then
		local card = ns:CreateCard(page.body, 520, 150)
		card:SetPoint("TOP", 0, -60)
		local icon = ns:CreateIcon(card, 40, def.icon)
		icon:SetPoint("TOPLEFT", 18, -18)
		icon.tex:SetDesaturated(1)
		local t = ns:CreateText(card, 16, C.text)
		t:SetPoint("TOPLEFT", icon, "TOPRIGHT", 14, -2)
		t:SetText("Module désactivé")
		local d = ns:CreateText(card, 12, C.muted)
		d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -8)
		d:SetPoint("RIGHT", card, "RIGHT", -18, 0)
		d:SetText("Ce module n'est pas chargé : il ne consomme aucune ressource. Active-le pour l'utiliser (rechargement de l'interface).")
		local b = ns:CreateButton(card, "Activer et recharger", 170, 30, function()
			ns.db.modules[def.module] = true
			local m = ns.moduleByKey[def.module]
			if m and m.addon then EnableAddOn(m.addon) end
			ReloadUI()
		end, "accent")
		b:SetPoint("BOTTOMRIGHT", -18, 18)
		return
	end
	local card = ns:CreateCard(page.body, 520, 150)
	card:SetPoint("TOP", 0, -60)
	local icon = ns:CreateIcon(card, 40, def.icon)
	icon:SetPoint("TOPLEFT", 18, -18)
	icon.tex:SetDesaturated(1)
	local t = ns:CreateText(card, 16, C.text)
	t:SetPoint("TOPLEFT", icon, "TOPRIGHT", 14, -2)
	t:SetText("Ce module ne s'est pas chargé")
	local d = ns:CreateText(card, 12, C.muted)
	d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -8)
	d:SetPoint("RIGHT", card, "RIGHT", -18, 0)
	local m = def.module and ns.moduleByKey[def.module]
	local why = m and m.loadError and ("Raison donnée par le jeu : " .. tostring(m.loadError) .. ".\n") or ""
	if m and m.addon and not IsAddOnLoaded(m.addon) then
		why = why .. "Le module " .. m.addon .. " n'est pas chargé : vérifie qu'il est coché dans la liste des addons (écran de sélection du personnage). "
	end
	d:SetText(why .. "Si le problème continue, active l'affichage des erreurs (/console scriptErrors 1), recharge l'interface et note le message affiché.")
	local b = ns:CreateButton(card, "Recharger", 120, 30, function() ReloadUI() end, "accent")
	b:SetPoint("BOTTOMRIGHT", -18, 18)
end

function ns:ShowPage(key, force)
	local f = self:CreateMainFrame()
	local def = self.pages[key] or self.pages.home
	key = def.key

	if f.searchResults then f.searchResults:Hide() end
	if self.currentPage == key and not force and def.frame and def.frame:IsShown() then return end

	local old = self.currentPage and self.pages[self.currentPage]
	if old and old.frame and old ~= def then
		if old.onHide then pcall(old.onHide, old.frame) end
		old.frame:Hide()
	end

	self.currentPage = key
	self.db.lastPage = key

	for k, b in pairs(f.navButtons) do b:SetSelected(k == key) end

	self:EnsurePageBuilt(def)
	def.frame:Show()
	if def.onShow then
		local ok, err = pcall(def.onShow, def.frame)
		if not ok then geterrorhandler()(err) end
	end

	-- onglet demandé par ns:Open(page, onglet)
	local tab = self.pendingTabs and self.pendingTabs[key]
	if tab then
		self.pendingTabs[key] = nil
		if def.frame.tabs then def.frame.tabs:Select(tab) end
	end
end

----------------------------------------------------------------
-- Recherche dans toutes les options
----------------------------------------------------------------
function ns:Search(text)
	text = text:lower()
	local out = {}
	for _, def in ipairs(self.pageList) do
		if def.title:lower():find(text, 1, true) then
			table.insert(out, { page = def.key, name = def.title, path = "Page", icon = def.icon })
		end
		if not def.module or self:ModuleReady(def.module) then
			local page = self:EnsurePageBuilt(def)
			local view = page.view
			if view and view.Index then
				for _, item in ipairs(view:Index()) do
					local hay = (item.name .. " " .. (item.desc or "")):lower()
					if hay:find(text, 1, true) then
						item.page = def.key
						item.icon = def.icon
						item.path = def.title .. (item.trail ~= "" and ("  >  " .. item.trail) or "")
						table.insert(out, item)
					end
				end
			end
		end
	end
	return out
end

function ns:RevealSearchResult(item)
	self:ShowPage(item.page, true)
	local def = self.pages[item.page]
	local page = def and def.frame
	if not page then return end
	-- page à onglets (Click-casting) : les options sont dans le 2e onglet
	if page.tabs and page.optionsTab then page.tabs:Select(page.optionsTab) end
	if page.view and item.keys then page.view:Reveal(item.keys, item.full) end
end

----------------------------------------------------------------
-- Ouverture / fermeture
----------------------------------------------------------------
function ns:Open(page, tab)
	if InCombatLockdown() then
		self.reopenAfterCombat = page or true
		self:Print("Impossible d'ouvrir le panneau en combat, il s'ouvrira à la sortie du combat.")
		return
	end
	if page and tab then
		self.pendingTabs = self.pendingTabs or {}
		self.pendingTabs[page] = tab
	end
	local f = self:CreateMainFrame()
	if f:IsShown() then
		if page then self:ShowPage(page, tab ~= nil) end
	else
		self.pendingPage = page
		f:Show()
	end
end

-- Ouvre une page et va directement au réglage demandé (chemin de groupes)
function ns:OpenOptionsAt(page, keys)
	if InCombatLockdown() then return end
	self:Open(page)
	local def = self.pages[page]
	local p = def and def.frame
	if not p then return end
	if self.frame and self.frame:IsShown() and self.currentPage ~= page then self:ShowPage(page) end
	if p.tabs and p.optionsTab then p.tabs:Select(p.optionsTab) end
	if p.view and keys then p.view:Reveal(keys) end
	PlaySound("igMainMenuOptionCheckBoxOn")
end

function ns:Toggle()
	if self.frame and self.frame:IsShown() then
		self.frame:Hide()
	else
		self:Open()
	end
end

-- Les options des barres sont protégées en combat : on ferme proprement.
ns:On("COMBAT_START", function()
	if ns.frame and ns.frame:IsShown() then
		ns.frame:Hide()
		ns.reopenAfterCombat = true
		ns:Print("Panneau fermé pendant le combat.")
	end
end)

ns:On("COMBAT_END", function()
	if ns.reopenAfterCombat then
		local page = ns.reopenAfterCombat
		ns.reopenAfterCombat = nil
		ns:Open(type(page) == "string" and page or nil)
	end
end)
