require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "disciplines/jinchuuriki/NinjaLineages_BijuuDefinitions"
require "disciplines/jinchuuriki/NinjaLineages_BijuuState"

NinjaLineages = NinjaLineages or {}
NinjaLineages.BijuuRegistryServer = NinjaLineages.BijuuRegistryServer or {}

local Server = NinjaLineages.BijuuRegistryServer
local Definitions = NinjaLineages.BijuuDefinitions
local BijuuState = NinjaLineages.BijuuState

local state = nil

local function log(message)
    print("[NL-BIJUU-REGISTRY] " .. tostring(message))
end

local function defaultState()
    local root = {
        schemaVersion = BijuuState.SCHEMA_VERSION,
        bijuu = {},
    }
    for _, id in ipairs(Definitions.Order) do
        root.bijuu[id] = {
            state = BijuuState.getInitialState(id),
            world = nil,
            host = nil,
            vessel = nil,
        }
    end
    return root
end

local migrations = {
    -- Future migrations will be placed here:
    -- [2] = function(persistedState) ... end
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

function Server.getAllRecordsSnapshot()
    local current = getState()
    local result = {}
    for _, id in ipairs(Definitions.Order) do
        local rec = current.bijuu and current.bijuu[id]
        if rec then
            result[id] = BijuuState.deepCopy(rec)
        end
    end
    return result
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

    Server.ensureState()
    for _, id in ipairs(Definitions.Order) do
        state.bijuu[id] = {
            state = BijuuState.getInitialState(id),
            world = nil,
            host = nil,
            vessel = nil,
        }
    end
    log("reset registry to canonical initial state (9 bijuu)")
    return true, "ok"
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

    if command == "debugBijuuDump" then
        if not canUseDebugCommands(player) then return end
        Server.dumpRegistry()
        if NinjaLineages.isServer() then
            sendServerCommand(player, "NinjaLineages", "debugResult", {
                ok = true,
                action = "bijuuDump",
            })
        elseif player and player.Say then
            player:Say("Bijū registry dumped to console.")
        end
    elseif command == "debugBijuuReset" then
        if not canUseDebugCommands(player) then return end
        local ok, reason = Server.resetRegistryDebug(true)
        if NinjaLineages.isServer() then
            sendServerCommand(player, "NinjaLineages", "debugResult", {
                ok = ok,
                action = "bijuuReset",
                reason = reason,
            })
        elseif player and player.Say then
            player:Say("Bijū registry reset to initial canonical state.")
        end
    elseif command == "debugBijuuTransition" then
        if not canUseDebugCommands(player) then return end
        local bijuuId = args and args.bijuuId
        local expectedState = args and args.expectedState
        local newState = args and args.newState
        local patch = args and args.patch
        local reason = args and args.reason or "debug_client_command"
        local ok, resultReason = Server.transition(bijuuId, expectedState, newState, patch, reason)
        if NinjaLineages.isServer() then
            sendServerCommand(player, "NinjaLineages", "debugResult", {
                ok = ok,
                action = "bijuuTransition",
                bijuuId = bijuuId,
                newState = newState,
                reason = resultReason,
            })
        elseif player and player.Say then
            player:Say(ok and ("Transitioned " .. tostring(bijuuId) .. " to " .. tostring(newState))
                or ("Transition rejected: " .. tostring(resultReason)))
        end
    end
end

local function onInitGlobalModData(isNewGame)
    Server.ensureState()
    log("initialized schema=" .. tostring(state and state.schemaVersion or BijuuState.SCHEMA_VERSION) .. " records=9")
end

NinjaLineages.addEventOnce(
    "server.bijuu.onInitGlobalModData",
    Events.OnInitGlobalModData,
    onInitGlobalModData
)

NinjaLineages.addEventOnce(
    "server.bijuu.onClientCommand",
    Events.OnClientCommand,
    onClientCommand
)
