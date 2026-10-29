--[[
	EasyUI - Page Temps de recharge
	Chiffres de temps de recharge sur les boutons, objets et auras.
]]
local _, ns = ...
local C = ns.colors

local PERIODS = {
	{ "soon", "Bientôt prêt (< 5 s)" },
	{ "seconds", "Secondes" },
	{ "minutes", "Minutes" },
	{ "hours", "Heures" },
}

local function O() return _G.OmniCC end

local function FontValues()
	local LSM = ns:GetLib("LibSharedMedia-3.0")
	local t = {}
	if LSM then
		for name, path in pairs(LSM:HashTable("font")) do t[name] = path end
	end
	return t
end

-- OmniCC stocke le chemin de police ; le menu montre les noms LSM
local function FontNameFromPath(path)
	for name, p in pairs(FontValues()) do
		if p == path then return name end
	end
end

local function Options()
	local general = { type = "group", name = "Général", order = 1, args = {
		models = {
			type = "toggle", name = "Afficher l'animation de recharge (cadran)", width = "full", order = 1,
			get = function() return O():ShowingCooldownModels() end,
			set = function(_, v) O():SetShowCooldownModels(v) end,
		},
		minDuration = {
			type = "range", name = "Durée minimale affichée", desc = "En secondes.", order = 2, min = 0, max = 30, step = 0.5,
			get = function() return O():GetMinDuration() end,
			set = function(_, v) O():SetMinDuration(v) end,
		},
		minFontSize = {
			type = "range", name = "Taille minimale du texte", desc = "Sous cette taille (petites icônes), le texte est masqué.", order = 3, min = 0, max = 24, step = 1,
			get = function() return O():GetMinFontSize() end,
			set = function(_, v) O():SetMinFontSize(v) end,
		},
		tenths = {
			type = "range", name = "Dixièmes de seconde sous", desc = "0 = jamais.", order = 4, min = 0, max = 10, step = 0.5,
			get = function() return O():GetTenthsDuration() end,
			set = function(_, v) O():SetTenthsDuration(v) end,
		},
		mmss = {
			type = "range", name = "Format MM:SS sous", desc = "En secondes (0 = jamais).", order = 5, min = 0, max = 3600, step = 30, bigStep = 60,
			get = function() return O():GetMMSSDuration() end,
			set = function(_, v) O():SetMMSSDuration(v) end,
		},
		finish = { type = "header", name = "Fin du temps de recharge", order = 10 },
		effect = {
			type = "select", name = "Effet", order = 11,
			values = { none = "Aucun", pulse = "Pulsation", shine = "Éclat" },
			sorting = { "none", "pulse", "shine" },
			get = function() return O():GetSelectedEffectID() end,
			set = function(_, v) O():SetEffect(v) end,
		},
		minEffect = {
			type = "range", name = "Durée minimale pour l'effet", desc = "En secondes.", order = 12, min = 0, max = 600, step = 5,
			get = function() return O():GetMinEffectDuration() end,
			set = function(_, v) O():SetMinEffectDuration(v) end,
		},
	} }

	local text = { type = "group", name = "Texte", order = 2, args = {
		font = {
			type = "select", name = "Police", order = 1, dialogControl = "LSM30_Font",
			values = FontValues,
			get = function() return FontNameFromPath(O():GetFontFace()) or O():GetFontFace() end,
			set = function(_, v) O():SetFontFace(FontValues()[v] or v) end,
		},
		outline = {
			type = "select", name = "Contour", order = 2,
			values = { [""] = "Aucun", OUTLINE = "Fin", THICKOUTLINE = "Épais" },
			sorting = { "", "OUTLINE", "THICKOUTLINE" },
			get = function() return O():GetFontOutline() or "" end,
			set = function(_, v) O():SetFontOutline(v) end,
		},
		size = {
			type = "range", name = "Taille", order = 3, min = 6, max = 36, step = 1,
			get = function() return O():GetFontSize() end,
			set = function(_, v) O():SetFontSize(v) end,
		},
		scale = {
			type = "toggle", name = "Adapter la taille à l'icône", order = 4,
			get = function() return O():ScalingText() end,
			set = function(_, v) O():SetScaleText(v) end,
		},
		styles = { type = "header", name = "Couleur et taille par durée", order = 10 },
	} }
	for i, p in ipairs(PERIODS) do
		text.args["color_" .. p[1]] = {
			type = "color", name = p[2], hasAlpha = true, order = 10 + i * 2,
			get = function() return O():GetPeriodColor(p[1]) end,
			set = function(_, r, g, b, a) O():SetPeriodColor(p[1], r, g, b, a) end,
		}
		text.args["scale_" .. p[1]] = {
			type = "range", name = "Taille relative", order = 11 + i * 2, min = 0.5, max = 2, step = 0.05, isPercent = true,
			get = function() return O():GetPeriodScale(p[1]) end,
			set = function(_, v) O():SetPeriodScale(p[1], v) end,
		}
	end

	local filter = { type = "group", name = "Exclusions", order = 3, args = {
		info = { type = "description", order = 0, fontSize = "medium",
			name = "Les cadres dont le nom correspond à un motif de la liste n'affichent pas de chiffres (ex. « PlayerFrame », « ^Grid »)." },
		use = {
			type = "toggle", name = "Utiliser la liste d'exclusion", width = "full", order = 1,
			get = function() return O():UsingBlacklist() end,
			set = function(_, v) O():SetUseBlacklist(v) end,
		},
		add = {
			type = "input", name = "Ajouter un motif", order = 2,
			get = function() return "" end,
			set = function(_, v) O():AddToBlacklist(v) end,
		},
		list = {
			type = "multiselect", name = "Motifs (décocher pour retirer)", order = 3,
			values = function()
				local t = {}
				for _, pat in ipairs(O():GetBlacklist()) do t[pat] = pat end
				return t
			end,
			get = function() return true end,
			set = function(_, key, v) if not v then O():RemoveFromBlacklist(key) end end,
		},
	} }

	return { type = "group", name = "Temps de recharge", args = { general = general, text = text, filter = filter } }
end

-- Aperçu : quelques icônes avec le texte de recharge aux couleurs choisies
local SAMPLES = {
	{ "Interface\\Icons\\Spell_Frost_IceStorm", "1:05", "minutes" },
	{ "Interface\\Icons\\Spell_Fire_FlameBolt", "48", "seconds" },
	{ "Interface\\Icons\\Spell_Nature_Lightning", "7", "seconds" },
	{ "Interface\\Icons\\Spell_Shadow_ShadowWordPain", "2.4", "soon" },
	{ "Interface\\Icons\\Spell_Holy_Renew", "", nil },
}

local function BuildPreview(page)
	local p = ns:AddPagePreview(page, 64)
	local icons = {}
	local prev
	for i, s in ipairs(SAMPLES) do
		local ic = ns:CreateIcon(p.area, 40, s[1])
		if prev then ic:SetPoint("LEFT", prev, "RIGHT", 16, 0) else ic:SetPoint("LEFT", 0, 0) end
		if s[3] then
			local shade = ns:CreateTex(ic, "OVERLAY", { 0, 0, 0, 0.6 })
			shade:SetPoint("TOPLEFT", 1, -1)
			shade:SetPoint("BOTTOMRIGHT", -1, 1)
			local holder = CreateFrame("Frame", nil, ic)
			holder:SetAllPoints()
			holder:SetFrameLevel(ic:GetFrameLevel() + 2)
			ic.label = holder:CreateFontString(nil, "OVERLAY")
			ic.label:SetPoint("CENTER", 1, 0)
		end
		ic.sample = s
		icons[i] = ic
		prev = ic
	end
	local hint = ns:CreateText(p.area, 12, C.muted)
	hint:SetPoint("LEFT", prev, "RIGHT", 16, 0)
	hint:SetText("couleur et taille selon le temps restant")

	function p:Refresh()
		local o = O()
		for _, ic in ipairs(icons) do
			local s = ic.sample
			if ic.label and s[3] then
				local face = o and o.GetFontFace and o:GetFontFace() or STANDARD_TEXT_FONT
				local size = o and o.GetFontSize and o:GetFontSize() or 18
				local scale = o and o.GetPeriodScale and o:GetPeriodScale(s[3]) or 1
				local outline = o and o.GetFontOutline and o:GetFontOutline() or "OUTLINE"
				if not ic.label:SetFont(face, math.max(8, math.min(26, size * scale)), outline) then
					ic.label:SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
				end
				local r, g, b = 1, 1, 1
				if o and o.GetPeriodColor then r, g, b = o:GetPeriodColor(s[3]) end
				ic.label:SetTextColor(r or 1, g or 1, b or 1, 1)
				ic.label:SetText(s[2])
			end
		end
	end
	return p
end

local TABS = { { key = "general", text = "Général" }, { key = "text", text = "Texte" }, { key = "filter", text = "Exclusions" } }

ns:RegisterPage({
	key = "cooldowns",
	module = "cooldowns",
	title = "Temps de recharge",
	subtitle = "Chiffres de temps de recharge sur les sorts, objets et auras, avec effet en fin de recharge.",
	icon = "Interface\\Icons\\Spell_Holy_BorrowedTime",
	group = "modules",
	order = 35,

	build = function(page)
		local style = ns:AddPageAction(page, "Style EasyUI", nil, function()
			ns:ApplyCooldownTheme()
			if page.cdPreview then page.cdPreview:Refresh() end
		end)
		ns:AttachTooltip(style, "Style EasyUI", "Police, couleurs et effet de fin de recharge au style EasyUI.")

		-- onglets en haut de page : la vue n'affiche que le groupe de l'onglet choisi
		local full = Options()
		local current = TABS[1].key
		local view
		page.view = ns:CreateOptionsView(page.body, function()
			if view and view.indexAll then return full end
			local g = full.args[current]
			return { type = "group", name = g.name, args = g.args }
		end, { key = "cooldowns" })
		view = page.view

		page.tabs = ns:CreateTabs(page, TABS, function(i)
			current = TABS[i].key
			if page.body:IsVisible() then view:Refresh() end
		end)
		page.cdPreview = BuildPreview(page)
		page.tabs:Select(1)

		-- recherche : on indexe tous les onglets, puis on ouvre le bon
		local index, reveal = view.Index, view.Reveal
		function view:Index()
			self.indexAll = true
			local ok, out = pcall(index, self)
			self.indexAll = nil
			return ok and out or {}
		end
		function view:Reveal(keys, fullKey)
			local first = keys and keys[1]
			for i, t in ipairs(TABS) do
				if t.key == first then page.tabs:Select(i) end
			end
			local rest = {}
			for i = 2, #(keys or {}) do rest[#rest + 1] = keys[i] end
			if fullKey and first then fullKey = fullKey:gsub("^" .. first .. "%.", "") end
			reveal(self, rest, fullKey)
		end
		view.onRefresh = function() page.cdPreview:Refresh() end
	end,

	onShow = function(page)
		if page.cdPreview then page.cdPreview:Refresh() end
	end,
})
