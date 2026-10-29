--[[
	EasyUI - Page Barres d'incantation
]]
local _, ns = ...
local C = ns.colors

-- Aperçu : barre du joueur dessinée avec ses réglages (taille, icône, couleur, textes)
local function BuildPreview(page)
	local p = ns:AddPagePreview(page, 56)
	local area = p.area

	local icon = ns:CreateIcon(area, 25, "Interface\\Icons\\Spell_Frost_FrostBolt02")
	local bar = CreateFrame("Frame", nil, area)
	ns:SetBackdrop(bar, { 0.078, 0.078, 0.078, 1 }, { 0, 0, 0, 1 })
	local fill = bar:CreateTexture(nil, "ARTWORK")
	fill:SetPoint("TOPLEFT", 1, -1)
	fill:SetPoint("BOTTOMLEFT", 1, 1)
	local ticks = {}
	for i = 1, 2 do
		local t = ns:CreateTex(bar, "OVERLAY", { 0, 0, 0, 0.55 })
		t:SetWidth(1)
		t:SetPoint("TOP", 0, -1)
		t:SetPoint("BOTTOM", 0, 1)
		ticks[i] = t
	end
	local lag = ns:CreateTex(bar, "OVERLAY", { 0.78, 0.16, 0.16, 0.55 })
	lag:SetPoint("TOPRIGHT", -1, -1)
	lag:SetPoint("BOTTOMRIGHT", -1, 1)
	local name = ns:CreateText(bar, 11, { 1, 1, 1, 1 })
	name:SetPoint("LEFT", 6, 0)
	name:SetText("Éclair de givre")
	local time = ns:CreateText(bar, 11, { 1, 1, 1, 1 }, nil, "RIGHT")
	time:SetPoint("RIGHT", -6, 0)
	time:SetText("1.2 / 2.0")
	local hint = ns:CreateText(area, 12, C.muted)
	hint:SetText("ticks et latence affichés")

	function p:Refresh()
		local q = ns:GetAceAddon("Quartz3")
		local mod = q and q:GetModule("Player", true)
		local db = mod and mod.db and mod.db.profile or {}
		local w = math.max(80, math.min(420, db.w or 180))
		local h = math.max(8, math.min(40, db.h or 25))
		bar:SetSize(w, h)
		icon:SetSize(h, h)
		bar:ClearAllPoints()
		icon:ClearAllPoints()
		local gap = db.icongap or 4
		if db.hideicon then
			icon:Hide()
			bar:SetPoint("LEFT", area, "LEFT", 0, 0)
		elseif db.iconposition == "right" then
			icon:Show()
			bar:SetPoint("LEFT", area, "LEFT", 0, 0)
			icon:SetPoint("LEFT", bar, "RIGHT", gap, 0)
		else
			icon:Show()
			icon:SetPoint("LEFT", area, "LEFT", 0, 0)
			bar:SetPoint("LEFT", icon, "RIGHT", gap, 0)
		end
		local LSM = ns:GetLib("LibSharedMedia-3.0")
		fill:SetTexture((LSM and db.texture and LSM:Fetch("statusbar", db.texture, true)) or ns.media.white)
		local col = q and q.db and q.db.profile.castingcolor or { 1, 0.49, 0 }
		fill:SetVertexColor(col[1], col[2], col[3], 1)
		fill:SetWidth((w - 2) * 0.62)
		ticks[1]:SetPoint("LEFT", bar, "LEFT", math.floor(w * 0.33), 0)
		ticks[2]:SetPoint("LEFT", bar, "LEFT", math.floor(w * 0.66), 0)
		lag:SetWidth(math.max(2, (w - 2) * 0.07))
		ns.SetShown(name, not db.hidenametext)
		ns.SetShown(time, not db.hidetimetext)
		hint:ClearAllPoints()
		hint:SetPoint("LEFT", (not db.hideicon and db.iconposition == "right") and icon or bar, "RIGHT", 16, 0)
	end
	return p
end

ns:RegisterPage({
	key = "quartz",
	module = "quartz",
	title = "Barres d'incantation",
	subtitle = "Joueur, cible, focus, familier, GCD, latence, buffs, swing, interruptions, vol...",
	icon = "Interface\\Icons\\Spell_Nature_Lightning",
	group = "modules",
	order = 30,

	build = function(page)
		page.lockBtn = ns:AddPageAction(page, "Déverrouiller", nil, function()
			local q = ns:GetAceAddon("Quartz3")
			if q.unlock then q:Lock() else q:Unlock(false) end
			page.lockBtn:SetLabel(q.unlock and "Verrouiller" or "Déverrouiller")
		end, "accent")
		ns:AttachTooltip(page.lockBtn, "Déplacer les barres", "Affiche les barres d'incantation pour pouvoir les placer à la souris.")

		local style = ns:AddPageAction(page, "Style EasyUI", nil, function() ns:ApplyQuartzTheme() end)
		ns:AttachTooltip(style, "Style EasyUI", "Applique la texture, la bordure et la police EasyUI à toutes les barres d'incantation.")

		page.castPreview = BuildPreview(page)

		page.view = ns:CreateOptionsView(page.body, "Quartz3", {
			key = "quartz",
			hide = { Profiles = true },
		})
		page.view.onRefresh = function() page.castPreview:Refresh() end
	end,

	onShow = function(page)
		local q = ns:GetAceAddon("Quartz3")
		if page.lockBtn and q then page.lockBtn:SetLabel(q.unlock and "Verrouiller" or "Déverrouiller") end
		if page.castPreview then page.castPreview:Refresh() end
	end,
})
