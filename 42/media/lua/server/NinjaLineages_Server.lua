require "NinjaLineages_Traits"

local SHARINGAN_STAGE_1_KILLS = 1
local SHARINGAN_STAGE_2_KILLS = 100
local SHARINGAN_STAGE_3_KILLS = 500

local function getNLData(player)
    local modData = player:getModData()
    modData.NinjaLineages = modData.NinjaLineages or {}
    return modData.NinjaLineages
end

local function transmitPlayerData(player)
    if player and player.transmitModData then
        pcall(function() player:transmitModData() end)
    end
end

local function hasSharingan(player)
    local trait = NinjaLineages.CharacterTrait
        and NinjaLineages.CharacterTrait.SHARINGAN
    if trait and player:hasTrait(trait) then return true end

    local ok, resolved = pcall(function()
        return CharacterTrait.get(ResourceLocation.of(NinjaLineages.TRAIT_SHARINGAN))
    end)
    return ok and resolved and player:hasTrait(resolved) == true
end

local function getSharinganStage(player)
    if not hasSharingan(player) then return 0 end
    local kills = player:getZombieKills() or 0
    if kills >= SHARINGAN_STAGE_3_KILLS then return 3 end
    if kills >= SHARINGAN_STAGE_2_KILLS then return 2 end
    if kills >= SHARINGAN_STAGE_1_KILLS then return 1 end
    return 0
end

local function unlockMangekyoIfEligible(victim)
    if not victim or not instanceof(victim, "IsoPlayer") then return end
    local attacker = victim:getAttackedBy()
    if not attacker or not instanceof(attacker, "IsoPlayer") then return end
    if getSharinganStage(attacker) < 3 then return end

    local data = getNLData(attacker)
    if data.mangekyoUnlocked then return end
    data.mangekyoUnlocked = true
    transmitPlayerData(attacker)
end

Events.OnCharacterDeath.Add(unlockMangekyoIfEligible)
