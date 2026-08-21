require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "NinjaLineages_Balance"
require "disciplines/jinchuuriki/NinjaLineages_BijuuDefinitions"
require "disciplines/jinchuuriki/NinjaLineages_BijuuState"
require "disciplines/jinchuuriki/NinjaLineages_BijuuBoss"
require "disciplines/jinchuuriki/NinjaLineages_BijuuCombat"
require "combat/NinjaLineages_CombatRuntime"
require "jinchuuriki/NinjaLineages_BijuuServerSupport"
require "jinchuuriki/NinjaLineages_BijuuRegistryServer"

NinjaLineages = NinjaLineages or {}
NinjaLineages.BijuuBossServer = NinjaLineages.BijuuBossServer or {}

local Server = NinjaLineages.BijuuBossServer
local Support = NinjaLineages.BijuuServerSupport
local Boss = NinjaLineages.BijuuBoss
local Definitions = NinjaLineages.BijuuDefinitions
local BijuuState = NinjaLineages.BijuuState
local BijuuCombat = NinjaLineages.BijuuCombat
local Registry = NinjaLineages.BijuuRegistryServer

local activeBosses = {}
local runtimeCounter = 1

local function log(message)
    print("[NL-BIJUU-BOSS] " .. tostring(message))
end

local function nextRuntimeId(bijuuId)
    local runtimeId = "bijuu_" .. tostring(bijuuId) .. "_" .. tostring(runtimeCounter)
    runtimeCounter = runtimeCounter + 1
    return runtimeId
end

local function proxyOnlineId(proxy)
    if not proxy or not proxy.getOnlineID then return nil end
    local ok, onlineId = pcall(function() return proxy:getOnlineID() end)
    if ok and onlineId and onlineId >= 0 then return onlineId end
    return nil
end

local function facingPayload(proxy)
    local forward = proxy and proxy.getForwardDirection and proxy:getForwardDirection()
    return forward and forward:getX() or 0, forward and forward:getY() or 1
end

local function shellPayload(runtime)
    local facingX, facingY = facingPayload(runtime.proxy)
    local currentHealth = runtime.maxHealth
    if runtime.proxy and runtime.proxy.getHealth then
        currentHealth = runtime.proxy:getHealth()
    end
    return {
        bijuuId = runtime.bijuuId,
        runtimeId = runtime.runtimeId,
        proxyOnlineId = runtime.proxyOnlineId,
        x = runtime.x,
        y = runtime.y,
        z = runtime.z,
        facingX = facingX,
        facingY = facingY,
        currentHealth = currentHealth,
        maxHealth = runtime.maxHealth,
    }
end

function Server.getActiveShellPayloads()
    local payloads = {}
    for _, runtime in pairs(activeBosses) do table.insert(payloads, shellPayload(runtime)) end
    return payloads
end

function Server.hasActiveBosses()
    return next(activeBosses) ~= nil
end

function Server.getActiveBossSnapshot(bijuuId)
    local runtime = activeBosses[bijuuId]
    if not runtime then return nil end
    return {
        bijuuId = runtime.bijuuId,
        runtimeId = runtime.runtimeId,
        proxyOnlineId = runtime.proxyOnlineId,
        x = runtime.x,
        y = runtime.y,
        z = runtime.z,
        tails = runtime.tails,
        phase = runtime.combat.phase,
        health = runtime.proxy and runtime.proxy.getHealth and runtime.proxy:getHealth() or 0,
        maxHealth = runtime.maxHealth,
    }
end

function Server.getActiveBossSnapshots()
    local snapshots = {}
    for _, bijuuId in ipairs(Definitions.Order) do
        local snapshot = Server.getActiveBossSnapshot(bijuuId)
        if snapshot then table.insert(snapshots, snapshot) end
    end
    return snapshots
end

function Server.findNearestActiveBoss(player, maximumDistance)
    if not player then return nil end
    local range = math.max(0, tonumber(maximumDistance) or 0)
    local nearest, nearestDistance = nil, range + 1
    for _, snapshot in ipairs(Server.getActiveBossSnapshots()) do
        if math.abs(player:getZ() - snapshot.z) < 2 then
            local dx, dy = player:getX() - snapshot.x, player:getY() - snapshot.y
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance <= range and distance < nearestDistance then
                nearest, nearestDistance = snapshot, distance
            end
        end
    end
    return nearest, nearestDistance
end

local function spawnZombieProxy(x, y, z)
    local cell = getCell and getCell()
    if not cell then return nil end

    local square = cell:getGridSquare(math.floor(x), math.floor(y), math.floor(z))
    if not square and cell.getOrCreateGridSquare then
        square = cell:getOrCreateGridSquare(math.floor(x), math.floor(y), math.floor(z))
    end

    local zombie = nil
    if addZombiesInOutfit then
        local before = cell:getZombieList()
        local beforeSize = before and before:size() or 0
        local ok = pcall(function()
            addZombiesInOutfit(math.floor(x), math.floor(y), math.floor(z), 1, nil, 0)
        end)
        local after = ok and cell:getZombieList() or nil
        if after and after:size() > beforeSize then zombie = after:get(after:size() - 1) end
    end

    if not zombie and IsoZombie and IsoZombie.new then
        local ok, created = pcall(function()
            local value = IsoZombie.new(cell)
            value:setX(x)
            value:setY(y)
            value:setZ(z)
            if square then value:setCurrentSquare(square) end
            return value
        end)
        if ok then zombie = created end
    end

    if not zombie and createZombie then
        local ok, created = pcall(function() return createZombie(x, y, z, nil, 0, nil) end)
        if ok then zombie = created end
    end

    if zombie then
        pcall(function()
            zombie:setX(x)
            zombie:setY(y)
            zombie:setZ(z)
        end)
    end
    return zombie
end

local function configureProxy(proxy, bijuuId, runtimeId, maxHealth)
    local modData = proxy:getModData()
    modData[Boss.KEY_BOSS_PROXY] = true
    modData[Boss.KEY_BIJUU_ID] = bijuuId
    modData[Boss.KEY_RUNTIME_ID] = runtimeId
    modData.zombieNinjaRolled = true
    modData.isZombieNinja = false
    if proxy.transmitModData then pcall(function() proxy:transmitModData() end) end

    local shellConfig = NinjaLineages.Balance.Jinchuuriki
        and NinjaLineages.Balance.Jinchuuriki.BossShell or {}
    local requestedWidth = shellConfig.PROXY_WIDTH or 2.4
    local originalWidth = 0.3
    if proxy.getWidth then
        local ok, width = pcall(function() return proxy:getWidth() end)
        if ok and width then originalWidth = width end
    end

    pcall(function()
        if proxy.setWidth then proxy:setWidth(requestedWidth) end
        if proxy.setShootable then proxy:setShootable(true) end
        if proxy.setCollidable then proxy:setCollidable(true) end
        if proxy.setHealth then proxy:setHealth(maxHealth) end
        if proxy.setTarget then proxy:setTarget(nil) end
        if proxy.setUseless then proxy:setUseless(true) end
        if proxy.setCanWalk then proxy:setCanWalk(true) end
    end)

    local actualWidth = originalWidth
    if proxy.getWidth then
        local ok, width = pcall(function() return proxy:getWidth() end)
        if ok and width then actualWidth = width end
    end
    log("proxy width default=" .. tostring(originalWidth)
        .. " requested=" .. tostring(requestedWidth)
        .. " actual=" .. tostring(actualWidth))
end

function Server.materialize(bijuuId, x, y, z, options)
    if not Support.isAuthoritative() then return nil, "client_unauthorized" end
    if not Definitions.isValidId(bijuuId) then return nil, "invalid_bijuu_id" end

    local registryState = Registry.getBijuuState(bijuuId)
    if not BijuuState.isMaterializedBossState(registryState) then
        log("materialize rejected bijuu=" .. tostring(bijuuId)
            .. " state=" .. tostring(registryState))
        return nil, "invalid_registry_state"
    end
    if activeBosses[bijuuId] then return nil, "runtime_exists" end

    local proxy = spawnZombieProxy(x, y, z)
    if not proxy then return nil, "spawn_failed" end

    local definition = Definitions.get(bijuuId)
    local tails = definition.tails
    local maximumHealth = BijuuCombat.getMaxHealth(tails)
    local runtimeId = nextRuntimeId(bijuuId)
    configureProxy(proxy, bijuuId, runtimeId, maximumHealth)

    local runtime = {
        bijuuId = bijuuId,
        runtimeId = runtimeId,
        definition = definition,
        tails = tails,
        maxHealth = maximumHealth,
        proxy = proxy,
        proxyOnlineId = proxyOnlineId(proxy),
        x = x,
        y = y,
        z = z,
        lastX = x,
        lastY = y,
        lastZ = z,
        debug = options and options.debug == true,
        debugOriginalState = options and options.debugOriginalState or nil,
        defeatHandled = false,
        lastBroadcastHealth = maximumHealth,
        meleeByPlayer = {},
        suppressions = {},
        combat = {
            phase = "idle",
            lastObservedHealth = maximumHealth,
            lastAttackerOnlineId = nil,
            targetOnlineId = nil,
            nextAttackAtGameMinutes = 0,
            nextRepathAtGameMinutes = 0,
            cooldownEndsAtGameMinutes = 0,
            volley = nil,
        },
    }

    activeBosses[bijuuId] = runtime
    Support.emit("bijuu_shell_spawned", shellPayload(runtime))
    log("materialized bijuu=" .. tostring(bijuuId) .. " tails=" .. tostring(tails)
        .. " hp=" .. tostring(maximumHealth) .. " runtime=" .. tostring(runtimeId))
    return runtime, "ok"
end

local function stopTelegraph(runtime)
    local volley = runtime.combat and runtime.combat.volley
    if not volley then return end
    Support.emit("bijuu_telegraph_ended", {
        volleyId = volley.volleyId,
        bijuuId = runtime.bijuuId,
        runtimeId = runtime.runtimeId,
    })
end

function Server.dematerialize(bijuuId, runtimeId, reason)
    if not Support.isAuthoritative() then return false, "client_unauthorized" end
    local runtime = activeBosses[bijuuId]
    if not runtime then return false, "no_active_runtime" end
    if runtimeId and runtime.runtimeId ~= runtimeId then return false, "mismatched_runtime" end

    stopTelegraph(runtime)
    if NinjaLineages.CombatRuntime and NinjaLineages.CombatRuntime.removeProjectilesByMeta then
        NinjaLineages.CombatRuntime.removeProjectilesByMeta("runtimeId", runtime.runtimeId)
    end
    if runtime.proxy then
        pcall(function()
            if runtime.proxy.removeFromWorld then runtime.proxy:removeFromWorld() end
            if runtime.proxy.removeFromSquare then runtime.proxy:removeFromSquare() end
        end)
    end

    activeBosses[bijuuId] = nil
    Support.emit("bijuu_shell_removed", {
        bijuuId = bijuuId,
        runtimeId = runtime.runtimeId,
    })
    log("dematerialized bijuu=" .. tostring(bijuuId)
        .. " runtime=" .. tostring(runtime.runtimeId)
        .. " reason=" .. tostring(reason or "none"))
    return true, "ok", runtime.debugOriginalState
end

local function playerOnlineId(player)
    if not player or not player.getOnlineID then return nil end
    local onlineId = player:getOnlineID()
    return onlineId and onlineId >= 0 and onlineId or nil
end

local function suppressionPlayerKey(player)
    local onlineId = playerOnlineId(player)
    if onlineId then return "online:" .. tostring(onlineId) end
    if player and player.getPlayerNum then
        return "local:" .. tostring(player:getPlayerNum())
    end
    return nil
end

local function pruneSuppressions(runtime, now)
    local movement, attacks = false, false
    for key, suppression in pairs(runtime.suppressions or {}) do
        if suppression.expiresAtGameMinutes <= now then
            runtime.suppressions[key] = nil
        else
            movement = movement or suppression.movement == true
            attacks = attacks or suppression.attacks == true
        end
    end
    return movement, attacks
end

function Server.addOrRefreshSuppression(bijuuId, runtimeId, sourceKey, player,
        options)
    local runtime = activeBosses[bijuuId]
    if not runtime or runtime.runtimeId ~= runtimeId then
        return false, "target_runtime_changed"
    end
    local playerKey = suppressionPlayerKey(player)
    local expiresAt = options and tonumber(options.expiresAtGameMinutes) or 0
    if not playerKey or type(sourceKey) ~= "string" or sourceKey == ""
            or expiresAt <= NinjaLineages.Utils.Time.gameMinutes() then
        return false, "invalid_suppression"
    end
    runtime.suppressions[playerKey .. "|" .. sourceKey] = {
        movement = options.movement == true,
        attacks = options.attacks == true,
        expiresAtGameMinutes = expiresAt,
    }
    return true, "ok"
end

function Server.removeSuppression(bijuuId, runtimeId, sourceKey, player)
    local runtime = activeBosses[bijuuId]
    local playerKey = suppressionPlayerKey(player)
    if not runtime or runtime.runtimeId ~= runtimeId or not playerKey then return false end
    runtime.suppressions[playerKey .. "|" .. tostring(sourceKey)] = nil
    return true
end

function Server.isMovementSuppressed(bijuuId, runtimeId, now)
    local runtime = activeBosses[bijuuId]
    if not runtime or runtime.runtimeId ~= runtimeId then return false end
    local movement = pruneSuppressions(runtime,
        tonumber(now) or NinjaLineages.Utils.Time.gameMinutes())
    return movement
end

function Server.isAttackSuppressed(bijuuId, runtimeId, now)
    local runtime = activeBosses[bijuuId]
    if not runtime or runtime.runtimeId ~= runtimeId then return false end
    local _, attacks = pruneSuppressions(runtime,
        tonumber(now) or NinjaLineages.Utils.Time.gameMinutes())
    return attacks
end

function Server.getSuppressionSnapshot(bijuuId, runtimeId)
    local runtime = activeBosses[bijuuId]
    if not runtime or runtime.runtimeId ~= runtimeId then return nil end
    local movement, attacks = pruneSuppressions(runtime,
        NinjaLineages.Utils.Time.gameMinutes())
    local count = 0
    for _ in pairs(runtime.suppressions) do count = count + 1 end
    return { movement = movement, attacks = attacks, contributions = count }
end

function Server.applyDamage(bijuuId, runtimeId, attacker, damage, source)
    if not Support.isAuthoritative() then return false, "client_unauthorized" end
    local runtime = activeBosses[bijuuId]
    if not runtime or runtime.runtimeId ~= runtimeId or runtime.defeatHandled then
        return false, "target_runtime_changed"
    end
    local amount = math.max(0, tonumber(damage) or 0)
    if amount <= 0 then return false, "invalid_damage" end
    local proxy = runtime.proxy
    if not proxy or (proxy.isDead and proxy:isDead()) then return false, "target_dead" end
    local before = tonumber(proxy:getHealth()) or 0
    pcall(function() proxy:setAttackedBy(attacker) end)
    proxy:setHealth(math.max(0, before - amount))
    runtime.combat.lastAttackerOnlineId = playerOnlineId(attacker)
    return true, "ok", math.max(0, before - amount)
end

local function findPlayerByOnlineId(onlineId)
    if onlineId == nil then return nil end
    if getPlayerByOnlineID then
        local player = getPlayerByOnlineID(onlineId)
        if player then return player end
    end
    local found = nil
    NinjaLineages.Utils.Players.forEach(function(player)
        if not found and playerOnlineId(player) == onlineId then found = player end
    end)
    return found
end

local function validTarget(player, x, y, z, maximumDistance)
    if not player or (player.isDead and player:isDead())
            or (player.isGhostMode and player:isGhostMode()) then return false, math.huge end
    if math.abs(player:getZ() - z) >= 2.0 then return false, math.huge end
    local distance = math.sqrt((player:getX() - x) ^ 2 + (player:getY() - y) ^ 2)
    return distance <= maximumDistance, distance
end

local function selectTarget(runtime, config)
    local x, y, z = runtime.x, runtime.y, runtime.z
    local attackRange = config.ATTACK_RANGE or 14.0
    local acquisitionRadius = config.ACQUISITION_RADIUS or 20.0

    local attacker = findPlayerByOnlineId(runtime.combat.lastAttackerOnlineId)
    local attackerValid, attackerDistance = validTarget(attacker, x, y, z, attackRange)
    if attackerValid then return attacker, attackerDistance end
    runtime.combat.lastAttackerOnlineId = nil

    local nearest, nearestDistance = nil, acquisitionRadius + 1
    NinjaLineages.Utils.Players.forEach(function(player)
        local valid, distance = validTarget(player, x, y, z, acquisitionRadius)
        if valid and distance < nearestDistance then
            nearest, nearestDistance = player, distance
        end
    end)
    return nearest, nearestDistance
end

local function suppressVanillaCombat(proxy)
    pcall(function()
        if proxy.setTarget then proxy:setTarget(nil) end
        if proxy.setAttackTargetSquare then proxy:setAttackTargetSquare(nil) end
    end)
end

local function stopProxyPath(proxy)
    pcall(function()
        if proxy.setPath2 then proxy:setPath2(nil) end
        if proxy.setTarget then proxy:setTarget(nil) end
    end)
end

local function pursue(runtime, target, now, config)
    if now < runtime.combat.nextRepathAtGameMinutes then return end
    local proxy = runtime.proxy
    local tx, ty, tz = target:getX(), target:getY(), target:getZ()
    if proxy.pathToLocationF then
        pcall(function() proxy:pathToLocationF(tx, ty, tz) end)
    elseif proxy.pathToLocation then
        pcall(function() proxy:pathToLocation(math.floor(tx), math.floor(ty), math.floor(tz)) end)
    elseif proxy.pathToCharacter then
        pcall(function() proxy:pathToCharacter(target) end)
    end
    runtime.combat.nextRepathAtGameMinutes = now + (config.REPATH_INTERVAL_MINUTES or 0.02)
end

local function startTelegraph(runtime, target, now, config)
    stopProxyPath(runtime.proxy)
    local trajectories = BijuuCombat.generateVolleyTrajectories(
        runtime.x, runtime.y, runtime.z,
        target:getX(), target:getY(), target:getZ(),
        runtime.tails,
        config.PROJECTILE_RANGE or 18.0,
        config.FAN_STEP_RADIANS or math.rad(9.0)
    )
    local duration = BijuuCombat.getTelegraphDuration(runtime.tails)
    local volleyId = "volley_" .. tostring(runtime.runtimeId) .. "_" .. tostring(now)
    runtime.combat.phase = "telegraph"
    runtime.combat.volley = {
        volleyId = volleyId,
        trajectories = trajectories,
        endsAtGameMinutes = now + duration,
        nextShotIndex = 1,
        nextShotAtGameMinutes = now + duration,
    }
    Support.emit("bijuu_telegraph_started", {
        volleyId = volleyId,
        bijuuId = runtime.bijuuId,
        runtimeId = runtime.runtimeId,
        startedAtGameMinutes = now,
        endsAtGameMinutes = now + duration,
        projectileHitRadius = config.PROJECTILE_HIT_RADIUS or 0.65,
        trajectories = trajectories,
    })
    log("telegraph started bijuu=" .. tostring(runtime.bijuuId)
        .. " shots=" .. tostring(#trajectories)
        .. " duration=" .. tostring(duration))
end

local function fireProjectile(runtime, trajectory, volleyId, now, config)
    local projectile = NinjaLineages.CombatRuntime.createProjectile({
        abilityId = "bijuu_volley",
        casterObject = runtime.proxy,
        originX = trajectory.originX,
        originY = trajectory.originY,
        originZ = trajectory.originZ,
        targetX = trajectory.destinationX,
        targetY = trajectory.destinationY,
        speed = config.PROJECTILE_SPEED or 28.0,
        maximumTravelDistance = config.PROJECTILE_RANGE or 18.0,
        trackingType = "fixed_path",
        spatialCollision = true,
        playerCollision = true,
        hitRadius = config.PROJECTILE_HIT_RADIUS or 0.65,
        isHostileNPC = true,
        suppressDebugLog = true,
        damagePayload = {
            damage = BijuuCombat.getProjectileDamage(runtime.tails),
            woundType = "burn",
            isHostileNPC = true,
            bijuuId = runtime.bijuuId,
            runtimeId = runtime.runtimeId,
        },
        meta = {
            bijuuId = runtime.bijuuId,
            runtimeId = runtime.runtimeId,
            volleyId = volleyId,
            hitGroupId = volleyId,
            hitTargetOncePerGroup = true,
        },
    })
    local color = Boss.getThemeColor(runtime.bijuuId)
    Support.emit("bijuu_projectile", {
        projectileId = projectile.projectileId,
        abilityId = "bijuu_volley",
        isBijuu = true,
        runtimeId = runtime.runtimeId,
        fromX = trajectory.originX,
        fromY = trajectory.originY,
        fromZ = trajectory.originZ,
        toX = trajectory.destinationX,
        toY = trajectory.destinationY,
        toZ = trajectory.destinationZ,
        speed = config.PROJECTILE_SPEED or 28.0,
        startGameMinutes = now,
        color = { R = color.r, G = color.g, B = color.b },
        thickness = 3.5,
        radius = 0.35,
    })
end

local function advanceCombat(runtime, target, targetDistance, now, config)
    local combat = runtime.combat
    local attackRange = config.ATTACK_RANGE or 14.0

    local movementSuppressed, attacksSuppressed = pruneSuppressions(runtime, now)
    if attacksSuppressed then
        if combat.phase == "telegraph" or combat.phase == "volley" then
            stopTelegraph(runtime)
            if NinjaLineages.CombatRuntime
                    and NinjaLineages.CombatRuntime.removeProjectilesByMeta then
                NinjaLineages.CombatRuntime.removeProjectilesByMeta(
                    "runtimeId", runtime.runtimeId)
            end
        end
        combat.volley = nil
        combat.phase = "idle"
        stopProxyPath(runtime.proxy)
        return
    end

    if combat.phase == "cooldown" then
        stopProxyPath(runtime.proxy)
        if now >= combat.cooldownEndsAtGameMinutes then combat.phase = "idle" end
        return
    end

    if combat.phase == "telegraph" then
        stopProxyPath(runtime.proxy)
        local volley = combat.volley
        if volley and now >= volley.endsAtGameMinutes then
            combat.phase = "volley"
            volley.nextShotAtGameMinutes = volley.endsAtGameMinutes
            Support.emit("bijuu_telegraph_ended", {
                volleyId = volley.volleyId,
                bijuuId = runtime.bijuuId,
                runtimeId = runtime.runtimeId,
            })
            log("telegraph ended bijuu=" .. tostring(runtime.bijuuId))
        end
        return
    end

    if combat.phase == "volley" then
        stopProxyPath(runtime.proxy)
        local volley = combat.volley
        if not volley then
            combat.phase = "cooldown"
            combat.cooldownEndsAtGameMinutes = now + BijuuCombat.getAttackCooldown(runtime.tails)
            return
        end
        local interval = BijuuCombat.getShotInterval(runtime.tails)
        while volley.nextShotIndex <= #volley.trajectories
                and now >= volley.nextShotAtGameMinutes do
            fireProjectile(runtime, volley.trajectories[volley.nextShotIndex], volley.volleyId,
                volley.nextShotAtGameMinutes, config)
            volley.nextShotIndex = volley.nextShotIndex + 1
            volley.nextShotAtGameMinutes = volley.nextShotAtGameMinutes + interval
        end
        if volley.nextShotIndex > #volley.trajectories then
            combat.volley = nil
            combat.phase = "cooldown"
            combat.cooldownEndsAtGameMinutes = now + BijuuCombat.getAttackCooldown(runtime.tails)
            log("volley complete bijuu=" .. tostring(runtime.bijuuId))
        end
        return
    end

    if not target then
        combat.phase = "idle"
        stopProxyPath(runtime.proxy)
    elseif targetDistance > attackRange and movementSuppressed then
        combat.phase = "idle"
        stopProxyPath(runtime.proxy)
    elseif targetDistance > attackRange then
        combat.phase = "pursuit"
        pursue(runtime, target, now, config)
    elseif now >= combat.nextAttackAtGameMinutes then
        startTelegraph(runtime, target, now, config)
    else
        combat.phase = "idle"
        stopProxyPath(runtime.proxy)
    end
end

local function handleDefeat(runtime)
    if runtime.defeatHandled then return end
    runtime.defeatHandled = true
    runtime.combat.phase = "defeated"
    stopTelegraph(runtime)
    runtime.combat.volley = nil
    log("boss defeated bijuu=" .. tostring(runtime.bijuuId)
        .. " runtime=" .. tostring(runtime.runtimeId))
    if NinjaLineages.BijuuLifecycleServer and NinjaLineages.BijuuLifecycleServer.handleBossDefeated then
        NinjaLineages.BijuuLifecycleServer.handleBossDefeated(
            runtime.bijuuId,
            runtime.runtimeId,
            { x = runtime.x, y = runtime.y, z = runtime.z }
        )
    end
end

function Server.update()
    local now = NinjaLineages.Utils.Time.gameMinutes()
    local config = NinjaLineages.Balance.Jinchuuriki
        and NinjaLineages.Balance.Jinchuuriki.BossCombat or {}

    for _, runtime in pairs(activeBosses) do
        local proxy = runtime.proxy
        if proxy then
            local currentHealth = proxy.getHealth and proxy:getHealth() or 0
            if currentHealth ~= runtime.lastBroadcastHealth then
                runtime.lastBroadcastHealth = currentHealth
                Support.emit("bijuu_shell_health", {
                    bijuuId = runtime.bijuuId,
                    runtimeId = runtime.runtimeId,
                    currentHealth = currentHealth,
                    maxHealth = runtime.maxHealth,
                })
            end
            if (proxy.isDead and proxy:isDead()) or currentHealth <= 0 then
                handleDefeat(runtime)
            else
                runtime.x, runtime.y, runtime.z = proxy:getX(), proxy:getY(), proxy:getZ()
                if not runtime.proxyOnlineId then
                    runtime.proxyOnlineId = proxyOnlineId(proxy)
                    if runtime.proxyOnlineId and proxy.transmitModData then
                        pcall(function() proxy:transmitModData() end)
                    end
                end
                suppressVanillaCombat(proxy)

                if currentHealth < runtime.combat.lastObservedHealth then
                    local attacker = proxy.getAttackedBy and proxy:getAttackedBy()
                    if attacker and instanceof(attacker, "IsoPlayer")
                            and not (attacker.isDead and attacker:isDead()) then
                        runtime.combat.lastAttackerOnlineId = playerOnlineId(attacker)
                    end
                end
                runtime.combat.lastObservedHealth = currentHealth

                local target, targetDistance = selectTarget(runtime, config)
                runtime.combat.targetOnlineId = playerOnlineId(target)
                advanceCombat(runtime, target, targetDistance, now, config)
            end
        end
    end
end

local function meleePlayerKey(player)
    local onlineId = playerOnlineId(player)
    if onlineId ~= nil then return "online:" .. tostring(onlineId) end
    local playerNumber = player.getPlayerNum and player:getPlayerNum() or 0
    return "local:" .. tostring(playerNumber)
end

function Server.handleMeleeSwing(player, args)
    if not Support.isAuthoritative() or not player or (player.isDead and player:isDead())
            or (player.isGhostMode and player:isGhostMode()) then return false end

    local weapon = player:getPrimaryHandItem()
    if weapon and weapon.isRanged and weapon:isRanged() then return false end

    local runtime = args and activeBosses[args.bijuuId]
    if not runtime or runtime.runtimeId ~= args.runtimeId then return false end
    local proxy = runtime.proxy
    if not proxy or (proxy.isDead and proxy:isDead()) then return false end

    local now = NinjaLineages.Utils.Time.gameMinutes()
    local release = NinjaLineages.Balance.Jinchuuriki
        and NinjaLineages.Balance.Jinchuuriki.Release or {}
    local minimumInterval = release.MELEE_SWING_MIN_INTERVAL_GAME_MINUTES or 0.005
    local key = meleePlayerKey(player)
    local previous = runtime.meleeByPlayer[key]
    if previous and ((args.swingId and previous.swingId == args.swingId)
            or now - previous.at < minimumInterval) then return false end

    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local rx, ry, rz = proxy:getX(), proxy:getY(), proxy:getZ()
    local dx, dy = rx - px, ry - py
    local distance = math.sqrt(dx * dx + dy * dy)
    local forward = player.getForwardDirection and player:getForwardDirection()
    if distance > 0.001 and forward then
        local facingDot = forward:getX() * (dx / distance) + forward:getY() * (dy / distance)
        if facingDot < 0.42 then return false end
    end

    local weaponRange = (weapon and weapon.getMaxRange and weapon:getMaxRange(player)) or 1.25
    local shell = NinjaLineages.Balance.Jinchuuriki
        and NinjaLineages.Balance.Jinchuuriki.BossShell or {}
    local allowedReach = (shell.PERIMETER_HITBOX_RADIUS or 1.2) + weaponRange + 0.35
    if distance > allowedReach or math.abs(pz - rz) >= 1.5 then return false end
    if NinjaLineages.Collision.traceSegment(px, py, pz, rx, ry, rz) ~= nil then return false end

    runtime.meleeByPlayer[key] = { swingId = args.swingId, at = now }
    local healthBefore = proxy.getHealth and proxy:getHealth() or 0
    if weapon and instanceof(weapon, "HandWeapon") then
        pcall(function() proxy:Hit(weapon, player, 1.0, false, 1.0) end)
    else
        pcall(function() proxy:Hit(nil, player, 1.0, false, 1.0) end)
    end

    local healthAfter = proxy.getHealth and proxy:getHealth() or healthBefore
    local damageMode = "native_hit"
    if healthAfter >= healthBefore and healthBefore > 0 and proxy.setHealth then
        damageMode = "health_fallback"
        local damage = 25.0
        if weapon and weapon.getMinDamage and weapon.getMaxDamage then
            local minimum = weapon:getMinDamage() or 1.0
            local maximum = weapon:getMaxDamage() or 2.0
            damage = minimum + ((maximum - minimum) * 0.5) * 20.0
        end
        proxy:setHealth(math.max(0, healthBefore - damage))
        healthAfter = proxy:getHealth()
    end
    runtime.combat.lastAttackerOnlineId = playerOnlineId(player)
    if Support.canUseDebug(player) then
        log("compensated melee runtime=" .. tostring(runtime.runtimeId)
            .. " swing=" .. tostring(args.swingId)
            .. " mode=" .. damageMode
            .. " hp=" .. tostring(healthBefore) .. "->" .. tostring(healthAfter))
    end
    return true
end

function Server.debugSpawnNearPlayer(player, bijuuId)
    if not Support.canUseDebug(player) then return false, "unauthorized" end
    if not Definitions.isValidId(bijuuId) then return false, "invalid_bijuu_id" end
    if activeBosses[bijuuId] then return false, "already_active" end

    local forward = player:getForwardDirection()
    local shellConfig = NinjaLineages.Balance.Jinchuuriki
        and NinjaLineages.Balance.Jinchuuriki.BossShell or {}
    local spawnDistance = shellConfig.SPAWN_DISTANCE or 4.0
    local spawnX = math.floor(player:getX() + (forward and forward:getX() or 0) * spawnDistance)
    local spawnY = math.floor(player:getY() + (forward and forward:getY() or 1) * spawnDistance)
    local spawnZ = player:getZ()
    local targetState = Definitions.isWildBeast(bijuuId)
        and BijuuState.WILD_ACTIVE or BijuuState.BOSS_ACTIVE
    local currentState = Registry.getBijuuState(bijuuId) or BijuuState.getInitialState(bijuuId)
    local transitioned, reason = Registry.transition(
        bijuuId, currentState, targetState,
        { world = { x = spawnX, y = spawnY, z = spawnZ } },
        "debug_spawn"
    )
    if not transitioned then return false, reason end

    local runtime, materializeReason = Server.materialize(
        bijuuId, spawnX, spawnY, spawnZ,
        { debug = true, debugOriginalState = currentState }
    )
    if not runtime then
        Registry.transition(bijuuId, targetState, currentState, nil, "debug_spawn_rollback")
        return false, materializeReason
    end
    return true, "ok"
end

function Server.debugDespawnAll(player)
    if not Support.canUseDebug(player) then return false, "unauthorized", 0 end
    local entries = {}
    for bijuuId, runtime in pairs(activeBosses) do
        table.insert(entries, {
            bijuuId = bijuuId,
            runtimeId = runtime.runtimeId,
            originalState = runtime.debugOriginalState or BijuuState.getInitialState(bijuuId),
        })
    end
    for _, entry in ipairs(entries) do
        local currentState = Registry.getBijuuState(entry.bijuuId)
        Server.dematerialize(entry.bijuuId, entry.runtimeId, "debug_despawn")
        Registry.transition(entry.bijuuId, currentState, entry.originalState, nil, "debug_despawn_restore")
    end
    return true, "ok", #entries
end

function Server.debugNudgeActive(player, dx, dy)
    if not Support.canUseDebug(player) then return false, "unauthorized", 0 end
    local count = 0
    for _, runtime in pairs(activeBosses) do
        local proxy = runtime.proxy
        if proxy and not (proxy.isDead and proxy:isDead()) then
            local x, y, z = proxy:getX() + (dx or 1), proxy:getY() + (dy or 0), proxy:getZ()
            pcall(function()
                proxy:setX(x)
                proxy:setY(y)
                proxy:setZ(z)
                local square = getCell():getGridSquare(math.floor(x), math.floor(y), math.floor(z))
                if square then proxy:setCurrentSquare(square) end
            end)
            runtime.x, runtime.y, runtime.z = x, y, z
            count = count + 1
        end
    end
    return count > 0, "ok", count
end

Support.registerDebugAction("spawn_shell", function(player, args)
    local ok, reason = Server.debugSpawnNearPlayer(player, args.bijuuId)
    return ok, reason, { bijuuId = args.bijuuId }
end)

Support.registerDebugAction("despawn_shells", function(player)
    local ok, reason, count = Server.debugDespawnAll(player)
    return ok, reason, { count = count }
end)

Support.registerDebugAction("nudge_shells", function(player, args)
    local ok, reason, count = Server.debugNudgeActive(
        player,
        tonumber(args.dx) or 1,
        tonumber(args.dy) or 0
    )
    return ok, reason, { count = count }
end)

local function onClientCommand(module, command, player, args)
    if module ~= "NinjaLineages" then return end
    if command == "bijuuMeleeSwing" then
        Server.handleMeleeSwing(player, args)
    elseif command == "requestBijuuActiveShells" then
        Support.emit("bijuu_active_shells", { shells = Server.getActiveShellPayloads() }, player)
        local sealingServer = NinjaLineages.BijuuSealingServer
        if sealingServer and sealingServer.getActiveRitualPayloads then
            for _, ritual in ipairs(sealingServer.getActiveRitualPayloads()) do
                Support.emit("bijuu_sealing_started", ritual, player)
            end
        end
    end
end

NinjaLineages.addEventOnce(
    "server.bijuuBoss.onClientCommand",
    Events.OnClientCommand,
    onClientCommand
)
