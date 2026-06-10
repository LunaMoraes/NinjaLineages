NinjaLineages = NinjaLineages or {}
NinjaLineages.Balance = NinjaLineages.Balance or {}

NinjaLineages.Balance.ChakraCostTier = {
    FREE = 0,
    TRIVIAL = 3,
    BASIC = 8,
    STANDARD = 15,
    ADVANCED = 25,
    MAJOR = 40,
    ULTIMATE = 65,
}

NinjaLineages.Balance.ChakraCostStepTier = {
    TINY = 2,
    SMALL = 3,
    STANDARD = 5,
    LARGE = 8,
    HARSH = 10,
}

NinjaLineages.Balance.CooldownTier = {
    NONE = 0,
    DASH = 5,
    QUICK = 15,
    SHORT = 30,
    STANDARD = 60,
    LONG = 120,
    VERY_LONG = 300,
}

NinjaLineages.Balance.DurationTier = {
    INSTANT = 0,
    BURST_MS = 500,
    BRIEF_MS = 3500,
    SHORT_MS = 8000,
    STANDARD_MS = 15000,
    LONG_MS = 30000,
    VERY_LONG_MS = 60000,
}

NinjaLineages.Balance.RadiusTier = {
    SELF = 0,
    TOUCH = 1.5,
    SMALL = 3.5,
    STANDARD = 7.0,
    LARGE = 10.0,
    HUGE = 15.0,
}

NinjaLineages.Balance.SustainedDrainTier = {
    TRACE = 1.5,
    MINIMAL = 3.0,
    LOW = 5.0,
    MODERATE = 8.5,
    HIGH = 12.0,
    EXTREME = 16.5,
    CRIPPLING = 25.0,
}

NinjaLineages.Balance.ChannelDrainTier = {
    LOW = 1.0,
    STANDARD = 2.0,
    HIGH = 3.0,
    EXTREME = 5.0,
}

NinjaLineages.Balance.DamageTier = {
    CHIP = { min = 0.05, max = 0.18 },
    LIGHT = { min = 0.18, max = 0.45 },
    MODERATE = { min = 0.45, max = 0.75 },
    HEAVY = { min = 0.75, max = 1.10 },
    DEVASTATING = { min = 1.10, max = 1.50 },
}

NinjaLineages.Balance.TraitCostTier = {
    STANDARD_LINEAGE = 14,
    RARE_LINEAGE = 18,
    MYTHIC_LINEAGE = 24,
}

function NinjaLineages.Balance.getCost(tier)
    return NinjaLineages.Balance.ChakraCostTier[tier] or 0
end

function NinjaLineages.Balance.getCostStep(tier)
    return NinjaLineages.Balance.ChakraCostStepTier[tier] or 0
end

function NinjaLineages.Balance.getCooldown(tier)
    return NinjaLineages.Balance.CooldownTier[tier] or 0
end

function NinjaLineages.Balance.getDuration(tier)
    return NinjaLineages.Balance.DurationTier[tier] or 0
end

function NinjaLineages.Balance.getRadius(tier)
    return NinjaLineages.Balance.RadiusTier[tier] or 0
end

function NinjaLineages.Balance.getSustainedDrain(tier)
    return NinjaLineages.Balance.SustainedDrainTier[tier] or 0
end

function NinjaLineages.Balance.getChannelDrain(tier)
    return NinjaLineages.Balance.ChannelDrainTier[tier] or 0
end

function NinjaLineages.Balance.getDamageRange(tier)
    local range = NinjaLineages.Balance.DamageTier[tier]
    if not range then return 0, 0 end
    return range.min, range.max
end

function NinjaLineages.Balance.rollDamage(tier)
    local minDamage, maxDamage = NinjaLineages.Balance.getDamageRange(tier)
    if NinjaLineages.Utils and NinjaLineages.Utils.Combat and NinjaLineages.Utils.Combat.randomDamage then
        return NinjaLineages.Utils.Combat.randomDamage(minDamage, maxDamage)
    end
    -- Fallback inline implementation to avoid hard load-order dependency
    local damageRoll = ZombRand(0, 1001) / 1000
    return minDamage + (damageRoll * (maxDamage - minDamage))
end
