require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "NinjaLineages_Balance"
require "disciplines/jinchuuriki/NinjaLineages_BijuuDefinitions"
require "disciplines/jinchuuriki/NinjaLineages_BijuuState"
require "jinchuuriki/NinjaLineages_BijuuRegistryServer"
require "jinchuuriki/NinjaLineages_BijuuBossServer"
require "jinchuuriki/NinjaLineages_BijuuSpawnServer"
require "jinchuuriki/NinjaLineages_BijuuServerSupport"

NinjaLineages = NinjaLineages or {}
NinjaLineages.BijuuLifecycleServer = NinjaLineages.BijuuLifecycleServer or {}

local LifecycleServer = NinjaLineages.BijuuLifecycleServer
local Definitions = NinjaLineages.BijuuDefinitions
local BijuuState = NinjaLineages.BijuuState
local Registry = NinjaLineages.BijuuRegistryServer
local BossServer = NinjaLineages.BijuuBossServer
local SpawnServer = NinjaLineages.BijuuSpawnServer
local Support = NinjaLineages.BijuuServerSupport

local pendingCorpseSuppression = {}
local forceNextReveal = false
local startupReconciled = false

local function log(message)
    print("[NL-BIJUU-LIFECYCLE] " .. tostring(message))
end

local function getReleaseConfig()
    return NinjaLineages.Balance and NinjaLineages.Balance.Jinchuuriki and NinjaLineages.Balance.Jinchuuriki.Release or {
        ZOMBIE_NINJA_REVEAL_CHANCE = 0.01,
        RESPAWN_MIN_DISTANCE_FROM_DEATH = 350.0,
        CORPSE_SUPPRESSION_TIMEOUT_MINUTES = 0.5,
        MELEE_SWING_MIN_INTERVAL_GAME_MINUTES = 0.005,
    }
end

function LifecycleServer.setForceNextReveal(value)
    forceNextReveal = (value == true)
end

function LifecycleServer.onZombieNinjaDead(zombie, attacker)
    if not Support.isAuthoritative() then return end
    if not zombie or not zombie.getModData then return end

    local modData = zombie:getModData()
    if modData.isZombieNinja ~= true then return end

    -- 1. Query available low-tail Bijū in HOST_POOL
    local availablePool = Registry.getHostPoolBijuuIds()
    if not availablePool or #availablePool == 0 then
        return -- No low-tail Bijū currently in HOST_POOL
    end

    -- 2. Check reveal chance
    local cfg = getReleaseConfig()
    local revealChance = cfg.ZOMBIE_NINJA_REVEAL_CHANCE or 0.01
    local shouldReveal = forceNextReveal

    if not shouldReveal then
        if ZomboidRandFloat then
            shouldReveal = (ZomboidRandFloat(0.0, 1.0) < revealChance)
        else
            shouldReveal = (math.random() < revealChance)
        end
    end

    forceNextReveal = false

    if not shouldReveal then
        return -- Normal Zombie Ninja death proceeds
    end

    -- 3. Uniformly choose one available candidate
    -- Shuffle candidates to ensure fair distribution during concurrency
    local candidates = {}
    for _, id in ipairs(availablePool) do
        table.insert(candidates, id)
    end
    for i = #candidates, 2, -1 do
        local j = math.random(1, i)
        candidates[i], candidates[j] = candidates[j], candidates[i]
    end

    local zx = zombie:getX()
    local zy = zombie:getY()
    local zz = zombie:getZ() or 0

    -- 4. Atomically claim via compare-and-swap transition
    local claimedId = nil
    for _, candidateId in ipairs(candidates) do
        local okClaim, claimRsn = Registry.transition(
            candidateId,
            BijuuState.HOST_POOL,
            BijuuState.BOSS_ACTIVE,
            {
                world = {
                    x = zx,
                    y = zy,
                    z = zz,
                }
            },
            "zombie_ninja_reveal"
        )
        if okClaim then
            claimedId = candidateId
            break
        end
    end

    if not claimedId then
        log("zombie ninja reveal roll succeeded but all candidates were already claimed")
        return
    end

    -- 5. Materialize boss shell at death coordinate
    local runtime, matRsn = BossServer.materialize(claimedId, zx, zy, zz, {
        debugOriginalState = BijuuState.HOST_POOL
    })

    if not runtime then
        log("reveal materialize failed for " .. tostring(claimedId) .. " (" .. tostring(matRsn) .. "), rolling back to HOST_POOL")
        Registry.transition(
            claimedId,
            BijuuState.BOSS_ACTIVE,
            BijuuState.HOST_POOL,
            { world = false, host = false, vessel = false },
            "reveal_materialize_failed"
        )
        return
    end

    -- 6. Register corpse suppression for this exact death
    local characterOnlineId = nil
    if zombie.getOnlineID then
        local ok, onlineId = pcall(function() return zombie:getOnlineID() end)
        if ok and onlineId and onlineId >= 0 then characterOnlineId = onlineId end
    end
    pendingCorpseSuppression[runtime.runtimeId] = {
        bijuuId = claimedId,
        runtimeId = runtime.runtimeId,
        characterOnlineId = characterOnlineId,
        x = zx,
        y = zy,
        z = zz,
        timestamp = NinjaLineages.Utils.Time.gameMinutes(),
    }

    log("zombie_ninja_reveal roll=success bijuu=" .. tostring(claimedId) .. " pos=(" .. tostring(zx) .. "," .. tostring(zy) .. "," .. tostring(zz) .. ") runtime=" .. tostring(runtime.runtimeId))
end

function LifecycleServer.onDeadBodySpawn(body)
    if not Support.isAuthoritative() then return end
    if not body or not instanceof(body, "IsoDeadBody") then return end
    if not body.isZombie or not body:isZombie() then return end

    local bx = body:getX()
    local by = body:getY()
    local bz = body:getZ()
    local bodyOnlineId = nil
    if body.getCharacterOnlineID then
        local ok, onlineId = pcall(function() return body:getCharacterOnlineID() end)
        if ok and onlineId and onlineId >= 0 then bodyOnlineId = onlineId end
    end
    local now = NinjaLineages.Utils.Time.gameMinutes()
    local timeout = getReleaseConfig().CORPSE_SUPPRESSION_TIMEOUT_MINUTES or 0.5

    for runtimeId, pending in pairs(pendingCorpseSuppression) do
        if now - pending.timestamp > timeout then
            pendingCorpseSuppression[runtimeId] = nil
        else
            local idMatches = pending.characterOnlineId ~= nil
                and bodyOnlineId ~= nil
                and pending.characterOnlineId == bodyOnlineId
            local coordinateMatches = pending.characterOnlineId == nil
                and math.floor(bx) == math.floor(pending.x)
                and math.floor(by) == math.floor(pending.y)
                and math.floor(bz) == math.floor(pending.z)
            if idMatches or coordinateMatches then
                pcall(function()
                    if body.removeFromWorld then body:removeFromWorld() end
                    if body.removeFromSquare then body:removeFromSquare() end
                end)
                log("suppressed zombie ninja corpse for released bijuu=" .. tostring(pending.bijuuId) .. " at (" .. tostring(bx) .. "," .. tostring(by) .. ")")
                pendingCorpseSuppression[runtimeId] = nil
                return
            end
        end
    end
end

local function pruneCorpseSuppressions()
    local now = NinjaLineages.Utils.Time.gameMinutes()
    local timeout = getReleaseConfig().CORPSE_SUPPRESSION_TIMEOUT_MINUTES or 0.5
    for runtimeId, pending in pairs(pendingCorpseSuppression) do
        if now - pending.timestamp > timeout then
            pendingCorpseSuppression[runtimeId] = nil
        end
    end
end

function LifecycleServer.handleBossDefeated(bijuuId, runtimeId, position)
    if not Support.isAuthoritative() then return end
    if not Definitions.isValidId(bijuuId) then return end

    local def = Definitions.get(bijuuId)
    if not def then return end

    local pos = position or { x = 0, y = 0, z = 0 }
    local currentState = Registry.getBijuuState(bijuuId)
    if currentState == BijuuState.SEALING then
        local sealingServer = NinjaLineages.BijuuSealingServer
        if sealingServer and sealingServer.cancelForBossDefeat then
            sealingServer.cancelForBossDefeat(bijuuId, runtimeId)
        end
        currentState = Registry.getBijuuState(bijuuId)
        if currentState == BijuuState.SEALING then
            local record = Registry.getRecord(bijuuId)
            local sourceState = record and record.sealing and record.sealing.sourceState
            if sourceState == BijuuState.WILD_ACTIVE or sourceState == BijuuState.BOSS_ACTIVE then
                Registry.transition(
                    bijuuId,
                    BijuuState.SEALING,
                    sourceState,
                    { sealing = false },
                    "boss_defeat_orphaned_sealing_rollback"
                )
                currentState = Registry.getBijuuState(bijuuId)
            end
        end
    end
    if def.nativeSpawnType == "host" and currentState ~= BijuuState.BOSS_ACTIVE then
        log("host defeat rejected incompatible custody bijuu=" .. tostring(bijuuId)
            .. " state=" .. tostring(currentState))
        return
    elseif def.nativeSpawnType == "wild"
            and currentState ~= BijuuState.WILD_ACTIVE
            and currentState ~= BijuuState.BOSS_ACTIVE then
        log("wild defeat rejected incompatible custody bijuu=" .. tostring(bijuuId)
            .. " state=" .. tostring(currentState))
        return
    end

    if def.nativeSpawnType == "host" then
        -- 1–3 Tails (Low Tails): Dematerialize & Return to HOST_POOL
        local transitioned, reason = Registry.transition(
            bijuuId,
            currentState,
            BijuuState.HOST_POOL,
            { world = false, host = false, vessel = false },
            "boss_defeated_host_return"
        )
        if not transitioned then
            log("host defeat transition failed bijuu=" .. tostring(bijuuId)
                .. " reason=" .. tostring(reason))
            return
        end
        BossServer.dematerialize(bijuuId, runtimeId, "boss_defeated")
        log("boss_defeated bijuu=" .. tostring(bijuuId) .. " native=host -> returned_to_host_pool")
    else
        -- Wild-native beasts can currently be WILD_ACTIVE or released BOSS_ACTIVE.
        local transitioned, reason = Registry.transition(
            bijuuId,
            currentState,
            BijuuState.RESPAWNING,
            nil,
            "boss_defeated_wild_respawn"
        )
        if not transitioned then
            log("wild defeat transition failed bijuu=" .. tostring(bijuuId)
                .. " reason=" .. tostring(reason))
            return
        end

        BossServer.dematerialize(bijuuId, runtimeId, "boss_defeated")

        LifecycleServer.recoverRespawningBijuu(bijuuId, pos)
    end
end

function LifecycleServer.recoverRespawningBijuu(bijuuId, previousPosition)
    if Registry.getBijuuState(bijuuId) ~= BijuuState.RESPAWNING then
        return false, "state_mismatch"
    end
    local cfg = getReleaseConfig()
    local options = { allowOtherRegions = true }
    if previousPosition then
        options.minDistance = cfg.RESPAWN_MIN_DISTANCE_FROM_DEATH or 350.0
        options.previousPos = previousPosition
    end
    local newLoc, reason = SpawnServer.findValidWildLocation(bijuuId, options)
    if not newLoc then
        log("wild respawn location search pending for " .. tostring(bijuuId)
            .. ": " .. tostring(reason))
        return false, reason
    end
    local transitioned, transitionReason = Registry.transition(
        bijuuId,
        BijuuState.RESPAWNING,
        BijuuState.WILD_DORMANT,
        { world = newLoc, vessel = false, sealing = false },
        "respawn_location_assigned"
    )
    if transitioned then
        log("wild respawn assigned bijuu=" .. tostring(bijuuId)
            .. " pos=(" .. tostring(newLoc.x) .. "," .. tostring(newLoc.y)
            .. ") region=" .. tostring(newLoc.regionId))
    end
    return transitioned, transitionReason, newLoc
end

function LifecycleServer.reconcileOnStartup()
    if not Support.isAuthoritative() or startupReconciled then return end
    startupReconciled = true
    local sealingServer = NinjaLineages.BijuuSealingServer
    if sealingServer and sealingServer.reconcileOrphanedSealing then
        sealingServer.reconcileOrphanedSealing()
    end
    SpawnServer.reconcileOnStartup()

    -- 1. Reconcile low-tail orphans (BOSS_ACTIVE with no runtime -> HOST_POOL)
    for _, bijuuId in ipairs(Definitions.Order) do
        local def = Definitions.get(bijuuId)
        if def and def.nativeSpawnType == "host" then
            local rec = Registry.getRecord(bijuuId)
            if rec and rec.state == BijuuState.BOSS_ACTIVE and not BossServer.getActiveBossSnapshot(bijuuId) then
                log("reconciling orphaned low-tail BOSS_ACTIVE -> HOST_POOL for " .. tostring(bijuuId))
                Registry.transition(
                    bijuuId,
                    BijuuState.BOSS_ACTIVE,
                    BijuuState.HOST_POOL,
                    { world = false, host = false, vessel = false },
                    "startup_reconcile"
                )
            end
        end
    end

    -- 2. Released wild bosses use BOSS_ACTIVE; after restart they return to wild custody.
    for _, bijuuId in ipairs(Registry.getWildBijuuIds()) do
        local rec = Registry.getRecord(bijuuId)
        if rec and rec.state == BijuuState.BOSS_ACTIVE
                and not BossServer.getActiveBossSnapshot(bijuuId) then
            local transitioned = Registry.transition(
                bijuuId,
                BijuuState.BOSS_ACTIVE,
                BijuuState.RESPAWNING,
                { world = false, vessel = false, sealing = false },
                "startup_reconcile_released_wild"
            )
            if transitioned then LifecycleServer.recoverRespawningBijuu(bijuuId) end
        end
    end

    -- 3. Reconcile wild respawning orphans (RESPAWNING -> WILD_DORMANT at new location)
    for _, bijuuId in ipairs(Registry.getWildBijuuIds()) do
        local rec = Registry.getRecord(bijuuId)
        if rec and rec.state == BijuuState.RESPAWNING then
            LifecycleServer.recoverRespawningBijuu(bijuuId)
        end
    end
end

function LifecycleServer.update()
    SpawnServer.update()
end

-- ============================================================================
-- Debug Tooling & Lifecycle Actions
-- ============================================================================

function LifecycleServer.debugForceNextZombieNinjaReveal(player)
    LifecycleServer.setForceNextReveal(true)
    log("debug force next Zombie Ninja reveal enabled by " .. tostring(player and player:getUsername() or "admin"))
    return true, "ok"
end

function LifecycleServer.debugForceDefeatActiveBoss(player, bijuuId)
    if not Definitions.isValidId(bijuuId) then return false, "invalid_bijuu_id" end
    local snap = BossServer.getActiveBossSnapshot(bijuuId)
    if not snap then return false, "no_active_boss" end

    LifecycleServer.handleBossDefeated(bijuuId, snap.runtimeId, { x = snap.x, y = snap.y, z = snap.z })
    log("debug force defeat triggered for " .. tostring(bijuuId) .. " runtime=" .. tostring(snap.runtimeId))
    return true, "ok"
end

function LifecycleServer.debugRerollWildLocation(player, bijuuId)
    if not Definitions.isValidId(bijuuId) then return false, "invalid_bijuu_id" end
    local rec = Registry.getRecord(bijuuId)
    if not rec then return false, "not_found" end
    if rec.state ~= BijuuState.WILD_DORMANT then return false, "must_be_wild_dormant" end

    local loc, rsn = SpawnServer.findValidWildLocation(bijuuId, { allowOtherRegions = true })
    if not loc then return false, rsn end

    local okPatch, patchRsn = Registry.patch(bijuuId, BijuuState.WILD_DORMANT, {
        world = loc,
    }, "debug_reroll_location")

    if okPatch then
        log("debug rerolled wild location for " .. tostring(bijuuId) .. " to (" .. tostring(loc.x) .. "," .. tostring(loc.y) .. ")")
        return true, "ok", loc
    end
    return false, patchRsn
end

-- ============================================================================
-- Event Registrations
-- ============================================================================

local function onZombieDead(zombie)
    LifecycleServer.onZombieNinjaDead(zombie)
end

local function onDeadBodySpawn(body)
    LifecycleServer.onDeadBodySpawn(body)
end

Support.registerDebugAction("force_release", function(player)
    return LifecycleServer.debugForceNextZombieNinjaReveal(player)
end)

Support.registerDebugAction("defeat_boss", function(player, args)
    local ok, reason = LifecycleServer.debugForceDefeatActiveBoss(player, args.bijuuId)
    return ok, reason, { bijuuId = args.bijuuId }
end)

Support.registerDebugAction("reroll_wild", function(player, args)
    local ok, reason, location = LifecycleServer.debugRerollWildLocation(player, args.bijuuId)
    return ok, reason, {
        bijuuId = args.bijuuId,
        location = location,
    }
end)

NinjaLineages.addEventOnce(
    "server.bijuuLifecycle.onZombieDead",
    Events.OnZombieDead,
    onZombieDead
)

if Events and Events.OnDeadBodySpawn then
    NinjaLineages.addEventOnce(
        "server.bijuuLifecycle.onDeadBodySpawn",
        Events.OnDeadBodySpawn,
        onDeadBodySpawn
    )
end

if Events and Events.EveryOneMinute then
    NinjaLineages.addEventOnce(
        "server.bijuuLifecycle.pruneCorpseSuppressions",
        Events.EveryOneMinute,
        pruneCorpseSuppressions
    )
end

if Events and Events.OnGameTimeLoaded then
    NinjaLineages.addEventOnce(
        "server.bijuuLifecycle.onGameTimeLoaded",
        Events.OnGameTimeLoaded,
        function()
            LifecycleServer.reconcileOnStartup()
        end
    )
end
