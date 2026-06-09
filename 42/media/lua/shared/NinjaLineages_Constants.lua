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
        COST = 15,
        COOLDOWN_SECONDS = 60,
        HEAL_BASE = 5.0,
        HEAL_PER_PROWESS = 1.5,
    },
    Reinforcement = {
        COST = 12,
        COOLDOWN_SECONDS = 90,
    },
    QuietStep = {
        COST = 10,
        COOLDOWN_SECONDS = 45,
    },
    ChakraFocus = {
        COST = 8,
        COOLDOWN_SECONDS = 60,
    },
    ChakraGrip = {
        COST = 8,
        COOLDOWN_SECONDS = 30,
    },
    BodyFlicker = {
        COST = 20,
        COOLDOWN_SECONDS = 15,
        DURATION_MS = 500,
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
        DRAIN_PER_SECOND = 3.0,
        DURATION_MS = 10000,
        COOLDOWN_SECONDS = 15,
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
    GentleFist = {
        CHAKRA_COST = 2.0,
        DAMAGE_MIN = 0.18,
        DAMAGE_MAX = 0.75,
    },
}

NinjaLineages.Constants.Rinnegan = {
    ShinraTensei = {
        BASE_COST = 35,
        COST_PER_ZOMBIE = 3,
        COST_CAP = 75,
        COOLDOWN_SECONDS = 15,
        RADIUS = 7.0,
        GUARANTEED_KNOCKDOWN_RADIUS = 3.5,
        DAMAGE_MIN = 0.75,
        DAMAGE_MAX = 1.10,
        DAMAGE_MIN_FALLOFF = 0.85,
    },
}

NinjaLineages.Constants.Senju = {
    BindingRoots = {
        COST = 35,
        RADIUS = 10.0,
        INNER_RADIUS = 6.0,
        COOLDOWN_SECONDS = 45,
        BIND_MS = 3500,
        INNER_KNOCKDOWN_CHANCE = 65,
        OUTER_KNOCKDOWN_CHANCE = 35,
    },
    CreationRebirth = {
        DURATION_MS = 8000,
        TICK_MS = 250,
        COST_PER_PART = 1.5,
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
        CHAKRA_COST = 5.0,
        RADIUS = 2.0,
        SCAN_MS = 500,
        DISCOVERY_MS = 5000,
        DISCOVERY_RADIUS = 25,
    },
    StorageSeal = {
        CHAKRA_COST = 10.0,
        UNSEAL_TIME = 80,
    },
}
