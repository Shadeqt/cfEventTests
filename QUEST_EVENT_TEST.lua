local addon = cfItemColors

-- WoW API calls
local _CreateFrame = CreateFrame
local _GetNumQuestLogEntries = GetNumQuestLogEntries
local _GetQuestLogTitle = GetQuestLogTitle
local _GetNumQuestLeaderBoards = GetNumQuestLeaderBoards
local _GetQuestLogLeaderBoard = GetQuestLogLeaderBoard
local _IsQuestComplete = IsQuestComplete
local _GetTime = GetTime
local _GetQuestLogSelection = GetQuestLogSelection
local _C_Container = C_Container
local _C_Timer = C_Timer

print("=== QUEST EVENT INVESTIGATION LOADED ===")
print("This module will log ALL quest-related events")
print("Watch your chat for detailed event information")
print("=============================================")

-- Event tracking frame
local investigationFrame = _CreateFrame("Frame")

-- All possible quest-related events for Classic Era
local QUEST_EVENTS = {
	-- Quest lifecycle events
	"QUEST_ACCEPTED",
	"QUEST_REMOVED",
	"QUEST_TURNED_IN",
	"QUEST_COMPLETE",

	-- Quest progress events
	"QUEST_WATCH_UPDATE",
	"QUEST_PROGRESS",

	-- Quest UI events
	"QUEST_DETAIL",
	"QUEST_FINISHED",
	"QUEST_GREETING",
	"QUEST_ACCEPT_CONFIRM",

	-- Quest log events
	"QUEST_LOG_UPDATE",
	"UNIT_QUEST_LOG_CHANGED",

	-- Quest POI/item events
	"QUEST_POI_UPDATE",
	"QUEST_ITEM_UPDATE",

	-- Bag events (for tracking quest item removal)
	"BAG_UPDATE",

	-- Player entering world (for initialization)
	"PLAYER_ENTERING_WORLD",
}

-- Event counter
local eventCounts = {}
for _, event in ipairs(QUEST_EVENTS) do
	eventCounts[event] = 0
end

-- Track pending quest watch updates to show data at QUEST_LOG_UPDATE time
local pendingQuestWatchUpdates = {}

-- Track quest items in bags to detect when they're removed
local trackedQuestItems = {}  -- [questId] = { itemName = true }

-- Track active quest turn-in to monitor item removal timing
local activeQuestTurnIn = nil  -- { questId = X, itemCounts = { itemName = count }, timestamp = time }

-- Track recent quest acceptances to associate received items
local recentQuestAccepted = nil  -- { questId = X, timestamp = time }

-- Helper to extract item name from objective text
local function extractItemNameFromObjective(objectiveText)
	-- Objective format: "✗ Tough Wolf Meat: 7/8" or "✓ Tough Wolf Meat: 8/8"
	local itemName = objectiveText:match("^[✗✓]%s*(.-):%s*%d+/%d+")
	return itemName
end

-- Register all events
for _, event in ipairs(QUEST_EVENTS) do
	investigationFrame:RegisterEvent(event)
	print("|cff00ff00Registered:|r " .. event)
end

-- Helper function to get quest info by quest ID
local function getQuestInfoById(questId)
	if not questId then return "nil" end

	local numEntries = _GetNumQuestLogEntries()
	for i = 1, numEntries do
		local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID = _GetQuestLogTitle(i)
		if questID == questId then
			local completeStatus = "incomplete"
			if isComplete == 1 then
				completeStatus = "complete"
			elseif isComplete == -1 then
				completeStatus = "failed"
			end

			return string.format("[%d] %s (Lv%d, %s)", questID, title or "Unknown", level or 0, completeStatus)
		end
	end

	return string.format("[%d] Not in quest log", questId)
end

-- Helper function to get quest log entry info
local function getQuestLogEntryInfo(questLogIndex)
	if not questLogIndex then return "nil" end

	local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID = _GetQuestLogTitle(questLogIndex)
	if not title then return "invalid index" end
	if isHeader then return "HEADER: " .. title end

	local completeStatus = "incomplete"
	if isComplete == 1 then
		completeStatus = "complete"
	elseif isComplete == -1 then
		completeStatus = "failed"
	end

	return string.format("[LogIdx:%d, QuestID:%d] %s (Lv%d, %s)", questLogIndex, questID or 0, title, level or 0, completeStatus)
end

-- Helper function to get quest objectives
local function getQuestObjectives(questLogIndex)
	if not questLogIndex then return {} end

	local objectives = {}
	local numObjectives = _GetNumQuestLeaderBoards(questLogIndex)

	if not numObjectives or numObjectives == 0 then
		return {"No objectives"}
	end

	for i = 1, numObjectives do
		local text, objectiveType, finished = _GetQuestLogLeaderBoard(i, questLogIndex)
		if text then
			local status = finished and "|cff00ff00✓|r" or "|cffff0000✗|r"
			table.insert(objectives, status .. " " .. text)
		end
	end

	return objectives
end

-- Helper function to compare quest progress (returns true if changed)
local function progressChanged(oldObjectives, newObjectives)
	if not oldObjectives or not newObjectives then return true end
	if #oldObjectives ~= #newObjectives then return true end

	for i = 1, #oldObjectives do
		if oldObjectives[i] ~= newObjectives[i] then
			return true
		end
	end

	return false
end

-- Helper function to count quest items in bags by scanning item tooltips
local function countQuestItemsInBags(questItemName)
	if not questItemName or questItemName == "" then return 0 end

	local totalCount = 0
	local NUM_BAG_SLOTS = NUM_BAG_SLOTS or 4

	-- Scan backpack (bag 0) and bags 1-4
	for bagId = 0, NUM_BAG_SLOTS do
		local numSlots = _C_Container.GetContainerNumSlots(bagId)
		if numSlots then
			for slotId = 1, numSlots do
				local containerInfo = _C_Container.GetContainerItemInfo(bagId, slotId)
				if containerInfo and containerInfo.hyperlink then
					-- Extract item name from hyperlink
					local itemName = containerInfo.hyperlink:match("%[(.-)%]")
					if itemName and itemName == questItemName then
						totalCount = totalCount + (containerInfo.stackCount or 1)
					end
				end
			end
		end
	end

	return totalCount
end

-- Helper function to show current quest log state
local function showQuestLogState()
	local numEntries, numQuests = _GetNumQuestLogEntries()
	print("  |cffaaaaaa  Quest Log:|r " .. numQuests .. " quests (" .. numEntries .. " total entries)")

	if numQuests > 0 then
		for i = 1, numEntries do
			local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID = _GetQuestLogTitle(i)
			if title and not isHeader then
				local completeStatus = "incomplete"
				if isComplete == 1 then
					completeStatus = "|cff00ff00complete|r"
				elseif isComplete == -1 then
					completeStatus = "|cffff0000failed|r"
				end

				print("    |cffaaaaaa  [" .. i .. "]|r " .. title .. " (ID:" .. (questID or "?") .. ", " .. completeStatus .. ")")
			end
		end
	end
end

-- Track UI state
local questDialogOpen = false
local questLogOpen = false

-- Monitor QuestFrame visibility
local function checkQuestFrameState()
	if QuestFrame and QuestFrame:IsShown() then
		if not questDialogOpen then
			questDialogOpen = true
			print("|cffff9900[Quest UI]|r Quest NPC Dialog OPENED")
		end
	else
		if questDialogOpen then
			questDialogOpen = false
			print("|cffff9900[Quest UI]|r Quest NPC Dialog CLOSED")
		end
	end
end

-- Monitor QuestLogFrame visibility
local function checkQuestLogState()
	if QuestLogFrame and QuestLogFrame:IsShown() then
		if not questLogOpen then
			questLogOpen = true
			print("|cffff9900[Quest UI]|r Quest Log OPENED")
		end
	else
		if questLogOpen then
			questLogOpen = false
			print("|cffff9900[Quest UI]|r Quest Log CLOSED")
		end
	end
end

-- Update UI state regularly
investigationFrame:SetScript("OnUpdate", function()
	checkQuestFrameState()
	checkQuestLogState()
end)

-- Track last event timestamp for delta timing
local lastEventTime = _GetTime()

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
	if event == "QUEST_ACCEPTED" then
		local questLogIndex, questId = arg1, arg2
		print("  |cffffaa00Quest Accepted:|r " .. getQuestLogEntryInfo(questLogIndex))
		print("  |cffffaa00Quest ID:|r " .. tostring(questId))

		-- Show objectives
		local objectives = getQuestObjectives(questLogIndex)
		if #objectives > 0 then
			print("  |cffffaa00  Objectives:|r")
			for _, obj in ipairs(objectives) do
				print("    |cffaaaaaa  " .. obj .. "|r")
			end
		end

		-- Mark this as a recent quest acceptance to associate received items
		recentQuestAccepted = {
			questId = questId,
			timestamp = _GetTime()
		}

	elseif event == "QUEST_REMOVED" then
		local questId = arg1
		print("  |cffffaa00Quest Removed:|r Quest ID: " .. tostring(questId))

		-- Check if quest items are still in bags after quest removal
		if trackedQuestItems[questId] then
			print("  |cffaaaaaa  Quest item status at QUEST_REMOVED:|r")
			for itemName, _ in pairs(trackedQuestItems[questId]) do
				local countInBags = countQuestItemsInBags(itemName)
				if countInBags > 0 then
					print("    |cffff0000  ⚠ Quest item STILL in bags:|r " .. itemName .. " x" .. countInBags)
				else
					print("    |cff00ff00  ✓ Quest item confirmed removed:|r " .. itemName)
				end
			end
			-- Clean up tracking
			trackedQuestItems[questId] = nil
		end

		-- Stop monitoring BAG_UPDATE if this was the active turn-in
		if activeQuestTurnIn and activeQuestTurnIn.questId == questId then
			print("  |cffaaaaaa  Stopped monitoring BAG_UPDATE for quest " .. questId .. "|r")
			activeQuestTurnIn = nil
		end

		-- Clean up any pending watch updates for this quest
		if pendingQuestWatchUpdates[questId] then
			pendingQuestWatchUpdates[questId] = nil
		end

	elseif event == "QUEST_TURNED_IN" then
		local questId, xpReward, moneyReward = arg1, arg2, arg3
		print("  |cffffaa00Quest Turned In:|r Quest ID: " .. tostring(questId))
		print("  |cffffaa00  XP Reward:|r " .. tostring(xpReward))
		print("  |cffffaa00  Money Reward:|r " .. tostring(moneyReward))

		-- Snapshot quest items in bags BEFORE quest is removed
		local itemCounts = {}
		if trackedQuestItems[questId] then
			print("  |cffff6600  Quest items in bags (BEFORE removal):|r")
			for itemName, _ in pairs(trackedQuestItems[questId]) do
				local countInBags = countQuestItemsInBags(itemName)
				itemCounts[itemName] = countInBags
				print("    |cffff6600  " .. itemName .. " x" .. countInBags .. "|r")
			end

			-- Start monitoring BAG_UPDATE for item removal
			activeQuestTurnIn = {
				questId = questId,
				itemCounts = itemCounts,
				timestamp = _GetTime()
			}
			print("  |cff00ff00  Started monitoring BAG_UPDATE for item removal...|r")
		end

		-- Clean up any pending watch updates for this quest
		if pendingQuestWatchUpdates[questId] then
			pendingQuestWatchUpdates[questId] = nil
		end

	elseif event == "QUEST_COMPLETE" then
		print("  |cffffaa00Quest Complete:|r All objectives finished")

	elseif event == "QUEST_WATCH_UPDATE" then
		local questId = arg1
		print("  |cffffaa00Quest Watch Updated:|r " .. getQuestInfoById(questId))

		-- Find the quest in the log and show current objectives
		local numEntries = _GetNumQuestLogEntries()
		for i = 1, numEntries do
			local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID = _GetQuestLogTitle(i)
			if questID == questId then
				local objectives = getQuestObjectives(i)
				if #objectives > 0 then
					print("  |cffffaa00  Progress (at QUEST_WATCH_UPDATE):|r |cffff6600Quest data is STALE - not updated yet!|r")
					for _, obj in ipairs(objectives) do
						print("    |cffaaaaaa  " .. obj .. "|r")

						-- Track quest items mentioned in objectives
						local itemName = extractItemNameFromObjective(obj)
						if itemName then
							if not trackedQuestItems[questId] then
								trackedQuestItems[questId] = {}
							end
							trackedQuestItems[questId][itemName] = true
						end
					end
				end

				-- Store quest info with OLD progress snapshot to check against later
				pendingQuestWatchUpdates[questId] = {
					questLogIndex = i,
					timestamp = _GetTime(),
					oldProgress = objectives  -- Store baseline progress
				}

				break
			end
		end

	elseif event == "QUEST_PROGRESS" then
		print("  |cffffaa00Quest Progress:|r Checking incomplete quest at NPC")

	elseif event == "QUEST_DETAIL" then
		local questStartItemID = arg1
		print("  |cffffaa00Quest Detail:|r Viewing quest details")
		if questStartItemID and questStartItemID ~= 0 then
			print("  |cffffaa00  Start Item:|r " .. tostring(questStartItemID))
		end

	elseif event == "QUEST_FINISHED" then
		print("  |cffffaa00Quest Finished:|r Dialog closed or interaction ended")

	elseif event == "QUEST_GREETING" then
		print("  |cffffaa00Quest Greeting:|r Multi-quest NPC menu shown")

	elseif event == "QUEST_ACCEPT_CONFIRM" then
		print("  |cffffaa00Quest Accept Confirm:|r Shared/escort quest prompt")

	elseif event == "QUEST_LOG_UPDATE" then
		print("  |cffffaa00Quest Log Update:|r Quest data has been updated")

		-- Check if we have any pending quest watch updates to verify
		for questId, data in pairs(pendingQuestWatchUpdates) do
			local timeSinceWatchUpdate = _GetTime() - data.timestamp
			local currentProgress = getQuestObjectives(data.questLogIndex)

			-- Compare current progress to stored OLD progress
			if progressChanged(data.oldProgress, currentProgress) then
				-- Data has changed! This is when the update happened
				if #currentProgress > 0 then
					print("  |cff00ff00  ✓ Quest data UPDATED at +" .. string.format("%.0fms", timeSinceWatchUpdate * 1000) .. " after QUEST_WATCH_UPDATE|r")
					print("  |cff00ff00  Progress is now accurate:|r")
					for _, obj in ipairs(currentProgress) do
						print("    |cffaaaaaa  " .. obj .. "|r")
					end
				end
				-- Remove from pending - we've confirmed the update
				pendingQuestWatchUpdates[questId] = nil
			else
				-- Data hasn't changed yet - still stale
				print("  |cffff6600  ✗ Quest data still stale at +" .. string.format("%.0fms", timeSinceWatchUpdate * 1000) .. " (no change from baseline)|r")
				-- Keep in pending list to check at next QUEST_LOG_UPDATE
			end
		end

	elseif event == "UNIT_QUEST_LOG_CHANGED" then
		local unitId = arg1
		print("  |cffffaa00Unit Quest Log Changed:|r " .. tostring(unitId))

	elseif event == "QUEST_POI_UPDATE" then
		print("  |cffffaa00Quest POI Update:|r Quest marker updated")

	elseif event == "QUEST_ITEM_UPDATE" then
		print("  |cffffaa00Quest Item Update:|r Quest item changed")

	elseif event == "PLAYER_ENTERING_WORLD" then
		local isInitialLogin, isReloadingUi = arg1, arg2
		print("  |cffffaa00Initial Login:|r " .. tostring(isInitialLogin))
		print("  |cffffaa00Reloading UI:|r " .. tostring(isReloadingUi))

	elseif event == "BAG_UPDATE" then
		local bagId = arg1

		-- Only process if we're actively monitoring a quest turn-in
		if activeQuestTurnIn then
			local questId = activeQuestTurnIn.questId
			local timeSinceTurnIn = _GetTime() - activeQuestTurnIn.timestamp
			local anyChanges = false

			-- Check all tracked items for this quest
			for itemName, oldCount in pairs(activeQuestTurnIn.itemCounts) do
				local currentCount = countQuestItemsInBags(itemName)

				if currentCount ~= oldCount then
					anyChanges = true
					if currentCount == 0 and oldCount > 0 then
						print("  |cff00ff00  ✓ Quest item REMOVED from bags:|r " .. itemName .. " (was x" .. oldCount .. ", now x0)")
						print("  |cff00ff00    Removal timing: +" .. string.format("%.0fms", timeSinceTurnIn * 1000) .. " after QUEST_TURNED_IN|r")
					elseif currentCount < oldCount then
						print("  |cffffaa00  Quest item count decreased:|r " .. itemName .. " (was x" .. oldCount .. ", now x" .. currentCount .. ")")
						print("  |cffffaa00    Timing: +" .. string.format("%.0fms", timeSinceTurnIn * 1000) .. " after QUEST_TURNED_IN|r")
					end

					-- Update tracking
					activeQuestTurnIn.itemCounts[itemName] = currentCount
				end
			end

			-- Don't log BAG_UPDATE events with no relevant changes (too spammy)
			if anyChanges then
				print("  |cffaaaaaa  BAG_UPDATE detected item removal (bagId: " .. tostring(bagId) .. ")|r")
			end
		end

	else
		-- Generic logging for any other events
		print("  |cffffaa00Args:|r " .. tostring(arg1) .. ", " .. tostring(arg2) .. ", " .. tostring(arg3) .. ", " .. tostring(arg4))
	end
end)

-- Hook quest-related UI functions with timing
if QuestLog_Update then
	hooksecurefunc("QuestLog_Update", function()
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Quest Hook]|r QuestLog_Update")
		lastEventTime = currentTime
	end)
end

if QuestInfo_Display then
	hooksecurefunc("QuestInfo_Display", function(template, parentFrame, acceptButton, material, mapView)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Quest Hook]|r QuestInfo_Display")
		lastEventTime = currentTime
	end)
end

if QuestFrameProgressItems_Update then
	hooksecurefunc("QuestFrameProgressItems_Update", function()
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Quest Hook]|r QuestFrameProgressItems_Update")
		lastEventTime = currentTime
	end)
end

if SelectQuestLogEntry then
	hooksecurefunc("SelectQuestLogEntry", function(questLogIndex)
		-- Don't log this - fires constantly on mouse-over
		-- print("|cffff9900[Quest Hook]|r SelectQuestLogEntry → " .. tostring(questLogIndex))
	end)
end

if AbandonQuest then
	hooksecurefunc("AbandonQuest", function()
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Quest Hook]|r AbandonQuest")
		lastEventTime = currentTime
	end)
end

if AcceptQuest then
	hooksecurefunc("AcceptQuest", function()
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Quest Hook]|r AcceptQuest")
		lastEventTime = currentTime
	end)
end

if DeclineQuest then
	hooksecurefunc("DeclineQuest", function()
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Quest Hook]|r DeclineQuest")
		lastEventTime = currentTime
	end)
end

if CompleteQuest then
	hooksecurefunc("CompleteQuest", function()
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Quest Hook]|r CompleteQuest")
		lastEventTime = currentTime
	end)
end

if GetQuestReward then
	hooksecurefunc("GetQuestReward", function(itemChoice)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Quest Hook]|r GetQuestReward → Choice: " .. tostring(itemChoice))
		lastEventTime = currentTime
	end)
end

print("|cff00ff00Quest investigation ready - events will print to chat|r")
