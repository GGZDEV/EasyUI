--[[
	sortBtn.lua
		imagine a button that sorts your inventory in Bagnon, crazy am I right?!1
--]]

local Bagnon = LibStub('AceAddon-3.0'):GetAddon('Bagnon')
local L = LibStub('AceLocale-3.0'):GetLocale('Bagnon')
local SortBtn = Bagnon.Classy:New('Button')
Bagnon.SortBtn = SortBtn

local SIZE = 20
local NORMAL_TEXTURE_SIZE = 64 * (SIZE / 36)

-- Bag Sorter code from Sushi Regular
local moves = {};
local frame = CreateFrame("Frame");
local current = nil;
local isGuildBankSort = false;

local function GetIDFromLink(link)
	return link and tonumber(string.match(link, "item:(%d+)"));
end

local function GetAscensionBankType()
	-- Bagnon_Forever mirrors IsPersonalBank/IsRealmBank from BANK_PERMISSIONS_PAYLOAD
	-- onto GuildBankFrame on GUILDBANKFRAME_OPENED.
	if GuildBankFrame and GuildBankFrame.IsPersonalBank then
		return "personal"
	elseif GuildBankFrame and GuildBankFrame.IsRealmBank then
		return "realm"
	end
	return "guild"
end

local function DoGuildBankMoves()
	while (current ~= nil or #moves > 0) do
		if current ~= nil then
			if CursorHasItem() then
				local _, id = GetCursorInfo();
				if (current ~= nil and current.id == id) then
					if (current.sourcetab ~= nil) then
						PickupGuildBankItem(current.targettab, current.targetslot);
						local link = GetGuildBankItemLink(current.targettab, current.targetslot);
						if (current.id ~= GetIDFromLink(link)) then
							return;
						end
					end
				else
					moves = {};
					current = nil;
					frame:Hide();
					return;
				end
			else
				if (current.sourcetab ~= nil) then
					local link = GetGuildBankItemLink(current.targettab, current.targetslot);
					if (current.id ~= GetIDFromLink(link)) then
						return;
					end
				end
				current = nil;
			end
		else
			if (#moves > 0) then
				current = table.remove(moves, 1);
				if (current.sourcetab ~= nil) then
					PickupGuildBankItem(current.sourcetab, current.sourceslot);
					if CursorHasItem() == false then
						return;
					end
					PickupGuildBankItem(current.targettab, current.targetslot);
					local link = GetGuildBankItemLink(current.targettab, current.targetslot);
					if (current.id == GetIDFromLink(link)) then
						current = nil;
					else
						return;
					end
				end
			end
		end
	end
	frame:Hide();
	isGuildBankSort = false;
end

-- Minimum time between starting consecutive container swaps. Blasting them
-- back-to-back outpaces the realm server (which rate-limits inbound packets)
-- and the predicted client state desyncs after ~10 moves. 150ms = ~6 swaps/sec
-- sustained; raise if you see desyncs, lower if your ping is very low.
local CONTAINER_SWAP_DELAY = 0.15
-- A pickup that doesn't land on the cursor is almost always a lag race where
-- the previous swap's state hasn't propagated yet. Retry instead of dropping
-- the move (which used to leave items un-sorted on laggy servers).
local MAX_PICKUP_RETRIES = 8
local nextSwapAt = 0

local function DoContainerMoves()
	-- Cursor-predicted swap semantics (client-side, immediate):
	--   Pickup(src)              -> cursor holds src's item, src empty
	--   Pickup(tgt) with item    -> swap; cursor now holds tgt's old item
	--   Pickup(tgt) empty target -> cursor empty, tgt has src's item
	--   Pickup(src) again        -> drops cursor item into the empty src slot
	-- That third pickup completes a non-stackable swap so the cursor ends
	-- the move empty and we're ready for the next one.
	if CursorHasItem() then
		-- Something is still settling (or external interference); wait a tick.
		return
	end
	if #moves == 0 then
		frame:Hide()
		return
	end
	if GetTime() < nextSwapAt then
		return
	end

	local move = moves[1]
	if move.sourcebag == nil then
		table.remove(moves, 1)
		return
	end

	PickupContainerItem(move.sourcebag, move.sourceslot)
	if not CursorHasItem() then
		-- Pickup didn't take. On a laggy server this usually means the
		-- previous swap's client state hasn't caught up; retry a few times
		-- before giving up so we don't silently drop the move.
		move.retries = (move.retries or 0) + 1
		if move.retries < MAX_PICKUP_RETRIES then
			nextSwapAt = GetTime() + CONTAINER_SWAP_DELAY
			return
		end
		table.remove(moves, 1)
		return
	end
	move.retries = nil

	PickupContainerItem(move.targetbag, move.targetslot)
	if CursorHasItem() then
		-- Cursor holds either tgt's displaced item (normal swap) or src's
		-- item (tgt rejected the swap). Either way, dropping it into the
		-- now-empty source slot is the right finishing move.
		PickupContainerItem(move.sourcebag, move.sourceslot)
	end

	table.remove(moves, 1)
	nextSwapAt = GetTime() + CONTAINER_SWAP_DELAY
end

local function DoMoves()
	if isGuildBankSort then
		DoGuildBankMoves()
	else
		DoContainerMoves()
	end
end

local function CompareItems(lItem, rItem)
	if (rItem.id == nil) then
		return true;
	elseif (lItem.id == nil) then
		return false;
	elseif (lItem.class ~= rItem.class) then
		if lItem.class == "Weapon" or rItem.class == "Weapon" then
			return lItem.class == "Weapon"
		end
		return (lItem.class < rItem.class);
	elseif (lItem.subclass ~= rItem.subclass) then
		return (lItem.subclass < rItem.subclass);
	elseif (lItem.quality ~= rItem.quality) then
		return (lItem.quality > rItem.quality);
	elseif (lItem.name ~= rItem.name) then
		return (lItem.name < rItem.name);
	elseif ((lItem.count) ~= (rItem.count)) then
		return ((lItem.count) >= (rItem.count));
	else
		return true;
	end
end

local function BeginSort()
	current = nil;
	moves = {};
	ClearCursor();
end

local function SortGuildBankTab(tabItems)
	for i = 1, #tabItems, 1 do
		local lowest = i;
		for j = #tabItems, i + 1, -1 do
			if (CompareItems(tabItems[lowest], tabItems[j]) == false) then
				lowest = j;
			end
		end
		if (i ~= lowest) then
			local move = {};
			move.id = tabItems[lowest].id;
			move.name = tabItems[lowest].name;
			move.sourcetab = tabItems[lowest].tab;
			move.sourceslot = tabItems[lowest].slot;
			move.targettab = tabItems[i].tab;
			move.targetslot = tabItems[i].slot;
			table.insert(moves, move);

			local tmp = tabItems[i];
			tabItems[i] = tabItems[lowest];
			tabItems[lowest] = tmp;

			tmp = tabItems[i].slot;
			tabItems[i].slot = tabItems[lowest].slot;
			tabItems[lowest].slot = tmp;
			tmp = tabItems[i].tab;
			tabItems[i].tab = tabItems[lowest].tab;
			tabItems[lowest].tab = tmp;
		end
	end
end

local function SortBag(bag)
	for i = 1, #bag, 1 do
		local lowest = i;
		for j = #bag, i + 1, -1 do
			if (CompareItems(bag[lowest], bag[j]) == false) then
				lowest = j;
			end
		end
		if (i ~= lowest) then
			-- store move
			local move = {};
			move.id = bag[lowest].id;
			move.name = bag[lowest].name;
			move.sourcebag = bag[lowest].bag;
			move.sourcetab = bag[lowest].tab;
			move.sourceslot = bag[lowest].slot;
			move.targetbag = bag[i].bag;
			move.targettab = bag[i].tab;
			move.targetslot = bag[i].slot;
			table.insert(moves, move);

			-- swap items
			local tmp = bag[i];
			bag[i] = bag[lowest];
			bag[lowest] = tmp;

			-- swap slots
			tmp = bag[i].slot;
			bag[i].slot = bag[lowest].slot;
			bag[lowest].slot = tmp;
			tmp = bag[i].bag;
			bag[i].bag = bag[lowest].bag;
			bag[lowest].bag = tmp;
			tmp = bag[i].tab;
			bag[i].tab = bag[lowest].tab;
			bag[lowest].tab = tmp;
		end
	end
end

-- Returns true iff every slot in `bagID` whose GetContainerItemLink is nil
-- is also reported empty by GetContainerNumFreeSlots. When the server is
-- laggy GetContainerItemInfo/Link can transiently return nil for slots that
-- actually contain items; sorting on that snapshot generates moves that
-- treat occupied slots as empty destinations, leaving holes in the result.
local function IsBagReadConsistent(bagID)
	local slots = GetContainerNumSlots(bagID) or 0
	local reportedFree = select(1, GetContainerNumFreeSlots(bagID)) or 0
	local actualEmpty = 0
	for s = 1, slots do
		if not GetContainerItemLink(bagID, s) then
			actualEmpty = actualEmpty + 1
		end
	end
	return actualEmpty == reportedFree, actualEmpty, reportedFree
end

local function CreateBagFromID(bagID)
	local items = GetContainerNumSlots(bagID);
	local bag = {};

	for i = 1, items, 1 do
		local item = {};
		local _, count, _, _, _, _, link = GetContainerItemInfo(bagID, i);
		item.bag = bagID;
		item.slot = i;
		item.name = "<EMPTY>";
		item.id = GetIDFromLink(link);
		if (item.id ~= nil) then
			item.count = count;
			item.name, _, item.quality, _, _, item.class, item.subclass, _, item.type, _, item.price = GetItemInfo(item.id);
		end
		table.insert(bag, item);
	end
	return bag;
end

local function CreateGuildBankTabItems(tabID)
	local items = {};
	local numSlots = 98;

	for i = 1, numSlots, 1 do
		local item = {};
		local texture, count, locked = GetGuildBankItemInfo(tabID, i);
		local link = GetGuildBankItemLink(tabID, i);

		item.tab = tabID;
		item.slot = i;
		item.name = "<EMPTY>";
		item.id = GetIDFromLink(link);
		if (item.id ~= nil) then
			item.count = count or 1;
			item.name, _, item.quality, _, _, item.class, item.subclass, _, item.type, _, item.price = GetItemInfo(item.id);
		end
		table.insert(items, item);
	end
	return items;
end

-- DoContainerMoves now drains optimistically (atomic swap, no server-confirm wait),
-- so we just run on every frame; the inner loop self-throttles when the cursor
-- is unexpectedly dirty.
frame:SetScript("OnUpdate", function(self, elapsed)
	DoMoves()
end)
frame:Hide();
--

--[[ Constructor ]] --
function SortBtn:New(frameID, parent)
	local b = self:Bind(CreateFrame('Button', nil, parent))
	b:SetWidth(SIZE)
	b:SetHeight(SIZE)
	b:RegisterForClicks('anyUp')

	local nt = b:CreateTexture()
	nt:SetTexture([[Interface\Buttons\UI-Quickslot2]])
	nt:SetWidth(NORMAL_TEXTURE_SIZE)
	nt:SetHeight(NORMAL_TEXTURE_SIZE)
	nt:SetPoint('CENTER', 0, -1)
	b:SetNormalTexture(nt)

	local pt = b:CreateTexture()
	pt:SetTexture([[Interface\Buttons\UI-Quickslot-Depress]])
	pt:SetAllPoints(b)
	b:SetPushedTexture(pt)

	local ht = b:CreateTexture()
	ht:SetTexture([[Interface\Buttons\ButtonHilight-Square]])
	ht:SetAllPoints(b)
	b:SetHighlightTexture(ht)

	local icon = b:CreateTexture()
	icon:SetAllPoints(b)
	icon:SetTexture([[Interface\Icons\ability_racial_bagoftricks]])

	b:SetScript('OnClick', b.OnClick)
	b:SetScript('OnEnter', b.OnEnter)
	b:SetScript('OnLeave', b.OnLeave)
	b:SetFrameID(frameID)

	return b
end

--[[ Frame Events ]] --
function SortBtn:OnClick()
	local bags = {};

	if self.frameID == "inventory" then
		-- Refuse to sort if any bag's read is inconsistent with the server's
		-- reported free-slot count — sorting on that snapshot is what causes
		-- the post-sort holes on a laggy server.
		for i = 0, NUM_BAG_FRAMES, 1 do
			local ok, empty, reported = IsBagReadConsistent(i)
			if not ok then
				DEFAULT_CHAT_FRAME:AddMessage(format(
					"|cFFFFAA00Bagnon: bag %d not fully loaded (read %d empty, server says %d) — try sort again in a moment.|r",
					i, empty, reported))
				return
			end
		end
		isGuildBankSort = false;
		for i = 0, NUM_BAG_FRAMES, 1 do
			local bag = CreateBagFromID(i);
			local type = select(2, GetContainerNumFreeSlots(i));
			if type == nil then
				type = "ALL"
			else
				type = tostring(type);
			end
			if bags[type] == nil then
				bags[type] = bag;
			else
				for j = 1, #bag, 1 do
					table.insert(bags[type], bag[j]);
				end
			end
		end
	elseif self.frameID == "bank" then
		isGuildBankSort = false;
		local i = -1
		local bag = CreateBagFromID(i);
		local type = select(2, GetContainerNumFreeSlots(i));
		if type == nil then
			type = "ALL"
		else
			type = tostring(type);
		end
		if bags[type] == nil then
			bags[type] = bag;
		else
			for j = 1, #bag, 1 do
				table.insert(bags[type], bag[j]);
			end
		end

		for i = NUM_BAG_FRAMES+1, NUM_BAG_FRAMES + NUM_BANKBAGSLOTS, 1 do
			local bag = CreateBagFromID(i);
			local type = select(2, GetContainerNumFreeSlots(i));
			if type == nil then
				type = "ALL"
			else
				type = tostring(type);
			end
			if bags[type] == nil then
				bags[type] = bag;
			else
				for j = 1, #bag, 1 do
					table.insert(bags[type], bag[j]);
				end
			end
		end
	elseif self.frameID == "guildbank" then
		isGuildBankSort = true;

		local currentTab = GetCurrentGuildBankTab and GetCurrentGuildBankTab() or 0

		if currentTab and currentTab > 0 then
			local bankType = GetAscensionBankType()
			local canSort = false

			if bankType == "personal" or bankType == "realm" then
				canSort = true
			else
				local _, _, canView, canDeposit, _, remainingWithdrawals = GetGuildBankTabInfo(currentTab)
				if canDeposit and (remainingWithdrawals == -1 or remainingWithdrawals > 0) then
					canSort = true
				end
			end

			if canSort then
				local tabItems = CreateGuildBankTabItems(currentTab)
				bags["GUILDBANK"] = tabItems
			else
				return
			end
		else
			return
		end
	end

	local bagCount = 0
	for k, v in pairs(bags) do
		if v ~= nil then
			bagCount = bagCount + 1
		end
	end

	if bagCount == 0 then
		return
	end

	BeginSort();

	for k, v in pairs(bags) do
		if v ~= nil then
			if isGuildBankSort then
				SortGuildBankTab(v);
			else
				SortBag(v);
			end
		end
	end

	frame:Show();
end

function SortBtn:OnEnter()
	if self:GetRight() > (GetScreenWidth() / 2) then
		GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
	else
		GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
	end
	self:UpdateTooltip()
end

function SortBtn:OnLeave()
	if GameTooltip:IsOwned(self) then
		GameTooltip:Hide()
	end
end

--[[ Update Methods ]] --

function SortBtn:UpdateTooltip()
	if GameTooltip:IsOwned(self) then
		GameTooltip:SetText(L.TipShowSortBtn)
	end
end

--[[ Properties ]] --

function SortBtn:SetFrameID(frameID)
	if self:GetFrameID() ~= frameID then
		self.frameID = frameID
	end
end

function SortBtn:GetFrameID()
	return self.frameID
end
