require "NinjaLineages_Traits"
require "NinjaLineages_Items"
require "NinjaLineages_RinneganMechanics"
require "NinjaLineages_AbilityExecution"
require "NinjaLineages_ProgressionServer"
require "NinjaLineages_PassivesServer"

local function notifyMangekyoUnlocked(player)
    if not player then return end

    if isServer and isServer() then
        sendServerCommand(player, "NinjaLineages", "abilityEvent", {
            kind = "mangekyo_unlocked",
            casterOnlineId = player:getOnlineID(),
        })
    end
end

local function unlockMangekyoIfEligible(victim)
    if not victim or not instanceof(victim, "IsoPlayer") then return end

    local attacker = victim:getAttackedBy()
    if not attacker or not instanceof(attacker, "IsoPlayer") then return end
    if not NinjaLineages.hasSharingan(attacker) then return end
    if NinjaLineages.getSharinganStage(attacker) < 3 then return end

    local data = NinjaLineages.getNLData(attacker)
    if data.mangekyoUnlocked then return end

    data.mangekyoUnlocked = true
    NinjaLineages.transmitPlayerData(attacker)
    notifyMangekyoUnlocked(attacker)
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
    unlockMangekyoIfEligible
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

if isServer and isServer() then
    NinjaLineages.addEventOnce(
        "server.everyOneMinute",
        Events.EveryOneMinute,
        everyOneMinute
    )
end
