# WoW Classic Era: Profession Events Reference
## Version 1.12 Event Investigation

**Last Updated:** October 25, 2025
**Testing Method:** Live event monitoring with comprehensive logging

---

## Quick Reference

### Primary Events for Profession Tracking
- **`TRADE_SKILL_SHOW`** - Trade skill window opened (Alchemy, Blacksmithing, Cooking, etc.)
- **`TRADE_SKILL_UPDATE`** - Recipe data loaded/changed (fires multiple times)
- **`TRADE_SKILL_CLOSE`** - Trade skill window closed (fires twice - see quirks)
- **`CRAFT_SHOW`** - Craft window opened (Enchanting)
- **`CRAFT_UPDATE`** - Craft data loaded/changed
- **`UNIT_SPELLCAST_START`** - Crafting spell cast begins (filter: unitId == "player", isTradeSkill == true)
- **`UNIT_SPELLCAST_STOP`** - Crafting spell completed
- **`BAG_UPDATE`** - Item changes during crafting (+273ms after cast completes)
- **`BAG_UPDATE_DELAYED`** - All bag updates completed (final item snapshot)
- **`SKILL_LINES_CHANGED`** - Profession skill updated (fires on login and skill-ups)

### Primary Hooks for Crafting Actions
- **`CastTradeSkill(index, repeat_count)`** - Player initiates crafting
- **`DoCraft(index)`** - Player initiates enchanting craft
- **`CloseTradeSkill()`** - Trade skill window closing
- **`CloseCraft()`** - Craft window closing

### Critical Quirks
- **TRADE_SKILL_CLOSE fires TWICE** when closing window (second has stale "Unknown" data)
- **UNIT_SPELLCAST_INTERRUPTED fires FOUR TIMES** when interrupting crafts (spam bug - debounce it)
- **BAG_UPDATE fires 5 TIMES** with same item changes (bags 2, 0, -2, 0, -2) - snapshot is global, not per-bag
- **BAG_UPDATE fires AFTER cast completes** - +273ms delay, not during casting (wait for it!)
- **Recipe data loads progressively**: First TRADE_SKILL_SHOW reports 0 recipes, then TRADE_SKILL_UPDATE populates them
- **Cached data on reopen**: Reopening profession shows all recipes immediately in TRADE_SKILL_SHOW
- **Out-of-order updates**: TRADE_SKILL_UPDATE can fire AFTER close but BEFORE reopen (~2 seconds delay)
- **Recipe selection triggers update**: TRADE_SKILL_UPDATE fires when selecting different recipes
- **Buying reagents triggers update**: TRADE_SKILL_UPDATE fires when purchasing crafting materials (recalculates availability)
- **Skill-ups trigger 2x SKILL_LINES_CHANGED**: Both fire within ~2 seconds, similar to login behavior
- **Skill-ups delay BAG_UPDATE**: +388ms with skill-up vs +273ms without (SKILL_LINES_CHANGED processes first)
- **Trainer interactions fire NO EVENTS** - Talking to profession trainers generates zero events
- **UPDATE_TRADESKILL_RECAST fires BEFORE casting** - Cooldown system updates when clicking craft button
- **CastTradeSkill hook missing** - May not exist in Classic Era, use UNIT_SPELLCAST_START instead

---

## Event Reference

### ✅ Events That Fire (Confirmed)

| Event | Arguments | When It Fires | Timing Notes |
|-------|-----------|---------------|--------------|
| `TRADE_SKILL_SHOW` | none | Trade skill window opened | Fires at 0ms baseline |
| `TRADE_SKILL_UPDATE` | none | Recipe data loaded/changed | First: +0ms (loads recipes), Second: +16ms (finalizes), Also fires on recipe selection |
| `TRADE_SKILL_CLOSE` | none | Trade skill window closed | **Fires TWICE** - second has no profession data |
| `SKILL_LINES_CHANGED` | none | Profession skills updated | Fires twice on login (+0ms, +693ms), also on skill-ups |
| `UNIT_SPELLCAST_START` | unitId, castGUID, spellID | Player begins casting | Filter: unitId == "player", check isTradeSkill flag. Fires +127ms after UPDATE_TRADESKILL_RECAST |
| `UNIT_SPELLCAST_STOP` | unitId, castGUID, spellID | Spell cast completed | Fires whether successful OR interrupted (0ms with interrupt) |
| `UNIT_SPELLCAST_FAILED` | unitId, castGUID, spellID | Spell cast failed | Not yet observed - may need insufficient reagents test |
| `UNIT_SPELLCAST_INTERRUPTED` | unitId, castGUID, spellID | Spell cast interrupted | **Fires FOUR TIMES** - spam bug, debounce it! |
| `UNIT_SPELLCAST_DELAYED` | unitId, castGUID, spellID | Cast time extended | Not yet observed |
| `UPDATE_TRADESKILL_RECAST` | none | Cooldown info updated | Fires BEFORE casting starts and AFTER interrupt/completion |
| `BAG_UPDATE` | bagId | Bag contents changed | Fires +273ms AFTER cast completes (not during). Fires 5x with same global item changes. Bags: 2, 0, -2, 0, -2 |
| `BAG_UPDATE_DELAYED` | none | All bag updates complete | Immediate (0ms) after last BAG_UPDATE. Contains final item snapshot. |
| `UPDATE_PENDING_MAIL` | none | Mail notification | Fires on login (+671ms), may indicate profession-related mail |
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
| `BAG_UPDATE` (during craft) | Bag changes during crafting | Filter was too aggressive - awaiting retest with fixed code |

### ❌ Events That Don't Fire

- **Profession Trainer Interactions** - Opening trainer window, viewing recipes, learning recipes: **NO EVENTS**
- *(More to be discovered during testing)*

---

## Hookable Functions

| Function | When It Fires | Arguments | Notes |
|----------|---------------|-----------|-------|
| `CastTradeSkill` | Player clicks craft button | `index, repeat_count` | Fires before UNIT_SPELLCAST_START |
| `DoCraft` | Player clicks enchant button | `index` | Enchanting equivalent of CastTradeSkill |
| `CloseTradeSkill` | Trade skill window closing | none | Fires simultaneously (0ms) with TRADE_SKILL_CLOSE |
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
UPDATE_PENDING_MAIL (#1) → +671ms
  ↓
SKILL_LINES_CHANGED (#2) → +693ms after mail check
```

**Notes:**
- SKILL_LINES_CHANGED fires twice during login as profession data initializes
- UPDATE_PENDING_MAIL may indicate profession-related mail (recipes, crafting materials)

---

### 2. First Time Opening Profession Window

```
TRADE_SKILL_SHOW → +0ms (baseline)
  - Profession: Cooking
  - Skill Level: 140/150
  - Available Recipes: 0 ← STALE DATA
  ↓
TradeSkillFrame → VISIBLE (UI State)
  ↓
TRADE_SKILL_UPDATE (#1) → +0ms
  - Recipe count: 0 → 23 ← DATA LOADS
  ↓
TRADE_SKILL_UPDATE (#2) → +16ms
  - Recipe count: 23 (stable) ← FINALIZED
```

**Key Findings:**
- Recipe data is **NOT available** at TRADE_SKILL_SHOW
- Takes **2 TRADE_SKILL_UPDATE events** to fully load recipes
- First update loads data (0 → 23 recipes)
- Second update finalizes list (+16ms later)

---

### 3. Selecting Different Recipes

```
[Player browses recipes for ~5 seconds]
  ↓
TRADE_SKILL_UPDATE (#3) → +4933ms after opening
  - Fired when player selects different recipe
```

**Notes:**
- Each recipe selection triggers TRADE_SKILL_UPDATE
- Good for tracking what player is viewing
- Timing varies based on user interaction speed

---

### 4. Closing Profession Window

```
TRADE_SKILL_CLOSE (#1) → +0ms (baseline)
  - Profession: Cooking ← HAS DATA
  ↓
CloseTradeSkill Hook → +0ms (simultaneous)
  ↓
TRADE_SKILL_CLOSE (#2) → +0ms
  - Profession: Unknown ← STALE DATA, NO PROFESSION NAME
  ↓
TradeSkillFrame → HIDDEN (UI State) → +0ms
```

**Critical Bug:**
- **TRADE_SKILL_CLOSE fires TWICE**
- Second event has already cleared profession data (shows "Unknown")
- Both events fire at same timestamp (0ms delta)
- **Recommendation:** Ignore second close event or check if profession name is valid

---

### 5. Closing and Immediately Reopening (Cached Data)

```
TRADE_SKILL_CLOSE (#3) → +0ms
  - Profession: Cooking
  ↓
CloseTradeSkill Hook → +0ms
  ↓
TRADE_SKILL_CLOSE (#4) → +0ms
  - Profession: Unknown ← STALE
  ↓
TradeSkillFrame → HIDDEN → +0ms
  ↓
TRADE_SKILL_UPDATE (#7) → +1933ms ← OUT OF ORDER!
  - Recipe count: 0 → 23
  - **Fires AFTER close but BEFORE reopen!**
  ↓
TRADE_SKILL_SHOW (#4) → +1933ms
  - Profession: Cooking
  - Skill Level: 140/150
  - Available Recipes: 23 ← IMMEDIATE DATA (cached)
  - Sample recipes shown immediately
  ↓
TradeSkillFrame → VISIBLE → +0ms
```

**Critical Findings:**
- **Recipe data persists** between close/reopen (cached in memory)
- Reopening shows **all 23 recipes immediately** in TRADE_SKILL_SHOW (no progressive load)
- **TRADE_SKILL_UPDATE fires out-of-order** (~2 seconds after close, before new open)
- **Optimization tip:** Cache profession data between opens, no need to rebuild state

---

### 6. Talking to Profession Trainer

```
[Player interacts with profession trainer]
  ↓
❌ NO EVENTS FIRE
```

**Critical Finding:**
- Opening trainer window: **NO EVENTS**
- Viewing available recipes at trainer: **NO EVENTS**
- Learning new recipes: **NOT YET TESTED** (may fire SKILL_LINES_CHANGED)
- **Recommendation:** Use UI frame monitoring or hooks to detect trainer interactions

---

### 7A. Successful Crafting WITHOUT Skill-Up (Complete Flow)

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
- **CastTradeSkill hook MISSING** - Did not fire or scrolled away (may not exist in Classic Era)

---

### 7B. Successful Crafting WITH Skill-Up

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
  - [Item changes - details were filtered in original test]
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

### 8. Interrupted Crafting

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

### 9. Buying Reagents (Profession Window Open)

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

## Recommendations for Addon Developers

### ✅ Best Practices

1. **Cache recipe data** - Data persists between window opens, no need to rebuild state
2. **Debounce TRADE_SKILL_CLOSE** - Handle duplicate close events (check if profession name is valid)
3. **Wait for TRADE_SKILL_UPDATE** - Don't trust recipe count at TRADE_SKILL_SHOW (starts at 0)
4. **Track crafting via spellcast** - Use UNIT_SPELLCAST_START/STOP with isTradeSkill flag
5. **Monitor BAG_UPDATE during crafts** - Track reagent consumption and item creation
6. **Don't hook SelectTradeSkill/SelectCraft** - These fire constantly on mouseover (spam)

### ⚠️ Gotchas to Avoid

1. **Don't rely on event ordering** - TRADE_SKILL_UPDATE can fire out-of-order (after close, before reopen)
2. **Validate profession data** - Always check if profession name exists before processing
3. **Handle missing trainer events** - No events fire for trainer interactions, need alternative detection
4. **Debounce duplicate events**:
   - TRADE_SKILL_CLOSE fires twice (second has no data)
   - UNIT_SPELLCAST_INTERRUPTED fires 4 times
   - SKILL_LINES_CHANGED fires twice on skill-ups
5. **Missing CastTradeSkill hook** - May not fire reliably in Classic Era, use UNIT_SPELLCAST_START instead
6. **BAG_UPDATE timing** - Events fire AFTER UNIT_SPELLCAST_STOP, not during casting

### 🔍 Alternative Detection Methods

**For trainer interactions (no events available):**
- Monitor `ClassTrainerFrame` visibility with OnUpdate
- Hook trainer-related functions if they exist
- Poll for new recipes after trainer window closes

---

## Open Questions / Needs Testing

### High Priority
- [ ] **Crafting flow** - Confirm spell cast events, BAG_UPDATE timing, reagent tracking
- [ ] **Skill-up detection** - Does SKILL_LINES_CHANGED fire? Does TRADE_SKILL_UPDATE show new skill level?
- [ ] **Learning recipes from trainer** - Any events when clicking to learn? SKILL_LINES_CHANGED after?
- [ ] **Enchanting (CRAFT_* events)** - Full event flow comparison vs TRADE_SKILL_*
- [ ] **Cooldown tracking** - Does UPDATE_TRADESKILL_RECAST fire? When?

### Medium Priority
- [ ] **Batch crafting** - Create multiple items, event patterns for repeat_count > 1
- [ ] **Recipe categories** - Expand/Collapse hooks, TRADE_SKILL_UPDATE behavior
- [ ] **Interrupted crafts** - UNIT_SPELLCAST_INTERRUPTED timing
- [ ] **Insufficient reagents** - Does craft fail silently or fire UNIT_SPELLCAST_FAILED?
- [ ] **Fishing** - Does it use TRADE_SKILL_* events or separate system?

### Low Priority
- [ ] **Gathering professions** - Mining/Skinning event behavior
- [ ] **Recipe discovery** - Random recipe drops/discoveries
- [ ] **Multiple professions** - Switching between different profession windows
- [ ] **Channeled profession spells** - UNIT_SPELLCAST_CHANNEL_* events

---

## Testing Methodology

This document is based on live testing using `PROFESSIONS_EVENT_TEST.lua`, which:
- Registers all profession-related events
- Logs timestamps with millisecond precision
- Tracks event counts and timing deltas
- Monitors UI frame visibility states
- Hooks profession-related functions
- Snapshots reagent counts before/after crafting
- Filters noise (non-player events, mouseover spam)

To reproduce these findings:
1. Enable `PROFESSIONS_EVENT_TEST.lua` in `cfEventTests.toc`
2. Reload UI (`/reload`)
3. Perform profession interactions
4. Check chat window for detailed event logs

---

## Version History

**v1.0 (October 25, 2025)**
- Initial documentation
- Confirmed TRADE_SKILL_SHOW/UPDATE/CLOSE event flows
- Documented duplicate TRADE_SKILL_CLOSE bug
- Confirmed out-of-order TRADE_SKILL_UPDATE behavior
- Documented recipe data caching behavior
- Confirmed NO EVENTS for trainer interactions
- Awaiting crafting flow testing

---

*This is a living document. Additional findings will be added as testing continues.*
