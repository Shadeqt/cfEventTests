-- WoW API calls (Classic Era 1.15 compatible)
local _CreateFrame = CreateFrame
local _GetTime = GetTime
local _GetActionInfo = GetActionInfo
local _GetActionText = GetActionText
local _GetActionTexture = GetActionTexture
local _GetActionCooldown = GetActionCooldown
local _GetActionCount = GetActionCount
local _HasAction = HasAction
local _IsActionInRange = IsActionInRange
local _IsUsableAction = IsUsableAction
local _IsCurrentAction = IsCurrentAction
local _IsAutoRepeatAction = IsAutoRepeatAction
local _IsAttackAction = IsAttackAction
local _IsEquippedAction = IsEquippedAction
local _IsConsumableAction = IsConsumableAction
local _UseAction = UseAction
local _PickupAction = PickupAction
local _PlaceAction = PlaceAction
local _ClearCursor = ClearCursor
local _GetCursorInfo = GetCursorInfo
local _GetShapeshiftForm = GetShapeshiftForm
local _GetNumShapeshiftForms = GetNumShapeshiftForms
local _GetShapeshiftFormInfo = GetShapeshiftFormInfo
local _CastShapeshiftForm = CastShapeshiftForm
local _CastSpell = CastSpell
local _CastSpellByName = CastSpellByName
local _SpellStopCasting = SpellStopCasting
-- GetSpellName doesn't exist in Classic Era
local _GetSpellCooldown = GetSpellCooldown
local _IsSpellInRange = IsSpellInRange
local _IsUsableSpell = IsUsableSpell
local _GetSpellTabInfo = GetSpellTabInfo
local _GetNumSpellTabs = GetNumSpellTabs
-- Power functions don't exist in Classic Era
local _GetComboPoints = GetComboPoints

-- Pet action API
local _GetPetActionInfo = GetPetActionInfo
local _PetHasActionBar = PetHasActionBar
local _UnitExists = UnitExists
local _UnitClass = UnitClass

-- Spell API
local _C_Spell = C_Spell

-- Constants
local _NUM_PET_ACTION_SLOTS = NUM_PET_ACTION_SLOTS

print("=== ACTIONBAR EVENT INVESTIGATION LOADED ===")
print("This module will log ALL actionbar-related events")
print("Watch your chat for detailed event information")
print("=============================================")

-- Event tracking frame
local investigationFrame = _CreateFrame("Frame")

-- All actionbar-related events for Classic Era (1.15)
local ACTIONBAR_EVENTS = {
	-- Core actionbar events
	"ACTIONBAR_SHOWGRID",
	"ACTIONBAR_HIDEGRID", 
	"ACTIONBAR_PAGE_CHANGED",
	"ACTIONBAR_SLOT_CHANGED",
	"UPDATE_BONUS_ACTIONBAR",
	
	-- Action button updates
	"ACTIONBAR_UPDATE_STATE",
	"ACTIONBAR_UPDATE_USABLE",
	"ACTIONBAR_UPDATE_COOLDOWN",
	"UPDATE_INVENTORY_ALERTS",
	
	-- Shapeshift/stance events
	"UPDATE_SHAPESHIFT_FORMS",
	"UPDATE_SHAPESHIFT_USABLE",
	"UPDATE_SHAPESHIFT_COOLDOWN",
	"UPDATE_SHAPESHIFT_FORM",
	
	-- Spell/ability events affecting actionbars
	"SPELL_UPDATE_COOLDOWN",
	"SPELL_UPDATE_USABLE",
	"SPELLS_CHANGED",
	"LEARNED_SPELL_IN_TAB",
	"SPELL_ACTIVATION_OVERLAY_GLOW_SHOW",
	"SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
	
	-- Mana/resource events
	"UNIT_MANA",
	"UNIT_RAGE",
	"UNIT_ENERGY",
	"UNIT_POWER_UPDATE",
	"UNIT_MAXMANA",
	"UNIT_MAXRAGE",
	"UNIT_MAXENERGY",
	"UNIT_DISPLAYPOWER",
	
	-- Combat/targeting events affecting actions
	"PLAYER_TARGET_CHANGED",
	"PLAYER_REGEN_ENABLED",
	"PLAYER_REGEN_DISABLED",
	"UNIT_HEALTH",
	"PLAYER_COMBO_POINTS",
	"UNIT_AURA",
	"PLAYER_AURAS_CHANGED",
	
	-- Range/usability events
	"CURRENT_SPELL_CAST_CHANGED",
	"SPELL_FAILED",
	"SPELL_INTERRUPTED",
	"START_AUTOREPEAT_SPELL",
	"STOP_AUTOREPEAT_SPELL",
	
	-- Item/equipment events affecting actions
	"BAG_UPDATE",
	"UNIT_INVENTORY_CHANGED",
	"PLAYER_EQUIPMENT_CHANGED",
	"UPDATE_BINDINGS",
	
	-- Player state changes
	"PLAYER_ENTERING_WORLD",
	"PLAYER_LEVEL_UP",
	"CHARACTER_POINTS_CHANGED",
	"PLAYER_ALIVE",
	"PLAYER_DEAD",
	"PLAYER_UNGHOST",
	
	-- Cursor/drag events
	"CURSOR_UPDATE",
	"ITEM_LOCK_CHANGED",
	
	-- Talent/skill events
	"SKILL_LINES_CHANGED",
	"UPDATE_MACROS",
}

-- Event counter
local eventCounts = {}
for _, event in ipairs(ACTIONBAR_EVENTS) do
	eventCounts[event] = 0
end

-- Track last event timestamp for timing delta analysis
local lastEventTime = _GetTime()

-- Event batching system
local lastBatchTime = 0
local currentBatch = {}
local BATCH_WINDOW = 0.05 -- 50ms window for batching events

-- Context tracking for understanding event triggers
local lastPlayerAction = ""
local lastPlayerActionTime = 0
local lastTargetChange = ""
local lastTargetChangeTime = 0
local lastCombatState = ""
local lastCombatStateTime = 0

-- Actionbar state tracking
local currentPage = 1
local lastShapeshiftForm = 0
local actionbarVisible = true

-- Track action operations
local activeActionOperation = nil -- { type = "use/pickup/place", timestamp = time, slot = X }

-- UI state tracking
local actionbarGridShown = false

-- Helper function to get action info
local function getActionInfo(slot)
	if not slot then return "nil" end
	
	local actionType, id, subType = _GetActionInfo(slot)
	if not actionType then
		return string.format("[%d] EMPTY", slot)
	end
	
	local actionText = _GetActionText(slot) or ""
	local texture = _GetActionTexture(slot) or ""
	local count = _GetActionCount(slot) or 0
	local hasAction = _HasAction(slot)
	
	-- Get cooldown info
	local start, duration, enable = _GetActionCooldown(slot)
	local cooldownStr = ""
	if start and duration and duration > 0 then
		local remaining = (start + duration) - _GetTime()
		if remaining > 0 then
			cooldownStr = string.format(" (CD: %.1fs)", remaining)
		end
	end
	
	-- Get usability
	local isUsable, notEnoughMana = _IsUsableAction(slot)
	local usableStr = ""
	if not isUsable then
		usableStr = notEnoughMana and " [NO MANA]" or " [UNUSABLE]"
	end
	
	-- Get range
	local inRange = _IsActionInRange(slot)
	local rangeStr = ""
	if inRange == 0 then
		rangeStr = " [OUT OF RANGE]"
	elseif inRange == nil then
		rangeStr = " [NO RANGE REQ]"
	end
	
	-- Additional spell info for spell actions (removed - action info is sufficient)
	local spellInfo = ""
	
	-- Get special states
	local states = {}
	if _IsCurrentAction(slot) then table.insert(states, "CURRENT") end
	if _IsAutoRepeatAction(slot) then table.insert(states, "REPEAT") end
	if _IsAttackAction(slot) then table.insert(states, "ATTACK") end
	if _IsEquippedAction(slot) then table.insert(states, "EQUIPPED") end
	if _IsConsumableAction(slot) then table.insert(states, "CONSUMABLE") end
	
	local stateStr = #states > 0 and (" [" .. table.concat(states, ", ") .. "]") or ""
	
	-- Format count
	local countStr = count > 0 and (" x" .. count) or ""
	
	-- Get display name
	local displayName = actionText
	if not displayName or displayName == "" then
		if actionType == "spell" then
			displayName = "Spell:" .. tostring(id)
		elseif actionType == "item" then
			local itemName = GetItemInfo and GetItemInfo(id)
			displayName = itemName or ("Item:" .. tostring(id))
		elseif actionType == "macro" then
			local macroName = GetMacroInfo and GetMacroInfo(id)
			displayName = macroName or ("Macro:" .. tostring(id))
		else
			displayName = actionType .. ":" .. tostring(id)
		end
	end
	
	return string.format("[%d] %s%s%s%s%s%s%s", slot, displayName, countStr, cooldownStr, usableStr, rangeStr, spellInfo, stateStr)
end

-- Helper function to get shapeshift info
local function getShapeshiftInfo()
	local numForms = _GetNumShapeshiftForms and _GetNumShapeshiftForms() or 0
	local currentForm = _GetShapeshiftForm and _GetShapeshiftForm() or 0
	
	if numForms == 0 then
		return "No shapeshift forms available"
	end
	
	local forms = {}
	for i = 1, numForms do
		local icon, active, castable, cooldownStart, cooldownDuration = _GetShapeshiftFormInfo(i)
		local formName = "Form " .. i
		
		-- Get cooldown info
		local cooldownStr = ""
		if cooldownStart and cooldownDuration and cooldownDuration > 0 then
			local remaining = (cooldownStart + cooldownDuration) - _GetTime()
			if remaining > 0 then
				cooldownStr = string.format(" (CD: %.1fs)", remaining)
			end
		end
		
		-- Get state
		local stateStr = ""
		if active then
			stateStr = " [ACTIVE]"
		elseif not castable then
			stateStr = " [UNUSABLE]"
		end
		
		table.insert(forms, formName .. cooldownStr .. stateStr)
	end
	
	return string.format("Forms: %s | Current: %d", table.concat(forms, ", "), currentForm)
end

-- Register all events with error handling
local registeredEvents = {}
for _, event in ipairs(ACTIONBAR_EVENTS) do
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

	-- Filter out very frequent events unless we're tracking action operations
	if event == "BAG_UPDATE" or event == "UNIT_HEALTH" or event == "UNIT_MANA" then
		if not activeActionOperation then
			return -- Don't log frequent updates outside action context
		end
	end
	
	-- Filter out periodic background validation events
	if event == "CURRENT_SPELL_CAST_CHANGED" or event == "UPDATE_SHAPESHIFT_FORM" or 
	   event == "ACTIONBAR_UPDATE_STATE" or event == "UNIT_POWER_UPDATE" then
		if not activeActionOperation and timeSinceLastEvent > 1.0 then
			return -- Skip periodic background updates
		end
	end
	
	-- Filter SPELL_UPDATE_USABLE unless it's triggered by meaningful events
	if event == "SPELL_UPDATE_USABLE" then
		if not activeActionOperation and timeSinceLastEvent > 1.0 and 
		   currentTime - lastTargetChangeTime > 1.0 and 
		   currentTime - lastCombatStateTime > 1.0 then
			return -- Skip periodic spell validation
		end
	end
	
	-- Filter CURSOR_UPDATE unless we're in action context
	if event == "CURSOR_UPDATE" then
		if not activeActionOperation then
			return
		end
	end

	-- Batch events that happen within the same time window
	if currentTime - lastBatchTime <= BATCH_WINDOW and #currentBatch > 0 then
		-- Add to current batch
		table.insert(currentBatch, {event = event, count = eventCounts[event]})
	else
		-- Print previous batch if exists
		if #currentBatch > 0 then
			if #currentBatch == 1 then
				local batchEvent = currentBatch[1]
				print("|cffff9900" .. string.format("[%.2f]", lastBatchTime) .. " [#" .. batchEvent.count .. "] " .. string.format("(+%.0fms)", (lastBatchTime - lastEventTime) * 1000) .. " |cff00ffff" .. batchEvent.event .. "|r")
			else
				local eventNames = {}
				for _, batchEvent in ipairs(currentBatch) do
					table.insert(eventNames, batchEvent.event .. "(#" .. batchEvent.count .. ")")
				end
				print("|cffff9900" .. string.format("[%.2f]", lastBatchTime) .. " " .. string.format("(+%.0fms)", (lastBatchTime - lastEventTime) * 1000) .. " |cff00ffff[BATCH " .. #currentBatch .. "] " .. table.concat(eventNames, ", ") .. "|r")
			end
			lastEventTime = lastBatchTime
		end
		
		-- Start new batch
		currentBatch = {{event = event, count = eventCounts[event]}}
		lastBatchTime = currentTime
	end

	-- Event-specific detailed logging
	if event == "ACTIONBAR_SHOWGRID" then
		print("  |cffffaa00Action Grid Shown|r")
		actionbarGridShown = true

	elseif event == "ACTIONBAR_HIDEGRID" then
		print("  |cffffaa00Action Grid Hidden|r")
		actionbarGridShown = false

	elseif event == "ACTIONBAR_PAGE_CHANGED" then
		print("  |cffffaa00Page Changed|r")
		-- Get current page if possible
		if GetActionBarPage then
			local newPage = GetActionBarPage()
			print("  |cffffaa00  New Page:|r " .. tostring(newPage))
			currentPage = newPage
		end

	elseif event == "ACTIONBAR_SLOT_CHANGED" then
		local slot = arg1
		print("  |cffffaa00Slot Changed:|r " .. tostring(slot))
		
		if slot then
			local actionInfo = getActionInfo(slot)
			print("  |cffffaa00  " .. actionInfo .. "|r")
		end

	elseif event == "UPDATE_BONUS_ACTIONBAR" then
		print("  |cffffaa00Bonus Actionbar Updated|r")

	elseif event == "ACTIONBAR_UPDATE_STATE" then
		print("  |cffffaa00Action States Updated|r")

	elseif event == "ACTIONBAR_UPDATE_USABLE" then
		print("  |cffffaa00Action Usability Updated|r")

	elseif event == "ACTIONBAR_UPDATE_COOLDOWN" then
		print("  |cffffaa00Action Cooldowns Updated|r")

	elseif event == "UPDATE_INVENTORY_ALERTS" then
		print("  |cffffaa00Inventory Alerts Updated|r")

	elseif event == "UPDATE_SHAPESHIFT_FORMS" then
		print("  |cffffaa00Shapeshift Forms Updated|r")
		local shapeshiftInfo = getShapeshiftInfo()
		print("  |cffffaa00  " .. shapeshiftInfo .. "|r")

	elseif event == "UPDATE_SHAPESHIFT_USABLE" then
		print("  |cffffaa00Shapeshift Usability Updated|r")

	elseif event == "UPDATE_SHAPESHIFT_COOLDOWN" then
		print("  |cffffaa00Shapeshift Cooldowns Updated|r")

	elseif event == "UPDATE_SHAPESHIFT_FORM" then
		print("  |cffffaa00Shapeshift Form Changed|r")
		local currentForm = _GetShapeshiftForm and _GetShapeshiftForm() or 0
		print("  |cffffaa00  Current Form:|r " .. tostring(currentForm))
		lastShapeshiftForm = currentForm

	elseif event == "SPELL_UPDATE_COOLDOWN" then
		print("  |cffffaa00Spell Cooldowns Updated|r")

	elseif event == "SPELL_UPDATE_USABLE" then
		print("  |cffffaa00Spell Usability Updated|r")
		
		-- Check action slots for spell usability changes
		local usabilityChanges = {}
		for slot = 1, 120 do -- Check all action slots
			if _HasAction(slot) then
				local actionType, id, subType = _GetActionInfo(slot)
				if actionType == "spell" then
					local isUsable, notEnoughMana = _IsUsableAction(slot)
					
					-- Safely get spell name
					local spellName = _GetActionText(slot)
					if not spellName or spellName == "" then
						spellName = "Spell:" .. tostring(id)
					end
					
					-- Get additional spell info
					local rangeInfo = ""
					local inRange = _IsActionInRange(slot)
					if inRange == 0 then
						rangeInfo = " [OUT OF RANGE]"
					elseif inRange == nil then
						rangeInfo = " [NO RANGE]"
					else
						rangeInfo = " [IN RANGE]"
					end
					
					local usabilityInfo = ""
					if not isUsable then
						usabilityInfo = notEnoughMana and " [NO MANA]" or " [UNUSABLE]"
					else
						usabilityInfo = " [USABLE]"
					end
					
					table.insert(usabilityChanges, string.format("Slot %d: %s%s%s", slot, spellName, usabilityInfo, rangeInfo))
				end
			end
		end
		
		-- Show only interesting spell states (filter out NO RANGE spam)
		local interestingChanges = {}
		for _, change in ipairs(usabilityChanges) do
			if change:find("%[IN RANGE%]") or change:find("%[OUT OF RANGE%]") or 
			   change:find("%[NO MANA%]") or change:find("%[UNUSABLE%]") then
				table.insert(interestingChanges, change)
			end
		end
		
		if #interestingChanges > 0 then
			print("  |cffaaaaaa  Important spell states:|r")
			for i = 1, math.min(8, #interestingChanges) do
				print("    |cffaaaaaa  " .. interestingChanges[i] .. "|r")
			end
			if #interestingChanges > 8 then
				print("    |cffaaaaaa  ... and " .. (#interestingChanges - 8) .. " more|r")
			end
		elseif #usabilityChanges > 0 then
			-- Show count of total spells but don't spam NO RANGE
			local rangedSpells = 0
			for _, change in ipairs(usabilityChanges) do
				if not change:find("%[NO RANGE%]") then
					rangedSpells = rangedSpells + 1
				end
			end
			print("  |cffaaaaaa  " .. #usabilityChanges .. " spells checked (" .. rangedSpells .. " with range requirements)|r")
		end

	elseif event == "BAG_UPDATE" then
		local bagId = arg1
		
		if activeActionOperation then
			local statusStr = "(during action operation)"
			print("  |cffffaa00Bag Updated " .. statusStr .. ":|r Bag " .. tostring(bagId))
		end

	elseif event == "UNIT_INVENTORY_CHANGED" then
		local unit = arg1
		print("  |cffffaa00Inventory Changed:|r " .. tostring(unit))

	elseif event == "PLAYER_TARGET_CHANGED" then
		print("  |cffffaa00Target Changed|r")
		local targetName = UnitName("target")
		if targetName then
			print("  |cffffaa00  New Target:|r " .. targetName)
			lastTargetChange = "Targeted " .. targetName
		else
			print("  |cffffaa00  Target Cleared|r")
			lastTargetChange = "Cleared Target"
		end
		lastTargetChangeTime = _GetTime()

	elseif event == "PLAYER_REGEN_ENABLED" then
		print("  |cff00ff00Combat Ended|r")
		lastCombatState = "Combat Ended"
		lastCombatStateTime = _GetTime()

	elseif event == "PLAYER_REGEN_DISABLED" then
		print("  |cffff0000Combat Started|r")
		lastCombatState = "Combat Started"
		lastCombatStateTime = _GetTime()

	elseif event == "UNIT_HEALTH" then
		local unit = arg1
		if activeActionOperation and unit == "player" then
			local health = UnitHealth(unit)
			local maxHealth = UnitHealthMax(unit)
			print("  |cffffaa00Health Changed (during action):|r " .. health .. "/" .. maxHealth)
		end

	elseif event == "UNIT_MANA" then
		local unit = arg1
		if unit == "player" then
			print("  |cffffaa00Mana/Power Changed:|r Unit: " .. unit)
			-- Note: Mana functions may not be available in Classic Era, just log the event
		end

	elseif event == "UNIT_RAGE" then
		local unit = arg1
		if unit == "player" then
			local rage = UnitMana(unit)
			local maxRage = UnitManaMax(unit)
			print("  |cffffaa00Rage Changed:|r " .. rage .. "/" .. maxRage .. " (" .. math.floor(rage/maxRage*100) .. "%)")
		end

	elseif event == "UNIT_ENERGY" then
		local unit = arg1
		if unit == "player" then
			local energy = UnitMana(unit)
			local maxEnergy = UnitManaMax(unit)
			print("  |cffffaa00Energy Changed:|r " .. energy .. "/" .. maxEnergy .. " (" .. math.floor(energy/maxEnergy*100) .. "%)")
		end

	elseif event == "UNIT_POWER_UPDATE" then
		local unit, powerTypeStr = arg1, arg2
		if unit == "player" then
			print("  |cffffaa00" .. tostring(powerTypeStr) .. " Power Update:|r Unit: " .. unit)
			-- Note: Power functions may not be available in Classic Era, just log the event
		end

	elseif event == "PLAYER_COMBO_POINTS" then
		local comboPoints = _GetComboPoints and _GetComboPoints("player", "target") or 0
		print("  |cffffaa00Combo Points:|r " .. comboPoints)

	elseif event == "SPELLS_CHANGED" then
		print("  |cffffaa00Spells Changed|r (learned/unlearned)")

	elseif event == "LEARNED_SPELL_IN_TAB" then
		local tabIndex, spellIndex = arg1, arg2
		print("  |cffffaa00Learned Spell:|r Tab " .. tostring(tabIndex) .. ", Index " .. tostring(spellIndex))

	elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
		local spellID = arg1
		print("  |cff00ff00Spell Glow Show:|r Spell " .. tostring(spellID))

	elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
		local spellID = arg1
		print("  |cffffaa00Spell Glow Hide:|r Spell " .. tostring(spellID))

	elseif event == "CURRENT_SPELL_CAST_CHANGED" then
		local isCasting = arg1
		print("  |cffffaa00Spell Cast Changed:|r " .. tostring(isCasting))

	elseif event == "SPELL_FAILED" then
		local spellID = arg1
		print("  |cffff0000Spell Failed:|r " .. tostring(spellID))

	elseif event == "SPELL_INTERRUPTED" then
		print("  |cffff0000Spell Interrupted|r")

	elseif event == "START_AUTOREPEAT_SPELL" then
		print("  |cff00ff00Auto-repeat Started|r")

	elseif event == "STOP_AUTOREPEAT_SPELL" then
		print("  |cffffaa00Auto-repeat Stopped|r")

	elseif event == "UNIT_AURA" then
		local unit = arg1
		if unit == "player" then
			print("  |cffffaa00Player Auras Changed|r")
		elseif unit == "target" then
			print("  |cffffaa00Target Auras Changed|r")
		end

	elseif event == "PLAYER_AURAS_CHANGED" then
		print("  |cffffaa00Player Auras Changed (legacy)|r")

	elseif event == "PLAYER_EQUIPMENT_CHANGED" then
		local slotID = arg1
		print("  |cffffaa00Equipment Changed:|r Slot " .. tostring(slotID))

	elseif event == "UPDATE_BINDINGS" then
		print("  |cffffaa00Key Bindings Updated|r")

	elseif event == "PLAYER_ALIVE" then
		print("  |cff00ff00Player Alive|r")

	elseif event == "PLAYER_DEAD" then
		print("  |cffff0000Player Dead|r")

	elseif event == "PLAYER_UNGHOST" then
		print("  |cff00ff00Player Unghost|r")

	elseif event == "SKILL_LINES_CHANGED" then
		print("  |cffffaa00Skill Lines Changed|r")

	elseif event == "UPDATE_MACROS" then
		print("  |cffffaa00Macros Updated|r")

	elseif event == "PLAYER_LEVEL_UP" then
		local newLevel = arg1
		print("  |cff00ff00Level Up!|r New Level: " .. tostring(newLevel))

	elseif event == "CHARACTER_POINTS_CHANGED" then
		local change = arg1
		print("  |cffffaa00Character Points Changed:|r " .. tostring(change))

	elseif event == "CURSOR_UPDATE" then
		if activeActionOperation then
			local cursorType, info1, info2 = _GetCursorInfo()
			print("  |cffffaa00Cursor Updated (during action):|r " .. tostring(cursorType))
		end

	elseif event == "ITEM_LOCK_CHANGED" then
		local bagId, slotId = arg1, arg2
		print("  |cffffaa00Item Lock Changed:|r Bag " .. tostring(bagId) .. ", Slot " .. tostring(slotId))

	elseif event == "PLAYER_ENTERING_WORLD" then
		local isInitialLogin, isReloadingUi = arg1, arg2
		print("  |cffffaa00Initial Login:|r " .. tostring(isInitialLogin))
		print("  |cffffaa00Reloading UI:|r " .. tostring(isReloadingUi))

	else
		-- Generic logging for any other events
		print("  |cffffaa00Args:|r " .. tostring(arg1) .. ", " .. tostring(arg2) .. ", " .. tostring(arg3) .. ", " .. tostring(arg4))
	end
end)

-- Function to determine event context
local function getEventContext(currentTime)
	local context = {}
	
	-- Check recent player actions
	if currentTime - lastPlayerActionTime < 2.0 and lastPlayerAction ~= "" then
		table.insert(context, "After " .. lastPlayerAction)
	end
	
	-- Check recent target changes
	if currentTime - lastTargetChangeTime < 1.0 and lastTargetChange ~= "" then
		table.insert(context, "Target: " .. lastTargetChange)
	end
	
	-- Check recent combat state changes
	if currentTime - lastCombatStateTime < 3.0 and lastCombatState ~= "" then
		table.insert(context, lastCombatState)
	end
	
	-- Check if we're in combat
	if UnitAffectingCombat and UnitAffectingCombat("player") then
		table.insert(context, "In Combat")
	end
	
	-- Check if we have a target
	if UnitExists("target") then
		local targetName = UnitName("target")
		local targetType = UnitIsPlayer("target") and "Player" or (UnitIsFriend("player", "target") and "Friendly" or "Hostile")
		table.insert(context, "Target: " .. targetType .. " " .. (targetName or "Unknown"))
	else
		table.insert(context, "No Target")
	end
	
	-- Check current form/stance
	if _GetShapeshiftForm then
		local form = _GetShapeshiftForm()
		if form > 0 then
			table.insert(context, "Form: " .. form)
		end
	end
	
	return #context > 0 and (" |cff888888[" .. table.concat(context, " | ") .. "]|r") or ""
end

-- Timer to flush final batch
local flushFrame = _CreateFrame("Frame")
flushFrame:SetScript("OnUpdate", function()
	if #currentBatch > 0 and _GetTime() - lastBatchTime > BATCH_WINDOW then
		local context = getEventContext(lastBatchTime)
		if #currentBatch == 1 then
			local batchEvent = currentBatch[1]
			print("|cffff9900" .. string.format("[%.2f]", lastBatchTime) .. " [#" .. batchEvent.count .. "] " .. string.format("(+%.0fms)", (lastBatchTime - lastEventTime) * 1000) .. " |cff00ffff" .. batchEvent.event .. "|r" .. context)
		else
			local eventNames = {}
			for _, batchEvent in ipairs(currentBatch) do
				table.insert(eventNames, batchEvent.event .. "(#" .. batchEvent.count .. ")")
			end
			print("|cffff9900" .. string.format("[%.2f]", lastBatchTime) .. " " .. string.format("(+%.0fms)", (lastBatchTime - lastEventTime) * 1000) .. " |cff00ffff[BATCH " .. #currentBatch .. "] " .. table.concat(eventNames, ", ") .. "|r" .. context)
		end
		lastEventTime = lastBatchTime
		currentBatch = {}
	end
end)

-- Hook actionbar functions
if _UseAction then
	hooksecurefunc("UseAction", function(slot, checkCursor, onSelf)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Action Hook]|r UseAction")
		
		local actionInfo = getActionInfo(slot)
		print("  |cffffaa00Action:|r " .. actionInfo)
		print("  |cffffaa00Check Cursor:|r " .. tostring(checkCursor))
		print("  |cffffaa00On Self:|r " .. tostring(onSelf))
		
		-- Track this operation
		activeActionOperation = {
			type = "use",
			timestamp = currentTime,
			slot = slot
		}
		
		-- Update context
		lastPlayerAction = "Used Action Slot " .. slot
		lastPlayerActionTime = currentTime
		
		lastEventTime = currentTime
	end)
end

if _PickupAction then
	hooksecurefunc("PickupAction", function(slot)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Action Hook]|r PickupAction")
		
		local actionInfo = getActionInfo(slot)
		print("  |cffffaa00Action:|r " .. actionInfo)
		
		-- Track this operation
		activeActionOperation = {
			type = "pickup",
			timestamp = currentTime,
			slot = slot
		}
		
		-- Update context
		lastPlayerAction = "Picked up Action from Slot " .. slot
		lastPlayerActionTime = currentTime
		
		lastEventTime = currentTime
	end)
end

if _PlaceAction then
	hooksecurefunc("PlaceAction", function(slot)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Action Hook]|r PlaceAction")
		
		print("  |cffffaa00Target Slot:|r " .. tostring(slot))
		
		-- Get cursor info
		local cursorType, info1, info2 = _GetCursorInfo()
		if cursorType then
			print("  |cffffaa00Cursor Type:|r " .. tostring(cursorType))
			print("  |cffffaa00Cursor Info:|r " .. tostring(info1) .. ", " .. tostring(info2))
		end
		
		-- Track this operation
		activeActionOperation = {
			type = "place",
			timestamp = currentTime,
			slot = slot
		}
		
		-- Update context
		lastPlayerAction = "Placed Action in Slot " .. slot
		lastPlayerActionTime = currentTime
		
		lastEventTime = currentTime
	end)
end

if _CastShapeshiftForm then
	hooksecurefunc("CastShapeshiftForm", function(index)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Action Hook]|r CastShapeshiftForm")
		
		print("  |cffffaa00Form Index:|r " .. tostring(index))
		
		-- Track this operation
		activeActionOperation = {
			type = "shapeshift",
			timestamp = currentTime,
			formIndex = index
		}
		
		lastEventTime = currentTime
	end)
end

if _CastSpell then
	hooksecurefunc("CastSpell", function(spellID, bookType)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Spell Hook]|r CastSpell")
		
		local spellName = _GetSpellName(spellID, bookType)
		print("  |cffffaa00Spell:|r " .. tostring(spellName) .. " (ID: " .. tostring(spellID) .. ")")
		print("  |cffffaa00Book Type:|r " .. tostring(bookType))
		
		-- Get spell info
		if _IsUsableSpell then
			local isUsable, notEnoughMana = _IsUsableSpell(spellID, bookType)
			local usableStr = isUsable and "Usable" or (notEnoughMana and "No Mana" or "Unusable")
			print("  |cffffaa00Usability:|r " .. usableStr)
		end
		
		if _GetSpellCooldown then
			local start, duration, enable = _GetSpellCooldown(spellID, bookType)
			if duration and duration > 0 then
				print("  |cffffaa00Cooldown:|r " .. string.format("%.1fs", duration))
			end
		end
		
		-- Track this operation
		activeActionOperation = {
			type = "cast_spell",
			timestamp = currentTime,
			spellID = spellID,
			spellName = spellName
		}
		
		lastEventTime = currentTime
	end)
end

if _CastSpellByName then
	hooksecurefunc("CastSpellByName", function(spellName, onSelf)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Spell Hook]|r CastSpellByName")
		
		print("  |cffffaa00Spell Name:|r " .. tostring(spellName))
		print("  |cffffaa00On Self:|r " .. tostring(onSelf))
		
		-- Track this operation
		activeActionOperation = {
			type = "cast_spell_by_name",
			timestamp = currentTime,
			spellName = spellName
		}
		
		lastEventTime = currentTime
	end)
end

if _SpellStopCasting then
	hooksecurefunc("SpellStopCasting", function()
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Spell Hook]|r SpellStopCasting")
		
		-- Track this operation
		activeActionOperation = {
			type = "stop_casting",
			timestamp = currentTime
		}
		
		lastEventTime = currentTime
	end)
end

-- Hook ActionButton update functions
hooksecurefunc("ActionButton_UpdateUsable", function(button)
	local currentTime = _GetTime()
	local delta = currentTime - lastEventTime
	print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Button Hook]|r ActionButton_UpdateUsable")
	
	if button and button.action then
		local actionInfo = getActionInfo(button.action)
		print("  |cffffaa00Button Action:|r " .. actionInfo)
	end
	
	lastEventTime = currentTime
end)

hooksecurefunc("ActionButton_UpdateRangeIndicator", function(button)
	local currentTime = _GetTime()
	local delta = currentTime - lastEventTime
	print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Button Hook]|r ActionButton_UpdateRangeIndicator")
	
	if button and button.action then
		local actionInfo = getActionInfo(button.action)
		print("  |cffffaa00Button Action:|r " .. actionInfo)
	end
	
	lastEventTime = currentTime
end)

-- Hook PetActionBar_Update for pet classes
local _, playerClass = UnitClass("player")
if playerClass == "HUNTER" or playerClass == "WARLOCK" then
	hooksecurefunc("PetActionBar_Update", function()
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Pet Hook]|r PetActionBar_Update")
		
		if PetHasActionBar() then
			print("  |cffffaa00Pet has action bar - checking pet actions|r")
			for i = 1, NUM_PET_ACTION_SLOTS do
				local name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled, spellId, hasRangeCheck, isInRange = GetPetActionInfo(i)
				if spellId then
					local rangeStr = hasRangeCheck and (isInRange and "[IN RANGE]" or "[OUT OF RANGE]") or "[NO RANGE]"
					local usableStr = ""
					if C_Spell and C_Spell.IsSpellUsable then
						local isUsable, notEnoughMana = C_Spell.IsSpellUsable(spellId)
						usableStr = isUsable and "[USABLE]" or (notEnoughMana and "[NO MANA]" or "[UNUSABLE]")
					end
					print("  |cffffaa00  Pet Slot " .. i .. ":|r " .. (name or ("Spell:" .. spellId)) .. " " .. rangeStr .. " " .. usableStr)
				end
			end
		else
			print("  |cffffaa00Pet has no action bar|r")
		end
		
		lastEventTime = currentTime
	end)
end

-- Clear operation tracking after a delay
local clearOperationFrame = _CreateFrame("Frame")
clearOperationFrame:SetScript("OnUpdate", function()
	if activeActionOperation then
		local currentTime = _GetTime()
		if currentTime - activeActionOperation.timestamp > 2.0 then
			activeActionOperation = nil
		end
	end
end)

-- Test functions for actionbar hooks
local function testActionbarHooks()
	print("|cff00ff00=== TESTING ACTIONBAR HOOKS ===|r")
	print("|cffff6600NOTE: Protected function calls have been disabled to prevent Blizzard UI warnings|r")
	print("|cffff6600The hooks are still active and will trigger when you manually use actions|r")
	
	-- Test hook availability (but don't call protected functions)
	print("|cffffaa00Checking UseAction hook availability...|r")
	if _UseAction then
		print("|cff00ff00✓ UseAction hook is available|r")
		if _HasAction(1) then
			print("|cffffaa00  Slot 1 has action: " .. getActionInfo(1) .. "|r")
			print("|cffffaa00  To test: manually click action button 1|r")
		else
			print("|cffff6600  Slot 1 is empty - place an action there to test|r")
		end
	else
		print("|cffff0000✗ UseAction function not available|r")
	end
	
	print("|cffffaa00Checking PickupAction/PlaceAction hook availability...|r")
	if _PickupAction and _PlaceAction then
		print("|cff00ff00✓ PickupAction and PlaceAction hooks are available|r")
		if _HasAction(2) then
			print("|cffffaa00  Slot 2 has action: " .. getActionInfo(2) .. "|r")
			print("|cffffaa00  To test: drag action button 2 to another slot|r")
		else
			print("|cffff6600  Slot 2 is empty - place an action there to test|r")
		end
	else
		print("|cffff0000✗ PickupAction or PlaceAction functions not available|r")
	end
	
	print("|cffffaa00Checking CastSpellByName hook availability...|r")
	if _CastSpellByName then
		print("|cff00ff00✓ CastSpellByName hook is available|r")
		print("|cffffaa00  To test: use a keybind or macro that calls CastSpellByName|r")
	else
		print("|cffff0000✗ CastSpellByName function not available|r")
	end
	
	print("|cffffaa00Checking SpellStopCasting hook availability...|r")
	if _SpellStopCasting then
		print("|cff00ff00✓ SpellStopCasting hook is available|r")
		print("|cffffaa00  To test: start casting a spell then press Escape|r")
	else
		print("|cffff0000✗ SpellStopCasting function not available|r")
	end
	
	print("|cffffaa00Checking CastShapeshiftForm hook availability...|r")
	if _CastShapeshiftForm then
		print("|cff00ff00✓ CastShapeshiftForm hook is available|r")
		if _GetNumShapeshiftForms and _GetNumShapeshiftForms() > 0 then
			print("|cffffaa00  " .. getShapeshiftInfo() .. "|r")
			print("|cffffaa00  To test: click a shapeshift form button|r")
		else
			print("|cffff6600  No shapeshift forms available for this character|r")
		end
	else
		print("|cffff0000✗ CastShapeshiftForm function not available|r")
	end
	
	print("|cffffaa00Checking ActionButton hooks availability...|r")
	if ActionButton_UpdateUsable and ActionButton_UpdateRangeIndicator then
		print("|cff00ff00✓ ActionButton_UpdateUsable and ActionButton_UpdateRangeIndicator hooks are available|r")
		print("|cffffaa00  To test: target something and use spells to trigger range/usability updates|r")
	else
		print("|cffff0000✗ ActionButton update functions not available|r")
	end
	
	print("|cffffaa00Checking PetActionBar_Update hook availability...|r")
	local _, playerClass = _UnitClass("player")
	if playerClass == "HUNTER" or playerClass == "WARLOCK" then
		if PetActionBar_Update then
			print("|cff00ff00✓ PetActionBar_Update hook is available for " .. playerClass .. "|r")
			if _UnitExists("pet") and _PetHasActionBar() then
				print("|cffffaa00  Pet exists with action bar - hook will trigger on pet updates|r")
			else
				print("|cffff6600  No pet or pet action bar - summon a pet to test|r")
			end
		else
			print("|cffff0000✗ PetActionBar_Update function not available|r")
		end
	else
		print("|cffff6600  Pet action bar hooks only available for Hunter/Warlock (you are " .. playerClass .. ")|r")
	end
	
	print("")
	print("|cff00ff00=== ACTIONBAR HOOK TESTS COMPLETE ===|r")
	print("|cffffaa00All hooks are monitoring and will log when you perform actions manually|r")
end

-- Slash command to test actionbar hooks
SLASH_TESTACTIONBARHOOKS1 = "/testactionbarhooks"
SlashCmdList["TESTACTIONBARHOOKS"] = testActionbarHooks

print("|cff00ff00Actionbar investigation ready - events will print to chat|r")
print("|cff00ff00Use abilities, drag actions, change pages to test events|r")
print("|cff00ff00Use /testactionbarhooks to test actionbar function hooks|r")
print("|cff00ff00Classic Era (1.15) compatible version loaded|r")