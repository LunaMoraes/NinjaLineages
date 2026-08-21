require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "disciplines/jinchuuriki/NinjaLineages_BijuuDefinitions"
require "disciplines/jinchuuriki/NinjaLineages_BijuuState"
require "jinchuuriki/NinjaLineages_BijuuServerSupport"

NinjaLineages = NinjaLineages or {}
NinjaLineages.BijuuRegistryServer = NinjaLineages.BijuuRegistryServer or {}

local Server = NinjaLineages.BijuuRegistryServer
local Definitions = NinjaLineages.BijuuDefinitions
local BijuuState = NinjaLineages.BijuuState
local Support = NinjaLineages.BijuuServerSupport

local state = nil

local allowedTransitions = {
    [BijuuState.HOST_POOL] = {
        [BijuuState.BOSS_ACTIVE] = true,
    },
    [BijuuState.WILD_DORMANT] = {
        [BijuuState.WILD_ACTIVE] = true,
    },
    [BijuuState.WILD_ACTIVE] = {
        [BijuuState.WILD_DORMANT] = true,
        [BijuuState.RESPAWNING] = true,
        [BijuuState.SEALING] = true,
    },
    [BijuuState.BOSS_ACTIVE] = {
        [BijuuState.HOST_POOL] = true,
        [BijuuState.RESPAWNING] = true,
        [BijuuState.SEALING] = true,
        [BijuuState.SEALED_VESSEL] = true,
    },
    [BijuuState.RESPAWNING] = {
        [BijuuState.WILD_DORMANT] = true,
    },
    [BijuuState.SEALING] = {
        [BijuuState.WILD_ACTIVE] = true,
        [BijuuState.BOSS_ACTIVE] = true,
        [BijuuState.SEALED_VESSEL] = true,
        [BijuuState.SEALED_PLAYER] = true,
    },
    [BijuuState.SEALED_VESSEL] = {
        [BijuuState.BOSS_ACTIVE] = true,
        [BijuuState.HOST_POOL] = true,
        [BijuuState.RESPAWNING] = true,
        [BijuuState.SEALED_PLAYER] = true,
    },
    [BijuuState.SEALED_PLAYER] = {
        [BijuuState.SEALING] = true,
        [BijuuState.SEALED_VESSEL] = true,
        [BijuuState.BOSS_ACTIVE] = true,
    },
}

local function log(message)
    print("[NL-BIJUU-REGISTRY] " .. tostring(message))
end

local migrations = {
    [2] = function(persistedState)
        for _, record in pairs(persistedState.bijuu or {}) do
            if record.sealing ~= nil and type(record.sealing) ~= "table" then
                record.sealing = nil
            end
        end
    end,
}

function Server.normalize()
    if not state then return end

    if state.schemaVersion == nil then
        state.schemaVersion = BijuuState.SCHEMA_VERSION
    end

    if state.schemaVersion > BijuuState.SCHEMA_VERSION then
        log("WARNING: persistent schemaVersion (" .. tostring(state.schemaVersion)
            .. ") is newer than code schemaVersion (" .. tostring(BijuuState.SCHEMA_VERSION)
            .. "). Skipping destructive normalization.")
        return
    end

    while state.schemaVersion < BijuuState.SCHEMA_VERSION do
        local nextVersion = state.schemaVersion + 1
        local migrationFn = migrations[nextVersion]
        if migrationFn then
            log("Running migration to schemaVersion=" .. tostring(nextVersion))
            local ok, err = pcall(migrationFn, state)
            if not ok then
                log("ERROR: migration to version " .. tostring(nextVersion) .. " failed: " .. tostring(err))
                break
            end
        end
        state.schemaVersion = nextVersion
    end

    state.bijuu = state.bijuu or {}

    -- Ensure all canonical Bijū exist and have a valid state
    for _, id in ipairs(Definitions.Order) do
        local rec = state.bijuu[id]
        if not rec or type(rec) ~= "table" then
            local initState = BijuuState.getInitialState(id)
            state.bijuu[id] = {
                state = initState,
                world = nil,
                host = nil,
                vessel = nil,
                sealing = nil,
            }
            log("repaired missing record=" .. tostring(id) .. " state=" .. tostring(initState))
        else
            if not BijuuState.isValidState(rec.state) then
                local oldState = rec.state
                local initState = BijuuState.getInitialState(id)
                rec.state = initState
                log("repaired invalid state for " .. tostring(id) .. ": " .. tostring(oldState) .. " -> " .. tostring(initState))
            end
        end
    end

    -- Remove any unknown / non-canonical keys in schema v1
    for id in pairs(state.bijuu) do
        if not Definitions.isValidId(id) then
            log("removed unknown bijuu record: " .. tostring(id))
            state.bijuu[id] = nil
        end
    end
end

local function getState()
    if not state then
        Server.ensureState()
    end
    return state
end

local function getRecordInternal(bijuuId)
    local current = getState()
    return current.bijuu and current.bijuu[bijuuId] or nil
end

function Server.ensureState()
    state = ModData.getOrCreate(BijuuState.DATA_KEY)
    Server.normalize()
    return state
end

function Server.getRecord(bijuuId)
    local rec = getRecordInternal(bijuuId)
    if not rec then return nil end
    return BijuuState.deepCopy(rec)
end

function Server.getBijuuState(bijuuId)
    local rec = getRecordInternal(bijuuId)
    return rec and rec.state or nil
end

function Server.transition(bijuuId, expectedState, newState, patch, reason)
    if not Definitions.isValidId(bijuuId) then
        log("rejected transition: invalid bijuu ID=" .. tostring(bijuuId))
        return false, "invalid_bijuu_id"
    end

    if not BijuuState.isValidState(newState) then
        log("rejected transition " .. tostring(bijuuId) .. ": invalid target state=" .. tostring(newState))
        return false, "invalid_target_state"
    end

    if not BijuuState.isValidState(expectedState) then
        log("rejected transition " .. tostring(bijuuId) .. ": invalid expected state=" .. tostring(expectedState))
        return false, "invalid_expected_state"
    end

    if newState ~= expectedState
            and not (allowedTransitions[expectedState] and allowedTransitions[expectedState][newState]) then
        log("rejected transition " .. tostring(bijuuId)
            .. ": illegal " .. tostring(expectedState) .. " -> " .. tostring(newState))
        return false, "illegal_transition"
    end

    Server.ensureState()
    local record = getRecordInternal(bijuuId)
    if not record then
        log("rejected transition " .. tostring(bijuuId) .. ": record not found in registry")
        return false, "record_not_found"
    end

    if record.state ~= expectedState then
        log("rejected transition " .. tostring(bijuuId)
            .. " expected=" .. tostring(expectedState)
            .. " actual=" .. tostring(record.state)
            .. " reason=" .. tostring(reason or "none"))
        return false, "state_mismatch"
    end

    record.state = newState

    if type(patch) == "table" then
        for key, value in pairs(patch) do
            if key ~= "state" then
                if value == false then
                    record[key] = nil
                elseif type(value) == "table" then
                    record[key] = BijuuState.deepCopy(value)
                else
                    record[key] = value
                end
            end
        end
    end

    log(tostring(bijuuId) .. " " .. tostring(expectedState) .. " -> " .. tostring(newState) .. " reason=" .. tostring(reason or "none"))
    return true, "ok"
end

function Server.patch(bijuuId, expectedState, patch, reason)
    return Server.transition(bijuuId, expectedState, expectedState, patch, reason or "patch")
end

function Server.getWildBijuuIds()
    local result = {}
    for _, id in ipairs(Definitions.Order) do
        local def = Definitions.get(id)
        if def and def.nativeSpawnType == "wild" then
            table.insert(result, id)
        end
    end
    return result
end

function Server.getHostPoolBijuuIds()
    Server.ensureState()
    local result = {}
    for _, id in ipairs(Definitions.Order) do
        local rec = getRecordInternal(id)
        if rec and rec.state == BijuuState.HOST_POOL then
            table.insert(result, id)
        end
    end
    return result
end

function Server.getHostedBijuuIds(playerKey)
    local result = {}
    if type(playerKey) ~= "string" or playerKey == "" then return result end
    Server.ensureState()
    for _, id in ipairs(Definitions.Order) do
        local rec = getRecordInternal(id)
        if rec and rec.state == BijuuState.SEALED_PLAYER
                and type(rec.host) == "table"
                and rec.host.playerKey == playerKey then
            table.insert(result, id)
        end
    end
    return result
end

function Server.dumpRegistry()
    local current = getState()
    log("--- BIJUU REGISTRY DUMP (schema=" .. tostring(current.schemaVersion) .. ") ---")
    for _, id in ipairs(Definitions.Order) do
        local rec = current.bijuu and current.bijuu[id]
        local details = ""
        if rec then
            if rec.world then
                details = details .. " pos=(" .. tostring(rec.world.x) .. "," .. tostring(rec.world.y) .. "," .. tostring(rec.world.z) .. ")"
            end
            if rec.host then
                details = details .. " host=" .. tostring(rec.host.playerKey)
            end
            if rec.vessel then
                details = details .. " vessel=" .. tostring(rec.vessel.token)
            end
            if rec.sealing then
                details = details .. " sealingSource=" .. tostring(rec.sealing.sourceState)
                    .. " runtime=" .. tostring(rec.sealing.runtimeId)
            end
            log(tostring(id) .. " state=" .. tostring(rec.state) .. details)
        else
            log(tostring(id) .. " MISSING")
        end
    end
    log("--- END DUMP ---")
end

function Server.resetRegistryDebug(force)
    local isDebug = (isDebugEnabled and isDebugEnabled())
        or (SandboxVars and SandboxVars.NinjaLineages and SandboxVars.NinjaLineages.DebugMode == true)
    if not isDebug and not force then
        log("debug reset rejected: DebugMode not active")
        return false, "not_debug"
    end

    if NinjaLineages.BijuuBossServer and NinjaLineages.BijuuBossServer.hasActiveBosses and NinjaLineages.BijuuBossServer.hasActiveBosses() then
        log("debug reset rejected: active bijuu boss runtimes exist")
        return false, "active_boss_exists"
    end

    Server.ensureState()
    for _, id in ipairs(Definitions.Order) do
        state.bijuu[id] = {
            state = BijuuState.getInitialState(id),
            world = nil,
            host = nil,
            vessel = nil,
            sealing = nil,
        }
    end
    log("reset registry to canonical initial state (9 bijuu)")
    return true, "ok"
end

Support.registerDebugAction("dump_registry", function()
    Server.dumpRegistry()
    return true, "ok"
end)

Support.registerDebugAction("reset_registry", function()
    return Server.resetRegistryDebug(true)
end)

Support.registerDebugAction("transition", function(_, args)
    local ok, reason = Server.transition(
        args.bijuuId,
        args.expectedState,
        args.newState,
        args.patch,
        args.reason or "debug_client_command"
    )
    return ok, reason, {
        bijuuId = args.bijuuId,
        newState = args.newState,
    }
end)

local function onInitGlobalModData(isNewGame)
    Server.ensureState()
    log("initialized schema=" .. tostring(state and state.schemaVersion or BijuuState.SCHEMA_VERSION) .. " records=9")
end

NinjaLineages.addEventOnce(
    "server.bijuu.onInitGlobalModData",
    Events.OnInitGlobalModData,
    onInitGlobalModData
)
