-- Post-balance constants. Current costs/cooldowns/durations/radius/damage live in NinjaLineages_Balance.lua.
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
    BodyFlicker = {
        BOOST_MULTIPLIER = 0.25,
    },
}

NinjaLineages.Constants.Uchiha = {
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
    SharinganDrainPerMinute = {
        [1] = 8.5,
        [2] = 12.0,
        [3] = 16.3,
    },
    MangekyoDrainPerMinute = 16.3,
    Kamui = {
        MIN_CHAKRA_GATE = 20,
        DURATION_MS = 10000,
    },
    Vision = {
        RECOVERY_HOURS = { 1, 6, 24 },
        ITEMS = {
            "Base.NL_KamuiVision_L1",
            "Base.NL_KamuiVision_L2",
            "Base.NL_KamuiVision_L3",
        },
    },
}

NinjaLineages.Constants.Hyuga = {
    ByakuganDrainPerMinute = 12.0,
}

NinjaLineages.Constants.Rinnegan = {
    ShinraTensei = {
        GUARANTEED_KNOCKDOWN_RADIUS = 3.5,
        DAMAGE_MIN_FALLOFF = 0.85,
    },
}

NinjaLineages.Constants.Senju = {
    BindingRoots = {
        INNER_RADIUS = 6.0,
        INNER_KNOCKDOWN_CHANCE = 65,
        OUTER_KNOCKDOWN_CHANCE = 35,
    },
    CreationRebirth = {
        TICK_MS = 250,
    },
    Passive = {
        ENDURANCE_PER_MINUTE = 0.15,
    },
}

NinjaLineages.Constants.Uzumaki = {
    Passive = {
        DAMAGE_REFUND = 0.33,
        BLEED_REFUND = 0.75,
        TICK_MS = 1000,
    },
    AlarmSeal = {
        RADIUS = 2.0,
        SCAN_MS = 500,
        DISCOVERY_MS = 5000,
        DISCOVERY_RADIUS = 25,
    },
    StorageSeal = {
        UNSEAL_TIME = 80,
    },
}
