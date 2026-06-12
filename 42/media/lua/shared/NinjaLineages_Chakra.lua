require "NinjaLineages_Traits"
require "NinjaLineages_Skills"
require "NinjaLineages_Progression"

NinjaLineages = NinjaLineages or {}
NinjaLineages.Chakra = NinjaLineages.Chakra or {}

-- Get max chakra based on traits
function NinjaLineages.Chakra.getMaxChakra(player)
    local maxVal = NinjaLineages.Constants.Chakra.MAX_BASE
    if NinjaLineages.hasSenju(player) then
        maxVal = maxVal * 2.0 -- +100% max cap multiplier (200)
    elseif NinjaLineages.hasUzumaki(player) then
        maxVal = maxVal * 1.7 -- +70% max cap multiplier (170)
    end

    local ccLevel = NinjaLineages.Skills.getChakraControlLevel(player)
    local ccMult = 1.0 + (ccLevel * 0.5)
    maxVal = maxVal * ccMult

    return maxVal
end

-- Get current chakra (initialize if nil)
function NinjaLineages.Chakra.getChakra(player)
    local data = NinjaLineages.getNLData(player)
    if not data.chakra then
        data.chakra = NinjaLineages.Chakra.getMaxChakra(player)
    end
    return data.chakra
end

-- Set chakra directly
function NinjaLineages.Chakra.setChakra(player, val)
    local data = NinjaLineages.getNLData(player)
    local maxVal = NinjaLineages.Chakra.getMaxChakra(player)
    data.chakra = math.max(0.0, math.min(maxVal, val))
    NinjaLineages.transmitPlayerData(player)
end

-- Spend chakra, returns boolean if successful
function NinjaLineages.Chakra.spendChakra(player, amount, opts)
    local current = NinjaLineages.Chakra.getChakra(player)
    if current < amount then return false end

    NinjaLineages.Chakra.setChakra(player, current - amount)

    opts = opts or {}
    if opts.awardXP ~= false then
        local ratio = opts.xpRatio or NinjaLineages.Balance.SkillXP.CHAKRA_SPEND_RATIO
        NinjaLineages.Skills.addJutsuProwessXP(player, amount * ratio)
        local ninjaRatio = NinjaLineages.Balance.Progression.NinjaXP.CHAKRA_RATIO
        NinjaLineages.Progression.awardXP(player, "chakra", math.floor(amount * ninjaRatio))
    end

    return true
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
