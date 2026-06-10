require "NinjaLineages_Constants"
require "NinjaLineages_Balance"

NinjaLineages = NinjaLineages or {}

NinjaLineages.TRAIT_BYAKUGAN = "NinjaLineages:byakugan"
NinjaLineages.TRAIT_SHARINGAN = "NinjaLineages:sharingan"
NinjaLineages.TRAIT_SENJU = "NinjaLineages:senju"
NinjaLineages.TRAIT_RINNEGAN = "NinjaLineages:rinnegan"
NinjaLineages.TRAIT_UZUMAKI = "NinjaLineages:uzumaki"

-- Centralized Registries for modular lineage architecture
NinjaLineages.Abilities = NinjaLineages.Abilities or {}
NinjaLineages.PlayerUpdates = NinjaLineages.PlayerUpdates or {}
NinjaLineages.ZombieUpdates = NinjaLineages.ZombieUpdates or {}
NinjaLineages.HitZombieListeners = NinjaLineages.HitZombieListeners or {}
NinjaLineages.PlayerGetDamageListeners = NinjaLineages.PlayerGetDamageListeners or {}
NinjaLineages.EveryMinuteListeners = NinjaLineages.EveryMinuteListeners or {}
NinjaLineages.CreatePlayerListeners = NinjaLineages.CreatePlayerListeners or {}

-- Safe call wrapper for named listener logging
function NinjaLineages.safeCall(kind, id, fn, ...)
    if not fn then return end
    local status, err = pcall(fn, ...)
    if not status then
        print("ERROR: [" .. tostring(kind) .. "] listener '" .. tostring(id) .. "' failed: " .. tostring(err))
    end
end

local function addListener(registry, idOrFn, maybeFn)
    local id, fn
    if type(idOrFn) == "string" then
        id = idOrFn
        fn = maybeFn
    else
        id = "anonymous"
        fn = idOrFn
    end
    if fn then
        table.insert(registry, { id = id, fn = fn })
    end
end

function NinjaLineages.registerAbility(ability)
    table.insert(NinjaLineages.Abilities, ability)
end

function NinjaLineages.registerPlayerUpdate(idOrFn, maybeFn)
    addListener(NinjaLineages.PlayerUpdates, idOrFn, maybeFn)
end

function NinjaLineages.registerZombieUpdate(idOrFn, maybeFn)
    addListener(NinjaLineages.ZombieUpdates, idOrFn, maybeFn)
end

function NinjaLineages.registerHitZombie(idOrFn, maybeFn)
    addListener(NinjaLineages.HitZombieListeners, idOrFn, maybeFn)
end

function NinjaLineages.registerPlayerGetDamage(idOrFn, maybeFn)
    addListener(NinjaLineages.PlayerGetDamageListeners, idOrFn, maybeFn)
end

function NinjaLineages.registerEveryMinute(idOrFn, maybeFn)
    addListener(NinjaLineages.EveryMinuteListeners, idOrFn, maybeFn)
end

function NinjaLineages.registerCreatePlayer(idOrFn, maybeFn)
    addListener(NinjaLineages.CreatePlayerListeners, idOrFn, maybeFn)
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
