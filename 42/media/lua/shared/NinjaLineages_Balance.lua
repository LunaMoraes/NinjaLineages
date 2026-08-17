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
    DASH = 2,
    QUICK = 6,
    SHORT = 12,
    STANDARD = 24,
    LONG = 48,
    VERY_LONG = 120,
}

NinjaLineages.Balance.DurationTier = {
    INSTANT = 0,
    RAPID_TICK = 0.1,
    BURST = 0.2,
    BRIEF = 1.4,
    SHORT = 3.2,
    COMBAT = 4,
    STANDARD = 6,
    LONG = 12,
    VERY_LONG = 24,
    WORLD_HOUR = 60,
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
    LOW = 2.5,
    STANDARD = 5.0,
    HIGH = 7.5,
    EXTREME = 12.5,
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

-- Authoritative gameplay tuning. Runtime modules consume these values directly;
-- visual, protocol, and identity constants remain in NinjaLineages_Constants.lua.
NinjaLineages.Balance.Chakra = {
    MAX_BASE = 100,
    BASE_REGEN_PCT_PER_MINUTE = 0.02,
    MEDITATION_REGEN_MULTIPLIER = 3.0,
    MEDITATION_DRAIN_MULTIPLIER = 0.25,
    COVERED_EYE_DRAIN_MULTIPLIER = 0.5,
    LOW_THRESHOLD = 0.30,
    CRITICAL_THRESHOLD = 0.10,
    CONTROL_MAX_PER_LEVEL = 0.5,
    Nature = {
        MAXIMUM = 100,
        MEDITATION_GAIN_PER_MINUTE = 10,
    },
}

NinjaLineages.Balance.SkillScaling = {
    REGEN_BASE = 1.0,
    REGEN_PER_CONTROL_LEVEL = 0.15,
    DRAIN_BASE = 1.0,
    DRAIN_REDUCTION_PER_CONTROL_LEVEL = 0.05,
    JUTSU_EFFECTIVENESS_BASE = 0.5,
    JUTSU_EFFECTIVENESS_PER_PROWESS_LEVEL = 0.05,
    JUTSU_DURATION_BASE = 1.0,
    JUTSU_DURATION_PER_PROWESS_LEVEL = 0.10,
}

NinjaLineages.Balance.CommonJutsu = {
    Healing = {
        HEAL_BASE = 5.0,
        HEAL_PER_PROWESS = 1.5,
    },
    Dash = {
        STEP_DISTANCE = 0.25,
    },
}

NinjaLineages.Balance.ResourceConversion = {
    CalorieControl = {
        CHAKRA_TO_HUNGER = 0.005,
        CHAKRA_TO_THIRST = 0.01,
    },
    PhysicalReinforcement = {
        CHAKRA_TO_ENDURANCE = 0.005,
        CHAKRA_TO_FATIGUE = 0.01,
    },
    ChakraFocus = {
        CHAKRA_TO_PANIC = 0.5,
        CHAKRA_TO_STRESS = 0.005,
    },
}

NinjaLineages.Balance.Lineages = {
    Uchiha = {
        SharinganStageKills = { [1] = 1, [2] = 100, [3] = 500 },
        SharinganDodgeChance = { [1] = 30, [2] = 60, [3] = 90 },
        VisionRecoveryMinutes = { 60, 360, 1440 },
    },
    Ocular = {
        FULL_POWER_EYE_COUNT = 2,
        FULL_POWER_MULTIPLIER = 1.0,
        SINGLE_EYE_MULTIPLIER = 0.5,
        ByakuganForaging = {
            VISION_BONUS = 5.0,
            WEATHER_EFFECT = 100,
            DARKNESS_EFFECT = 100,
        },
        RinneganForaging = {
            VISION_BONUS = 2.0,
        },
    },
    Senju = {
        CHAKRA_POOL_MULTIPLIER = 2.0,
        CreationRebirth = {
            UNLOCK_LEVEL = 7,
            SCROLL_MIN_MAX_CHAKRA = 500,
            SCROLL_GUARANTEED_MAX_CHAKRA = 900,
        },
        ENDURANCE_PER_MINUTE = 0.15,
    },
    Uzumaki = {
        CHAKRA_POOL_MULTIPLIER = 1.7,
        BLEEDING_REMAINING_PER_MINUTE = 0.5,
        ALARM_RADIUS_TIER = "TOUCH",
        STORAGE_UNSEAL_TIME = 80,
    },
}

NinjaLineages.Balance.SageMode = {
    BASE_MELEE_DAMAGE_MULTIPLIER = 1.20,
    TOAD_MELEE_DAMAGE_MULTIPLIER = 1.40,
    BASE_ATTACK_SPEED_MULTIPLIER = 1.20,
    TOAD_ATTACK_SPEED_MULTIPLIER = 1.35,
    MOVEMENT_SPEED_MULTIPLIER = 1.15,
    BASE_ACCURACY_BONUS = 15,
    SNAKE_ACCURACY_BONUS = 35,
    BASE_JUTSU_DAMAGE_MULTIPLIER = 1.20,
    SNAIL_JUTSU_DAMAGE_MULTIPLIER = 1.40,
    BASE_JUTSU_HEALING_MULTIPLIER = 1.20,
    SNAIL_JUTSU_HEALING_MULTIPLIER = 1.40,
    Trials = {
        MEDITATION_MINUTES = 30,
        TOAD_MELEE_KILLS = 50,
        SNAKE_RANGED_KILLS = 30,
        SNAIL_HEALTH_HEALED = 200,
    },
}

NinjaLineages.Balance.Summoning = {
    COST_TIER = "MAJOR",
    DURATION_TIER = "LONG",
    Toad = {
        ACTION_INTERVAL_MS = 2500,
        TARGET_RADIUS_TIER = "STANDARD",
        SPLASH_RADIUS_TIER = "SMALL",
        DAMAGE_TIER = "HEAVY",
    },
    Snake = {
        ACTION_INTERVAL_MS = 1500,
        TARGET_RADIUS_TIER = "LARGE",
        DAMAGE_TIER = "HEAVY",
    },
    Snail = {
        ACTION_INTERVAL_MS = 4000,
        HEALING_TIER = "HEAVY",
        RADIUS_TIER = "MEDIUM",
    },
}

NinjaLineages.Balance.JutsuRuntime = {
    Projectile = { DEFAULT_SPEED = 20 },
    Kamui = { STEP_DISTANCE = 0.055 },
    Katon = {
        STREAM_DURATION_MS = 750,
        FIRE_ENERGY = 100,
        FIRE_LIFE = 500,
    },
    ChakraNeedle = {
        PROJECTILE_SPEED = 40,
        MAX_TRAVEL_RANGE_MULTIPLIER = 2,
    },
    EarthWall = {
        HEALTH = 250,
        DURATION_TIER = "LONG",
    },
    ShinraTensei = {
        PUSH_STEP = 0.25,
        PUSH_DURATION_MINUTES = 0.28,
        INSTANT_KILL_RADIUS_FACTOR = 0.5,
        MINIMUM_PUSH_FORCE = 2.0,
        MAXIMUM_PUSH_FORCE = 8.0,
        INSTANT_KILL_DAMAGE_FALLBACK = 1000,
    },
    DemonicFlute = {
        SLOW_FACTOR = 0.70,
        MOVEMENT_VARIABLE = 0.3,
    },
    BindingRoots = {
        INNER_KNOCKDOWN_CHANCE = 65,
        OUTER_KNOCKDOWN_CHANCE = 35,
    },
}

NinjaLineages.Balance.NinjaTools = {
    MAINTENANCE_LEVEL_CAP = 10,
    MAXIMUM_RECOVERY_CHANCE = 0.80,
    MAINTENANCE_XP = 2,
}

NinjaLineages.Balance.RareScrolls = {
    LOOT_WEIGHT = 0.2,
    LEARNING_CHANCE_PER_LEVEL = 0.125,
}

NinjaLineages.Balance.Social = {
    INVITE_LIFETIME_SECONDS = 60,
    INVITE_RANGE_TIER = "TOUCH",
    MAX_TEAM_SIZE = 3,
    MAX_FLAG_SEVERITY = 5,
}

NinjaLineages.Balance.GeneExperimentation = {
    ZOMBIE_NINJA_CHANCE_DEFAULT = 20,
    Extraction = {
        MIN_ROLL_FRESHNESS = 60,
        MAX_ROLL_FRESHNESS = 100,
        PERFECT_ROLL_THRESHOLD = 85,
        CORPSE_VALIDATION_RADIUS_TIER = "SMALL",
        CORPSE_FRESHNESS_WINDOW_MINUTES = 10,
        TIMED_ACTION_MAX = 900,
        TIMED_ACTION_MIN = 300,
        TIMED_ACTION_REDUCTION_PER_DOCTOR_LEVEL = 60,
    },
    Surgery = {
        BASE_DURATION = 400,
        PATIENT_RANGE_TIER = "SMALL",
        TIMED_ACTION_BASE = 350,
        TIMED_ACTION_MIN = 120,
        TIMED_ACTION_REDUCTION_PER_DOCTOR_LEVEL = 20,
        MANGEKYO_FRESHNESS_COST = 5,
        HEAD_DAMAGE_FRESHNESS_FACTOR = 0.5,
        RINNEGAN_AWAKENING_CHANCE = 10,
        GENE_EFFECT_DURATION_MINUTES = 3 * 24 * 60,
    },
    BloodTransfusion = {
        TIMED_ACTION_DURATION = 120,
        CHAKRA_RESTORE_COST_TIER = "MAJOR",
        REGEN_DURATION_TIER = "STANDARD",
        REGEN_MULTIPLIER = 1.50,
        SICKNESS_CHANCE_PER_MISSING_FRESHNESS = 0.5,
        SICKNESS_SEVERITY_PER_MISSING_FRESHNESS = 0.4,
    },
    GeneEffects = {
        Buffs = {
            {
                id = "vitality_surge",
                nameKey = "UI_NL_GeneEffect_VitalitySurge_Name",
                descKey = "UI_NL_GeneEffect_VitalitySurge_Desc",
                isBuff = true,
                healthRegenPerMinute = 0.15,
            },
            {
                id = "chakra_surge",
                nameKey = "UI_NL_GeneEffect_ChakraSurge_Name",
                descKey = "UI_NL_GeneEffect_ChakraSurge_Desc",
                isBuff = true,
                chakraRegenMultiplier = 1.35,
            },
            {
                id = "physical_vigor",
                nameKey = "UI_NL_GeneEffect_PhysicalVigor_Name",
                descKey = "UI_NL_GeneEffect_PhysicalVigor_Desc",
                isBuff = true,
                fatigueRecoveryPerMinute = 0.01,
                enduranceRecoveryPerMinute = 0.02,
            },
            {
                id = "agility_infusion",
                nameKey = "UI_NL_GeneEffect_SensoryClarity_Name",
                descKey = "UI_NL_GeneEffect_SensoryClarity_Desc",
                isBuff = true,
                speedMultiplier = 1.10,
            },
        },
        Debuffs = {
            {
                id = "cellular_rejection",
                nameKey = "UI_NL_GeneEffect_CellularRejection_Name",
                descKey = "UI_NL_GeneEffect_CellularRejection_Desc",
                isBuff = false,
                fatigueGainPerMinute = 0.005,
            },
            {
                id = "chakra_instability",
                nameKey = "UI_NL_GeneEffect_ChakraInstability_Name",
                descKey = "UI_NL_GeneEffect_ChakraInstability_Desc",
                isBuff = false,
                chakraCostMultiplier = 1.30,
            },
            {
                id = "muscle_atrophy",
                nameKey = "UI_NL_GeneEffect_PhysicalDegradation_Name",
                descKey = "UI_NL_GeneEffect_PhysicalDegradation_Desc",
                isBuff = false,
                damageMultiplier = 0.80,
            },
            {
                id = "sensory_disorientation",
                nameKey = "UI_NL_GeneEffect_SensoryDisorientation_Name",
                descKey = "UI_NL_GeneEffect_SensoryDisorientation_Desc",
                isBuff = false,
                dizzinessBonus = true,
            },
        },
    },
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
        MEDITATION_INTERVAL_MINUTES = 4,
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

NinjaLineages.Balance.Missions = {
    Generated = {
        PoolSize = 3,
        GenerationIntervalHours = 1,
        ExpiryHours = 24,
        KillZombieRanges = {
            D = { minimum = 10, maximum = 20 },
            C = { minimum = 20, maximum = 40 },
            B = { minimum = 40, maximum = 75 },
            A = { minimum = 75, maximum = 125 },
            S = { minimum = 125, maximum = 200 },
        },
    },
    NinjaXP = {
        D = 25,
        C = 50,
        B = 100,
        A = 200,
        S = 400,
    },
    VillageXP = {
        D = 10,
        C = 20,
        B = 40,
        A = 80,
        S = 160,
    },
    VillageRankUnlockXP = {
        B = 100,
        A = 300,
        S = 700,
    },
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
    CHAKRA_CONTROL_TICK_MINUTES = 2,
    CHAKRA_CONTROL_TICK_XP = 1.5,
    CHAKRA_CONTROL_COMPLETION_XP = 10.0,
    ACTION_TICKS = 3000,
}

NinjaLineages.Balance.TraitCostTier = {
    STANDARD_LINEAGE = 14,
    RARE_LINEAGE = 18,
    MYTHIC_LINEAGE = 24,
}

local function isDebugMode()
    return (isDebugEnabled and isDebugEnabled())
        or (SandboxVars and SandboxVars.NinjaLineages and SandboxVars.NinjaLineages.DebugMode == true)
end

local function warnInvalidTier(category, tier)
    if tier ~= nil and isDebugMode() then
        print(string.format("[NinjaLineages.Balance] [DEBUG] Invalid %s: '%s'", tostring(category), tostring(tier)))
    end
end

function NinjaLineages.Balance.getCost(tier)
    if tier and not NinjaLineages.Balance.ChakraCostTier[tier] then
        warnInvalidTier("ChakraCostTier", tier)
    end
    return NinjaLineages.Balance.ChakraCostTier[tier] or 0
end

function NinjaLineages.Balance.getCostStep(tier)
    if tier and not NinjaLineages.Balance.ChakraCostStepTier[tier] then
        warnInvalidTier("ChakraCostStepTier", tier)
    end
    return NinjaLineages.Balance.ChakraCostStepTier[tier] or 0
end

function NinjaLineages.Balance.getCooldown(tier)
    if tier and not NinjaLineages.Balance.CooldownTier[tier] then
        warnInvalidTier("CooldownTier", tier)
    end
    return NinjaLineages.Balance.CooldownTier[tier] or 0
end

function NinjaLineages.Balance.getDuration(tier)
    if tier and not NinjaLineages.Balance.DurationTier[tier] then
        warnInvalidTier("DurationTier", tier)
    end
    return NinjaLineages.Balance.DurationTier[tier] or 0
end

function NinjaLineages.Balance.getRadius(tier)
    if tier and not NinjaLineages.Balance.RadiusTier[tier] then
        warnInvalidTier("RadiusTier", tier)
    end
    return NinjaLineages.Balance.RadiusTier[tier] or 0
end

function NinjaLineages.Balance.getSustainedDrain(tier)
    if tier and not NinjaLineages.Balance.SustainedDrainTier[tier] then
        warnInvalidTier("SustainedDrainTier", tier)
    end
    return NinjaLineages.Balance.SustainedDrainTier[tier] or 0
end

function NinjaLineages.Balance.getChannelDrain(tier)
    if tier and not NinjaLineages.Balance.ChannelDrainTier[tier] then
        warnInvalidTier("ChannelDrainTier", tier)
    end
    return NinjaLineages.Balance.ChannelDrainTier[tier] or 0
end

function NinjaLineages.Balance.getDamageRange(tier)
    local range = NinjaLineages.Balance.DamageTier[tier]
    if not range then
        warnInvalidTier("DamageTier", tier)
        return 0, 0
    end
    return range.min, range.max
end

function NinjaLineages.Balance.rollDamage(tier)
    if tier and not NinjaLineages.Balance.DamageTier[tier] then
        warnInvalidTier("DamageTier", tier)
    end
    local minDamage, maxDamage = NinjaLineages.Balance.getDamageRange(tier)
    local damageRoll = ZombRand(0, 1001) / 1000
    return minDamage + (damageRoll * (maxDamage - minDamage))
end

function NinjaLineages.Balance.getHealing(tier)
    if tier and not NinjaLineages.Balance.HealingTier[tier] then
        warnInvalidTier("HealingTier", tier)
    end
    return NinjaLineages.Balance.HealingTier[tier]
end

function NinjaLineages.Balance.getTargeting(tier)
    local definition = NinjaLineages.Balance.TargetingTier[tier]
    if not definition then
        warnInvalidTier("TargetingTier", tier)
        return nil
    end
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
    if tier and not NinjaLineages.Balance.MasteryTier[tier] then
        warnInvalidTier("MasteryTier", tier)
    end
    return NinjaLineages.Balance.MasteryTier[tier] or 0
end

function NinjaLineages.Balance.getGeneEffect(id)
    if not id then return nil end
    local definitions = NinjaLineages.Balance.GeneExperimentation.GeneEffects
    for _, definition in ipairs(definitions.Buffs) do
        if definition.id == id then return definition end
    end
    for _, definition in ipairs(definitions.Debuffs) do
        if definition.id == id then return definition end
    end
    return nil
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
    local pages = NinjaLineages.Balance.Progression.TrainingPages[tier] or 0
    local trainingSetting = SandboxVars and SandboxVars.NinjaLineages and SandboxVars.NinjaLineages.TrainingTime or 1
    if trainingSetting == 2 then
        pages = pages / 2
    elseif trainingSetting == 3 then
        pages = pages / 4
    end
    return pages
end

function NinjaLineages.Balance.scaleNinjaXP(value)
    return math.max(0, value * NinjaLineages.Balance.getSandboxMultiplier("NinjaXPGainMultiplier"))
end
