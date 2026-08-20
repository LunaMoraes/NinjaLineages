require "disciplines/jinchuuriki/NinjaLineages_BijuuDefinitions"

NinjaLineages = NinjaLineages or {}
NinjaLineages.BijuuState = NinjaLineages.BijuuState or {}

local BijuuState = NinjaLineages.BijuuState
local Definitions = NinjaLineages.BijuuDefinitions

BijuuState.DATA_KEY = "NinjaLineagesBijuu"
BijuuState.SCHEMA_VERSION = 1

BijuuState.HOST_POOL       = "HOST_POOL"
BijuuState.WILD_DORMANT    = "WILD_DORMANT"
BijuuState.WILD_ACTIVE     = "WILD_ACTIVE"
BijuuState.BOSS_ACTIVE     = "BOSS_ACTIVE"
BijuuState.SEALING         = "SEALING"
BijuuState.SEALED_VESSEL   = "SEALED_VESSEL"
BijuuState.SEALED_PLAYER   = "SEALED_PLAYER"
BijuuState.RESPAWNING      = "RESPAWNING"

BijuuState.ValidStates = {
    [BijuuState.HOST_POOL]       = true,
    [BijuuState.WILD_DORMANT]    = true,
    [BijuuState.WILD_ACTIVE]     = true,
    [BijuuState.BOSS_ACTIVE]     = true,
    [BijuuState.SEALING]         = true,
    [BijuuState.SEALED_VESSEL]   = true,
    [BijuuState.SEALED_PLAYER]   = true,
    [BijuuState.RESPAWNING]      = true,
}

function BijuuState.isValidState(state)
    if not state then return false end
    return BijuuState.ValidStates[state] == true
end

function BijuuState.isValidBijuuId(id)
    return Definitions.isValidId(id)
end

function BijuuState.getDefinition(id)
    return Definitions.get(id)
end

function BijuuState.getInitialState(id)
    local def = Definitions.get(id)
    if not def then return nil end
    if def.nativeSpawnType == "host" then
        return BijuuState.HOST_POOL
    elseif def.nativeSpawnType == "wild" then
        return BijuuState.WILD_DORMANT
    end
    return BijuuState.WILD_DORMANT
end

function BijuuState.deepCopy(source)
    if type(source) ~= "table" then return source end
    local result = {}
    for key, value in pairs(source) do
        result[key] = type(value) == "table" and BijuuState.deepCopy(value) or value
    end
    return result
end

function BijuuState.requestDebugDump(player)
    if not player then return false end
    if NinjaLineages.isClient and NinjaLineages.isClient() then
        sendClientCommand(player, "NinjaLineages", "debugBijuuDump", {})
        return true
    end
    if NinjaLineages.BijuuRegistryServer and NinjaLineages.BijuuRegistryServer.dumpRegistry then
        NinjaLineages.BijuuRegistryServer.dumpRegistry()
        return true
    end
    return false
end

function BijuuState.requestDebugReset(player)
    if not player then return false end
    if NinjaLineages.isClient and NinjaLineages.isClient() then
        sendClientCommand(player, "NinjaLineages", "debugBijuuReset", {})
        return true
    end
    if NinjaLineages.BijuuRegistryServer and NinjaLineages.BijuuRegistryServer.resetRegistryDebug then
        return NinjaLineages.BijuuRegistryServer.resetRegistryDebug(true)
    end
    return false
end
