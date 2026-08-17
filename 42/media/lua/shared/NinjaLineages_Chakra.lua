require "NinjaLineages_Traits"
require "NinjaLineages_Skills"
require "NinjaLineages_Progression"
require "NinjaLineages_Balance"

NinjaLineages = NinjaLineages or {}
NinjaLineages.Chakra = NinjaLineages.Chakra or {}

-- Get max chakra based on traits
function NinjaLineages.Chakra.getMaxChakra(player)
    local chakraBalance = NinjaLineages.Balance.Chakra
    local maxVal = chakraBalance.MAX_BASE
    if NinjaLineages.hasSenju(player) then
        maxVal = maxVal * NinjaLineages.Balance.Lineages.Senju.CHAKRA_POOL_MULTIPLIER
    elseif NinjaLineages.hasUzumaki(player) then
        maxVal = maxVal * NinjaLineages.Balance.Lineages.Uzumaki.CHAKRA_POOL_MULTIPLIER
    end

    local ccLevel = NinjaLineages.Skills.getChakraControlLevel(player)
    local ccMult = 1.0 + (ccLevel * chakraBalance.CONTROL_MAX_PER_LEVEL)
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
    local data = NinjaLineages.getNLData(player)
    local effect = data and data.activeGeneEffect
        and NinjaLineages.Balance.getGeneEffect(data.activeGeneEffect.id)
    if effect and effect.chakraCostMultiplier then
        amount = amount * effect.chakraCostMultiplier
    end
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
    local data = NinjaLineages.getNLData(player)
    local effect = data and data.activeGeneEffect
        and NinjaLineages.Balance.getGeneEffect(data.activeGeneEffect.id)
    if effect and effect.chakraCostMultiplier then
        amount = amount * effect.chakraCostMultiplier
    end
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

function NinjaLineages.Chakra.getMaxNatureChakra(player)
    return NinjaLineages.Balance.Chakra.Nature.MAXIMUM
end

function NinjaLineages.Chakra.getNatureChakra(player)
    local data = NinjaLineages.getNLData(player)
    if not data then return 0 end
    return data.natureChakra or 0
end

function NinjaLineages.Chakra.setNatureChakra(player, val)
    local data = NinjaLineages.getNLData(player)
    if not data then return end
    data.natureChakra = math.max(0.0, math.min(NinjaLineages.Balance.Chakra.Nature.MAXIMUM, val or 0))
    NinjaLineages.transmitPlayerData(player)
end

function NinjaLineages.Chakra.addNatureChakra(player, amount)
    local current = NinjaLineages.Chakra.getNatureChakra(player)
    NinjaLineages.Chakra.setNatureChakra(player, current + amount)
end

function NinjaLineages.Chakra.spendNatureChakra(player, amount)
    local current = NinjaLineages.Chakra.getNatureChakra(player)
    local requested = math.max(0, tonumber(amount) or 0)
    if current < requested then return false end
    NinjaLineages.Chakra.setNatureChakra(player, current - requested)
    return true
end
