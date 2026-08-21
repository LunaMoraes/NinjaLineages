require "NinjaLineages_Traits"
require "NinjaLineages_Items"
require "NinjaLineages_RinneganMechanics"
require "NinjaLineages_AbilityExecution"
require "NinjaLineages_ProgressionServer"
require "NinjaLineages_PassivesServer"
require "NinjaLineages_GeneExperimentationServer"
require "NinjaLineages_ZombieNinjaServer"
require "NinjaLineages_ExperimentalSurgeryServer"
require "NinjaLineages_SocialServer"
require "NinjaLineages_MissionServer"
require "jinchuuriki/NinjaLineages_BijuuServerSupport"
require "jinchuuriki/NinjaLineages_BijuuRegistryServer"
require "jinchuuriki/NinjaLineages_BijuuBossServer"
require "jinchuuriki/NinjaLineages_BijuuLifecycleServer"
require "jinchuuriki/NinjaLineages_BijuuSealingServer"
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
    elseif command == "sharinganEvadeBroadcast" then
        sendServerCommand("NinjaLineages", "abilityEvent", args)
    end
end

local function updateAbilities()
    NinjaLineages.AbilityAuthority.pruneSeenRequests()
    NinjaLineages.RinneganMechanics.update()
    if NinjaLineages.CombatRuntime then
        NinjaLineages.CombatRuntime.update()
    end
    if NinjaLineages.EarthWall then
        NinjaLineages.EarthWall.update()
    end
    if NinjaLineages.BijuuBossServer and NinjaLineages.BijuuBossServer.update then
        NinjaLineages.BijuuBossServer.update()
    end
    if NinjaLineages.BijuuLifecycleServer and NinjaLineages.BijuuLifecycleServer.update then
        NinjaLineages.BijuuLifecycleServer.update()
    end
    if NinjaLineages.BijuuSealingServer and NinjaLineages.BijuuSealingServer.update then
        NinjaLineages.BijuuSealingServer.update()
    end
    NinjaLineages.AbilityAuthority.updateWorld()

    NinjaLineages.Utils.Players.forEach(function(player)
        NinjaLineages.AbilityAuthority.updatePlayer(player)

        if NinjaLineages.ServerPassives then
            NinjaLineages.ServerPassives.updatePlayer(player)
        end
    end)
end

local function everyOneMinute()
    NinjaLineages.AbilityAuthority.updateAlarmSeals()

    NinjaLineages.Utils.Players.forEach(function(player)
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

if NinjaLineages.isServer() or not NinjaLineages.isClient() then
    NinjaLineages.addEventOnce(
        "server.onTick.updateAbilities",
        Events.OnTick,
        updateAbilities
    )
    NinjaLineages.addEventOnce(
        "server.everyOneMinute",
        Events.EveryOneMinute,
        everyOneMinute
    )
end

NinjaLineages.JutsuCatalog.validateExecutors()
