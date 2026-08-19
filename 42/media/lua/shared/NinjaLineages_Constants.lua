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

NinjaLineages.Constants.Summoning = {
    Colors = {
        toad = { R = 1.0, G = 0.50, B = 0.08 },
        snake = { R = 0.68, G = 0.15, B = 0.90 },
        snail = { R = 0.15, G = 0.88, B = 0.92 },
    },
    VFX = {
        MARKER_INNER_RADIUS = 0.22,
        MARKER_OUTER_RADIUS = 0.42,
        MARKER_THICKNESS = 2.0,
        MARKER_ALPHA_BASE = 0.65,
        MARKER_ALPHA_PULSE = 0.25,
        POOF_DURATION_GAME_MINUTES = 0.05,
        POOF_MAX_RADIUS = 1.5,
        TOAD_SLAM_DURATION_GAME_MINUTES = 0.06,
        TOAD_SLAM_MAX_RADIUS = 3.5,
        SNAKE_STRIKE_DURATION_GAME_MINUTES = 0.03,
        SNAKE_STRIKE_THICKNESS = 4.0,
        KATSUYU_WAVE_DURATION_GAME_MINUTES = 0.08,
        KATSUYU_WAVE_MAX_RADIUS = 6.0,
    },
}

NinjaLineages.Constants.Rasengan = {
    Color = { R = 0.15, G = 0.70, B = 1.0 },
    CoreColor = { R = 0.90, G = 0.96, B = 1.0 },
    CORE_RADIUS = 0.25,
    SHELL_RADIUS = 0.40,
    SWIRL_RADIUS = 0.45,
    SWIRL_THICKNESS = 2.0,
    ROTATION_SPEED_RAD_PER_GAME_MINUTE = 50.0,
    WALL_BURST_DURATION_GAME_MINUTES = 0.05,
    WALL_BURST_MAX_RADIUS = 3.0,
    RASENGAN_FADEOUT_DURATION_GAME_MINUTES = 0.04,
}

