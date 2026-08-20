require "NinjaLineages_Balance"
require "disciplines/jinchuuriki/NinjaLineages_BijuuDefinitions"

NinjaLineages = NinjaLineages or {}
NinjaLineages.BijuuCombat = NinjaLineages.BijuuCombat or {}

local BijuuCombat = NinjaLineages.BijuuCombat

function BijuuCombat.getTailFactor(tails)
    local t = math.max(1, math.min(9, tonumber(tails) or 1))
    return (t - 1) / 8
end

local function getCombatConfig()
    return NinjaLineages.Balance and NinjaLineages.Balance.Jinchuuriki and NinjaLineages.Balance.Jinchuuriki.BossCombat or {
        HEALTH_1_TAIL = 500.0,
        HEALTH_9_TAIL = 2000.0,
        TELEGRAPH_1_TAIL_MINUTES = 0.8,
        TELEGRAPH_9_TAIL_MINUTES = 0.4,
        SHOT_INTERVAL_1_TAIL_MINUTES = 0.2,
        SHOT_INTERVAL_9_TAIL_MINUTES = 0.06,
        COOLDOWN_1_TAIL_MINUTES = 1.2,
        COOLDOWN_9_TAIL_MINUTES = 0.6,
        DAMAGE_1_TAIL = 18.0,
        DAMAGE_9_TAIL = 35.0,
        PROJECTILE_RANGE = 18.0,
        FAN_STEP_RADIANS = math.rad(9.0),
    }
end

function BijuuCombat.getMaxHealth(tails)
    local f = BijuuCombat.getTailFactor(tails)
    local cfg = getCombatConfig()
    local minHp = cfg.HEALTH_1_TAIL or 500.0
    local maxHp = cfg.HEALTH_9_TAIL or 2000.0
    return minHp + f * (maxHp - minHp)
end

function BijuuCombat.getTelegraphDuration(tails)
    local f = BijuuCombat.getTailFactor(tails)
    local cfg = getCombatConfig()
    local t1 = cfg.TELEGRAPH_1_TAIL_MINUTES or 0.8
    local t9 = cfg.TELEGRAPH_9_TAIL_MINUTES or 0.4
    return t1 - f * (t1 - t9)
end

function BijuuCombat.getShotInterval(tails)
    local f = BijuuCombat.getTailFactor(tails)
    local cfg = getCombatConfig()
    local s1 = cfg.SHOT_INTERVAL_1_TAIL_MINUTES or 0.2
    local s9 = cfg.SHOT_INTERVAL_9_TAIL_MINUTES or 0.06
    return s1 - f * (s1 - s9)
end

function BijuuCombat.getAttackCooldown(tails)
    local f = BijuuCombat.getTailFactor(tails)
    local cfg = getCombatConfig()
    local c1 = cfg.COOLDOWN_1_TAIL_MINUTES or 1.2
    local c9 = cfg.COOLDOWN_9_TAIL_MINUTES or 0.6
    return c1 - f * (c1 - c9)
end

function BijuuCombat.getProjectileDamage(tails)
    local f = BijuuCombat.getTailFactor(tails)
    local cfg = getCombatConfig()
    local d1 = cfg.DAMAGE_1_TAIL or 18.0
    local d9 = cfg.DAMAGE_9_TAIL or 35.0
    return d1 + f * (d9 - d1)
end

function BijuuCombat.generateVolleyTrajectories(originX, originY, originZ, targetX, targetY, targetZ, tailCount, projectileRange, fanAngleStep)
    local count = math.max(1, math.min(9, tonumber(tailCount) or 1))
    local cfg = getCombatConfig()
    local range = tonumber(projectileRange) or cfg.PROJECTILE_RANGE or 18.0
    local step = tonumber(fanAngleStep) or cfg.FAN_STEP_RADIANS or math.rad(9.0)

    local oX = tonumber(originX) or 0
    local oY = tonumber(originY) or 0
    local oZ = tonumber(originZ) or 0
    local tX = tonumber(targetX) or oX
    local tY = tonumber(targetY) or oY

    local dx = tX - oX
    local dy = tY - oY
    local dist = math.sqrt(dx * dx + dy * dy)
    local atan2 = math.atan2 or math.atan
    local baseAngle = dist > 0.001 and atan2(dy, dx) or 0

    local trajectories = {}
    for i = 1, count do
        local offset = 0
        if count > 1 then
            offset = (i - 1 - (count - 1) / 2) * step
        end
        local angle = baseAngle + offset
        local destX = oX + math.cos(angle) * range
        local destY = oY + math.sin(angle) * range
        local destZ = oZ

        table.insert(trajectories, {
            index = i,
            originX = oX,
            originY = oY,
            originZ = oZ,
            destinationX = destX,
            destinationY = destY,
            destinationZ = destZ,
            angle = angle,
        })
    end

    return trajectories
end
