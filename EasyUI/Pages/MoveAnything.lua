--[[
	EasyUI - Page Cadres Blizzard
	Déplacer / redimensionner / masquer n'importe quel cadre de l'interface.
]]
local _, ns = ...

local function Move(name)
	if not MovAny then return end
	if InCombatLockdown() then
		ns:Print("Impossible en combat.")
		return
	end
	MovAny:ToggleMove(MovAny:Translate(name) or name)
end

-- faux bouton pour réutiliser les fonctions d'options d'origine
local function Fake(v) return { GetChecked = function() return v end, SetChecked = function() end } end

local OPTIONS = {
	{ "tooltips", "Infobulles dans la liste des cadres", "Maj inverse l'affichage des infobulles." },
	{ "playSound", "Son à l'ouverture de la liste" },
	{ "closeGUIOnEscape", "Échap ferme la liste des cadres" },
	{ "alwaysShowNudger", "Toujours afficher le panneau d'ajustement", "Avec la liste ouverte, le panneau de déplacement fin (flèches) reste affiché." },
	{ "dontSearchFrameNames", "Ne pas chercher dans les noms techniques" },
	{ "noBags", "Ne pas gérer les sacs Blizzard", "À cocher si un autre module déplace les sacs (c'est le cas d'EasyUI)." },
	{ "dontHookCreateFrame", "Ne pas surveiller la création de cadres", "Rechargement nécessaire." },
	{ "squareMM", "Minimap carrée" },
	{ "noMMMW", "Désactiver le zoom de la minimap à la molette", "Rechargement nécessaire." },
}

local function Options()
	local quick = { type = "group", name = "Accès rapide", order = 1, args = {
		info = { type = "description", order = 0, fontSize = "medium",
			name = "Clique sur un cadre pour afficher sa poignée : glisser pour déplacer, coins pour redimensionner, molette pour la transparence, Ctrl + clic droit pour ses options. Re-clique pour retirer la poignée." },
		common = { type = "header", name = "Cadres courants", order = 1 },
	} }
	for i, entry in ipairs(ns.editFrames) do
		quick.args["f" .. i] = {
			type = "execute", name = entry[2], order = 1 + i, width = "half",
			desc = "Cadre : " .. entry[1],
			func = function() Move(entry[1]) end,
		}
	end
	quick.args.byName = { type = "header", name = "Par nom", order = 50 }
	quick.args.name = {
		type = "input", name = "Nom du cadre", order = 51,
		desc = "Nom technique du cadre (ex. PlayerFrame). Utilise « Trouver le nom » pour le connaître.",
		get = function() return "" end,
		set = function(_, v) v = v and v:trim() if v and v ~= "" then Move(v) end end,
	}
	quick.args.fstack = {
		type = "execute", name = "Trouver le nom", order = 52,
		desc = "Affiche le nom du cadre sous la souris. Re-clique pour arrêter.",
		func = function()
			if not IsAddOnLoaded("Blizzard_DebugTools") then LoadAddOn("Blizzard_DebugTools") end
			if FrameStackTooltip_Toggle then FrameStackTooltip_Toggle() end
		end,
	}
	quick.args.list = {
		type = "execute", name = "Liste complète des cadres", order = 53,
		func = function() MovAny:ToggleGUI() end,
	}
	quick.args.tip = { type = "description", order = 60,
		name = "Dans le chat : /move NomDuCadre pour déplacer, /unmove NomDuCadre pour remettre à sa place." }

	local opts = { type = "group", name = "Options", order = 2, args = {
		charSpecific = {
			type = "toggle", name = "Positions propres à ce personnage", order = 1, width = "full",
			desc = "Chaque personnage garde ses propres positions de cadres.",
			get = function() return MoveAnything_UseCharacterSettings and true or false end,
			set = function(_, v)
				if InCombatLockdown() then return end
				MovAny:OnCheckCharacterSpecific(Fake(v))
				if MAOptCharacterSpecific then MAOptCharacterSpecific:SetChecked(v) end
			end,
		},
		rows = {
			type = "range", name = "Lignes dans la liste des cadres", order = 2, min = 2, max = 100, step = 1,
			get = function() return MADB.frameListRows or 18 end,
			set = function(_, v) MovAny:SetNumRows(v) end,
		},
		sep = { type = "header", name = "", order = 3 },
	} }
	for i, o in ipairs(OPTIONS) do
		opts.args[o[1]] = {
			type = "toggle", name = o[2], desc = o[3], order = 3 + i,
			get = function() return MADB[o[1]] and true or false end,
			set = function(_, v) MovAny:OptionCheckboxChecked(Fake(v), o[1]) end,
		}
	end
	opts.args.reset = { type = "header", name = "Réinitialisation", order = 50 }
	opts.args.resetProfile = {
		type = "execute", name = "Réinitialiser ce profil", order = 51,
		confirm = true, confirmText = "Remettre à leur place tous les cadres de ce profil ?",
		func = function() MovAny:ResetProfile() end,
	}
	opts.args.resetAll = {
		type = "execute", name = "Tout réinitialiser", order = 52,
		confirm = true, confirmText = "Tout réinitialiser (cadres et options) ?",
		func = function()
			MovAny:ResetAllFrames()
			if MovAny_OptionsOnShow then MovAny_OptionsOnShow() end
		end,
	}

	return { type = "group", name = "Cadres", args = { quick = quick, options = opts } }
end

ns:RegisterPage({
	key = "moveanything",
	module = "moveanything",
	title = "Cadres Blizzard",
	subtitle = "Déplace, redimensionne, rend transparent ou cache n'importe quel élément de l'interface.",
	icon = "Interface\\Icons\\Ability_Rogue_Sprint",
	group = "modules",
	order = 50,

	build = function(page)
		ns:AddPageAction(page, "Mode édition", 110, function() ns:SetEditMode(true) end, "accent")
		ns:AddPageAction(page, "Liste complète", 110, function() MovAny:ToggleGUI() end)
		page.view = ns:CreateOptionsView(page.body, Options(), { key = "moveanything" })
	end,
})
