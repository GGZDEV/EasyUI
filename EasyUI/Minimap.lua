--[[
	EasyUI - Bouton de minimap
	Clic gauche : panneau  |  Clic droit : mode édition  |  Glisser : déplacer
]]
local _, ns = ...

local ICON = "Interface\\Icons\\INV_Misc_Gear_08"
local button

local function UpdatePosition()
	local angle = math.rad(ns.db.minimap.angle or 215)
	local radius = (Minimap:GetWidth() / 2) + 6
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OnDragUpdate()
	local mx, my = Minimap:GetCenter()
	local cx, cy = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	cx, cy = cx / scale, cy / scale
	ns.db.minimap.angle = math.deg(math.atan2(cy - my, cx - mx)) % 360
	UpdatePosition()
end

local function Create()
	button = CreateFrame("Button", "EasyUIMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local overlay = button:CreateTexture(nil, "OVERLAY")
	overlay:SetSize(53, 53)
	overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	overlay:SetPoint("TOPLEFT")

	local bg = button:CreateTexture(nil, "BACKGROUND")
	bg:SetSize(20, 20)
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetPoint("TOPLEFT", 7, -5)

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(17, 17)
	icon:SetTexture(ICON)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:SetPoint("TOPLEFT", 7, -6)
	button.icon = icon

	button:SetScript("OnClick", function(self, btn)
		if btn == "RightButton" then
			ns:ToggleEditMode()
		else
			ns:Toggle()
		end
	end)
	button:SetScript("OnDragStart", function(self)
		self:LockHighlight()
		self:SetScript("OnUpdate", OnDragUpdate)
	end)
	button:SetScript("OnDragStop", function(self)
		self:UnlockHighlight()
		self:SetScript("OnUpdate", nil)
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine(("|cff%sEasy|rUI"):format(ns:AccentHex()))
		GameTooltip:AddLine("Clic gauche : ouvrir le panneau", 1, 1, 1)
		GameTooltip:AddLine("Clic droit : mode édition", 1, 1, 1)
		GameTooltip:AddLine("Glisser : déplacer ce bouton", 0.6, 0.6, 0.6)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)

	UpdatePosition()
end

function ns:UpdateMinimapButton()
	if not button then Create() end
	if self.db.minimap.hide then button:Hide() else button:Show() end
end

ns:On("LOGIN", function() ns:UpdateMinimapButton() end)
