require "combat/NinjaLineages_Targeting"
require "combat/NinjaLineages_Collision"
require "combat/NinjaLineages_Damage"

NinjaLineages = NinjaLineages or {}
NinjaLineages.CombatRuntime = NinjaLineages.CombatRuntime or {}

NinjaLineages.CombatRuntime.projectiles = NinjaLineages.CombatRuntime.projectiles or {}
local nextProjectileId = 0

function NinjaLineages.CombatRuntime.generateId()
    nextProjectileId = nextProjectileId + 1
    return "nlp_" .. tostring(nextProjectileId)
end

function NinjaLineages.CombatRuntime.createProjectile(config)
    local nowGameMinutes = NinjaLineages.Utils.Time.gameMinutes()
    local speed = tonumber(config.speed) or 12
    if speed <= 0 then speed = 12 end

    local travelTime
    if config.targetX and config.targetY then
        local dx = config.targetX - config.originX
        local dy = config.targetY - config.originY
        local distance = math.sqrt(dx * dx + dy * dy)
        travelTime = (distance / speed) + 0.5
    else
        travelTime = (20 / speed) + 0.5
    end

    local p = {
        projectileId = config.projectileId or NinjaLineages.CombatRuntime.generateId(),
        casterOnlineId = config.casterOnlineId,
        abilityId = config.abilityId,
        trackingType = config.trackingType or "fixed_path",
        originX = config.originX,
        originY = config.originY,
        originZ = config.originZ,
        currentX = config.originX,
        currentY = config.originY,
        currentZ = config.originZ,
        directionX = config.directionX or 0,
        directionY = config.directionY or 0,
        targetKind = config.targetKind,
        targetOnlineId = config.targetOnlineId,
        targetX = config.targetX,
        targetY = config.targetY,
        speed = speed,
        radius = config.radius or 0.5,
        createdAtGameMinutes = nowGameMinutes,
        lastTickGameMinutes = nowGameMinutes,
        expiresAtGameMinutes = nowGameMinutes + travelTime,
        damagePayload = config.damagePayload or {},
        collisionMask = config.collisionMask or NinjaLineages.Collision.Masks.jutsu_projectile,
        resolved = false,
        hitKind = nil,
        hitX = nil,
        hitY = nil,
        hitZ = nil,
    }

    NinjaLineages.CombatRuntime.projectiles[p.projectileId] = p
    return p
end

function NinjaLineages.CombatRuntime.removeProjectile(projectileId)
    NinjaLineages.CombatRuntime.projectiles[projectileId] = nil
end

function NinjaLineages.CombatRuntime.update()
    if NinjaLineages.isClient() and not NinjaLineages.isServer() then return end

    local nowGameMinutes = NinjaLineages.Utils.Time.gameMinutes()
    local toRemove = {}

    for id, p in pairs(NinjaLineages.CombatRuntime.projectiles) do
        local shouldRemove = false

        if p.resolved then
            shouldRemove = true
        elseif nowGameMinutes >= p.expiresAtGameMinutes then
            shouldRemove = true
        else
            local caster = nil
            if p.casterOnlineId and getPlayerByOnlineID then
                caster = getPlayerByOnlineID(p.casterOnlineId)
            end

            if p.trackingType == "homing" and p.targetKind and p.targetOnlineId then
                local targetObj = nil
                if p.targetKind == "zombie" then
                    targetObj = NinjaLineages.Utils.Zombies.getByOnlineID(p.targetOnlineId)
                elseif p.targetKind == "player" then
                    if getPlayerByOnlineID then
                        targetObj = getPlayerByOnlineID(p.targetOnlineId)
                    end
                end

                if targetObj and not targetObj:isDead() then
                    p.targetX = targetObj:getX()
                    p.targetY = targetObj:getY()
                else
                    shouldRemove = true
                end
            end

            if not shouldRemove then
                local destX, destY
                if p.targetX and p.targetY then
                    destX, destY = p.targetX, p.targetY
                else
                    destX = p.currentX + p.directionX * 1000
                    destY = p.currentY + p.directionY * 1000
                end

                local dx = destX - p.currentX
                local dy = destY - p.currentY
                local dist = math.sqrt(dx * dx + dy * dy)

                local delta = nowGameMinutes - p.lastTickGameMinutes
                if delta < 0 then delta = 0 end
                local moveDist = p.speed * delta

                if dist <= 0.001 then
                    p.resolved = true
                    shouldRemove = true
                elseif dist <= moveDist then
                    p.currentX = destX
                    p.currentY = destY
                    p.resolved = true

                    if p.targetKind and p.targetOnlineId then
                        local targetObj = nil
                        if p.targetKind == "zombie" then
                            targetObj = NinjaLineages.Utils.Zombies.getByOnlineID(p.targetOnlineId)
                        elseif p.targetKind == "player" then
                            if getPlayerByOnlineID then
                                targetObj = getPlayerByOnlineID(p.targetOnlineId)
                            end
                        end
                        if targetObj and not targetObj:isDead() then
                            local target = {
                                kind = p.targetKind,
                                onlineId = p.targetOnlineId,
                                object = targetObj,
                                x = targetObj:getX(),
                                y = targetObj:getY(),
                                z = targetObj:getZ(),
                                distance = 0,
                            }
                            NinjaLineages.Damage.applyTargetDamageAndControl(caster, target, p.damagePayload)
                        end
                    end

                    shouldRemove = true
                else
                    local nx = p.currentX + (dx / dist) * moveDist
                    local ny = p.currentY + (dy / dist) * moveDist

                    local blocker = NinjaLineages.Collision.traceLine(
                        p.currentX, p.currentY, p.currentZ,
                        nx, ny, p.currentZ,
                        p.collisionMask
                    )

                    if blocker then
                        p.resolved = true
                        p.hitX = blocker.x
                        p.hitY = blocker.y
                        p.hitZ = blocker.z
                        shouldRemove = true
                    else
                        p.currentX = nx
                        p.currentY = ny
                    end
                end
            end
        end

        p.lastTickGameMinutes = nowGameMinutes

        if shouldRemove then
            table.insert(toRemove, id)
        end
    end

    for _, id in ipairs(toRemove) do
        NinjaLineages.CombatRuntime.removeProjectile(id)
    end
end

function NinjaLineages.CombatRuntime.getProjectileState(projectileId)
    return NinjaLineages.CombatRuntime.projectiles[projectileId]
end

function NinjaLineages.CombatRuntime.getActiveProjectileCount()
    local count = 0
    for _ in pairs(NinjaLineages.CombatRuntime.projectiles) do
        count = count + 1
    end
    return count
end
