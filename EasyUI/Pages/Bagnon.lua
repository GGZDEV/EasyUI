--[[
	EasyUI - Page Sacs
	Réglages des sacs, de la banque, du trousseau et de la banque de guilde.
]]
local _, ns = ...

local FRAMES = {
	{ "inventory", "Inventaire" },
	{ "bank", "Banque" },
	{ "keys", "Trousseau" },
	{ "guildbank", "Banque de guilde" },
}

local EVENTS = {
	{ "bank", "Ouvrir les sacs à la banque" },
	{ "ah", "Ouvrir les sacs à l'hôtel des ventes" },
	{ "vendor", "Ouvrir les sacs chez un marchand" },
	{ "trade", "Ouvrir les sacs pendant un échange" },
	{ "guildbank", "Ouvrir les sacs à la banque de guilde" },
	{ "craft", "Ouvrir les sacs pendant l'artisanat" },
	{ "player", "Ouvrir les sacs avec la fiche personnage" },
}

local SLOT_COLORS = {
	{ "ammo", "Emplacements de munitions" },
	{ "trade", "Emplacements de sacs d'artisanat" },
	{ "shard", "Emplacements de sacs d'âmes" },
	{ "keyring", "Emplacements du trousseau" },
}

local LAYERS = { LOW = "Bas", MEDIUMLOW = "Moyen-bas", MEDIUM = "Moyen", MEDIUMHIGH = "Moyen-haut", HIGH = "Haut", TOPLEVEL = "Au premier plan" }

local function B() return ns:GetAceAddon("Bagnon") end
local function S() return B().Settings end
local function FS(id) return B().FrameSettings:Get(id) end

local function FrameGroup(id, label, order)
	local function fs() return FS(id) end
	local args = {
		look = { type = "header", name = "Apparence", order = 1 },
		color = {
			type = "color", name = "Couleur du fond", hasAlpha = true, order = 2,
			get = function() return fs():GetColor() end,
			set = function(_, r, g, b, a) fs():SetColor(r, g, b, a) end,
		},
		border = {
			type = "color", name = "Couleur de la bordure", hasAlpha = true, order = 3,
			get = function() return fs():GetBorderColor() end,
			set = function(_, r, g, b, a) fs():SetBorderColor(r, g, b, a) end,
		},
		columns = {
			type = "range", name = "Colonnes", min = 4, max = 36, step = 1, order = 4,
			get = function() return fs():GetItemFrameColumns() end,
			set = function(_, v) fs():SetItemFrameColumns(v) end,
		},
		spacing = {
			type = "range", name = "Espacement", min = -16, max = 36, step = 2, order = 5,
			get = function() return fs():GetItemFrameSpacing() end,
			set = function(_, v) fs():SetItemFrameSpacing(v) end,
		},
		scale = {
			type = "range", name = "Échelle", min = 0.5, max = 2, step = 0.05, isPercent = true, order = 6,
			get = function() return fs():GetScale() end,
			set = function(_, v) fs():SetScale(v) end,
		},
		opacity = {
			type = "range", name = "Opacité", min = 0.1, max = 1, step = 0.01, isPercent = true, order = 7,
			get = function() return fs():GetOpacity() end,
			set = function(_, v) fs():SetOpacity(v) end,
		},
		layer = {
			type = "select", name = "Plan d'affichage", order = 8,
			values = function()
				local t = {}
				for _, l in ipairs(fs():GetAvailableLayers()) do t[l] = LAYERS[l] or l end
				return t
			end,
			sorting = { "LOW", "MEDIUMLOW", "MEDIUM", "MEDIUMHIGH", "HIGH", "TOPLEVEL" },
			get = function() return fs():GetLayer() end,
			set = function(_, v) fs():SetLayer(v) end,
		},
		elements = { type = "header", name = "Éléments", order = 20 },
		bagFrame = {
			type = "toggle", name = "Barre des sacs", order = 21,
			get = function() return fs():HasBagFrame() end,
			set = function(_, v) fs():SetHasBagFrame(v) end,
		},
		money = {
			type = "toggle", name = "Argent", order = 22,
			get = function() return fs():HasMoneyFrame() end,
			set = function(_, v) fs():SetHasMoneyFrame(v) end,
		},
		dbo = {
			type = "toggle", name = "Infos (sélecteur de personnage)", order = 23,
			get = function() return fs():HasDBOFrame() end,
			set = function(_, v) fs():SetHasDBOFrame(v) end,
		},
		search = {
			type = "toggle", name = "Bouton de recherche", order = 24,
			get = function() return fs():HasSearchToggle() end,
			set = function(_, v) fs():SetHasSearchToggle(v) end,
		},
		sort = {
			type = "toggle", name = "Bouton de tri", order = 25,
			get = function() return fs():HasSortBtn() end,
			set = function(_, v) fs():SetHasSortBtn(v) end,
		},
		options = {
			type = "toggle", name = "Bouton d'options", order = 26,
			get = function() return fs():HasOptionsToggle() end,
			set = function(_, v) fs():SetHasOptionsToggle(v) end,
		},
		reverse = {
			type = "toggle", name = "Inverser l'ordre des emplacements", order = 27,
			get = function() return fs():IsSlotOrderReversed() end,
			set = function(_, v) fs():SetReverseSlotOrder(v) end,
		},
		bagBreak = {
			type = "toggle", name = "Séparer les sacs", order = 28,
			get = function() return fs():IsBagBreakEnabled() end,
			set = function(_, v) fs():SetBagBreak(v) end,
		},
	}
	return {
		type = "group", name = label, order = order, args = args,
		hidden = function()
			if id == "guildbank" then
				local gb = B():GetModule("GuildBank", true)
				return not (gb and gb:IsEnabled())
			end
		end,
	}
end

local function Options()
	local frames = { type = "group", name = "Fenêtres", order = 2, childGroups = "tab", args = {} }
	for i, f in ipairs(FRAMES) do frames.args[f[1]] = FrameGroup(f[1], f[2], i) end

	local display = { type = "group", name = "Ouverture automatique", order = 3, args = {
		info = { type = "description", order = 0, fontSize = "medium",
			name = "Les sacs s'ouvrent tout seuls dans ces situations (et se ferment à la fin)." },
	} }
	for i, e in ipairs(EVENTS) do
		display.args[e[1]] = {
			type = "toggle", name = e[2], width = "full", order = i,
			get = function() return S():IsFrameShownAtEvent("inventory", e[1]) end,
			set = function(_, v) S():SetShowFrameAtEvent("inventory", e[1], v) end,
		}
	end

	local colors = { type = "group", name = "Couleurs", order = 4, args = {
		quality = {
			type = "toggle", name = "Bordure selon la qualité de l'objet", width = "full", order = 1,
			get = function() return S():HighlightingItemsByQuality() end,
			set = function(_, v) S():SetHighlightItemsByQuality(v) end,
		},
		quest = {
			type = "toggle", name = "Mettre en évidence les objets de quête", width = "full", order = 2,
			get = function() return S():HighlightingQuestItems() end,
			set = function(_, v) S():SetHighlightQuestItems(v) end,
		},
		opacity = {
			type = "range", name = "Intensité de la mise en évidence", min = 0.1, max = 1, step = 0.01, isPercent = true, order = 3,
			get = function() return S():GetHighlightOpacity() end,
			set = function(_, v) S():SetHighlightOpacity(v) end,
		},
		bagType = {
			type = "toggle", name = "Colorer les emplacements selon le type de sac", width = "full", order = 4,
			get = function() return S():ColoringBagSlots() end,
			set = function(_, v) S():SetColorBagSlots(v) end,
		},
		slots = { type = "header", name = "Couleurs des emplacements", order = 10 },
	} }
	for i, c in ipairs(SLOT_COLORS) do
		colors.args["slot_" .. c[1]] = {
			type = "color", name = c[2], order = 10 + i,
			disabled = function() return not S():ColoringBagSlots() end,
			get = function() return S():GetItemSlotColor(c[1]) end,
			set = function(_, r, g, b) S():SetItemSlotColor(c[1], r, g, b) end,
		}
	end

	return {
		type = "group", name = "Sacs",
		args = {
			general = { type = "group", name = "Général", order = 1, args = {
				enable = { type = "header", name = "Fenêtres utilisées", order = 1 },
				inv = {
					type = "toggle", name = "Fenêtre d'inventaire unifiée", order = 2,
					desc = "Rechargement de l'interface nécessaire.",
					get = function() return S():WillFrameBeEnabled("inventory") end,
					set = function(_, v) S():SetEnableFrame("inventory", v) ns:AskReload() end,
				},
				bank = {
					type = "toggle", name = "Fenêtre de banque unifiée", order = 3,
					desc = "Rechargement de l'interface nécessaire.",
					get = function() return S():WillFrameBeEnabled("bank") end,
					set = function(_, v) S():SetEnableFrame("bank", v) ns:AskReload() end,
				},
				keys = {
					type = "toggle", name = "Fenêtre de trousseau", order = 4,
					desc = "Rechargement de l'interface nécessaire.",
					get = function() return S():WillFrameBeEnabled("keys") end,
					set = function(_, v) S():SetEnableFrame("keys", v) ns:AskReload() end,
				},
				guild = {
					type = "toggle", name = "Fenêtre de banque de guilde", order = 5,
					desc = "Remplace la banque de guilde Blizzard. Rechargement nécessaire.",
					get = function() return ns.db.modules.guildbank ~= false end,
					set = function(_, v) ns.db.modules.guildbank = v ns:AskReload() end,
				},
				behavior = { type = "header", name = "Comportement", order = 10 },
				empty = {
					type = "toggle", name = "Afficher le fond des emplacements vides", order = 11,
					get = function() return S():ShowingEmptyItemSlotTextures() end,
					set = function(_, v) S():SetShowEmptyItemSlotTexture(v) end,
				},
				lock = {
					type = "toggle", name = "Verrouiller la position des fenêtres", order = 12,
					get = function() return S():AreFramePositionsLocked() end,
					set = function(_, v) S():SetLockFramePositions(v) end,
				},
				passthrough = {
					type = "toggle", name = "Sacs non affichés : fenêtres Blizzard", order = 13, width = "full",
					desc = "Un sac masqué de la fenêtre unifiée s'ouvre dans sa fenêtre Blizzard d'origine. Rechargement nécessaire.",
					get = function() return S():WillBlizzardBagPassThroughBeEnabled() end,
					set = function(_, v) S():SetEnableBlizzardBagPassThrough(v) ns:AskReload() end,
				},
				theme = { type = "header", name = "Style", order = 20 },
				applyTheme = {
					type = "execute", name = "Appliquer le style EasyUI", order = 21,
					desc = "Fond sombre et bordure fine sur toutes les fenêtres de sacs.",
					func = function() ns:ApplyBagnonTheme() end,
				},
			} },
			frames = frames,
			display = display,
			colors = colors,
		},
	}
end

ns:RegisterPage({
	key = "bagnon",
	module = "bagnon",
	title = "Sacs",
	subtitle = "Sacs, banque, trousseau et banque de guilde en une seule fenêtre, avec inventaire de tous tes personnages.",
	icon = "Interface\\Icons\\INV_Misc_Bag_07",
	group = "modules",
	order = 40,

	build = function(page)
		ns:AddPageAction(page, "Trousseau", 86, function() ns:ToggleBagnon("keys") end)
		ns:AddPageAction(page, "Banque", 76, function() ns:ToggleBagnon("bank") end)
		ns:AddPageAction(page, "Sacs", 66, function() ns:ToggleBagnon("inventory") end, "accent")
		page.view = ns:CreateOptionsView(page.body, Options(), { key = "bagnon" })
		if ns.pendingBagnonTab then
			page.view.tabSel = { frames = ns.pendingBagnonTab }
			ns.pendingBagnonTab = nil
		end
	end,
})

-- ouvre directement l'onglet de la fenêtre demandée (clic droit sur un titre de sac)
function ns:OpenBagnonFrameOptions(frameID)
	self.db.optionPaths = self.db.optionPaths or {}
	self.db.optionPaths.bagnon = { "frames" }
	local page = self.pages.bagnon
	if page and page.frame and page.frame.view then
		page.frame.view.tabSel = page.frame.view.tabSel or {}
		page.frame.view.tabSel.frames = frameID
	else
		self.pendingBagnonTab = frameID
	end
	self:Open("bagnon")
end
