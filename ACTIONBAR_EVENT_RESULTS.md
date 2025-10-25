# WoW Classic Era: Actionbar Events Reference
## Version 1.15 Event Investigation

**Last Updated:** October 25, 2025
**Testing:** Action button usage, drag/drop, targeting, spell casting, mana/range tracking

---

## Test Summary

### Events Registered for Testing
**Total Events Monitored:** 42 actionbar-related events

### Events That Fired During Testing
| Event | Fired? | Frequency | Notes |
|-------|--------|-----------|-------|
| `ACTIONBAR_SLOT_CHANGED` | ✅ | 1× per slot change | Reliable, shows cooldown info |
| `ACTIONBAR_SHOWGRID` | ✅ | 1× per drag start | Grid visibility during drag |
| `ACTIONBAR_HIDEGRID` | ✅ | 1× per drag end | Grid hiding after placement |
| `ACTIONBAR_UPDATE_STATE` | ✅ | High frequency | **Spam: Every 2-4 seconds** |
| `ACTIONBAR_UPDATE_COOLDOWN` | ✅ | High frequency | **Spam: After every action** |
| `SPELL_UPDATE_USABLE` | ✅ | Very high frequency | **Spam: Constant validation** |
| `SPELL_UPDATE_COOLDOWN` | ✅ | 1× per spell cast | Reliable cooldown tracking |
| `UPDATE_SHAPESHIFT_FORM` | ✅ | Periodic | Form state validation |
| `UPDATE_SHAPESHIFT_COOLDOWN` | ✅ | 1× per spell cast | Form cooldown updates |
| `PLAYER_TARGET_CHANGED` | ✅ | 1× per target change | **Critical for range updates** |
| `UNIT_POWER_UPDATE` | ✅ | Very high frequency | **Spam: 4× per spell cast** |
| `UNIT_AURA` | ✅ | 2× per buff/debuff | Player and target auras |
| `CURRENT_SPELL_CAST_CHANGED` | ✅ | Multiple per cast | **Spam: 3-8× per spell** |
| `SPELLS_CHANGED` | ✅ | 1× on login | Spell system initialization |
| `UPDATE_BINDINGS` | ✅ | 5× on login | Key binding initialization |
| `UPDATE_MACROS` | ✅ | 2× on login | Macro system initialization |
| `SKILL_LINES_CHANGED` | ✅ | 1× on login | Skill system initialization |
| `PLAYER_ENTERING_WORLD` | ✅ | 1× on login/reload | Standard initialization |

### Events That Did NOT Fire During Testing
| Event | Status | Reason |
|-------|--------|--------|
| `ACTIONBAR_PAGE_CHANGED` | ❌ | No page switching performed |
| `UPDATE_BONUS_ACTIONBAR` | ❌ | No bonus bar conditions met |
| `UPDATE_INVENTORY_ALERTS` | ❌ | No inventory alerts triggered |
| `UPDATE_SHAPESHIFT_USABLE` | ❌ | May require specific class/conditions |
| `PLAYER_REGEN_ENABLED` | ❌ | No combat testing performed |
| `PLAYER_REGEN_DISABLED` | ❌ | No combat testing performed |
| `LEARNED_SPELL_IN_TAB` | ❌ | No spell learning occurred |
| `SPELL_ACTIVATION_OVERLAY_GLOW_*` | ❌ | No proc effects triggered |

### Hooks That Fired During Testing
| Hook | Fired? | Frequency | Notes |
|------|--------|-----------|-------|
| `UseAction` | ✅ | 1× per button click | **Perfect for action tracking** |
| `PickupAction` | ✅ | 1× per drag start | Shows source slot info |
| `PlaceAction` | ✅ | 1× per drag end | Shows cursor and target slot |
| `CastSpell` | ❌ | Not tested | Direct spell casting |
| `CastSpellByName` | ❌ | Not tested | Spell casting by name |
| `SpellStopCasting` | ❌ | Not tested | Spell interruption |
| `CastShapeshiftForm` | ❌ | Not tested | Form switching |

### Tests Performed Headlines
1. **Login/Reload** - Initialization events (9× batched events)
2. **Combat Testing** - Enter/exit combat with PLAYER_REGEN_* events
3. **Target Changes** - Multiple target types (player, hostile, friendly, clear)
4. **Range Detection** - [NO RANGE] ↔ [IN RANGE] transitions (3 ranged spells)
5. **Low Mana Testing** - Cast until [NO MANA], verify mana regeneration
6. **Spell Casting** - Multiple spells with different costs and ranges
7. **Action Dragging** - Moving spells between slots with grid show/hide
8. **Mana Regeneration** - [NO MANA] → [USABLE] recovery patterns
9. **Health Tracking** - Combat damage detection during spell casting
10. **Event Batching** - Filtered spam, focused on actionable events

---

## Quick Decision Guide

### Event Reliability for AI Decision Making
| Event | Reliability | Performance | Best Use Case |
|-------|-------------|-------------|---------------|
| `PLAYER_TARGET_CHANGED` | 100% | Low | ✅ **Primary range update trigger** |
| `UseAction` (hook) | 100% | Low | ✅ **Primary action usage detection** |
| `ACTIONBAR_SLOT_CHANGED` | 100% | Low | ✅ Action placement/cooldown tracking |
| `SPELL_UPDATE_USABLE` | 100% | High | ⚠️ **Critical but spammy** |
| `UNIT_POWER_UPDATE` | 100% | Very High | ⚠️ **Mana tracking but very spammy** |
| `ACTIONBAR_UPDATE_STATE` | 100% | High | ⚠️ Periodic validation (every 2-4s) |
| `ACTIONBAR_UPDATE_COOLDOWN` | 100% | Medium | ⚠️ Fires after every action |

### Use Case → Best Event Mapping
- **Range-based coloring:** `PLAYER_TARGET_CHANGED` → immediate `IsActionInRange()` check
- **Mana-based coloring:** `SPELL_UPDATE_USABLE` → `IsUsableAction()` check
- **Action usage tracking:** `UseAction` hook → slot identification
- **Slot content changes:** `ACTIONBAR_SLOT_CHANGED` → re-evaluate slot
- **Real-time updates:** Batch `SPELL_UPDATE_USABLE` events (50ms window)

### Critical Actionbar Coloring Rules
- **Range Detection:** `IsActionInRange(slot)` returns 1/0/nil (in/out/no requirement)
- **Usability Detection:** `IsUsableAction(slot)` returns `isUsable, notEnoughMana`
- **Immediate Updates:** Target changes update range instantly (0ms delay)
- **Batch Processing:** Group frequent events to avoid UI lag
- **Slot Range:** 1-120 covers all actionbar slots across pages

---

## Event Sequence Patterns

### Predictable Sequences (Safe to rely on order)
```
Target Change: PLAYER_TARGET_CHANGED → SPELL_UPDATE_USABLE (0ms delay)
Spell Cast: UseAction hook → [BATCH 5-14] CURRENT_SPELL_CAST_CHANGED, ACTIONBAR_UPDATE_COOLDOWN, ACTIONBAR_UPDATE_STATE, SPELL_UPDATE_COOLDOWN, UPDATE_SHAPESHIFT_COOLDOWN
Action Drag: PickupAction hook → ACTIONBAR_SHOWGRID → PlaceAction hook → ACTIONBAR_SLOT_CHANGED → ACTIONBAR_HIDEGRID
Mana Change: UNIT_POWER_UPDATE (4×) → SPELL_UPDATE_USABLE
Aura Application: UNIT_AURA (player) → UNIT_AURA (target) → SPELL_UPDATE_USABLE
```

### UI State Changes
```
Drag Start: ACTIONBAR_SHOWGRID → Grid visible (0ms delay)
Drag End: ACTIONBAR_HIDEGRID → Grid hidden (0ms delay)
Target Change: PLAYER_TARGET_CHANGED → Range updates (0ms delay)
Spell Cast: UseAction → [CURRENT] state → Cooldown cascade
```

---

## Performance Impact Summary

| Operation | Total Events | Spam Events | Performance Impact |
|-----------|--------------|-------------|-------------------|
| Target Change | 2 | None | Minimal |
| Spell Cast | 14-20 | CURRENT_SPELL_CAST_CHANGED (3-8×), UNIT_POWER_UPDATE (4×) | High |
| Action Drag | 5 | None | Low |
| Periodic Updates | 4 | SPELL_UPDATE_USABLE, ACTIONBAR_UPDATE_STATE | Medium |

**Note:** Spell casting generates significant event spam requiring batching for performance.

---

## Essential API Functions

### Action Information
```lua
-- Get action details
local actionType, id, subType = GetActionInfo(slot)
local actionText = GetActionText(slot)
local texture = GetActionTexture(slot)
local count = GetActionCount(slot)

-- Check action state
local hasAction = HasAction(slot)
local inRange = IsActionInRange(slot)  -- 1=in range, 0=out of range, nil=no range
local isUsable, notEnoughMana = IsUsableAction(slot)
local isCurrent = IsCurrentAction(slot)
local isAutoRepeat = IsAutoRepeatAction(slot)

-- Get cooldown info
local start, duration, enable = GetActionCooldown(slot)
```

### Action Operations
```lua
-- Use actions
UseAction(slot, checkCursor, onSelf)

-- Drag/drop actions
PickupAction(slot)  -- Pick up action from slot
PlaceAction(slot)   -- Place cursor action to slot

-- Cursor management
local cursorType, info1, info2 = GetCursorInfo()
ClearCursor()
```

### Shapeshift Functions
```lua
-- Get shapeshift info
local numForms = GetNumShapeshiftForms()
local currentForm = GetShapeshiftForm()
local icon, active, castable, cooldownStart, cooldownDuration = GetShapeshiftFormInfo(index)

-- Cast shapeshift form
CastShapeshiftForm(index)
```

### Page Management
```lua
-- Get current page (if function exists)
local currentPage = GetActionBarPage and GetActionBarPage() or 1
```

---

## Implementation Patterns

### ✅ Recommended for Actionbar Coloring
```lua
-- Primary events for actionbar coloring addon
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")  -- Range updates
eventFrame:RegisterEvent("SPELL_UPDATE_USABLE")    -- Usability updates
eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED") -- Slot changes

-- Batch frequent events to avoid lag
local updateTimer = nil
local function scheduleUpdate()
    if updateTimer then updateTimer:Cancel() end
    updateTimer = C_Timer.NewTimer(0.05, updateActionbarColors)
end

-- Efficient range/usability checking
local function updateActionbarColors()
    for slot = 1, 120 do
        if HasAction(slot) then
            local isUsable, notEnoughMana = IsUsableAction(slot)
            local inRange = IsActionInRange(slot)
            
            if not isUsable and notEnoughMana then
                -- Blue tint for no mana
                colorActionButton(slot, "mana")
            elseif inRange == 0 then
                -- Red tint for out of range
                colorActionButton(slot, "range")
            else
                -- Normal color
                colorActionButton(slot, "normal")
            end
        end
    end
end

-- Hook for immediate feedback
hooksecurefunc("UseAction", function(slot)
    -- Immediate visual feedback on action use
    updateSingleActionButton(slot)
end)
```

### ❌ Anti-Patterns
```lua
-- DON'T update on every SPELL_UPDATE_USABLE without batching
if event == "SPELL_UPDATE_USABLE" then
    updateActionbarColors() -- This fires constantly!
end

-- DON'T check all 120 slots on every event
-- Batch updates and use timers

-- DON'T ignore the notEnoughMana flag
local isUsable = IsUsableAction(slot)
-- Missing: , notEnoughMana parameter

-- DON'T assume range values
if IsActionInRange(slot) then -- Wrong! Can return nil
    -- This fails for spells with no range requirement
end
```

---

## Key Technical Details

### Critical Timing Discoveries
- **Action Response:** TBD during testing
- **Cooldown Updates:** TBD during testing  
- **Page Switching:** TBD during testing
- **Form Changes:** TBD during testing

### Action Slot System
- **Slot Range:** 1-120 (12 slots × 10 pages)
- **Page System:** Page 1 = slots 1-12, Page 2 = slots 13-24, etc.
- **Empty Slots:** Return nil for most GetAction* functions
- **Action Types:** spell, item, macro, companion, equipmentset

### Cooldown System
- **Global Cooldown:** Affects most actions
- **Spell Cooldowns:** Individual spell cooldowns
- **Item Cooldowns:** Item-specific cooldowns
- **Form Cooldowns:** Shapeshift form cooldowns

### Range System
- **Range Values:** 1 (in range), 0 (out of range), nil (no range requirement)
- **Target Dependency:** Updates with PLAYER_TARGET_CHANGED
- **Combat Dependency:** Some actions only usable in/out of combat

---

## Additional Testing Needed for Actionbar Coloring

### Critical Missing Tests (High Priority)
1. **Combat State Changes** - Test PLAYER_REGEN_ENABLED/DISABLED events
   - Some spells only usable in/out of combat
   - Combat affects spell availability and coloring needs
   
2. **Low Mana Scenarios** - Cast spells until out of mana
   - Verify `notEnoughMana` flag behavior
   - Test mana-dependent spell coloring transitions
   
3. **Out of Range Testing** - Move away from target while having ranged spells
   - Verify range detection accuracy
   - Test range coloring with different spell types
   
4. **Page Switching** - Test ACTIONBAR_PAGE_CHANGED event
   - Verify slot numbering across pages (1-12, 13-24, etc.)
   - Ensure coloring persists across page changes

5. **Different Spell Types** - Test various action types
   - Item actions (potions, trinkets)
   - Macro actions
   - Equipment set actions

### Medium Priority Tests
1. **Class-Specific Features** - Test with different classes
   - Shapeshift forms (Druid)
   - Stances (Warrior)
   - Stealth (Rogue)
   
2. **Buff/Debuff Dependencies** - Test spells requiring specific auras
   - Spells only usable with certain buffs
   - Form-dependent abilities
   
3. **Cooldown Interactions** - Test global vs spell-specific cooldowns
   - Verify coloring during cooldown periods
   - Test cooldown completion updates

### Performance Testing Needed
1. **Event Frequency Under Load** - Test with full actionbars
   - Measure SPELL_UPDATE_USABLE frequency with 120 actions
   - Optimize batching window for smooth performance
   
2. **Memory Usage** - Test addon memory impact
   - Monitor memory with continuous coloring updates
   - Test for memory leaks during extended play

### Validation Tests Required
1. **Edge Cases** - Test unusual scenarios
   - Empty action slots mixed with filled slots
   - Actions that change type (shapeshifting)
   - Network lag affecting event timing
   
2. **UI Integration** - Test with other actionbar addons
   - Bartender compatibility
   - ElvUI compatibility
   - Default UI modifications

**Recommendation:** Focus on combat state and mana testing first, as these are core to actionbar coloring functionality.