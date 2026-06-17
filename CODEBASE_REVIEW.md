# NinjaLineages Codebase Review — B42.19

> **Scope:** 35+ Lua files across `shared/`, `client/`, `server/`, plus scripts & XML.  
> **Focus:** Architecture, coupling, standardization, and correctness risks.
> **Last updated:** After DRY refactor pass (Uzumaki, Byakugan, Kamui, Uchiha, Corpse, Scroll utils extracted to shared modules).

---

## ✅ FIXED — DRY Violations (Refactored Into Shared Modules)

The following duplication issues have been resolved by extracting logic into shared modules under `shared/lineages/` and `shared/disciplines/`:

| # | Duplication | Extracted To | Consumers |
|---|---|---|---|
| **1.1** | Uzumaki damage refund & bleed slow | `shared/lineages/NinjaLineages_UzumakiPassives.lua` | `PassivesServer.lua`, `client/lineages/Uzumaki.lua` |
| **1.2** | Byakugan eye management & traits | `shared/lineages/NinjaLineages_ByakuganPassives.lua` | `PassivesServer.lua`, `client/lineages/Hyuga.lua` |
| **1.3** | Kamui state save/restore | `shared/lineages/NinjaLineages_KamuiState.lua` | `AbilityAuthority.lua`, `AbilityExecution.lua` |
| **1.4** | Mangekyō unlock on death | `shared/lineages/NinjaLineages_UchihaPassives.lua` | `Server.lua`, `client/lineages/Uchiha.lua` |
| **1.5** | Corpse identifier / lookup | `shared/disciplines/NinjaLineages_CorpseUtils.lua` | `GeneExperimentationClient.lua`, `GeneExperimentationServer.lua` |
| **1.6** | Sealed scroll inventory helpers | `shared/disciplines/NinjaLineages_ScrollUtils.lua` | `AbilityExecution.lua`, `Uzumaki.lua`, `Items.lua` |
| **1.7** | Sealed scroll type check | `shared/disciplines/NinjaLineages_ScrollUtils.lua` | `Items.lua`, `Uzumaki.lua` |

**Key improvements:**
- Kamui state now captures `wasGodMod` (previously missed in `AbilityAuthority` path, causing a latent desync bug).
- Corpse lookup now handles `isZombie` branch (server version was missing it).
- Client lineage files no longer register duplicate event handlers for SP authority.

---

## 🔴 HIGH — Architecture & Coupling Problems

### 2.1 `AbilityExecution.lua` is still a God File (~963 lines)
**File:** `42/media/lua/shared/NinjaLineages_AbilityExecution.lua`

It still contains:
- Generic jutsu effect execution (`executeGenericEffect`)
- Specialized executors (`sharingan`, `byakugan`, `kamui`, `shinra_tensei`, `binding_roots`, `creation_rebirth`, `corpse_odor_conditioning`)
- Alarm seal world update logic (`updateAlarmSeals`, `squareContainsZombieInRadius`, `squareIntersectsRadius`)
- Storage seal inventory handlers (`alarm_seal`, `storage_seal`, `storage_unseal`)
- Sharingan evade hook (`sharinganEvade`) + gentle fist hook (`gentleFist`)
- Player resource loop (`everyMinute`) — chakra regen, eye drain, trait sync, `creationRebirth` tick
- Forward movement / dash interpolation
- Odor mask equip/unequip logic

**Problem:** Even after Kamui extraction, this file still has **no seams** — you cannot change alarm seal logic without touching the same file as Chakra regen. The `active` table is still a weakly-typed state bag keyed by player, holding `forwardMovement`, `kamuiUntil`, `creationRebirthUntil`, and `lastResourceUpdateAt` with no schema.

**Fix (incremental):**
1. Extract `NinjaLineages.AlarmSeals` module (ModData, radius scan, trigger).
2. Extract `NinjaLineages.ResourceLoop` module (regen, drain, trait sync, creationRebirth tick).
3. Extract `NinjaLineages.CombatHooks` module (Sharingan evade, gentle fist).
4. Keep `AbilityExecution` as a thin router: `validate → commit → dispatch to specialized module`.

---

### 2.2 Inconsistent Client/Server Authority Split
**Pattern:** The DRY fixes moved duplicated logic to shared modules, but the *pattern* of where things live is still inconsistent. Some client lineage files still use `isClient()` guards, while others now delegate to shared modules. The rule is not enforced.

**Examples:**
- Hyuga: client file is now a minimal marker; all logic lives in `ByakuganPassives.lua`. ✅
- Uzumaki: client file still has alarm seal & storage seal UI logic (correct), but the scroll helper logic is now delegated. ✅
- Uchiha: client file still has visual/moodle logic (correct), but the Mangekyō unlock death handler is removed. ✅

**Remaining issue:** Other files still follow the old pattern. For example:
- `client/lineages/Uchiha.lua` still has `SharinganMoodles` (visuals, correct — keep).
- `client/lineages/Senju.lua` (not reviewed) may have similar duplication.
- `client/lineages/Rinnegan.lua` (not reviewed) may have similar duplication.

**Fix:** Establish a clear rule and enforce it everywhere:
- **Gameplay mutations** (items, traits, health, chakra, unlocks) → `server/` or `shared/` only.
- **Visuals / moodles / UI / sounds** → `client/` only.
- **SP-only client lineage files** should never register gameplay-mutation event handlers.

---

### 2.3 `NinjaLineages.getNLData()` returns raw mutable table
**Used everywhere.**

**Problem:** Any module can do `data.foo = true` and `NinjaLineages.transmitPlayerData(player)` without any validation, type checking, or event hook. This makes data flow impossible to trace and introduces desync risks (client writes a field the server doesn't expect).

**Fix:** Introduce thin typed accessors:
```lua
function NinjaLineages.Data.setEyePowerActive(player, active)
    local data = NinjaLineages.getNLData(player)
    data.eyePowerActive = active
    NinjaLineages.transmitPlayerData(player)
end
```
Even better, route writes through server commands in MP so the server is the single source of truth.

---

### 2.4 Event Registration is Inconsistent
**Files:** Multiple.

**Pattern:**
- `NinjaLineages.addEventOnce(key, Events.OnX, handler)` — used in most modern files.
- `Events.OnX.Add(handler)` — used directly in `NinjaLineages_PassivesServer.lua` (line 259), `NinjaLineages_AbilityExecution.lua` (lines 651, 683), `NinjaLineages_TreePassives.lua` (line 122).

**Problem:** Direct `.Add()` is not idempotent. If the file is hot-reloaded or required twice, the handler fires twice. `addEventOnce` guards against this, but direct calls do not.

**Fix:** Audit all direct `Events.X.Add` calls and convert them to `NinjaLineages.addEventOnce`.

---

### 2.5 `AbilityAuthority` and `AbilityExecution` have circular dependency
**Files:** `NinjaLineages_AbilityAuthority.lua` and `NinjaLineages_AbilityExecution.lua`

- `AbilityExecution` requires `AbilityAuthority` (line 1).
- `AbilityAuthority` calls `Authority.handleEvent` which dispatches to `NinjaLineages.Rinnegan.addPulse` (defined in `Rinnegan` client file, which depends on the shared layer).
- **Kamui state extraction is done** — the `maintainLocalKamuiNoClip` issue is resolved via `NinjaLineages.KamuiState`.

**Remaining issue:** The `AbilityExecution` → `AbilityAuthority` require still exists. This is acceptable if `AbilityAuthority` never requires `AbilityExecution`, but the fact that `handleEvent` dispatches to `Rinnegan.addPulse` (a client module) creates a cross-context dependency chain that could break if the client file is not loaded in a dedicated server context.

**Fix:** Consider making `AbilityAuthority` dispatch to a registration-based plugin system rather than hard-coding lineage-specific handlers. Or ensure `AbilityAuthority` only handles the generic result forwarding and never lineage-specific logic.

---

## 🟡 MEDIUM — Standardization & Consistency Issues

### 3.1 Line Endings are Mixed
**Observation:** `Read` reports `\r` (mixed/lone CR) on many files. For example:
- `NinjaLineages_Utils.lua` — mixed `\r` and `\n`
- `NinjaLineages_JutsuCatalog.lua` — mixed
- `NinjaLineages_AbilityAuthority.lua` — mixed
- `NinjaLineages_JutsuTreeUI.lua` — mixed

**Fix:** Standardize to LF (`\n`) across the entire `lua/` tree. Mixed line endings cause `git diff` noise and `old_string` mismatch headaches during edits.

---

### 3.2 Inconsistent `isClient` / `isServer` Guard Patterns
**Examples:**
```lua
if isClient and isClient() then      -- AbilityAuthority.lua, AbilityExecution.lua
if isClient() then                    -- Hyuga.lua (line 28)
if not (isClient and isClient()) then -- PassivesServer.lua, Uzumaki.lua
if isServer and isServer() then       -- Server.lua (line 134)
```

**Problem:** `isClient` is a global that may be `nil` in some contexts (e.g., menu screens). The `isClient and isClient()` pattern is safer, but not used uniformly.

**Fix:** Add a helper in `NinjaLineages.Utils`:
```lua
function NinjaLineages.Utils.isClient() return isClient and isClient() end
function NinjaLineages.Utils.isServer() return isServer and isServer() end
```
Then use those everywhere.

---

### 3.3 Inconsistent pcall Patterns
**Examples:**
- `NinjaLineages_Utils.lua` wraps almost every engine call in `pcall` (good).
- `NinjaLineages_AbilityExecution.lua` sometimes wraps, sometimes doesn't (e.g., `player:getVehicle()` at line 212 is unprotected).
- `NinjaLineages_RinneganMechanics.lua` uses `pcall` only in `applyDamage`.

**Fix:** Adopt a rule: **Any B42 engine call that could return nil or throw in a future patch gets `pcall`**. Provide a `NinjaLineages.Utils.safeCall` wrapper that logs failures with context.

---

### 3.4 Hardcoded Constants Scattered in Implementation
**Examples:**
- `KAMUI_SP_STEP_DISTANCE = 0.055` in `AbilityExecution.lua` (line 16)
- `KAMUI_ALPHA = 0.55` in `AbilityAuthority.lua` (line 10) — **Note:** This was moved into `KamuiState.lua` but is still hardcoded there.
- `duration = 0.2`, `distance = 3.0` in `GeneExperimentationClient.lua` (lines 244–245) for zombie dash — should reference `NinjaLineages.Balance` or `Constants`
- `2.0` in-game minutes for zombie dash cooldown in `GeneExperimentationClient.lua` (line 332) vs `0.16` in `GeneExperimentationServer.lua` (line 78) — **these are different values!** This is likely a bug.

**Fix:** Move all magic numbers into `NinjaLineages.Constants` or `NinjaLineages.Balance`.

---

### 3.5 Inconsistent `require` Chains
**Example:** `NinjaLineages_Effects.lua` requires ~15 files, many of which already require each other. `NinjaLineages_Items.lua` requires `NinjaLineages_Traits`, `NinjaLineages_Utils`, `NinjaLineages_Chakra`, `NinjaLineages_Progression`, and `ISReadABook` — but `Traits` already depends on `Constants`, and `Utils` is used by almost everything.

**Fix:** Document a load-order DAG. Prefer requiring only what the file directly uses. Avoid deep require chains that make circular dependencies likely.

---

## 🟢 LOW — Correctness Risks & Dead Code

### 4.1 `sayCastError` is Dead Code
**File:** `42/media/lua/shared/NinjaLineages_RinneganMechanics.lua:24–36`

`mechanics.validateCast` returns `false, reason, remaining` but the callers (`execute` in the same file, and `specializedExecutors.shinra_tensei` in `AbilityExecution.lua`) do **not** call `sayCastError`. The error display is handled by `AbilityAuthority.handleResult` instead.

**Fix:** Remove `sayCastError` or replace `validateCast` with a version that returns a message key directly.

---

### 4.2 `getPlayer()` Used in MP Contexts
**Files:**
- `NinjaLineages_GeneExperimentationClient.lua:311, 334, 393` — uses `getPlayer()` instead of `getSpecificPlayer(playerNum)` or the passed player.
- `NinjaLineages_Items.lua:16–23` — `RecipeCodeOnTest` uses `getPlayer()` / `getSpecificPlayer(0)`.

**Problem:** In split-screen or MP, `getPlayer()` returns player 0. If another player is interacting, the check evaluates against the wrong character.

**Fix:** In context-menu handlers, always use `getSpecificPlayer(playerNum)`. In recipe tests, the engine may not expose the crafting player — you may need to mark the recipe as always available and gate it server-side.

---

### 4.3 `gentleFist` and `sharinganEvade` Hooks Use Raw `Events.Add`
**File:** `42/media/lua/shared/NinjaLineages_AbilityExecution.lua:651–653`
```lua
if not (isClient and isClient()) and Events and Events.OnHitZombie then
    Events.OnHitZombie.Add(gentleFist)
end
```

Same issue for `sharinganEvade` (line 683). These are not guarded by `addEventOnce`, so a reload causes double registration.

**Fix:** Convert to `NinjaLineages.addEventOnce` with appropriate keys.

---

### 4.4 `forwardMovement` and `zombieDash` Share Algorithm but No Helper
**Files:** `AbilityExecution.lua:696–723` and `GeneExperimentationClient.lua:258–289`

Both do:
1. Compute progress from `now / duration`
2. Step along a direction vector
3. Check `isBlockedTo` between squares
4. Set position with `setX`/`setY`

**Fix:** Extract `NinjaLineages.Utils.Movement.interpolateMove(entity, startX, startY, dirX, dirY, distance, stepSize, duration)`.

---

### 4.5 `refreshWornItemModifiers` is Both Local and Exported
**File:** `NinjaLineages_Utils.lua:19–27`

```lua
local function refreshWornItemModifiers(player) ... end
function NinjaLineages.Utils.Inventory.refreshWornItemModifiers(player)
    refreshWornItemModifiers(player)
end
```

The exported function is an unnecessary pass-through. Just make the local function the public one.

---

### 4.6 `NinjaLineages_PassivesServer.lua` Lacks `isClient()` Guard on Load
**File:** `42/media/lua/server/NinjaLineages_PassivesServer.lua`

The file is in `server/` but the engine may still load it in SP (where client and server are the same process). The `isLivePlayer` check is runtime, but the file should still be safe to require in any context.

**Fix:** Not critical, but ensure any top-level `Events.OnX.Add` calls use `addEventOnce` so SP doesn't double-register if the file is also required from a client init path.

---

## 5. Recommended Refactor Priority

| Priority | Action | Files to Touch | Status |
|----------|--------|---------------|--------|
| **P0** | Extract Uzumaki/Byakugan passive logic into shared modules | `PassivesServer`, `Uzumaki`, `Hyuga` | ✅ Done |
| **P0** | Collapse Kamui state save/restore into one module | `AbilityAuthority`, `AbilityExecution` | ✅ Done |
| **P0** | Extract Mangekyō unlock into shared module | `Server.lua`, `Uchiha.lua` | ✅ Done |
| **P0** | Extract corpse/scroll utilities into shared modules | `GeneExperimentationClient`, `GeneExperimentationServer`, `Items`, `Uzumaki`, `AbilityExecution` | ✅ Done |
| **P1** | Split `AbilityExecution.lua` into 3–4 focused modules | `AbilityExecution` (new: `AlarmSeals`, `ResourceLoop`, `CombatHooks`) | 🔴 Pending |
| **P1** | Standardize `isClient`/`isServer` guards | All files | 🔴 Pending |
| **P1** | Convert all direct `Events.X.Add` to `addEventOnce` | `PassivesServer`, `AbilityExecution`, `TreePassives` | 🔴 Pending |
| **P2** | Fix `getPlayer()` → `getSpecificPlayer(playerNum)` | `GeneExperimentationClient`, `Items` | 🔴 Pending |
| **P2** | Move magic numbers to `Constants` / `Balance` | `AbilityExecution`, `GeneExperimentationClient`, `AbilityAuthority` | 🔴 Pending |
| **P2** | Normalize line endings to LF | All `.lua` files | 🔴 Pending |
| **P3** | Introduce `NinjaLineages.Data` typed accessors | All files writing to `getNLData()` | 🔴 Pending |
| **P3** | Extract shared movement interpolation | `AbilityExecution`, `GeneExperimentationClient` | 🔴 Pending |

---

## 6. Summary

The DRY refactor pass is **complete**. The following duplication has been collapsed into shared modules:

- `NinjaLineages.UzumakiPassives` — damage refund, bleed slow, health snapshotting
- `NinjaLineages.ByakuganPassives` — Byakugan sight item equip/unequip, trait management
- `NinjaLineages.KamuiState` — save/restore, apply, maintain, emit, safe-exit, place-phased
- `NinjaLineages.UchihaPassives` — Mangekyō unlock on death
- `NinjaLineages.CorpseUtils` — corpse identifier / lookup (with `isZombie` fix)
- `NinjaLineages.ScrollUtils` — sealed scroll type check, backpack check, inventory access

**What remains:**

1. **God modules** — `AbilityExecution.lua` still does too much; needs seams (AlarmSeals, ResourceLoop, CombatHooks).
2. **Inconsistent safety patterns** — `pcall`, `isClient`, event registration, and line endings vary file-to-file.
3. **Scattered magic numbers** — zombie dash cooldown mismatch (`2.0` vs `0.16`), Kamui constants, alarm seal radius, etc.
4. **Client/server authority rule** — need to enforce the rule consistently across all remaining files.
5. **Raw mutable data** — `getNLData()` is still an open table; typed accessors would prevent desyncs.

The highest-impact remaining win is **carving up `AbilityExecution.lua`** so that each subsystem (Alarm Seals, Resource Loop, Combat Hooks) can evolve independently.
