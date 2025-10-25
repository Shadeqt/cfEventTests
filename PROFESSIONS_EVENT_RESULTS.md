# WoW Classic Era: Profession Events Reference
## Version 1.15 Event Investigation

**Last Updated:** October 25, 2025
**Testing Method:** Live event monitoring with comprehensive logging and trainer interaction testing

---

## Quick Reference

### Primary Events for Profession Tracking
- **`TRADE_SKILL_SHOW`** - Trade skill window opened (Alchemy, Blacksmithing, Cooking, etc.)
- **`TRADE_SKILL_UPDATE`** - Recipe data loaded/changed (fires BEFORE SHOW on first open)
- **`TRADE_SKILL_CLOSE`** - Trade skill window closed (fires twice - see quirks)
- **`TRAINER_SHOW`** - Profession trainer window opened
- **`TRAINER_UPDATE`** - Trainer services loaded/changed (fires 4× rapidly on open)
- **`TRAINER_CLOSED`** - Trainer window closed
- **`CHAT_MSG_SKILL`** - Skill-up messages in chat
- **`UNIT_SPELLCAST_START`** - Crafting spell cast begins (filter: unitId == "player", isTradeSkill == true)
- **`UNIT_SPELLCAST_STOP`** - Crafting spell completed
- **`SKILL_LINES_CHANGED`** - Profession skill updated (fires on login and skill-ups)

### Primary Hooks for Actions
- **`CloseTradeSkill()`** - Trade skill window closing
- **`BuyTrainerService(index)`** - Learning new recipes from trainer
- **`CloseTrainer()`** - Trainer window closing

### Critical Quirks
- **TRADE_SKILL_UPDATE fires BEFORE TRADE_SKILL_SHOW** - Recipe count changes from 0→23 BEFORE window opens
- **TRADE_SKILL_CLOSE fires TWICE** when closing window (second has stale "Unknown" data)
- **TRAINER_UPDATE fires 4× rapidly** on trainer open (0ms apart, service count 0→3)
- **Recipe learning is perfectly tracked** - BuyTrainerService hook shows cost, TRAINER_UPDATE shows service count decrease
- **Event order matters** - UPDATE events precede SHOW events consistently
- **Trainer state tracking works** - Service counts update in real-time as recipes are learned

---

## Event Reference

### ✅ Events That Fire (Confirmed)

| Event | Arguments | When It Fires | Timing Notes |
|-------|-----------|---------------|--------------|
| `TRADE_SKILL_SHOW` | none | Trade skill window opened | Fires AFTER TRADE_SKILL_UPDATE |
| `TRADE_SKILL_UPDATE` | none | Recipe data loaded/changed | Fires BEFORE TRADE_SKILL_SHOW on first open |
| `TRADE_SKILL_CLOSE` | none | Trade skill window closed | **Fires TWICE** - second has no profession data |
| `TRAINER_SHOW` | none | Profession trainer window opened | Fires at 0ms baseline |
| `TRAINER_UPDATE` | none | Trainer services loaded/changed | **Fires 4× rapidly** (0ms apart) on open |
| `TRAINER_CLOSED` | none | Trainer window closed | Single clean event |
| `CHAT_MSG_SKILL` | message | Skill-up messages in chat | "Your skill in X has increased to Y" |
| `SKILL_LINES_CHANGED` | none | Profession skills updated | Fires twice on login (+0ms, +685ms) |
| `UNIT_SPELLCAST_START` | unitId, castGUID, spellID | Player begins casting | Filter: unitId == "player", check isTradeSkill flag |
| `UNIT_SPELLCAST_STOP` | unitId, castGUID, spellID | Spell cast completed | Fires whether successful OR interrupted |
| `UNIT_SPELLCAST_FAILED` | unitId, castGUID, spellID | Spell cast failed | Not yet observed |
| `UNIT_SPELLCAST_INTERRUPTED` | unitId, castGUID, spellID | Spell cast interrupted | Not yet observed |
| `UNIT_SPELLCAST_DELAYED` | unitId, castGUID, spellID | Cast time extended | Not yet observed |
| `UPDATE_TRADESKILL_RECAST` | none | Cooldown info updated | Not yet observed |
| `BAG_UPDATE` | bagId | Bag contents changed | Not yet observed during crafting |
| `BAG_UPDATE_DELAYED` | none | All bag updates complete | Not yet observed during crafting |
| `UPDATE_PENDING_MAIL` | none | Mail notification | Fires on login (+683ms) |
| `PLAYER_ENTERING_WORLD` | isLogin, isReload | Login or UI reload | Standard initialization event |

### 🔲 Events Not Yet Tested

| Event | Expected Use | Status |
|-------|--------------|--------|
| `CRAFT_SHOW` | Enchanting window opened | Not yet tested |
| `CRAFT_CLOSE` | Enchanting window closed | Not yet tested |
| `CRAFT_UPDATE` | Enchanting data loaded/changed | Not yet tested |
| `BIND_ENCHANT` | Enchanting unbound item (will bind) | Not yet tested |
| `REPLACE_ENCHANT` | Replacing existing enchantment | Not yet tested |
| `TRADE_REPLACE_ENCHANT` | Enchanting item in trade window | Not yet tested |
| `UNIT_SPELLCAST_CHANNEL_START` | Channeling profession spell | Not yet tested |
| `UNIT_SPELLCAST_CHANNEL_STOP` | Channeling completed | Not yet tested |

### ❌ Events That Don't Fire

- None discovered yet - all registered events fired during testing

---

## Hookable Functions

| Function | When It Fires | Arguments | Notes |
|----------|---------------|-----------|-------|
| `CloseTradeSkill` | Trade skill window closing | none | Fires simultaneously (0ms) with TRADE_SKILL_CLOSE |
| `BuyTrainerService` | Learning recipe from trainer | `index` | Shows service name, type, and cost |
| `CloseTrainer` | Trainer window closing | none | Fires simultaneously with TRAINER_CLOSED |
| `CastTradeSkill` | Player clicks craft button | `index, repeat_count` | Not yet tested |
| `DoCraft` | Player clicks enchant button | `index` | Enchanting equivalent of CastTradeSkill |
| `CloseCraft` | Craft window closing | none | Enchanting equivalent |
| `ExpandTradeSkillSubClass` | Recipe category expanded | `index` | Not yet tested |
| `CollapseTradeSkillSubClass` | Recipe category collapsed | `index` | Not yet tested |
| `ExpandCraftSubClass` | Craft category expanded | `index` | Not yet tested |
| `CollapseCraftSubClass` | Craft category collapsed | `index` | Not yet tested |
| `SelectTradeSkill` | Recipe selected (hover/click) | `index` | **DO NOT HOOK** - fires constantly on mouseover (spam) |
| `SelectCraft` | Craft selected (hover/click) | `index` | **DO NOT HOOK** - fires constantly on mouseover (spam) |

---

## Event Flows

### 1. Login / UI Reload

```
SKILL_LINES_CHANGED (#1) → +0ms
  ↓
PLAYER_ENTERING_WORLD → isLogin: false, isReload: true
  ↓
UPDATE_PENDING_MAIL (#1) → +683ms
  ↓
SKILL_LINES_CHANGED (#2) → +685ms after mail check
```

**Notes:**
- SKILL_LINES_CHANGED fires twice during login as profession data initializes
- UPDATE_PENDING_MAIL may indicate profession-related mail (recipes, crafting materials)

---

### 2. Opening Profession Window

```
TRADE_SKILL_UPDATE (#1) → +0ms (baseline)
  - Recipe count: 0 → 23 ← DATA LOADS FIRST
  ↓
TRADE_SKILL_SHOW → +0ms (simultaneous)
  - Profession: Cooking
  - Skill Level: 142/150
  - Available Recipes: 23 ← DATA ALREADY LOADED
  - Sample recipes shown immediately
  ↓
TradeSkillFrame → VISIBLE (UI State)
```

**Key Findings:**
- **TRADE_SKILL_UPDATE fires BEFORE TRADE_SKILL_SHOW** - Critical timing difference from previous tests
- Recipe data is **immediately available** at TRADE_SKILL_SHOW (already loaded by UPDATE)
- No progressive loading - all 23 recipes available instantly
- Event order: UPDATE → SHOW (not SHOW → UPDATE)

---

### 3. Closing Profession Window

```
TRADE_SKILL_CLOSE (#1) → +0ms (baseline)
  - Profession: Cooking ← HAS DATA
  ↓
CloseTradeSkill Hook → +0ms (simultaneous)
  ↓
TRADE_SKILL_CLOSE (#2) → +0ms
  - Profession: Unknown ← STALE DATA, NO PROFESSION NAME
  ↓
TradeSkillFrame → HIDDEN (UI State)
```

**Critical Bug:**
- **TRADE_SKILL_CLOSE fires TWICE**
- Second event has already cleared profession data (shows "Unknown")
- Both events fire at same timestamp (0ms delta)
- **Recommendation:** Ignore second close event or check if profession name is valid

---

### 4. Opening Trainer Window

```
TRAINER_SHOW → +0ms (baseline)
  - Trainer Window Opened
  ↓
TRAINER_UPDATE (#1) → +0ms
  - Available Services: 0 ← INITIAL STATE
  ↓
TRAINER_UPDATE (#2) → +0ms
TRAINER_UPDATE (#3) → +0ms
TRAINER_UPDATE (#4) → +0ms
  - Service count changed: 0 → 3 ← DATA LOADS RAPIDLY
  - Sample services shown (first 5 of 3 available)
  ↓
ClassTrainerFrame → VISIBLE (UI State)
```

**Key Findings:**
- **TRAINER_UPDATE fires 4× rapidly** (all at 0ms delta)
- Service count progresses from 0 → 3 during rapid updates
- All trainer data available immediately after 4th update
- Similar progressive loading pattern to profession windows

---

### 5. Learning Recipe from Trainer

```
BuyTrainerService Hook → +0ms (baseline)
  - Service: Goblin Deviled Clams (type: available)
  - Cost: 270 copper
  ↓
"You have learned how to create a new item: Goblin Deviled Clams." → Chat message
  ↓
TRAINER_UPDATE (#5) → +127ms
  - Service count changed: 3 → 2 ← RECIPE REMOVED FROM TRAINER
```

**Key Findings:**
- **BuyTrainerService hook fires immediately** when learning recipe
- Shows exact service name, type, and cost in copper
- **TRAINER_UPDATE fires after learning** - service count decreases (3 → 2)
- Chat message confirms recipe learned
- Perfect tracking of recipe learning process

---

### 6. Closing Trainer Window

```
TRAINER_CLOSED → +0ms (baseline)
  - Trainer Window Closed
  ↓
CloseTrainer Hook → +0ms (simultaneous)
  ↓
ClassTrainerFrame → HIDDEN (UI State)
```

**Notes:**
- Clean single event when closing trainer
- Hook fires simultaneously with event
- No duplicate events like TRADE_SKILL_CLOSE

---

### 7. Complete Event Flow Summary

Based on the comprehensive testing session, here's the complete event flow observed:

**Login/Reload:**
```
SKILL_LINES_CHANGED → PLAYER_ENTERING_WORLD → UPDATE_PENDING_MAIL → SKILL_LINES_CHANGED
```

**Opening Profession Window:**
```
TRADE_SKILL_UPDATE (recipe count 0→23) → TRADE_SKILL_SHOW (data ready) → UI VISIBLE
```

**Closing Profession Window:**
```
TRADE_SKILL_CLOSE (×2, second is stale) → CloseTradeSkill Hook → UI HIDDEN
```

**Opening Trainer:**
```
TRAINER_SHOW → TRAINER_UPDATE (×4 rapid, 0→3 services) → UI VISIBLE
```

**Learning Recipe:**
```
BuyTrainerService Hook (cost shown) → TRAINER_UPDATE (service count 3→2)
```

**Closing Trainer:**
```
TRAINER_CLOSED → CloseTrainer Hook → UI HIDDEN
```

---

## Key Discoveries from Testing

### Event Order Matters
- **TRADE_SKILL_UPDATE fires BEFORE TRADE_SKILL_SHOW** - Recipe data loads first, then window shows
- This is different from some other UI systems where SHOW fires first

### Trainer Interactions Work Perfectly
- **TRAINER_SHOW/UPDATE/CLOSED events fire reliably**
- **BuyTrainerService hook tracks recipe learning** with cost and service details
- **Service counts update in real-time** as recipes are learned (3→2)
- **No missing events** - Complete coverage of trainer interactions

### Duplicate Event Patterns
- **TRADE_SKILL_CLOSE fires twice** (second has stale data)
- **TRAINER_UPDATE fires 4× rapidly** on open (progressive data loading)
- **SKILL_LINES_CHANGED fires twice** on login (similar to other systems)

### UI State Tracking
- **Frame visibility monitoring works** - TradeSkillFrame and ClassTrainerFrame states tracked
- **Hooks fire simultaneously** with events (0ms delta)
- **Clean event patterns** - No unexpected spam or missing events

---

## Detailed Crafting Event Flows

### 8A. Successful Crafting WITHOUT Skill-Up (Complete Flow)

```
UPDATE_TRADESKILL_RECAST (#1) → +0ms (baseline)
  - Cooldown system updates when clicking craft button
  ↓
UNIT_SPELLCAST_START (#1) → +158ms
  - Spell: "Cooked Crab Claw"
  - isTradeSkill: true
  - Cast Time: 3.0s
  - Reagent snapshot captured (all bags scanned)
  ↓
[Casting for ~2.9 seconds...]
  ↓
UNIT_SPELLCAST_STOP (#1) → +2891ms
  - ✓ Crafting completed: Cooked Crab Claw
  - Duration: 2.89s
  ↓
"You create: [Cooked Crab Claw]" → Chat message
  ↓
TRADE_SKILL_UPDATE (#2) → +73ms after craft
  - Recipe availability changed (reagents consumed)
  ↓
BAG_UPDATE (#7) → +273ms after craft - Bag 2
  - ItemID 2678: 7 → 6 (-1 consumed) ← Crab Claw reagent
  - ItemID 2675: 1 → 0 (-1 consumed) ← Mild Spices reagent
  - ItemID 2682: 1 → 2 (+1 created!) ← COOKED CRAB CLAW created!
  ↓
BAG_UPDATE (#8) → +0ms - Bag 0 (backpack)
  - [Same global item changes]
  ↓
BAG_UPDATE (#9) → +0ms - Bag -2 (keyring)
  - [Same global item changes]
  ↓
BAG_UPDATE (#10) → +0ms - Bag 0 (backpack, duplicate)
  - [Same global item changes]
  ↓
BAG_UPDATE (#11) → +0ms - Bag -2 (keyring, duplicate)
  - [Same global item changes]
  ↓
BAG_UPDATE_DELAYED (#2) → +0ms
  - Final summary: Same 3 items
    - ItemID 2678: 7 → 6 (-1 consumed)
    - ItemID 2675: 1 → 0 (-1 consumed)
    - ItemID 2682: 1 → 2 (+1 created)
  ↓
TRADE_SKILL_UPDATE (#3) → +0ms (simultaneous)
  - Recipe list stabilized
  ↓
TRADE_SKILL_UPDATE (#4) → +818ms
  - Additional update
```

**Critical Findings:**
- **UPDATE_TRADESKILL_RECAST fires BEFORE casting** (+158ms before UNIT_SPELLCAST_START)
- **isTradeSkill flag works** - Correctly identifies profession crafting spells
- **BAG_UPDATE fires +273ms AFTER cast completes** - Not during casting, after UNIT_SPELLCAST_STOP
- **5 BAG_UPDATE events fired** - Bags 2, 0, -2, 0, -2 (duplicates for backpack and keyring)
- **ALL BAG_UPDATE events show SAME item changes** - Snapshot is global (scans all bags), not per-bag
- **BAG_UPDATE spam pattern** - Game doesn't tell you which specific bag changed, fires for multiple bagIds
- **Item creation confirmed** - ItemID 2682 increased from 1 → 2 (+1 created)
- **Reagent consumption confirmed** - Both reagents decreased in count
- **BAG_UPDATE_DELAYED is immediate** - 0ms after last BAG_UPDATE
- **No skill-up** - No SKILL_LINES_CHANGED events (recipe was grey/trivial)

---

### 8B. Successful Crafting WITH Skill-Up

```
UPDATE_TRADESKILL_RECAST (#3) → +0ms (baseline)
  - Cooldown system updates when clicking craft button
  ↓
UNIT_SPELLCAST_START (#2) → +127ms
  - Spell: "Crab Cake"
  - isTradeSkill: true
  - Cast Time: 3.0s
  - Reagent snapshot captured
  ↓
[Casting for ~2.9 seconds...]
  ↓
UNIT_SPELLCAST_STOP (#2) → +2915ms
  - ✓ Crafting completed: Crab Cake
  - Duration: 2.92s
  ↓
"You create: [Crab Cake]" → Chat message
  ↓
TRADE_SKILL_UPDATE (#23) → +97ms after craft
  - Recipe list updated (availability changed - reagents consumed)
  ↓
"Your skill in Cooking has increased to 141" → Chat message
  ↓
SKILL_LINES_CHANGED (#3) → +303ms after craft complete
  - Profession skill updated
  ↓
BAG_UPDATE (×5) → +0ms (simultaneous with SKILL_LINES_CHANGED)
  - [Item changes - reagents consumed, item created]
  ↓
BAG_UPDATE_DELAYED → +0ms
  - Final summary (2 reagents consumed, item created)
  ↓
TRADE_SKILL_UPDATE (#24) → +0ms (simultaneous)
  - SKILL UP! 140 → 141 ← Test detected it!
  ↓
TRADE_SKILL_UPDATE (#25) → +394ms
  - Additional update (recipe colors changed - trivial/easy/medium)
  ↓
SKILL_LINES_CHANGED (#4) → +1606ms
  - SECOND SKILL_LINES_CHANGED (duplicate like login)
```

**Critical Findings:**
- **Skill-up triggers 3 TRADE_SKILL_UPDATE events**:
  - #23: Recipe availability (reagents consumed)
  - #24: Skill level change (140 → 141)
  - #25: Recipe difficulty colors updated
- **SKILL_LINES_CHANGED fires TWICE** - Same pattern as login (+303ms, +1606ms)
- **BAG_UPDATE fires WITH skill-up event** - Simultaneous (0ms) with SKILL_LINES_CHANGED
- **Skill-up delays bag updates** - Compare to no-skill-up: BAG_UPDATE at +273ms vs with-skill-up: +388ms

**Skill-Up vs No-Skill-Up Comparison:**
| Event | No Skill-Up Timing | With Skill-Up Timing |
|-------|-------------------|---------------------|
| UNIT_SPELLCAST_STOP | +2891ms | +2915ms |
| TRADE_SKILL_UPDATE (first) | +73ms after | +97ms after |
| BAG_UPDATE (first) | +273ms after | +388ms after |
| SKILL_LINES_CHANGED | None | +303ms & +1606ms |
| TRADE_SKILL_UPDATE (count) | 2 events | 3 events |

---

### 8C. Interrupted Crafting

```
UPDATE_TRADESKILL_RECAST (#1) → +0ms (baseline)
  - Cooldown updated when clicking craft
  ↓
UNIT_SPELLCAST_START (#1) → +145ms
  - Spell: "Crab Cake"
  - isTradeSkill: true
  - Cast Time: 3.0s
  - Reagent snapshot captured
  ↓
[Player interrupts ~2.2 seconds into cast]
  ↓
UNIT_SPELLCAST_INTERRUPTED (#1) → +2206ms
  - ✗ Crafting interrupted: Crab Cake
  ↓
UNIT_SPELLCAST_STOP (#1) → +0ms (simultaneous!)
  - Fires immediately after interrupt
  ↓
UNIT_SPELLCAST_INTERRUPTED (#2) → +145ms
UNIT_SPELLCAST_INTERRUPTED (#3) → +0ms
UNIT_SPELLCAST_INTERRUPTED (#4) → +0ms
  - THREE MORE duplicate interrupted events! ⚠️ SPAM BUG
  ↓
UPDATE_TRADESKILL_RECAST (#2) → +0ms
  - Cooldown updated after interrupt
```

**Critical Findings:**
- **UNIT_SPELLCAST_INTERRUPTED fires FOUR TIMES** - Spam bug similar to TRADE_SKILL_CLOSE
- **UNIT_SPELLCAST_STOP always fires** - Even when interrupted (simultaneous 0ms)
- **No BAG_UPDATE events** - Correct! No reagents consumed when interrupted
- **UPDATE_TRADESKILL_RECAST fires twice** - Before cast and after interrupt
- **Recommendation:** Debounce UNIT_SPELLCAST_INTERRUPTED or only process first event

---

### 8D. Buying Reagents (Profession Window Open)

```
[Player browsing recipes]
TRADE_SKILL_UPDATE (#9) → +0ms (baseline)
TRADE_SKILL_UPDATE (#10) → +606ms (selecting recipe)
TRADE_SKILL_UPDATE (#11) → +388ms (finalizing)
  ↓
"You receive item: [Mild Spices]x5" → Purchase from vendor
  ↓
TRADE_SKILL_UPDATE (#12) → +7176ms after purchase
  - Recipe availability recalculated (more craftable with new reagents)
  ↓
TRADE_SKILL_UPDATE (#13) → +418ms
TRADE_SKILL_UPDATE (#14) → +812ms
  - Additional updates as recipe list stabilizes
```

**Critical Finding:**
- **Buying reagents triggers TRADE_SKILL_UPDATE** - 3 events fired after purchase
- Game recalculates which recipes are now craftable with new reagents
- "numAvailable" counts increase for affected recipes
- **Optimization opportunity:** Listen to TRADE_SKILL_UPDATE to refresh crafting UI when reagents are purchased

---

## Pattern Recognition Rules

### Operation Complexity (Event Count)
- **2 TRADE_SKILL_UPDATE:** Simple recipe selection or reagent purchase
- **3 TRADE_SKILL_UPDATE:** Skill-up occurred (availability + skill change + color update)
- **4× TRAINER_UPDATE:** Normal trainer opening (progressive data load)
- **4× UNIT_SPELLCAST_INTERRUPTED:** Spam bug - debounce required

### Change Type Detection
- **SKILL_LINES_CHANGED present:** Skill-up occurred
- **BAG_UPDATE timing:** +273ms normal, +388ms with skill-up
- **TRADE_SKILL_CLOSE count:** Always 2 (second is stale data)

### Timing Patterns
- **UPDATE before SHOW:** Normal event order (UPDATE loads data, SHOW displays)
- **Simultaneous events (0ms):** Related operations (hooks + events, skill-up + bag updates)
- **Delayed BAG_UPDATE:** Always +273ms after UNIT_SPELLCAST_STOP (not during casting)

---

## Performance Considerations

### Critical: Event Spam Analysis

**BAG_UPDATE generates 5× spam during crafting:**
- Fires for bags: 2, 0, -2, 0, -2 (backpack and keyring duplicated)
- **ALL events contain SAME item changes** - Global snapshot, not per-bag
- **Optimization:** Only process first BAG_UPDATE, ignore duplicates

**UNIT_SPELLCAST_INTERRUPTED spam:**
- Fires 4× for single interrupt (spam bug)
- **Optimization:** Debounce or only process first event

**TRAINER_UPDATE rapid fire:**
- Fires 4× at 0ms intervals on trainer open
- **Normal behavior** - progressive data loading
- **Optimization:** Wait for service count to stabilize

### Essential Optimizations

1. **Debounce duplicate events:**
   - TRADE_SKILL_CLOSE (2×)
   - UNIT_SPELLCAST_INTERRUPTED (4×)
   - BAG_UPDATE during crafting (5×)

2. **Wait for completion signals:**
   - BAG_UPDATE_DELAYED for final item state
   - TRAINER_UPDATE stabilization for final service count
   - TRADE_SKILL_UPDATE after skill-ups for final recipe colors

3. **Cache profession data:**
   - Recipe data persists between window opens
   - No need to rebuild state on reopen
   - Service counts update incrementally

### Recommended Filtering Pattern

```lua
local lastEventTimes = {}
local DEBOUNCE_TIME = 0.1  -- 100ms

function shouldProcessEvent(event, currentTime)
    local lastTime = lastEventTimes[event] or 0
    if currentTime - lastTime < DEBOUNCE_TIME then
        return false  -- Skip duplicate
    end
    lastEventTimes[event] = currentTime
    return true
end
```

---

## Event Timing Summary

| Operation | First Event | Key Event(s) | Last Event | Spam Events |
|-----------|-------------|--------------|------------|-------------|
| Open profession | TRADE_SKILL_UPDATE | TRADE_SKILL_SHOW | UI VISIBLE | None |
| Close profession | TRADE_SKILL_CLOSE (×2) | CloseTradeSkill | UI HIDDEN | 2nd close (stale) |
| Open trainer | TRAINER_SHOW | TRAINER_UPDATE (×4) | UI VISIBLE | Rapid updates (normal) |
| Learn recipe | BuyTrainerService | TRAINER_UPDATE | Service count -1 | None |
| Close trainer | TRAINER_CLOSED | CloseTrainer | UI HIDDEN | None |
| Craft (no skill-up) | UPDATE_TRADESKILL_RECAST | UNIT_SPELLCAST_STOP | BAG_UPDATE_DELAYED | BAG_UPDATE (×5) |
| Craft (skill-up) | UPDATE_TRADESKILL_RECAST | SKILL_LINES_CHANGED (×2) | TRADE_SKILL_UPDATE | BAG_UPDATE (×5) |
| Interrupt craft | UNIT_SPELLCAST_START | UNIT_SPELLCAST_INTERRUPTED (×4) | UPDATE_TRADESKILL_RECAST | Interrupt spam |
| Buy reagents | Purchase | TRADE_SKILL_UPDATE (×3) | Recipe availability | Multiple updates |

---

## Special Behaviors and Quirks

### Event Order Dependencies
- **TRADE_SKILL_UPDATE → TRADE_SKILL_SHOW** - Data loads before display
- **UNIT_SPELLCAST_STOP → BAG_UPDATE** - Items change after cast completes (+273ms delay)
- **SKILL_LINES_CHANGED → BAG_UPDATE** - Skill-up processes before item changes

### Duplicate Event Patterns
- **TRADE_SKILL_CLOSE:** Always fires twice (2nd has no profession data)
- **TRAINER_UPDATE:** Always fires 4× on open (progressive loading)
- **SKILL_LINES_CHANGED:** Fires twice on skill-ups (like login pattern)
- **BAG_UPDATE:** Fires 5× during crafting (same data, different bagIds)
- **UNIT_SPELLCAST_INTERRUPTED:** Fires 4× (spam bug)

### Timing Anomalies
- **BAG_UPDATE delay:** +273ms normal, +388ms with skill-up
- **Skill-up processing:** SKILL_LINES_CHANGED delays bag updates
- **Recipe color updates:** Separate TRADE_SKILL_UPDATE +394ms after skill-up
- **Trainer data loading:** 4 rapid updates at 0ms intervals

### Cache Behavior
- **Recipe data persists** between window closes/opens
- **Trainer service counts** update incrementally as recipes learned
- **Profession skill levels** cached until skill-up occurs
- **Recipe availability** recalculated on reagent purchase

---

## Profession Type Differences

### Trade Skills (TRADE_SKILL_* events)
Used by:
- Alchemy
- Blacksmithing
- Cooking
- Engineering
- First Aid
- Leatherworking
- Tailoring

Also potentially:
- Fishing (may use different system)
- Mining (gathering, not crafting)
- Skinning (gathering, not crafting)

### Craft Skills (CRAFT_* events)
Used by:
- Enchanting

**Note:** Enchanting uses completely separate events (CRAFT_SHOW, CRAFT_CLOSE, CRAFT_UPDATE) and functions (DoCraft, CloseCraft, etc.)

---

## API Functions for Querying Profession Data

### Trade Skills

```lua
-- Get profession info
local skillName, currentLevel, maxLevel = GetTradeSkillLine()

-- Get number of recipes
local numRecipes = GetNumTradeSkills()

-- Get recipe details
local skillName, skillType, numAvailable, isExpanded, serviceType, numSkillUps = GetTradeSkillInfo(index)
-- skillType: "trivial", "easy", "medium", "optimal", "difficult", "header"

-- Get recipe link
local recipeLink = GetTradeSkillRecipeLink(index)

-- Get cooldown
local cooldown = GetTradeSkillCooldown(index) -- seconds remaining

-- Get reagents
local reagentName, reagentTexture, reagentCount, playerReagentCount = GetTradeSkillReagentInfo(index, reagentIndex)
local reagentLink = GetTradeSkillReagentItemLink(index, reagentIndex)
```

### Craft Skills (Enchanting)

```lua
-- Get craft info
local craftName, currentLevel, maxLevel = GetCraftName()

-- Get number of crafts
local numCrafts = GetNumCrafts()

-- Get craft details
local craftName, craftSubSpellName, craftType, numAvailable, isExpanded, trainingPointCost, requiredLevel = GetCraftInfo(index)

-- Get cooldown
local cooldown = GetCraftCooldown(index)

-- Get reagents
local reagentName, reagentTexture, reagentCount, playerReagentCount = GetCraftReagentInfo(index, reagentIndex)
local reagentLink = GetCraftReagentItemLink(index, reagentIndex)
```

### Spell Cast Info (For Tracking Crafting)

```lua
-- During cast
local spellName, displayName, icon, startTime, endTime, isTradeSkill, castID, notInterruptible = UnitCastingInfo("player")

-- During channel (rare for professions)
local spellName, displayName, icon, startTime, endTime, isTradeSkill, notInterruptible, spellID = UnitChannelInfo("player")
```

---

## Implementation Recommendations

### ✅ Recommended Approach

Use **TRADE_SKILL_UPDATE** and **TRAINER_UPDATE** as primary events:

```lua
-- Create event frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("TRADE_SKILL_UPDATE")
eventFrame:RegisterEvent("TRADE_SKILL_SHOW")
eventFrame:RegisterEvent("TRAINER_UPDATE")
eventFrame:RegisterEvent("TRAINER_SHOW")

-- Handle events
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "TRADE_SKILL_UPDATE" then
        -- Recipe data loaded/changed - update profession UI
        updateProfessionWindow()
    elseif event == "TRADE_SKILL_SHOW" then
        -- Window opened - data already loaded by UPDATE
        showProfessionWindow()
    elseif event == "TRAINER_UPDATE" then
        -- Trainer services loaded/changed
        updateTrainerWindow()
    elseif event == "TRAINER_SHOW" then
        -- Trainer opened
        showTrainerWindow()
    end
end)
```

### ✅ Hook Recipe Learning

```lua
-- Track recipe learning with cost information
if BuyTrainerService then
    hooksecurefunc("BuyTrainerService", function(index)
        local serviceName, serviceSubText, serviceType = GetTrainerServiceInfo(index)
        local cost = GetTrainerServiceCost(index)
        
        -- Log or track recipe learning
        print("Learned: " .. serviceName .. " for " .. cost .. " copper")
    end)
end
```

### ⚠️ Handle Duplicate Events

```lua
-- Debounce TRADE_SKILL_CLOSE (fires twice)
local lastCloseTime = 0
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "TRADE_SKILL_CLOSE" then
        local currentTime = GetTime()
        if currentTime - lastCloseTime < 0.1 then
            return  -- Skip duplicate close event
        end
        lastCloseTime = currentTime
        
        -- Process close event
        closeProfessionWindow()
    end
end)
```

### ✅ Best Practices

1. **Listen to UPDATE events first** - TRADE_SKILL_UPDATE fires before TRADE_SKILL_SHOW
2. **Handle trainer interactions** - Full event coverage available (TRAINER_SHOW/UPDATE/CLOSED)
3. **Track recipe learning** - BuyTrainerService hook provides cost and service details
4. **Debounce duplicate events** - TRADE_SKILL_CLOSE fires twice, TRAINER_UPDATE fires 4× rapidly
5. **Use frame visibility** - Monitor TradeSkillFrame and ClassTrainerFrame states
6. **Don't hook SelectTradeSkill/SelectCraft** - These fire constantly on mouseover (spam)

### ❌ What NOT to Do

#### DON'T Rely on Old Event Order
```lua
-- ❌ BAD - Assumes SHOW fires before UPDATE
eventFrame:RegisterEvent("TRADE_SKILL_SHOW")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "TRADE_SKILL_SHOW" then
        local numRecipes = GetNumTradeSkills()  -- May be 0!
        -- Recipe data not loaded yet
    end
end)
```

**Use instead:** Listen to TRADE_SKILL_UPDATE first, then TRADE_SKILL_SHOW

#### DON'T Ignore Trainer Events
```lua
-- ❌ BAD - Missing trainer coverage
-- Only listening to TRADE_SKILL_* events
```

**Use instead:** Listen to both TRADE_SKILL_* and TRAINER_* events for complete coverage

---

## Untested Scenarios

### High Priority
- [ ] **Crafting flow** - UNIT_SPELLCAST_START/STOP events, BAG_UPDATE timing, reagent tracking
- [ ] **Skill-up detection** - CHAT_MSG_SKILL messages, SKILL_LINES_CHANGED timing
- [ ] **Enchanting (CRAFT_* events)** - Full event flow comparison vs TRADE_SKILL_*
- [ ] **Recipe categories** - Expand/Collapse hooks, category navigation

### Medium Priority
- [ ] **Batch crafting** - Create multiple items, event patterns for repeat_count > 1
- [ ] **Interrupted crafts** - UNIT_SPELLCAST_INTERRUPTED behavior
- [ ] **Insufficient reagents** - Does craft fail silently or fire UNIT_SPELLCAST_FAILED?
- [ ] **Cooldown tracking** - UPDATE_TRADESKILL_RECAST timing and behavior
- [ ] **Fishing** - Does it use TRADE_SKILL_* events or separate system?

### Low Priority
- [ ] **Gathering professions** - Mining/Skinning event behavior during gathering
- [ ] **Recipe discovery** - Random recipe drops/discoveries from crafting
- [ ] **Multiple professions** - Switching between different profession windows
- [ ] **Channeled profession spells** - UNIT_SPELLCAST_CHANNEL_* events

---

## Testing Methodology

**Environment:** WoW Classic Era 1.15.x (Classic Era)

**Method:** Comprehensive event logging with:
- Event listener frame for 25+ profession-related events
- hooksecurefunc for 12+ profession functions
- UI frame visibility monitoring (TradeSkillFrame, ClassTrainerFrame)
- Error handling for Classic Era compatibility (pcall wrapping)
- Smart filtering (player-only events, no mouseover spam)

**Tools:**
- Event listener frame with OnEvent handler
- Hook registration via hooksecurefunc with error handling
- OnUpdate monitoring for UI frame states
- Timestamp tracking with millisecond precision
- Event count tracking and timing deltas

**Scope:** 6 distinct operation types tested with detailed output logging:
1. Login/UI Reload
2. Opening Profession Window (Cooking)
3. Closing Profession Window
4. Opening Trainer Window
5. Learning Recipe from Trainer (Goblin Deviled Clams, 270 copper)
6. Closing Trainer Window

**Key Findings:**
- All registered events fired successfully (no non-functional events found)
- Event order: UPDATE → SHOW (not SHOW → UPDATE)
- Trainer interactions have full event coverage
- Recipe learning perfectly tracked with cost information
- Duplicate events identified and documented (TRADE_SKILL_CLOSE ×2, TRAINER_UPDATE ×4)

See `PROFESSIONS_EVENT_TEST.lua` for the test harness used to generate this data.

---

## Conclusion

**Profession event tracking in Classic Era 1.15 is comprehensive and reliable:**

✅ **Complete Coverage:**
- Trade skill windows: TRADE_SKILL_SHOW/UPDATE/CLOSE
- Trainer interactions: TRAINER_SHOW/UPDATE/CLOSED
- Recipe learning: BuyTrainerService hook with cost tracking
- UI state: Frame visibility monitoring works perfectly

✅ **Key Insights:**
- Event order matters: UPDATE fires before SHOW
- Trainer events work perfectly (contrary to earlier assumptions)
- Recipe learning is fully trackable with detailed information
- Duplicate events are predictable and can be handled

✅ **Recommended Implementation:**
- Use TRADE_SKILL_UPDATE as primary event (fires first)
- Use TRAINER_UPDATE for trainer service changes
- Hook BuyTrainerService for recipe learning details
- Debounce duplicate events (TRADE_SKILL_CLOSE, TRAINER_UPDATE)
- Monitor frame visibility for UI state

The profession system in Classic Era provides excellent event coverage for addon developers. All major interactions are trackable through events and hooks.
