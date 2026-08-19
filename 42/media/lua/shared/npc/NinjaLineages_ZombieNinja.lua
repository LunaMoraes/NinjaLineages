require "NinjaLineages_Balance"
require "NinjaLineages_Constants"
require "NinjaLineages_Utils"
require "NinjaLineages_JutsuCatalog"
require "combat/NinjaLineages_Collision"

NinjaLineages = NinjaLineages or {}
NinjaLineages.ZombieNinja = NinjaLineages.ZombieNinja or {}
local ZombieNinja = NinjaLineages.ZombieNinja
local Balance = NinjaLineages.Balance
local JutsuCatalog = NinjaLineages.JutsuCatalog
local Collision = NinjaLineages.Collision

ZombieNinja.Jutsu = {
    DASH = "dash",
    KILLING_INTENT = "killing_intent",
    SUBSTITUTION = "substitution_jutsu",
    SNARE = "snare_jutsu",
}

ZombieNinja.Commands = {
    REQUEST_JUTSU = "zombieNinjaJutsuRequest",
    JUTSU_ACK = "zombieNinjaJutsuAck",
    EXECUTE_JUTSU = "zombieNinjaExecuteJutsu",
    ROLL_MUTATION = "rollZombieNinja",
    SYNC_STATE = "syncZombieNinjaState",
    SUBSTITUTION_TRIGGER = "zombieNinjaSubstitutionTrigger",
}

function ZombieNinja.rollMutation(zombie)
    if not zombie then return false end
    local modData = zombie:getModData()
    if modData.zombieNinjaRolled then return modData.isZombieNinja == true end
    modData.zombieNinjaRolled = true
    local chance = SandboxVars and SandboxVars.NinjaLineages
        and SandboxVars.NinjaLineages.ZombieNinjaChance
        or (Balance.GeneExperimentation and Balance.GeneExperimentation.ZOMBIE_NINJA_CHANCE_DEFAULT)
        or 10
    modData.isZombieNinja = (ZombRand(0, 100) < chance)
    return modData.isZombieNinja
end

function ZombieNinja.isZombieNinja(zombie)
    if not zombie then return false end
    local modData = zombie:getModData()
    return modData and modData.isZombieNinja == true
end

function ZombieNinja.canAct(zombie)
    if not zombie or zombie:isDead() then return false end
    if zombie:isKnockedDown() or zombie:isFalling() or zombie:isProne() or zombie:isGettingUp() then
        return false
    end
    return true
end

function ZombieNinja.isValidTarget(zombie, player)
    if not player or not instanceof(player, "IsoPlayer") or player:isDead() then return false end
    if player:isGhostMode() then return false end
    if not zombie then return false end
    if math.floor(player:getZ()) ~= math.floor(zombie:getZ()) then return false end
    if zombie:getTarget() ~= player then return false end
    return true
end

function ZombieNinja.isCooldownReady(zombie, nowGameMinutes)
    if not zombie then return false end
    local nextAt = zombie:getModData().nextZombieJutsuAt or 0
    return nowGameMinutes >= nextAt
end

function ZombieNinja.isSubstitutionArmed(zombie)
    if not zombie then return false end
    return zombie:getModData().zombieNinjaSubstitutionArmed == true
end

function ZombieNinja.calculateDashGeometry(zombie, player)
    local desiredStopRange = Balance.getRadius("TOUCH")
    local maxTravel = Balance.getRadius("SMALL")
    local currentDistance = zombie:DistTo(player)
    local travelDistance = math.min(maxTravel, math.max(0, currentDistance - desiredStopRange))

    local dx = player:getX() - zombie:getX()
    local dy = player:getY() - zombie:getY()
    local len = math.sqrt((dx * dx) + (dy * dy))
    local dirX, dirY
    if len > 0.0001 then
        dirX, dirY = dx / len, dy / len
    else
        dirX, dirY = 0, 1
    end

    local duration = Balance.getDuration("BURST")

    return {
        directionX = dirX,
        directionY = dirY,
        travelDistance = travelDistance,
        duration = duration,
    }
end

function ZombieNinja.calculateSnareGeometry(zombie, player)
    local desiredStopRange = Balance.getRadius("TOUCH")
    local maxPull = Balance.getRadius("SMALL")
    local currentDistance = zombie:DistTo(player)
    local pullDistance = math.min(maxPull, math.max(0, currentDistance - desiredStopRange))
    local duration = Balance.getDuration("BURST")

    return {
        pullDistance = pullDistance,
        duration = duration,
    }
end

function ZombieNinja.calculateKillingIntentMagnitude()
    local resolved = JutsuCatalog.resolveBalance("killing_intent")
    local cost = resolved and resolved.cost or Balance.getCost("STANDARD")
    local conversion = Balance.ResourceConversion
        and Balance.ResourceConversion.ChakraFocus
        and Balance.ResourceConversion.ChakraFocus.CHAKRA_TO_PANIC
        or 1.0
    return cost * conversion
end

local function isValidDestinationSquare(zombie, x, y, z)
    local cell = getCell()
    if not cell then return false end
    local square = cell:getGridSquare(x, y, z)
    if not square then return false end
    if square:isSolid() or square:isSolidTrans() then return false end
    if not square:isFree(false) then return false end

    local hit = Collision.traceSegment(
        zombie:getX(), zombie:getY(), zombie:getZ(),
        x, y, z,
        Collision.Masks.jutsu_projectile
    )
    if hit ~= nil then return false end

    return true
end

function ZombieNinja.findSubstitutionDestination(zombie, attacker)
    if not zombie or not attacker then return nil end
    local z = math.floor(zombie:getZ())
    local forward = attacker:getForwardDirection()
    local fX = forward and forward:getX() or 0
    local fY = forward and forward:getY() or 1
    local fLen = math.sqrt((fX * fX) + (fY * fY))
    if fLen > 0.0001 then
        fX, fY = fX / fLen, fY / fLen
    else
        fX, fY = 0, 1
    end

    local perpX = -fY
    local perpY = fX
    local touchDist = Balance.getRadius("TOUCH")

    -- 3 preferred candidates relative to attacker
    local candidates = {
        { x = attacker:getX() - (fX * touchDist), y = attacker:getY() - (fY * touchDist) }, -- Behind attacker
        { x = attacker:getX() + (perpX * touchDist), y = attacker:getY() + (perpY * touchDist) }, -- Perpendicular side 1
        { x = attacker:getX() - (perpX * touchDist), y = attacker:getY() - (perpY * touchDist) }, -- Perpendicular side 2
    }

    for _, cand in ipairs(candidates) do
        local testX, testY = cand.x, cand.y
        if isValidDestinationSquare(zombie, testX, testY, z) then
            return { x = testX, y = testY, z = z }
        end
    end

    -- Fallback search inside Balance.getRadius("SMALL")
    local searchRadius = Balance.getRadius("SMALL")
    local idealX = candidates[1].x
    local idealY = candidates[1].y
    local bestSquare = nil
    local bestDist = 99999

    local minX = math.floor(attacker:getX() - searchRadius)
    local maxX = math.ceil(attacker:getX() + searchRadius)
    local minY = math.floor(attacker:getY() - searchRadius)
    local maxY = math.ceil(attacker:getY() + searchRadius)

    for gx = minX, maxX do
        for gy = minY, maxY do
            local testX = gx + 0.5
            local testY = gy + 0.5
            local dAttacker = math.sqrt((testX - attacker:getX())^2 + (testY - attacker:getY())^2)
            if dAttacker <= searchRadius then
                if isValidDestinationSquare(zombie, testX, testY, z) then
                    local dIdeal = math.sqrt((testX - idealX)^2 + (testY - idealY)^2)
                    if dIdeal < bestDist then
                        bestDist = dIdeal
                        bestSquare = { x = testX, y = testY, z = z }
                    end
                end
            end
        end
    end

    return bestSquare
end

function ZombieNinja.getEligibleJutsus(zombie, player, nowGameMinutes)
    if not ZombieNinja.isZombieNinja(zombie) then return {} end
    if not ZombieNinja.canAct(zombie) then return {} end
    if not ZombieNinja.isValidTarget(zombie, player) then return {} end
    if ZombieNinja.isSubstitutionArmed(zombie) then return {} end
    if not ZombieNinja.isCooldownReady(zombie, nowGameMinutes) then return {} end

    local eligible = {}
    local dist = zombie:DistTo(player)
    local touchRadius = Balance.getRadius("TOUCH")
    local mediumRadius = Balance.getRadius("MEDIUM")

    -- 1. Dash / Body Flicker: distance > TOUCH and distance <= MEDIUM
    if dist > touchRadius and dist <= mediumRadius then
        table.insert(eligible, ZombieNinja.Jutsu.DASH)
    end

    -- 2. Killing Intent: distance <= resolved.radius
    local resolvedKi = JutsuCatalog.resolveBalance("killing_intent")
    local kiRadius = resolvedKi and resolvedKi.radius or Balance.getRadius("SMALL")
    if dist <= kiRadius then
        table.insert(eligible, ZombieNinja.Jutsu.KILLING_INTENT)
    end

    -- 3. Substitution: eligible when canAct & validTarget & not armed
    table.insert(eligible, ZombieNinja.Jutsu.SUBSTITUTION)

    -- 4. Snare: distance > TOUCH and distance <= STANDARD.range, with clear line of effect
    local snareRange = Balance.getTargeting("STANDARD").range
    if dist > touchRadius and dist <= snareRange then
        local hit = Collision.traceSegment(
            zombie:getX(), zombie:getY(), zombie:getZ(),
            player:getX(), player:getY(), player:getZ(),
            Collision.Masks.jutsu_projectile
        )
        if hit == nil then
            table.insert(eligible, ZombieNinja.Jutsu.SNARE)
        end
    end

    return eligible
end

function ZombieNinja.selectRandomJutsu(eligible)
    if not eligible or #eligible == 0 then return nil end
    local idx = ZombRand(#eligible) + 1
    return eligible[idx]
end
