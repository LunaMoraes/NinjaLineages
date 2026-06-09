require "NinjaLineages_Traits"
require "NinjaLineages_Skills"

NinjaLineages = NinjaLineages or {}
NinjaLineages.Chakra = NinjaLineages.Chakra or {}

-- Get max chakra based on traits
function NinjaLineages.Chakra.getMaxChakra(player)
    local maxVal = NinjaLineages.Constants.MAX_BASE_CHAKRA
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
    local oldVal = data.chakra or maxVal
    local newVal = math.max(0.0, math.min(maxVal, val))

    -- Award Jutsu Prowess XP on depletion (1:10 ratio)
    if newVal < oldVal then
        local depleted = oldVal - newVal
        if depleted > 0 then
            NinjaLineages.Skills.addJutsuProwessXP(player, depleted / 10.0)
        end
    end

    data.chakra = newVal
    NinjaLineages.transmitPlayerData(player)
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
