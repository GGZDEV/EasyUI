--[[
	EasyUI - Page Barres de noms
	Les barres de noms sont fournies par le client Ascension (Ascension NamePlates).
	Cette page donne accès à leurs options et aux réglages d'affichage du jeu.
]]
local _, ns = ...

-- cherche la catégorie d'options des barres de noms du client
local function FindPanel()
	for _, panel in ipairs(INTERFACEOPTIONS_ADDONCATEGORIES or {}) do
		local n = (panel.name or ""):lower()
		if n:find("nameplate") or n:find("name plate") or n:find("barres de nom") then return panel end
	end
end

local function OpenPanel()
	local panel = FindPanel()
	if panel then
		ns.frame:Hide()
		InterfaceOptionsFrame_OpenToCategory(panel)
		InterfaceOptionsFrame_OpenToCategory(panel)
		return
	end
	-- sinon : options d'interface du jeu (section barres de noms)
	ns.frame:Hide()
	if InterfaceOptionsFrame_OpenToCategory and InterfaceOptionsNamesPanel then
		InterfaceOptionsFrame_OpenToCategory(InterfaceOptionsNamesPanel)
	end
end

local function CVarToggle(cvar, name, desc, order)
	return {
		type = "toggle", name = name, desc = desc, order = order,
		get = function() return GetCVar(cvar) == "1" end,
		set = function(_, v) if not InCombatLockdown() then pcall(SetCVar, cvar, v and "1" or "0") end end,
	}
end

local function Options()
	return { type = "group", name = "Barres de noms", args = {
		info = { type = "description", order = 0, fontSize = "medium",
			name = "Les barres de noms sont gérées par le module Ascension NamePlates intégré au client. Ses options détaillées s'ouvrent avec le bouton ci-dessous ; les réglages d'affichage du jeu sont ici." },
		open = { type = "execute", name = "Options des barres de noms", order = 1, func = OpenPanel },
		showH = { type = "header", name = "Afficher les barres de", order = 10 },
		enemies = CVarToggle("nameplateShowEnemies", "Ennemis", "Raccourci clavier du jeu : V.", 11),
		friends = CVarToggle("nameplateShowFriends", "Alliés", "Raccourci clavier du jeu : Maj + V.", 12),
		enemyPets = CVarToggle("nameplateShowEnemyPets", "Familiers ennemis", nil, 13),
		enemyGuardians = CVarToggle("nameplateShowEnemyGuardians", "Gardiens ennemis", nil, 14),
		enemyTotems = CVarToggle("nameplateShowEnemyTotems", "Totems ennemis", nil, 15),
		friendlyPets = CVarToggle("nameplateShowFriendlyPets", "Familiers alliés", nil, 16),
		skullH = { type = "header", name = "Tête de mort (va-t-elle mourir ?)", order = 30 },
		skullInfo = { type = "description", order = 31,
			name = "Une petite tête de mort apparaît à gauche de la barre de nom de ta cible quand tes effets sur la durée suffiront à la tuer : inutile de la frapper davantage, passe à la suivante." },
		skull = { type = "toggle", name = "Afficher la tête de mort", order = 32,
			get = function() return ns.db.plates.skull end, set = function(_, v) ns.db.plates.skull = v end },
		skullOnTarget = { type = "toggle", name = "Sur le cadre de cible si pas de barre de nom", order = 33,
			get = function() return ns.db.plates.skullOnTarget end, set = function(_, v) ns.db.plates.skullOnTarget = v end },
		skullSize = { type = "range", name = "Taille", min = 12, max = 56, step = 1, order = 34,
			get = function() return ns.db.plates.skullSize end, set = function(_, v) ns.db.plates.skullSize = v end },
		skullMargin = { type = "range", name = "Prudence", order = 35, min = 0.5, max = 1.5, step = 0.05, isPercent = true,
			desc = "100 % = les dégâts prévus doivent égaler la vie restante. En dessous de 100 %, la tête de mort n'apparaît qu'avec de la marge (plus sûr).",
			get = function() return 2 - ns.db.plates.skullMargin end, set = function(_, v) ns.db.plates.skullMargin = 2 - v end },
		skullX = { type = "range", name = "Décalage horizontal", order = 36, min = -40, max = 40, step = 1,
			desc = "Négatif = plus à gauche de la barre de vie.",
			get = function() return ns.db.plates.skullX or 0 end,
			set = function(_, v) ns.db.plates.skullX = v if ns.Skull then ns.Skull:Reset() ns.Skull:Test() end end },
		skullTest = { type = "execute", name = "Tester sur ma cible", order = 37,
			desc = "Affiche la tête de mort 5 secondes sur la cible actuelle pour vérifier sa position et sa taille.",
			func = function() if ns.Skull then ns.Skull:Test() end end },
		behaviourH = { type = "header", name = "Comportement", order = 20 },
		overlap = CVarToggle("nameplateAllowOverlap", "Autoriser le chevauchement", "Désactivé : les barres s'écartent pour ne pas se superposer.", 21),
	} }
end

ns:RegisterPage({
	key = "nameplates",
	title = "Barres de noms",
	subtitle = "Barres de vie au-dessus des personnages : quelles unités les affichent et accès aux options détaillées.",
	icon = "Interface\\Icons\\Ability_Hunter_SniperShot",
	group = "modules",
	order = 54,

	build = function(page)
		ns:AddPageAction(page, "Options détaillées", 140, OpenPanel, "accent")
		page.view = ns:CreateOptionsView(page.body, Options(), { key = "nameplates" })
	end,
})
