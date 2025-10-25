-- Master Hook Test Script
-- This script provides a comprehensive test of all hooks across all event test files

local _GetTime = GetTime

print("=== MASTER HOOK TEST SCRIPT LOADED ===")
print("This script will test ALL hooks from ALL event test files")
print("Make sure all event test files are loaded first!")
print("===========================================")

-- Master test function that calls all individual hook tests
local function runAllHookTests()
	print("|cff00ff00=== STARTING COMPREHENSIVE HOOK TESTING ===|r")
	print("|cffffaa00Testing hooks from all loaded event test files...|r")
	print("")
	
	local startTime = _GetTime()
	
	-- Test Trade hooks
	if SlashCmdList["TESTTRADEHOOKS"] then
		print("|cff00ffff=== TRADE HOOKS ===|r")
		SlashCmdList["TESTTRADEHOOKS"]()
		print("")
	else
		print("|cffff6600Trade hook tests not available - TRADE_EVENT_TEST.lua not loaded|r")
	end
	
	-- Test Actionbar hooks
	if SlashCmdList["TESTACTIONBARHOOKS"] then
		print("|cff00ffff=== ACTIONBAR HOOKS ===|r")
		SlashCmdList["TESTACTIONBARHOOKS"]()
		print("")
	else
		print("|cffff6600Actionbar hook tests not available - ACTIONBAR_EVENT_TEST.lua not loaded|r")
	end
	
	-- Test Auction House hooks
	if SlashCmdList["TESTAUCTIONHOOKS"] then
		print("|cff00ffff=== AUCTION HOUSE HOOKS ===|r")
		SlashCmdList["TESTAUCTIONHOOKS"]()
		print("")
	else
		print("|cffff6600Auction house hook tests not available - AUCTION_EVENT_TEST.lua not loaded|r")
	end
	
	-- Test Bag/Bank hooks
	if SlashCmdList["TESTBAGHOOKS"] then
		print("|cff00ffff=== BAG/BANK HOOKS ===|r")
		SlashCmdList["TESTBAGHOOKS"]()
		print("")
	else
		print("|cffff6600Bag/Bank hook tests not available - BAG_BANK_EVENT_TEST.lua not loaded|r")
	end
	
	-- Test Character hooks
	if SlashCmdList["TESTCHARACTERHOOKS"] then
		print("|cff00ffff=== CHARACTER HOOKS ===|r")
		SlashCmdList["TESTCHARACTERHOOKS"]()
		print("")
	else
		print("|cffff6600Character hook tests not available - CHARACTER_EVENT_TEST.lua not loaded|r")
	end
	
	-- Test Inspect hooks
	if SlashCmdList["TESTINSPECTHOOKS"] then
		print("|cff00ffff=== INSPECT HOOKS ===|r")
		SlashCmdList["TESTINSPECTHOOKS"]()
		print("")
	else
		print("|cffff6600Inspect hook tests not available - INSPECT_EVENT_TEST.lua not loaded|r")
	end
	
	-- Test Loot hooks
	if SlashCmdList["TESTLOOTHOOKS"] then
		print("|cff00ffff=== LOOT HOOKS ===|r")
		SlashCmdList["TESTLOOTHOOKS"]()
		print("")
	else
		print("|cffff6600Loot hook tests not available - LOOT_EVENT_TEST.lua not loaded|r")
	end
	
	-- Test Mailbox hooks
	if SlashCmdList["TESTMAILBOXHOOKS"] then
		print("|cff00ffff=== MAILBOX HOOKS ===|r")
		SlashCmdList["TESTMAILBOXHOOKS"]()
		print("")
	else
		print("|cffff6600Mailbox hook tests not available - MAILBOX_EVENT_TEST.lua not loaded|r")
	end
	
	-- Test Merchant hooks
	if SlashCmdList["TESTMERCANTHOOKS"] then
		print("|cff00ffff=== MERCHANT HOOKS ===|r")
		SlashCmdList["TESTMERCANTHOOKS"]()
		print("")
	else
		print("|cffff6600Merchant hook tests not available - MERCHANT_EVENT_TEST.lua not loaded|r")
	end
	
	-- Test Profession hooks
	if SlashCmdList["TESTPROFESSIONHOOKS"] then
		print("|cff00ffff=== PROFESSION HOOKS ===|r")
		SlashCmdList["TESTPROFESSIONHOOKS"]()
		print("")
	else
		print("|cffff6600Profession hook tests not available - PROFESSIONS_EVENT_TEST.lua not loaded|r")
	end
	
	-- Test Quest hooks
	if SlashCmdList["TESTQUESTHOOKS"] then
		print("|cff00ffff=== QUEST HOOKS ===|r")
		SlashCmdList["TESTQUESTHOOKS"]()
		print("")
	else
		print("|cffff6600Quest hook tests not available - QUEST_EVENT_TEST.lua not loaded|r")
	end
	
	local endTime = _GetTime()
	local totalTime = endTime - startTime
	
	print("|cff00ff00=== COMPREHENSIVE HOOK TESTING COMPLETE ===|r")
	print("|cffffaa00Total test time:|r " .. string.format("%.2f seconds", totalTime))
	print("|cffffaa00Check the chat log above for detailed results|r")
	print("")
	print("|cffff9900IMPORTANT NOTES:|r")
	print("|cffff6600- Some tests require specific conditions (open windows, targets, items)|r")
	print("|cffff6600- Tests marked as 'not available' mean the window/condition wasn't met|r")
	print("|cffff6600- Hook functions that don't exist will show 'function not available'|r")
	print("|cffff6600- This is normal for Classic Era - not all functions exist|r")
end

-- Function to test specific category of hooks
local function testSpecificHooks(category)
	category = category and category:lower() or ""
	
	if category == "trade" and SlashCmdList["TESTTRADEHOOKS"] then
		SlashCmdList["TESTTRADEHOOKS"]()
	elseif category == "actionbar" and SlashCmdList["TESTACTIONBARHOOKS"] then
		SlashCmdList["TESTACTIONBARHOOKS"]()
	elseif category == "auction" and SlashCmdList["TESTAUCTIONHOOKS"] then
		SlashCmdList["TESTAUCTIONHOOKS"]()
	elseif category == "bag" or category == "bags" and SlashCmdList["TESTBAGHOOKS"] then
		SlashCmdList["TESTBAGHOOKS"]()
	elseif category == "character" and SlashCmdList["TESTCHARACTERHOOKS"] then
		SlashCmdList["TESTCHARACTERHOOKS"]()
	elseif category == "inspect" and SlashCmdList["TESTINSPECTHOOKS"] then
		SlashCmdList["TESTINSPECTHOOKS"]()
	elseif category == "loot" and SlashCmdList["TESTLOOTHOOKS"] then
		SlashCmdList["TESTLOOTHOOKS"]()
	elseif category == "mailbox" or category == "mail" and SlashCmdList["TESTMAILBOXHOOKS"] then
		SlashCmdList["TESTMAILBOXHOOKS"]()
	elseif category == "merchant" and SlashCmdList["TESTMERCANTHOOKS"] then
		SlashCmdList["TESTMERCANTHOOKS"]()
	elseif category == "profession" or category == "professions" and SlashCmdList["TESTPROFESSIONHOOKS"] then
		SlashCmdList["TESTPROFESSIONHOOKS"]()
	elseif category == "quest" or category == "quests" and SlashCmdList["TESTQUESTHOOKS"] then
		SlashCmdList["TESTQUESTHOOKS"]()
	else
		print("|cffff0000Unknown category or test not available:|r " .. tostring(category))
		print("|cffffaa00Available categories:|r trade, actionbar, auction, bag, character, inspect, loot, mailbox, merchant, profession, quest")
	end
end

-- Function to list all available hook tests
local function listAvailableHookTests()
	print("|cff00ff00=== AVAILABLE HOOK TESTS ===|r")
	
	local available = {}
	local unavailable = {}
	
	if SlashCmdList["TESTTRADEHOOKS"] then
		table.insert(available, "Trade (/testtradehooks)")
	else
		table.insert(unavailable, "Trade (TRADE_EVENT_TEST.lua not loaded)")
	end
	
	if SlashCmdList["TESTACTIONBARHOOKS"] then
		table.insert(available, "Actionbar (/testactionbarhooks)")
	else
		table.insert(unavailable, "Actionbar (ACTIONBAR_EVENT_TEST.lua not loaded)")
	end
	
	if SlashCmdList["TESTAUCTIONHOOKS"] then
		table.insert(available, "Auction House (/testauctionhooks)")
	else
		table.insert(unavailable, "Auction House (AUCTION_EVENT_TEST.lua not loaded)")
	end
	
	if SlashCmdList["TESTBAGHOOKS"] then
		table.insert(available, "Bag/Bank (/testbaghooks)")
	else
		table.insert(unavailable, "Bag/Bank (BAG_BANK_EVENT_TEST.lua not loaded)")
	end
	
	if SlashCmdList["TESTCHARACTERHOOKS"] then
		table.insert(available, "Character (/testcharacterhooks)")
	else
		table.insert(unavailable, "Character (CHARACTER_EVENT_TEST.lua not loaded)")
	end
	
	if SlashCmdList["TESTINSPECTHOOKS"] then
		table.insert(available, "Inspect (/testinspecthooks)")
	else
		table.insert(unavailable, "Inspect (INSPECT_EVENT_TEST.lua not loaded)")
	end
	
	if SlashCmdList["TESTLOOTHOOKS"] then
		table.insert(available, "Loot (/testloothooks)")
	else
		table.insert(unavailable, "Loot (LOOT_EVENT_TEST.lua not loaded)")
	end
	
	if SlashCmdList["TESTMAILBOXHOOKS"] then
		table.insert(available, "Mailbox (/testmailboxhooks)")
	else
		table.insert(unavailable, "Mailbox (MAILBOX_EVENT_TEST.lua not loaded)")
	end
	
	if SlashCmdList["TESTMERCANTHOOKS"] then
		table.insert(available, "Merchant (/testmercanthooks)")
	else
		table.insert(unavailable, "Merchant (MERCHANT_EVENT_TEST.lua not loaded)")
	end
	
	if SlashCmdList["TESTPROFESSIONHOOKS"] then
		table.insert(available, "Profession (/testprofessionhooks)")
	else
		table.insert(unavailable, "Profession (PROFESSIONS_EVENT_TEST.lua not loaded)")
	end
	
	if SlashCmdList["TESTQUESTHOOKS"] then
		table.insert(available, "Quest (/testquesthooks)")
	else
		table.insert(unavailable, "Quest (QUEST_EVENT_TEST.lua not loaded)")
	end
	
	print("|cff00ff00Available Tests:|r")
	for _, test in ipairs(available) do
		print("  |cff00ff00✓|r " .. test)
	end
	
	if #unavailable > 0 then
		print("")
		print("|cffff6600Unavailable Tests:|r")
		for _, test in ipairs(unavailable) do
			print("  |cffff0000✗|r " .. test)
		end
	end
	
	print("")
	print("|cffffaa00Use /testallhooks to run all available tests|r")
	print("|cffffaa00Use /testhooks <category> to test specific category|r")
end

-- Slash commands
SLASH_TESTALLHOOKS1 = "/testallhooks"
SlashCmdList["TESTALLHOOKS"] = runAllHookTests

SLASH_TESTHOOKS1 = "/testhooks"
SlashCmdList["TESTHOOKS"] = testSpecificHooks

SLASH_LISTHOOKTESTS1 = "/listhooktests"
SlashCmdList["LISTHOOKTESTS"] = listAvailableHookTests

print("|cff00ff00Master Hook Test ready!|r")
print("|cffffaa00Commands:|r")
print("  |cff00ff00/testallhooks|r - Run all available hook tests")
print("  |cff00ff00/testhooks <category>|r - Test specific category")
print("  |cff00ff00/listhooktests|r - List all available hook tests")
print("|cffffaa00Individual tests are also available (see /listhooktests)|r")