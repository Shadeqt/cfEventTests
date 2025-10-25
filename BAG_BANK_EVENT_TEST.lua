local addon = cfItemColors

-- WoW API calls
local _CreateFrame = CreateFrame
local _C_Container = C_Container
local _C_Timer = C_Timer
local _IsBagOpen = IsBagOpen
local _GetTime = GetTime

-- Constants
local NUM_BAG_SLOTS = NUM_BAG_SLOTS
local NUM_BANKBAGSLOTS = NUM_BANKBAGSLOTS
local BANK_CONTAINER = BANK_CONTAINER

print("=== BAG AND BANK EVENT INVESTIGATION LOADED ===")
print("This module will log ALL bag and bank related events")
print("Watch your chat for detailed event information")
print("================================================")

-- Event tracking frame
local investigationFrame = _CreateFrame("Frame")

-- All possible bag and bank related events for Classic Era
local BAG_EVENTS = {
	-- Bag content events
	"BAG_UPDATE",
	"BAG_UPDATE_DELAYED",
	"BAG_UPDATE_COOLDOWN",

	-- Bag slot events
	"BAG_NEW_ITEMS_UPDATED",
	"BAG_SLOT_FLAGS_UPDATED",
	"ITEM_LOCK_CHANGED",
	"ITEM_LOCKED",
	"ITEM_UNLOCKED",

	-- Bank events
	"BANKFRAME_OPENED",
	"BANKFRAME_CLOSED",
	"PLAYERBANKSLOTS_CHANGED",
	"PLAYERBANKBAGSLOTS_CHANGED",

	-- Container events
	"ITEM_PUSH",
	"BAG_CONTAINER_UPDATE",

	-- Inventory events that might affect bags
	"UNIT_INVENTORY_CHANGED",
	"PLAYER_EQUIPMENT_CHANGED",

	-- Player entering world (for initialization)
	"PLAYER_ENTERING_WORLD",

	-- Additional container events
	"BAG_CLOSED",
	"BAG_OPEN",
}

-- Event counter
local eventCounts = {}
for _, event in ipairs(BAG_EVENTS) do
	eventCounts[event] = 0
end

-- Track last event timestamp for timing delta analysis
local lastEventTime = _GetTime()

-- Item state tracking system
local bagSnapshots = {}  -- [bagId] = { [slotId] = {itemId, stackCount, itemName, quality} }

-- Async operation tracking
local pendingAsyncOps = {}  -- Track operations that may complete asynchronously
local lastDelayedTime = nil  -- Track last BAG_UPDATE_DELAYED to detect double-delayed cycles

-- Stale data verification for ITEM_PUSH
local pendingItemPush = {}  -- { bagId = {iconFileID, timestamp, verified} }

-- UI state tracking
local bagFrameStates = {}  -- [bagId] = isVisible
local bankFrameOpen = false

-- Register all events
for _, event in ipairs(BAG_EVENTS) do
	investigationFrame:RegisterEvent(event)
	print("|cff00ff00Registered:|r " .. event)
end

-- Helper function to get bag info
local function getBagInfo(bagId)
	if not bagId then return "nil" end

	local numSlots = _C_Container.GetContainerNumSlots(bagId)
	local freeSlots = _C_Container.GetContainerNumFreeSlots(bagId)
	local isOpen = _IsBagOpen(bagId)
	local openStatus = isOpen and "OPEN" or "CLOSED"

	local bagType = "unknown"
	if bagId == 0 then
		bagType = "BACKPACK"
	elseif bagId == BANK_CONTAINER then
		bagType = "BANK"
	elseif bagId >= 1 and bagId <= NUM_BAG_SLOTS then
		bagType = "BAG"
	elseif bagId >= (NUM_BAG_SLOTS + 1) and bagId <= (NUM_BAG_SLOTS + NUM_BANKBAGSLOTS) then
		bagType = "BANK_BAG"
	end

	return string.format("%s [ID:%d, Slots:%d/%d, %s]", bagType, bagId, numSlots - freeSlots, numSlots, openStatus)
end

-- Helper function to get item info
local function getItemInfo(bagId, slotId)
	if not bagId or not slotId then return "nil" end

	local itemId = _C_Container.GetContainerItemID(bagId, slotId)
	if not itemId then return "empty" end

	local containerInfo = _C_Container.GetContainerItemInfo(bagId, slotId)
	if not containerInfo then return "itemId:" .. itemId .. " (no info)" end

	local itemLink = containerInfo.hyperlink
	local itemName = itemLink and itemLink:match("%[(.-)%]") or "unknown"
	local stackCount = containerInfo.stackCount or 0
	local quality = containerInfo.quality or 0

	return string.format("%s (x%d, q%d, id:%d)", itemName, stackCount, quality, itemId)
end

-- Helper function to snapshot a bag's current state
local function snapshotBag(bagId)
	if not bagId then return nil end

	local snapshot = {}
	local numSlots = _C_Container.GetContainerNumSlots(bagId)
	if not numSlots or numSlots == 0 then return snapshot end

	for slotId = 1, numSlots do
		local itemId = _C_Container.GetContainerItemID(bagId, slotId)
		if itemId then
			local containerInfo = _C_Container.GetContainerItemInfo(bagId, slotId)
			if containerInfo then
				local itemLink = containerInfo.hyperlink
				local itemName = itemLink and itemLink:match("%[(.-)%]") or "unknown"
				snapshot[slotId] = {
					itemId = itemId,
					stackCount = containerInfo.stackCount or 1,
					itemName = itemName,
					quality = containerInfo.quality or 0
				}
			end
		end
	end

	return snapshot
end

-- Helper function to compare two bag snapshots and detect changes
local function compareBagSnapshots(bagId, oldSnapshot, newSnapshot)
	if not oldSnapshot or not newSnapshot then return nil end

	local changes = {
		added = {},      -- Items that appeared
		removed = {},    -- Items that disappeared
		changed = {}     -- Items whose stack count changed
	}

	-- Check for removed or changed items
	for slotId, oldItem in pairs(oldSnapshot) do
		local newItem = newSnapshot[slotId]
		if not newItem then
			-- Item was removed
			table.insert(changes.removed, {
				slotId = slotId,
				itemName = oldItem.itemName,
				stackCount = oldItem.stackCount,
				itemId = oldItem.itemId
			})
		elseif newItem.itemId == oldItem.itemId and newItem.stackCount ~= oldItem.stackCount then
			-- Stack count changed
			table.insert(changes.changed, {
				slotId = slotId,
				itemName = newItem.itemName,
				oldCount = oldItem.stackCount,
				newCount = newItem.stackCount,
				itemId = newItem.itemId
			})
		elseif newItem.itemId ~= oldItem.itemId then
			-- Different item in same slot (treat as remove + add)
			table.insert(changes.removed, {
				slotId = slotId,
				itemName = oldItem.itemName,
				stackCount = oldItem.stackCount,
				itemId = oldItem.itemId
			})
			table.insert(changes.added, {
				slotId = slotId,
				itemName = newItem.itemName,
				stackCount = newItem.stackCount,
				itemId = newItem.itemId
			})
		end
	end

	-- Check for added items
	for slotId, newItem in pairs(newSnapshot) do
		if not oldSnapshot[slotId] then
			table.insert(changes.added, {
				slotId = slotId,
				itemName = newItem.itemName,
				stackCount = newItem.stackCount,
				itemId = newItem.itemId
			})
		end
	end

	return changes
end

-- Event handler with detailed logging
investigationFrame:SetScript("OnEvent", function(self, event, ...)
	local arg1, arg2, arg3, arg4 = ...
	eventCounts[event] = (eventCounts[event] or 0) + 1

	local currentTime = _GetTime()
	local timeSinceLastEvent = currentTime - lastEventTime
	local timestamp = string.format("[%.2f]", currentTime)
	local countInfo = string.format("[#%d]", eventCounts[event])
	local deltaInfo = string.format("(+%.0fms)", timeSinceLastEvent * 1000)

	print("|cffff9900" .. timestamp .. " " .. countInfo .. " " .. deltaInfo .. " |cff00ffff" .. event .. "|r")

	lastEventTime = currentTime

	-- Event-specific detailed logging
	if event == "BAG_UPDATE" then
		local bagId = arg1
		print("  |cffffaa00Bag Updated:|r " .. getBagInfo(bagId))

		-- Take new snapshot and compare with previous
		if bagId then
			local oldSnapshot = bagSnapshots[bagId]
			local newSnapshot = snapshotBag(bagId)

			if oldSnapshot then
				local changes = compareBagSnapshots(bagId, oldSnapshot, newSnapshot)

				if changes then
					local hasChanges = (#changes.added > 0) or (#changes.removed > 0) or (#changes.changed > 0)

					if hasChanges then
						-- Show what changed
						if #changes.added > 0 then
							print("  |cff00ff00  Items ADDED:|r")
							for _, item in ipairs(changes.added) do
								print("    |cff00ff00  + Slot " .. item.slotId .. ":|r " .. item.itemName .. " x" .. item.stackCount)
							end
						end

						if #changes.removed > 0 then
							print("  |cffff0000  Items REMOVED:|r")
							for _, item in ipairs(changes.removed) do
								print("    |cffff0000  - Slot " .. item.slotId .. ":|r " .. item.itemName .. " x" .. item.stackCount)
							end
						end

						if #changes.changed > 0 then
							print("  |cffff9900  Stack counts CHANGED:|r")
							for _, item in ipairs(changes.changed) do
								print("    |cffff9900  ~ Slot " .. item.slotId .. ":|r " .. item.itemName .. " (" .. item.oldCount .. " → " .. item.newCount .. ")")
							end
						end
					else
						print("  |cffaaaaaa  No item changes detected (duplicate BAG_UPDATE)|r")
					end
				end
			else
				-- First time seeing this bag - just list contents
				local numSlots = _C_Container.GetContainerNumSlots(bagId)
				if numSlots and numSlots > 0 then
					print("  |cffaaaaaa  Initial contents:|r")
					for slotId = 1, numSlots do
						local itemInfo = getItemInfo(bagId, slotId)
						if itemInfo ~= "empty" then
							print("    |cffaaaaaa  Slot " .. slotId .. ":|r " .. itemInfo)
						end
					end
				end
			end

			-- Update snapshot for next comparison
			bagSnapshots[bagId] = newSnapshot

			-- Check if this is related to a pending ITEM_PUSH
			if pendingItemPush[bagId] then
				local pushData = pendingItemPush[bagId]
				local timeSincePush = currentTime - pushData.timestamp

				-- Verify if item is now visible in bag
				local itemVisible = false
				for slotId, itemData in pairs(newSnapshot) do
					if itemData then
						itemVisible = true
						break
					end
				end

				if itemVisible and not pushData.verified then
					print("  |cff00ff00  ✓ ITEM_PUSH item now visible at +" .. string.format("%.0fms", timeSincePush * 1000) .. " after ITEM_PUSH|r")
					pushData.verified = true
				elseif not itemVisible then
					print("  |cffff6600  ⚠ ITEM_PUSH item still not visible (stale data)|r")
				end
			end
		end

	elseif event == "BAG_UPDATE_DELAYED" then
		-- Check if this is a second DELAYED cycle (async operation)
		if lastDelayedTime then
			local timeSinceLastDelayed = currentTime - lastDelayedTime
			if timeSinceLastDelayed < 2.0 then
				print("  |cffff00ff⚠ ASYNC OPERATION DETECTED:|r Second BAG_UPDATE_DELAYED at +" .. string.format("%.0fms", timeSinceLastDelayed * 1000) .. " after previous")
				print("  |cffff00ff  This indicates async operation (cross-bag split, vendor purchase, etc.)|r")
			end
		end

		print("  |cffffaa00Info:|r All pending bag updates completed")
		lastDelayedTime = currentTime

		-- Clean up verified ITEM_PUSH entries
		for bagId, pushData in pairs(pendingItemPush) do
			if pushData.verified then
				pendingItemPush[bagId] = nil
			end
		end

	elseif event == "BAG_UPDATE_COOLDOWN" then
		local bagId = arg1
		print("  |cffffaa00Bag Cooldown:|r " .. getBagInfo(bagId))

	elseif event == "BAG_NEW_ITEMS_UPDATED" then
		print("  |cffffaa00Info:|r New items flags updated")

	elseif event == "BAG_SLOT_FLAGS_UPDATED" then
		local bagId, slotId = arg1, arg2
		print("  |cffffaa00Slot Flags:|r " .. getBagInfo(bagId))
		print("  |cffffaa00  Slot:|r " .. (slotId or "nil") .. " - " .. getItemInfo(bagId, slotId))

	elseif event == "ITEM_LOCK_CHANGED" then
		local bagId, slotId = arg1, arg2
		if bagId and slotId then
			print("  |cffffaa00Item Lock:|r " .. getBagInfo(bagId))
			print("  |cffffaa00  Slot:|r " .. slotId .. " - " .. getItemInfo(bagId, slotId))
		else
			print("  |cffffaa00Equipment Lock:|r bagId=" .. tostring(bagId) .. ", slotId=" .. tostring(slotId))
		end

	elseif event == "ITEM_LOCKED" then
		local bagId, slotId = arg1, arg2
		if bagId and slotId then
			print("  |cffff6600Item LOCKED:|r " .. getBagInfo(bagId))
			print("  |cffff6600  Slot:|r " .. slotId .. " - " .. getItemInfo(bagId, slotId))
		else
			print("  |cffff6600Equipment LOCKED:|r bagId=" .. tostring(bagId) .. ", slotId=" .. tostring(slotId))
		end

	elseif event == "ITEM_UNLOCKED" then
		local bagId, slotId = arg1, arg2
		if bagId and slotId then
			print("  |cff66ff00Item UNLOCKED:|r " .. getBagInfo(bagId))
			print("  |cff66ff00  Slot:|r " .. slotId .. " - " .. getItemInfo(bagId, slotId))
		else
			print("  |cff66ff00Equipment UNLOCKED:|r bagId=" .. tostring(bagId) .. ", slotId=" .. tostring(slotId))
		end

	elseif event == "BANKFRAME_OPENED" then
		print("  |cff00ff00Bank Opened|r")
		local numSlots = _C_Container.GetContainerNumSlots(BANK_CONTAINER)
		print("  |cffffaa00Bank has " .. numSlots .. " slots|r")

	elseif event == "BANKFRAME_CLOSED" then
		print("  |cffff0000Bank Closed|r")

	elseif event == "PLAYERBANKSLOTS_CHANGED" then
		local slotId = arg1
		print("  |cffffaa00Bank Slot Changed:|r " .. slotId .. " - " .. getItemInfo(BANK_CONTAINER, slotId))

	elseif event == "PLAYERBANKBAGSLOTS_CHANGED" then
		local slotId = arg1
		print("  |cffffaa00Bank Bag Slot Changed:|r " .. slotId)

	elseif event == "ITEM_PUSH" then
		local bagId, iconFileID = arg1, arg2
		print("  |cffffaa00Item Pushed:|r " .. getBagInfo(bagId))
		print("  |cffffaa00  Icon:|r " .. tostring(iconFileID))

		-- Check if item is already visible (unlikely, but verify)
		if bagId then
			local snapshot = snapshotBag(bagId)
			local itemCount = 0
			for slotId, itemData in pairs(snapshot) do
				if itemData then
					itemCount = itemCount + 1
				end
			end

			if itemCount > 0 then
				print("  |cff00ff00  Item already visible in bag (synchronous)|r")
			else
				print("  |cffff6600  Item NOT yet visible (stale data - will appear in later BAG_UPDATE)|r")
			end

			-- Track this ITEM_PUSH to verify when item becomes visible
			pendingItemPush[bagId] = {
				iconFileID = iconFileID,
				timestamp = currentTime,
				verified = false
			}
		end

	elseif event == "BAG_CONTAINER_UPDATE" then
		print("  |cffff00ffContainer Update:|r All containers refreshed")

	elseif event == "UNIT_INVENTORY_CHANGED" then
		local unitTarget = arg1
		print("  |cffffaa00Unit:|r " .. tostring(unitTarget))

	elseif event == "PLAYER_EQUIPMENT_CHANGED" then
		local equipmentSlot, hasCurrent = arg1, arg2
		print("  |cffffaa00Equipment Slot:|r " .. tostring(equipmentSlot) .. ", Has Item: " .. tostring(hasCurrent))

	elseif event == "PLAYER_ENTERING_WORLD" then
		local isInitialLogin, isReloadingUi = arg1, arg2
		print("  |cffffaa00Initial Login:|r " .. tostring(isInitialLogin))
		print("  |cffffaa00Reloading UI:|r " .. tostring(isReloadingUi))

	elseif event == "BAG_CLOSED" then
		local bagId = arg1
		print("  |cffffaa00Bag Closed:|r " .. getBagInfo(bagId))

	elseif event == "BAG_OPEN" then
		local bagId = arg1
		print("  |cffffaa00Bag Opened:|r " .. getBagInfo(bagId))

	else
		-- Generic logging for any other events
		print("  |cffffaa00Args:|r " .. tostring(arg1) .. ", " .. tostring(arg2) .. ", " .. tostring(arg3) .. ", " .. tostring(arg4))
	end
end)

-- Continuous UI state monitoring
local function checkBagFrameStates()
	-- Monitor ContainerFrame visibility
	for bagId = 0, NUM_BAG_SLOTS do
		local containerFrame = _G["ContainerFrame" .. (bagId + 1)]
		local isVisible = containerFrame and containerFrame:IsShown()

		if bagFrameStates[bagId] ~= isVisible then
			bagFrameStates[bagId] = isVisible
			local state = isVisible and "|cff00ff00VISIBLE|r" or "|cffff0000HIDDEN|r"
			local currentTime = _GetTime()
			local delta = currentTime - lastEventTime
			print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [UI State]|r ContainerFrame for bagId " .. bagId .. " → " .. state)
			lastEventTime = currentTime
		end
	end
end

local function checkBankFrameState()
	local isVisible = BankFrame and BankFrame:IsShown()

	if bankFrameOpen ~= isVisible then
		bankFrameOpen = isVisible
		local state = isVisible and "|cff00ff00VISIBLE|r" or "|cffff0000HIDDEN|r"
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [UI State]|r BankFrame → " .. state)
		lastEventTime = currentTime
	end
end

-- Add OnUpdate for continuous monitoring
investigationFrame:SetScript("OnUpdate", function()
	checkBagFrameStates()
	checkBankFrameState()
end)

-- Hook bag toggle functions
hooksecurefunc("ToggleBag", function(bagId)
	local currentTime = _GetTime()
	local delta = currentTime - lastEventTime
	print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Bag Hook]|r ToggleBag → bagId: " .. tostring(bagId))
	lastEventTime = currentTime
end)

hooksecurefunc("ToggleBackpack", function()
	local currentTime = _GetTime()
	local delta = currentTime - lastEventTime
	print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Bag Hook]|r ToggleBackpack")
	lastEventTime = currentTime
end)

-- Hook additional bag functions that might be used for closing
if OpenBag then
	hooksecurefunc("OpenBag", function(bagId, forceUpdate)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Bag Hook]|r OpenBag → bagId: " .. tostring(bagId) .. ", forceUpdate: " .. tostring(forceUpdate))
		lastEventTime = currentTime
	end)
end

if CloseBag then
	hooksecurefunc("CloseBag", function(bagId)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Bag Hook]|r CloseBag → bagId: " .. tostring(bagId))
		lastEventTime = currentTime
	end)
end

if CloseAllBags then
	hooksecurefunc("CloseAllBags", function()
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Bag Hook]|r CloseAllBags")
		lastEventTime = currentTime
	end)
end

if OpenAllBags then
	hooksecurefunc("OpenAllBags", function(forceUpdate)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Bag Hook]|r OpenAllBags → forceUpdate: " .. tostring(forceUpdate))
		lastEventTime = currentTime
	end)
end

-- Test functions for bag/bank hooks
local function testBagHooks()
	print("|cff00ff00=== TESTING BAG/BANK HOOKS ===|r")
	
	-- Test ToggleBackpack hook
	print("|cffffaa00Testing ToggleBackpack hook...|r")
	if ToggleBackpack then
		ToggleBackpack()
	else
		print("|cffff0000ToggleBackpack function not available|r")
	end
	
	-- Test ToggleBag hook for bag 1
	print("|cffffaa00Testing ToggleBag hook for bag 1...|r")
	if ToggleBag then
		ToggleBag(1)
	else
		print("|cffff0000ToggleBag function not available|r")
	end
	
	-- Test OpenBag hook
	print("|cffffaa00Testing OpenBag hook for bag 2...|r")
	if OpenBag then
		OpenBag(2)
	else
		print("|cffff0000OpenBag function not available|r")
	end
	
	-- Test CloseBag hook
	print("|cffffaa00Testing CloseBag hook for bag 2...|r")
	if CloseBag then
		CloseBag(2)
	else
		print("|cffff0000CloseBag function not available|r")
	end
	
	-- Test OpenAllBags hook
	print("|cffffaa00Testing OpenAllBags hook...|r")
	if OpenAllBags then
		OpenAllBags()
	else
		print("|cffff0000OpenAllBags function not available|r")
	end
	
	-- Test CloseAllBags hook
	print("|cffffaa00Testing CloseAllBags hook...|r")
	if CloseAllBags then
		CloseAllBags()
	else
		print("|cffff0000CloseAllBags function not available|r")
	end
	
	print("|cff00ff00=== BAG/BANK HOOK TESTS COMPLETE ===|r")
end

-- Slash command to test bag/bank hooks
SLASH_TESTBAGHOOKS1 = "/testbaghooks"
SlashCmdList["TESTBAGHOOKS"] = testBagHooks

print("|cff00ff00Bag/Bank investigation ready - events will print to chat|r")
print("|cff00ff00Use /testbaghooks to test bag/bank function hooks|r")
