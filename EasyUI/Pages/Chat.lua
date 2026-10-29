--[[
	EasyUI - Page Messagerie
	Chuchotements en fenêtres séparées, historique, règles d'ouverture.
]]
local _, ns = ...

local function W() return _G.WIM end
local function DB() return (W() and W().db) or _G.WIM3_Data end

local PLACES = {
	{ "resting", "En ville / auberge" }, { "other", "Ailleurs (exploration)" }, { "party", "En groupe" },
	{ "raid", "En raid" }, { "pvp", "Champ de bataille" }, { "arena", "Arène" }, { "combat", "En combat" },
}

local function Options()
	local general = { type = "group", name = "Général", order = 1, args = {
		enabled = {
			type = "toggle", name = "Chuchotements en fenêtres séparées", width = "full", order = 1,
			desc = "Désactivé : les chuchotements restent dans la fenêtre de discussion normale.",
			get = function() return DB().enabled end,
			set = function(_, v) if W().SetEnabled then W().SetEnabled(v) else DB().enabled = v end end,
		},
		tooltips = {
			type = "toggle", name = "Infobulles d'aide", order = 2,
			get = function() return DB().showToolTips end,
			set = function(_, v) DB().showToolTips = v end,
		},
		who = {
			type = "toggle", name = "Infos sur l'interlocuteur (niveau, classe, guilde)", order = 3,
			get = function() return DB().whoLookups end,
			set = function(_, v) DB().whoLookups = v end,
		},
		clamp = {
			type = "toggle", name = "Garder les fenêtres dans l'écran", order = 4,
			get = function() return DB().clampToScreen end,
			set = function(_, v) DB().clampToScreen = v end,
		},
		tabsH = { type = "header", name = "Onglets", order = 10 },
		sortBy = {
			type = "select", name = "Ordre des onglets", order = 11,
			values = { [1] = "Ordre d'ouverture", [2] = "Dernière activité", [3] = "Alphabétique" },
			sorting = { 1, 2, 3 },
			get = function() return DB().tabs and DB().tabs.sortBy or 2 end,
			set = function(_, v) DB().tabs.sortBy = v end,
		},
		toolsH = { type = "header", name = "Outils", order = 20 },
		history = { type = "execute", name = "Historique des conversations", order = 21,
			func = function() ns.frame:Hide() if W().ShowHistoryViewer then W().ShowHistoryViewer() end end },
		advanced = { type = "execute", name = "Options avancées", order = 22,
			desc = "Apparence des fenêtres, filtres, sons, alias...",
			func = function() ns.frame:Hide() if W().ShowOptions then W().ShowOptions() end end },
	} }

	local rules = { type = "group", name = "Ouverture des fenêtres", order = 2, childGroups = "tab", args = {} }
	for i, p in ipairs(PLACES) do
		local function R() return DB().pop_rules.whisper[p[1]] end
		rules.args[p[1]] = { type = "group", name = p[2], order = i, args = {
			onReceive = { type = "toggle", name = "Ouvrir quand je reçois un message", width = "full", order = 1,
				get = function() return R().onReceive end, set = function(_, v) R().onReceive = v end },
			onSend = { type = "toggle", name = "Ouvrir quand j'envoie un message", width = "full", order = 2,
				get = function() return R().onSend end, set = function(_, v) R().onSend = v end },
			supress = { type = "toggle", name = "Retirer les chuchotements de la discussion normale", width = "full", order = 3,
				get = function() return R().supress end, set = function(_, v) R().supress = v end },
			autofocus = { type = "toggle", name = "Placer le curseur dans la fenêtre", width = "full", order = 4,
				get = function() return R().autofocus end, set = function(_, v) R().autofocus = v end },
			keepfocus = { type = "toggle", name = "Garder le curseur après l'envoi", width = "full", order = 5,
				get = function() return R().keepfocus end, set = function(_, v) R().keepfocus = v end },
		} }
	end

	local history = { type = "group", name = "Historique", order = 3, args = {
		friends = { type = "toggle", name = "Enregistrer les amis", order = 1,
			get = function() return DB().history.whispers.friends end, set = function(_, v) DB().history.whispers.friends = v end },
		guild = { type = "toggle", name = "Enregistrer la guilde", order = 2,
			get = function() return DB().history.whispers.guild end, set = function(_, v) DB().history.whispers.guild = v end },
		all = { type = "toggle", name = "Enregistrer tout le monde", order = 3,
			get = function() return DB().history.whispers.all end, set = function(_, v) DB().history.whispers.all = v end },
		preview = { type = "toggle", name = "Afficher les derniers messages à l'ouverture", order = 4,
			get = function() return DB().history.preview end, set = function(_, v) DB().history.preview = v end },
		previewCount = { type = "range", name = "Messages affichés", order = 5, min = 1, max = 100, step = 1,
			get = function() return DB().history.previewCount end, set = function(_, v) DB().history.previewCount = v end },
		maxCount = { type = "range", name = "Messages gardés par personne", order = 6, min = 50, max = 2000, step = 50,
			get = function() return DB().history.maxCount end, set = function(_, v) DB().history.maxCount = v end },
	} }

	return { type = "group", name = "Messagerie", args = { general = general, rules = rules, history = history } }
end

ns:RegisterPage({
	key = "chat",
	module = "chat",
	title = "Messagerie",
	subtitle = "Chuchotements en fenêtres façon messagerie instantanée, avec onglets et historique.",
	icon = "Interface\\Icons\\INV_Letter_03",
	group = "modules",
	order = 57,

	build = function(page)
		ns:AddPageAction(page, "Historique", 100, function()
			ns.frame:Hide()
			if W().ShowHistoryViewer then W().ShowHistoryViewer() end
		end)
		page.view = ns:CreateOptionsView(page.body, Options(), { key = "chat" })
	end,
})
