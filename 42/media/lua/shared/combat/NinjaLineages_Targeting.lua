require "NinjaLineages_Social"

NinjaLineages = NinjaLineages or {}
NinjaLineages.Targeting = NinjaLineages.Targeting or {}

function NinjaLineages.Targeting.isServerPvPEnabled()
    return false
end

function NinjaLineages.Targeting.isHostilePlayer(caster, targetPlayer)
    if not caster or not targetPlayer or caster == targetPlayer then return false end
    if not NinjaLineages.Targeting.isServerPvPEnabled() then return false end
    if NinjaLineages.Social.areSameTeam(caster, targetPlayer) then return false end
    if NinjaLineages.Social.areSameVillage(caster, targetPlayer) then return false end
    return true
end

function NinjaLineages.Targeting.isFriendly(caster, targetPlayer)
    return not NinjaLineages.Targeting.isHostilePlayer(caster, targetPlayer)
end

function NinjaLineages.Targeting.collectVisibleZombies(caster, targetingConfig)
    local targets = {}
    if not caster or not targetingConfig then return targets end

    local entries = NinjaLineages.Utils.Zombies.collectClosestVisible(
        caster,
        targetingConfig.range,
        targetingConfig.maxTargets
    )

    for _, entry in ipairs(entries) do
        local zombie = entry.zombie
        if zombie and not zombie:isDead() then
            table.insert(targets, {
                kind = "zombie",
                onlineId = zombie.getOnlineID and zombie:getOnlineID() or nil,
                object = zombie,
                x = zombie:getX(),
                y = zombie:getY(),
                z = zombie:getZ(),
                distance = entry.distance,
            })
        end
    end

    return targets
end

function NinjaLineages.Targeting.collectHostilePlayers(caster, targetingConfig)
    local targets = {}
    if not caster or not targetingConfig then return targets end
    if not NinjaLineages.Targeting.isServerPvPEnabled() then return targets end

    local players = getOnlinePlayers and getOnlinePlayers()
    if not players then return targets end

    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player and player ~= caster and NinjaLineages.Targeting.isHostilePlayer(caster, player) then
            local dist = player:DistTo(caster)
            if dist <= targetingConfig.range then
                table.insert(targets, {
                    kind = "player",
                    onlineId = player:getOnlineID(),
                    object = player,
                    x = player:getX(),
                    y = player:getY(),
                    z = player:getZ(),
                    distance = dist,
                })
            end
        end
    end

    table.sort(targets, function(a, b) return a.distance < b.distance end)

    local maxTargets = targetingConfig.maxTargets
    if maxTargets and maxTargets > 0 then
        while #targets > maxTargets do table.remove(targets) end
    end

    return targets
end

function NinjaLineages.Targeting.collectValidTargets(caster, targetingConfig)
    local targets = {}
    if not caster or not targetingConfig then return targets end

    local zombies = NinjaLineages.Targeting.collectVisibleZombies(caster, targetingConfig)
    for _, t in ipairs(zombies) do table.insert(targets, t) end

    local players = NinjaLineages.Targeting.collectHostilePlayers(caster, targetingConfig)
    for _, t in ipairs(players) do table.insert(targets, t) end

    local maxTargets = targetingConfig.maxTargets
    if maxTargets and maxTargets > 0 then
        while #targets > maxTargets do table.remove(targets) end
    end

    return targets
end

function NinjaLineages.Targeting.resolveRequestedTargets(caster, targetingConfig, args)
    local targets = {}
    if not caster or not targetingConfig then return targets end

    local maxTargets = targetingConfig.maxTargets or 1
    local range = targetingConfig.range or 10

    local hasRequestedZombies = args and args.targetZombies and #args.targetZombies > 0
    local hasRequestedIds = args and args.targetIds and #args.targetIds > 0

    for _, zombie in ipairs((args and args.targetZombies) or {}) do
        if #targets >= maxTargets then break end
        if zombie and not zombie:isDead() and zombie:DistTo(caster) <= range then
            table.insert(targets, {
                kind = "zombie",
                onlineId = zombie.getOnlineID and zombie:getOnlineID() or nil,
                object = zombie,
                x = zombie:getX(),
                y = zombie:getY(),
                z = zombie:getZ(),
                distance = zombie:DistTo(caster),
            })
        end
    end

    for _, zombieId in ipairs((args and args.targetIds) or {}) do
        if #targets >= maxTargets then break end
        local zombie = NinjaLineages.Utils.Zombies.getByOnlineID(zombieId)
        if zombie and not zombie:isDead() and zombie:DistTo(caster) <= range then
            table.insert(targets, {
                kind = "zombie",
                onlineId = zombieId,
                object = zombie,
                x = zombie:getX(),
                y = zombie:getY(),
                z = zombie:getZ(),
                distance = zombie:DistTo(caster),
            })
        end
    end

    if #targets == 0 and not hasRequestedZombies and not hasRequestedIds
            and not (NinjaLineages.isClient and NinjaLineages.isClient()) then
        return NinjaLineages.Targeting.collectValidTargets(caster, targetingConfig)
    end

    return targets
end
