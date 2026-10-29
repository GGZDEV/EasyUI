--[[
	EasyUI - Intégration des modules
	Bartender4, Quartz, Bagnon, MoveAnything et Clique sont embarqués dans
	EasyUI (dossier Modules). Ce fichier les décrit et branche leurs réglages
	sur ceux d'EasyUI.
]]
local _, ns = ...

----------------------------------------------------------------
-- Description des modules
----------------------------------------------------------------
ns.modules = {
	{
		key = "bartender", page = "bartender", addon = "EasyUI_Bars", title = "Barres d'action",
		desc = "Barres, familier, postures, XP et réputation",
		icon = "Interface\\Icons\\INV_Drink_05",
		ready = function() return ns:GetAceAddon("Bartender4") ~= nil end,
		action = { "Déverrouiller", function()
			local bt = ns:GetAceAddon("Bartender4")
			if bt then
				bt:ToggleLock()
				if not bt.Locked and bt.HideUnlockDialog then bt:HideUnlockDialog() end
			end
		end },
	},
	{
		key = "quartz", page = "quartz", addon = "EasyUI_Castbars", title = "Barres d'incantation",
		desc = "Joueur, cible, focus, recharge globale, swing",
		icon = "Interface\\Icons\\Spell_Nature_Lightning",
		ready = function() return ns:GetAceAddon("Quartz3") ~= nil end,
		action = { "Déverrouiller", function()
			local q = ns:GetAceAddon("Quartz3")
			if q then q:ToggleLock(false) end
		end },
	},
	{
		key = "cooldowns", page = "cooldowns", addon = "EasyUI_Cooldowns", title = "Temps de recharge",
		desc = "Chiffres sur les sorts, objets et auras",
		icon = [[Interface\Icons\Spell_Holy_BorrowedTime]],
		ready = function() return _G.OmniCC ~= nil and _G.OmniCC.GetDB ~= nil end,
		action = { "Style EasyUI", function() ns:ApplyCooldownTheme() end },
	},
	{
		key = "raid", page = "raid", title = "Cadres de raid",
		desc = "Groupe et raid : dissipation, aggro, portée",
		icon = [[Interface\Icons\Spell_Holy_PrayerOfHealing]],
		ready = function() return ns.RF ~= nil and ns.db.raid ~= nil end,
		action = { "Aperçu", function() ns.RF:ShowPreview(not ns.RF.previewShown) end },
	},
	{
		key = "damage", page = "damage", addon = "EasyUI_Damage", title = "Compteur de dégâts",
		desc = "Dégâts, soins et interruptions par combat",
		icon = [[Interface\Icons\Ability_Warrior_BattleShout]],
		ready = function() return _G.Details ~= nil and _G.Details.GetInstance ~= nil end,
		action = { "Afficher", function() _G.Details:ToggleWindows() end },
	},
	{
		key = "bagnon", page = "bagnon", addon = "EasyUI_Bags", title = "Sacs",
		desc = "Sacs, banque et banque de guilde réunis",
		icon = "Interface\\Icons\\INV_Misc_Bag_07",
		ready = function() return ns:GetAceAddon("Bagnon") ~= nil end,
		action = { "Ouvrir les sacs", function() ns:ToggleBagnon("inventory") end },
	},
	{
		key = "moveanything", page = "moveanything", addon = "EasyUI_Frames", title = "Cadres Blizzard",
		desc = "Déplacer, redimensionner ou masquer",
		icon = "Interface\\Icons\\Ability_Rogue_Sprint",
		ready = function() return MovAny ~= nil and MovAny.ToggleGUI ~= nil end,
		action = { "Éditeur", function() MovAny:ToggleGUI() end },
	},
	{
		key = "minimap", page = "minimap", addon = "EasyUI_Minimap", title = "Minimap",
		desc = "Forme, bordure, boutons, coordonnées",
		icon = [[Interface\Icons\INV_Misc_Spyglass_02]],
		ready = function() return ns:GetAceAddon("SexyMap") ~= nil end,
		action = { "Style EasyUI", function() ns:ApplyMinimapTheme() end },
	},
	{
		key = "clique", page = "clique", addon = "EasyUI_Clique", title = "Click-casting",
		desc = "Sorts liés aux clics sur les cadres",
		icon = "Interface\\Icons\\Spell_Holy_Renew",
		ready = function() local c = _G.EasyUI_CliqueAddon return c ~= nil and c.db ~= nil end,
		action = { "Liaisons", function() ns:OpenCliqueEditor() end },
	},
}

-- modules sans page dédiée pour l'instant (chargés aussi par le chargeur)
table.insert(ns.modules, 2, {
	key = "unitframes", page = "unitframes", title = "Cadres d'unité",
	desc = "Joueur, cible, focus, cible de la cible, familier",
	icon = [[Interface\Icons\Achievement_Character_Human_Male]],
	ready = function() return ns.UF ~= nil and ns.UF.ready end,
	action = { "Aperçu", function() ns.UF:TogglePreview() end },
})
table.insert(ns.modules, {
	key = "mail", page = "mail", addon = "EasyUI_Mail", title = "Courrier",
	desc = "Ouverture groupée, carnet d'adresses",
	icon = [[Interface\Icons\INV_Letter_15]],
	ready = function() return ns:GetAceAddon("Postal") ~= nil end,
	action = { "Options", function() ns:ShowPage("mail") end },
})
table.insert(ns.modules, {
	key = "chat", page = "chat", addon = "EasyUI_Chat", title = "Messagerie",
	desc = "Chuchotements en fenêtres, historique, onglets",
	icon = [[Interface\Icons\INV_Letter_03]],
	ready = function() return _G.WIM ~= nil end,
	action = { "Historique", function() if WIM and WIM.ShowHistoryViewer then WIM.ShowHistoryViewer() end end },
})

table.insert(ns.modules, {
	key = "auction", page = "auction", addon = "EasyUI_Auction", title = "Hôtel des ventes",
	desc = "Recherche rapide, historique des prix",
	icon = [[Interface\Icons\INV_Misc_Coin_02]],
	ready = function() return _G.AuctionatorLoaded == true end,
	action = { "Options", function() ns:ShowPage("auction") end },
})

ns.moduleByKey = {}
for _, m in ipairs(ns.modules) do ns.moduleByKey[m.key] = m end

-- un module est désactivé quand EasyUIDB.modules[clé] == false
function ns:ModuleEnabled(key)
	return not (self.db and self.db.modules and self.db.modules[key] == false)
end

function ns:SetModuleEnabled(key, on)
	self.db.modules[key] = on and true or false
	local m = self.moduleByKey[key]
	if m and m.addon then
		if on then EnableAddOn(m.addon) else DisableAddOn(m.addon) end
	end
	self:AskReload()
end

function ns:ModuleReady(key)
	if not self:ModuleEnabled(key) then return false end
	local m = self.moduleByKey[key]
	if not m then return true end
	local ok, res = pcall(m.ready)
	return ok and res
end

----------------------------------------------------------------
-- Raccourcis communs
----------------------------------------------------------------
function ns:ToggleBagnon(frameID)
	local b = self:GetAceAddon("Bagnon")
	if b and b.ToggleFrame then b:ToggleFrame(frameID) end
end

function ns:OpenCliqueEditor()
	if InCombatLockdown() then return end
	if self.frame then self.frame:Hide() end
	if SlashCmdList.CLIQUE then SlashCmdList.CLIQUE("") end
end

----------------------------------------------------------------
-- Réglages appliqués au chargement
----------------------------------------------------------------
ns:On("ADDON_LOADED", function(name)
	if name ~= ns.name then return end
	-- Banque de guilde Bagnon désactivable (avant l'activation des modules Ace)
	local bagnon = ns:GetAceAddon("Bagnon")
	local gb = bagnon and bagnon:GetModule("GuildBank", true)
	if gb and ns.db.modules.guildbank == false then
		gb:SetEnabledState(false)
	end
end)

----------------------------------------------------------------
-- Barre d'incantation du jeu : masquée (la barre EasyUI la remplace)
----------------------------------------------------------------
local SKIP_CAST = { "target", "focus", "arena", "boss", "party", "raid", "nameplate", "pet",
	"quartz", "easyui", "weakauras", "details", "mirror" }
local hiddenCast = {}

local function QuartzPlayerActive()
	local q = ns:GetAceAddon("Quartz3")
	local p = q and q:GetModule("Player", true)
	return p and p:IsEnabled()
end

local function HideCastFrame(f)
	if not f or hiddenCast[f] then return end
	hiddenCast[f] = true
	f:Hide()
	f:HookScript("OnShow", function(self)
		if ns.db.hideGameCastbar and QuartzPlayerActive() then self:Hide() end
	end)
end

-- repère les barres d'incantation du joueur visibles qui ne sont pas les nôtres
local function ScanCastbars()
	if not (ns.db.hideGameCastbar and QuartzPlayerActive()) then return end
	HideCastFrame(_G.CastingBarFrame)
	local f = EnumerateFrames()
	while f do
		if f:IsVisible() and f:IsObjectType("StatusBar") then
			local target = f:GetName() and f or f:GetParent()
			local name = target and target.GetName and target:GetName()
			if name and target ~= UIParent then
				local low = name:lower()
				if low:find("cast") then
					local skip = false
					for _, word in ipairs(SKIP_CAST) do
						if low:find(word, 1, true) then skip = true break end
					end
					if not skip then HideCastFrame(target) end
				end
			end
		end
		f = EnumerateFrames(f)
	end
end

local castWatch = CreateFrame("Frame")
castWatch:RegisterEvent("UNIT_SPELLCAST_START")
castWatch:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
-- quelques sorts suffisent à repérer la barre du jeu : on arrête ensuite (balayage coûteux)
local scans = 0
castWatch:SetScript("OnEvent", function(self, _, unit)
	if unit ~= "player" then return end
	scans = scans + 1
	if scans >= 3 then self:UnregisterAllEvents() end
	ns:After(0.05, ScanCastbars)
end)

ns:On("LOGIN", function()
	-- profils existants : on force la barre Blizzard masquée une fois
	if (ns.db.dbVersion or 2) < 3 then
		local q = ns:GetAceAddon("Quartz3")
		local p = q and q:GetModule("Player", true)
		if p and p.db then
			p.db.profile.hideblizz = true
			if p.ApplySettings then pcall(p.ApplySettings, p) end
		end
		ns.db.dbVersion = 3
	end
	ns:After(2, ScanCastbars)
end)
