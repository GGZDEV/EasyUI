--[[
	Copyright (c) 2009, Hendrik "Nevcairiel" Leppkes < h.leppkes at gmail dot com >
	All rights reserved.
]]

if not HasMultiCastActionBar then return end

-- CoA: UnitClassMask may be absent on this client; treat as "no mask".
local classMask = UnitClassMask and UnitClassMask("player")

-- CoA: Enum.ClassMask only knows vanilla classes (SHAMAN/HERO); custom classes
-- (e.g. Witchdoctor) won't match. EnumUtil/Enum.ClassMask may also be nil on
-- this client. Guard both: if the mask API is unavailable OR the player's class
-- isn't in the vanilla set, fall through to the MultiCastActionBarFrame check —
-- if the engine created the bar for this player we wrap it regardless of class.
local _vanillaMask = EnumUtil and Enum and Enum.ClassMask
  and EnumUtil.CombineMasks(Enum.ClassMask.SHAMAN, Enum.ClassMask.HERO)
if _vanillaMask and classMask and not bit.contains(_vanillaMask, classMask)
   and not MultiCastActionBarFrame then
	return
end

-- fetch upvalues
local L = LibStub("AceLocale-3.0"):GetLocale("Bartender4")
local Bar = Bartender4.Bar.prototype

local defaults = { profile = Bartender4:Merge({
	enabled = true,
}, Bartender4.Bar.defaults) }

-- register module
local MultiCastMod = Bartender4:NewModule("MultiCast")

-- create prototype information
local MultiCastBar = setmetatable({}, {__index = Bar})

local function OnShowMultiCastActionBar()
	if MultiCastMod:IsEnabled() then
		MultiCastMod:ApplyConfig()
	end
end

function MultiCastMod:OnInitialize()
	hooksecurefunc("ShowMultiCastActionBar", OnShowMultiCastActionBar)
	self.db = Bartender4.db:RegisterNamespace("MultiCast", defaults)
	self:SetEnabledState(self.db.profile.enabled)
end

function MultiCastMod:OnEnable()
	if not self.bar then
		self.bar = setmetatable(Bartender4.Bar:Create("MultiCast", self.db.profile, L["Totem Bar"]), {__index = MultiCastBar})
		self.bar.content = MultiCastActionBarFrame
		self.bar.content:SetScript("OnShow", nil)
		self.bar.content:SetScript("OnHide", nil)
		self.bar.content:SetScript("OnUpdate", nil)
		self.bar.content.ignoreFramePositionManager = true

		self.bar.content:SetParent(self.bar)
		self.bar.content:Show()
		self.bar.content:SetFrameLevel(self.bar:GetFrameLevel() + 1)
	end
	self.bar:Enable()
	self:ToggleOptions()
	self:ApplyConfig()
end

function MultiCastMod:ApplyConfig()
	if not self:IsEnabled() then return end
	self.bar:ApplyConfig(self.db.profile)
end

function MultiCastBar:ApplyConfig(config)
	Bar.ApplyConfig(self, config)

	self:PerformLayout()
end

-- EasyUI : la barre prend la taille des boutons réellement affichés
-- (le cadre du jeu fait toujours 230 px, même avec 3 totems : impossible de bien centrer)
local function TotemButtons()
	local list = { _G.MultiCastSummonSpellButton, _G.MultiCastRecallSpellButton }
	for i = 1, 4 do list[#list + 1] = _G["MultiCastSlotButton" .. i] end
	for i = 1, 12 do list[#list + 1] = _G["MultiCastActionButton" .. i] end
	return list
end

function MultiCastBar:PerformLayout()
	if InCombatLockdown() then self.layoutPending = true return end
	self.layoutPending = nil
	local bar = self.content
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", self, "TOPLEFT", 3, 1)

	local cl, ct = bar:GetLeft(), bar:GetTop()
	local l, r, t, b
	if cl and ct then
		for _, btn in ipairs(TotemButtons()) do
			if btn and btn:IsShown() and btn:GetLeft() and btn:GetWidth() > 1 then
				local bl, br, bt, bb = btn:GetLeft(), btn:GetRight(), btn:GetTop(), btn:GetBottom()
				l = l and math.min(l, bl) or bl
				r = r and math.max(r, br) or br
				t = t and math.max(t, bt) or bt
				b = b and math.min(b, bb) or bb
			end
		end
	end
	if not l then
		self:SetSize(230, 40)
		return
	end
	-- coordonnées du contenu -> coordonnées de la barre
	local k = bar:GetEffectiveScale() / self:GetEffectiveScale()
	self:SetSize(math.max(10, (r - l) * k), math.max(10, (t - b) * k))
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", self, "TOPLEFT", (cl - l) * k, (ct - t) * k)
end

-- recalcul quand des totems apparaissent / disparaissent
do
	local watcher = CreateFrame("Frame")
	local wait = 0
	local function Later()
		wait = 0.1
		watcher:Show()
	end
	watcher:Hide()
	watcher:SetScript("OnUpdate", function(self, el)
		wait = wait - el
		if wait > 0 then return end
		self:Hide()
		if MultiCastMod.bar and MultiCastMod:IsEnabled() then MultiCastMod.bar:PerformLayout() end
	end)
	watcher:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_ENABLED" then
			if MultiCastMod.bar and MultiCastMod.bar.layoutPending then Later() end
		else
			Later()
		end
	end)
	for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "UPDATE_MULTI_CAST_ACTIONBAR", "SPELLS_CHANGED",
		"LEARNED_SPELL_IN_TAB", "PLAYER_REGEN_ENABLED", "PLAYER_TALENT_UPDATE" }) do
		pcall(watcher.RegisterEvent, watcher, e)
	end
	for _, fn in ipairs({ "MultiCastActionBar_Update", "MultiCastSummonSpellButton_Update", "MultiCastRecallSpellButton_Update" }) do
		if type(_G[fn]) == "function" then hooksecurefunc(fn, Later) end
	end
end
