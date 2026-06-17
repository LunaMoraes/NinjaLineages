require "NinjaLineages_Traits"

NinjaLineages = NinjaLineages or {}
NinjaLineages.UchihaPassives = NinjaLineages.UchihaPassives or {}

local UchihaPassives = NinjaLineages.UchihaPassives

function UchihaPassives.notifyMangekyoUnlocked(player)
    if not player then return end
    if NinjaLineages.isServer() then
        sendServerCommand(player, "NinjaLineages", "abilityEvent", {
            kind = "mangekyo_unlocked",
            casterOnlineId = player:getOnlineID(),
        })
    end
end

function UchihaPassives.unlockMangekyoIfEligible(victim)
    if not victim or not instanceof(victim, "IsoPlayer") then return end

    local attacker = victim:getAttackedBy()
    if not attacker or not instanceof(attacker, "IsoPlayer") then return end
    if not NinjaLineages.hasSharingan(attacker) then return end
    if NinjaLineages.getSharinganStage(attacker) < 3 then return end

    local data = NinjaLineages.getNLData(attacker)
    if data.mangekyoUnlocked then return end

    data.mangekyoUnlocked = true
    NinjaLineages.transmitPlayerData(attacker)
    UchihaPassives.notifyMangekyoUnlocked(attacker)
end
