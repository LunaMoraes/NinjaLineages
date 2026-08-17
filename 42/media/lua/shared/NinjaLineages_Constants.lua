-- Gameplay tuning lives in NinjaLineages_Balance.lua. This file contains only
-- presentation, protocol, identity, and non-tunable runtime constants.

NinjaLineages = NinjaLineages or {}
NinjaLineages.Constants = NinjaLineages.Constants or {}

NinjaLineages.Constants.Geometry = {
    EPSILON = 0.0001,
    DIRECTION_EPSILON = 0.001,
    COLLISION_TRACE_STEP = 0.20,
    TILE_CENTER_OFFSET = 0.5,
    TILE_DISTANCE_EPSILON = 0.15,
}

NinjaLineages.Constants.Runtime = {
    DemonicFlute = {
        TELEPORT_DISTANCE_SQUARED = 0.25,
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
    Vision = {
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

NinjaLineages.Constants.Medical = {
    ChakraNeedle = {
        VISUAL_DURATION_MS = 400,
        THICKNESS = 2.0,
        COLOR = { R = 0.25, G = 0.55, B = 1.0 },
    },
}
