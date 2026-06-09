NinjaLineages = NinjaLineages or {}
NinjaLineages.Constants = NinjaLineages.Constants or {}
NinjaLineages.Chakra = NinjaLineages.Chakra or {}

-- Chakra capacity & cost constants
local chakraConstants = {
    MAX_BASE_CHAKRA = 100,
    HEALING_JUTSU_COST = 15,
    REINFORCEMENT_JUTSU_COST = 12,
    QUIET_STEP_COST = 10,
    CHAKRA_FOCUS_COST = 8,
    CHAKRA_GRIP_COST = 8,
    BODY_FLICKER_COST = 20,

    -- Advanced Jutsus / Abilities Costs
    SHINRA_BASE_COST = 35,
    SHINRA_COST_PER_ZOMBIE = 3,
    SHINRA_COST_CAP = 75,
    WOOD_ROOTS_COST = 35,
    CREATION_REBIRTH_COST_PER_PART = 1.5,
    KAMUI_MIN_GATE = 20,
    KAMUI_DRAIN_PER_SECOND = 3.0,

    -- Eye sustained drains (per minute in-game time)
    BYAKUGAN_DRAIN_PER_MINUTE = 12.0,
    SHARINGAN_DRAIN_PER_MINUTE = {
        [1] = 8.5,
        [2] = 12.0,
        [3] = 16.3,
    },
    MANGEKYO_DRAIN_PER_MINUTE = 16.3,
}

-- Populate both Constants and Chakra namespaces
for k, v in pairs(chakraConstants) do
    NinjaLineages.Constants[k] = v
    NinjaLineages.Chakra[k] = v
end

-- Sharingan stage thresholds (kills)
NinjaLineages.Constants.SHARINGAN_STAGE_1_KILLS = 1
NinjaLineages.Constants.SHARINGAN_STAGE_2_KILLS = 100
NinjaLineages.Constants.SHARINGAN_STAGE_3_KILLS = 500

-- Ability Tuning Constants (from Effects)
NinjaLineages.Constants.KAMUI_DURATION_MS = 10000
NinjaLineages.Constants.KAMUI_ENDURANCE_MIN = 0.20
NinjaLineages.Constants.KAMUI_ENDURANCE_DRAIN_PER_SECOND = 0.08
NinjaLineages.Constants.KAMUI_COOLDOWN_SECONDS = 15

NinjaLineages.Constants.SHINRA_COOLDOWN_SECONDS = 15
NinjaLineages.Constants.SHINRA_RADIUS = 7.0
NinjaLineages.Constants.SHINRA_GUARANTEED_KNOCKDOWN_RADIUS = 3.5
NinjaLineages.Constants.SHINRA_BASE_ENDURANCE_COST = 0.35
NinjaLineages.Constants.SHINRA_ENDURANCE_COST_PER_ZOMBIE = 0.03
NinjaLineages.Constants.SHINRA_ENDURANCE_COST_CAP = 0.75
NinjaLineages.Constants.SHINRA_MIN_DAMAGE = 0.75
NinjaLineages.Constants.SHINRA_MAX_DAMAGE = 1.10
NinjaLineages.Constants.SHINRA_MIN_DAMAGE_FALLOFF = 0.85

NinjaLineages.Constants.WOOD_ROOTS_RADIUS = 10.0
NinjaLineages.Constants.WOOD_ROOTS_INNER_RADIUS = 6.0
NinjaLineages.Constants.WOOD_ROOTS_COOLDOWN_SECONDS = 45
NinjaLineages.Constants.WOOD_ROOTS_ENDURANCE_COST = 0.35
NinjaLineages.Constants.WOOD_ROOTS_BIND_MS = 3500

NinjaLineages.Constants.CREATION_REBIRTH_DURATION_MS = 8000
NinjaLineages.Constants.CREATION_REBIRTH_TICK_MS = 250
NinjaLineages.Constants.CREATION_REBIRTH_ENDURANCE_PER_PART = 0.015

NinjaLineages.Constants.UZUMAKI_DAMAGE_REFUND = 0.33
NinjaLineages.Constants.UZUMAKI_BLEED_REFUND = 0.75
NinjaLineages.Constants.UZUMAKI_PASSIVE_TICK_MS = 1000

NinjaLineages.Constants.ALARM_SEAL_RADIUS = 2.0
NinjaLineages.Constants.ALARM_SEAL_SCAN_MS = 500
NinjaLineages.Constants.ALARM_SEAL_DISCOVERY_MS = 5000

NinjaLineages.Constants.BYAKUGAN_PUSH_MIN_DAMAGE = 0.18
NinjaLineages.Constants.BYAKUGAN_PUSH_MAX_DAMAGE = 0.75

NinjaLineages.Constants.VISION_RECOVERY_HOURS = { 1, 6, 24 }
NinjaLineages.Constants.VISION_ITEMS = {
    "Base.NL_KamuiVision_L1",
    "Base.NL_KamuiVision_L2",
    "Base.NL_KamuiVision_L3",
}
