--[[
	EasyUI - Page Barres d'action
]]
local _, ns = ...

----------------------------------------------------------------
-- Section « Raccourcis clavier » (mode LibKeyBound de Bartender, en plus clair)
----------------------------------------------------------------
local function KB() return ns:GetLib("LibKeyBound-1.0") end

local function StartBinding()
	if InCombatLockdown() then return end
	local kb = KB()
	if not kb then return end
	if ns.frame then ns.frame:Hide() end
	if not kb:IsShown() then kb:Activate() end
end

-- liste lisible des touches assignées, barre par barre
local function BindingSummary()
	local bt = ns:GetAceAddon("Bartender4")
	local reg = bt and bt.Bar and bt.Bar.barregistry
	if not reg then return "" end
	local ids = {}
	for id, bar in pairs(reg) do
		if bar.buttons and bar.config and bar.config.enabled ~= false then ids[#ids + 1] = id end
	end
	table.sort(ids, function(a, b)
		local na, nb = tonumber(a), tonumber(b)
		if na and nb then return na < nb end
		if na then return true end
		if nb then return false end
		return tostring(a) < tostring(b)
	end)
	local lines = {}
	for _, id in ipairs(ids) do
		local bar = reg[id]
		local keys, n = {}, 0
		for _, button in ipairs(bar.buttons) do
			local k = button.GetHotkey and button:GetHotkey()
			if k and k ~= "" then n = n + 1 keys[#keys + 1] = k end
		end
		local label = tonumber(id) and ("Barre " .. id) or (bar.GetName and bar:GetName() or tostring(id))
		if n > 0 then
			lines[#lines + 1] = ("|cffffffff%s|r  |cffffd100%d|r touche(s) :  %s"):format(label, n, table.concat(keys, "  "))
		else
			lines[#lines + 1] = ("|cffffffff%s|r  |cff808080aucune touche|r"):format(label)
		end
	end
	return table.concat(lines, "\n")
end

local function KeyGroup()
	return {
		type = "group", name = "Raccourcis clavier", order = 5,
		args = {
			info = { type = "description", order = 1, fontSize = "medium",
				name = "Assigne une touche à n'importe quel bouton de tes barres :\n"
					.. "1. clique sur « Assigner des touches » ;\n"
					.. "2. survole un bouton et appuie sur la touche voulue (Maj, Ctrl et Alt combinables, molette et boutons de souris acceptés) ;\n"
					.. "3. Échap sur un bouton survolé efface sa touche ;\n"
					.. "4. clique sur « Terminer » dans la petite fenêtre ou retape la commande pour quitter.\n"
					.. "Les touches sont enregistrées par personnage, comme les raccourcis du jeu." },
			start = { type = "execute", name = "Assigner des touches", order = 2,
				desc = "Ferme le panneau et passe en mode raccourcis. Impossible en combat.",
				func = StartBinding },
			game = { type = "execute", name = "Raccourcis du jeu", order = 3,
				desc = "Ouvre la fenêtre de raccourcis de WoW (déplacement, interface, cibles...).",
				func = function()
					if InCombatLockdown() then return end
					if ns.frame then ns.frame:Hide() end
					if not KeyBindingFrame then LoadAddOn("Blizzard_BindingUI") end
					if KeyBindingFrame then ShowUIPanel(KeyBindingFrame) end
				end },
			showH = { type = "header", name = "Affichage", order = 10 },
			showKeys = { type = "toggle", name = "Afficher les touches sur les boutons", order = 11, width = "full",
				desc = "S'applique à toutes les barres d'action. Réglable aussi barre par barre.",
				get = function()
					local bt = ns:GetAceAddon("Bartender4")
					for _, bar in pairs(bt.Bar.barregistry) do
						if bar.GetHideHotkey and bar:GetHideHotkey() then return false end
					end
					return true
				end,
				set = function(_, v)
					local bt = ns:GetAceAddon("Bartender4")
					for _, bar in pairs(bt.Bar.barregistry) do
						if bar.SetHideHotkey then bar:SetHideHotkey(not v) end
					end
				end },
			listH = { type = "header", name = "Touches assignées", order = 20 },
			list = { type = "description", order = 21, fontSize = "medium", name = BindingSummary },
		},
	}
end

ns:RegisterPage({
	key = "bartender",
	module = "bartender",
	title = "Barres d'action",
	subtitle = "Disposition, nombre de boutons, pagination, visibilité et apparence de chaque barre.",
	icon = "Interface\\Icons\\INV_Drink_05",
	group = "modules",
	order = 20,

	build = function(page)
		local bt = ns:GetAceAddon("Bartender4")

		page.lockBtn = ns:AddPageAction(page, "Déverrouiller", 110, function()
			bt:ToggleLock()
			page.lockBtn:SetLabel(bt.Locked and "Déverrouiller" or "Verrouiller")
		end, "accent")

		local kb = ns:AddPageAction(page, "Raccourcis", 96, StartBinding)
		ns:AttachTooltip(kb, "Mode raccourcis", "Survole un bouton et appuie sur une touche pour l'assigner. Échap pour effacer.")

		-- ajoute la section raccourcis à l'arbre d'options de Bartender
		local reg = ns:GetLib("AceConfigRegistry-3.0")
		if reg and reg:GetOptionsTable("Bartender4") then reg:GetOptionsTable("Bartender4")("dialog", "EasyUI-1.0") end
		if bt.options and bt.options.args and not bt.options.args.easyKeys then
			bt.options.args.easyKeys = KeyGroup()
		end

		page.view = ns:CreateOptionsView(page.body, "Bartender4", {
			key = "bartender",
			-- profils gérés dans la page Profils, FAQ inutile
			hide = { profiles = true, faq = true, minimapIcon = true, kb = true },
		})
	end,

	onShow = function(page)
		local bt = ns:GetAceAddon("Bartender4")
		if page.lockBtn and bt then page.lockBtn:SetLabel(bt.Locked and "Déverrouiller" or "Verrouiller") end
	end,
})
