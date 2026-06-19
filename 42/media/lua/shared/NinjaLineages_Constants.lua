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
}

NinjaLineages.Constants.Uchiha = {
    Audio = {
        ACTIVATION_VOICE = "NLSharinganActivation",
        DODGE_EFFECT = "NLSharinganDodge",
    },
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
    Passive = {
        DAMAGE_REFUND = 0.33,
        BLEED_REFUND = 0.75,
        TICK_MINUTES = 0.4,
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
    NervousSystemShock = {
        VISUAL_DURATION_MS = 400,
        THICKNESS = 2.5,
        COLOR = { R = 0.65, G = 0.25, B = 0.85 },
    },
}

NinjaLineages.Constants.CalorieControl = {
    CHAKRA_TO_HUNGER = 0.005,  -- 1% hunger (0.01) restored per 2 chakra spent (200 chakra = 100% hunger)
    CHAKRA_TO_THIRST = 0.01,   -- 1% thirst (0.01) restored per 1 chakra spent (100 chakra = 100% thirst)
}
