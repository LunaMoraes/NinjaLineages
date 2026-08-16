-- Global balance tiers live in NinjaLineages_Balance.lua; per-jutsu tuning lives in NinjaLineages_JutsuCatalog.lua.
-- This file only contains constants that define specific mechanics, identity states, or scaling formulas.

NinjaLineages = NinjaLineages or {}
NinjaLineages.Constants = NinjaLineages.Constants or {}

NinjaLineages.Constants.Chakra = {
    MAX_BASE = 100,
    BASE_REGEN_PCT_PER_MINUTE = 0.02,
    MEDITATION_REGEN_MULTIPLIER = 3.0,
    MEDITATION_DRAIN_MULTIPLIER = 0.25,
    COVERED_EYE_DRAIN_MULTIPLIER = 0.5,
    LOW_THRESHOLD = 0.30,
    CRITICAL_THRESHOLD = 0.10,
}

NinjaLineages.Constants.CommonJutsu = {
    Healing = {
        HEAL_BASE = 5.0,
        HEAL_PER_PROWESS = 1.5,
    },
    Dash = {
        STEP_DISTANCE = 0.25,
    },
}

NinjaLineages.Constants.GenJutsu = {
    CommonVisual = {
        VISUAL_DURATION_MS = 1000,
        VISUAL_HOLD_MS = 650,
        CIRCLE_SEGMENTS = 64,
        CIRCLE_THICKNESS = 2.0,
        CIRCLE_ALPHA = 0.85,
    },
    BringerOfDarkness = {
        VISUAL_DURATION_MS = 1000,
        VISUAL_HOLD_MS = 650,
        CIRCLE_SEGMENTS = 64,
        CIRCLE_THICKNESS = 2.0,
        CIRCLE_COLOR = {
            R = 0.32,
            G = 0.08,
            B = 0.48,
        },
        CIRCLE_ALPHA = 0.85,
        BLIND_ITEM = "Base.NL_BringerOfDarknessBlind",
    },
    DemonicFlute = {
        VISUAL_DURATION_MS = 1000,
        VISUAL_HOLD_MS = 650,
        CIRCLE_SEGMENTS = 64,
        CIRCLE_THICKNESS = 2.0,
        CIRCLE_COLOR = {
            R = 0.75,
            G = 0.25,
            B = 0.80,
        },
        CIRCLE_ALPHA = 0.85,
    },
}

NinjaLineages.Constants.Uchiha = {
    Audio = {
        ACTIVATION_VOICE = "NLSharinganActivation",
        DODGE_EFFECT = "NLSharinganDodge",
    },
    PVP_DODGE_DEDUP_MS = 300,
    SharinganStageKills = {
        [1] = 1,
        [2] = 100,
        [3] = 500,
    },
    SharinganDodgeChance = {
        [1] = 30,
        [2] = 60,
        [3] = 90,
    },
    Vision = {
        RECOVERY_MINUTES = { 60, 360, 1440 },
        ITEMS = {
            "Base.NL_KamuiVision_L1",
            "Base.NL_KamuiVision_L2",
            "Base.NL_KamuiVision_L3",
        },
    },
}

NinjaLineages.Constants.Hyuga = {
    Audio = {
        ACTIVATION_VOICE = "NLByakuganActivation",
    },
}

NinjaLineages.Constants.Rinnegan = {
    ShinraTensei = {
        ACTIVATION_VOICE = "NLShinraTenseiActivation",
        PUSH_STEP = 0.25,
        PUSH_DURATION_MINUTES = 0.28,
        VISUAL_DURATION_MS = 700,
        PULSE_SEGMENTS = 64,
        PULSE_THICKNESS = 2.0,
        PULSE_COLOR = {
            R = 0.58,
            G = 0.20,
            B = 0.86,
        },
    },
}

NinjaLineages.Constants.Senju = {
    CHAKRA_POOL_MULTIPLIER = 2.0,
    CreationRebirth = {
        SENJU_UNLOCK_LEVEL = 7,
        SCROLL_MIN_MAX_CHAKRA = 500,
        SCROLL_GUARANTEED_MAX_CHAKRA = 900,
    },
    Passive = {
        ENDURANCE_PER_MINUTE = 0.15,
    },
}

NinjaLineages.Constants.Uzumaki = {
    CHAKRA_POOL_MULTIPLIER = 1.7,
    Passive = {
        BLEEDING_REMAINING_PER_MINUTE = 0.5,
    },
    AlarmSeal = {
        RADIUS = 2.0,
    },
    StorageSeal = {
        UNSEAL_TIME = 80,
    },
}

NinjaLineages.Constants.Medical = {
    ChakraNeedle = {
        VISUAL_DURATION_MS = 400,
        THICKNESS = 2.0,
        COLOR = { R = 0.25, G = 0.55, B = 1.0 },
    },
}

NinjaLineages.Constants.CalorieControl = {
    CHAKRA_TO_HUNGER = 0.005,  -- 1% hunger (0.01) restored per 2 chakra spent (200 chakra = 100% hunger)
    CHAKRA_TO_THIRST = 0.01,   -- 1% thirst (0.01) restored per 1 chakra spent (100 chakra = 100% thirst)
}

NinjaLineages.Constants.PhysicalReinforcement = {
    CHAKRA_TO_ENDURANCE = 0.005,
    CHAKRA_TO_FATIGUE = 0.01,
}

NinjaLineages.Constants.ChakraFocus = {
    CHAKRA_TO_PANIC = 0.5,
    CHAKRA_TO_STRESS = 0.005,
}

NinjaLineages.Constants.GeneExperimentation = {
    Extraction = {
        MIN_ROLL_FRESHNESS = 60,
        MAX_ROLL_FRESHNESS = 100,
        PERFECT_ROLL_THRESHOLD = 85,
    },
    Surgery = {
        BASE_DURATION = 400,
        MANGEKYO_FRESHNESS_COST = 5,
        HEAD_DAMAGE_FRESHNESS_FACTOR = 0.5,
        RINNEGAN_AWAKENING_CHANCE = 10,
        GENE_EFFECT_DURATION_MINUTES = 3 * 24 * 60, -- 4320 in-game minutes (3 days)
    },
    GeneEffects = {
        Buffs = {
            {
                id = "vitality_surge",
                nameKey = "UI_NL_GeneEffect_vitality_surge_Name",
                descKey = "UI_NL_GeneEffect_vitality_surge_Desc",
                isBuff = true,
                healthRegenBonus = 0.30,
            },
            {
                id = "chakra_surge",
                nameKey = "UI_NL_GeneEffect_chakra_surge_Name",
                descKey = "UI_NL_GeneEffect_chakra_surge_Desc",
                isBuff = true,
                chakraRegenBonus = 0.35,
            },
            {
                id = "physical_vigor",
                nameKey = "UI_NL_GeneEffect_physical_vigor_Name",
                descKey = "UI_NL_GeneEffect_physical_vigor_Desc",
                isBuff = true,
                fatigueMultiplier = 0.50,
                enduranceMultiplier = 1.50,
            },
            {
                id = "agility_infusion",
                nameKey = "UI_NL_GeneEffect_agility_infusion_Name",
                descKey = "UI_NL_GeneEffect_agility_infusion_Desc",
                isBuff = true,
                speedMultiplier = 1.10,
            },
        },
        Debuffs = {
            {
                id = "cellular_rejection",
                nameKey = "UI_NL_GeneEffect_cellular_rejection_Name",
                descKey = "UI_NL_GeneEffect_cellular_rejection_Desc",
                isBuff = false,
                fatigueMultiplier = 1.50,
                enduranceMultiplier = 0.70,
            },
            {
                id = "chakra_instability",
                nameKey = "UI_NL_GeneEffect_chakra_instability_Name",
                descKey = "UI_NL_GeneEffect_chakra_instability_Desc",
                isBuff = false,
                chakraCostMultiplier = 1.30,
            },
            {
                id = "muscle_atrophy",
                nameKey = "UI_NL_GeneEffect_muscle_atrophy_Name",
                descKey = "UI_NL_GeneEffect_muscle_atrophy_Desc",
                isBuff = false,
                damageMultiplier = 0.80,
            },
            {
                id = "sensory_disorientation",
                nameKey = "UI_NL_GeneEffect_sensory_disorientation_Name",
                descKey = "UI_NL_GeneEffect_sensory_disorientation_Desc",
                isBuff = false,
                dizzinessBonus = true,
            },
        },
    },
}

