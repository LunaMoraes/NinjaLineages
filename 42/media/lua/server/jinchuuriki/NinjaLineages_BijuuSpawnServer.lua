require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "NinjaLineages_Balance"
require "disciplines/jinchuuriki/NinjaLineages_BijuuDefinitions"
require "disciplines/jinchuuriki/NinjaLineages_BijuuState"
require "disciplines/jinchuuriki/NinjaLineages_BijuuBoss"
require "jinchuuriki/NinjaLineages_BijuuRegistryServer"
require "jinchuuriki/NinjaLineages_BijuuBossServer"

NinjaLineages = NinjaLineages or {}
NinjaLineages.BijuuSpawnServer = NinjaLineages.BijuuSpawnServer or {}

local SpawnServer = NinjaLineages.BijuuSpawnServer
local Definitions = NinjaLineages.BijuuDefinitions
local BijuuState = NinjaLineages.BijuuState
local Registry = NinjaLineages.BijuuRegistryServer
local BossServer = NinjaLineages.BijuuBossServer

local lastPersistCheckGameMinutes = 0

local function log(message)
    print("[NL-BIJUU-SPAWN] " .. tostring(message))
end

local function getWildConfig()
    return NinjaLineages.Balance and NinjaLineages.Balance.Jinchuuriki and NinjaLineages.Balance.Jinchuuriki.WildSpawn or {
        FOOTPRINT_RADIUS = 2.5,
        POSITION_PERSIST_INTERVAL_GAME_MINUTES = 0.5,
        POSITION_PERSIST_MIN_DISTANCE = 2.0,
        REGIONS = {},
        BIJUU_REGION_MAP = {},
    }
end

function SpawnServer.isValidFootprint(x, y, z)
    if (tonumber(z) or 0) ~= 0 then return false end
    local cell = getCell()
    if not cell then return true end

    local cfg = getWildConfig()
    local radius = cfg.FOOTPRINT_RADIUS or 2.5

    local sampleOffsets = {
        { x = 0, y = 0 },
        { x = -radius, y = 0 },
        { x = radius, y = 0 },
        { x = 0, y = -radius },
        { x = 0, y = radius },
        { x = -radius * 0.7, y = -radius * 0.7 },
        { x = radius * 0.7, y = -radius * 0.7 },
        { x = -radius * 0.7, y = radius * 0.7 },
        { x = radius * 0.7, y = radius * 0.7 },
    }

    for _, off in ipairs(sampleOffsets) do
        local checkX = math.floor(x + off.x)
        local checkY = math.floor(y + off.y)
        local sq = cell:getGridSquare(checkX, checkY, 0)
        if sq then
            if sq.getRoom and sq:getRoom() ~= nil then return false end
            if sq.getBuilding and sq:getBuilding() ~= nil then return false end
            if sq.isSolid and sq:isSolid() then return false end
            if sq.isSolidTrans and sq:isSolidTrans() then return false end
            if sq.getProperties and sq:getProperties():Is(IsoFlagType.water) then return false end
            if sq.testCollideSpecialObjects and sq:testCollideSpecialObjects(nil) then return false end
        end
    end

    return true
end

function SpawnServer.assignMissingWildLocations()
    local wildIds = Registry.getWildBijuuIds()
    local cfg = getWildConfig()
    local assignedCount = 0

    for _, bijuuId in ipairs(wildIds) do
        local record = Registry.getRecord(bijuuId)
        if record and record.state == BijuuState.WILD_DORMANT and not record.world then
            local regionId = cfg.BIJUU_REGION_MAP and cfg.BIJUU_REGION_MAP[bijuuId]
            local region = regionId and cfg.REGIONS and cfg.REGIONS[regionId]

            local posX = region and region.defaultX or 10000
            local posY = region and region.defaultY or 10000

            if not SpawnServer.isValidFootprint(posX, posY, 0) and region then
                -- Bounded jitter search for a clear exterior square
                local found = false
                for dx = -20, 20, 5 do
                    for dy = -20, 20, 5 do
                        local candX = posX + dx
                        local candY = posY + dy
                        if candX >= region.minX and candX <= region.maxX and candY >= region.minY and candY <= region.maxY then
                            if SpawnServer.isValidFootprint(candX, candY, 0) then
                                posX, posY = candX, candY
                                found = true
                                break
                            end
                        end
                    end
                    if found then break end
                end
            end

            local okPatch, rsn = Registry.patch(bijuuId, BijuuState.WILD_DORMANT, {
                world = {
                    x = posX,
                    y = posY,
                    z = 0,
                    regionId = regionId or "wilderness_unknown",
                }
            }, "initial_wild_placement")

            if okPatch then
                assignedCount = assignedCount + 1
                log("assigned wild location for " .. tostring(bijuuId) .. " at (" .. tostring(posX) .. "," .. tostring(posY) .. ",0) in " .. tostring(regionId))
            else
                log("failed to assign wild location for " .. tostring(bijuuId) .. ": " .. tostring(rsn))
            end
        end
    end

    return assignedCount
end

function SpawnServer.isLocationLoaded(x, y, z)
    local cell = getCell()
    if not cell then return false end
    local sq = cell:getGridSquare(math.floor(x), math.floor(y), math.floor(z or 0))
    return sq ~= nil
end

function SpawnServer.tryMaterializeWildBijuu(bijuuId)
    local record = Registry.getRecord(bijuuId)
    if not record or record.state ~= BijuuState.WILD_DORMANT or not record.world then
        return false, "not_wild_dormant"
    end

    local wx = record.world.x
    local wy = record.world.y
    local wz = record.world.z or 0

    if not SpawnServer.isValidFootprint(wx, wy, wz) then
        log("rejected wild materialize: invalid footprint at (" .. tostring(wx) .. "," .. tostring(wy) .. "," .. tostring(wz) .. ")")
        return false, "invalid_footprint"
    end

    -- 1. Atomically transition WILD_DORMANT -> WILD_ACTIVE
    local okTrans, transRsn = Registry.transition(
        bijuuId,
        BijuuState.WILD_DORMANT,
        BijuuState.WILD_ACTIVE,
        nil,
        "chunk_load_stream"
    )

    if not okTrans then
        log("wild transition failed for " .. tostring(bijuuId) .. ": " .. tostring(transRsn))
        return false, transRsn
    end

    -- 2. Materialize physical boss proxy
    local runtime, matRsn = BossServer.materialize(bijuuId, wx, wy, wz, {
        debugOriginalState = BijuuState.WILD_DORMANT
    })

    if not runtime then
        -- Rollback on spawn failure
        log("materialize failed for " .. tostring(bijuuId) .. " (" .. tostring(matRsn) .. "), rolling back to WILD_DORMANT")
        Registry.transition(bijuuId, BijuuState.WILD_ACTIVE, BijuuState.WILD_DORMANT, nil, "materialize_failed_rollback")
        return false, matRsn
    end

    log("streamed wild bijuu=" .. tostring(bijuuId) .. " runtime=" .. tostring(runtime.runtimeId) .. " at (" .. tostring(wx) .. "," .. tostring(wy) .. ")")
    return true, "ok", runtime
end

local function isServerAuthority()
    if isClient and isClient() and not (isServer and isServer()) then
        return false
    end
    return true
end

function SpawnServer.reconcileOnStartup()
    if not isServerAuthority() then return end
    SpawnServer.assignMissingWildLocations()

    local wildIds = Registry.getWildBijuuIds()
    for _, bijuuId in ipairs(wildIds) do
        local record = Registry.getRecord(bijuuId)
        if record then
            -- Reconcile orphaned WILD_ACTIVE (e.g. server restarted while materialized)
            if record.state == BijuuState.WILD_ACTIVE and not BossServer.getActiveBossSnapshot(bijuuId) then
                log("reconciling orphaned WILD_ACTIVE -> WILD_DORMANT for " .. tostring(bijuuId))
                Registry.transition(bijuuId, BijuuState.WILD_ACTIVE, BijuuState.WILD_DORMANT, nil, "startup_reconcile")
                record = Registry.getRecord(bijuuId)
            end

            -- Reconcile loaded area
            if record and record.state == BijuuState.WILD_DORMANT and record.world then
                if SpawnServer.isLocationLoaded(record.world.x, record.world.y, record.world.z) then
                    SpawnServer.tryMaterializeWildBijuu(bijuuId)
                end
            end
        end
    end
end

function SpawnServer.onLoadChunk(chunk)
    if not isServerAuthority() then return end
    if not chunk then return end
    local chunkWx = chunk.wx
    local chunkWy = chunk.wy
    if not chunkWx or not chunkWy then return end

    local minWorldX = chunkWx * 10
    local maxWorldX = minWorldX + 10
    local minWorldY = chunkWy * 10
    local maxWorldY = minWorldY + 10

    local wildIds = Registry.getWildBijuuIds()
    for _, bijuuId in ipairs(wildIds) do
        local record = Registry.getRecord(bijuuId)
        if record and record.state == BijuuState.WILD_DORMANT and record.world then
            local bx = record.world.x
            local by = record.world.y
            if bx >= minWorldX and bx < maxWorldX and by >= minWorldY and by < maxWorldY then
                SpawnServer.tryMaterializeWildBijuu(bijuuId)
            end
        end
    end
end

function SpawnServer.update()
    if not isServerAuthority() then return end
    local now = NinjaLineages.Utils.Time.gameMinutes()
    local cfg = getWildConfig()
    local persistInterval = cfg.POSITION_PERSIST_INTERVAL_GAME_MINUTES or 0.5
    local minDistance = cfg.POSITION_PERSIST_MIN_DISTANCE or 2.0

    local shouldCheckPersist = (now - lastPersistCheckGameMinutes) >= persistInterval

    local wildIds = Registry.getWildBijuuIds()
    for _, bijuuId in ipairs(wildIds) do
        local record = Registry.getRecord(bijuuId)
        if record and record.state == BijuuState.WILD_ACTIVE then
            local snap = BossServer.getActiveBossSnapshot(bijuuId)
            if snap then
                -- 1. Movement persistence
                if shouldCheckPersist and record.world then
                    local dx = snap.x - record.world.x
                    local dy = snap.y - record.world.y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist >= minDistance then
                        Registry.patch(bijuuId, BijuuState.WILD_ACTIVE, {
                            world = {
                                x = snap.x,
                                y = snap.y,
                                z = snap.z,
                                regionId = record.world.regionId,
                            }
                        }, "movement_sync")
                        record = Registry.getRecord(bijuuId)
                    end
                end

                -- 2. Area unload dematerialization (unless defeated, which is preserved for Slice 5)
                if snap.phase ~= "defeated" then
                    if not SpawnServer.isLocationLoaded(snap.x, snap.y, snap.z) then
                        log("area unloaded for wild bijuu=" .. tostring(bijuuId) .. ", dematerializing at (" .. tostring(snap.x) .. "," .. tostring(snap.y) .. ")")
                        BossServer.dematerialize(bijuuId, snap.runtimeId, "area_unloaded")
                        Registry.transition(bijuuId, BijuuState.WILD_ACTIVE, BijuuState.WILD_DORMANT, {
                            world = {
                                x = snap.x,
                                y = snap.y,
                                z = snap.z,
                                regionId = record.world and record.world.regionId or "wilderness_unknown",
                            }
                        }, "area_unloaded")
                    end
                end
            end
        end
    end

    if shouldCheckPersist then
        lastPersistCheckGameMinutes = now
    end
end

-- ============================================================================
-- Debug Commands & Handlers
-- ============================================================================

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

function SpawnServer.debugAssignMissingLocations(player)
    local count = SpawnServer.assignMissingWildLocations()
    if player and player.Say then
        player:Say("Assigned " .. tostring(count) .. " missing wild Bijū locations.")
    end
    return true, "ok", count
end

function SpawnServer.debugTeleportToWild(player, bijuuId)
    if not player then return false, "no_player" end
    if not Definitions.isValidId(bijuuId) then return false, "invalid_id" end

    local record = Registry.getRecord(bijuuId)
    if not record or not record.world then
        return false, "no_world_coordinate"
    end

    NinjaLineages.Utils.Movement.placeEntity(player, record.world.x, record.world.y, record.world.z or 0)
    if player.Say then
        player:Say("Teleported to " .. tostring(bijuuId) .. " wild coordinate (" .. tostring(math.floor(record.world.x)) .. "," .. tostring(math.floor(record.world.y)) .. ").")
    end
    return true, "ok"
end

function SpawnServer.debugForceReconciliation(player)
    SpawnServer.reconcileOnStartup()
    if player and player.Say then
        player:Say("Forced wild Bijū world reconciliation.")
    end
    return true, "ok"
end

local function onClientCommand(module, command, player, args)
    if module ~= "NinjaLineages" then return end

    if command == "debugBijuuAssignWild" then
        if not canUseDebugCommands(player) then return end
        local ok, rsn, count = SpawnServer.debugAssignMissingLocations(player)
        if NinjaLineages.isServer() then
            sendServerCommand(player, "NinjaLineages", "debugResult", {
                ok = ok,
                action = "bijuuAssignWild",
                count = count,
                reason = rsn,
            })
        end
    elseif command == "debugBijuuTeleportWild" then
        if not canUseDebugCommands(player) then return end
        local bijuuId = args and args.bijuuId
        local ok, rsn = SpawnServer.debugTeleportToWild(player, bijuuId)
        if NinjaLineages.isServer() then
            sendServerCommand(player, "NinjaLineages", "debugResult", {
                ok = ok,
                action = "bijuuTeleportWild",
                bijuuId = bijuuId,
                reason = rsn,
            })
        end
    elseif command == "debugBijuuReconcileWild" then
        if not canUseDebugCommands(player) then return end
        local ok, rsn = SpawnServer.debugForceReconciliation(player)
        if NinjaLineages.isServer() then
            sendServerCommand(player, "NinjaLineages", "debugResult", {
                ok = ok,
                action = "bijuuReconcileWild",
                reason = rsn,
            })
        end
    end
end

NinjaLineages.addEventOnce(
    "server.bijuuSpawn.onClientCommand",
    Events.OnClientCommand,
    onClientCommand
)

if Events and Events.LoadChunk then
    NinjaLineages.addEventOnce(
        "server.bijuuSpawn.onLoadChunk",
        Events.LoadChunk,
        function(chunk)
            SpawnServer.onLoadChunk(chunk)
        end
    )
end

if Events and Events.OnGameTimeLoaded then
    NinjaLineages.addEventOnce(
        "server.bijuuSpawn.onGameTimeLoaded",
        Events.OnGameTimeLoaded,
        function()
            SpawnServer.reconcileOnStartup()
        end
    )
end
