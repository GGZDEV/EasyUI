--[[
	EasyUI - Page Cadres d'unité
]]
local _, ns = ...

local UNITS = {
	{ "player", "Joueur" }, { "target", "Cible" }, { "targettarget", "Cible de la cible" },
	{ "focus", "Focus" }, { "pet", "Familier" },
}

local function DB() return ns.db.uf end
local function Apply() if ns.UF then ns.UF:Apply() end end

local function UnitGroup(unit, label, order)
	local function U() return DB().units[unit] end
	local function o(key, def)
		def.get = function() return U()[key] end
		def.set = function(_, v) U()[key] = v Apply() end
		return def
	end
	local args = {
		enabled = o("enabled", { type = "toggle", name = "Afficher ce cadre", order = 1, width = "full" }),
		sizeH = { type = "header", name = "Taille", order = 10 },
		width = o("width", { type = "range", name = "Largeur", min = 60, max = 400, step = 1, order = 11 }),
		height = o("height", { type = "range", name = "Hauteur", min = 14, max = 100, step = 1, order = 12 }),
		powerHeight = o("powerHeight", { type = "range", name = "Barre de ressource (0 = aucune)", min = 0, max = 30, step = 1, order = 13 }),
		portrait = o("portrait", { type = "select", name = "Portrait", order = 14,
			values = { none = "Aucun", left = "À gauche", right = "À droite" }, sorting = { "none", "left", "right" } }),
		textH = { type = "header", name = "Textes", order = 20 },
		fontSize = o("fontSize", { type = "range", name = "Taille du texte", min = 7, max = 20, step = 1, order = 21 }),
		healthText = o("healthText", { type = "select", name = "Texte de vie", order = 22,
			values = { full = "Actuelle / max (%)", current = "Actuelle", percent = "Pourcentage", deficit = "Vie manquante", none = "Aucun" },
			sorting = { "full", "current", "percent", "deficit", "none" } }),
		powerText = o("powerText", { type = "toggle", name = "Valeur de la ressource", order = 23,
			desc = "Affichée si la barre de ressource fait au moins 8 pixels de haut." }),
		showLevel = o("showLevel", { type = "toggle", name = "Niveau (élite, rare...)", order = 24 }),
		colorName = o("colorName", { type = "toggle", name = "Nom à la couleur de classe / réaction", order = 25 }),
	}
	if unit ~= "targettarget" and unit ~= "pet" then
		args.aurasH = { type = "header", name = "Effets", order = 30 }
		args.debuffs = o("debuffs", { type = "range", name = "Effets négatifs affichés", min = 0, max = 24, step = 1, order = 31 })
		args.buffs = o("buffs", { type = "range", name = "Effets positifs affichés", min = 0, max = 24, step = 1, order = 32 })
		args.auraSize = o("auraSize", { type = "range", name = "Taille des icônes", min = 12, max = 40, step = 1, order = 33 })
		args.onlyMine = o("onlyMine", { type = "toggle", name = "Seulement mes effets négatifs", order = 34 })
		args.fadeOthers = o("fadeOthers", { type = "toggle", name = "Atténuer les effets des autres", order = 35 })
	end
	if unit == "target" then
		args.combo = o("combo", { type = "toggle", name = "Points de combo au-dessus du cadre", order = 40 })
	end
	args.posH = { type = "header", name = "Position", order = 50 }
	args.move = { type = "execute", name = "Déplacer (mode édition)", order = 51, func = function() ns:SetEditMode(true) end }
	return { type = "group", name = label, order = order, args = args }
end

local function Options()
	local general = { type = "group", name = "Général", order = 1, args = {
		enabled = { type = "toggle", name = "Utiliser les cadres d'unité EasyUI", width = "full", order = 1,
			get = function() return DB().enabled end,
			set = function(_, v) DB().enabled = v Apply() if not v then ns:AskReload() end end },
		hideBlizzard = { type = "toggle", name = "Masquer les cadres Blizzard remplacés", width = "full", order = 2,
			desc = "Joueur, cible, focus, familier. Les runes et totems restent affichés. Réactiver nécessite un rechargement.",
			get = function() return DB().hideBlizzard end,
			set = function(_, v) DB().hideBlizzard = v if v then Apply() else ns:AskReload() end end },
		lookH = { type = "header", name = "Apparence", order = 10 },
		colorMode = { type = "select", name = "Couleur de la barre de vie", order = 11,
			values = { class = "Classe / réaction", dark = "Sombre (nom coloré)", gradient = "Selon la vie" },
			sorting = { "class", "dark", "gradient" },
			get = function() return DB().colorMode end, set = function(_, v) DB().colorMode = v Apply() end },
		bgAlpha = { type = "range", name = "Opacité du fond", order = 12, min = 0, max = 1, step = 0.05, isPercent = true,
			get = function() return DB().bgAlpha end, set = function(_, v) DB().bgAlpha = v Apply() end },
		previewH = { type = "header", name = "Aperçu", order = 20 },
		preview = { type = "execute", name = "Afficher / masquer l'aperçu", order = 21,
			desc = "Affiche les cadres absents (cible, focus...) pour les régler. Automatique en mode édition.",
			func = function() ns.UF:TogglePreview() end },
	} }
	local args = { general = general }
	for i, u in ipairs(UNITS) do args[u[1]] = UnitGroup(u[1], u[2], 1 + i) end
	return { type = "group", name = "Cadres d'unité", args = args }
end

ns:RegisterPage({
	key = "unitframes",
	module = "unitframes",
	title = "Cadres d'unité",
	subtitle = "Joueur, cible, cible de la cible, focus et familier : barres, portrait, textes, effets, points de combo.",
	icon = "Interface\\Icons\\Achievement_Character_Human_Male",
	group = "modules",
	order = 22,

	build = function(page)
		ns:AddPageAction(page, "Mode édition", 110, function() ns:SetEditMode(true) end, "accent")
		ns:AddPageAction(page, "Aperçu", 70, function() ns.UF:TogglePreview() end)
		page.view = ns:CreateOptionsView(page.body, Options(), { key = "unitframes" })
	end,
})
