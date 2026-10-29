--[[
	EasyUI - Assistant de premier lancement
	Couleur d'accent, police, échelle de l'interface et style des modules,
	en une seule fenêtre. Relançable depuis le tableau de bord ou les options.
]]
local _, ns = ...
local C = ns.colors

local SWATCHES = {
	{ 1.00, 0.82, 0.00 }, { 0.10, 0.84, 0.63 }, { 0.20, 0.66, 1.00 }, { 0.64, 0.42, 1.00 },
	{ 1.00, 0.45, 0.62 }, { 1.00, 0.55, 0.15 }, { 0.95, 0.30, 0.30 }, { 0.85, 0.87, 0.92 },
}

local wizard
local choice = {}

local function Section(parent, y, text)
	local h = ns:CreateHeader(parent, text)
	h:SetPoint("TOPLEFT", 30, y)
	h:SetPoint("RIGHT", parent, "RIGHT", -30, 0)
	return h
end

local function Build()
	local f = CreateFrame("Frame", "EasyUISetup", UIParent)
	f:SetSize(620, 560)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	ns:SetBackdrop(f, C.bg, { 1, 1, 1, 0.08 })
	f:Hide()
	tinsert(UISpecialFrames, "EasyUISetup")

	local shadow = CreateFrame("Frame", nil, f)
	shadow:SetPoint("TOPLEFT", -8, 8)
	shadow:SetPoint("BOTTOMRIGHT", 8, -8)
	shadow:SetFrameLevel(math.max(0, f:GetFrameLevel() - 1))
	shadow:SetBackdrop({ bgFile = ns.media.white })
	shadow:SetBackdropColor(0, 0, 0, 0.5)

	local glow = ns:CreateTex(f, "BORDER")
	glow:SetHeight(120)
	glow:SetPoint("TOPLEFT", 1, -1)
	glow:SetPoint("TOPRIGHT", -1, -1)
	ns:RegisterAccent(glow, function(t, r, g, b) t:SetGradientAlpha("VERTICAL", r, g, b, 0, r, g, b, 0.12) end)

	local logo = ns:CreateText(f, 30, C.text)
	logo:SetPoint("TOPLEFT", 30, -28)
	local function UpdateLogo() logo:SetText(("Bienvenue dans |cff%sEasy|rUI"):format(ns:AccentHex())) end
	UpdateLogo()
	ns:On("ACCENT_CHANGED", UpdateLogo)
	local sub = ns:CreateText(f, 13, C.muted)
	sub:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 1, -8)
	sub:SetText("Quelques choix rapides pour démarrer. Tout se modifie ensuite dans le panneau (/eui).")

	-- Couleur d'accent
	Section(f, -110, "Couleur d'accent")
	f.swatches = {}
	for i, c in ipairs(SWATCHES) do
		local b = CreateFrame("Button", nil, f)
		b:SetSize(36, 36)
		b:SetPoint("TOPLEFT", 30 + (i - 1) * 46, -146)
		local ring = ns:CreateTex(b, "BACKGROUND", nil, ns.media.ring)
		ring:SetAllPoints()
		ring:SetVertexColor(1, 1, 1, 0)
		b.ring = ring
		local dot = ns:CreateTex(b, "ARTWORK", { c[1], c[2], c[3], 1 }, ns.media.circle)
		dot:SetPoint("TOPLEFT", 5, -5)
		dot:SetPoint("BOTTOMRIGHT", -5, 5)
		b:SetScript("OnClick", function()
			choice.classColor = false
			ns.db.useClassColor = false
			ns.db.accent = { r = c[1], g = c[2], b = c[3] }
			ns:UpdateAccent()
			f:RefreshSwatches()
		end)
		b.color = c
		f.swatches[i] = b
	end
	local classBtn = ns:CreateCheck(f, "Couleur de ma classe",
		function() return ns.db.useClassColor end,
		function(v) ns.db.useClassColor = v ns:UpdateAccent() f:RefreshSwatches() end)
	classBtn:SetPoint("TOPLEFT", 30 + #SWATCHES * 46 + 6, -152)
	f.classBtn = classBtn

	function f:RefreshSwatches()
		local a = ns.db.accent
		for _, b in ipairs(self.swatches) do
			local c = b.color
			local sel = not ns.db.useClassColor and math.abs(c[1] - a.r) < 0.02 and math.abs(c[2] - a.g) < 0.02 and math.abs(c[3] - a.b) < 0.02
			b.ring:SetVertexColor(1, 1, 1, sel and 0.9 or 0)
		end
		self.classBtn:Refresh()
	end

	-- Police
	Section(f, -196, "Police de l'interface")
	local fontDD = ns:CreateDropdown(f, 260,
		function()
			local t = {}
			for _, ft in ipairs(ns.fonts) do table.insert(t, { value = ft.key, text = ft.name }) end
			return t
		end,
		function() return choice.font or ns.db.font or ns.DEFAULT_FONT end,
		function(v) choice.font = v f:UpdateFontPreview() end)
	fontDD:SetPoint("TOPLEFT", 30, -232)
	local preview = f:CreateFontString(nil, "OVERLAY")
	preview:SetPoint("LEFT", fontDD, "RIGHT", 18, 0)
	preview:SetFont(ns.media.font, 14)
	preview:SetTextColor(1, 1, 1, 0.85)
	preview:SetText("Barres, sacs, recharges : tout EasyUI")
	function f:UpdateFontPreview()
		local key = choice.font or ns.db.font or ns.DEFAULT_FONT
		for _, ft in ipairs(ns.fonts) do
			if ft.key == key then preview:SetFont(ft.path, 14 + ft.boost) end
		end
	end

	-- Échelle
	Section(f, -276, "Échelle de l'interface")
	local scaleInfo = ns:CreateText(f, 12, C.muted)
	scaleInfo:SetPoint("TOPLEFT", 30, -314)
	scaleInfo:SetPoint("RIGHT", f, "RIGHT", -30, 0)
	local pixel = ns:CreateButton(f, "Pixel perfect (recommandé)", 220, 30)
	pixel:SetPoint("TOPLEFT", 30, -336)
	local keep = ns:CreateButton(f, "Garder l'échelle actuelle", 200, 30)
	keep:SetPoint("LEFT", pixel, "RIGHT", 10, 0)
	function f:RefreshScale()
		pixel:SetStyle(choice.pixel and "accent" or "normal")
		keep:SetStyle(choice.pixel and "normal" or "accent")
		local h = tonumber((GetCVar("gxResolution") or ""):match("%d+x(%d+)"))
		local target = h and math.max(0.64, math.min(1, 768 / h)) or 1
		scaleInfo:SetText(("Actuelle : %.2f   -   Pixel perfect pour ta résolution : %.2f"):format(tonumber(GetCVar("uiScale")) or 1, target))
		choice.pixelValue = target
	end
	pixel:SetScript("OnClick", function() choice.pixel = true f:RefreshScale() end)
	keep:SetScript("OnClick", function() choice.pixel = false f:RefreshScale() end)

	-- Style
	Section(f, -384, "Style des modules")
	local styleAll = ns:CreateCheck(f, "Appliquer le style EasyUI (incantation, sacs, recharges)",
		function() return choice.style end, function(v) choice.style = v end)
	styleAll:SetPoint("TOPLEFT", 30, -420)
	local buttons = ns:CreateCheck(f, "Boutons d'action modernes",
		function() return choice.buttons end, function(v) choice.buttons = v end)
	buttons:SetPoint("TOPLEFT", 30, -450)
	f.styleAll, f.buttonsCheck = styleAll, buttons

	-- Pied
	local line = ns:CreateLine(f)
	line:SetPoint("BOTTOMLEFT", 1, 62)
	line:SetPoint("BOTTOMRIGHT", -1, 62)
	local later = ns:CreateButton(f, "Plus tard", 120, 34, function()
		ns.db.setupDone = true
		f:Hide()
	end, "ghost")
	later:SetPoint("BOTTOMLEFT", 30, 14)
	local finish = ns:CreateButton(f, "Terminer", 160, 34, function() ns:FinishSetup() end, "accent")
	finish:SetPoint("BOTTOMRIGHT", -30, 14)

	return f
end

function ns:ShowSetupWizard()
	if InCombatLockdown() then return end
	if not wizard then wizard = Build() end
	choice = {
		font = self.db.font or ns.DEFAULT_FONT,
		pixel = false,
		style = true,
		buttons = self.db.skin.buttons ~= false,
	}
	if self.frame and self.frame:IsShown() then self.frame:Hide() end
	wizard:RefreshSwatches()
	wizard:UpdateFontPreview()
	wizard:RefreshScale()
	wizard.styleAll:Refresh()
	wizard.buttonsCheck:Refresh()
	wizard:Show()
end

function ns:FinishSetup()
	local needReload = false
	local db = self.db
	if choice.font and choice.font ~= (db.font or ns.DEFAULT_FONT) then
		db.font = choice.font
		needReload = true
	end
	if choice.pixel and choice.pixelValue and not InCombatLockdown() then
		SetCVar("useUiScale", "1")
		SetCVar("uiScale", choice.pixelValue)
	end
	if choice.buttons ~= (db.skin.buttons ~= false) then
		db.skin.buttons = choice.buttons
		if choice.buttons then self:SkinActionButtons() else needReload = true end
	end
	if choice.style then
		self:ApplyQuartzTheme()
		self:ApplyBagnonTheme()
		self:ApplyCooldownTheme()
	end
	db.setupDone = true
	if wizard then wizard:Hide() end
	self:Print("Configuration terminée. Ouvre le panneau avec |cffffffff/eui|r.")
	if needReload then self:AskReload() end
end

-- Premier lancement : on propose l'assistant quelques secondes après la connexion
ns:On("LOGIN", function()
	if ns.db.setupDone then return end
	ns:After(4, function()
		if not InCombatLockdown() and not ns.db.setupDone then ns:ShowSetupWizard() end
	end)
end)
