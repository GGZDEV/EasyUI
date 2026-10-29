--[[
	EasyUI - Page Cadres de raid
]]
local _, ns = ...

local function DB() return ns.db.raid end
local function Apply() if ns.RF then ns.RF:Apply() end end

-- raccourci : réglage simple de ns.db.raid[clé]
local function opt(def)
	local key = def.key
	def.key = nil
	def.get = def.get or function() return DB()[key] end
	def.set = def.set or function(_, v) DB()[key] = v Apply() end
	return def
end

-- réglage de la disposition affichée (groupe, raid 10, 25, 40)
local function lopt(def)
	local key = def.key
	def.key = nil
	def.get = function() return ns.RF:Layout()[key] end
	def.set = function(_, v) ns.RF:Layout()[key] = v Apply() end
	return def
end

local function Options()
	return { type = "group", name = "Cadres de raid", args = {
		general = { type = "group", name = "Général", order = 1, args = {
			enabled = opt({ key = "enabled", type = "toggle", name = "Activer les cadres de raid EasyUI", width = "full", order = 1,
				set = function(_, v) DB().enabled = v Apply() if not v then ns:AskReload() end end }),
			showH = { type = "header", name = "Affichage", order = 10 },
			showParty = opt({ key = "showParty", type = "toggle", name = "Afficher en groupe (5 joueurs)", order = 11 }),
			showPlayer = opt({ key = "showPlayer", type = "toggle", name = "M'afficher dans le groupe", order = 12 }),
			showSolo = opt({ key = "showSolo", type = "toggle", name = "Afficher même seul", order = 13 }),
			sortByName = opt({ key = "sortByName", type = "toggle", name = "Trier par nom dans chaque groupe", order = 14 }),
			blizzH = { type = "header", name = "Cadres Blizzard", order = 20 },
			hideBlizzParty = opt({ key = "hideBlizzParty", type = "toggle", name = "Masquer les cadres de groupe Blizzard", order = 21,
				set = function(_, v) DB().hideBlizzParty = v if v then Apply() else ns:AskReload() end end }),
			hideBlizzRaid = opt({ key = "hideBlizzRaid", type = "toggle", name = "Masquer les cadres de raid du jeu", order = 22,
				set = function(_, v) DB().hideBlizzRaid = v if v then Apply() else ns:AskReload() end end }),
			previewH = { type = "header", name = "Aperçu", order = 30 },
			previewInfo = { type = "description", order = 31,
				name = "L'aperçu affiche des cadres factices pour régler la disposition sans être en groupe. Il s'affiche aussi automatiquement en mode édition." },
			previewCount = opt({ key = "previewCount", type = "select", name = "Taille de l'aperçu", order = 32,
				values = { [5] = "Groupe (5)", [10] = "Raid 10", [25] = "Raid 25", [40] = "Raid 40" },
				sorting = { 5, 10, 25, 40 },
				set = function(_, v) DB().previewCount = v if ns.RF.previewShown then ns.RF:ShowPreview(true) end end }),
			preview = { type = "execute", name = "Afficher / masquer l'aperçu", order = 33,
				func = function() ns.RF:ShowPreview(not ns.RF.previewShown) end },
		} },

		layout = { type = "group", name = "Disposition", order = 2, args = {
			sizeSel = { type = "select", name = "Disposition à régler", order = 1, width = "full",
				desc = "Chaque taille de groupe a sa propre disposition et sa propre position. Elle s'applique toute seule selon le nombre de joueurs.",
				values = { [5] = "Groupe (1 à 5 joueurs)", [10] = "Raid 10 (6 à 10)", [25] = "Raid 25 (11 à 25)", [40] = "Raid 40 (26 à 40)" },
				sorting = { 5, 10, 25, 40 },
				get = function() return ns.RF.BRACKET_SIZE[ns.RF:Bracket()] end,
				set = function(_, v) DB().previewCount = v ns.RF:ShowPreview(true) end },
			sizeInfo = { type = "description", order = 2,
				name = function()
					return "Tu règles : |cffffffff" .. ns.RF.BRACKET_LABEL[ns.RF:Bracket()] .. "|r (aperçu affiché). En mode édition, la molette sur le cadre de raid change aussi de taille." 
				end },
			sizeH = { type = "header", name = "Taille", order = 10 },
			width = lopt({ key = "width", type = "range", name = "Largeur", min = 40, max = 200, step = 1, order = 11 }),
			height = lopt({ key = "height", type = "range", name = "Hauteur", min = 20, max = 120, step = 1, order = 12 }),
			spacing = lopt({ key = "spacing", type = "range", name = "Espace entre les joueurs", min = 0, max = 20, step = 1, order = 13 }),
			groupSpacing = lopt({ key = "groupSpacing", type = "range", name = "Espace entre les groupes", min = 0, max = 40, step = 1, order = 14 }),
			dirH = { type = "header", name = "Sens", order = 20 },
			growth = lopt({ key = "growth", type = "select", name = "Dans un groupe, les joueurs vont vers", order = 21,
				desc = "Le bas ou le haut : groupes en colonnes. La droite ou la gauche : groupes en lignes.",
				values = { DOWN = "Le bas", UP = "Le haut", RIGHT = "La droite", LEFT = "La gauche" },
				sorting = { "DOWN", "UP", "RIGHT", "LEFT" } }),
			groupGrowth = lopt({ key = "groupGrowth", type = "select", name = "Les groupes suivants vont vers", order = 22,
				desc = "Où se place le groupe 2 par rapport au groupe 1. « La gauche » : le groupe 1 est tout à droite.",
				values = { RIGHT = "La droite", LEFT = "La gauche", DOWN = "Le bas", UP = "Le haut" },
				sorting = { "RIGHT", "LEFT", "DOWN", "UP" } }),
			groupsPerRow = lopt({ key = "groupsPerRow", type = "range", name = "Groupes avant de passer à la ligne", min = 1, max = 8, step = 1, order = 23,
				desc = "8 = tous les groupes à la suite ; 4 = deux rangées de 4 groupes..." }),
			posH = { type = "header", name = "Position et copie", order = 30 },
			pos = { type = "execute", name = "Déplacer (mode édition)", order = 31,
				func = function() ns:SetEditMode(true) end },
			reset = { type = "execute", name = "Position par défaut", order = 32,
				desc = "Remet cette disposition à sa position d'origine.",
				func = function() ns.RF:Layout().point = { unpack(ns.RF.DEFAULT_POINT) } Apply() end },
			copyAll = { type = "execute", name = "Copier vers toutes les tailles", order = 33,
				desc = "Donne cette disposition (taille, sens et position) au groupe et à tous les raids.",
				confirm = true, confirmText = "Remplacer la disposition des autres tailles par celle-ci ?",
				func = function()
					local cur = ns.RF:Bracket()
					local src = ns.RF:Layout(cur)
					for _, b in ipairs(ns.RF.BRACKETS) do
						if b ~= cur then DB().layouts[b] = ns.RF.CopyLayout(src) end
					end
					Apply()
				end },
		} },

		look = { type = "group", name = "Apparence", order = 3, args = {
			colorH = { type = "header", name = "Barre de vie", order = 1 },
			colorMode = opt({ key = "colorMode", type = "select", name = "Couleur", order = 2,
				values = { class = "Couleur de classe", dark = "Sombre (nom coloré)", gradient = "Selon la vie (vert à rouge)" },
				sorting = { "class", "dark", "gradient" } }),
			bgAlpha = opt({ key = "bgAlpha", type = "range", name = "Opacité du fond", min = 0, max = 1, step = 0.05, isPercent = true, order = 3 }),
			powerHeight = opt({ key = "powerHeight", type = "range", name = "Barre de ressource (0 = aucune)", min = 0, max = 10, step = 1, order = 4 }),
			powerManaOnly = opt({ key = "powerManaOnly", type = "toggle", name = "Ressource : mana uniquement", order = 5 }),
			textH = { type = "header", name = "Textes", order = 10 },
			fontSize = opt({ key = "fontSize", type = "range", name = "Taille du texte", min = 7, max = 18, step = 1, order = 11 }),
			nameLength = opt({ key = "nameLength", type = "range", name = "Longueur du nom", min = 3, max = 20, step = 1, order = 12 }),
			healthText = opt({ key = "healthText", type = "select", name = "Texte de vie", order = 13,
				values = { deficit = "Vie manquante", percent = "Pourcentage", current = "Vie actuelle", none = "Aucun" },
				sorting = { "deficit", "percent", "current", "none" } }),
			rangeAlpha = opt({ key = "rangeAlpha", type = "range", name = "Opacité hors de portée", min = 0.1, max = 1, step = 0.05, isPercent = true, order = 14 }),
			iconsH = { type = "header", name = "Icônes", order = 20 },
			roleIcon = opt({ key = "roleIcon", type = "toggle", name = "Rôle (tank / soin / dégâts)", order = 21 }),
			leaderIcon = opt({ key = "leaderIcon", type = "toggle", name = "Chef de groupe", order = 22 }),
			raidIcon = opt({ key = "raidIcon", type = "toggle", name = "Marqueur de raid", order = 23 }),
			readyCheck = opt({ key = "readyCheck", type = "toggle", name = "Appel « prêt »", order = 24 }),
		} },

		auras = { type = "group", name = "Effets", order = 4, args = {
			debuffH = { type = "header", name = "Effets négatifs", order = 1 },
			debuffs = opt({ key = "debuffs", type = "range", name = "Nombre affiché", min = 0, max = 4, step = 1, order = 2 }),
			debuffSize = opt({ key = "debuffSize", type = "range", name = "Taille", min = 8, max = 32, step = 1, order = 3 }),
			dispelHighlight = opt({ key = "dispelHighlight", type = "toggle", name = "Contour coloré si dissipable", order = 4,
				desc = "Magie en bleu, malédiction en violet, maladie en marron, poison en vert." }),
			buffH = { type = "header", name = "Mes effets positifs (soins sur la durée...)", order = 10 },
			buffs = opt({ key = "buffs", type = "range", name = "Nombre affiché", min = 0, max = 4, step = 1, order = 11 }),
			buffSize = opt({ key = "buffSize", type = "range", name = "Taille", min = 8, max = 32, step = 1, order = 12 }),
			stateH = { type = "header", name = "États", order = 20 },
			aggro = opt({ key = "aggro", type = "toggle", name = "Contour rouge si le joueur a l'aggro", order = 21 }),
			targetHighlight = opt({ key = "targetHighlight", type = "toggle", name = "Contour blanc sur ma cible", order = 22 }),
		} },
	} }
end

ns:RegisterPage({
	key = "raid",
	module = "raid",
	title = "Cadres de raid",
	subtitle = "Groupe et raid : vie, ressource, effets, dissipation, aggro, portée. Compatibles click-casting.",
	icon = "Interface\\Icons\\Spell_Holy_PrayerOfHealing",
	group = "modules",
	order = 25,

	build = function(page)
		ns:AddPageAction(page, "Mode édition", 110, function() ns:SetEditMode(true) end, "accent")
		ns:AddPageAction(page, "Aperçu", 70, function() ns.RF:ShowPreview(not ns.RF.previewShown) end)
		page.view = ns:CreateOptionsView(page.body, Options(), { key = "raid" })
		ns.RF.page = page
	end,
})
