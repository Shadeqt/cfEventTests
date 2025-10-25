-- WoW API calls (Classic Era 1.15 compatible)
local _CreateFrame = CreateFrame
local _GetTime = GetTime
local _GetNumLootItems = GetNumLootItems
local _GetLootSlotInfo = GetLootSlotInfo
local _GetLootSlotLink = GetLootSlotLink
local _LootSlot = LootSlot
local _LootSlotHasItem = LootSlotHasItem
local _CloseLoot = CloseLoot
-- Classic Era loot functions (some may not exist)
local _GetLootThreshold = GetLootThreshold  -- May not exist in Classic Era
local _GetLootMethod = GetLootMethod        -- May not exist in Classic Era  
local _GetMasterLootCandidate = GetMasterLootCandidate  -- May not exist in Classic Era
local _GetNumPartyMembers = GetNumPartyMembers
local _UnitName = UnitName
local _UnitExists = UnitExists
local _UnitIsDead = UnitIsDead
local _UnitCanAttack = UnitCanAttack
local _GetUnitName = GetUnitName
local _C_Timer = C_Timer

-- Classic Era container API - use proper Classic functions
-- In Classic Era 1.15, these functions may not exist, use alternatives
local _GetContainerNumSlots = function(bagId)
	if GetContainerNumSlots then
		return GetContainerNumSlots(bagId)
	elseif GetBagSize then
		return GetBagSize(bagId)
	else
		-- Fallback for Classic Era
		if bagId == 0 then return 20 end  -- Backpack has 20 slots
		return 0  -- Unknown bag size
	end
end

local _GetContainerItemInfo = function(bagId, slotId)
	if GetContainerItemInfo then
		return GetContainerItemInfo(bagId, slotId)
	else
		-- Classic Era fallback - return nil if function doesn't exist
		return nil
	end
end

local _GetContainerItemLink = function(bagId, slotId)
	if GetContainerItemLink then
		return GetContainerItemLink(bagId, slotId)
	else
		-- Classic Era fallback - return nil if function doesn't exist
		return nil
	end
end

print("=== LOOT EVENT INVESTIGATION LOADED ===")
print("This module will log ALL loot-related events")
print("Watch your chat for detailed event information")
print("Kill mobs, open chests, and loot to test events")
print("===========================================")

-- Event tracking frame
local investigationFrame = _CreateFrame("Frame")

-- All DIRECT loot-related events for Classic Era (1.15)
local LOOT_EVENTS = {
	-- Core loot window events
	"LOOT_OPENED",
	"LOOT_CLOSED",
	"LOOT_SLOT_CLEARED",
	"LOOT_SLOT_CHANGED",

	-- Loot method and distribution events
	"PARTY_LOOT_METHOD_CHANGED",
	"LOOT_BIND_CONFIRM",

	-- Master loot events (Classic Era)
	"OPEN_MASTER_LOOT_LIST",
	"UPDATE_MASTER_LOOT_LIST",

	-- Group loot roll events (Classic Era)
	"START_LOOT_ROLL",
	"CANCEL_LOOT_ROLL",

	-- Additional Classic Era loot events
	"LOOT_READY",
	"CORPSE_IN_RANGE",
	"CORPSE_OUT_OF_RANGE",

	-- Chat messages for loot (direct loot confirmation)
	"CHAT_MSG_LOOT",
	"CHAT_MSG_MONEY",

	-- Bag events (for tracking loot arrival only)
	"BAG_UPDATE",
	"BAG_UPDATE_DELAYED",

	-- Money events (for coin loot)
	"PLAYER_MONEY",

	-- Loot-specific UI events
	"ADDON_LOADED",
	"PLAYER_ENTERING_WORLD",
}

-- Event counter
local eventCounts = {}
for _, event in ipairs(LOOT_EVENTS) do
	eventCounts[event] = 0
end

-- Track last event timestamp for timing delta analysis
local lastEventTime = _GetTime()

-- Loot state tracking
local lootWindowOpen = false
local currentLootTarget = nil  -- Store unit ID or object name
local currentLootGUID = nil   -- Store target GUID if available
local lootSnapshot = {}       -- Store loot window contents
local lootStartTime = nil     -- When loot window opened
local lastLootedItems = {}    -- Track recently looted items

-- Loot method tracking
local currentLootMethod = nil
local currentLootThreshold = nil
local currentMasterLooter = nil

-- Loot roll tracking
local activeLootRolls = {}  -- [rollID] = { item, rollTime, players }

-- Bag update batching to reduce spam
local bagUpdateBatch = {
	active = false,
	startTime = nil,
	updates = {},  -- [bagId] = count
	timer = nil
}

-- Bag snapshot for tracking loot arrival
local bagSnapshot = {}  -- [itemId] = count

-- UI state tracking
local lootFrameVisible = false
local masterLootFrameVisible = false

-- Helper function to get loot slot info
local function getLootSlotInfo(slotIndex)
	if not slotIndex then return "nil" end

	local texture, item, quantity, quality, locked = _GetLootSlotInfo(slotIndex)
	if not texture then
		return "empty slot"
	end

	local itemLink = _GetLootSlotLink(slotIndex)
	local itemName = item or "Unknown"
	if itemLink then
		itemName = itemLink:match("%[(.-)%]") or itemName
	end

	local qualityColor = ""
	if quality == 0 then qualityColor = "|cff9d9d9d" -- Poor (grey)
	elseif quality == 1 then qualityColor = "|cffffffff" -- Common (white)
	elseif quality == 2 then qualityColor = "|cff1eff00" -- Uncommon (green)
	elseif quality == 3 then qualityColor = "|cff0070dd" -- Rare (blue)
	elseif quality == 4 then qualityColor = "|cffa335ee" -- Epic (purple)
	elseif quality == 5 then qualityColor = "|cffff8000" -- Legendary (orange)
	else qualityColor = "|cffffffff" end

	local lockedStr = locked and " (LOCKED)" or ""
	local quantityStr = quantity and quantity > 1 and (" x" .. quantity) or ""

	return string.format("[%d] %s%s|r%s%s", slotIndex, qualityColor, itemName, quantityStr, lockedStr)
end

-- Helper function to snapshot all loot slots
local function snapshotLootWindow()
	local snapshot = {}
	local numItems = _GetNumLootItems()

	if not numItems or numItems == 0 then
		return snapshot
	end

	for i = 1, numItems do
		local texture, item, quantity, quality, locked = _GetLootSlotInfo(i)
		if texture then
			local itemLink = _GetLootSlotLink(i)
			local hasItem = _LootSlotHasItem(i)

			snapshot[i] = {
				texture = texture,
				item = item,
				quantity = quantity,
				quality = quality,
				locked = locked,
				itemLink = itemLink,
				hasItem = hasItem
			}
		end
	end

	return snapshot
end

-- Helper function to get loot roll info
local function getLootRollInfo(rollID)
	if not rollID then return "invalid roll ID" end
	
	-- In Classic, we track rolls manually since GetLootRollItemInfo may not exist
	local rollInfo = activeLootRolls[rollID]
	if rollInfo then
		return string.format("Roll ID %d: %s (%ds remaining)", rollID, rollInfo.item or "Unknown Item", rollInfo.timeRemaining or 0)
	end
	
	return "Roll ID " .. rollID .. " (unknown item)"
end

-- Helper function to start bag update batching
local function startBagUpdateBatch()
	if not bagUpdateBatch.active then
		bagUpdateBatch.active = true
		bagUpdateBatch.startTime = _GetTime()
		bagUpdateBatch.updates = {}
		
		-- Schedule batch summary after 500ms of no new updates
		if bagUpdateBatch.timer then
			bagUpdateBatch.timer:Cancel()
		end
	end
end

-- Helper function to add bag update to batch
local function addBagUpdateToBatch(bagId)
	startBagUpdateBatch()
	bagUpdateBatch.updates[bagId] = (bagUpdateBatch.updates[bagId] or 0) + 1
	
	-- Reset timer - we'll summarize after 500ms of no new updates
	if bagUpdateBatch.timer then
		bagUpdateBatch.timer:Cancel()
	end
	
	bagUpdateBatch.timer = _C_Timer.After(0.5, function()
		-- Check if batch is still active (might have been reset already)
		if not bagUpdateBatch.active or not bagUpdateBatch.startTime then
			return  -- Batch was already processed, ignore this timer
		end
		
		-- Summarize the batch
		local currentTime = _GetTime()
		local batchDuration = currentTime - bagUpdateBatch.startTime
		local totalUpdates = 0
		local bagSummary = {}
		
		for bagId, count in pairs(bagUpdateBatch.updates) do
			totalUpdates = totalUpdates + count
			table.insert(bagSummary, "Bag " .. bagId .. " (" .. count .. "x)")
		end
		
		local timestamp = string.format("[%.2f]", currentTime)
		local deltaInfo = string.format("(%.0fms duration)", batchDuration * 1000)
		
		print("|cffff9900" .. timestamp .. " " .. deltaInfo .. " |cff00ffff[BAG UPDATE BATCH]|r")
		print("  |cffffaa00Total Updates:|r " .. totalUpdates .. " across " .. #bagSummary .. " bags")
		print("  |cffffaa00Bags:|r " .. table.concat(bagSummary, ", "))
		
		-- Reset batch
		bagUpdateBatch.active = false
		bagUpdateBatch.startTime = nil
		bagUpdateBatch.updates = {}
		bagUpdateBatch.timer = nil
		
		lastEventTime = currentTime
	end)
end

-- Helper function to get loot method info (Classic Era compatible)
local function getLootMethodInfo()
	-- In Classic Era, these functions may not exist, so we use pcall
	local lootMethod, masterLooterPartyID, masterLooterRaidID = nil, nil, nil
	local lootThreshold = nil
	
	-- Try to get loot method (may not exist in Classic Era)
	if _GetLootMethod then
		local success, method, masterParty, masterRaid = pcall(_GetLootMethod)
		if success then
			lootMethod = method
			masterLooterPartyID = masterParty
			masterLooterRaidID = masterRaid
		end
	end
	
	-- Try to get loot threshold (may not exist in Classic Era)
	if _GetLootThreshold then
		local success, threshold = pcall(_GetLootThreshold)
		if success then
			lootThreshold = threshold
		end
	end

	local methodStr = "Unknown"
	if lootMethod == "freeforall" then methodStr = "Free for All"
	elseif lootMethod == "roundrobin" then methodStr = "Round Robin"
	elseif lootMethod == "master" then methodStr = "Master Loot"
	elseif lootMethod == "group" then methodStr = "Group Loot"
	elseif lootMethod == "needbeforegreed" then methodStr = "Need Before Greed"
	elseif not lootMethod then methodStr = "Classic Era (method unknown)"
	end

	local thresholdStr = "Unknown"
	if lootThreshold == 0 then thresholdStr = "Poor"
	elseif lootThreshold == 1 then thresholdStr = "Common"
	elseif lootThreshold == 2 then thresholdStr = "Uncommon"
	elseif lootThreshold == 3 then thresholdStr = "Rare"
	elseif lootThreshold == 4 then thresholdStr = "Epic"
	elseif lootThreshold == 5 then thresholdStr = "Legendary"
	elseif not lootThreshold then thresholdStr = "Classic Era (threshold unknown)"
	end

	local masterLooterName = nil
	if lootMethod == "master" and masterLooterPartyID and _UnitName then
		if masterLooterPartyID == 0 then
			masterLooterName = _UnitName("player")
		else
			masterLooterName = _UnitName("party" .. masterLooterPartyID)
		end
	end

	return methodStr, thresholdStr, masterLooterName
end

-- Helper function to snapshot bag contents (Classic Era compatible)
local function snapshotBags()
	local snapshot = {}
	local NUM_BAG_SLOTS = NUM_BAG_SLOTS or 4

	-- Try to scan bags, but handle API differences gracefully
	local success, result = pcall(function()
		for bagId = 0, NUM_BAG_SLOTS do
			local numSlots = _GetContainerNumSlots(bagId)
			if numSlots and numSlots > 0 then
				for slotId = 1, numSlots do
					local itemLink = _GetContainerItemLink(bagId, slotId)
					if itemLink then
						local itemInfo = _GetContainerItemInfo(bagId, slotId)
						local stackCount = 1  -- Default stack count
						
						-- Handle different return formats
						if itemInfo then
							if type(itemInfo) == "table" then
								stackCount = itemInfo.stackCount or 1
							else
								-- itemInfo might be the stack count directly in some versions
								stackCount = itemInfo or 1
							end
						end
						
						local itemId = tonumber(itemLink:match("item:(%d+)"))
						if itemId and stackCount then
							snapshot[itemId] = (snapshot[itemId] or 0) + stackCount
						end
					end
				end
			end
		end
		return snapshot
	end)

	if success then
		return result
	else
		-- If bag scanning fails, return empty snapshot
		print("  |cffff6600Warning: Bag scanning failed (Classic Era API compatibility)|r")
		return {}
	end
end

-- Helper function to compare bag snapshots
local function compareBagSnapshots(oldSnapshot, newSnapshot)
	if not oldSnapshot or not newSnapshot then return nil end

	local changes = {}

	-- Check for new/increased items (loot gained)
	for itemId, newCount in pairs(newSnapshot) do
		local oldCount = oldSnapshot[itemId] or 0
		if newCount > oldCount then
			table.insert(changes, {
				itemId = itemId,
				oldCount = oldCount,
				newCount = newCount,
				change = newCount - oldCount,
				type = "gained"
			})
		end
	end

	-- Check for removed/decreased items (items lost/used)
	for itemId, oldCount in pairs(oldSnapshot) do
		local newCount = newSnapshot[itemId] or 0
		if newCount < oldCount then
			table.insert(changes, {
				itemId = itemId,
				oldCount = oldCount,
				newCount = newCount,
				change = newCount - oldCount,
				type = "lost"
			})
		end
	end

	return changes
end

-- Register all events with error handling
local registeredEvents = {}
for _, event in ipairs(LOOT_EVENTS) do
	local success = pcall(investigationFrame.RegisterEvent, investigationFrame, event)
	if success then
		registeredEvents[event] = true
		print("|cff00ff00Registered:|r " .. event)
	else
		print("|cffff6600Skipped (not available):|r " .. event)
	end
end

-- Event handler with detailed logging
investigationFrame:SetScript("OnEvent", function(self, event, ...)
	-- Only process events we successfully registered
	if not registeredEvents[event] then
		return
	end
	
	local arg1, arg2, arg3, arg4 = ...
	eventCounts[event] = (eventCounts[event] or 0) + 1

	local currentTime = _GetTime()
	local timeSinceLastEvent = currentTime - lastEventTime
	local timestamp = string.format("[%.2f]", currentTime)
	local countInfo = string.format("[#%d]", eventCounts[event])
	local deltaInfo = string.format("(+%.0fms)", timeSinceLastEvent * 1000)

	-- Filter bag events to only loot-related contexts
	if event == "BAG_UPDATE" then
		-- Only process if we're in loot context (but don't return early since we batch them)
		if not lootWindowOpen and not lastLootedItems.tracking then
			return  -- Don't process bag updates outside loot context
		end
	end

	-- Skip printing BAG_UPDATE events - they're handled by batching system
	if event ~= "BAG_UPDATE" then
		print("|cffff9900" .. timestamp .. " " .. countInfo .. " " .. deltaInfo .. " |cff00ffff" .. event .. "|r")
	end

	lastEventTime = currentTime

	-- Event-specific detailed logging
	if event == "LOOT_OPENED" then
		lootWindowOpen = true
		lootStartTime = currentTime
		print("  |cff00ff00Loot Window Opened|r")

		-- Identify loot source
		if _UnitExists("target") then
			currentLootTarget = _UnitName("target") or "Unknown Target"
			print("  |cffffaa00  Loot Source:|r " .. currentLootTarget .. " (unit)")
		else
			currentLootTarget = "Object/Chest"
			print("  |cffffaa00  Loot Source:|r Object or Chest")
		end

		-- Snapshot loot contents
		lootSnapshot = snapshotLootWindow()
		local numItems = _GetNumLootItems()
		print("  |cffffaa00  Loot Items:|r " .. (numItems or 0))

		-- Show all loot items
		if numItems and numItems > 0 then
			print("  |cffaaaaaa  Available loot:|r")
			for i = 1, numItems do
				local lootInfo = getLootSlotInfo(i)
				print("    |cffaaaaaa  " .. lootInfo .. "|r")
			end
		else
			print("  |cffaaaaaa  No items to loot|r")
		end

		-- Snapshot bags before looting (may be limited in Classic Era)
		bagSnapshot = snapshotBags()
		local itemCount = 0
		for _ in pairs(bagSnapshot) do itemCount = itemCount + 1 end
		print("  |cffaaaaaa  Snapshotted " .. itemCount .. " unique items before looting|r")

		-- Get current loot method
		local lootMethod, lootThreshold, masterLooter = getLootMethodInfo()
		print("  |cffffaa00  Loot Method:|r " .. lootMethod .. " (threshold: " .. lootThreshold .. ")")
		if masterLooter then
			print("  |cffffaa00  Master Looter:|r " .. masterLooter)
		end

	elseif event == "LOOT_CLOSED" then
		lootWindowOpen = false
		print("  |cff00ff00Loot Window Closed|r")

		if lootStartTime then
			local lootDuration = currentTime - lootStartTime
			print("  |cffffaa00  Loot Duration:|r " .. string.format("%.2fs", lootDuration))
		end

		-- Compare final bag state
		local newBagSnapshot = snapshotBags()
		local bagChanges = compareBagSnapshots(bagSnapshot, newBagSnapshot)

		if bagChanges and #bagChanges > 0 then
			print("  |cff00ff00  Items gained from loot:|r")
			for _, change in ipairs(bagChanges) do
				if change.type == "gained" then
					print("    |cff00ff00  + ItemID " .. change.itemId .. " x" .. change.change .. "|r")
				end
			end
		else
			print("  |cffaaaaaa  No items were looted|r")
		end

		-- Start tracking for delayed loot arrival
		lastLootedItems.tracking = true
		lastLootedItems.timestamp = currentTime
		lastLootedItems.bagSnapshot = bagSnapshot

		-- Clear loot state
		currentLootTarget = nil
		currentLootGUID = nil
		lootSnapshot = {}
		lootStartTime = nil

	elseif event == "LOOT_SLOT_CLEARED" then
		local slotIndex = arg1
		print("  |cffffaa00Loot Slot Cleared:|r slot " .. tostring(slotIndex))

		-- Show what was in this slot
		if lootSnapshot[slotIndex] then
			local item = lootSnapshot[slotIndex]
			local itemName = item.item or "Unknown"
			if item.itemLink then
				itemName = item.itemLink:match("%[(.-)%]") or itemName
			end
			local quantityStr = item.quantity and item.quantity > 1 and (" x" .. item.quantity) or ""
			print("  |cff00ff00  Looted:|r " .. itemName .. quantityStr)
		end

	elseif event == "LOOT_SLOT_CHANGED" then
		local slotIndex = arg1
		print("  |cffffaa00Loot Slot Changed:|r slot " .. tostring(slotIndex))
		print("  |cffffaa00  New contents:|r " .. getLootSlotInfo(slotIndex))

	elseif event == "PARTY_LOOT_METHOD_CHANGED" then
		print("  |cff00ff00Party Loot Method Changed|r")

		local lootMethod, lootThreshold, masterLooter = getLootMethodInfo()
		print("  |cffffaa00  New Method:|r " .. lootMethod .. " (threshold: " .. lootThreshold .. ")")
		if masterLooter then
			print("  |cffffaa00  Master Looter:|r " .. masterLooter)
		end

		-- Update tracking
		currentLootMethod = lootMethod
		currentLootThreshold = lootThreshold
		currentMasterLooter = masterLooter

	elseif event == "LOOT_BIND_CONFIRM" then
		local slotIndex = arg1
		print("  |cffff6600Loot Bind Confirmation:|r slot " .. tostring(slotIndex))
		print("  |cffff6600  ⚠ This item will bind to you!|r")

		if slotIndex then
			print("  |cffffaa00  Item:|r " .. getLootSlotInfo(slotIndex))
		end

	elseif event == "OPEN_MASTER_LOOT_LIST" then
		print("  |cff00ff00Master Loot List Opened|r")

	elseif event == "UPDATE_MASTER_LOOT_LIST" then
		print("  |cffffaa00Master Loot List Updated|r")

	elseif event == "LOOT_READY" then
		print("  |cff00ff00Loot Ready:|r Loot window data is available")

	elseif event == "CORPSE_IN_RANGE" then
		print("  |cff00ff00Corpse In Range:|r Lootable corpse is now in range")

	elseif event == "CORPSE_OUT_OF_RANGE" then
		print("  |cffff6600Corpse Out Of Range:|r Lootable corpse is now out of range")

	elseif event == "START_LOOT_ROLL" then
		local rollID, rollTime = arg1, arg2
		print("  |cff00ff00Loot Roll Started:|r Roll ID " .. tostring(rollID))
		print("  |cffffaa00  Roll Time:|r " .. tostring(rollTime) .. " seconds")
		
		-- Track this roll
		activeLootRolls[rollID] = {
			rollTime = rollTime,
			timeRemaining = rollTime,
			startTime = currentTime
		}

	elseif event == "CANCEL_LOOT_ROLL" then
		local rollID = arg1
		print("  |cffff6600Loot Roll Cancelled:|r Roll ID " .. tostring(rollID))
		
		-- Remove from tracking if we were tracking it
		if activeLootRolls[rollID] then
			activeLootRolls[rollID] = nil
		end

	elseif event == "CHAT_MSG_LOOT" then
		local message = arg1
		print("  |cff00ff00Loot Message:|r " .. tostring(message))

		-- Parse common loot messages
		if message then
			-- "You receive loot: [Item Name] x2"
			local itemLink, quantity = message:match("You receive loot: (.-)(?: x(%d+))?%.")
			if itemLink then
				local itemName = itemLink:match("%[(.-)%]") or itemLink
				local quantityStr = quantity and (" x" .. quantity) or ""
				print("  |cff00ff00  ✓ Confirmed loot:|r " .. itemName .. quantityStr)
			end

			-- "Player receives loot: [Item Name]"
			local playerName, itemLink2 = message:match("(.+) receives loot: (.+)%.")
			if playerName and itemLink2 then
				local itemName = itemLink2:match("%[(.-)%]") or itemLink2
				print("  |cffffaa00  Other player loot:|r " .. playerName .. " got " .. itemName)
			end
		end

	elseif event == "CHAT_MSG_MONEY" then
		local message = arg1
		print("  |cff00ff00Money Message:|r " .. tostring(message))

		-- Parse money messages
		if message then
			-- "You loot 5 Silver, 23 Copper"
			local money = message:match("You loot (.+)")
			if money then
				print("  |cff00ff00  ✓ Money looted:|r " .. money)
			end
		end

	elseif event == "ADDON_LOADED" then
		local addonName = arg1
		if addonName == "cfEventTests" then
			print("  |cff00ff00Loot Event Test Addon Loaded|r")
		end

	elseif event == "BAG_UPDATE" then
		local bagId = arg1
		
		-- Add to batch instead of logging immediately
		addBagUpdateToBatch(bagId)

		-- If we're tracking loot arrival, check for changes (but don't spam)
		if lastLootedItems.tracking then
			local newBagSnapshot = snapshotBags()
			local bagChanges = compareBagSnapshots(lastLootedItems.bagSnapshot, newBagSnapshot)

			if bagChanges and #bagChanges > 0 then
				for _, change in ipairs(bagChanges) do
					if change.type == "gained" then
						local timeSinceLoot = currentTime - lastLootedItems.timestamp
						print("  |cff00ff00  ✓ Loot arrived:|r ItemID " .. change.itemId .. " x" .. change.change)
						print("  |cff00ff00    Arrival timing: +" .. string.format("%.0fms", timeSinceLoot * 1000) .. " after loot closed|r")
					end
				end
			end
		end

	elseif event == "BAG_UPDATE_DELAYED" then
		print("  |cff00ff00All bag updates completed|r")
		
		-- Force batch summary if one is pending
		if bagUpdateBatch.active and bagUpdateBatch.timer and bagUpdateBatch.startTime then
			bagUpdateBatch.timer:Cancel()
			
			-- Immediate batch summary
			local batchDuration = currentTime - bagUpdateBatch.startTime
			local totalUpdates = 0
			local bagSummary = {}
			
			for bagId, count in pairs(bagUpdateBatch.updates) do
				totalUpdates = totalUpdates + count
				table.insert(bagSummary, "Bag " .. bagId .. " (" .. count .. "x)")
			end
			
			print("  |cffffaa00  Batch Summary:|r " .. totalUpdates .. " updates in " .. string.format("%.0fms", batchDuration * 1000))
			print("  |cffffaa00    Bags:|r " .. table.concat(bagSummary, ", "))
			
			-- Reset batch
			bagUpdateBatch.active = false
			bagUpdateBatch.startTime = nil
			bagUpdateBatch.updates = {}
			bagUpdateBatch.timer = nil
		end

		-- Final check for loot arrival
		if lastLootedItems.tracking then
			local newBagSnapshot = snapshotBags()
			local bagChanges = compareBagSnapshots(lastLootedItems.bagSnapshot, newBagSnapshot)

			if bagChanges and #bagChanges > 0 then
				print("  |cff00ff00  Final loot summary:|r")
				for _, change in ipairs(bagChanges) do
					if change.type == "gained" then
						print("    |cff00ff00  + ItemID " .. change.itemId .. " x" .. change.change .. "|r")
					end
				end
			end

			-- Stop tracking after 5 seconds
			local timeSinceLoot = currentTime - lastLootedItems.timestamp
			if timeSinceLoot > 5.0 then
				lastLootedItems.tracking = false
			end
		end

	elseif event == "PLAYER_MONEY" then
		-- Only log if we're in loot context
		if lootWindowOpen or (lastLootedItems.tracking and (currentTime - lastLootedItems.timestamp) < 2.0) then
			print("  |cff00ff00Money Changed|r (during/after loot)")
		end

	elseif event == "PLAYER_ENTERING_WORLD" then
		local isInitialLogin, isReloadingUi = arg1, arg2
		print("  |cffffaa00Initial Login:|r " .. tostring(isInitialLogin))
		print("  |cffffaa00Reloading UI:|r " .. tostring(isReloadingUi))

		-- Initialize loot method tracking
		local lootMethod, lootThreshold, masterLooter = getLootMethodInfo()
		currentLootMethod = lootMethod
		currentLootThreshold = lootThreshold
		currentMasterLooter = masterLooter
		print("  |cffffaa00  Initial loot method:|r " .. lootMethod .. " (threshold: " .. lootThreshold .. ")")

	else
		-- Generic logging for any other events
		print("  |cffffaa00Args:|r " .. tostring(arg1) .. ", " .. tostring(arg2) .. ", " .. tostring(arg3) .. ", " .. tostring(arg4))
	end
end)

-- Monitor LootFrame visibility
local function checkLootFrameState()
	if LootFrame and LootFrame:IsShown() then
		if not lootFrameVisible then
			lootFrameVisible = true
			local currentTime = _GetTime()
			local delta = currentTime - lastEventTime
			print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [UI State]|r LootFrame → |cff00ff00VISIBLE|r")
			lastEventTime = currentTime
		end
	else
		if lootFrameVisible then
			lootFrameVisible = false
			local currentTime = _GetTime()
			local delta = currentTime - lastEventTime
			print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [UI State]|r LootFrame → |cffff0000HIDDEN|r")
			lastEventTime = currentTime
		end
	end
end

-- Monitor MasterLooterFrame visibility
local function checkMasterLootFrameState()
	if MasterLooterFrame and MasterLooterFrame:IsShown() then
		if not masterLootFrameVisible then
			masterLootFrameVisible = true
			local currentTime = _GetTime()
			local delta = currentTime - lastEventTime
			print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [UI State]|r MasterLooterFrame → |cff00ff00VISIBLE|r")
			lastEventTime = currentTime
		end
	else
		if masterLootFrameVisible then
			masterLootFrameVisible = false
			local currentTime = _GetTime()
			local delta = currentTime - lastEventTime
			print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [UI State]|r MasterLooterFrame → |cffff0000HIDDEN|r")
			lastEventTime = currentTime
		end
	end
end

-- Add OnUpdate for continuous UI monitoring
investigationFrame:SetScript("OnUpdate", function()
	checkLootFrameState()
	checkMasterLootFrameState()
end)

-- Hook loot-related functions
if LootSlot then
	hooksecurefunc("LootSlot", function(slotIndex)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Loot Hook]|r LootSlot")
		print("  |cffffaa00Looting Slot:|r " .. getLootSlotInfo(slotIndex))
		lastEventTime = currentTime
	end)
end

if CloseLoot then
	hooksecurefunc("CloseLoot", function()
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Loot Hook]|r CloseLoot")
		lastEventTime = currentTime
	end)
end

if ConfirmLootSlot then
	hooksecurefunc("ConfirmLootSlot", function(slotIndex)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Loot Hook]|r ConfirmLootSlot")
		print("  |cffffaa00Confirming Bind:|r " .. getLootSlotInfo(slotIndex))
		lastEventTime = currentTime
	end)
end

if ConfirmLootRoll then
	hooksecurefunc("ConfirmLootRoll", function(rollID, rollType)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Loot Hook]|r ConfirmLootRoll")
		print("  |cffffaa00Roll ID:|r " .. tostring(rollID))
		print("  |cffffaa00Roll Type:|r " .. tostring(rollType))
		lastEventTime = currentTime
	end)
end

if RollOnLoot then
	hooksecurefunc("RollOnLoot", function(rollID, rollType)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Loot Hook]|r RollOnLoot")
		print("  |cffffaa00Roll ID:|r " .. tostring(rollID))
		
		local rollTypeStr = "Unknown"
		if rollType == 1 then rollTypeStr = "Need"
		elseif rollType == 2 then rollTypeStr = "Greed"
		elseif rollType == 0 then rollTypeStr = "Pass"
		end
		print("  |cffffaa00Roll Type:|r " .. rollTypeStr)
		lastEventTime = currentTime
	end)
end

-- Master loot function hooks
if GiveMasterLoot then
	hooksecurefunc("GiveMasterLoot", function(slotIndex, candidateIndex)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Master Loot Hook]|r GiveMasterLoot")
		print("  |cffffaa00Item:|r " .. getLootSlotInfo(slotIndex))
		
		local candidateName = "Unknown Player"
		if _GetMasterLootCandidate then
			local success, name = pcall(_GetMasterLootCandidate, candidateIndex)
			if success and name then
				candidateName = name
			end
		end
		print("  |cffffaa00Giving to:|r " .. tostring(candidateName))
		lastEventTime = currentTime
	end)
end

-- Loot method function hooks
if SetLootMethod then
	hooksecurefunc("SetLootMethod", function(lootMethod, masterPlayer, threshold)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Loot Hook]|r SetLootMethod")
		print("  |cffffaa00New Method:|r " .. tostring(lootMethod))
		print("  |cffffaa00Master Player:|r " .. tostring(masterPlayer))
		print("  |cffffaa00Threshold:|r " .. tostring(threshold))
		lastEventTime = currentTime
	end)
end

if SetLootThreshold then
	hooksecurefunc("SetLootThreshold", function(threshold)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Loot Hook]|r SetLootThreshold")
		print("  |cffffaa00New Threshold:|r " .. tostring(threshold))
		lastEventTime = currentTime
	end)
end

-- Additional loot-specific hooks
if SetOptOutOfLoot then
	hooksecurefunc("SetOptOutOfLoot", function(optOut)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Loot Hook]|r SetOptOutOfLoot")
		print("  |cffffaa00Opt Out:|r " .. tostring(optOut))
		lastEventTime = currentTime
	end)
end

-- Loot frame update hooks
if LootFrame_Update then
	hooksecurefunc("LootFrame_Update", function()
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Loot Hook]|r LootFrame_Update")
		lastEventTime = currentTime
	end)
end

if LootButton_OnClick then
	hooksecurefunc("LootButton_OnClick", function(self, button)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		local slotIndex = self:GetID()
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Loot Hook]|r LootButton_OnClick")
		print("  |cffffaa00Button:|r " .. tostring(button))
		print("  |cffffaa00Slot:|r " .. getLootSlotInfo(slotIndex))
		lastEventTime = currentTime
	end)
end

-- Auto-loot function hooks
if GetCVar then
	-- Monitor auto-loot setting changes
	local autoLootEnabled = GetCVar("autoLootDefault") == "1"
	local function checkAutoLootSetting()
		local newAutoLoot = GetCVar("autoLootDefault") == "1"
		if newAutoLoot ~= autoLootEnabled then
			autoLootEnabled = newAutoLoot
			local currentTime = _GetTime()
			local delta = currentTime - lastEventTime
			print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Setting Change]|r Auto-loot → " .. (autoLootEnabled and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"))
			lastEventTime = currentTime
		end
	end

	-- Check auto-loot setting periodically
	_C_Timer.NewTicker(1.0, checkAutoLootSetting)
end

-- Slash command to show current loot state
SLASH_LOOTSTATE1 = "/lootstate"
SlashCmdList["LOOTSTATE"] = function()
	print("|cff00ff00=== CURRENT LOOT STATE ===|r")
	
	print("|cffffaa00Loot Window Open:|r " .. tostring(lootWindowOpen))
	
	if currentLootTarget then
		print("|cffffaa00Current Loot Target:|r " .. tostring(currentLootTarget))
	else
		print("|cffffaa00Current Loot Target:|r none")
	end
	
	local lootMethod, lootThreshold, masterLooter = getLootMethodInfo()
	print("|cffffaa00Loot Method:|r " .. lootMethod .. " (threshold: " .. lootThreshold .. ")")
	if masterLooter then
		print("|cffffaa00Master Looter:|r " .. masterLooter)
	end
	
	-- Show active loot rolls
	local activeRolls = 0
	for rollID, rollInfo in pairs(activeLootRolls) do
		activeRolls = activeRolls + 1
	end
	
	if activeRolls > 0 then
		print("|cffffaa00Active Loot Rolls:|r " .. activeRolls)
		for rollID, rollInfo in pairs(activeLootRolls) do
			print("  |cffaaaaaa  " .. getLootRollInfo(rollID) .. "|r")
		end
	else
		print("|cffffaa00Active Loot Rolls:|r none")
	end
	
	if GetCVar then
		local autoLoot = GetCVar("autoLootDefault") == "1"
		print("|cffffaa00Auto-loot Enabled:|r " .. tostring(autoLoot))
	end
	
	print("|cff00ff00=== END LOOT STATE ===|r")
end

print("|cff00ff00Loot investigation ready - events will print to chat|r")
print("|cff00ff00Kill mobs, open chests, and loot items to test events|r")
print("|cff00ff00Use /lootstate to see current loot state|r")
print("|cff00ff00Classic Era (1.15) compatible version loaded|r")