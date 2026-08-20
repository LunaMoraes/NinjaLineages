require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "NinjaLineages_Balance"
require "disciplines/jinchuuriki/NinjaLineages_BijuuDefinitions"
require "disciplines/jinchuuriki/NinjaLineages_BijuuState"
require "disciplines/jinchuuriki/NinjaLineages_BijuuBoss"
require "jinchuuriki/NinjaLineages_BijuuRegistryServer"
require "jinchuuriki/NinjaLineages_BijuuBossServer"
require "jinchuuriki/NinjaLineages_BijuuServerSupport"

NinjaLineages = NinjaLineages or {}
NinjaLineages.BijuuSpawnServer = NinjaLineages.BijuuSpawnServer or {}

local SpawnServer = NinjaLineages.BijuuSpawnServer
local Definitions = NinjaLineages.BijuuDefinitions
local BijuuState = NinjaLineages.BijuuState
local Registry = NinjaLineages.BijuuRegistryServer
local BossServer = NinjaLineages.BijuuBossServer
local Support = NinjaLineages.BijuuServerSupport

local lastPersistCheckGameMinutes = 0
local lastStreamCheckGameMinutes = 0

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

function SpawnServer.checkFootprintState(x, y, z)
    if (tonumber(z) or 0) ~= 0 then return "INVALID" end
    local cell = getCell()
    if not cell then return "UNLOADED" end

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

    local function isWaterSquare(sq)
        if not sq then return false end
        if sq.has and sq:has(IsoFlagType.water) then return true end
        local props = sq.getProperties and sq:getProperties()
        if props and props.has and props:has(IsoFlagType.water) then return true end
        if props and props.Is and props:Is(IsoFlagType.water) then return true end
        return false
    end

    local hasUnloaded = false
    for _, off in ipairs(sampleOffsets) do
        local checkX = math.floor(x + off.x)
        local checkY = math.floor(y + off.y)
        local sq = cell:getGridSquare(checkX, checkY, 0)
        if not sq then
            hasUnloaded = true
        else
            if sq.getRoom and sq:getRoom() ~= nil then return "INVALID" end
            if sq.getBuilding and sq:getBuilding() ~= nil then return "INVALID" end
            if sq.has and sq:has(IsoFlagType.solid) then return "INVALID" end
            if sq.has and sq:has(IsoFlagType.solidtrans) then return "INVALID" end
            if sq.isSolid and sq:isSolid() then return "INVALID" end
            if sq.isSolidTrans and sq:isSolidTrans() then return "INVALID" end
            if isWaterSquare(sq) then return "INVALID" end
            if sq.testCollideSpecialObjects and sq:testCollideSpecialObjects(nil) then return "INVALID" end
        end
    end

    if hasUnloaded then
        return "UNLOADED"
    end

    return "VALID"
end

function SpawnServer.findValidWildLocation(bijuuId, options)
    options = options or {}
    local minDistance = options.minDistance or 0
    local previousPos = options.previousPos
    local cfg = getWildConfig()

    local primaryRegionId = cfg.BIJUU_REGION_MAP and cfg.BIJUU_REGION_MAP[bijuuId]
    local regionList = {}

    if primaryRegionId and cfg.REGIONS and cfg.REGIONS[primaryRegionId] then
        table.insert(regionList, cfg.REGIONS[primaryRegionId])
    end

    if options.allowOtherRegions and cfg.REGIONS then
        for rId, reg in pairs(cfg.REGIONS) do
            if rId ~= primaryRegionId then
                table.insert(regionList, reg)
            end
        end
    end

    if #regionList == 0 then
        return nil, "no_regions_available"
    end

    local fallbackCandidate = nil

    for _, region in ipairs(regionList) do
        local startX = region.defaultX or math.floor((region.minX + region.maxX) / 2)
        local startY = region.defaultY or math.floor((region.minY + region.maxY) / 2)

        -- Search candidate points with jitter steps
        for step = 0, 40, 5 do
            for dx = -step, step, 5 do
                for dy = -step, step, 5 do
                    local candX = startX + dx
                    local candY = startY + dy
                    if candX >= region.minX and candX <= region.maxX and candY >= region.minY and candY <= region.maxY then
                        local distOk = true
                        if previousPos and minDistance > 0 then
                            local dX = candX - previousPos.x
                            local dY = candY - previousPos.y
                            if math.sqrt(dX * dX + dY * dY) < minDistance then
                                distOk = false
                            end
                        end

                        if distOk then
                            local st = SpawnServer.checkFootprintState(candX, candY, 0)
                            if st == "VALID" then
                                return {
                                    x = candX,
                                    y = candY,
                                    z = 0,
                                    regionId = region.id or "wilderness_unknown",
                                    verified = true,
                                }, "ok"
                            elseif st == "UNLOADED" and not fallbackCandidate then
                                fallbackCandidate = {
                                    x = candX,
                                    y = candY,
                                    z = 0,
                                    regionId = region.id or "wilderness_unknown",
                                    verified = false,
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    if fallbackCandidate then
        return fallbackCandidate, "unloaded_region_candidate"
    end

    return nil, "no_valid_location_found"
end

function SpawnServer.assignMissingWildLocations()
    local wildIds = Registry.getWildBijuuIds()
    local assignedCount = 0

    for _, bijuuId in ipairs(wildIds) do
        local record = Registry.getRecord(bijuuId)
        if record and record.state == BijuuState.WILD_DORMANT and not record.world then
            local loc, rsn = SpawnServer.findValidWildLocation(bijuuId)
            if loc then
                local okPatch, patchRsn = Registry.patch(bijuuId, BijuuState.WILD_DORMANT, {
                    world = loc,
                }, "initial_wild_placement")

                if okPatch then
                    assignedCount = assignedCount + 1
                    log("assigned wild location for " .. tostring(bijuuId) .. " at (" .. tostring(loc.x) .. "," .. tostring(loc.y) .. ",0) in " .. tostring(loc.regionId) .. " verified=" .. tostring(loc.verified))
                else
                    log("failed to patch wild location for " .. tostring(bijuuId) .. ": " .. tostring(patchRsn))
                end
            else
                log("failed to find wild location candidate for " .. tostring(bijuuId) .. ": " .. tostring(rsn))
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

    local fpState = SpawnServer.checkFootprintState(wx, wy, wz)
    if fpState == "UNLOADED" then
        return false, "chunk_not_loaded"
    end

    if fpState == "INVALID" then
        -- Attempt local jitter search in loaded cell (+-10 tiles, step 2) for an adjacent clear square
        local resolved = false
        for dx = -10, 10, 2 do
            for dy = -10, 10, 2 do
                if SpawnServer.checkFootprintState(wx + dx, wy + dy, 0) == "VALID" then
                    wx = wx + dx
                    wy = wy + dy
                    resolved = true
                    Registry.patch(bijuuId, BijuuState.WILD_DORMANT, {
                        world = {
                            x = wx,
                            y = wy,
                            z = 0,
                            regionId = record.world.regionId,
                            verified = true,
                        }
                    }, "relocated_to_valid_loaded_footprint")
                    break
                end
            end
            if resolved then break end
        end

        if not resolved then
            log("rejected wild materialize for " .. tostring(bijuuId) .. ": invalid loaded footprint at (" .. tostring(wx) .. "," .. tostring(wy) .. ")")
            return false, "invalid_footprint"
        end
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

function SpawnServer.reconcileOnStartup()
    if not Support.isAuthoritative() then return end
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

function SpawnServer.update()
    if not Support.isAuthoritative() then return end
    local now = NinjaLineages.Utils.Time.gameMinutes()
    local cfg = getWildConfig()
    local persistInterval = cfg.POSITION_PERSIST_INTERVAL_GAME_MINUTES or 0.5
    local streamInterval = cfg.STREAM_SCAN_INTERVAL_GAME_MINUTES or 0.05
    local minDistance = cfg.POSITION_PERSIST_MIN_DISTANCE or 2.0

    local shouldCheckPersist = (now - lastPersistCheckGameMinutes) >= persistInterval
    local shouldCheckStreaming = (now - lastStreamCheckGameMinutes) >= streamInterval
    if not shouldCheckPersist and not shouldCheckStreaming then return end

    local wildIds = Registry.getWildBijuuIds()
    for _, bijuuId in ipairs(wildIds) do
        local record = Registry.getRecord(bijuuId)
        if record then
            if shouldCheckStreaming and record.state == BijuuState.WILD_DORMANT and record.world then
                -- Check if dormant wild beast location is loaded in cell or near a player
                if SpawnServer.isLocationLoaded(record.world.x, record.world.y, record.world.z) then
                    SpawnServer.tryMaterializeWildBijuu(bijuuId)
                end
            elseif record.state == BijuuState.WILD_ACTIVE then
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
                    if shouldCheckStreaming and snap.phase ~= "defeated" then
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
    end

    if shouldCheckPersist then
        lastPersistCheckGameMinutes = now
    end
    if shouldCheckStreaming then
        lastStreamCheckGameMinutes = now
    end
end

-- ============================================================================
-- Debug Commands & Handlers
-- ============================================================================

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

    local snapshot = BossServer.getActiveBossSnapshot(bijuuId)
    local destination = snapshot or record.world
    local safeOffset = (getWildConfig().FOOTPRINT_RADIUS or 2.5) + 3.0
    NinjaLineages.Utils.Movement.placeEntity(
        player,
        destination.x + safeOffset,
        destination.y,
        destination.z or 0
    )

    local status = snapshot and "already_active" or "pending_chunk_load"
    if not snapshot and record.state == BijuuState.WILD_DORMANT
            and SpawnServer.isLocationLoaded(record.world.x, record.world.y, record.world.z) then
        local materialized, materializeReason = SpawnServer.tryMaterializeWildBijuu(bijuuId)
        status = materialized and "materialized" or materializeReason
    end
    if player.Say then
        player:Say("Teleported near " .. tostring(bijuuId)
            .. " (" .. tostring(status) .. ").")
    end
    return true, status
end

function SpawnServer.debugForceReconciliation(player)
    SpawnServer.reconcileOnStartup()
    if player and player.Say then
        player:Say("Forced wild Bijū world reconciliation.")
    end
    return true, "ok"
end

Support.registerDebugAction("assign_wild", function(player)
    local ok, reason, count = SpawnServer.debugAssignMissingLocations(player)
    return ok, reason, { count = count }
end)

Support.registerDebugAction("teleport_wild", function(player, args)
    local ok, reason = SpawnServer.debugTeleportToWild(player, args.bijuuId)
    return ok, reason, { bijuuId = args.bijuuId }
end)

Support.registerDebugAction("reconcile_world", function(player)
    return SpawnServer.debugForceReconciliation(player)
end)
