--[[
	EasyUI - Tableau de bord
	Liste des modules sur deux colonnes (case pour activer / désactiver,
	icône, description, bouton Configurer), puis le profil actif.
]]
local _, ns = ...
local C = ns.colors

local ROW_H = 54
local COL_GAP = 20

local function PageOrder(mod)
	local def = mod.page and ns.pages[mod.page]
	return def and def.order or 999
end

-- état voulu au prochain chargement (la case reflète ce choix, pas l'état actuel)
local function SetWanted(mod, on)
	ns.db.modules[mod.key] = on and true or false
	if mod.addon then
		if on then EnableAddOn(mod.addon) else DisableAddOn(mod.addon) end
	end
end

local function CreateModuleRow(parent, mod, page)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(ROW_H)
	local line = ns:CreateTex(row, "BORDER", { 0.114, 0.114, 0.125, 1 })
	line:SetHeight(1)
	line:SetPoint("BOTTOMLEFT")
	line:SetPoint("BOTTOMRIGHT")

	local check = CreateFrame("Button", nil, row)
	check:SetSize(24, 24)
	check:SetPoint("LEFT", 8, 0)
	local box = ns:CreateSwitch(check)
	box:SetPoint("CENTER")
	check:SetScript("OnEnter", function(self)
		box:SetBackdropBorderColor(ns:AccentMix(0.48))
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(mod.title, 1, 1, 1)
		GameTooltip:AddLine("Cocher / décocher : active ou désactive le module au prochain rechargement de l'interface.", nil, nil, nil, true)
		GameTooltip:Show()
	end)
	check:SetScript("OnLeave", function()
		box:SetBackdropBorderColor(C.checkBorder[1], C.checkBorder[2], C.checkBorder[3], 1)
		GameTooltip:Hide()
	end)
	check:SetScript("OnClick", function()
		PlaySound("igMainMenuOptionCheckBoxOn")
		SetWanted(mod, not ns:ModuleEnabled(mod.key))
		page:RefreshModules()
	end)

	local icon = ns:CreateIcon(row, 34, mod.icon)
	icon:SetPoint("LEFT", check, "RIGHT", 8, 0)

	local cfg = ns:CreateButton(row, "Configurer", nil, 24, function() ns:ShowPage(mod.page) end)
	cfg:SetPoint("RIGHT", -4, 0)

	local name = ns:CreateText(row, 14, C.bright)
	name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -1)
	name:SetPoint("RIGHT", cfg, "LEFT", -10, 0)
	name:SetText(mod.title)

	local desc = ns:CreateText(row, 12, C.muted)
	desc:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
	desc:SetPoint("RIGHT", cfg, "LEFT", -10, 0)
	desc:SetHeight(16)
	desc:SetText(mod.desc)

	local status = ns:CreateText(row, 11, C.bad, nil, "RIGHT")
	status:SetPoint("BOTTOMRIGHT", name, "BOTTOMRIGHT", 0, 0)

	function row:Refresh()
		local enabled = ns:ModuleEnabled(mod.key)
		box:SetValue(enabled)
		if enabled then
			ns.SetTextColorC(name, C.bright)
			icon.tex:SetDesaturated(nil)
			icon:SetAlpha(1)
		else
			ns.SetTextColorC(name, C.dim)
			icon.tex:SetDesaturated(1)
			icon:SetAlpha(0.35)
		end
		-- module coché mais pas chargé : erreur ou rechargement en attente
		local loaded = not mod.addon or IsAddOnLoaded(mod.addon)
		if enabled and loaded and not ns:ModuleReady(mod.key) then
			status:SetText("erreur")
		elseif enabled and not loaded then
			status:SetText("|cffffd100à recharger|r")
		elseif not enabled and mod.addon and IsAddOnLoaded(mod.addon) then
			status:SetText("|cffffd100à recharger|r")
		else
			status:SetText("")
		end
	end
	return row
end

ns:RegisterPage({
	key = "home",
	title = "Tableau de bord",
	subtitle = "Toute ton interface au même endroit. Choisis un module à gauche, cherche un réglage, ou passe en mode édition.",
	icon = "Interface\\Icons\\INV_Misc_Map_01",
	group = "general",
	order = 1,

	build = function(page)
		-- le titre de section « Modules » sert de titre de page
		page.titleArea:SetHeight(1)
		page.title:Hide()

		local area = ns:CreateScrollArea(page.body)
		area:SetAllPoints()
		area.page = page
		local body = area.child
		local W = ns.CONTENT_W - 14
		body:SetWidth(W)

		local h1 = ns:CreateHeader(body, "Modules", 17)
		h1:SetPoint("TOPLEFT", 0, 0)
		h1:SetPoint("RIGHT", body, "RIGHT", 0, 0)
		page.modHeader = h1

		local list = {}
		for _, mod in ipairs(ns.modules) do if not mod.hidden then list[#list + 1] = mod end end
		table.sort(list, function(a, b) return PageOrder(a) < PageOrder(b) end)

		page.rows = {}
		local colW = math.floor((W - COL_GAP) / 2)
		for i, mod in ipairs(list) do
			local row = CreateModuleRow(body, mod, page)
			local col = (i - 1) % 2
			local r = math.floor((i - 1) / 2)
			row:SetPoint("TOPLEFT", h1, "BOTTOMLEFT", col * (colW + COL_GAP), -2 - r * ROW_H)
			row:SetWidth(colW)
			page.rows[i] = row
		end
		local rows = math.ceil(#list / 2)
		page.moduleCount = #list

		function page:RefreshModules()
			local on = 0
			for _, row in ipairs(self.rows) do row:Refresh() end
			for _, mod in ipairs(list) do if ns:ModuleEnabled(mod.key) then on = on + 1 end end
			self.modHeader.note:SetText(("%d activés sur %d  ·  décocher un module le désactive au prochain rechargement"):format(on, #list))
		end

		------------------------------------------------------------ profil
		local h2 = ns:CreateHeader(body, "Profil", 17)
		h2:SetPoint("TOPLEFT", h1, "BOTTOMLEFT", 0, -2 - rows * ROW_H - 18)
		h2:SetPoint("RIGHT", body, "RIGHT", 0, 0)

		local label = ns:CreateText(body, 13, C.nav)
		label:SetPoint("TOPLEFT", h2, "BOTTOMLEFT", 0, -18)
		label:SetWidth(90)
		label:SetText("Profil actif")

		local P = ns.Profiles
		local function Items(exceptCurrent)
			local t, cur = {}, P and P.Current()
			for name in pairs(P and P.All() or {}) do
				if not (exceptCurrent and name == cur) then t[#t + 1] = { value = name, text = name } end
			end
			table.sort(t, function(a, b) return a.text < b.text end)
			return t
		end

		local drop = ns:CreateDropdown(body, 240, function() return Items(false) end,
			function() return P and P.Current() end,
			function(v) if P then P.Apply(v) end end)
		drop:SetPoint("LEFT", label, "RIGHT", 0, 0)
		page.profileDrop = drop

		local copy = ns:CreateButton(body, "Copier depuis…", nil, 28)
		copy:SetPoint("LEFT", drop, "RIGHT", 10, 0)
		copy:SetScript("OnClick", function(self)
			local items = Items(true)
			if #items == 0 then ns:Print("Aucun autre profil.") return end
			ns:ShowMenu(self, items, nil, function(v) if P then P.CopyFrom(v) end end)
		end)
		ns:AttachTooltip(copy, "Copier depuis…", "Remplace les réglages du profil actif par ceux d'un autre profil, pour tous les modules.")

		local manage = ns:CreateButton(body, "Gérer les profils", nil, 28, function() ns:ShowPage("profiles") end)
		manage:SetPoint("LEFT", copy, "RIGHT", 10, 0)

		local wizard = ns:CreateButton(body, "Assistant de configuration", nil, 28, function() ns:ShowSetupWizard() end)
		wizard:SetPoint("LEFT", manage, "RIGHT", 10, 0)

		area:SetContentHeight(30 + 2 + rows * ROW_H + 18 + 30 + 18 + 30 + 10)
	end,

	onShow = function(page)
		if page.RefreshModules then page:RefreshModules() end
		if page.profileDrop then page.profileDrop:Refresh() end
	end,
})
