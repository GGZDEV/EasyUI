local parent = SexyMap
local modName = "Shapes"
local mod = SexyMap:NewModule(modName)
local L = LibStub("AceLocale-3.0"):GetLocale("SexyMap")
local db
local CallbackHandler = LibStub:GetLibrary("CallbackHandler-1.0")
mod.callbacks = CallbackHandler:New(mod)

local keys = {}
local function interpolate(points, angle)
	for i = 1, #keys do tremove(keys) end
	for k, v in pairs(points) do
		tinsert(keys, k)
	end
	table.sort(keys)
	local pre, post = 0, 360
	for _, key in ipairs(keys) do
		if key <= angle then
			pre = key
		else
			post = key
			break
		end
	end
	local pct = (angle - pre) / (post - pre)
	local x1, y1 = unpack(points[pre])
	local x2, y2 = unpack(points[post])
	local x, y = x1 + ((x2 - x1) * pct), y1 + ((y2 - y1) * pct)
	return x, y
end

--[[
------------------------------------------------------------------------
  Circle. Easy!
------------------------------------------------------------------------
]]--
local function circle(angle, radius)
	local bx = cos(angle) * radius
	local by = sin(angle) * radius
	return bx, by
end

--[[
------------------------------------------------------------------------
  Other shapes. Define corners; locations are linearly interpolated.
------------------------------------------------------------------------
]]--
local shapePoints = {}
shapePoints.square = {	
	  [0] = { 1,  0},
	 [45] = { 1,  1},
	[135] = {-1,  1},
	[225] = {-1, -1},
	[315] = { 1, -1},
	[360] = { 1,  0},	
}

shapePoints.diamond = {
	[0]   = { 1,  0},
	[90]  = { 0,  1},
	[180] = {-1,  0},
	[270] = { 0, -1},
	[360] = { 1,  0}
}

local off = tan(22.5)
shapePoints.octagon = {
	[0]   = { 1,  0},
	[22.5]  = { 1,  off},
	[67.5] = {off,  1},
	[112.5] = {-off, 1},
	[157.5]  = { -1,  off},
	[202.5]  = { -1,  -off},
	[247.5]  = { -off, -1},
	[292.5]  = { off, -1},
	[337.5]  = { 1, -off},
	[360]  = { 1, 0},
}

local w, h = sin(30), cos(30)
shapePoints.hexagon = {
	[0]   = { 1,  0},
	[60]  = { w,  h},
	[120] = {-w,  h},
	[180] = {-1,  0},
	[240] = {-w, -h},
	[300] = { w, -h},
	[360] = { 1,  0}
}

shapePoints.bottomRight = {
	[0]		= {1, 0},
	[45]	= {1, 1},
	[90]	= {0, 1},
	[180]	= {-1, 0},
	[225]	= {-1, -1},
	[315]	= {1, -1},
	[360]	= {1, 0}
}
for i = 91, 179, 5 do
	shapePoints.bottomRight[i] = { cos(i), sin(i) }
end

shapePoints.topLeft = {
	  [0] 	= { 1,  0},
	 [45]	= { 1,  1},
	[135] 	= {-1,  1},
	[225] 	= {-1, -1},
	[270] 	= { 0, -1},
	[360] 	= { 1,  0},
}
for i = 271, 359, 5 do
	shapePoints.topLeft[i] = { cos(i), sin(i) }
end

shapePoints.bottomLeft = {
	  [0] = { 1,  0},
	 [90] = { 0,  1},
	[135] = {-1,  1},
	[225] = {-1, -1},
	[315] = { 1, -1},
	[360] = { 1,  0},
}
for i = 1, 89, 5 do
	shapePoints.bottomLeft[i] = { cos(i), sin(i) }
end

shapePoints.topRight = {
	  [0] = { 1,  0},
	 [45] = { 1,  1},	  
	 [90] = { 0,  1},
	[135] = {-1,  1},
	[180] = {-1,  0},
	[270] = { 0, -1},
	[315] = { 1, -1},
	[360] = { 1,  0},
}
for i = 181, 269, 5 do
	shapePoints.topRight[i] = { cos(i), sin(i) }
end


local function byShape(shape, angle, radius)
	local x,y = interpolate(shapePoints[shape], angle)
	return x * radius, y * radius
end

--[[
------------------------------------------------------------------------
  Master Shapes table
------------------------------------------------------------------------
]]--
-- Ascension 3.3.5a silently rounds Minimap:SetMaskTexture() for several texture
-- paths the upstream / retail addon assumed worked:
--   * SPELLS\T_VFX_BORDER and shapes\squareFuzzy don't exist on this client
--   * Interface\BUTTONS\WHITE8X8 loads but the engine ignores it as a mask
--     (documented in coa-template/PORTING.md)
-- The fix per PORTING.md is to bundle an opaque BLP and point the mask at it.
-- shapes/t_vfx_border.blp is the upstream BigWigsMods/SexyMap texture re-encoded
-- as BLP2/DXT3 (alpha_encoding=1) so it actually decodes on 3.3.5a.
local legacyMappings = {
	["Interface\\AddOns\\EasyUI_Minimap\\SexyMap\\shapes\\squareFuzzy"] = "Interface\\AddOns\\EasyUI_Minimap\\SexyMap\\shapes\\square",
	["SPELLS\\T_VFX_BORDER"] = "Interface\\AddOns\\EasyUI_Minimap\\SexyMap\\shapes\\square",
	["Interface\\BUTTONS\\WHITE8X8"] = "Interface\\AddOns\\EasyUI_Minimap\\SexyMap\\shapes\\square",
	-- Interim path used in coa.1 of the v1.2.5 fix before we renamed the
	-- bundled BLP to square.blp. Catches any saved profile that picked it up
	-- between the two deploys.
	["Interface\\AddOns\\EasyUI_Minimap\\SexyMap\\shapes\\t_vfx_border"] = "Interface\\AddOns\\EasyUI_Minimap\\SexyMap\\shapes\\square",
}

local shapes = {
	["Textures\\MinimapMask"] = {
		name = L["Circle"],
		geometry = circle
	},
	["ENVIRONMENTS\\STARS\\Deathsky_Mask"] = {
		name = L["Faded Circle (Small)"],
		geometry = circle
	},
	["Interface\\AddOns\\EasyUI_Minimap\\SexyMap\\shapes\\largecircle"] = {
		name = L["Faded Circle (Large)"],
		geometry = circle
	},
	["Interface\\AddOns\\EasyUI_Minimap\\SexyMap\\shapes\\diamond"] = {
		name = L["Diamond"],
		geometry = "diamond"
	},
	["Interface\\AddOns\\EasyUI_Minimap\\SexyMap\\shapes\\square"] = {
		name = L["Square"],
		geometry = "square",
		shape = "SQUARE"
	},
	["Interface\\AddOns\\EasyUI_Minimap\\SexyMap\\shapes\\heart"] = {
		name = L["Heart"],
		geometry = circle
	},
	["Interface\\AddOns\\EasyUI_Minimap\\SexyMap\\shapes\\octagon"] = {
		name = L["Octagon"],
		geometry = "octagon"
	},
	["Interface\\AddOns\\EasyUI_Minimap\\SexyMap\\shapes\\hexagon"] = {
		name = L["Hexagon"],
		geometry = "hexagon"
	},
	["Interface\\AddOns\\EasyUI_Minimap\\SexyMap\\shapes\\snowflake"] = {
		name = L["Snowflake"],
		geometry = circle
	},
	["Interface\\AddOns\\EasyUI_Minimap\\SexyMap\\shapes\\route66"] = {
		name = L["Route 66"],
		geometry = circle
	},
	["Interface\\AddOns\\EasyUI_Minimap\\SexyMap\\shapes\\bottomright"] = {
		name = L["Rounded - Bottom Right"],
		geometry = "bottomRight",
		shape = "CORNER-BOTTOMRIGHT"
	},
	["Interface\\AddOns\\EasyUI_Minimap\\SexyMap\\shapes\\bottomleft"] = {
		name = L["Rounded - Bottom Left"],
		geometry = "bottomLeft",
		shape = "CORNER-BOTTOMLEFT"
	},
	["Interface\\AddOns\\EasyUI_Minimap\\SexyMap\\shapes\\topright"] = {
		name = L["Rounded - Top Right"],
		geometry = "topRight",
		shape = "CORNER-TOPRIGHT"
	},
	["Interface\\AddOns\\EasyUI_Minimap\\SexyMap\\shapes\\topleft"] = {
		name = L["Rounded - Top Left"],
		geometry = "topLeft",
		shape = "CORNER-TOPLEFT"
	},
}

local defaults = {
	profile = {}
}

local shapeList = {}
for k, v in pairs(shapes) do
	shapeList[k] = v.name
end

local shapeOptions = {
	type = "select",
	name = L["Minimap shape"],
	values = shapeList,
	get = function()
		return legacyMappings[db.shape] or db.shape or "Textures\\MinimapMask"
	end,
	set = function(info, v)
		mod:ApplyShape(v)
	end
}

function mod:OnInitialize()
	self.db = parent.db:RegisterNamespace(modName, defaults)
	db = self.db.profile
end

-- On 3.3.5a, Minimap:SetMaskTexture() during OnEnable doesn't always bind the
-- mask — the engine appears to discard mask changes that happen before the
-- frame's first PLAYER_ENTERING_WORLD pass, even though db.shape in Lua is
-- correct. Re-apply on PLAYER_ENTERING_WORLD so the saved shape sticks after
-- /reload without the user having to re-pick a preset.
local reapplyFrame = CreateFrame("Frame")
reapplyFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
reapplyFrame:SetScript("OnEvent", function()
	if mod.ApplyShape and db then
		mod:ApplyShape()
	end
end)

function mod:OnEnable()
	db = self.db.profile
	db.shape = db.shape or parent:GetModule("General").db.profile.shape or "Textures\\MinimapMask"
	self:ApplyShape()
end

function mod:GetPosition(angle, radius)
	if angle < 0 then angle = 360 + angle end
	angle = angle % 360
	local func = shapes[db.shape] and shapes[db.shape].geometry or circle
	if type(func) == "function" then
		return func(angle, radius)
	else
		return byShape(func, angle, radius)
	end
end

function mod:GetShapeOptions()
	return shapeOptions
end

function mod:GetShape()
	return db.shape
end

local minimapShape

-- On 3.3.5a, Minimap:SetMaskTexture() doesn't trigger a texture load if the BLP
-- hasn't been referenced yet — so calling it during OnEnable after /reload
-- silently falls back to the round default. Force the engine to load the file
-- first by parking it on a hidden Minimap texture, then set the mask.
local preloadTex = Minimap:CreateTexture(nil, "BACKGROUND")
preloadTex:Hide()

function mod:ApplyShape(shape)
	shape = legacyMappings[shape] or shape
	dbShape = db.shape and legacyMappings[db.shape] or db.shape
	if shape or dbShape then
		minimapShape = (shapes[shape] or shapes[dbShape] or {}).shape or "ROUND"
		db.shape = shape or dbShape or "Textures\\MinimapMask"
		preloadTex:SetTexture(db.shape)
		Minimap:SetMaskTexture(db.shape)
	end
	self.callbacks:Fire("SexyMap_ShapeChanged")
end

function GetMininmapShape()
	return minimapShape or "ROUND"
end
