require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "NinjaLineages_Balance"
require "disciplines/jinchuuriki/NinjaLineages_BijuuDefinitions"
require "disciplines/jinchuuriki/NinjaLineages_BijuuState"
require "jinchuuriki/NinjaLineages_BijuuRegistryServer"
require "jinchuuriki/NinjaLineages_BijuuBossServer"
require "jinchuuriki/NinjaLineages_BijuuSpawnServer"

NinjaLineages = NinjaLineages or {}
NinjaLineages.BijuuLifecycleServer = NinjaLineages.BijuuLifecycleServer or {}

local LifecycleServer = NinjaLineages.BijuuLifecycleServer
local Definitions = NinjaLineages.BijuuDefinitions
local BijuuState = NinjaLineages.BijuuState
local Registry = NinjaLineages.BijuuRegistryServer
local BossServer = NinjaLineages.BijuuBossServer
local SpawnServer = NinjaLineages.BijuuSpawnServer

local pendingCorpseSuppression = {}
local forceNextReveal = false

local function log(message)
    print("[NL-BIJUU-LIFECYCLE] " .. tostring(message))
end

local function isServerAuthority()
    if isClient and isClient() and not (isServer and isServer()) then
        return false
    end
    return true
end

local function getCorpseKey(x, y, z)
    return tostring(math.floor(x or 0)) .. ":" .. tostring(math.floor(y or 0)) .. ":" .. tostring(math.floor(z or 0))
end

local function getReleaseConfig()
    return NinjaLineages.Balance and NinjaLineages.Balance.Jinchuuriki and NinjaLineages.Balance.Jinchuuriki.Release or {
        ZOMBIE_NINJA_REVEAL_CHANCE = 0.01,
        RESPAWN_MIN_DISTANCE_FROM_DEATH = 350.0,
        CORPSE_SUPPRESSION_TIMEOUT_MINUTES = 0.5,
        MELEE_SWING_MIN_INTERVAL_GAME_MINUTES = 0.005,
    }
end

function LifecycleServer.getPendingCorpseSuppression()
    return pendingCorpseSuppression
end

function LifecycleServer.setForceNextReveal(value)
    forceNextReveal = (value == true)
end

function LifecycleServer.onZombieNinjaDead(zombie, attacker)
    if not isServerAuthority() then return end
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
    local key = getCorpseKey(zx, zy, zz)
    pendingCorpseSuppression[key] = {
        bijuuId = claimedId,
        runtimeId = runtime.runtimeId,
        timestamp = NinjaLineages.Utils.Time.gameMinutes(),
    }

    log("zombie_ninja_reveal roll=success bijuu=" .. tostring(claimedId) .. " pos=(" .. tostring(zx) .. "," .. tostring(zy) .. "," .. tostring(zz) .. ") runtime=" .. tostring(runtime.runtimeId))
end

function LifecycleServer.onDeadBodySpawn(body)
    if not isServerAuthority() then return end
    if not body or not instanceof(body, "IsoDeadBody") then return end

    local bx = body:getX()
    local by = body:getY()
    local bz = body:getZ()
    local key = getCorpseKey(bx, by, bz)

    local pending = pendingCorpseSuppression[key]
    if pending then
        local now = NinjaLineages.Utils.Time.gameMinutes()
        local cfg = getReleaseConfig()
        local timeout = cfg.CORPSE_SUPPRESSION_TIMEOUT_MINUTES or 0.5

        if (now - pending.timestamp) <= timeout then
            pcall(function()
                if body.removeFromWorld then body:removeFromWorld() end
                if body.removeFromSquare then body:removeFromSquare() end
            end)
            log("suppressed zombie ninja corpse for released bijuu=" .. tostring(pending.bijuuId) .. " at (" .. tostring(bx) .. "," .. tostring(by) .. ")")
        end
        pendingCorpseSuppression[key] = nil
    end
end

function LifecycleServer.handleBossDefeated(bijuuId, runtimeId, position)
    if not isServerAuthority() then return end
    if not Definitions.isValidId(bijuuId) then return end

    local def = Definitions.get(bijuuId)
    if not def then return end

    local pos = position or { x = 0, y = 0, z = 0 }

    if def.nativeSpawnType == "host" then
        -- 1–3 Tails (Low Tails): Dematerialize & Return to HOST_POOL
        BossServer.dematerialize(bijuuId, runtimeId, "boss_defeated")
        Registry.transition(
            bijuuId,
            BijuuState.BOSS_ACTIVE,
            BijuuState.HOST_POOL,
            { world = false, host = false, vessel = false },
            "boss_defeated_host_return"
        )
        log("boss_defeated bijuu=" .. tostring(bijuuId) .. " native=host -> returned_to_host_pool")
    else
        -- 4–9 Tails (Wild Beasts): WILD_ACTIVE -> RESPAWNING -> WILD_DORMANT at new location
        Registry.transition(
            bijuuId,
            BijuuState.WILD_ACTIVE,
            BijuuState.RESPAWNING,
            nil,
            "boss_defeated_wild_respawn"
        )

        BossServer.dematerialize(bijuuId, runtimeId, "boss_defeated")

        local cfg = getReleaseConfig()
        local minSeparation = cfg.RESPAWN_MIN_DISTANCE_FROM_DEATH or 350.0

        local newLoc, rsn = SpawnServer.findValidWildLocation(bijuuId, {
            minDistance = minSeparation,
            previousPos = pos,
            allowOtherRegions = true,
        })

        if newLoc then
            Registry.transition(
                bijuuId,
                BijuuState.RESPAWNING,
                BijuuState.WILD_DORMANT,
                { world = newLoc },
                "respawn_location_assigned"
            )
            log("boss_defeated bijuu=" .. tostring(bijuuId) .. " native=wild -> respawn_location pos=(" .. tostring(newLoc.x) .. "," .. tostring(newLoc.y) .. ") region=" .. tostring(newLoc.regionId))
        else
            log("wild respawn location search pending for " .. tostring(bijuuId) .. ": " .. tostring(rsn))
        end
    end
end

function LifecycleServer.reconcileOnStartup()
    if not isServerAuthority() then return end

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

    -- 2. Reconcile wild respawning orphans (RESPAWNING -> WILD_DORMANT at new location)
    for _, bijuuId in ipairs(Registry.getWildBijuuIds()) do
        local rec = Registry.getRecord(bijuuId)
        if rec and rec.state == BijuuState.RESPAWNING then
            local loc, rsn = SpawnServer.findValidWildLocation(bijuuId, { allowOtherRegions = true })
            if loc then
                log("reconciled RESPAWNING -> WILD_DORMANT for " .. tostring(bijuuId) .. " at (" .. tostring(loc.x) .. "," .. tostring(loc.y) .. ")")
                Registry.transition(
                    bijuuId,
                    BijuuState.RESPAWNING,
                    BijuuState.WILD_DORMANT,
                    { world = loc },
                    "startup_reconcile"
                )
            else
                log("startup reconciliation: wild respawn location search failed for " .. tostring(bijuuId) .. ": " .. tostring(rsn))
            end
        end
    end
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

local function canUseDebugCommands(player)
    if not (SandboxVars
            and SandboxVars.NinjaLineages
            and SandboxVars.NinjaLineages.DebugMode == true) then
        return false
    end

    if NinjaLineages.isSinglePlayer and NinjaLineages.isSinglePlayer() then
        return true
    end

    local ok, accessLevel = pcall(function() return player:getAccessLevel() end)
    return ok and string.lower(tostring(accessLevel or "")) == "admin"
end

local function onClientCommand(module, command, player, args)
    if module ~= "NinjaLineages" then return end

    if command == "debugForceNextZombieNinjaReveal" then
        if not canUseDebugCommands(player) then return end
        local ok, reason = LifecycleServer.debugForceNextZombieNinjaReveal(player)
        if NinjaLineages.isServer() then
            sendServerCommand(player, "NinjaLineages", "debugResult", {
                ok = ok,
                action = "debugForceNextZombieNinjaReveal",
                reason = reason,
            })
        elseif player and player.Say then
            player:Say("Enabled forced Zombie Ninja Bijū reveal on next death.")
        end
    elseif command == "debugForceDefeatActiveBoss" then
        if not canUseDebugCommands(player) then return end
        local bijuuId = args and args.bijuuId
        local ok, reason = LifecycleServer.debugForceDefeatActiveBoss(player, bijuuId)
        if NinjaLineages.isServer() then
            sendServerCommand(player, "NinjaLineages", "debugResult", {
                ok = ok,
                action = "debugForceDefeatActiveBoss",
                bijuuId = bijuuId,
                reason = reason,
            })
        elseif player and player.Say then
            player:Say(ok and ("Defeated active boss: " .. tostring(bijuuId)) or ("Defeat failed: " .. tostring(reason)))
        end
    elseif command == "debugRerollWildLocation" then
        if not canUseDebugCommands(player) then return end
        local bijuuId = args and args.bijuuId
        local ok, reason, loc = LifecycleServer.debugRerollWildLocation(player, bijuuId)
        if NinjaLineages.isServer() then
            sendServerCommand(player, "NinjaLineages", "debugResult", {
                ok = ok,
                action = "debugRerollWildLocation",
                bijuuId = bijuuId,
                reason = reason,
                location = loc,
            })
        elseif player and player.Say then
            player:Say(ok and ("Rerolled location for " .. tostring(bijuuId)) or ("Reroll failed: " .. tostring(reason)))
        end
    end
end

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

if Events and Events.OnGameTimeLoaded then
    NinjaLineages.addEventOnce(
        "server.bijuuLifecycle.onGameTimeLoaded",
        Events.OnGameTimeLoaded,
        function()
            LifecycleServer.reconcileOnStartup()
        end
    )
end

NinjaLineages.addEventOnce(
    "server.bijuuLifecycle.onClientCommand",
    Events.OnClientCommand,
    onClientCommand
)
