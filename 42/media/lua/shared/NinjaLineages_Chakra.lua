require "NinjaLineages_Traits"

NinjaLineages = NinjaLineages or {}
NinjaLineages.Chakra = {}

-- Constant base costs
NinjaLineages.Chakra.MAX_BASE_CHAKRA = 100
NinjaLineages.Chakra.HEALING_JUTSU_COST = 15
NinjaLineages.Chakra.REINFORCEMENT_JUTSU_COST = 12
NinjaLineages.Chakra.QUIET_STEP_COST = 10
NinjaLineages.Chakra.CHAKRA_FOCUS_COST = 8
NinjaLineages.Chakra.CHAKRA_GRIP_COST = 8
NinjaLineages.Chakra.BODY_FLICKER_COST = 20

-- Cost replacement values
NinjaLineages.Chakra.SHINRA_BASE_COST = 35
NinjaLineages.Chakra.SHINRA_COST_PER_ZOMBIE = 3
NinjaLineages.Chakra.SHINRA_COST_CAP = 75
NinjaLineages.Chakra.WOOD_ROOTS_COST = 35
NinjaLineages.Chakra.CREATION_REBIRTH_COST_PER_PART = 1.5
NinjaLineages.Chakra.KAMUI_MIN_GATE = 20
NinjaLineages.Chakra.KAMUI_DRAIN_PER_SECOND = 8.0  -- sustained drains are handled in update ticks (per second)

-- Eye sustained drains (per minute in in-game time)
NinjaLineages.Chakra.BYAKUGAN_DRAIN_PER_MINUTE = 24.0 -- 0.4 per real second equivalent if 1 min = 60s
NinjaLineages.Chakra.SHARINGAN_DRAIN_PER_MINUTE = {
    [1] = 48.0, -- 0.8 per second equivalent
    [2] = 60.0, -- 1.0 per second equivalent
    [3] = 72.0, -- 1.2 per second equivalent
}
NinjaLineages.Chakra.MANGEKYO_DRAIN_PER_MINUTE = 120.0 -- 2.0 per second equivalent

-- Retrieve or initialize player modData
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

local function playerHasTrait(player, key, traitId)
    if not player then return false end
    local traitObj = NinjaLineages.CharacterTrait and NinjaLineages.CharacterTrait[key]
    if traitObj and player:hasTrait(traitObj) then
        return true
    end
    local ok, resolved = pcall(function()
        return CharacterTrait.get(ResourceLocation.of(traitId))
    end)
    return ok and resolved and player:hasTrait(resolved) == true
end

-- Get max chakra based on traits
function NinjaLineages.Chakra.getMaxChakra(player)
    local maxVal = NinjaLineages.Chakra.MAX_BASE_CHAKRA
    if playerHasTrait(player, "SENJU", NinjaLineages.TRAIT_SENJU) then
        maxVal = maxVal * 2.0 -- +100% max cap multiplier (200)
    elseif playerHasTrait(player, "UZUMAKI", NinjaLineages.TRAIT_UZUMAKI) then
        maxVal = maxVal * 1.7 -- +70% max cap multiplier (170)
    end
    return maxVal
end

-- Get current chakra (initialize if nil)
function NinjaLineages.Chakra.getChakra(player)
    local data = getNLData(player)
    if not data.chakra then
        data.chakra = NinjaLineages.Chakra.getMaxChakra(player)
    end
    return data.chakra
end

-- Set chakra directly
function NinjaLineages.Chakra.setChakra(player, val)
    local data = getNLData(player)
    local maxVal = NinjaLineages.Chakra.getMaxChakra(player)
    data.chakra = math.max(0.0, math.min(maxVal, val))
    transmitPlayerData(player)
end

-- Spend chakra, returns boolean if successful
function NinjaLineages.Chakra.spendChakra(player, amount)
    local current = NinjaLineages.Chakra.getChakra(player)
    if current >= amount then
        NinjaLineages.Chakra.setChakra(player, current - amount)
        return true
    end
    return false
end

-- Check if can afford chakra cost
function NinjaLineages.Chakra.canAffordChakra(player, amount)
    return NinjaLineages.Chakra.getChakra(player) >= amount
end

-- Add chakra
function NinjaLineages.Chakra.addChakra(player, amount)
    local current = NinjaLineages.Chakra.getChakra(player)
    NinjaLineages.Chakra.setChakra(player, current + amount)
end
