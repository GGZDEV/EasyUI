--[[
	EasyUI - Page Click-casting
]]
local _, ns = ...
local C = ns.colors

local SET_LABELS = {
	default = "Toujours", ooc = "Hors combat", friend = "Allié", enemy = "Ennemi",
	hovercast = "Survol", global = "Global", pritalent = "Spé 1", sectalent = "Spé 2",
}

local BLIZZ = {
	{ "PlayerFrame", "Joueur" }, { "PetFrame", "Familier" }, { "TargetFrame", "Cible" },
	{ "TargetFrameToT", "Cible de la cible" }, { "FocusFrame", "Focus" }, { "FocusFrameToT", "Cible du focus" },
	{ "party", "Groupe" }, { "compactraid", "Raid compact" }, { "arena", "Ennemis d'arène" }, { "boss", "Boss" },
}

local function CQ() return _G.EasyUI_CliqueAddon or _G.Clique end

----------------------------------------------------------------
-- Liste des liaisons
----------------------------------------------------------------
local function BuildOverview(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetAllPoints()

	local info = ns:CreateText(f, 12, C.muted, ns.media.fontAlt)
	info:SetPoint("TOPLEFT", 0, 0)
	info:SetPoint("RIGHT", f, "RIGHT", 0, 0)
	f.info = info

	local box = ns:CreatePanel(f, C.panel)
	box:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -10)
	box:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)

	local area = ns:CreateScrollArea(box)
	area:SetPoint("TOPLEFT", 6, -6)
	area:SetPoint("BOTTOMRIGHT", -4, 6)
	f.area = area
	f.rows = {}

	local empty = ns:CreateText(box, 12, C.muted, nil, "CENTER")
	empty:SetPoint("CENTER")
	empty:SetText("Aucune liaison. Clique sur « Éditeur de liaisons » pour en créer.")
	f.empty = empty

	function f:Refresh()
		local cq = CQ()
		if not (cq and cq.bindings) then return end
		local profile = cq.db:GetCurrentProfile()
		self.info:SetText(("Profil : |cffffffff%s|r   -   %d liaison(s). Elles s'appliquent aux cadres d'unité (joueur, cible, groupe, raid...)."):format(profile, #cq.bindings))
		local child = self.area.child
		for _, r in ipairs(self.rows) do r:Hide() end
		for i, binding in ipairs(cq.bindings) do
			local row = self.rows[i]
			if not row then
				row = CreateFrame("Frame", nil, child)
				row:SetHeight(30)
				row.bg = ns:CreateTex(row, "BACKGROUND", { 1, 1, 1, 0.03 })
				row.bg:SetAllPoints()
				row.icon = ns:CreateIcon(row, 22, nil)
				row.icon:SetPoint("LEFT", 4, 0)
				row.key = ns:CreateText(row, 12, C.text)
				row.key:SetPoint("LEFT", row.icon, "RIGHT", 10, 0)
				row.key:SetWidth(160)
				ns:RegisterAccent(row.key, "text")
				row.action = ns:CreateText(row, 12, C.text, ns.media.fontAlt)
				row.action:SetPoint("LEFT", row.key, "RIGHT", 8, 0)
				row.action:SetWidth(250)
				row.sets = ns:CreateText(row, 10, C.muted, ns.media.fontAlt, "RIGHT")
				row.sets:SetPoint("RIGHT", -8, 0)
				row.sets:SetPoint("LEFT", row.action, "RIGHT", 8, 0)
				self.rows[i] = row
			end
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -(i - 1) * 32)
			row:SetPoint("RIGHT", child, "RIGHT", 0, 0)
			ns.SetShown(row.bg, i % 2 == 0)
			local ok, icon = pcall(cq.GetBindingIcon, cq, binding)
			row.icon.tex:SetTexture(ok and icon or "Interface\\Icons\\INV_Misc_QuestionMark")
			local ok2, key = pcall(cq.GetBindingKeyComboText, cq, binding)
			row.key:SetText(ok2 and key or tostring(binding.key))
			local ok3, action = pcall(cq.GetBindingActionText, cq, binding.type, binding)
			row.action:SetText(ok3 and action or tostring(binding.type))
			local sets = {}
			if type(binding.sets) == "table" then
				for k, v in pairs(binding.sets) do
					if v then tinsert(sets, SET_LABELS[k] or k) end
				end
			end
			table.sort(sets)
			row.sets:SetText(table.concat(sets, ", "))
			row:Show()
		end
		self.area:SetContentHeight(#cq.bindings * 32)
		ns.SetShown(self.empty, #cq.bindings == 0)
	end
	f:SetScript("OnShow", f.Refresh)
	return f
end

----------------------------------------------------------------
-- Options
----------------------------------------------------------------
local function ProfileValues()
	local t = {}
	for _, p in ipairs(CQ().db:GetProfiles({})) do t[p] = p end
	return t
end

local function Options()
	local general = { type = "group", name = "Général", order = 1, args = {
		profile = {
			type = "select", name = "Profil actif", order = 1,
			values = ProfileValues,
			get = function() return CQ().db:GetCurrentProfile() end,
			set = function(_, v) if not InCombatLockdown() then CQ().db:SetProfile(v) end end,
		},
		newProfile = {
			type = "input", name = "Nouveau profil", order = 2,
			get = function() return "" end,
			set = function(_, v) v = v and v:trim() if v ~= "" and not InCombatLockdown() then CQ().db:SetProfile(v) end end,
		},
		behaviour = { type = "header", name = "Comportement", order = 10 },
		downclick = {
			type = "toggle", name = "Déclencher à l'appui du clic", width = "full", order = 11,
			desc = "Le sort part à l'appui plutôt qu'au relâchement du bouton (expérimental).",
			get = function() return CQ().settings.downclick end,
			set = function(_, v) CQ().settings.downclick = v CQ():FireMessage("BINDINGS_CHANGED") end,
		},
		fastooc = {
			type = "toggle", name = "Couper les liaisons « hors combat » quand le groupe entre en combat", width = "full", order = 12,
			get = function() return CQ().settings.fastooc end,
			set = function(_, v) CQ().settings.fastooc = v CQ():UpdateCombatWatch() end,
		},
		stopcastingfix = {
			type = "toggle", name = "Corriger les sorts lancés sur une cible morte", width = "full", order = 13,
			get = function() return CQ().settings.stopcastingfix end,
			set = function(_, v) CQ().settings.stopcastingfix = v CQ():FireMessage("BINDINGS_CHANGED") end,
		},
		spec = { type = "header", name = "Profil par spécialisation", order = 20 },
		specswap = {
			type = "toggle", name = "Changer de profil selon la spécialisation", width = "full", order = 21,
			get = function() return CQ().settings.specswap end,
			set = function(_, v) CQ().settings.specswap = v end,
		},
	} }
	for i = 1, 12 do
		general.args["specswap" .. i] = {
			type = "select", name = "Spécialisation " .. i, order = 21 + i,
			hidden = function() return not CQ().settings.specswap end,
			values = ProfileValues,
			get = function() return CQ().settings["specswap" .. i] or CQ().db:GetCurrentProfile() end,
			set = function(_, v) CQ().settings["specswap" .. i] = v end,
		}
	end

	local frames = { type = "group", name = "Cadres pris en charge", order = 2, args = {
		info = { type = "description", order = 0, fontSize = "medium",
			name = "Cadres d'unité Blizzard qui acceptent le click-casting. Rechargement de l'interface nécessaire." },
	} }
	for i, b in ipairs(BLIZZ) do
		frames.args[b[1]] = {
			type = "toggle", name = b[2], order = i,
			get = function() return CQ().settings.blizzframes[b[1]] end,
			set = function(_, v) CQ().settings.blizzframes[b[1]] = v ns:AskReload() end,
		}
	end

	local blacklist = { type = "group", name = "Cadres exclus", order = 3, args = {
		info = { type = "description", order = 0, fontSize = "medium",
			name = "Les cadres cochés n'utilisent plus le click-casting (rechargement parfois nécessaire)." },
		list = {
			type = "multiselect", name = "Cadres", order = 1,
			values = function()
				local t, cq = {}, CQ()
				for frame in pairs(cq.ccframes or {}) do
					local n = type(frame) == "table" and frame.GetName and frame:GetName()
					if n then t[n] = n end
				end
				for n in pairs(cq.hccframes or {}) do t[n] = n end
				for n in pairs(cq.settings.blacklist or {}) do t[n] = n end
				return t
			end,
			get = function(_, key) return CQ().settings.blacklist[key] and true or false end,
			set = function(_, key, v)
				CQ().settings.blacklist[key] = v and true or nil
				CQ():FireMessage("BLACKLIST_CHANGED")
			end,
		},
	} }

	local share = { type = "group", name = "Partager", order = 4,
		hidden = function() return not (CQ().CanImportExport and CQ():CanImportExport()) end,
		args = {
			export = {
				type = "input", name = "Exporter (copier ce texte)", order = 1, width = "full",
				get = function() return CQ():GetExportString() end,
				set = function() end,
			},
			import = {
				type = "input", name = "Importer (coller un texte puis OK)", order = 2, width = "full",
				get = function() return "" end,
				set = function(_, text)
					local data = CQ():DecodeExportString(text or "")
					if data and not InCombatLockdown() then
						CQ():ImportBindings(data)
						ns:Print("Liaisons importées dans le profil actuel.")
					else
						ns:Print("Texte d'import invalide.")
					end
				end,
			},
		},
	}

	return { type = "group", name = "Click-casting", args = { general = general, frames = frames, blacklist = blacklist, share = share } }
end

ns:RegisterPage({
	key = "clique",
	module = "clique",
	title = "Click-casting",
	subtitle = "Associe sorts, macros et ciblage aux clics de souris sur les cadres d'unité.",
	icon = "Interface\\Icons\\Spell_Holy_Renew",
	group = "modules",
	order = 60,

	build = function(page)
		ns:AddPageAction(page, "Éditeur de liaisons", 150, function() ns:OpenCliqueEditor() end, "accent")

		local overview = BuildOverview(page.body)
		local optsHolder = CreateFrame("Frame", nil, page.body)
		optsHolder:SetAllPoints()
		page.overview, page.optsHolder = overview, optsHolder
		page.view = ns:CreateOptionsView(optsHolder, Options(), { key = "clique" })
		page.optionsTab = 2 -- la recherche ouvre cet onglet

		page.tabBar = ns:CreateTabs(page, { { text = "Liaisons" }, { text = "Options" } }, function(i)
			ns.SetShown(overview, i == 1)
			ns.SetShown(optsHolder, i == 2)
		end)
		overview:Hide()
		optsHolder:Hide()
	end,

	onShow = function(page)
		if not page.tabBar then return end
		local i = page.tabBar.selected or 1
		page.tabBar.selected = nil
		page.tabBar:Select(i)
	end,
})
