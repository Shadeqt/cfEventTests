-- WoW API calls
local _CreateFrame = CreateFrame
local _GetInventoryItemLink = GetInventoryItemLink
local _GetInventoryItemQuality = GetInventoryItemQuality
local _GetInventoryItemDurability = GetInventoryItemDurability
local _GetInventoryItemTexture = GetInventoryItemTexture
local _GetTime = GetTime
local _GetAverageItemLevel = GetAverageItemLevel
local _UnitName = UnitName

-- Constants - Equipment slot names (not used in test, just for reference)
local EQUIPMENT_SLOTS = {
	"Head", "Neck", "Shoulder", "Shirt", "Chest", "Waist", "Legs", "Feet", "Wrist", "Hands",
	"Finger0", "Finger1", "Trinket0", "Trinket1", "Back", "MainHand", "SecondaryHand", "Ranged", "Tabard", "Ammo"
}

print("=== CHARACTER EQUIPMENT EVENT INVESTIGATION LOADED ===")
print("This module will log ALL character equipment related events")
print("Watch your chat for detailed event information")
print("=======================================================")

-- Event tracking frame
local investigationFrame = _CreateFrame("Frame")

-- All possible character equipment related events for Classic Era
local CHARACTER_EVENTS = {
	-- Equipment events
	"PLAYER_EQUIPMENT_CHANGED",

	-- Inventory events
	"UNIT_INVENTORY_CHANGED",

	-- Durability events
	"UPDATE_INVENTORY_DURABILITY",
	"UPDATE_INVENTORY_ALERTS",

	-- Item level events
	"PLAYER_AVG_ITEM_LEVEL_UPDATE",

	-- Item locking
	"ITEM_LOCK_CHANGED",
	"ITEM_LOCKED",
	"ITEM_UNLOCKED",

	-- Character frame events
	"UNIT_MODEL_CHANGED",
	"CHARACTER_POINTS_CHANGED",

	-- Player entering world (for initialization)
	"PLAYER_ENTERING_WORLD",
}

-- Event counter
local eventCounts = {}
for _, event in ipairs(CHARACTER_EVENTS) do
	eventCounts[event] = 0
end

-- Statistics tracking (total fired vs displayed)
local eventCountsTotal = {}     -- All events fired (including filtered)
local eventCountsDisplayed = {} -- Events actually logged to chat
local hookCountsTotal = {}      -- All hook calls
local hookCountsDisplayed = {}  -- Hook calls logged to chat

for _, event in ipairs(CHARACTER_EVENTS) do
	eventCountsTotal[event] = 0
	eventCountsDisplayed[event] = 0
end

-- Track last event timestamp for timing delta analysis
local lastEventTime = _GetTime()

-- Equipment state tracking system
local equipmentSnapshots = {}  -- [slotId] = {itemLink, itemName, quality, durability, durabilityMax, texture}

-- Event batching system (for spam detection)
local BATCH_THRESHOLD = 5  -- Only batch if 5+ events at same time
local BATCH_TIME_WINDOW = 0.016  -- ~1 frame at 60fps
local eventBatch = {
	name = nil,
	timestamp = 0,
	calls = {}  -- array of {arg1, arg2, arg3, arg4, eventCount}
}

-- UI state tracking
local characterFrameOpen = false
local lastAvgItemLevel = nil

-- Slot ID to name mapping (1-19)
-- Classic WoW inventory slots: https://wowpedia.fandom.com/wiki/InventorySlotId
-- Note: Slot 0 and 20 don't exist in Classic Era - ammo/arrows are consumables, not equipment
local SLOT_NAMES = {
	[1] = "Head",
	[2] = "Neck",
	[3] = "Shoulder",
	[4] = "Shirt",
	[5] = "Chest",
	[6] = "Waist",
	[7] = "Legs",
	[8] = "Feet",
	[9] = "Wrist",
	[10] = "Hands",
	[11] = "Finger0",
	[12] = "Finger1",
	[13] = "Trinket0",
	[14] = "Trinket1",
	[15] = "Back",
	[16] = "MainHand",
	[17] = "SecondaryHand",
	[18] = "Ranged",
	[19] = "Tabard"
	-- Ammo/arrows are NOT equipment slots in Classic - they're consumables
}

-- Register all events
for _, event in ipairs(CHARACTER_EVENTS) do
	investigationFrame:RegisterEvent(event)
	print("|cff00ff00Registered:|r " .. event)
end

-- Helper function to get slot info
local function getSlotInfo(slotId)
	if not slotId then return "nil" end

	local slotName = SLOT_NAMES[slotId] or "Unknown"
	local itemLink = _GetInventoryItemLink("player", slotId)

	if not itemLink then
		return string.format("%s [ID:%d] - EMPTY", slotName, slotId)
	end

	local itemName = itemLink:match("%[(.-)%]") or "unknown"
	local quality = _GetInventoryItemQuality("player", slotId) or 0
	local durability, durabilityMax = _GetInventoryItemDurability(slotId)

	local durabilityStr = ""
	if durability and durabilityMax then
		local durabilityPercent = (durability / durabilityMax) * 100
		durabilityStr = string.format(", dur:%.0f%%", durabilityPercent)
	end

	return string.format("%s [ID:%d] - %s (q%d%s)", slotName, slotId, itemName, quality, durabilityStr)
end

-- Helper function to snapshot a single equipment slot
local function snapshotSlot(slotId)
	local itemLink = _GetInventoryItemLink("player", slotId)

	if not itemLink then
		return nil
	end

	local itemName = itemLink:match("%[(.-)%]") or "unknown"
	local quality = _GetInventoryItemQuality("player", slotId) or 0
	local durability, durabilityMax = _GetInventoryItemDurability(slotId)
	local texture = _GetInventoryItemTexture("player", slotId)

	return {
		itemLink = itemLink,
		itemName = itemName,
		quality = quality,
		durability = durability,
		durabilityMax = durabilityMax,
		texture = texture
	}
end

-- Helper function to snapshot all equipment
local function snapshotAllEquipment()
	local snapshot = {}
	for slotId = 1, 19 do  -- Classic slots are 1-19
		snapshot[slotId] = snapshotSlot(slotId)
	end
	return snapshot
end

-- Helper function to compare equipment snapshots
local function compareEquipmentSnapshots(oldSnapshot, newSnapshot)
	if not oldSnapshot or not newSnapshot then return nil end

	local changes = {
		equipped = {},     -- Items that were equipped
		unequipped = {},   -- Items that were removed
		swapped = {},      -- Items that were swapped
		durability = {}    -- Items with durability changes
	}

	for slotId = 1, 19 do  -- Classic slots are 1-19
		local oldItem = oldSnapshot[slotId]
		local newItem = newSnapshot[slotId]

		-- Check for equipment changes
		if not oldItem and newItem then
			-- Item equipped
			table.insert(changes.equipped, {
				slotId = slotId,
				slotName = SLOT_NAMES[slotId],
				itemName = newItem.itemName,
				quality = newItem.quality
			})
		elseif oldItem and not newItem then
			-- Item unequipped
			table.insert(changes.unequipped, {
				slotId = slotId,
				slotName = SLOT_NAMES[slotId],
				itemName = oldItem.itemName,
				quality = oldItem.quality
			})
		elseif oldItem and newItem then
			if oldItem.itemLink ~= newItem.itemLink then
				-- Item swapped
				table.insert(changes.swapped, {
					slotId = slotId,
					slotName = SLOT_NAMES[slotId],
					oldItemName = oldItem.itemName,
					newItemName = newItem.itemName,
					oldQuality = oldItem.quality,
					newQuality = newItem.quality
				})
			elseif oldItem.durability and newItem.durability and oldItem.durability ~= newItem.durability then
				-- Durability changed
				table.insert(changes.durability, {
					slotId = slotId,
					slotName = SLOT_NAMES[slotId],
					itemName = newItem.itemName,
					oldDurability = oldItem.durability,
					newDurability = newItem.durability,
					durabilityMax = newItem.durabilityMax
				})
			end
		end
	end

	return changes
end

-- Determine if an event should be displayed (filter non-player equipment events)
local function shouldDisplayEvent(event, arg1, arg2, arg3, arg4)
	-- Always suppress UPDATE_INVENTORY_DURABILITY (fires for all units globally, too spammy)
	if event == "UPDATE_INVENTORY_DURABILITY" then
		return false
	end

	-- Filter UNIT_* events to player only
	if event == "UNIT_INVENTORY_CHANGED" or event == "UNIT_MODEL_CHANGED" then
		if arg1 ~= "player" then
			return false
		end

		-- For UNIT_INVENTORY_CHANGED, only display if equipment actually changed
		if event == "UNIT_INVENTORY_CHANGED" then
			local oldSnapshot = equipmentSnapshots
			local newSnapshot = snapshotAllEquipment()
			if oldSnapshot then
				local changes = compareEquipmentSnapshots(oldSnapshot, newSnapshot)
				if not changes or (#changes.equipped == 0 and #changes.unequipped == 0 and #changes.swapped == 0) then
					return false  -- No equipment changes, just bag spam
				end
			end
		end
	end

	-- All other events pass through
	return true
end

-- Process and print a single event call (detailed logging)
local function processSingleEventCall(event, arg1, arg2, arg3, arg4, currentTime, timeSinceLastEvent, eventCount)
	local timestamp = string.format("[%.2f]", currentTime)
	local countInfo = string.format("[#%d]", eventCount)
	local deltaInfo = string.format("(+%.0fms)", timeSinceLastEvent * 1000)

	print("|cffff9900" .. timestamp .. " " .. countInfo .. " " .. deltaInfo .. " |cff00ffff" .. event .. "|r")

	-- Event-specific detailed logging
	if event == "PLAYER_EQUIPMENT_CHANGED" then
		local slotId, hasCurrent = arg1, arg2
		print("  |cffffaa00Slot Changed:|r " .. getSlotInfo(slotId))
		print("  |cffffaa00Has Item:|r " .. tostring(hasCurrent))

		-- Take new snapshot and compare with previous
		local oldSnapshot = equipmentSnapshots
		local newSnapshot = snapshotAllEquipment()

		if oldSnapshot then
			local changes = compareEquipmentSnapshots(oldSnapshot, newSnapshot)

			if changes then
				local hasChanges = (#changes.equipped > 0) or (#changes.unequipped > 0) or (#changes.swapped > 0)

				if hasChanges then
					-- Show what changed
					if #changes.equipped > 0 then
						print("  |cff00ff00  Items EQUIPPED:|r")
						for _, item in ipairs(changes.equipped) do
							print("    |cff00ff00  + " .. item.slotName .. ":|r " .. item.itemName .. " (q" .. item.quality .. ")")
						end
					end

					if #changes.unequipped > 0 then
						print("  |cffff0000  Items UNEQUIPPED:|r")
						for _, item in ipairs(changes.unequipped) do
							print("    |cffff0000  - " .. item.slotName .. ":|r " .. item.itemName .. " (q" .. item.quality .. ")")
						end
					end

					if #changes.swapped > 0 then
						print("  |cffff9900  Items SWAPPED:|r")
						for _, item in ipairs(changes.swapped) do
							print("    |cffff9900  ~ " .. item.slotName .. ":|r " .. item.oldItemName .. " → " .. item.newItemName)
						end
					end
				else
					print("  |cffaaaaaa  No equipment changes detected (duplicate event)|r")
				end
			end
		end

		-- Update snapshot for next comparison
		equipmentSnapshots = newSnapshot

	elseif event == "UNIT_INVENTORY_CHANGED" then
		local unitTarget = arg1
		print("  |cffffaa00Unit:|r " .. tostring(unitTarget))

		if unitTarget == "player" then
			-- Take snapshot to detect any changes
			local oldSnapshot = equipmentSnapshots
			local newSnapshot = snapshotAllEquipment()

			if oldSnapshot then
				local changes = compareEquipmentSnapshots(oldSnapshot, newSnapshot)

				if changes and (#changes.equipped > 0 or #changes.unequipped > 0 or #changes.swapped > 0) then
					print("  |cff00ff00  Detected equipment changes at UNIT_INVENTORY_CHANGED|r")
				end
			end

			equipmentSnapshots = newSnapshot
		end

	elseif event == "UPDATE_INVENTORY_DURABILITY" then
		print("  |cffffaa00Durability Update:|r Equipment durability changed")

		-- Take snapshot to detect durability changes
		local oldSnapshot = equipmentSnapshots
		local newSnapshot = snapshotAllEquipment()

		if oldSnapshot then
			local changes = compareEquipmentSnapshots(oldSnapshot, newSnapshot)

			if changes and #changes.durability > 0 then
				print("  |cffff6600  Durability CHANGED:|r")
				for _, item in ipairs(changes.durability) do
					local oldPercent = (item.oldDurability / item.durabilityMax) * 100
					local newPercent = (item.newDurability / item.durabilityMax) * 100
					print("    |cffff6600  " .. item.slotName .. ":|r " .. item.itemName ..
						string.format(" (%.0f%% → %.0f%%)", oldPercent, newPercent))
				end
			end
		end

		equipmentSnapshots = newSnapshot

	elseif event == "UPDATE_INVENTORY_ALERTS" then
		print("  |cffff0000Alert Update:|r Low/broken durability alert")

	elseif event == "PLAYER_AVG_ITEM_LEVEL_UPDATE" then
		local avgItemLevel, avgItemLevelEquipped = _GetAverageItemLevel()
		print("  |cffffaa00Avg Item Level:|r " .. string.format("%.2f (equipped: %.2f)", avgItemLevel or 0, avgItemLevelEquipped or 0))

		if lastAvgItemLevel then
			local diff = avgItemLevelEquipped - lastAvgItemLevel
			if diff > 0 then
				print("  |cff00ff00  Item level INCREASED by " .. string.format("%.2f", diff) .. "|r")
			elseif diff < 0 then
				print("  |cffff0000  Item level DECREASED by " .. string.format("%.2f", math.abs(diff)) .. "|r")
			end
		end

		lastAvgItemLevel = avgItemLevelEquipped

	elseif event == "ITEM_LOCK_CHANGED" then
		local bagId, slotId = arg1, arg2
		if bagId == nil and slotId then
			-- Equipment lock (bagId is nil for equipment)
			print("  |cffffaa00Equipment Lock:|r " .. getSlotInfo(slotId))
		end

	elseif event == "ITEM_LOCKED" then
		local bagId, slotId = arg1, arg2
		if bagId == nil and slotId then
			print("  |cffff6600Equipment LOCKED:|r " .. getSlotInfo(slotId))
		end

	elseif event == "ITEM_UNLOCKED" then
		local bagId, slotId = arg1, arg2
		if bagId == nil and slotId then
			print("  |cff66ff00Equipment UNLOCKED:|r " .. getSlotInfo(slotId))
		end

	elseif event == "UNIT_MODEL_CHANGED" then
		local unitTarget = arg1
		print("  |cffffaa00Unit:|r " .. tostring(unitTarget))

	elseif event == "CHARACTER_POINTS_CHANGED" then
		local change = arg1
		print("  |cffffaa00Change:|r " .. tostring(change))

	elseif event == "PLAYER_ENTERING_WORLD" then
		local isInitialLogin, isReloadingUi = arg1, arg2
		print("  |cffffaa00Initial Login:|r " .. tostring(isInitialLogin))
		print("  |cffffaa00Reloading UI:|r " .. tostring(isReloadingUi))

		-- Initial equipment snapshot
		equipmentSnapshots = snapshotAllEquipment()

		-- Show initial equipment
		print("  |cffaaaaaa  Initial equipment:|r")
		for slotId = 1, 19 do  -- Classic slots are 1-19
			local slotInfo = getSlotInfo(slotId)
			if not slotInfo:match("EMPTY") then
				print("    |cffaaaaaa  " .. slotInfo .. "|r")
			end
		end
		print("  |cffaaaaaa  Note: Ammo/arrows are consumables, not equipment slots in Classic|r")

		-- Get initial avg item level
		local avgItemLevel, avgItemLevelEquipped = _GetAverageItemLevel()
		if avgItemLevelEquipped then
			lastAvgItemLevel = avgItemLevelEquipped
			print("  |cffaaaaaa  Avg item level: " .. string.format("%.2f", avgItemLevelEquipped) .. "|r")
		end

	else
		-- Generic logging for any other events
		print("  |cffffaa00Args:|r " .. tostring(arg1) .. ", " .. tostring(arg2) .. ", " .. tostring(arg3) .. ", " .. tostring(arg4))
	end
end

-- Process and print a batched set of event calls
local function processBatchedEventCalls(event, calls, firstCallTime, firstCallDelta)
	local batchCount = #calls
	local timestamp = string.format("[%.2f]", firstCallTime)
	local countRange = string.format("[#%d-#%d]", calls[1].eventCount, calls[batchCount].eventCount)
	local deltaInfo = string.format("(+%.0fms)", firstCallDelta * 1000)

	-- Print batched header with warning
	print("|cffff9900" .. timestamp .. " " .. countRange .. " " .. deltaInfo .. " |cff00ffff" .. event .. " x" .. batchCount .. " FIRED |cffff0000⚠ SPAM|r")

	-- Collect unique arg1 values (most useful for seeing what slots/units)
	local uniqueArg1 = {}
	local arg1Counts = {}
	for _, call in ipairs(calls) do
		local arg1Str = tostring(call.arg1)
		if not uniqueArg1[arg1Str] then
			uniqueArg1[arg1Str] = true
			arg1Counts[arg1Str] = 1
		else
			arg1Counts[arg1Str] = arg1Counts[arg1Str] + 1
		end
	end

	-- Show summary of unique values
	local arg1List = {}
	for arg1Val, count in pairs(arg1Counts) do
		if count > 1 then
			table.insert(arg1List, arg1Val .. " (x" .. count .. ")")
		else
			table.insert(arg1List, arg1Val)
		end
	end

	if #arg1List > 0 then
		print("  |cffffaa00Unique arg1 values:|r " .. table.concat(arg1List, ", "))
	end

	-- For UNIT_INVENTORY_CHANGED, check if any actually changed equipment
	if event == "UNIT_INVENTORY_CHANGED" then
		local hadEquipmentChange = false
		for _, call in ipairs(calls) do
			if call.arg1 == "player" then
				-- Check last call's snapshot
				local oldSnapshot = equipmentSnapshots
				local newSnapshot = snapshotAllEquipment()
				if oldSnapshot then
					local changes = compareEquipmentSnapshots(oldSnapshot, newSnapshot)
					if changes and (#changes.equipped > 0 or #changes.unequipped > 0 or #changes.swapped > 0) then
						hadEquipmentChange = true
						print("  |cff00ff00  Equipment changes detected in batch|r")
					end
				end
				equipmentSnapshots = newSnapshot
				break
			end
		end
		if not hadEquipmentChange then
			print("  |cffaaaaaa  No equipment changes (likely bag-related spam)|r")
		end
	end
end

-- Flush the current batch (either print individually or as batch)
local function flushEventBatch()
	if not eventBatch.name or #eventBatch.calls == 0 then return end

	local batchCount = #eventBatch.calls

	-- Filter calls that should be displayed
	local displayedCalls = {}
	for _, call in ipairs(eventBatch.calls) do
		if shouldDisplayEvent(call.event, call.arg1, call.arg2, call.arg3, call.arg4) then
			table.insert(displayedCalls, call)
			eventCountsDisplayed[call.event] = (eventCountsDisplayed[call.event] or 0) + 1
		end
	end

	-- Only print if we have calls to display
	if #displayedCalls > 0 then
		if #displayedCalls < BATCH_THRESHOLD then
			-- Print each call individually
			for _, call in ipairs(displayedCalls) do
				processSingleEventCall(call.event, call.arg1, call.arg2, call.arg3, call.arg4,
					call.timestamp, call.timeSinceLastEvent, call.eventCount)
			end
		else
			-- Print as a batched spam warning
			local firstCall = displayedCalls[1]
			processBatchedEventCalls(eventBatch.name, displayedCalls, firstCall.timestamp, firstCall.timeSinceLastEvent)
		end
	end

	-- Update last event time to the last call in batch
	local lastCall = eventBatch.calls[batchCount]
	lastEventTime = lastCall.timestamp

	-- Clear the batch
	eventBatch.name = nil
	eventBatch.timestamp = 0
	eventBatch.calls = {}
end

-- Event handler with batching logic
investigationFrame:SetScript("OnEvent", function(self, event, ...)
	local arg1, arg2, arg3, arg4 = ...
	eventCounts[event] = (eventCounts[event] or 0) + 1
	eventCountsTotal[event] = (eventCountsTotal[event] or 0) + 1  -- Track total fired

	local currentTime = _GetTime()
	local timeSinceLastEvent = currentTime - lastEventTime

	-- Check if we should flush the current batch
	local shouldFlush = false
	if eventBatch.name and eventBatch.name ~= event then
		-- Different event, flush
		shouldFlush = true
	elseif eventBatch.name and (currentTime - eventBatch.timestamp) > BATCH_TIME_WINDOW then
		-- Same event but outside time window, flush
		shouldFlush = true
	end

	if shouldFlush then
		flushEventBatch()
		timeSinceLastEvent = currentTime - lastEventTime  -- Recalculate after flush
	end

	-- Add this event call to the batch
	if not eventBatch.name then
		eventBatch.name = event
		eventBatch.timestamp = currentTime
	end

	table.insert(eventBatch.calls, {
		event = event,
		arg1 = arg1,
		arg2 = arg2,
		arg3 = arg3,
		arg4 = arg4,
		timestamp = currentTime,
		timeSinceLastEvent = timeSinceLastEvent,
		eventCount = eventCounts[event]
	})
end)

-- Monitor CharacterFrame visibility
local function checkCharacterFrameState()
	if CharacterFrame and CharacterFrame:IsShown() then
		if not characterFrameOpen then
			characterFrameOpen = true
			local currentTime = _GetTime()
			local delta = currentTime - lastEventTime
			print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [UI State]|r CharacterFrame → |cff00ff00VISIBLE|r")
			lastEventTime = currentTime
		end
	else
		if characterFrameOpen then
			characterFrameOpen = false
			local currentTime = _GetTime()
			local delta = currentTime - lastEventTime
			print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [UI State]|r CharacterFrame → |cffff0000HIDDEN|r")
			lastEventTime = currentTime
		end
	end
end

-- Flush batch on a short timer to handle end-of-burst scenarios
local batchFlusher = _CreateFrame("Frame")
batchFlusher:SetScript("OnUpdate", function(self)
	local currentTime = _GetTime()
	if eventBatch.name and (currentTime - eventBatch.timestamp) > BATCH_TIME_WINDOW then
		flushEventBatch()
	end

	-- Also do UI state monitoring
	checkCharacterFrameState()
end)

-- Hook equipment-related UI functions
if PaperDollItemSlotButton_Update then
	hooksecurefunc("PaperDollItemSlotButton_Update", function(button)
		if not button then return end
		local slotId = button:GetID()

		-- Track total hook calls
		hookCountsTotal["PaperDollItemSlotButton_Update"] = (hookCountsTotal["PaperDollItemSlotButton_Update"] or 0) + 1

		-- Filter: Only display equipment slots (1-19), not bag slots (31-34, etc)
		if slotId < 1 or slotId > 19 then
			return  -- Silently filter bag slots
		end

		hookCountsDisplayed["PaperDollItemSlotButton_Update"] = (hookCountsDisplayed["PaperDollItemSlotButton_Update"] or 0) + 1

		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Equipment Hook]|r PaperDollItemSlotButton_Update � " .. getSlotInfo(slotId))
		lastEventTime = currentTime
	end)
end

if CharacterFrame_Expand then
	hooksecurefunc("CharacterFrame_Expand", function()
		hookCountsTotal["CharacterFrame_Expand"] = (hookCountsTotal["CharacterFrame_Expand"] or 0) + 1
		hookCountsDisplayed["CharacterFrame_Expand"] = (hookCountsDisplayed["CharacterFrame_Expand"] or 0) + 1

		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Equipment Hook]|r CharacterFrame_Expand")
		lastEventTime = currentTime
	end)
end

if CharacterFrame_Collapse then
	hooksecurefunc("CharacterFrame_Collapse", function()
		hookCountsTotal["CharacterFrame_Collapse"] = (hookCountsTotal["CharacterFrame_Collapse"] or 0) + 1
		hookCountsDisplayed["CharacterFrame_Collapse"] = (hookCountsDisplayed["CharacterFrame_Collapse"] or 0) + 1

		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Equipment Hook]|r CharacterFrame_Collapse")
		lastEventTime = currentTime
	end)
end

if EquipItemByName then
	hooksecurefunc("EquipItemByName", function(itemName, slot)
		hookCountsTotal["EquipItemByName"] = (hookCountsTotal["EquipItemByName"] or 0) + 1
		hookCountsDisplayed["EquipItemByName"] = (hookCountsDisplayed["EquipItemByName"] or 0) + 1

		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Equipment Hook]|r EquipItemByName � item: " .. tostring(itemName) .. ", slot: " .. tostring(slot))
		lastEventTime = currentTime
	end)
end

if UseInventoryItem then
	hooksecurefunc("UseInventoryItem", function(slot)
		hookCountsTotal["UseInventoryItem"] = (hookCountsTotal["UseInventoryItem"] or 0) + 1
		hookCountsDisplayed["UseInventoryItem"] = (hookCountsDisplayed["UseInventoryItem"] or 0) + 1

		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Equipment Hook]|r UseInventoryItem � " .. getSlotInfo(slot))
		lastEventTime = currentTime
	end)
end

if PickupInventoryItem then
	hooksecurefunc("PickupInventoryItem", function(slot)
		hookCountsTotal["PickupInventoryItem"] = (hookCountsTotal["PickupInventoryItem"] or 0) + 1
		hookCountsDisplayed["PickupInventoryItem"] = (hookCountsDisplayed["PickupInventoryItem"] or 0) + 1

		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Equipment Hook]|r PickupInventoryItem � " .. getSlotInfo(slot))
		lastEventTime = currentTime
	end)
end

-- Slash command to show statistics
SLASH_EVENTSTATS1 = "/eventstats"
SlashCmdList["EVENTSTATS"] = function()
	print("|cff00ff00=== CHARACTER EVENT STATISTICS ===|r")

	-- Calculate totals
	local totalEventsFired = 0
	local totalEventsDisplayed = 0
	for event, count in pairs(eventCountsTotal) do
		totalEventsFired = totalEventsFired + count
		totalEventsDisplayed = totalEventsDisplayed + (eventCountsDisplayed[event] or 0)
	end

	local totalHooksFired = 0
	local totalHooksDisplayed = 0
	for hookName, count in pairs(hookCountsTotal) do
		totalHooksFired = totalHooksFired + count
		totalHooksDisplayed = totalHooksDisplayed + (hookCountsDisplayed[hookName] or 0)
	end

	print("|cffffaa00Total Events:|r " .. totalEventsFired .. " fired, " .. totalEventsDisplayed .. " displayed, " .. (totalEventsFired - totalEventsDisplayed) .. " filtered")
	print("|cffffaa00Total Hooks:|r " .. totalHooksFired .. " fired, " .. totalHooksDisplayed .. " displayed, " .. (totalHooksFired - totalHooksDisplayed) .. " filtered")
	print("")

	-- Events breakdown
	print("|cff00ffff=== EVENTS BREAKDOWN ===|r")
	for _, event in ipairs(CHARACTER_EVENTS) do
		local total = eventCountsTotal[event] or 0
		local displayed = eventCountsDisplayed[event] or 0
		local filtered = total - displayed

		if total > 0 then
			local filterPercent = total > 0 and string.format("%.1f%%", (filtered / total) * 100) or "0%"
			print("|cffffaa00" .. event .. ":|r " .. total .. " total (" .. displayed .. " shown, " .. filtered .. " filtered = " .. filterPercent .. ")")
		end
	end

	-- Hooks breakdown
	if next(hookCountsTotal) then
		print("")
		print("|cff00ffff=== HOOKS BREAKDOWN ===|r")
		for hookName, total in pairs(hookCountsTotal) do
			local displayed = hookCountsDisplayed[hookName] or 0
			local filtered = total - displayed

			if total > 0 then
				local filterPercent = total > 0 and string.format("%.1f%%", (filtered / total) * 100) or "0%"
				print("|cffffaa00" .. hookName .. ":|r " .. total .. " total (" .. displayed .. " shown, " .. filtered .. " filtered = " .. filterPercent .. ")")
			end
		end
	end

	print("|cff00ff00=== END STATISTICS ===|r")
end

-- Test functions for character hooks
local function testCharacterHooks()
	print("|cff00ff00=== TESTING CHARACTER HOOKS ===|r")
	
	-- Test CharacterFrame_Expand hook
	print("|cffffaa00Testing CharacterFrame_Expand hook...|r")
	if CharacterFrame_Expand then
		CharacterFrame_Expand()
	else
		print("|cffff0000CharacterFrame_Expand function not available|r")
	end
	
	-- Test CharacterFrame_Collapse hook
	print("|cffffaa00Testing CharacterFrame_Collapse hook...|r")
	if CharacterFrame_Collapse then
		CharacterFrame_Collapse()
	else
		print("|cffff0000CharacterFrame_Collapse function not available|r")
	end
	
	-- Test UseInventoryItem hook (use main hand weapon if equipped)
	local mainHandLink = _GetInventoryItemLink("player", 16) -- Main hand slot
	if mainHandLink then
		print("|cffffaa00Testing UseInventoryItem hook on main hand...|r")
		if UseInventoryItem then
			UseInventoryItem(16)
		else
			print("|cffff0000UseInventoryItem function not available|r")
		end
	else
		print("|cffff6600Cannot test UseInventoryItem - no main hand weapon equipped|r")
	end
	
	-- Test PickupInventoryItem hook (pickup/place back main hand)
	if mainHandLink then
		print("|cffffaa00Testing PickupInventoryItem hook on main hand...|r")
		if PickupInventoryItem then
			PickupInventoryItem(16)
			-- Place it back immediately
			PickupInventoryItem(16)
		else
			print("|cffff0000PickupInventoryItem function not available|r")
		end
	else
		print("|cffff6600Cannot test PickupInventoryItem - no main hand weapon equipped|r")
	end
	
	-- Test EquipItemByName hook (try to equip something from bags)
	print("|cffffaa00Testing EquipItemByName hook...|r")
	if EquipItemByName then
		-- Try to equip any weapon we can find in bags
		for bag = 0, 4 do
			local numSlots = GetContainerNumSlots and GetContainerNumSlots(bag) or 0
			for slot = 1, numSlots do
				local itemLink = GetContainerItemLink and GetContainerItemLink(bag, slot)
				if itemLink then
					local itemName = itemLink:match("%[(.-)%]")
					if itemName then
						EquipItemByName(itemName)
						print("|cffffaa00  Attempted to equip:|r " .. itemName)
						break
					end
				end
			end
		end
	else
		print("|cffff0000EquipItemByName function not available|r")
	end
	
	print("|cff00ff00=== CHARACTER HOOK TESTS COMPLETE ===|r")
end

-- Slash command to test character hooks
SLASH_TESTCHARACTERHOOKS1 = "/testcharacterhooks"
SlashCmdList["TESTCHARACTERHOOKS"] = testCharacterHooks

print("|cff00ff00Character equipment investigation ready - events will print to chat|r")
print("|cff00ff00Use /eventstats to see event statistics (total fired vs displayed)|r")
print("|cff00ff00Use /testcharacterhooks to test character function hooks|r")
