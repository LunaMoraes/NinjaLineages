require "NinjaLineages_Traits"
require "NinjaLineages_Items"
require "NinjaLineages_RinneganMechanics"
require "NinjaLineages_AbilityExecution"
require "NinjaLineages_ProgressionServer"
require "NinjaLineages_PassivesServer"
require "NinjaLineages_GeneExperimentationServer"
require "lineages/NinjaLineages_UchihaPassives"

local function handleAbilityRequest(player, args)
    if not player then return end

    local result = NinjaLineages.AbilityAuthority.execute(
        player,
        args and args.requestId,
        args and args.actionId,
        args and args.args or {}
    )

    result.casterOnlineId = player:getOnlineID()
    sendServerCommand(player, "NinjaLineages", "abilityResult", result)

    if result.ok and NinjaLineages.ServerPassives then
        NinjaLineages.ServerPassives.updatePlayer(player)
    end

    if result.ok and result.actionId == "shinra_tensei" then
        sendServerCommand("NinjaLineages", "abilityEvent", {
            kind = "shinra_tensei_pulse",
            x = player:getX(),
            y = player:getY(),
            z = math.floor(player:getZ()),
            casterOnlineId = player:getOnlineID(),
        })
    end

    if result.ok and result.state and result.state.event then
        local event = result.state.event
        event.casterOnlineId = event.casterOnlineId or player:getOnlineID()
        sendServerCommand("NinjaLineages", "abilityEvent", event)
    end
end

local function onClientCommand(module, command, player, args)
    if module ~= "NinjaLineages" then return end

    if command == "abilityRequest" then
        handleAbilityRequest(player, args)
    end
end

local function forEachOnlinePlayer(callback)
    local players = getOnlinePlayers and getOnlinePlayers()
    if players then
        for i = 0, players:size() - 1 do
            local player = players:get(i)
            if player then callback(player) end
        end
        return
    end

    if getNumActivePlayers and getSpecificPlayer then
        for i = 0, getNumActivePlayers() - 1 do
            local player = getSpecificPlayer(i)
            if player then callback(player) end
        end
    end
end

local function updateAbilities()
    NinjaLineages.AbilityAuthority.pruneSeenRequests()
    NinjaLineages.RinneganMechanics.update()
    NinjaLineages.AbilityAuthority.updateWorld()

    forEachOnlinePlayer(function(player)
        NinjaLineages.AbilityAuthority.updatePlayer(player)

        if NinjaLineages.ServerPassives then
            NinjaLineages.ServerPassives.updatePlayer(player)
        end
    end)
end

local function everyOneMinute()
    NinjaLineages.AbilityAuthority.updateAlarmSeals()

    forEachOnlinePlayer(function(player)
        NinjaLineages.AbilityAuthority.everyMinute(player)

        if NinjaLineages.ServerPassives then
            NinjaLineages.ServerPassives.everyMinute(player)
        end
    end)
end

NinjaLineages.addEventOnce(
    "server.onCharacterDeath.unlockMangekyo",
    Events.OnCharacterDeath,
    NinjaLineages.UchihaPassives.unlockMangekyoIfEligible
)

NinjaLineages.addEventOnce(
    "server.onClientCommand",
    Events.OnClientCommand,
    onClientCommand
)

NinjaLineages.addEventOnce(
    "server.onTick.updateAbilities",
    Events.OnTick,
    updateAbilities
)

if NinjaLineages.isServer() then
    NinjaLineages.addEventOnce(
        "server.everyOneMinute",
        Events.EveryOneMinute,
        everyOneMinute
    )
end
