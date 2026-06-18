require "combat/NinjaLineages_Damage"

NinjaLineages = NinjaLineages or {}
NinjaLineages.CombatRuntime = NinjaLineages.CombatRuntime or {}

NinjaLineages.CombatRuntime.projectiles = NinjaLineages.CombatRuntime.projectiles or {}
local nextProjectileId = 0
local LOG_PREFIX = "[DEBUG-NL-PROJECTILE] "

local function log(message)
    print(LOG_PREFIX .. message)
end

local function readHealth(target)
    if not target or not target.getHealth then return "unavailable" end
    local ok, health = pcall(function() return target:getHealth() end)
    if not ok then return "error" end
    return tostring(health)
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

function NinjaLineages.CombatRuntime.createProjectile(config)
    local nowGameMinutes = NinjaLineages.Utils.Time.gameMinutes()
    local speed = tonumber(config.speed) or 20
    if speed <= 0 then speed = 20 end

    local dx = (config.targetX or config.originX) - config.originX
    local dy = (config.targetY or config.originY) - config.originY
    local distance = math.sqrt((dx * dx) + (dy * dy))

    local projectile = {
        projectileId = config.projectileId or generateId(),
        casterObject = config.casterObject,
        casterOnlineId = config.casterOnlineId,
        abilityId = config.abilityId,
        targetKind = config.targetKind,
        targetObject = config.targetObject,
        targetOnlineId = config.targetOnlineId,
        impactAtGameMinutes = nowGameMinutes + (distance / speed),
        damagePayload = config.damagePayload or {},
    }

    NinjaLineages.CombatRuntime.projectiles[projectile.projectileId] = projectile
    log(string.format(
        "CREATED id=%s ability=%s targetKind=%s targetId=%s targetObject=%s distance=%.4f speed=%.4f now=%.6f impactAt=%.6f",
        tostring(projectile.projectileId),
        tostring(projectile.abilityId),
        tostring(projectile.targetKind),
        tostring(projectile.targetOnlineId),
        tostring(projectile.targetObject ~= nil),
        distance,
        speed,
        nowGameMinutes,
        projectile.impactAtGameMinutes
    ))
    return projectile
end

function NinjaLineages.CombatRuntime.removeProjectile(projectileId)
    NinjaLineages.CombatRuntime.projectiles[projectileId] = nil
end

function NinjaLineages.CombatRuntime.update()
    if NinjaLineages.isClient() and not NinjaLineages.isServer() then return end

    local nowGameMinutes = NinjaLineages.Utils.Time.gameMinutes()
    local toRemove = {}

    for id, projectile in pairs(NinjaLineages.CombatRuntime.projectiles) do
        if nowGameMinutes >= projectile.impactAtGameMinutes then
            log(string.format(
                "IMPACT_DUE id=%s now=%.6f impactAt=%.6f",
                tostring(id),
                nowGameMinutes,
                projectile.impactAtGameMinutes
            ))

            local caster = projectile.casterObject
            if not caster and projectile.casterOnlineId and getPlayerByOnlineID then
                caster = getPlayerByOnlineID(projectile.casterOnlineId)
            end

            local targetObject, targetSource = resolveTargetObject(projectile)
            if targetObject then
                local healthBefore = readHealth(targetObject)
                NinjaLineages.Damage.applyTargetDamageAndControl(caster, {
                    kind = projectile.targetKind,
                    onlineId = projectile.targetOnlineId,
                    object = targetObject,
                    x = targetObject:getX(),
                    y = targetObject:getY(),
                    z = targetObject:getZ(),
                    distance = 0,
                }, projectile.damagePayload)
                log(string.format(
                    "DAMAGE_APPLIED id=%s source=%s casterFound=%s targetDead=%s damage=%s healthBefore=%s healthAfter=%s",
                    tostring(id),
                    tostring(targetSource),
                    tostring(caster ~= nil),
                    tostring(targetObject:isDead()),
                    tostring(projectile.damagePayload.damage),
                    healthBefore,
                    readHealth(targetObject)
                ))
            else
                log(string.format(
                    "TARGET_MISSING id=%s reason=%s targetKind=%s targetId=%s hadStoredObject=%s",
                    tostring(id),
                    tostring(targetSource),
                    tostring(projectile.targetKind),
                    tostring(projectile.targetOnlineId),
                    tostring(projectile.targetObject ~= nil)
                ))
            end

            table.insert(toRemove, id)
        end
    end

    for _, id in ipairs(toRemove) do
        NinjaLineages.CombatRuntime.removeProjectile(id)
        log("REMOVED id=" .. tostring(id))
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
