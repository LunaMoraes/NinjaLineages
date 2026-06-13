NinjaLineages = NinjaLineages or {}
NinjaLineages.Balance = NinjaLineages.Balance or {}

NinjaLineages.Balance.ChakraCostTier = {
    FREE = 0,
    TRIVIAL = 3,
    BASIC = 8,
    STANDARD = 15,
    COMMITTED = 20,
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
    RAPID_TICK_MS = 250,
    BURST_MS = 500,
    BRIEF_MS = 3500,
    SHORT_MS = 8000,
    COMBAT_MS = 10000,
    STANDARD_MS = 15000,
    LONG_MS = 30000,
    VERY_LONG_MS = 60000,
}

NinjaLineages.Balance.RadiusTier = {
    SELF = 0,
    TOUCH = 1.5,
    SMALL = 3.5,
    MEDIUM = 6.0,
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

NinjaLineages.Balance.HealingTier = {
    LIGHT = { health = 6.0, wound = 12.0, pain = 4.0, fatigue = 0.02 },
    MODERATE = { health = 12.0, wound = 24.0, pain = 12.0, fatigue = 0.08 },
    HEAVY = { health = 20.0, wound = 40.0, pain = 25.0, fatigue = 0.18 },
    DEVASTATING = { health = 30.0, wound = 60.0, pain = 40.0, fatigue = 0.25 },
    CREATION_REBIRTH = {
        health = 3.0,
        bleeding = 4.0,
        scratch = 4.0,
        cut = 4.0,
        deepWound = 3.0,
        burn = 2.0,
        fracture = 1.0,
    },
}

NinjaLineages.Balance.TargetingTier = {
    NARROW = { radius = "SMALL", minimumDot = 0.82, targets = 1 },
    STANDARD = { radius = "STANDARD", minimumDot = 0.65, targets = 1 },
    SMALL_CLUSTER = { radius = "STANDARD", minimumDot = 0.60, targets = 3, clusterRadius = "TOUCH" },
    WIDE = { radius = "LARGE", minimumDot = 0.35, targets = 5 },
}

NinjaLineages.Balance.Progression = {
    NodeCost = {
        GENIN = 100,
        CHUNIN = 250,
        JONIN = 500,
    },
    TrainingPages = {
        GENIN = 100,
        CHUNIN = 200,
        JONIN = 300,
        KAGE = 360,
    },
    NinjaXP = {
        KILL = 2,
        CHAKRA_RATIO = 0.25,
        CHAKRA_DAILY_CAP = 30,
        MEDITATION_INTERVAL_SECONDS = 10,
        MEDITATION_REWARD = 1,
        MEDITATION_DAILY_CAP = 30,
    },
    RankNodeWeight = {
        GENIN = 1,
        CHUNIN = 2,
        JONIN = 3,
        RARE = 4,
        LINEAGE = 2,
    },
    RankThreshold = {
        NONE = 0,
        GENIN = 2,
        CHUNIN = 8,
        JONIN = 18,
        KAGE = 40,
    },
    SkillScoreDivisor = 2,
    UzumakiFuinjutsuMultiplier = 0.75,
    ProbabilityMaximum = 100,
    NormalizedMaximum = 1,
    PercentScale = 100,
    ConditionRestore = 1,
}

NinjaLineages.Balance.SkillXP = {
    CHAKRA_SPEND_RATIO = 0.10,
}

NinjaLineages.Balance.MasteryTier = {
    GENIN = 0.10,
    CHUNIN = 0.20,
    JONIN = 0.35,
}

NinjaLineages.Balance.Meditation = {
    CHAKRA_CONTROL_TICK_MS = 5000,
    CHAKRA_CONTROL_TICK_XP = 1.5,
    CHAKRA_CONTROL_COMPLETION_XP = 10.0,
    ACTION_TICKS = 3000,
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

function NinjaLineages.Balance.getHealing(tier)
    return NinjaLineages.Balance.HealingTier[tier]
end

function NinjaLineages.Balance.getTargeting(tier)
    local definition = NinjaLineages.Balance.TargetingTier[tier]
    if not definition then return nil end
    return {
        range = NinjaLineages.Balance.getRadius(definition.radius),
        minDot = definition.minimumDot,
        maxTargets = definition.targets,
        clusterRadius = definition.clusterRadius
            and NinjaLineages.Balance.getRadius(definition.clusterRadius)
            or nil,
    }
end

function NinjaLineages.Balance.getMastery(tier)
    return NinjaLineages.Balance.MasteryTier[tier] or 0
end

function NinjaLineages.Balance.getSandboxMultiplier(key)
    local options = SandboxVars and SandboxVars.NinjaLineages
    local raw = options and tonumber(options[key]) or 100
    return math.max(0, raw) / 100
end

function NinjaLineages.Balance.getNodeCost(tier, player, disciplineId)
    local value = NinjaLineages.Balance.Progression.NodeCost[tier] or 0
    value = value * NinjaLineages.Balance.getSandboxMultiplier("NinjaXPCostMultiplier")
    if disciplineId == "fuinjutsu" and NinjaLineages.hasUzumaki and NinjaLineages.hasUzumaki(player) then
        value = value * NinjaLineages.Balance.Progression.UzumakiFuinjutsuMultiplier
    end
    return math.max(0, math.floor(value + 0.5))
end

function NinjaLineages.Balance.getTrainingPages(tier)
    return NinjaLineages.Balance.Progression.TrainingPages[tier] or 0
end

function NinjaLineages.Balance.scaleNinjaXP(value)
    return math.max(0, value * NinjaLineages.Balance.getSandboxMultiplier("NinjaXPGainMultiplier"))
end
