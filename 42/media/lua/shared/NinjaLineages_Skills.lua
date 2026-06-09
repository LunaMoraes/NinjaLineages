NinjaLineages = NinjaLineages or {}
NinjaLineages.Skills = {}

-- Safely retrieve perk enum values
local function getChakraControlPerk()
    return Perks.FromString("ChakraControl")
end

local function getJutsuProwessPerk()
    return Perks.FromString("JutsuProwess")
end

-- Getters for player perk levels
function NinjaLineages.Skills.getChakraControlLevel(player)
    local perk = getChakraControlPerk()
    if perk then
        return player:getPerkLevel(perk) or 0
    end
    return 0
end

function NinjaLineages.Skills.getJutsuProwessLevel(player)
    local perk = getJutsuProwessPerk()
    if perk then
        return player:getPerkLevel(perk) or 0
    end
    return 0
end

-- Add XP helpers (Note: PZ XP methods take amount where 1 level block is standard)
function NinjaLineages.Skills.addChakraControlXP(player, amount)
    local perk = getChakraControlPerk()
    if perk and amount > 0 then
        player:getXp():AddXP(perk, amount)
    end
end

function NinjaLineages.Skills.addJutsuProwessXP(player, amount)
    local perk = getJutsuProwessPerk()
    if perk and amount > 0 then
        player:getXp():AddXP(perk, amount)
    end
end

-- Multiplier scales
-- Chakra Control Level 0-10 -> 1.0x to 2.5x regen
function NinjaLineages.Skills.getRegenMultiplier(level)
    return 1.0 + (level * 0.15)
end

-- Chakra Control Level 0-10 -> 0% to 50% drain reduction (so returns a factor 1.0 to 0.5)
function NinjaLineages.Skills.getDrainReduction(level)
    return 1.0 - (level * 0.05)
end

-- Jutsu Prowess Level 0-10 -> 50% to 100% effectiveness scaling
function NinjaLineages.Skills.getJutsuEffectiveness(level)
    return 0.5 + (level * 0.05)
end

-- Jutsu Prowess Level 0-10 -> 1.0x to 2.0x duration scaling
function NinjaLineages.Skills.getJutsuDuration(level)
    return 1.0 + (level * 0.1)
end
