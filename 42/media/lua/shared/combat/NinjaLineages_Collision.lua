NinjaLineages = NinjaLineages or {}
NinjaLineages.Collision = NinjaLineages.Collision or {}

NinjaLineages.Collision.Masks = {
    jutsu_projectile = {
        walls = true,
        closedDoors = true,
        barricades = true,
        windows = "probe",
        fences = "probe",
    },
}

function NinjaLineages.Collision.traceLine(originX, originY, originZ, targetX, targetY, targetZ, mask)
    if not mask then return nil end

    local floorZ = math.floor(originZ)
    local cell = getCell()
    if not cell then return nil end

    local dx = targetX - originX
    local dy = targetY - originY
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist <= 0.001 then return nil end

    local nx = dx / dist
    local ny = dy / dist

    local step = 0.25
    local prevX, prevY = math.floor(originX), math.floor(originY)
    local prevSquare = cell:getGridSquare(prevX, prevY, floorZ)

    for i = step, dist, step do
        local cx = originX + nx * i
        local cy = originY + ny * i
        local tx = math.floor(cx)
        local ty = math.floor(cy)

        if tx ~= prevX or ty ~= prevY then
            local square = cell:getGridSquare(tx, ty, floorZ)
            if square and prevSquare and square:isBlockedTo(prevSquare) then
                return { x = tx, y = ty, z = floorZ, square = square }
            end
            prevX, prevY = tx, ty
            prevSquare = square
        end
    end

    return nil
end

function NinjaLineages.Collision.findFirstBlocker(originX, originY, originZ, targetX, targetY, targetZ, mask)
    return NinjaLineages.Collision.traceLine(originX, originY, originZ, targetX, targetY, targetZ, mask)
end

function NinjaLineages.Collision.damageBlocker(blocker, payload)
    return false
end
