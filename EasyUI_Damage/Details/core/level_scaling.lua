-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Details = _G.Details
local addonName, Details222 = "Details", EasyUIPriv["Details"]

local UnitGUID = UnitGUID
local UnitLevel = UnitLevel
local UnitExists = UnitExists
local UnitIsLevelScaling = UnitIsLevelScaling
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local IsInInstance = IsInInstance
local GetInstanceInfo = GetInstanceInfo
local GetNumGroupMembers = GetNumGroupMembers
local GetTime = GetTime
local GetExpansionLevel = GetExpansionLevel
local floor = math.floor
local bitBand = bit.band
local tonumber = tonumber
local pcall = pcall
local select = select

local LevelScaling = Details.LevelScaling or {}
Details.LevelScaling = LevelScaling

LevelScaling.enabled = LevelScaling.enabled ~= false
LevelScaling.cacheDuration = LevelScaling.cacheDuration or 1
LevelScaling.levelScalingActiveCacheDuration = LevelScaling.levelScalingActiveCacheDuration or 0.5
LevelScaling.observedLevelScalingContextDuration = LevelScaling.observedLevelScalingContextDuration or 300
LevelScaling.levelCache = LevelScaling.levelCache or {}

local LE_PARTY_CATEGORY_INSTANCE = LE_PARTY_CATEGORY_INSTANCE
local OBJECT_TYPE_PLAYER = 0x00000400
local JSON_NULL = {}
local LEVEL_SCALING_UNIT_IDS = {"target", "focus", "mouseover", "targettarget", "pettarget"}

local function getExpansionModifier(modifier)
	if (type(modifier) ~= "table") then
		return modifier
	end

	local expansionLevel = GetExpansionLevel and GetExpansionLevel() or 0
	local modifierIndex = expansionLevel + 1
	return modifier[modifierIndex] or modifier["modifier_" .. modifierIndex] or modifier["modifier" .. modifierIndex] or modifier.modifier or modifier.modifier_1 or modifier.modifier1
end

local function getRowModifier(row)
	return row.modifier or getExpansionModifier(row)
end

local function jsonDecode(jsonText)
	local position = 1
	local length = #jsonText

	local function fail(message)
		error("level scaling json: " .. message .. " near byte " .. position, 3)
	end

	local function peek()
		return jsonText:sub(position, position)
	end

	local function skipWhitespace()
		while (position <= length) do
			local character = peek()
			if (character ~= " " and character ~= "\n" and character ~= "\r" and character ~= "\t") then
				return
			end
			position = position + 1
		end
	end

	local parseValue

	local function parseString()
		position = position + 1
		local output = {}

		while (position <= length) do
			local character = peek()
			if (character == "\"") then
				position = position + 1
				return table.concat(output)
			end

			if (character == "\\") then
				local escaped = jsonText:sub(position + 1, position + 1)
				if (escaped == "\"" or escaped == "\\" or escaped == "/") then
					output[#output + 1] = escaped
					position = position + 2
				elseif (escaped == "b") then
					output[#output + 1] = "\b"
					position = position + 2
				elseif (escaped == "f") then
					output[#output + 1] = "\f"
					position = position + 2
				elseif (escaped == "n") then
					output[#output + 1] = "\n"
					position = position + 2
				elseif (escaped == "r") then
					output[#output + 1] = "\r"
					position = position + 2
				elseif (escaped == "t") then
					output[#output + 1] = "\t"
					position = position + 2
				elseif (escaped == "u") then
					output[#output + 1] = "?"
					position = position + 6
				else
					fail("invalid string escape")
				end
			else
				output[#output + 1] = character
				position = position + 1
			end
		end

		fail("unterminated string")
	end

	local function parseNumber()
		local startPosition = position
		local character = peek()
		if (character == "-") then
			position = position + 1
		end

		while (position <= length and peek():match("%d")) do
			position = position + 1
		end

		if (peek() == ".") then
			position = position + 1
			while (position <= length and peek():match("%d")) do
				position = position + 1
			end
		end

		character = peek()
		if (character == "e" or character == "E") then
			position = position + 1
			character = peek()
			if (character == "+" or character == "-") then
				position = position + 1
			end
			while (position <= length and peek():match("%d")) do
				position = position + 1
			end
		end

		local value = tonumber(jsonText:sub(startPosition, position - 1))
		if (value == nil) then
			fail("invalid number")
		end

		return value
	end

	local function parseArray()
		position = position + 1
		local output = {}

		skipWhitespace()
		if (peek() == "]") then
			position = position + 1
			return output
		end

		while (position <= length) do
			output[#output + 1] = parseValue()
			skipWhitespace()

			local character = peek()
			if (character == "]") then
				position = position + 1
				return output
			elseif (character == ",") then
				position = position + 1
			else
				fail("expected ',' or ']'")
			end
		end

		fail("unterminated array")
	end

	local function parseObject()
		position = position + 1
		local output = {}

		skipWhitespace()
		if (peek() == "}") then
			position = position + 1
			return output
		end

		while (position <= length) do
			skipWhitespace()
			if (peek() ~= "\"") then
				fail("expected object key")
			end

			local key = parseString()
			skipWhitespace()
			if (peek() ~= ":") then
				fail("expected ':'")
			end

			position = position + 1
			output[key] = parseValue()
			skipWhitespace()

			local character = peek()
			if (character == "}") then
				position = position + 1
				return output
			elseif (character == ",") then
				position = position + 1
			else
				fail("expected ',' or '}'")
			end
		end

		fail("unterminated object")
	end

	function parseValue()
		skipWhitespace()
		local character = peek()

		if (character == "{") then
			return parseObject()
		elseif (character == "[") then
			return parseArray()
		elseif (character == "\"") then
			return parseString()
		elseif (character == "-" or character:match("%d")) then
			return parseNumber()
		elseif (jsonText:sub(position, position + 3) == "true") then
			position = position + 4
			return true
		elseif (jsonText:sub(position, position + 4) == "false") then
			position = position + 5
			return false
		elseif (jsonText:sub(position, position + 3) == "null") then
			position = position + 4
			return JSON_NULL
		end

		fail("unexpected value")
	end

	local result = parseValue()
	skipWhitespace()
	if (position <= length) then
		fail("trailing content")
	end

	return result
end

local function setModifier(modifierTable, modifierType, originLevel, targetLevel, modifier)
	if (not modifierType or not originLevel or not targetLevel or not modifier) then
		return
	end

	originLevel = tonumber(originLevel)
	targetLevel = tonumber(targetLevel)
	if (not originLevel or not targetLevel or not modifier) then
		return
	end

	if (type(modifier) ~= "table") then
		modifier = tonumber(modifier)
		if (not modifier) then
			return
		end
	end

	local byType = modifierTable[modifierType]
	if (not byType) then
		byType = {}
		modifierTable[modifierType] = byType
	end

	local byOrigin = byType[originLevel]
	if (not byOrigin) then
		byOrigin = {}
		byType[originLevel] = byOrigin
	end

	byOrigin[targetLevel] = modifier
end

local function normalizeJsonPayload(payload)
	local modifierTable = {}

	local rows = payload.rows or (#payload > 0 and payload)
	if (rows and #rows > 0) then
		for _, row in ipairs(rows) do
			setModifier(modifierTable, row.type, row.origin_level or row.originLevel, row.target_level or row.targetLevel, getRowModifier(row))
		end
		return modifierTable
	end

	local nestedPayload = payload.modifiers or payload
	for modifierType, byOrigin in pairs(nestedPayload) do
		if (type(byOrigin) == "table" and byOrigin ~= JSON_NULL) then
			for originLevel, byTarget in pairs(byOrigin) do
				if (type(byTarget) == "table" and byTarget ~= JSON_NULL) then
					for targetLevel, modifier in pairs(byTarget) do
						setModifier(modifierTable, modifierType, originLevel, targetLevel, modifier)
					end
				end
			end
		end
	end

	return modifierTable
end

local function getGroupUnitIds()
	if (IsInRaid and IsInRaid()) then
		return Details222.UnitIdCache.Raid
	end

	return Details222.UnitIdCache.Party
end

local function normalizeLevelScalingState(active)
	if (active ~= nil) then
		return active == true or active == 1
	end

	return nil
end

local function callLevelScalingChecker(checker, unitId, owner)
	if (type(checker) ~= "function") then
		return nil
	end

	local ok, active
	if (owner) then
		ok, active = pcall(checker, owner, unitId)
		if (ok) then
			active = normalizeLevelScalingState(active)
			if (active ~= nil) then
				return active
			end
		end

		ok, active = pcall(checker, owner)
		if (ok) then
			active = normalizeLevelScalingState(active)
			if (active ~= nil) then
				return active
			end
		end
	end

	ok, active = pcall(checker, unitId)
	if (ok) then
		active = normalizeLevelScalingState(active)
		if (active ~= nil) then
			return active
		end
	end

	if (unitId ~= nil) then
		ok, active = pcall(checker)
		if (ok) then
			active = normalizeLevelScalingState(active)
			if (active ~= nil) then
				return active
			end
		end
	end

	return nil
end

local function checkLevelScalingProviders(unitId, owner, ...)
	for i = 1, select("#", ...) do
		local result = callLevelScalingChecker(select(i, ...), unitId, owner)
		if (result ~= nil) then
			return result
		end
	end

	return nil
end

function LevelScaling:SetDamageModifierProvider(provider)
	if (provider ~= nil and type(provider) ~= "function") then
		error("Details.LevelScaling:SetDamageModifierProvider expects a function or nil", 2)
	end

	self.damageModifierProvider = provider
end

function LevelScaling:SetLevelScalingActiveProvider(provider)
	if (provider ~= nil and type(provider) ~= "function") then
		error("Details.LevelScaling:SetLevelScalingActiveProvider expects a function or nil", 2)
	end

	self.levelScalingActiveProvider = provider
	self.levelScalingActiveCache = nil
end

function LevelScaling:SetDamageModifierTable(modifierTable)
	self.damageModifierTable = modifierTable
end

function LevelScaling:SetDamageModifierJson(jsonText)
	if (type(jsonText) ~= "string") then
		error("Details.LevelScaling:SetDamageModifierJson expects a JSON string", 2)
	end

	self:SetDamageModifierTable(normalizeJsonPayload(jsonDecode(jsonText)))
end

function LevelScaling:GetCachedUnitLevel(unitGUID)
	if (not unitGUID or unitGUID == "") then
		return nil
	end

	local now = GetTime()
	local cached = self.levelCache[unitGUID]
	if (cached and cached.expiresAt > now) then
		return cached.level
	end

	for _, unitId in ipairs(getGroupUnitIds()) do
		if (UnitExists(unitId) and UnitGUID(unitId) == unitGUID) then
			local level = UnitLevel(unitId)
			if (level and level > 0) then
				self.levelCache[unitGUID] = {level = level, expiresAt = now + self.cacheDuration}
				return level
			end
		end
	end

	return nil
end

function LevelScaling:GetDamageModifier(sourceLevel, targetLevel, token, spellId, spellName, spellSchool, targetFlags)
	if (self.damageModifierProvider) then
		return self.damageModifierProvider(sourceLevel, targetLevel, token, spellId, spellName, spellSchool, targetFlags)
	end

	local ascensionLevelScaling = _G.AscensionLevelScaling
	if (ascensionLevelScaling and ascensionLevelScaling.GetDamageModifier) then
		return ascensionLevelScaling.GetDamageModifier(sourceLevel, targetLevel, token, spellId, spellName, spellSchool, targetFlags)
	end

	local modifierTable = self.damageModifierTable
	if (modifierTable) then
		local _, instanceType = IsInInstance()
		local isOpenWorld = instanceType == "none"
		local targetIsPlayer = targetFlags and bitBand(targetFlags, OBJECT_TYPE_PLAYER) ~= 0
		local damageType = token == "SWING_DAMAGE" or token == "RANGE_DAMAGE" or token == "SPELL_EXTRA_ATTACKS" or token == "DAMAGE_SPLIT"
		local modifierType

		if (damageType) then
			if (targetIsPlayer) then
				modifierType = isOpenWorld and "BaseDamageVsPlayerOpenWorld" or "BaseDamageVsPlayer"
			else
				modifierType = isOpenWorld and "BaseDamageVsCreatureOpenWorld" or "BaseDamageVsCreature"
			end
		else
			if (targetIsPlayer) then
				modifierType = isOpenWorld and "SpellDamageVsPlayerOpenWorld" or "SpellDamageVsPlayer"
			else
				modifierType = isOpenWorld and "SpellDamageVsCreatureOpenWorld" or "SpellDamageVsCreature"
			end
		end

		local byType = modifierTable[modifierType]
		local byOrigin = byType and byType[sourceLevel]
		return byOrigin and getExpansionModifier(byOrigin[targetLevel])
	end

	return nil
end

function LevelScaling:IsVisibleLevelScaledUnit(unitGUID)
	if (type(UnitIsLevelScaling) ~= "function") then
		return nil
	end

	if (unitGUID and unitGUID ~= "") then
		for _, unitId in ipairs(LEVEL_SCALING_UNIT_IDS) do
			if (UnitExists(unitId) and UnitGUID(unitId) == unitGUID) then
				return callLevelScalingChecker(UnitIsLevelScaling, unitId)
			end
		end
	end

	return callLevelScalingChecker(UnitIsLevelScaling, "target")
end

function LevelScaling:GetCurrentContextKey()
	local _, instanceType, _, _, _, _, _, mapId, _, lfgDungeonId = GetInstanceInfo and GetInstanceInfo()
	local groupSize = GetNumGroupMembers and GetNumGroupMembers() or 0
	return (mapId or 0) .. ":" .. (instanceType or "none") .. ":" .. (lfgDungeonId or 0) .. ":" .. groupSize
end

function LevelScaling:SetObservedLevelScalingContext(active, now)
	self.observedLevelScalingContext = {
		active = active and true or false,
		contextKey = self:GetCurrentContextKey(),
		expiresAt = now + self.observedLevelScalingContextDuration,
	}
end

function LevelScaling:GetObservedLevelScalingContext(now)
	local context = self.observedLevelScalingContext
	if (not context or context.expiresAt <= now or context.contextKey ~= self:GetCurrentContextKey()) then
		return nil
	end

	return context.active
end

function LevelScaling:IsLevelScalingInstanceContext()
	if (not IsInInstance or not IsInInstance() or not GetInstanceInfo) then
		return false
	end

	local _, instanceType, _, _, _, _, _, _, _, lfgDungeonId = GetInstanceInfo()
	if (instanceType ~= "party") then
		return false
	end

	if (LE_PARTY_CATEGORY_INSTANCE and IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) then
		return true
	end

	if (lfgDungeonId ~= nil and lfgDungeonId > 0) then
		return true
	end

	return true
end

function LevelScaling:IsGroupedLevelScalingActive(targetActor, targetOwner)
	local now = GetTime()
	local cached = self.levelScalingActiveCache
	if (cached and cached.expiresAt > now) then
		return cached.active
	end

	local inGroup = (IsInGroup and IsInGroup()) or (IsInRaid and IsInRaid())
	if (not inGroup) then
		self.observedLevelScalingContext = nil
		self.levelScalingActiveCache = {active = false, expiresAt = now + self.levelScalingActiveCacheDuration}
		return false
	end

	local providerResult = callLevelScalingChecker(self.levelScalingActiveProvider, "player")
	if (providerResult ~= nil) then
		self.observedLevelScalingContext = nil
		self.levelScalingActiveCache = {active = providerResult, expiresAt = now + self.levelScalingActiveCacheDuration}
		return providerResult
	end

	local ascensionLevelScaling = _G.AscensionLevelScaling
	if (ascensionLevelScaling) then
		providerResult = checkLevelScalingProviders(
			"player",
			ascensionLevelScaling,
			ascensionLevelScaling.HasLevelScaling,
			ascensionLevelScaling.UnitHasLevelScaling
		)
		if (providerResult ~= nil) then
			self.observedLevelScalingContext = nil
			self.levelScalingActiveCache = {active = providerResult, expiresAt = now + self.levelScalingActiveCacheDuration}
			return providerResult
		end
	end

	providerResult = checkLevelScalingProviders(
		"player",
		nil,
		_G.UnitHasLevelScaling
	)
	if (providerResult ~= nil) then
		self.observedLevelScalingContext = nil
		self.levelScalingActiveCache = {active = providerResult, expiresAt = now + self.levelScalingActiveCacheDuration}
		return providerResult
	end

	if (self:IsLevelScalingInstanceContext()) then
		self.levelScalingActiveCache = {active = true, expiresAt = now + self.levelScalingActiveCacheDuration}
		return true
	end

	providerResult = self:IsVisibleLevelScaledUnit(targetActor and targetActor.serial or targetOwner and targetOwner.serial)
	if (providerResult ~= nil) then
		self:SetObservedLevelScalingContext(providerResult, now)
		self.levelScalingActiveCache = {active = providerResult, expiresAt = now + self.levelScalingActiveCacheDuration}
		return providerResult
	end

	providerResult = self:GetObservedLevelScalingContext(now)
	if (providerResult ~= nil) then
		self.levelScalingActiveCache = {active = providerResult, expiresAt = now + self.levelScalingActiveCacheDuration}
		return providerResult
	end

	self.levelScalingActiveCache = {active = false, expiresAt = now + self.levelScalingActiveCacheDuration}
	return false
end

function LevelScaling:ScaleDamageAmount(amount, token, sourceSerial, sourceActor, ownerActor, targetActor, targetOwner, spellId, spellName, spellSchool, targetFlags)
	if (not self.enabled or not amount or amount <= 0) then
		return amount, nil
	end

	if (not self:IsGroupedLevelScalingActive(targetActor, targetOwner)) then
		return amount, nil
	end

	if (targetActor and targetActor.grupo or targetOwner and targetOwner.grupo) then
		return amount, nil
	end

	local scaledSourceActor = ownerActor or sourceActor
	if (not scaledSourceActor or not scaledSourceActor.grupo) then
		return amount, nil
	end

	local sourceLevel = self:GetCachedUnitLevel(scaledSourceActor.serial or sourceSerial)
	local targetLevel = UnitLevel("player")
	if (not sourceLevel or not targetLevel or sourceLevel <= 0 or targetLevel <= 0 or sourceLevel == targetLevel) then
		return amount, nil
	end

	local modifier = self:GetDamageModifier(sourceLevel, targetLevel, token, spellId, spellName, spellSchool, targetFlags)
	if (not modifier or modifier == 100) then
		return amount, nil
	end

	local scaledAmount = floor((amount * modifier / 100) + 0.5)
	if (scaledAmount <= 0) then
		scaledAmount = 1
	end

	return scaledAmount, modifier
end

function LevelScaling:ScaleRelatedAmount(amount, modifier)
	if (not amount or not modifier or amount <= 0 or modifier == 100) then
		return amount
	end

	local scaledAmount = floor((amount * modifier / 100) + 0.5)
	if (scaledAmount <= 0) then
		scaledAmount = 1
	end

	return scaledAmount
end
