--[[
	EasyUI - Core
	Namespace, base de données, événements, commandes et fonctions communes.
]]
local addonName, ns = ...
_G.EasyUI = ns

ns.name = addonName
ns.version = GetAddOnMetadata(addonName, "Version") or "?"

BINDING_HEADER_EASYUI = "EasyUI"
BINDING_NAME_EASYUI_TOGGLE = "Ouvrir / fermer EasyUI"
BINDING_NAME_EASYUI_EDITMODE = "Mode édition (déplacer l'interface)"

----------------------------------------------------------------
-- Base de données
----------------------------------------------------------------
local defaults = {
	scale = 1,
	accent = { r = 1.00, g = 0.82, b = 0.00 },
	useClassColor = false,
	lastPage = "home",
	minimap = { hide = false, angle = 215 },
	hideAddonMinimapIcons = true,
	grid = { size = 32, show = true },
	editMode = {
		bartender = true,     -- déverrouiller les barres d'action
		quartz = true,        -- déverrouiller les barres d'incantation
		bagnon = true,        -- afficher les sacs pour les placer
		blizzard = true,      -- poignées MoveAnything sur les cadres Blizzard
		moveanything = false, -- ouvrir aussi la fenêtre complète de MoveAnything
		skipFrames = {},      -- cadres Blizzard exclus du mode édition
		snap = true,          -- aimantation commune (bords, centres, écran)
	},
	modules = { guildbank = true },
	hideGameCastbar = true,
	skin = { buttons = true, windows = true, bagnon = false },
	raid = {
		enabled = true, width = 88, height = 46, spacing = 3, groupSpacing = 10, groupsPerRow = 8,
		growth = "DOWN", sortByName = false, showParty = true, showPlayer = true, showSolo = false,
		hideBlizzParty = true, hideBlizzRaid = true,
		colorMode = "class", bgAlpha = 0.85, nameLength = 8, fontSize = 11, healthText = "deficit",
		powerHeight = 3, powerManaOnly = true, rangeAlpha = 0.4,
		debuffs = 3, debuffSize = 16, buffs = 3, buffSize = 14,
		dispelHighlight = true, aggro = true, targetHighlight = true,
		roleIcon = true, leaderIcon = true, raidIcon = true, readyCheck = true,
		previewCount = 25, point = { "TOPLEFT", "TOPLEFT", 30, -280 },
	},
	movers = {},
	uf = {
		enabled = true, hideBlizzard = true, colorMode = "class", bgAlpha = 0.85,
		units = {
			player = { enabled = true, width = 230, height = 44, powerHeight = 10, portrait = "left", fontSize = 12,
				healthText = "full", powerText = true, showLevel = true, colorName = false,
				buffs = 0, debuffs = 0, auraSize = 22, onlyMine = false, fadeOthers = false, combo = false,
				point = { "CENTER", "CENTER", -280, -170 } },
			target = { enabled = true, width = 230, height = 44, powerHeight = 10, portrait = "right", fontSize = 12,
				healthText = "full", powerText = true, showLevel = true, colorName = true,
				buffs = 8, debuffs = 16, auraSize = 22, onlyMine = false, fadeOthers = true, combo = true,
				point = { "CENTER", "CENTER", 280, -170 } },
			targettarget = { enabled = true, width = 130, height = 26, powerHeight = 0, portrait = "none", fontSize = 10,
				healthText = "percent", powerText = false, showLevel = false, colorName = true,
				buffs = 0, debuffs = 0, auraSize = 18, onlyMine = false, fadeOthers = false, combo = false,
				point = { "CENTER", "CENTER", 480, -160 } },
			focus = { enabled = true, width = 180, height = 34, powerHeight = 6, portrait = "none", fontSize = 11,
				healthText = "percent", powerText = false, showLevel = true, colorName = true,
				buffs = 0, debuffs = 6, auraSize = 20, onlyMine = true, fadeOthers = false, combo = false,
				point = { "CENTER", "CENTER", -280, -60 } },
			pet = { enabled = true, width = 130, height = 26, powerHeight = 4, portrait = "none", fontSize = 10,
				healthText = "percent", powerText = false, showLevel = false, colorName = false,
				buffs = 0, debuffs = 0, auraSize = 18, onlyMine = false, fadeOthers = false, combo = false,
				point = { "CENTER", "CENTER", -355, -220 } },
		},
	},
	plates = { skull = true, skullSize = 26, skullOnTarget = true, skullMargin = 1.0, skullX = 0 },
	point = nil,
	dbVersion = 2,
}

local function copyDefaults(src, dst)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			copyDefaults(v, dst[k])
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
	return dst
end

----------------------------------------------------------------
-- Utilitaires
----------------------------------------------------------------
function ns:Print(msg, ...)
	if select("#", ...) > 0 then msg = msg:format(...) end
	local r, g, b = self:GetAccent()
	DEFAULT_CHAT_FRAME:AddMessage(("|cff%02x%02x%02xEasyUI|r: %s"):format(r * 255, g * 255, b * 255, msg))
end

function ns:GetAccent()
	local db = self.db
	if db and db.useClassColor then
		local _, class = UnitClass("player")
		local c = class and RAID_CLASS_COLORS[class]
		if c then return c.r, c.g, c.b end
	end
	local a = (db and db.accent) or defaults.accent
	return a.r, a.g, a.b
end

function ns:GetLib(name)
	return LibStub and LibStub(name, true)
end

function ns:GetAceAddon(name)
	local AceAddon = self:GetLib("AceAddon-3.0")
	if not AceAddon then return end
	local ok, obj = pcall(AceAddon.GetAddon, AceAddon, name, true)
	return ok and obj or nil
end

-- Timer minimal (pas de C_Timer en 3.3.5)
local timerFrame = CreateFrame("Frame")
local timers = {}
timerFrame:SetScript("OnUpdate", function(self, elapsed)
	for i = #timers, 1, -1 do
		local t = timers[i]
		t.left = t.left - elapsed
		if t.left <= 0 then
			table.remove(timers, i)
			t.func()
		end
	end
	if #timers == 0 then self:Hide() end
end)
timerFrame:Hide()

function ns:After(delay, func)
	timers[#timers + 1] = { left = delay, func = func }
	timerFrame:Show()
end

----------------------------------------------------------------
-- Callbacks internes (pages qui écoutent les changements)
----------------------------------------------------------------
local callbacks = {}
function ns:On(event, func)
	callbacks[event] = callbacks[event] or {}
	table.insert(callbacks[event], func)
end

function ns:Fire(event, ...)
	local list = callbacks[event]
	if not list then return end
	for _, func in ipairs(list) do
		local ok, err = pcall(func, ...)
		if not ok then geterrorhandler()(err) end
	end
end

----------------------------------------------------------------
-- Rechargement
----------------------------------------------------------------
StaticPopupDialogs["EASYUI_RELOAD"] = {
	text = "|cffffd100EasyUI|r\n\nCe changement nécessite un rechargement de l'interface.\nRecharger maintenant ?",
	button1 = "Recharger",
	button2 = "Plus tard",
	OnAccept = function() ReloadUI() end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
}

function ns:AskReload()
	StaticPopup_Show("EASYUI_RELOAD")
end

----------------------------------------------------------------
-- Chargement des modules compagnons (EasyUI_*), sauf ceux désactivés
----------------------------------------------------------------
function ns:LoadModules()
	-- Les modules sont des addons normaux, chargés par le jeu juste après le cœur.
	-- Le jeu ne relit les .toc qu'au lancement : si un module est encore vu comme
	-- « à la demande », on le charge nous-mêmes (avec les traductions françaises).
	local loc = GetLocale()
	for _, m in ipairs(self.modules or {}) do
		if m.addon then
			if self.db.modules[m.key] == false then
				DisableAddOn(m.addon)
			else
				EnableAddOn(m.addon)
				if not IsAddOnLoaded(m.addon) and IsAddOnLoadOnDemand(m.addon) then
					local saved = GAME_LOCALE
					if loc == "enUS" or loc == "enGB" then GAME_LOCALE = "frFR" end
					local ok, reason = LoadAddOn(m.addon)
					GAME_LOCALE = saved
					if not ok then m.loadError = reason end
				else
					local _, _, _, _, loadable, reason = GetAddOnInfo(m.addon)
					if not loadable and reason and reason ~= "" then m.loadError = reason end
				end
			end
		end
	end
end

----------------------------------------------------------------
-- Événements
----------------------------------------------------------------
local events = CreateFrame("Frame")
ns.events = events
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")

events:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == addonName then
			local fresh = EasyUIDB == nil
			EasyUIDB = EasyUIDB or {}
			-- v1 -> v2 : les modules sont intégrés, un seul bouton minimap suffit
			if not fresh and (EasyUIDB.dbVersion or 1) < 2 then
				EasyUIDB.hideAddonMinimapIcons = true
				EasyUIDB.dbVersion = 2
			end
			-- nouvelle charte : l'ancien vert par défaut devient l'or
			local a = EasyUIDB.accent
			if not EasyUIDB.goldAccent and a and math.abs((a.r or 0) - 0.10) < 0.01
				and math.abs((a.g or 0) - 0.84) < 0.01 and math.abs((a.b or 0) - 0.63) < 0.01 then
				EasyUIDB.accent = { r = 1.00, g = 0.82, b = 0.00 }
			end
			EasyUIDB.goldAccent = true
			EasyUIDB = copyDefaults(defaults, EasyUIDB)
			ns.db = EasyUIDB
			ns:LoadModules()
		end
		ns:Fire("ADDON_LOADED", arg1)
	elseif event == "PLAYER_LOGIN" then
		ns:Fire("LOGIN")
		ns:ApplyAddonMinimapIcons()
	elseif event == "PLAYER_REGEN_DISABLED" then
		ns.inCombat = true
		ns:Fire("COMBAT_START")
	elseif event == "PLAYER_REGEN_ENABLED" then
		ns.inCombat = false
		ns:Fire("COMBAT_END")
	end
end)

----------------------------------------------------------------
-- Icônes minimap des autres addons (Bartender4 utilise LibDBIcon)
----------------------------------------------------------------
function ns:ApplyAddonMinimapIcons()
	local LDBIcon = self:GetLib("LibDBIcon-1.0")
	local bt = self:GetAceAddon("Bartender4")
	if not (LDBIcon and bt and bt.db and bt.db.profile.minimapIcon) then return end
	if self.db.hideAddonMinimapIcons then
		bt.db.profile.minimapIcon.hide = true
		LDBIcon:Hide("Bartender4")
	end
end

----------------------------------------------------------------
-- Commandes
----------------------------------------------------------------
SLASH_EASYUI1 = "/eui"
SLASH_EASYUI2 = "/easyui"
SLASH_EASYUI3 = "/eaui"
SlashCmdList["EASYUI"] = function(msg)
	msg = (msg or ""):lower():trim()
	if msg == "edit" or msg == "move" or msg == "unlock" then
		ns:ToggleEditMode()
	elseif msg == "lock" then
		ns:SetEditMode(false)
	elseif msg == "reset" then
		ns.db.point = nil
		ns.db.scale = 1
		if ns.frame then ns:RestorePosition() end
		ns:Print("Position et échelle de la fenêtre réinitialisées.")
	elseif msg == "help" or msg == "?" then
		ns:Print("Commandes :")
		print("  |cffffd100/eui|r - ouvrir / fermer le panneau")
		print("  |cffffd100/eui edit|r - activer / désactiver le mode édition")
		print("  |cffffd100/eui lock|r - tout verrouiller")
		print("  |cffffd100/eui <page>|r - ouvrir une page (barres, incantation, recharge, sacs, cadres, clique, profils, options)")
		print("  |cffffd100/eui reset|r - recentrer la fenêtre")
	elseif msg ~= "" and ns.pageAliases[msg] then
		ns:Open(ns.pageAliases[msg])
	else
		ns:Toggle()
	end
end

ns.pageAliases = {
	home = "home", accueil = "home",
	bars = "bartender", barres = "bartender", bt = "bartender", bartender = "bartender",
	cast = "quartz", incantation = "quartz", quartz = "quartz",
	cd = "cooldowns", recharge = "cooldowns", cooldowns = "cooldowns", omnicc = "cooldowns",
	bags = "bagnon", sacs = "bagnon", bagnon = "bagnon",
	frames = "moveanything", cadres = "moveanything", move = "moveanything", moveanything = "moveanything",
	clique = "clique", click = "clique",
	profiles = "profiles", profils = "profiles",
	options = "settings", settings = "settings", config = "settings",
}
