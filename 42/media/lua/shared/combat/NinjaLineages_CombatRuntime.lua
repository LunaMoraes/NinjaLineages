require "combat/NinjaLineages_Collision"
require "combat/NinjaLineages_Damage"

NinjaLineages = NinjaLineages or {}
NinjaLineages.CombatRuntime = NinjaLineages.CombatRuntime or {}

local Runtime = NinjaLineages.CombatRuntime
Runtime.projectiles = Runtime.projectiles or {}
Runtime.katonStreams = Runtime.katonStreams or {}

local nextProjectileId = 0
local nextKatonStreamId = 0
local LOG_PREFIX = "[DEBUG-NL-PROJECTILE] "
local KATON_LOG_PREFIX = "[DEBUG-NL-KATON] "
local resolveCaster

local function log(message)
    if SandboxVars
            and SandboxVars.NinjaLineages
            and SandboxVars.NinjaLineages.DebugMode == true then
        print(LOG_PREFIX .. message)
    end
end

local function katonLog(message)
    if SandboxVars
            and SandboxVars.NinjaLineages
            and SandboxVars.NinjaLineages.DebugMode == true then
        print(KATON_LOG_PREFIX .. message)
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

local function generateKatonId()
    nextKatonStreamId = nextKatonStreamId + 1
    return "nlk_" .. tostring(nextKatonStreamId)
end

local function collectKatonTiles(config)
    local tiles = {}
    local radius = math.max(0.1, tonumber(config.range) or 0.1)
    local minDot = tonumber(config.minDot) or 0.82
    local baseX = math.floor(config.originX)
    local baseY = math.floor(config.originY)
    local z = math.floor(config.originZ or 0)
    local iRadius = math.ceil(radius)

    for dx = -iRadius, iRadius do
        for dy = -iRadius, iRadius do
            local tileX, tileY = baseX + dx, baseY + dy
            local centerX, centerY = tileX + 0.5, tileY + 0.5
            local offsetX = centerX - config.originX
            local offsetY = centerY - config.originY
            local distance = math.sqrt(offsetX * offsetX + offsetY * offsetY)
            if distance > 0.15 and distance <= radius then
                local dot = (offsetX / distance) * config.directionX
                    + (offsetY / distance) * config.directionY
                if dot >= minDot then
                    table.insert(tiles, {
                        x = tileX,
                        y = tileY,
                        z = z,
                        centerX = centerX,
                        centerY = centerY,
                        distance = distance,
                        activationProgress = distance / radius,
                    })
                end
            end
        end
    end

    table.sort(tiles, function(a, b) return a.distance < b.distance end)
    return tiles
end

function Runtime.createKatonStream(config)
    local directionLength = math.sqrt(
        config.directionX * config.directionX + config.directionY * config.directionY
    )
    if directionLength <= 0.0001 then return nil end

    local nowMs = NinjaLineages.Utils.Time.realMilliseconds()
    local stream = {
        streamId = config.streamId or generateKatonId(),
        casterObject = config.casterObject,
        casterOnlineId = config.casterOnlineId,
        originX = config.originX,
        originY = config.originY,
        originZ = math.floor(config.originZ or 0),
        directionX = config.directionX / directionLength,
        directionY = config.directionY / directionLength,
        range = math.max(0.1, tonumber(config.range) or 0.1),
        minDot = tonumber(config.minDot) or 0.82,
        durationMs = math.max(1, tonumber(config.durationMs) or 750),
        startedAtMs = nowMs,
        damageRoll = config.damageRoll,
        controlTier = config.controlTier,
        collisionMask = config.collisionMask or NinjaLineages.Collision.Masks.jutsu_projectile,
        tiles = {},
        nextTileIndex = 1,
        hitTargets = {},
    }
    stream.tiles = collectKatonTiles(stream)
    Runtime.katonStreams[stream.streamId] = stream
    katonLog(string.format(
        "CREATED id=%s origin=(%.2f,%.2f,%d) direction=(%.3f,%.3f) range=%.2f tiles=%d durationMs=%d",
        stream.streamId,
        stream.originX,
        stream.originY,
        stream.originZ,
        stream.directionX,
        stream.directionY,
        stream.range,
        #stream.tiles,
        stream.durationMs
    ))
    return stream
end

local function targetKey(target)
    if not target then return nil end
    if target.getOnlineID then
        local ok, id = pcall(function() return target:getOnlineID() end)
        if ok and id and id >= 0 then
            return objectName(target) .. ":" .. tostring(id)
        end
    end
    return tostring(target)
end

local function applyKatonToSquare(stream, square)
    local movingObjects = square and square:getMovingObjects()
    if not movingObjects then return end
    local caster = resolveCaster(stream)

    for i = 0, movingObjects:size() - 1 do
        local object = movingObjects:get(i)
        local key = targetKey(object)
        if object and key and not stream.hitTargets[key] then
            local damage = stream.damageRoll and stream.damageRoll() or 0
            local payload = {
                damage = damage,
                controlTier = stream.controlTier,
            }
            if instanceof(object, "IsoZombie") and not object:isDead() then
                stream.hitTargets[key] = true
                NinjaLineages.Damage.applyTargetDamageAndControl(caster, {
                    kind = "zombie",
                    object = object,
                }, payload)
            elseif instanceof(object, "IsoPlayer") and object ~= caster and not object:isDead() then
                local damaged = NinjaLineages.Damage.applyTargetDamageAndControl(caster, {
                    kind = "player",
                    object = object,
                }, payload)
                if damaged then stream.hitTargets[key] = true end
            end
        end
    end
end

local function activateKatonTile(stream, tile)
    local collision = NinjaLineages.Collision.traceSegment(
        stream.originX,
        stream.originY,
        stream.originZ,
        tile.centerX,
        tile.centerY,
        tile.z,
        stream.collisionMask
    )
    if collision then
        katonLog(string.format(
            "MASKED id=%s tile=(%d,%d,%d) collision=%s",
            stream.streamId,
            tile.x,
            tile.y,
            tile.z,
            tostring(collision.kind)
        ))
        return
    end

    local cell = getCell()
    local square = cell and cell:getGridSquare(tile.x, tile.y, tile.z)
    if not square then return end
    applyKatonToSquare(stream, square)
    if IsoFireManager and IsoFireManager.StartFire then
        pcall(function() IsoFireManager.StartFire(cell, square, true, 100, 500) end)
    end
end

local function updateKatonStreams(nowMs)
    local completed = {}
    for streamId, stream in pairs(Runtime.katonStreams) do
        local progress = math.min(1, math.max(0, (nowMs - stream.startedAtMs) / stream.durationMs))
        while stream.nextTileIndex <= #stream.tiles
                and stream.tiles[stream.nextTileIndex].activationProgress <= progress do
            activateKatonTile(stream, stream.tiles[stream.nextTileIndex])
            stream.nextTileIndex = stream.nextTileIndex + 1
        end
        if progress >= 1 then table.insert(completed, streamId) end
    end
    for _, streamId in ipairs(completed) do
        Runtime.katonStreams[streamId] = nil
        katonLog("COMPLETED id=" .. tostring(streamId))
    end
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

resolveCaster = function(projectile)
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
    updateKatonStreams(NinjaLineages.Utils.Time.realMilliseconds())
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
