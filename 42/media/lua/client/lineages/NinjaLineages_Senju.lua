require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "NinjaLineages_Balance"

NinjaLineages = NinjaLineages or {}
NinjaLineages.Senju = NinjaLineages.Senju or {}

local consts = NinjaLineages.Constants

local function updateCreationRebirthUnlock(player)
    if not NinjaLineages.hasSenju(player) then return end
    if NinjaLineages.CreationRebirth.isUnlocked(player) then return end

    local requiredLevel = consts.Senju.CreationRebirth.SENJU_UNLOCK_LEVEL
    if NinjaLineages.Skills.getChakraControlLevel(player) >= requiredLevel then
        NinjaLineages.CreationRebirth.unlock(player, "UI_NL_Unlock_CreationRebirth")
    end
end

local function applySenjuEndurance(player)
    if not player then return end

    local senjuTrait = NinjaLineages.getTraitObject(NinjaLineages.TRAIT_SENJU)
    if not senjuTrait then return end
    local data = NinjaLineages.getNLData(player)
    local fastHealer = NinjaLineages.getTraitObject("base:fasthealer")
    if not player:hasTrait(senjuTrait) then
        if data.senjuAddedFastHealer and fastHealer then
            pcall(function() player:getCharacterTraits():remove(fastHealer) end)
            data.senjuAddedFastHealer = nil
            NinjaLineages.transmitPlayerData(player)
        end
        return
    end

    if fastHealer and not player:hasTrait(fastHealer) then
        pcall(function() player:getCharacterTraits():add(fastHealer) end)
        data.senjuAddedFastHealer = true
        NinjaLineages.transmitPlayerData(player)
    end
end

NinjaLineages.registerPlayerUpdate("senju.update", applySenjuEndurance)

NinjaLineages.registerCreatePlayer("senju.init", function(player)
    applySenjuEndurance(player)
    updateCreationRebirthUnlock(player)
end)

Events.LevelPerk.Add(function(player, perk)
    local chakraControl = Perks.FromString("ChakraControl")
    if perk == chakraControl then updateCreationRebirthUnlock(player) end
end)

NinjaLineages.registerEveryMinute("senju.passive", function(player)
    if not NinjaLineages.hasSenju(player) then return end
    local stats = player:getStats()
    if not stats then return end
    local currentEndurance = stats:get(CharacterStat.ENDURANCE)
    stats:set(
        CharacterStat.ENDURANCE,
        math.min(1.0, currentEndurance + consts.Senju.Passive.ENDURANCE_PER_MINUTE)
    )
end)
