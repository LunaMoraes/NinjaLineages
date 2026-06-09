require "NinjaLineages_Traits"

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
