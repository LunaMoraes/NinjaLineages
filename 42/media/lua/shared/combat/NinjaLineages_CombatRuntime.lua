require "combat/NinjaLineages_Collision"
require "combat/NinjaLineages_Damage"

NinjaLineages = NinjaLineages or {}
NinjaLineages.CombatRuntime = NinjaLineages.CombatRuntime or {}

local Runtime = NinjaLineages.CombatRuntime
Runtime.projectiles = Runtime.projectiles or {}

local nextProjectileId = 0
local LOG_PREFIX = "[DEBUG-NL-PROJECTILE] "

local function log(message)
    if SandboxVars
            and SandboxVars.NinjaLineages
            and SandboxVars.NinjaLineages.DebugMode == true then
        print(LOG_PREFIX .. message)
    end
end

local function readHealth(target)
    if not target or not target.getHealth then return "unavailable" end
    local ok, health = pcall(function() return target:getHealth() end)
    return ok and tostring(health) or "error"
end

local function objectName(object)
    if not object then return "world" end
    if object.getObjectName then
        local ok, name = pcall(function() return object:getObjectName() end)
        if ok and name then return tostring(name) end
    end
    return tostring(object)
end

local function generateId()
    nextProjectileId = nextProjectileId + 1
    return "nlp_" .. tostring(nextProjectileId)
end

local function resolveTargetObject(projectile)
    local target = projectile.targetObject
    if target and not target:isDead() then
        return target, "stored_object"
    end

    local onlineId = tonumber(projectile.targetOnlineId)
    if not onlineId or onlineId < 0 then
        return nil, target and "stored_target_dead" or "no_valid_online_id"
    end

    if projectile.targetKind == "zombie" then
        target = NinjaLineages.Utils.Zombies.getByOnlineID(onlineId)
        return target, target and "zombie_online_id" or "zombie_online_id_not_found"
    end
    if projectile.targetKind == "player" and getPlayerByOnlineID then
        target = getPlayerByOnlineID(onlineId)
        return target, target and "player_online_id" or "player_online_id_not_found"
    end
    return nil, "unsupported_target_kind"
end

local function resolveCaster(projectile)
    if projectile.casterObject then return projectile.casterObject end
    if projectile.casterOnlineId and getPlayerByOnlineID then
        return getPlayerByOnlineID(projectile.casterOnlineId)
    end
    return nil
end

local function broadcastResolution(projectile, result, x, y, z)
    local event = {
        kind = "projectile_resolved",
        projectileId = projectile.projectileId,
        result = result,
        x = x,
        y = y,
        z = z,
    }
    if NinjaLineages.isServer() then
        sendServerCommand("NinjaLineages", "abilityEvent", event)
    elseif NinjaLineages.AbilityAuthority
            and NinjaLineages.AbilityAuthority.handleEvent then
        NinjaLineages.AbilityAuthority.handleEvent(event)
    end
end

local function finish(projectile, result, x, y, z, toRemove)
    broadcastResolution(projectile, result, x, y, z)
    table.insert(toRemove, projectile.projectileId)
end

function Runtime.createProjectile(config)
    local now = NinjaLineages.Utils.Time.gameMinutes()
    local speed = tonumber(config.speed) or 20
    if speed <= 0 then speed = 20 end

    local dx = (config.targetX or config.originX) - config.originX
    local dy = (config.targetY or config.originY) - config.originY
    local initialDistance = math.sqrt((dx * dx) + (dy * dy))
    local maximumTravelDistance = math.max(
        0.1,
        initialDistance,
        tonumber(config.maximumTravelDistance) or initialDistance
    )

    local projectile = {
        projectileId = config.projectileId or generateId(),
        casterObject = config.casterObject,
        casterOnlineId = config.casterOnlineId,
        abilityId = config.abilityId,
        trackingType = config.trackingType or "fixed_path",
        currentX = config.originX,
        currentY = config.originY,
        currentZ = config.originZ or 0,
        targetKind = config.targetKind,
        targetObject = config.targetObject,
        targetOnlineId = config.targetOnlineId,
        targetX = config.targetX,
        targetY = config.targetY,
        speed = speed,
        damagePayload = config.damagePayload or {},
        collisionMask = config.collisionMask or NinjaLineages.Collision.Masks.jutsu_projectile,
        createdAtGameMinutes = now,
        lastTickGameMinutes = now,
        expiresAtGameMinutes = now + (maximumTravelDistance / speed),
    }

    Runtime.projectiles[projectile.projectileId] = projectile
    log(string.format(
        "CREATED id=%s ability=%s tracking=%s targetKind=%s targetId=%s targetObject=%s pos=(%.3f,%.3f,%.3f) speed=%.3f expiresAt=%.6f",
        tostring(projectile.projectileId),
        tostring(projectile.abilityId),
        tostring(projectile.trackingType),
        tostring(projectile.targetKind),
        tostring(projectile.targetOnlineId),
        tostring(projectile.targetObject ~= nil),
        projectile.currentX,
        projectile.currentY,
        projectile.currentZ,
        projectile.speed,
        projectile.expiresAtGameMinutes
    ))
    return projectile
end

function Runtime.removeProjectile(projectileId)
    Runtime.projectiles[projectileId] = nil
end

local function handleCollision(projectile, collision, caster)
    local blocker = collision.object
    local healthBefore = readHealth(blocker)
    local damaged, structuralDamage = false, 0
    if blocker then
        damaged, structuralDamage = NinjaLineages.Damage.applyBarrierDamage(
            caster,
            blocker,
            projectile.damagePayload
        )
    end
    log(string.format(
        "BLOCKED id=%s collision=%s object=%s pos=(%.3f,%.3f,%.3f) damaged=%s structuralDamage=%.3f healthBefore=%s healthAfter=%s",
        tostring(projectile.projectileId),
        tostring(collision.kind),
        objectName(blocker),
        collision.x,
        collision.y,
        collision.z,
        tostring(damaged),
        structuralDamage,
        healthBefore,
        readHealth(blocker)
    ))
end

function Runtime.update()
    if NinjaLineages.isClient() and not NinjaLineages.isServer() then return end

    local now = NinjaLineages.Utils.Time.gameMinutes()
    local toRemove = {}

    for _, projectile in pairs(Runtime.projectiles) do
        local previousTick = projectile.lastTickGameMinutes
        projectile.lastTickGameMinutes = now
        local resolved = false

        if now >= projectile.expiresAtGameMinutes then
            log("EXPIRED id=" .. tostring(projectile.projectileId))
            finish(
                projectile,
                "expired",
                projectile.currentX,
                projectile.currentY,
                projectile.currentZ,
                toRemove
            )
            resolved = true
        else
            local targetObject, targetSource = resolveTargetObject(projectile)
            if projectile.trackingType == "homing" then
                if not targetObject then
                    log(string.format(
                        "TARGET_LOST id=%s reason=%s",
                        tostring(projectile.projectileId),
                        tostring(targetSource)
                    ))
                    finish(
                        projectile,
                        "target_lost",
                        projectile.currentX,
                        projectile.currentY,
                        projectile.currentZ,
                        toRemove
                    )
                    resolved = true
                else
                    projectile.targetX = targetObject:getX()
                    projectile.targetY = targetObject:getY()
                end
            end

            if not resolved then
                local dx = projectile.targetX - projectile.currentX
                local dy = projectile.targetY - projectile.currentY
                local distance = math.sqrt((dx * dx) + (dy * dy))
                local delta = math.max(0, now - previousTick)
                local moveDistance = projectile.speed * delta
                local nextX, nextY = projectile.targetX, projectile.targetY

                if distance > moveDistance and distance > 0.0001 then
                    nextX = projectile.currentX + (dx / distance) * moveDistance
                    nextY = projectile.currentY + (dy / distance) * moveDistance
                end

                local collision = NinjaLineages.Collision.traceSegment(
                    projectile.currentX,
                    projectile.currentY,
                    projectile.currentZ,
                    nextX,
                    nextY,
                    projectile.currentZ,
                    projectile.collisionMask
                )
                if collision then
                    handleCollision(projectile, collision, resolveCaster(projectile))
                    finish(
                        projectile,
                        "blocked",
                        collision.x,
                        collision.y,
                        collision.z,
                        toRemove
                    )
                elseif distance <= moveDistance or distance <= 0.0001 then
                    projectile.currentX = projectile.targetX
                    projectile.currentY = projectile.targetY

                    if targetObject and not targetObject:isDead() then
                        local healthBefore = readHealth(targetObject)
                        NinjaLineages.Damage.applyTargetDamageAndControl(
                            resolveCaster(projectile),
                            {
                                kind = projectile.targetKind,
                                onlineId = projectile.targetOnlineId,
                                object = targetObject,
                                x = targetObject:getX(),
                                y = targetObject:getY(),
                                z = targetObject:getZ(),
                                distance = 0,
                            },
                            projectile.damagePayload
                        )
                        log(string.format(
                            "TARGET_HIT id=%s source=%s damage=%s healthBefore=%s healthAfter=%s",
                            tostring(projectile.projectileId),
                            tostring(targetSource),
                            tostring(projectile.damagePayload.damage),
                            healthBefore,
                            readHealth(targetObject)
                        ))
                        finish(
                            projectile,
                            "target_hit",
                            projectile.currentX,
                            projectile.currentY,
                            projectile.currentZ,
                            toRemove
                        )
                    else
                        finish(
                            projectile,
                            "target_lost",
                            projectile.currentX,
                            projectile.currentY,
                            projectile.currentZ,
                            toRemove
                        )
                    end
                else
                    projectile.currentX = nextX
                    projectile.currentY = nextY
                end
            end
        end
    end

    for _, id in ipairs(toRemove) do
        Runtime.removeProjectile(id)
        log("REMOVED id=" .. tostring(id))
    end
end

function Runtime.getProjectileState(projectileId)
    return Runtime.projectiles[projectileId]
end

function Runtime.getActiveProjectileCount()
    local count = 0
    for _ in pairs(Runtime.projectiles) do count = count + 1 end
    return count
end
