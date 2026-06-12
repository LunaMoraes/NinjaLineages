require "NinjaLineages_Traits"
require "NinjaLineages_Items"
require "NinjaLineages_RinneganMechanics"
require "NinjaLineages_ProgressionServer"

local function unlockMangekyoIfEligible(victim)
    if not victim or not instanceof(victim, "IsoPlayer") then return end
    local attacker = victim:getAttackedBy()
    if not attacker or not instanceof(attacker, "IsoPlayer") then return end
    if NinjaLineages.getSharinganStage(attacker) < 3 then return end

    local data = NinjaLineages.getNLData(attacker)
    if data.mangekyoUnlocked then return end
    data.mangekyoUnlocked = true
    NinjaLineages.transmitPlayerData(attacker)
end

Events.OnCharacterDeath.Add(unlockMangekyoIfEligible)

local function rejectShinraTensei(player, reason, remaining)
    sendServerCommand(player, "NinjaLineages", "shinraTenseiRejected", {
        reason = reason,
        remaining = remaining,
    })
end

local function castShinraTensei(player)
    local executed, reason, remaining = NinjaLineages.RinneganMechanics.execute(player)
    if not executed then
        rejectShinraTensei(player, reason, remaining)
        return
    end

    sendServerCommand("NinjaLineages", "shinraTenseiPulse", {
        x = player:getX(),
        y = player:getY(),
        z = math.floor(player:getZ()),
        casterOnlineId = player:getOnlineID(),
    })
end

local function onClientCommand(module, command, player, args)
    if module ~= "NinjaLineages" then return end
    if command == "shinraTensei" then
        castShinraTensei(player)
    end
end

Events.OnClientCommand.Add(onClientCommand)
Events.OnTick.Add(NinjaLineages.RinneganMechanics.update)
