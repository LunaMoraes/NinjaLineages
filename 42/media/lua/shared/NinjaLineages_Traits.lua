require "NinjaLineages_Constants"

NinjaLineages = NinjaLineages or {}

NinjaLineages.TRAIT_BYAKUGAN = "NinjaLineages:byakugan"
NinjaLineages.TRAIT_SHARINGAN = "NinjaLineages:sharingan"
NinjaLineages.TRAIT_SENJU = "NinjaLineages:senju"
NinjaLineages.TRAIT_RINNEGAN = "NinjaLineages:rinnegan"
NinjaLineages.TRAIT_UZUMAKI = "NinjaLineages:uzumaki"

-- Centralized Registries for modular lineage architecture
NinjaLineages.Abilities = {}
NinjaLineages.PlayerUpdates = {}
NinjaLineages.ZombieUpdates = {}
NinjaLineages.HitZombieListeners = {}
NinjaLineages.PlayerGetDamageListeners = {}
NinjaLineages.EveryMinuteListeners = {}
NinjaLineages.CreatePlayerListeners = {}

function NinjaLineages.registerAbility(ability)
    table.insert(NinjaLineages.Abilities, ability)
end

function NinjaLineages.registerPlayerUpdate(fn)
    table.insert(NinjaLineages.PlayerUpdates, fn)
end

function NinjaLineages.registerZombieUpdate(fn)
    table.insert(NinjaLineages.ZombieUpdates, fn)
end

function NinjaLineages.registerHitZombie(fn)
    table.insert(NinjaLineages.HitZombieListeners, fn)
end

function NinjaLineages.registerPlayerGetDamage(fn)
    table.insert(NinjaLineages.PlayerGetDamageListeners, fn)
end

function NinjaLineages.registerEveryMinute(fn)
    table.insert(NinjaLineages.EveryMinuteListeners, fn)
end

function NinjaLineages.registerCreatePlayer(fn)
    table.insert(NinjaLineages.CreatePlayerListeners, fn)
end

-- Helper to retrieve or initialize player modData
function NinjaLineages.getNLData(player)
    if not player then return nil end
    local modData = player:getModData()
    modData.NinjaLineages = modData.NinjaLineages or {}
    return modData.NinjaLineages
end

-- Helper to transmit player modData in multiplayer
function NinjaLineages.transmitPlayerData(player)
    if player and player.transmitModData then
        pcall(function() player:transmitModData() end)
    end
end

-- Helper to get a character trait by its ID
local traitObjects = {}
function NinjaLineages.getTraitObject(traitId)
    if traitObjects[traitId] then
        return traitObjects[traitId]
    end
    local ok, resolved = pcall(function()
        if CharacterTrait and CharacterTrait.get then
            return CharacterTrait.get(ResourceLocation.of(traitId))
        end
    end)
    if ok and resolved then
        traitObjects[traitId] = resolved
        return resolved
    end
    return nil
end

-- Trait checks
function NinjaLineages.hasTrait(player, traitKey, traitId)
    if not player then return false end
    
    -- Check if trait key is already registered in NinjaLineages.CharacterTrait
    local traitObj = NinjaLineages.CharacterTrait and NinjaLineages.CharacterTrait[traitKey]
    if traitObj then
        local ok, hasIt = pcall(function() return player:hasTrait(traitObj) end)
        if ok then return hasIt == true end
    end
    
    -- Try resolving using the new B42 API
    local trait = NinjaLineages.getTraitObject(traitId)
    if trait then
        local ok, hasIt = pcall(function() return player:hasTrait(trait) end)
        if ok then return hasIt == true end
    end
    
    -- Fall back to string-based checks
    local ok, traits = pcall(function() return player:getTraits() end)
    if ok and traits then
        local cleanId = traitId:gsub("^NinjaLineages:", ""):gsub("^base:", "")
        return traits:contains(cleanId) or traits:contains(traitId)
    end
    
    return false
end

function NinjaLineages.hasByakugan(player)
    return NinjaLineages.hasTrait(player, "BYAKUGAN", NinjaLineages.TRAIT_BYAKUGAN)
end

function NinjaLineages.hasSharingan(player)
    return NinjaLineages.hasTrait(player, "SHARINGAN", NinjaLineages.TRAIT_SHARINGAN)
end

function NinjaLineages.hasSenju(player)
    return NinjaLineages.hasTrait(player, "SENJU", NinjaLineages.TRAIT_SENJU)
end

function NinjaLineages.hasRinnegan(player)
    return NinjaLineages.hasTrait(player, "RINNEGAN", NinjaLineages.TRAIT_RINNEGAN)
end

function NinjaLineages.hasUzumaki(player)
    return NinjaLineages.hasTrait(player, "UZUMAKI", NinjaLineages.TRAIT_UZUMAKI)
end

-- Sharingan Stage lookup
function NinjaLineages.getSharinganStage(player)
    if not NinjaLineages.hasSharingan(player) then return 0 end
    local kills = player:getZombieKills() or 0
    local consts = NinjaLineages.Constants
    if kills >= consts.Uchiha.SharinganStageKills[3] then return 3 end
    if kills >= consts.Uchiha.SharinganStageKills[2] then return 2 end
    if kills >= consts.Uchiha.SharinganStageKills[1] then return 1 end
    return 0
end

-- Hook into foraging system to register Byakugan vision bonuses
local function addForageSkillDefs(forageSystemInstance)
    if forageSystemInstance and forageSystemInstance.forageSkillDefinitions then
        forageSystemInstance.forageSkillDefinitions[NinjaLineages.TRAIT_BYAKUGAN] = {
            name = NinjaLineages.TRAIT_BYAKUGAN,
            type = "trait",
            visionBonus = 5.0,      -- Substantial search radius expansion
            weatherEffect = 100,    -- Immune to weather foraging penalty
            darknessEffect = 100,   -- Immune to darkness foraging penalty
            specialisations = {}
        }
        forageSystemInstance.forageSkillDefinitions[NinjaLineages.TRAIT_RINNEGAN] = {
            name = NinjaLineages.TRAIT_RINNEGAN,
            type = "trait",
            visionBonus = 2.0,
            specialisations = {}
        }
    end
end

-- Use the foraging system's initialization hook
if Events.preAddSkillDefs then
    Events.preAddSkillDefs.Add(addForageSkillDefs)
end
