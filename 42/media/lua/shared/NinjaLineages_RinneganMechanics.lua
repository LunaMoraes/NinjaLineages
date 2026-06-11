require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "NinjaLineages_Chakra"
require "NinjaLineages_Balance"

NinjaLineages = NinjaLineages or {}
NinjaLineages.RinneganMechanics = NinjaLineages.RinneganMechanics or {}

local mechanics = NinjaLineages.RinneganMechanics
local consts = NinjaLineages.Constants
local cooldownKey = "rinnegan.shinra_tensei"

function mechanics.getRadius()
    return NinjaLineages.Balance.getRadius("STANDARD")
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
    local baseCost = NinjaLineages.Balance.getCost("MAJOR")
    local stepCost = NinjaLineages.Balance.getCostStep("SMALL")
    local capCost = NinjaLineages.Balance.getCost("ULTIMATE")
    return math.min(capCost, baseCost + (targetCount * stepCost))
end

function mechanics.validateCast(player, targets)
    if not player or not NinjaLineages.hasRinnegan(player) then
        return false, "lineage"
    end

    local onCooldown, remaining = NinjaLineages.Cooldowns.isOnCooldown(player, cooldownKey)
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
    local guaranteedRadius = consts.Rinnegan.ShinraTensei.GUARANTEED_KNOCKDOWN_RADIUS
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

local function pushZombieToRadius(player, target)
    local zombie = target.zombie
    local distanceToPush = math.max(0, mechanics.getRadius() - target.distance)
    if distanceToPush <= 0 then return end

    local dirX, dirY = getPushDirection(player, target)
    local startX = zombie:getX()
    local startY = zombie:getY()
    local z = math.floor(zombie:getZ())
    local stepSize = consts.Rinnegan.ShinraTensei.PUSH_STEP
    local travelled = 0
    local validX = startX
    local validY = startY
    local currentSquare = zombie:getCurrentSquare()

    while travelled < distanceToPush do
        local nextTravelled = math.min(distanceToPush, travelled + stepSize)
        local nextX = startX + (dirX * nextTravelled)
        local nextY = startY + (dirY * nextTravelled)
        local nextSquare = getCell():getGridSquare(nextX, nextY, z)

        if not canEnterSquare(currentSquare, nextSquare) then
            break
        end

        validX = nextX
        validY = nextY
        currentSquare = nextSquare
        travelled = nextTravelled
    end

    if validX ~= startX or validY ~= startY then
        zombie:setX(validX)
        zombie:setY(validY)
    end
end

local function applyDamage(player, target)
    local radius = mechanics.getRadius()
    local falloff = math.max(
        consts.Rinnegan.ShinraTensei.DAMAGE_MIN_FALLOFF,
        1.0 - ((target.distance / radius) * 0.15)
    )
    local damage = NinjaLineages.Balance.rollDamage("HEAVY") * falloff
    NinjaLineages.Utils.Combat.applyZombieDamage(player, target.zombie, damage)
end

local function applyToZombie(player, target)
    local zombie = target.zombie
    if not zombie or zombie:isDead() then return end

    pushZombieToRadius(player, target)

    local knockdown = ZombRand(1, 101) <= getKnockdownChance(target.distance)
    local force = math.max(2.0, 8.0 - target.distance)
    NinjaLineages.Utils.Combat.staggerZombie(zombie, {
        knockdown = knockdown,
        position = "FRONT",
        force = force,
    })
    applyDamage(player, target)
end

function mechanics.execute(player)
    local targets = mechanics.collectTargets(player)
    local valid, reason, remaining, cost = mechanics.validateCast(player, targets)
    if not valid then return false, reason, remaining end

    NinjaLineages.Chakra.spendChakra(player, cost)
    for _, target in ipairs(targets) do
        applyToZombie(player, target)
    end

    NinjaLineages.Cooldowns.set(
        player,
        cooldownKey,
        NinjaLineages.Balance.getCooldown("STANDARD")
    )
    return true
end
