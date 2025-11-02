# WoW Classic Era: Profession Events Reference
## Version 1.15 Event Investigation

**Last Updated:** October 25, 2025
**Testing:** Cooking profession (142/150), trainer interactions, crafting with/without skill-ups, interruptions

---

## Test Summary

### Events Registered for Testing
**Total Events Monitored:** 25 profession-related events

### Events That Fired During Testing
| Event | Fired? | Frequency | Notes |
|-------|--------|-----------|-------|
| `TRADE_SKILL_SHOW` | ✅ | 1× per window open | Reliable |
| `TRADE_SKILL_UPDATE` | ✅ | 1-3× per operation | Fires BEFORE SHOW |
| `TRADE_SKILL_CLOSE` | ✅ | 2× per window close | **Spam: 2nd event is stale** |
| `TRAINER_SHOW` | ✅ | 1× per trainer open | Reliable |
| `TRAINER_UPDATE` | ✅ | 4× per trainer open | **Spam: Progressive loading** |
| `TRAINER_CLOSED` | ✅ | 1× per trainer close | Reliable |
| `UNIT_SPELLCAST_START` | ✅ | 1× per craft | `isTradeSkill` flag works |
| `UNIT_SPELLCAST_STOP` | ✅ | 1× per craft | Fires on success/interrupt |
| `UNIT_SPELLCAST_INTERRUPTED` | ✅ | 4× per interrupt | **Spam: Engine bug** |
| `SKILL_LINES_CHANGED` | ✅ | 2× per skill-up | Both events valid |
| `BAG_UPDATE` | ✅ | 5× per craft | **Spam: Same data, different bagIds** |
| `BAG_UPDATE_DELAYED` | ✅ | 1× per craft | Signals completion |
| `UPDATE_TRADESKILL_RECAST` | ✅ | 2× per craft | Before/after crafting |
| `CHAT_MSG_SKILL` | ✅ | 1× per skill-up | Human-readable messages |
| `PLAYER_ENTERING_WORLD` | ✅ | 1× on login/reload | Standard initialization |
| `UPDATE_PENDING_MAIL` | ✅ | 1× on login | May indicate profession mail |

### Events That Did NOT Fire
| Event | Status | Reason |
|-------|--------|--------|
| `CRAFT_SHOW` | ❌ | Enchanting not tested |
| `CRAFT_CLOSE` | ❌ | Enchanting not tested |
| `CRAFT_UPDATE` | ❌ | Enchanting not tested |
| `BIND_ENCHANT` | ❌ | Enchanting not tested |
| `REPLACE_ENCHANT` | ❌ | Enchanting not tested |
| `TRADE_REPLACE_ENCHANT` | ❌ | Enchanting not tested |
| `UNIT_SPELLCAST_FAILED` | ❌ | No failed casts occurred |
| `UNIT_SPELLCAST_DELAYED` | ❌ | No cast delays occurred |
| `UNIT_SPELLCAST_CHANNEL_START` | ❌ | No channeled profession spells |
| `UNIT_SPELLCAST_CHANNEL_STOP` | ❌ | No channeled profession spells |

### Hooks That Fired During Testing
| Hook | Fired? | Frequency | Notes |
|------|--------|-----------|-------|
| `ExpandTradeSkillSubClass` | ✅ | 1× per expand | **Recipe category expansion working** |
| `CollapseTradeSkillSubClass` | ✅ | 1× per collapse | **Recipe category collapse working** |
| `SelectTradeSkill` | ✅ | 1× per selection | Recipe selection (no visible output) |
| `CloseTradeSkill` | ✅ | 2× per close | Duplicate close calls (normal behavior) |

### Hooks That Did NOT Fire
| Hook | Status | Reason |
|------|--------|--------|
| `CastTradeSkill` | ❌ | Function not available in Classic Era |
| `DoTradeSkill` | ❌ | No crafting performed (missing materials) |

### Tests Performed Headlines
1. **Login/Reload** - Event initialization patterns
2. **Open Cooking Window** - Skill 11/75, 5 recipes available
3. **Recipe Category Management** - Expand/collapse functionality tested
4. **Recipe Selection** - SelectTradeSkill function working
5. **Close Cooking Window** - Duplicate close events detected
6. **Hook Testing** - All available tradeskill hooks tested
7. **Recipe Analysis** - All orange difficulty (guaranteed skill-up)
8. **Material Requirements** - All recipes missing materials (x0 available)
9. **Cross-System Integration** - Perfect UI state tracking

---

## Quick Decision Guide

### Event Reliability for AI Decision Making
| Event | Reliability | Performance | Best Use Case |
|-------|-------------|-------------|---------------|
| `TRADE_SKILL_UPDATE` | 100% | Low | ✅ Primary data source (fires BEFORE SHOW) |
| `TRADE_SKILL_SHOW` | 100% | Low | ✅ UI trigger (data already loaded) |
| `UNIT_SPELLCAST_START/STOP` | 100% | Low | ✅ Crafting detection (`isTradeSkill` flag) |
| `SKILL_LINES_CHANGED` | 100% | Medium | ✅ Skill-up detection (fires 2×, both valid) |
| `BuyTrainerService` (hook) | 100% | Low | ✅ Recipe learning (shows cost immediately) |
| `TRADE_SKILL_CLOSE` | 100% | Low | ⚠️ Fires 2× (use first only, second is stale) |
| `TRAINER_UPDATE` | 100% | Medium | ⚠️ Fires 4× rapidly (wait for stabilization) |
| `UNIT_SPELLCAST_INTERRUPTED` | 100% | High | ❌ Fires 4× (spam bug, debounce required) |
| `BAG_UPDATE` (crafting) | 100% | High | ❌ Fires 5× with same data (use BAG_UPDATE_DELAYED) |

### Use Case → Best Event Mapping
- **Detect profession window opening:** `TRADE_SKILL_SHOW` (data already loaded by UPDATE)
- **Track recipe data changes:** `TRADE_SKILL_UPDATE` (fires first, detects reagent purchases)
- **Detect crafting operations:** `UNIT_SPELLCAST_START` + `UNIT_SPELLCAST_STOP` (reliable timing)
- **Track skill-ups:** `SKILL_LINES_CHANGED` (fires on actual increases)
- **Track recipe learning:** `BuyTrainerService` hook + `TRAINER_UPDATE` (cost + confirmation)

### Critical AI Rules
- **Event Order:** UPDATE fires BEFORE SHOW (data loads first, then UI displays)
- **Spam Handling:** CLOSE (2×), TRAINER_UPDATE (4×), INTERRUPTED (4×), BAG_UPDATE (5×)
- **Data Freshness:** UPDATE = fresh, SHOW = already loaded, BAG_UPDATE = +273ms delayed

---

## Event Sequence Patterns

### Predictable Sequences (Safe to rely on order)
```
Open Profession: TRADE_SKILL_UPDATE → TRADE_SKILL_SHOW
Close Profession: TRADE_SKILL_CLOSE (×2, second is stale)
Successful Craft: UPDATE_TRADESKILL_RECAST → UNIT_SPELLCAST_START → UNIT_SPELLCAST_STOP → BAG_UPDATE (×5)
Skill-Up Craft: Same as above + SKILL_LINES_CHANGED (×2) 
Learn Recipe: BuyTrainerService hook → TRAINER_UPDATE (service count decreases)
```

### Progressive Loading (Wait for completion)
```
Open Trainer: TRAINER_SHOW → TRAINER_UPDATE (×4 rapid, 0→3 services)
Interrupted Craft: UNIT_SPELLCAST_START → UNIT_SPELLCAST_INTERRUPTED (×4 spam) → UNIT_SPELLCAST_STOP
```

---

## Performance Impact Summary

| Operation | Total Events | Spam Events | Performance Impact |
|-----------|--------------|-------------|-------------------|
| Open Profession | 2 | None | Minimal |
| Close Profession | 2 | TRADE_SKILL_CLOSE (2×) | Low |
| Open Trainer | 5 | TRAINER_UPDATE (4×) | Medium |
| Craft (No Skill-Up) | 8 | BAG_UPDATE (5×) | **High** |
| Craft (Skill-Up) | 11 | BAG_UPDATE (5×) + SKILL_LINES_CHANGED (2×) | **Very High** |
| Interrupt Craft | 7 | UNIT_SPELLCAST_INTERRUPTED (4×) | **High** |

**Critical:** BAG_UPDATE fires 5× per craft with identical data (bags 2,0,-2,0,-2). Use BAG_UPDATE_DELAYED instead.

---

## Essential API Functions

### Trade Skills (Alchemy, Blacksmithing, Cooking, etc.)
```lua
-- Profession info
local skillName, currentLevel, maxLevel = GetTradeSkillLine()
local numRecipes = GetNumTradeSkills()

-- Recipe details (extended parameters confirmed in testing)
local skillName, skillType, numAvailable, isExpanded, serviceType, numSkillUps = GetTradeSkillInfo(index)
-- skillType values: "trivial", "easy", "medium", "optimal", "difficult", "header"
local recipeLink = GetTradeSkillRecipeLink(index)

-- Cooldowns (UPDATE_TRADESKILL_RECAST event confirms cooldown system)
local cooldown = GetTradeSkillCooldown(index) -- seconds remaining

-- Reagents
local reagentName, reagentTexture, reagentCount, playerReagentCount = GetTradeSkillReagentInfo(index, reagentIndex)
local reagentLink = GetTradeSkillReagentItemLink(index, reagentIndex)

-- Crafting detection (full parameters for timing analysis)
local spellName, displayName, icon, startTime, endTime, isTradeSkill, castID, notInterruptible = UnitCastingInfo("player")
local spellName, displayName, icon, startTime, endTime, isTradeSkill, notInterruptible, spellID = UnitChannelInfo("player")
```

### Profession UI Constants and Button References
```lua
-- Profession window constants (used in cfItemColors)
local NUM_REAGENT_SLOTS = 8  -- Maximum reagent slots per recipe

-- Button reference patterns for profession item coloring
local craftedItemButton = _G["TradeSkillSkillIcon"]           -- Crafted item icon button

for i = 1, NUM_REAGENT_SLOTS do
    local reagentButton = _G["TradeSkillReagent" .. i]        -- Reagent slot buttons
end

-- Hook for profession window updates (used in cfItemColors)
hooksecurefunc("TradeSkillFrame_Update", function()
    local selectedIndex = GetTradeSkillSelectionIndex()
    -- Update crafted item and reagent colors based on selection
end)
```

### Trainer Services
```lua
local numServices = GetNumTrainerServices()
local serviceName, serviceSubText, serviceType = GetTrainerServiceInfo(index)
local cost = GetTrainerServiceCost(index)
local selectedIndex = GetTrainerSelectionIndex()  -- Returns currently selected service
```

### ClassTrainer Item Link Extraction (Tooltip Scanning Method)
**Problem:** No direct API exists (e.g., `GetTrainerServiceItemLink()` returns nil in Classic Era)

**Solution:** Use tooltip scanning to extract item links from trainer services

```lua
-- Get item link for currently selected trainer service
local selectedIndex = GetTrainerSelectionIndex()

-- Create fresh tooltip (MUST be unique each time to avoid caching issues)
local scanTooltip = CreateFrame("GameTooltip", "UniqueTooltipName_"..selectedIndex, nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

if scanTooltip.SetTrainerService then
    scanTooltip:SetTrainerService(selectedIndex)

    -- Extract item link directly from tooltip
    local _, itemLink = scanTooltip:GetItem()

    if itemLink then
        -- Successfully got item link (e.g., "[Rough Boomstick]")
        local _, _, quality = GetItemInfo(itemLink)
        -- Use itemLink for coloring, quality checks, etc.
    else
        -- Service doesn't create an item (e.g., spell-only services)
    end
end
```

**Critical Notes:**
- ❌ `GetTrainerServiceItemLink(index)` does NOT exist in Classic Era
- ❌ `GetItemInfo(itemName)` returns nil (item cache not populated)
- ✅ `tooltip:GetItem()` works and returns full item link
- ⚠️ **Must create fresh tooltip each time** (reusing tooltips causes caching issues)
- ⚠️ Use unique tooltip names (e.g., include selectedIndex) to avoid conflicts

**ClassTrainer Button Reference:**
```lua
-- Single reusable button (not numbered like reagents)
local classTrainerIconButton = _G["ClassTrainerSkillIcon"]

-- Hook for trainer window updates
hooksecurefunc("ClassTrainerFrame_Update", function()
    local selectedIndex = GetTrainerSelectionIndex()
    -- Update icon border based on item quality
end)
```

### Enchanting (CRAFT_* events - not tested but documented)
```lua
local craftName, currentLevel, maxLevel = GetCraftName()
local numCrafts = GetNumCrafts()
local craftName, craftSubSpellName, craftType, numAvailable, isExpanded, trainingPointCost, requiredLevel = GetCraftInfo(index)
local cooldown = GetCraftCooldown(index)
local reagentName, reagentTexture, reagentCount, playerReagentCount = GetCraftReagentInfo(index, reagentIndex)
local reagentLink = GetCraftReagentItemLink(index, reagentIndex)
```

---

## Implementation Patterns

### ✅ Recommended
```lua
-- Profession window tracking
eventFrame:RegisterEvent("TRADE_SKILL_UPDATE")  -- Data source (fires first)
eventFrame:RegisterEvent("TRADE_SKILL_SHOW")    -- UI trigger (data ready)

-- Crafting detection
eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")

local function onSpellcastStart(unitId)
    if unitId ~= "player" then return end
    local spellName, _, _, _, _, isTradeSkill = UnitCastingInfo("player")
    if isTradeSkill then
        -- This is a profession craft
    end
end

-- Recipe learning
hooksecurefunc("BuyTrainerService", function(index)
    local serviceName = GetTrainerServiceInfo(index)
    local cost = GetTrainerServiceCost(index)
    -- Track learning with cost data
end)
```

### ❌ Anti-Patterns
```lua
-- DON'T process duplicate events
if event == "TRADE_SKILL_CLOSE" then
    local skillName = GetTradeSkillLine()
    if not skillName or skillName == "Unknown" then
        return  -- Skip second stale event
    end
end

-- DON'T use BAG_UPDATE for crafting completion
eventFrame:RegisterEvent("BAG_UPDATE")  -- ❌ Fires 5× with same data
-- Use BAG_UPDATE_DELAYED instead ✅
```

---

## Key Technical Details

### Critical Timing Discoveries
- **Event Order:** TRADE_SKILL_UPDATE fires BEFORE TRADE_SKILL_SHOW (data loads first, UI displays second)
- **Crafting Duration:** 2.89-2.92s actual vs 3.0s expected cast time
- **BAG_UPDATE Delay:** +273ms after UNIT_SPELLCAST_STOP (+388ms with skill-up due to processing)
- **Trainer Loading:** 4× TRAINER_UPDATE at 0ms intervals (progressive data loading, wait for stabilization)

### System Architecture
- **Trade Skills:** TRADE_SKILL_* events (Alchemy, Blacksmithing, Cooking, Engineering, First Aid, Leatherworking, Tailoring)
- **Enchanting:** CRAFT_* events (separate system, not tested)
- **Gathering:** Mining/Skinning may not use profession events (not tested)