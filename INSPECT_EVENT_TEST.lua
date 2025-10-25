-- WoW API calls (Classic Era 1.15 compatible)
local _CreateFrame = CreateFrame
local _GetTime = GetTime
local _UnitName = UnitName
local _UnitClass = UnitClass
local _UnitLevel = UnitLevel
local _UnitRace = UnitRace
local _GetInventoryItemLink = GetInventoryItemLink
local _GetInventoryItemQuality = GetInventoryItemQuality
local _GetInventoryItemTexture = GetInventoryItemTexture
local _GetInventoryItemDurability = GetInventoryItemDurability
local _CanInspect = CanInspect
local _CheckInteractDistance = CheckInteractDistance
local _InspectUnit = InspectUnit
local _ClearInspectPlayer = ClearInspectPlayer

print("=== INSPECT EVENT INVESTIGATION LOADED ===")
print("This module will log ALL inspect-related events")
print("Watch your chat for detailed event information")
print("==============================================")

-- Event tracking frame
local investigationFrame = _CreateFrame("Frame")

-- All inspect-related events for Classic Era (1.15)
local INSPECT_EVENTS = {
	-- Core inspect events
	"INSPECT_READY",
	"INSPECT_HONOR_UPDATE",
	"INSPECT_TALENT_READY",
	
	-- Player entering world (for initialization)
	"PLAYER_ENTERING_WORLD",
}

-- Event counter
local eventCounts = {}
for _, event in ipairs(INSPECT_EVENTS) do
	eventCounts[event] = 0
end

-- Track last event timestamp for timing delta analysis
local lastEventTime = _GetTime()

-- Inspect state tracking
local currentInspectTarget = nil  -- Store unit ID
local currentInspectTargetName = nil  -- Store unit name for reference after target is lost
local inspectInProgress = false
local lastInspectRequest = nil  -- { unitId, unitName, timestamp, completed }
local inspectDataReceived = {}  -- Track what data we've received

-- Equipment slot tracking for inspect target
local inspectEquipmentSnapshot = {}  -- [slotId] = {itemLink, itemName, quality, texture}

-- UI state tracking
local inspectFrameOpen = false

-- Classic WoW inventory slots (1-19)
local SLOT_NAMES = {
	[1] = "Head", [2] = "Neck", [3] = "Shoulder", [4] = "Shirt", [5] = "Chest",
	[6] = "Waist", [7] = "Legs", [8] = "Feet", [9] = "Wrist", [10] = "Hands",
	[11] = "Finger0", [12] = "Finger1", [13] = "Trinket0", [14] = "Trinket1",
	[15] = "Back", [16] = "MainHand", [17] = "SecondaryHand", [18] = "Ranged", [19] = "Tabard"
}

-- Register all events with error handling
local registeredEvents = {}
for _, event in ipairs(INSPECT_EVENTS) do
	local success = pcall(investigationFrame.RegisterEvent, investigationFrame, event)
	if success then
		registeredEvents[event] = true
		print("|cff00ff00Registered:|r " .. event)
	else
		print("|cffff6600Skipped (not available):|r " .. event)
	end
end

-- Helper function to get unit info
local function getUnitInfo(unitId)
	if not unitId then return "nil" end
	
	local name = _UnitName(unitId)
	if not name then return "invalid unit" end
	
	local class, classToken = _UnitClass(unitId)
	local level = _UnitLevel(unitId)
	local race, raceToken = _UnitRace(unitId)
	
	local info = string.format("%s (Lv%d %s %s)", name, level or 0, race or "Unknown", class or "Unknown")
	
	return info
end

-- Helper function to get inspect equipment info
local function getInspectEquipmentInfo(slotId)
	if not slotId then return "nil" end
	
	local slotName = SLOT_NAMES[slotId] or "Unknown"
	local itemLink = _GetInventoryItemLink("target", slotId)
	
	if not itemLink then
		return string.format("%s [ID:%d] - EMPTY", slotName, slotId)
	end
	
	local itemName = itemLink:match("%[(.-)%]") or "unknown"
	local quality = _GetInventoryItemQuality("target", slotId) or 0
	local texture = _GetInventoryItemTexture("target", slotId)
	
	return string.format("%s [ID:%d] - %s (q%d)", slotName, slotId, itemName, quality)
end

-- Helper function to snapshot inspect target's equipment
local function snapshotInspectEquipment()
	local snapshot = {}
	for slotId = 1, 19 do  -- Classic slots are 1-19
		local itemLink = _GetInventoryItemLink("target", slotId)
		if itemLink then
			local itemName = itemLink:match("%[(.-)%]") or "unknown"
			local quality = _GetInventoryItemQuality("target", slotId) or 0
			local texture = _GetInventoryItemTexture("target", slotId)
			
			snapshot[slotId] = {
				itemLink = itemLink,
				itemName = itemName,
				quality = quality,
				texture = texture
			}
		end
	end
	return snapshot
end

-- Helper function to check if unit can be inspected
local function checkInspectability(unitId)
	if not unitId then return false, "no unit" end
	
	local canInspect = _CanInspect(unitId)
	if not canInspect then
		return false, "cannot inspect (too far, not player, etc.)"
	end
	
	local inRange = _CheckInteractDistance(unitId, 1)  -- 1 = inspect distance
	if not inRange then
		return false, "out of inspect range"
	end
	
	return true, "can inspect"
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



	print("|cffff9900" .. timestamp .. " " .. countInfo .. " " .. deltaInfo .. " |cff00ffff" .. event .. "|r")

	lastEventTime = currentTime

	-- Event-specific detailed logging
	if event == "INSPECT_READY" then
		local guid = arg1
		print("  |cff00ff00Inspect Data Ready:|r GUID: " .. tostring(guid))
		
		if currentInspectTarget then
			local targetInfo = getUnitInfo(currentInspectTarget)
			if targetInfo == "invalid unit" and currentInspectTargetName then
				targetInfo = currentInspectTargetName .. " (target lost)"
			end
			print("  |cff00ff00  Target:|r " .. targetInfo)
			
			-- Check timing if we have a pending request
			if lastInspectRequest and not lastInspectRequest.completed then
				local inspectDuration = currentTime - lastInspectRequest.timestamp
				print("  |cff00ff00  Inspect Duration:|r " .. string.format("%.0fms", inspectDuration * 1000))
				lastInspectRequest.completed = true
			end
			
			-- Snapshot equipment immediately
			inspectEquipmentSnapshot = snapshotInspectEquipment()
			
			-- Show equipment summary
			local equippedCount = 0
			for slotId = 1, 19 do
				if inspectEquipmentSnapshot[slotId] then
					equippedCount = equippedCount + 1
				end
			end
			print("  |cff00ff00  Equipment (immediate):|r " .. equippedCount .. "/19 slots equipped")
			
			-- Show sample equipment (first 5 equipped items)
			local shown = 0
			for slotId = 1, 19 do
				if inspectEquipmentSnapshot[slotId] and shown < 5 then
					print("    |cffaaaaaa  " .. getInspectEquipmentInfo(slotId) .. "|r")
					shown = shown + 1
				end
			end
			if equippedCount > 5 then
				print("    |cffaaaaaa  ... and " .. (equippedCount - 5) .. " more items|r")
			end
			
			-- Schedule delayed re-checks to see when data actually arrives
			local checkDelays = {100, 250, 500, 1000, 2000}  -- milliseconds
			for _, delay in ipairs(checkDelays) do
				C_Timer.After(delay / 1000, function()
					local delayedSnapshot = snapshotInspectEquipment()
					local delayedCount = 0
					for slotId = 1, 19 do
						if delayedSnapshot[slotId] then
							delayedCount = delayedCount + 1
						end
					end
					
					if delayedCount ~= equippedCount then
						print("  |cffff9900  Equipment (+" .. delay .. "ms):|r " .. delayedCount .. "/19 slots equipped |cff00ff00(DATA CHANGED!)|r")
						
						-- Show new items that appeared
						for slotId = 1, 19 do
							if delayedSnapshot[slotId] and not inspectEquipmentSnapshot[slotId] then
								print("    |cff00ff00  + " .. getInspectEquipmentInfo(slotId) .. "|r")
							end
						end
						
						-- Update our snapshot
						inspectEquipmentSnapshot = delayedSnapshot
					else
						print("  |cffaaaaaa  Equipment (+" .. delay .. "ms):|r " .. delayedCount .. "/19 slots (no change)|r")
					end
				end)
			end
			
			inspectDataReceived.equipment = true
		end
		
		inspectInProgress = false

	elseif event == "INSPECT_HONOR_UPDATE" then
		print("  |cff00ff00Honor Data Ready:|r PvP honor information updated")
		inspectDataReceived.honor = true

	elseif event == "INSPECT_TALENT_READY" then
		print("  |cff00ff00Talent Data Ready:|r Talent information updated")
		inspectDataReceived.talents = true

	elseif event == "PLAYER_ENTERING_WORLD" then
		local isInitialLogin, isReloadingUi = arg1, arg2
		print("  |cffffaa00Initial Login:|r " .. tostring(isInitialLogin))
		print("  |cffffaa00Reloading UI:|r " .. tostring(isReloadingUi))

	else
		-- Generic logging for any other events
		print("  |cffffaa00Args:|r " .. tostring(arg1) .. ", " .. tostring(arg2) .. ", " .. tostring(arg3) .. ", " .. tostring(arg4))
	end
end)

-- Monitor InspectFrame visibility
local function checkInspectFrameState()
	if InspectFrame and InspectFrame:IsShown() then
		if not inspectFrameOpen then
			inspectFrameOpen = true
			local currentTime = _GetTime()
			local delta = currentTime - lastEventTime
			print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [UI State]|r InspectFrame → |cff00ff00VISIBLE|r")
			lastEventTime = currentTime
		end
	else
		if inspectFrameOpen then
			inspectFrameOpen = false
			local currentTime = _GetTime()
			local delta = currentTime - lastEventTime
			print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [UI State]|r InspectFrame → |cffff0000HIDDEN|r")
			lastEventTime = currentTime
		end
	end
end

-- Add OnUpdate for continuous UI monitoring
investigationFrame:SetScript("OnUpdate", function()
	checkInspectFrameState()
end)

-- Hook inspect-related functions
if InspectUnit then
	hooksecurefunc("InspectUnit", function(unitId)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Inspect Hook]|r InspectUnit")
		lastEventTime = currentTime
		
		if unitId then
			print("  |cffffaa00Inspecting:|r " .. getUnitInfo(unitId))
			
			-- Check if we can actually inspect this unit
			local canInspect, reason = checkInspectability(unitId)
			if canInspect then
				print("  |cff00ff00  ✓ Inspect request valid|r")
				
				-- Track this inspect request
				currentInspectTarget = unitId
				currentInspectTargetName = _UnitName(unitId) or "Unknown"
				inspectInProgress = true
				inspectDataReceived = {}
				lastInspectRequest = {
					unitId = unitId,
					unitName = currentInspectTargetName,
					timestamp = currentTime,
					completed = false
				}
				
				print("  |cff00ff00  Started monitoring for INSPECT_READY...|r")
			else
				print("  |cffff0000  ✗ Inspect request invalid:|r " .. reason)
			end
		else
			print("  |cffff0000  ✗ No unit specified|r")
		end
	end)
end

if ClearInspectPlayer then
	hooksecurefunc("ClearInspectPlayer", function()
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Inspect Hook]|r ClearInspectPlayer")
		lastEventTime = currentTime
		
		-- Clear inspect state
		if currentInspectTarget or currentInspectTargetName then
			local targetInfo = "Unknown"
			if currentInspectTarget then
				targetInfo = getUnitInfo(currentInspectTarget)
				if targetInfo == "invalid unit" and currentInspectTargetName then
					targetInfo = currentInspectTargetName .. " (target lost)"
				end
			elseif currentInspectTargetName then
				targetInfo = currentInspectTargetName .. " (target lost)"
			end
			print("  |cffffaa00Clearing inspect data for:|r " .. targetInfo)
		end
		
		currentInspectTarget = nil
		currentInspectTargetName = nil
		inspectInProgress = false
		inspectDataReceived = {}
		inspectEquipmentSnapshot = {}
	end)
end

-- Hook inspect frame functions
if InspectFrame_Show then
	hooksecurefunc("InspectFrame_Show", function(unit)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Inspect Hook]|r InspectFrame_Show")
		lastEventTime = currentTime
		
		if unit then
			print("  |cffffaa00Showing inspect frame for:|r " .. getUnitInfo(unit))
		end
	end)
end

if InspectFrame_Hide then
	hooksecurefunc("InspectFrame_Hide", function()
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Inspect Hook]|r InspectFrame_Hide")
		lastEventTime = currentTime
	end)
end

-- Hook inspect equipment update functions
if InspectPaperDollFrame_SetLevel then
	hooksecurefunc("InspectPaperDollFrame_SetLevel", function()
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Inspect Hook]|r InspectPaperDollFrame_SetLevel")
		lastEventTime = currentTime
	end)
end

if InspectPaperDollItemSlotButton_Update then
	hooksecurefunc("InspectPaperDollItemSlotButton_Update", function(button)
		if not button then return end
		local slotId = button:GetID()
		
		-- Only log equipment slots (1-19), not bag slots
		if slotId < 1 or slotId > 19 then
			return
		end
		
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Inspect Hook]|r InspectPaperDollItemSlotButton_Update")
		print("  |cffffaa00Slot:|r " .. getInspectEquipmentInfo(slotId))
		lastEventTime = currentTime
	end)
end



-- Slash command to show current inspect state
SLASH_INSPECTSTATE1 = "/inspectstate"
SlashCmdList["INSPECTSTATE"] = function()
	print("|cff00ff00=== CURRENT INSPECT STATE ===|r")
	
	if currentInspectTarget or currentInspectTargetName then
		local targetInfo = "Unknown"
		if currentInspectTarget then
			targetInfo = getUnitInfo(currentInspectTarget)
			if targetInfo == "invalid unit" and currentInspectTargetName then
				targetInfo = currentInspectTargetName .. " (target lost)"
			end
		elseif currentInspectTargetName then
			targetInfo = currentInspectTargetName .. " (target lost)"
		end
		print("|cffffaa00Current Inspect Target:|r " .. targetInfo)
		print("|cffffaa00Inspect In Progress:|r " .. tostring(inspectInProgress))
		
		-- Show what data we've received
		local dataReceived = {}
		for dataType, received in pairs(inspectDataReceived) do
			if received then
				table.insert(dataReceived, dataType)
			end
		end
		
		if #dataReceived > 0 then
			print("|cffffaa00Data Received:|r " .. table.concat(dataReceived, ", "))
		else
			print("|cffffaa00Data Received:|r none")
		end
		
		-- Show equipment count
		local equippedCount = 0
		for slotId = 1, 19 do
			if inspectEquipmentSnapshot[slotId] then
				equippedCount = equippedCount + 1
			end
		end
		print("|cffffaa00Equipment Cached:|r " .. equippedCount .. "/19 slots")
		
	else
		print("|cffaaaaaa No inspect target|r")
	end
	
	local currentTarget = _UnitName("target")
	if currentTarget then
		print("|cffffaa00Current Target:|r " .. getUnitInfo("target"))
		local canInspect, reason = checkInspectability("target")
		print("|cffffaa00Can Inspect Target:|r " .. tostring(canInspect) .. " (" .. reason .. ")")
	else
		print("|cffaaaaaa No target|r")
	end
	
	print("|cff00ff00=== END INSPECT STATE ===|r")
end

-- Test functions for inspect hooks
local function testInspectHooks()
	print("|cff00ff00=== TESTING INSPECT HOOKS ===|r")
	
	-- Test InspectUnit hook
	if UnitExists("target") and UnitIsPlayer("target") then
		print("|cffffaa00Testing InspectUnit hook on target...|r")
		if InspectUnit then
			InspectUnit("target")
		else
			print("|cffff0000InspectUnit function not available|r")
		end
		
		-- Test ClearInspectPlayer hook
		print("|cffffaa00Testing ClearInspectPlayer hook...|r")
		if ClearInspectPlayer then
			ClearInspectPlayer()
		else
			print("|cffff0000ClearInspectPlayer function not available|r")
		end
	else
		print("|cffff6600Cannot test InspectUnit - no player target|r")
		print("|cffff6600Target a player first, then run /testinspecthooks|r")
	end
	
	-- Test InspectFrame_Show hook
	print("|cffffaa00Testing InspectFrame_Show hook...|r")
	if InspectFrame_Show then
		InspectFrame_Show("target")
	else
		print("|cffff0000InspectFrame_Show function not available|r")
	end
	
	-- Test InspectFrame_Hide hook
	print("|cffffaa00Testing InspectFrame_Hide hook...|r")
	if InspectFrame_Hide then
		InspectFrame_Hide()
	else
		print("|cffff0000InspectFrame_Hide function not available|r")
	end
	
	-- Test InspectPaperDollFrame_SetLevel hook
	print("|cffffaa00Testing InspectPaperDollFrame_SetLevel hook...|r")
	if InspectPaperDollFrame_SetLevel then
		InspectPaperDollFrame_SetLevel()
	else
		print("|cffff0000InspectPaperDollFrame_SetLevel function not available|r")
	end
	
	print("|cff00ff00=== INSPECT HOOK TESTS COMPLETE ===|r")
end

-- Slash command to test inspect hooks
SLASH_TESTINSPECTHOOKS1 = "/testinspecthooks"
SlashCmdList["TESTINSPECTHOOKS"] = testInspectHooks

print("|cff00ff00Inspect investigation ready - events will print to chat|r")
print("|cff00ff00Target players and use inspect (default: right-click → Inspect) to test|r")
print("|cff00ff00Use /inspectstate to see current inspect state|r")
print("|cff00ff00Use /testinspecthooks to test inspect function hooks|r")
print("|cff00ff00Classic Era (1.15) compatible version loaded|r")