require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "NinjaLineages_Chakra"
require "NinjaLineages_Balance"
require "NinjaLineages_JutsuCatalog"

NinjaLineages = NinjaLineages or {}
NinjaLineages.RinneganMechanics = NinjaLineages.RinneganMechanics or {}

local mechanics = NinjaLineages.RinneganMechanics
local consts = NinjaLineages.Constants
local activePushes = {}
local nextPushUpdateAt = 0

function mechanics.getRadius()
    return NinjaLineages.JutsuCatalog.resolveBalance("shinra_tensei").radius
end

function mechanics.collectTargets(player)
    local targets = {}
    local zombies = getCell() and getCell():getZombieList()
    if not player or not zombies then return targets end

    local radius = mechanics.getRadius()
    local playerZ = math.floor(player:getZ())
    for i = 0, zombies:size() - 1 do
        local zombie = zombies:get(i)
        if zombie and not zombie:isDead() and math.floor(zombie:getZ()) == playerZ then
            local dx = zombie:getX() - player:getX()
            local dy = zombie:getY() - player:getY()
            local distance = math.sqrt((dx * dx) + (dy * dy))
            if distance <= radius then
                table.insert(targets, {
                    zombie = zombie,
                    distance = distance,
                    dx = dx,
                    dy = dy,
                })
            end
        end
    end
    return targets
end

function mechanics.getCost(targetCount)
    local resolved = NinjaLineages.JutsuCatalog.resolveBalance("shinra_tensei")
    local baseCost = resolved.cost
    local stepCost = resolved.costStep
    local capCost = resolved.maximumCost
    return math.min(capCost, baseCost + (targetCount * stepCost))
end

function mechanics.validateCast(player, targets)
    if not player or not NinjaLineages.hasRinnegan(player) then
        return false, "lineage"
    end

    local onCooldown, remaining = NinjaLineages.Cooldowns.isOnCooldown(
        player,
        NinjaLineages.JutsuCatalog.getCooldownKey("shinra_tensei")
    )
    if onCooldown then
        return false, "cooldown", remaining
    end

    targets = targets or mechanics.collectTargets(player)
    local cost = mechanics.getCost(#targets)
    if not NinjaLineages.Chakra.canAffordChakra(player, cost) then
        return false, "chakra"
    end

    return true, nil, nil, cost
end

local function getKnockdownChance(distance)
    local radius = mechanics.getRadius()
    local guaranteedRadius = NinjaLineages.JutsuCatalog.resolveBalance("shinra_tensei")
        .guaranteedKnockdownRadius
    if distance <= guaranteedRadius then return 100 end

    local outerRange = radius - guaranteedRadius
    if outerRange <= 0 then return 0 end

    local remaining = math.max(0, radius - distance)
    return math.floor((remaining / outerRange) * 100)
end

local function getPushDirection(player, target)
    if target.distance > 0.001 then
        return target.dx / target.distance, target.dy / target.distance
    end

    local forward = player:getForwardDirection()
    if forward then
        local dx = forward:getX()
        local dy = forward:getY()
        local length = math.sqrt((dx * dx) + (dy * dy))
        if length > 0.001 then
            return dx / length, dy / length
        end
    end
    return 1, 0
end

local function canEnterSquare(fromSquare, toSquare)
    if not fromSquare or not toSquare then return false end
    if fromSquare == toSquare then return true end
    if not toSquare:TreatAsSolidFloor() then return false end
    if toSquare:isSolid() or toSquare:isSolidTrans() then return false end
    if not toSquare:isFree(false) then return false end
    if fromSquare:isBlockedTo(toSquare) then return false end
    return true
end

local function getValidPush(player, target)
    local zombie = target.zombie
    local distanceToPush = math.max(0, mechanics.getRadius() - target.distance)
    local dirX, dirY = getPushDirection(player, target)
    local startX = zombie:getX()
    local startY = zombie:getY()
    local z = math.floor(zombie:getZ())
    if distanceToPush <= 0 then
        return startX, startY, dirX, dirY, 0
    end

    local stepSize = consts.Rinnegan.ShinraTensei.PUSH_STEP
    local travelled = 0
    local currentSquare = zombie:getCurrentSquare()

    while travelled < distanceToPush do
        local nextTravelled = math.min(distanceToPush, travelled + stepSize)
        local nextX = startX + (dirX * nextTravelled)
        local nextY = startY + (dirY * nextTravelled)
        local nextSquare = getCell():getGridSquare(nextX, nextY, z)

        if not canEnterSquare(currentSquare, nextSquare) then
            break
        end

        currentSquare = nextSquare
        travelled = nextTravelled
    end

    return startX, startY, dirX, dirY, travelled
end

local function applyDamage(player, state)
    local zombie = state.zombie
    local radius = mechanics.getRadius()
    if state.startDistance <= radius / 2 then
        local ok, health = pcall(function() return zombie:getHealth() end)
        NinjaLineages.Utils.Combat.applyZombieDamage(player, zombie, ok and health or 1000)
        return
    end

    local travelRatio = math.min(1, state.maxTravel / radius)
    local damage = NinjaLineages.JutsuCatalog.resolveBalance("shinra_tensei").damage
    local minDamage, maxDamage = damage.min, damage.max
    local damage = minDamage + ((maxDamage - minDamage) * travelRatio)
    NinjaLineages.Utils.Combat.applyZombieDamage(player, zombie, damage)
end

local function finishPush(state)
    local zombie = state.zombie
    if not zombie or zombie:isDead() then return end
    local knockdown = ZombRand(1, 101) <= getKnockdownChance(state.startDistance)
    local force = math.max(2.0, 8.0 - state.startDistance)
    NinjaLineages.Utils.Combat.staggerZombie(zombie, {
        knockdown = knockdown,
        position = "FRONT",
        force = force,
    })
    applyDamage(state.player, state)
end

local function beginPush(player, target, startedAt)
    local zombie = target.zombie
    if not zombie or zombie:isDead() then return end
    local startX, startY, dirX, dirY, maxTravel = getValidPush(player, target)
    table.insert(activePushes, {
        player = player,
        zombie = zombie,
        startX = startX,
        startY = startY,
        dirX = dirX,
        dirY = dirY,
        startDistance = target.distance,
        maxTravel = maxTravel,
        lastTravel = 0,
        startedAt = startedAt,
    })
end

function mechanics.update()
    if #activePushes == 0 then return end
    local now = NinjaLineages.Utils.Time.nowMs()
    if now < nextPushUpdateAt then return end
    nextPushUpdateAt = now + consts.Rinnegan.ShinraTensei.PUSH_UPDATE_INTERVAL_MS

    local duration = consts.Rinnegan.ShinraTensei.PULSE_DURATION_MS
    local radius = mechanics.getRadius()

    for i = #activePushes, 1, -1 do
        local state = activePushes[i]
        local zombie = state.zombie
        if not zombie or zombie:isDead() then
            table.remove(activePushes, i)
        else
            local progress = math.min(1, math.max(0, (now - state.startedAt) / duration))
            local waveRadius = radius * progress
            local travelled = math.min(
                state.maxTravel,
                math.max(0, waveRadius - state.startDistance)
            )

            if travelled > state.lastTravel then
                local x = state.startX + (state.dirX * travelled)
                local y = state.startY + (state.dirY * travelled)
                zombie:setX(x)
                zombie:setY(y)
                state.lastTravel = travelled
            end

            if progress >= 1 then
                finishPush(state)
                table.remove(activePushes, i)
            end
        end
    end
end

function mechanics.execute(player)
    local targets = mechanics.collectTargets(player)
    local valid, reason, remaining, cost = mechanics.validateCast(player, targets)
    if not valid then return false, reason, remaining end

    NinjaLineages.Chakra.spendChakra(player, cost)
    local startedAt = NinjaLineages.Utils.Time.nowMs()
    for _, target in ipairs(targets) do
        beginPush(player, target, startedAt)
    end

    NinjaLineages.Cooldowns.set(
        player,
        NinjaLineages.JutsuCatalog.getCooldownKey("shinra_tensei"),
        NinjaLineages.JutsuCatalog.resolveBalance("shinra_tensei").cooldown
    )
    return true
end
