--[[
	EasyUI - Page Courrier
]]
local _, ns = ...

local function P() return ns:GetAceAddon("Postal") end
local function DB() return P().db.profile end

local MODULES = {
	{ "OpenAll", "Tout relever", "Bouton pour ouvrir tout le courrier (objets et argent) d'un coup." },
	{ "Select", "Sélection multiple", "Cases à cocher pour ouvrir ou renvoyer plusieurs lettres." },
	{ "Express", "Raccourcis de clic", "Maj + clic : prendre le contenu ; Ctrl + clic : renvoyer ; Alt + clic : joindre un objet." },
	{ "BlackBook", "Carnet d'adresses", "Contacts, personnages récents et reroll en saisie automatique." },
	{ "Wire", "Objet automatique", "Remplit l'objet de la lettre avec le montant envoyé." },
	{ "Rake", "Bilan d'argent", "Affiche l'argent total récupéré à la fermeture de la boîte." },
	{ "TradeBlock", "Bloquer les échanges", "Refuse échanges et invitations de guilde pendant que la boîte est ouverte." },
	{ "DoNotWant", "Renvoi rapide", "Icône pour renvoyer ou supprimer une lettre directement depuis la liste." },
	{ "CarbonCopy", "Copier une lettre", "Bouton pour copier le texte d'une lettre." },
}

local AH = {
	{ "AHWon", "Objets gagnés (hôtel des ventes)" }, { "AHSuccess", "Ventes réussies" },
	{ "AHOutbid", "Enchères dépassées" }, { "AHExpired", "Ventes expirées" }, { "AHCancelled", "Ventes annulées" },
	{ "NeutralAHWon", "Gagnés (HV neutre)" }, { "NeutralAHSuccess", "Ventes (HV neutre)" },
	{ "NeutralAHOutbid", "Dépassées (HV neutre)" }, { "NeutralAHExpired", "Expirées (HV neutre)" },
	{ "NeutralAHCancelled", "Annulées (HV neutre)" },
}

local function FreeValues()
	local t = {}
	for _, v in ipairs(P().keepFreeOptions or { 0, 1, 2, 3, 5 }) do t[v] = v .. " emplacement(s)" end
	return t
end

local function Options()
	local modules = { type = "group", name = "Fonctions", order = 1, args = {
		info = { type = "description", order = 0, fontSize = "medium",
			name = "Choisis les fonctions ajoutées à la boîte aux lettres. Elles s'appliquent à la prochaine ouverture." },
	} }
	for i, m in ipairs(MODULES) do
		modules.args[m[1]] = {
			type = "toggle", name = m[2], desc = m[3], order = i,
			get = function() return DB().ModuleEnabledState[m[1]] and true or false end,
			set = function(_, v)
				DB().ModuleEnabledState[m[1]] = v
				local mod = P():GetModule(m[1], true)
				if mod then if v then mod:Enable() else mod:Disable() end end
			end,
		}
	end

	local open = { type = "group", name = "Tout relever", order = 2, args = {
		speed = {
			type = "range", name = "Délai entre deux lettres", desc = "En secondes. Plus court = plus rapide, mais le serveur peut refuser.", order = 1,
			min = 0.2, max = 2, step = 0.05,
			get = function() return DB().OpenSpeed end,
			set = function(_, v) DB().OpenSpeed = v end,
		},
		free = {
			type = "select", name = "Garder libres dans les sacs", order = 2, values = FreeValues,
			get = function() return DB().OpenAll.KeepFreeSpace end,
			set = function(_, v) DB().OpenAll.KeepFreeSpace = v DB().Select.KeepFreeSpace = v end,
		},
		attachments = {
			type = "toggle", name = "Prendre aussi les lettres normales avec objets", order = 3,
			get = function() return DB().OpenAll.Attachments end,
			set = function(_, v) DB().OpenAll.Attachments = v end,
		},
		spam = {
			type = "toggle", name = "Afficher le détail dans le chat", order = 4,
			get = function() return DB().OpenAll.SpamChat end,
			set = function(_, v) DB().OpenAll.SpamChat = v DB().Select.SpamChat = v end,
		},
		ahH = { type = "header", name = "Courrier de l'hôtel des ventes à relever", order = 10 },
	} }
	for i, a in ipairs(AH) do
		open.args[a[1]] = {
			type = "toggle", name = a[2], order = 10 + i,
			get = function() return DB().OpenAll[a[1]] end,
			set = function(_, v) DB().OpenAll[a[1]] = v end,
		}
	end

	local express = { type = "group", name = "Raccourcis", order = 3, args = {
		alt = { type = "toggle", name = "Alt + clic sur un objet : le joindre", order = 1,
			get = function() return DB().Express.EnableAltClick end, set = function(_, v) DB().Express.EnableAltClick = v end },
		autosend = { type = "toggle", name = "Envoyer automatiquement après Alt + clic", order = 2,
			get = function() return DB().Express.AutoSend end, set = function(_, v) DB().Express.AutoSend = v end },
		wheel = { type = "toggle", name = "Molette pour parcourir la boîte", order = 3,
			get = function() return DB().Express.MouseWheel end, set = function(_, v) DB().Express.MouseWheel = v end },
		tooltip = { type = "toggle", name = "Infobulle des lettres à plusieurs objets", order = 4,
			get = function() return DB().Express.MultiItemTooltip end, set = function(_, v) DB().Express.MultiItemTooltip = v end },
	} }

	local book = { type = "group", name = "Carnet d'adresses", order = 4, args = {
		autofill = { type = "toggle", name = "Remplir avec le dernier destinataire", order = 1,
			get = function() return DB().BlackBook.AutoFill end, set = function(_, v) DB().BlackBook.AutoFill = v end },
		auto = { type = "toggle", name = "Saisie automatique des noms", order = 2,
			get = function() return DB().BlackBook.UseAutoComplete end, set = function(_, v) DB().BlackBook.UseAutoComplete = v end },
		acH = { type = "header", name = "Proposer en saisie automatique", order = 10 },
		alts = { type = "toggle", name = "Mes personnages", order = 11,
			get = function() return DB().BlackBook.AutoCompleteAlts end, set = function(_, v) DB().BlackBook.AutoCompleteAlts = v end },
		recent = { type = "toggle", name = "Destinataires récents", order = 12,
			get = function() return DB().BlackBook.AutoCompleteRecent end, set = function(_, v) DB().BlackBook.AutoCompleteRecent = v end },
		contacts = { type = "toggle", name = "Contacts", order = 13,
			get = function() return DB().BlackBook.AutoCompleteContacts end, set = function(_, v) DB().BlackBook.AutoCompleteContacts = v end },
		friends = { type = "toggle", name = "Amis", order = 14,
			get = function() return DB().BlackBook.AutoCompleteFriends end, set = function(_, v) DB().BlackBook.AutoCompleteFriends = v end },
		guild = { type = "toggle", name = "Guilde", order = 15,
			get = function() return DB().BlackBook.AutoCompleteGuild end, set = function(_, v) DB().BlackBook.AutoCompleteGuild = v end },
		clearRecent = { type = "execute", name = "Vider les destinataires récents", order = 20,
			confirm = true, confirmText = "Vider la liste des destinataires récents ?",
			func = function() wipe(DB().BlackBook.recent) end },
	} }

	return { type = "group", name = "Courrier", args = { modules = modules, open = open, express = express, book = book } }
end

ns:RegisterPage({
	key = "mail",
	module = "mail",
	title = "Courrier",
	subtitle = "Boîte aux lettres améliorée : tout relever, sélection multiple, raccourcis, carnet d'adresses.",
	icon = "Interface\\Icons\\INV_Letter_15",
	group = "modules",
	order = 56,

	build = function(page)
		page.view = ns:CreateOptionsView(page.body, Options(), { key = "mail" })
	end,
})
