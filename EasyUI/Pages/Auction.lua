--[[
	EasyUI - Page Hôtel des ventes
	Vente rapide avec prix conseillé, achat, listes de courses, analyse des prix
	et prix dans les infobulles. Les réglages sont ceux du module (par personnage).
]]
local _, ns = ...

local CATEGORY = "EasyUI - Hôtel des ventes"

-- ouvre les options détaillées (baisse de prix, piles, listes de courses...)
function ns:OpenAuctionOptions()
	if InCombatLockdown() then return end
	if self.frame then self.frame:Hide() end
	if InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(CATEGORY)
		InterfaceOptionsFrame_OpenToCategory(CATEGORY) -- deux fois : contournement connu du 3.3.5
	end
end

-- réglage numérique 0 / 1 stocké dans une variable globale du module
local function Flag(var, name, order, desc, after)
	return {
		type = "toggle", name = name, desc = desc, order = order,
		get = function() return (_G[var] or 0) ~= 0 end,
		set = function(_, v) _G[var] = v and 1 or 0 if after then after() end end,
	}
end

local function Value(var, def)
	def.get = function() return _G[var] end
	def.set = function(_, v) _G[var] = v end
	return def
end

local function SV() return _G.AUCTIONATOR_SAVEDVARS or {} end

local function Options()
	local general = { type = "group", name = "Général", order = 1, args = {
		info = { type = "description", order = 0, fontSize = "medium",
			name = "À l'hôtel des ventes, trois onglets s'ajoutent : |cffffffffVendre|r (prix conseillé selon les offres en cours), "
				.. "|cffffffffAcheter|r (recherche et listes de courses) et |cffffffffPlus|r (analyse complète, historique). "
				.. "Les réglages ci-dessous sont propres à ce personnage." },
		openH = { type = "header", name = "Ouverture", order = 10 },
		deftab = Value("AUCTIONATOR_DEFTAB", { type = "select", name = "Onglet affiché à l'ouverture", order = 11,
			values = { [0] = "Onglet du jeu (parcourir)", [1] = "Vendre", [2] = "Acheter", [3] = "Plus" },
			sorting = { 0, 1, 2, 3 } }),
		bags = Flag("AUCTIONATOR_OPEN_ALL_BAGS", "Ouvrir tous les sacs avec l'hôtel des ventes", 12),
		sellH = { type = "header", name = "Vente", order = 20 },
		alt = Flag("AUCTIONATOR_ENABLE_ALT", "Alt + clic sur un objet des sacs : le mettre en vente", 21,
			"Place l'objet dans l'onglet Vendre avec le prix conseillé."),
		startPrice = Flag("AUCTIONATOR_SHOW_ST_PRICE", "Afficher et régler le prix de départ (enchère)", 22, nil,
			function() if Atr_ShowHide_StartingPrice and AuctionFrame then pcall(Atr_ShowHide_StartingPrice) end end),
		discount = { type = "range", name = "Prix de départ : rabais sur le prix d'achat immédiat", order = 23,
			min = 0, max = 100, step = 1,
			desc = "En pourcentage. 5 % = l'enchère de départ vaut 95 % du prix d'achat immédiat.",
			get = function() return SV().STARTING_DISCOUNT or 5 end,
			set = function(_, v) if _G.AUCTIONATOR_SAVEDVARS then AUCTIONATOR_SAVEDVARS.STARTING_DISCOUNT = v end end },
		duration = Value("AUCTIONATOR_DEF_DURATION", { type = "select", name = "Durée des ventes par défaut", order = 24,
			values = { N = "Celle du jeu (dernière utilisée)", S = "12 heures", M = "24 heures", L = "48 heures" },
			sorting = { "N", "S", "M", "L" } }),
		moreH = { type = "header", name = "Réglages détaillés", order = 30 },
		moreInfo = { type = "description", order = 31,
			name = "Baisse automatique selon le prix, taille des piles par objet, listes de courses, base de prix : dans la fenêtre d'options détaillées." },
		more = { type = "execute", name = "Options détaillées", order = 32, func = function() ns:OpenAuctionOptions() end },
	} }

	local tips = { type = "group", name = "Infobulles", order = 2, args = {
		info = { type = "description", order = 0, fontSize = "medium",
			name = "Prix ajoutés dans l'infobulle des objets, même loin de l'hôtel des ventes (après une première analyse)." },
		vendor = Flag("AUCTIONATOR_V_TIPS", "Prix chez le marchand", 1),
		auction = Flag("AUCTIONATOR_A_TIPS", "Prix à l'hôtel des ventes", 2),
		de = Flag("AUCTIONATOR_D_TIPS", "Valeur en désenchantement", 3),
		shift = Value("AUCTIONATOR_SHIFT_TIPS", { type = "select", name = "Avec Maj enfoncé, afficher", order = 10,
			values = { [1] = "Le prix de la pile", [2] = "Le prix à l'unité" }, sorting = { 1, 2 } }),
		deDetails = Value("AUCTIONATOR_DE_DETAILS_TIPS", { type = "select", name = "Détail du désenchantement", order = 11,
			values = { [1] = "Avec Maj enfoncé", [2] = "Avec Ctrl enfoncé", [3] = "Avec Alt enfoncé", [4] = "Jamais", [5] = "Toujours" },
			sorting = { 1, 2, 3, 4, 5 } }),
	} }

	local scan = { type = "group", name = "Analyse des prix", order = 3, args = {
		info = { type = "description", order = 0, fontSize = "medium",
			name = "L'analyse complète (onglet Plus, à l'hôtel des ventes) relève le prix de tous les objets en vente pour les infobulles et les prix conseillés." },
		minLevel = Value("AUCTIONATOR_SCAN_MINLEVEL", { type = "select", name = "Qualité minimale enregistrée", order = 1,
			values = { [1] = "|cff9d9d9dMédiocre (tout)|r", [2] = "|cffffffffCommune|r", [3] = "|cff1eff00Inhabituelle|r",
				[4] = "|cff0070ddRare|r", [5] = "|cffa335eeÉpique|r" },
			sorting = { 1, 2, 3, 4, 5 } }),
		hist = Value("AUCTIONATOR_DB_MAXHIST_DAYS", { type = "range", name = "Jours d'historique conservés", order = 2,
			min = 1, max = 60, step = 1 }),
	} }

	return { type = "group", name = "Hôtel des ventes", args = { general = general, tips = tips, scan = scan } }
end

ns:RegisterPage({
	key = "auction",
	module = "auction",
	title = "Hôtel des ventes",
	subtitle = "Vente rapide au bon prix, achat, listes de courses, analyse des prix et prix dans les infobulles.",
	icon = "Interface\\Icons\\INV_Misc_Coin_02",
	group = "modules",
	order = 58,

	build = function(page)
		ns:AddPageAction(page, "Options détaillées", 140, function() ns:OpenAuctionOptions() end)
		page.view = ns:CreateOptionsView(page.body, Options(), { key = "auction" })
	end,
})
