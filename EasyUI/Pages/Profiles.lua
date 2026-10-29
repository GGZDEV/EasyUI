--[[
	EasyUI - Page Profils
	Bascule les barres d'action, les barres d'incantation et le click-casting
	sur le même profil, ou gère chaque profil séparément.
]]
local _, ns = ...

local SOURCES = {
	{ key = "bars", title = "Barres d'action", get = function() local a = ns:GetAceAddon("Bartender4") return a and a.db end },
	{ key = "cast", title = "Barres d'incantation", get = function() local a = ns:GetAceAddon("Quartz3") return a and a.db end },
	{ key = "click", title = "Click-casting", get = function() return _G.Clique and _G.Clique.db end },
	{ key = "minimap", title = "Minimap", get = function() local a = ns:GetAceAddon("SexyMap") return a and a.db end },
	{ key = "mail", title = "Courrier", get = function() local a = ns:GetAceAddon("Postal") return a and a.db end },
}

local function CharProfileName()
	return UnitName("player") .. " - " .. GetRealmName()
end

local function ApplyAll(name)
	if InCombatLockdown() then ns:Print("Impossible en combat.") return end
	name = name and name:trim()
	if not name or name == "" then return end
	for _, src in ipairs(SOURCES) do
		local db = src.get()
		if db then db:SetProfile(name) end
	end
	ns:Print("Profil |cffffffff%s|r appliqué partout.", name)
end

local function AllProfiles()
	local t = {}
	for _, src in ipairs(SOURCES) do
		local db = src.get()
		if db then for _, p in ipairs(db:GetProfiles({})) do t[p] = p end end
	end
	return t
end

-- profil commun à tous les modules (utilisé par le tableau de bord)
local function CopyAll(from)
	if InCombatLockdown() then ns:Print("Impossible en combat.") return end
	for _, src in ipairs(SOURCES) do
		local db = src.get()
		if db and db:GetCurrentProfile() ~= from then
			local has = false
			for _, p in ipairs(db:GetProfiles({})) do if p == from then has = true break end end
			if has then pcall(db.CopyProfile, db, from) end
		end
	end
	ns:Print("Réglages du profil |cffffffff%s|r copiés dans le profil actif.", from)
end

ns.Profiles = {
	All = AllProfiles,
	Apply = function(name) ApplyAll(name) end,
	CopyFrom = CopyAll,
	Current = function()
		for _, src in ipairs(SOURCES) do
			local db = src.get()
			if db then return db:GetCurrentProfile() end
		end
	end,
}

local function Options()
	local global = { type = "group", name = "Profil global", order = 1, args = {
		info = { type = "description", order = 0, fontSize = "medium",
			name = "Un même profil pour toute l'interface. Il est créé s'il n'existe pas encore (exemples : « Heal », « DPS », « PvP »)." },
		pick = {
			type = "select", name = "Basculer sur un profil existant", order = 1,
			values = AllProfiles,
			get = function() local db = SOURCES[1].get() return db and db:GetCurrentProfile() end,
			set = function(_, v) ApplyAll(v) end,
		},
		new = {
			type = "input", name = "Nouveau profil", order = 2,
			get = function() return "" end,
			set = function(_, v) ApplyAll(v) end,
		},
		char = {
			type = "execute", name = "Profil de ce personnage", order = 3,
			desc = function() return "Utilise « " .. CharProfileName() .. " » partout." end,
			func = function() ApplyAll(CharProfileName()) end,
		},
		default = {
			type = "execute", name = "Profil par défaut", order = 4,
			func = function() ApplyAll("Default") end,
		},
		note = { type = "description", order = 10,
			name = "Les sacs gardent leurs réglages par personnage automatiquement. Pour des positions de cadres Blizzard par personnage : Cadres Blizzard > Options. Le click-casting peut changer de profil seul selon la spécialisation (Click-casting > Options)." },
	} }

	local args = { global = global }
	for i, src in ipairs(SOURCES) do
		args[src.key] = { type = "group", name = src.title, order = 1 + i,
			hidden = function() return src.get() == nil end,
			args = {
				current = {
					type = "select", name = "Profil actif", order = 1,
					values = function() local t = {} for _, p in ipairs(src.get():GetProfiles({})) do t[p] = p end return t end,
					get = function() return src.get():GetCurrentProfile() end,
					set = function(_, v) if not InCombatLockdown() then src.get():SetProfile(v) end end,
				},
				new = {
					type = "input", name = "Nouveau profil", order = 2,
					get = function() return "" end,
					set = function(_, v) v = v and v:trim() if v ~= "" and not InCombatLockdown() then src.get():SetProfile(v) end end,
				},
				copy = {
					type = "select", name = "Copier depuis", order = 3,
					desc = "Remplace les réglages du profil actif par ceux d'un autre profil.",
					values = function()
						local t, cur = {}, src.get():GetCurrentProfile()
						for _, p in ipairs(src.get():GetProfiles({})) do if p ~= cur then t[p] = p end end
						return t
					end,
					get = function() return nil end,
					set = function(_, v) src.get():CopyProfile(v) end,
					confirm = true, confirmText = "Écraser le profil actif avec ce profil ?",
				},
				delete = {
					type = "select", name = "Supprimer un profil", order = 4,
					values = function()
						local t, cur = {}, src.get():GetCurrentProfile()
						for _, p in ipairs(src.get():GetProfiles({})) do if p ~= cur then t[p] = p end end
						return t
					end,
					get = function() return nil end,
					set = function(_, v) src.get():DeleteProfile(v) end,
					confirm = true, confirmText = "Supprimer définitivement ce profil ?",
				},
				reset = {
					type = "execute", name = "Réinitialiser le profil actif", order = 5,
					confirm = true, confirmText = "Remettre le profil actif aux réglages par défaut ?",
					func = function() src.get():ResetProfile() end,
				},
			},
		}
	end
	return { type = "group", name = "Profils", args = args }
end

ns:RegisterPage({
	key = "profiles",
	title = "Profils",
	subtitle = "Un profil pour toute l'interface (par personnage, par rôle...) ou un profil par module.",
	icon = "Interface\\Icons\\INV_Misc_Note_01",
	group = "system",
	order = 80,

	build = function(page)
		page.view = ns:CreateOptionsView(page.body, Options(), { key = "profiles" })
	end,
})
