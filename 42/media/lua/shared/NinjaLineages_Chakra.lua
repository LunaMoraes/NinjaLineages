require "NinjaLineages_Traits"
require "NinjaLineages_Skills"
require "NinjaLineages_Progression"

NinjaLineages = NinjaLineages or {}
NinjaLineages.Chakra = NinjaLineages.Chakra or {}

-- Get max chakra based on traits
function NinjaLineages.Chakra.getMaxChakra(player)
    local maxVal = NinjaLineages.Constants.Chakra.MAX_BASE
    if NinjaLineages.hasSenju(player) then
        local mult = NinjaLineages.Constants.Senju and NinjaLineages.Constants.Senju.CHAKRA_POOL_MULTIPLIER or 2.0
        maxVal = maxVal * mult
    elseif NinjaLineages.hasUzumaki(player) then
        local mult = NinjaLineages.Constants.Uzumaki and NinjaLineages.Constants.Uzumaki.CHAKRA_POOL_MULTIPLIER or 1.7
        maxVal = maxVal * mult
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

-- ============================================================================
-- Nature Chakra API (Max 100, Generated only through meditation)
-- ============================================================================

NinjaLineages.Chakra.MAX_NATURE_CHAKRA = 100

function NinjaLineages.Chakra.getMaxNatureChakra(player)
    return NinjaLineages.Chakra.MAX_NATURE_CHAKRA
end

function NinjaLineages.Chakra.getNatureChakra(player)
    local data = NinjaLineages.getNLData(player)
    if not data then return 0 end
    return data.natureChakra or 0
end

function NinjaLineages.Chakra.setNatureChakra(player, val)
    local data = NinjaLineages.getNLData(player)
    if not data then return end
    data.natureChakra = math.max(0.0, math.min(NinjaLineages.Chakra.MAX_NATURE_CHAKRA, val or 0))
    NinjaLineages.transmitPlayerData(player)
end

function NinjaLineages.Chakra.addNatureChakra(player, amount)
    local current = NinjaLineages.Chakra.getNatureChakra(player)
    NinjaLineages.Chakra.setNatureChakra(player, current + amount)
end

function NinjaLineages.Chakra.spendNatureChakra(player, amount)
    local current = NinjaLineages.Chakra.getNatureChakra(player)
    if current < amount then return false end
    NinjaLineages.Chakra.setNatureChakra(player, current - amount)
    return true
end

