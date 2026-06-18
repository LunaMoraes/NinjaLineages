NinjaLineages = NinjaLineages or {}
NinjaLineages.Collision = NinjaLineages.Collision or {}

local Collision = NinjaLineages.Collision

Collision.Masks = {
    jutsu_projectile = {
        world = true,
    },
}

local function collisionResult(kind, object, square, x, y, z)
    return {
        kind = kind,
        object = object,
        square = square,
        x = x,
        y = y,
        z = z,
    }
end

function Collision.traceSegment(originX, originY, originZ, targetX, targetY, targetZ, mask)
    if not mask or not mask.world then return nil end

    local cell = getCell()
    if not cell then return nil end
    local floorZ = math.floor(originZ)
    local dx, dy = targetX - originX, targetY - originY
    local distance = math.sqrt((dx * dx) + (dy * dy))
    if distance <= 0.0001 then return nil end

    local directionX, directionY = dx / distance, dy / distance
    local previousSquare = cell:getGridSquare(
        math.floor(originX),
        math.floor(originY),
        floorZ
    )
    if not previousSquare then return nil end

    local step = 0.20
    local travelled = step
    while travelled <= distance + step do
        local sample = math.min(travelled, distance)
        local x = originX + directionX * sample
        local y = originY + directionY * sample
        local square = cell:getGridSquare(math.floor(x), math.floor(y), floorZ)
        if not square then
            return collisionResult("unloaded", nil, nil, x, y, floorZ)
        end

        if square ~= previousSquare then
            local object = previousSquare:testCollideSpecialObjects(square)
            if object then
                return collisionResult("object", object, square, x, y, floorZ)
            end
            if previousSquare:isBlockedTo(square) then
                return collisionResult("world", nil, square, x, y, floorZ)
            end
            previousSquare = square
        end
        travelled = travelled + step
    end
    return nil
end
