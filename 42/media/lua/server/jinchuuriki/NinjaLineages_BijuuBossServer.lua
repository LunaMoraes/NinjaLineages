require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "NinjaLineages_Balance"
require "disciplines/jinchuuriki/NinjaLineages_BijuuDefinitions"
require "disciplines/jinchuuriki/NinjaLineages_BijuuState"
require "disciplines/jinchuuriki/NinjaLineages_BijuuBoss"
require "disciplines/jinchuuriki/NinjaLineages_BijuuCombat"
require "combat/NinjaLineages_CombatRuntime"
require "jinchuuriki/NinjaLineages_BijuuRegistryServer"

NinjaLineages = NinjaLineages or {}
NinjaLineages.BijuuBossServer = NinjaLineages.BijuuBossServer or {}

local Server = NinjaLineages.BijuuBossServer
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
    local id = "bijuu_" .. tostring(bijuuId) .. "_" .. tostring(runtimeCounter)
    runtimeCounter = runtimeCounter + 1
    return id
end

function Server.hasActiveBosses()
    for _ in pairs(activeBosses) do return true end
    return false
end

function Server.getActiveBossCount()
    local count = 0
    for _ in pairs(activeBosses) do count = count + 1 end
    return count
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
        phase = runtime.combat and runtime.combat.phase or "idle",
        health = runtime.proxy and runtime.proxy.getHealth and runtime.proxy:getHealth() or 0,
        maxHealth = runtime.combat and runtime.combat.maxHealth or 1000,
    }
end

local function spawnZombieProxy(x, y, z)
    local cell = getCell()
    if not cell then return nil end

    local square = cell:getGridSquare(math.floor(x), math.floor(y), math.floor(z))
    if not square then
        square = cell:getOrCreateGridSquare(math.floor(x), math.floor(y), math.floor(z))
    end

    local zombie = nil

    if addZombiesInOutfit then
        local beforeList = cell:getZombieList()
        local beforeSize = beforeList and beforeList:size() or 0
        local ok = pcall(function()
            addZombiesInOutfit(math.floor(x), math.floor(y), math.floor(z), 1, nil, 0)
        end)
        if ok then
            local afterList = cell:getZombieList()
            if afterList and afterList:size() > beforeSize then
                zombie = afterList:get(afterList:size() - 1)
            end
        end
    end

    if not zombie and IsoZombie and IsoZombie.new then
        local ok, res = pcall(function()
            local zObj = IsoZombie.new(cell)
            zObj:setX(x)
            zObj:setY(y)
            zObj:setZ(z)
            if square then
                zObj:setCurrentSquare(square)
            end
            return zObj
        end)
        if ok and res then zombie = res end
    end

    if not zombie and createZombie then
        local ok, res = pcall(function()
            return createZombie(x, y, z, nil, 0, nil)
        end)
        if ok and res then zombie = res end
    end

    if zombie then
        pcall(function() zombie:setX(x) end)
        pcall(function() zombie:setY(y) end)
        pcall(function() zombie:setZ(z) end)
    end

    return zombie
end

function Server.materialize(bijuuId, x, y, z, opts)
    if not Definitions.isValidId(bijuuId) then
        log("rejected materialize: invalid bijuu ID=" .. tostring(bijuuId))
        return nil, "invalid_bijuu_id"
    end

    local regState = Registry.getBijuuState(bijuuId)
    if not BijuuState.isMaterializedBossState(regState) then
        log("rejected materialize: bijuu=" .. tostring(bijuuId) .. " registry state is " .. tostring(regState) .. ", expected WILD_ACTIVE or BOSS_ACTIVE")
        return nil, "invalid_registry_state"
    end

    if activeBosses[bijuuId] then
        log("rejected materialize: bijuu=" .. tostring(bijuuId) .. " already has active runtime=" .. tostring(activeBosses[bijuuId].runtimeId))
        return nil, "runtime_exists"
    end

    local runtimeId = nextRuntimeId(bijuuId)
    local rootProxy = spawnZombieProxy(x, y, z)
    if not rootProxy then
        log("failed materialize: could not spawn root proxy zombie at (" .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(z) .. ")")
        return nil, "spawn_failed"
    end

    local def = Definitions.get(bijuuId)
    local tails = def and def.tails or 1
    local maxHp = BijuuCombat.getMaxHealth(tails)

    -- 1. Exclude root proxy from Zombie Ninja mutation and classify
    local modData = rootProxy:getModData()
    modData[Boss.KEY_BOSS_PROXY] = true
    modData[Boss.KEY_BIJUU_ID] = bijuuId
    modData[Boss.KEY_RUNTIME_ID] = runtimeId
    modData.zombieNinjaRolled = true
    modData.isZombieNinja = false

    -- 2. Probe and apply engine width
    local shellConfig = NinjaLineages.Balance.Jinchuuriki and NinjaLineages.Balance.Jinchuuriki.BossShell
    local targetWidth = shellConfig and shellConfig.PROXY_WIDTH or 2.4
    local defaultWidth = 0.3
    if rootProxy.getWidth then
        local okW, w = pcall(function() return rootProxy:getWidth() end)
        if okW and w then defaultWidth = w end
    end

    local actualWidth = defaultWidth
    if rootProxy.setWidth then
        pcall(function() rootProxy:setWidth(targetWidth) end)
        if rootProxy.getWidth then
            local okW, w = pcall(function() return rootProxy:getWidth() end)
            if okW and w then actualWidth = w end
        end
    end
    log("proxy width default=" .. tostring(defaultWidth) .. " requested=" .. tostring(targetWidth) .. " actual=" .. tostring(actualWidth))

    -- 3. Configure root proxy attributes (Shootable for Ballistics / Firearms, Collidable for Movement)
    pcall(function()
        if rootProxy.setShootable then rootProxy:setShootable(true) end
        if rootProxy.setCollidable then rootProxy:setCollidable(true) end
        if rootProxy.setHealth then rootProxy:setHealth(maxHp) end
    end)

    local onlineId = nil
    if rootProxy.getOnlineID then
        local okId, idVal = pcall(function() return rootProxy:getOnlineID() end)
        if okId and idVal and idVal >= 0 then
            onlineId = idVal
        end
    end

    local nowGameMinutes = NinjaLineages.Utils.Time.gameMinutes()
    local runtime = {
        bijuuId = bijuuId,
        runtimeId = runtimeId,
        proxy = rootProxy,
        proxyOnlineId = onlineId,
        spawnedAtGameMinutes = nowGameMinutes,
        x = x,
        y = y,
        z = z,
        tails = tails,
        debug = opts and opts.debug == true,
        debugOriginalState = opts and opts.debugOriginalState,
        combat = {
            phase = "idle",
            maxHealth = maxHp,
            lastObservedHealth = maxHp,
            lastAttackerOnlineId = nil,
            targetOnlineId = nil,
            nextAttackAtGameMinutes = nowGameMinutes + 0.05,
            nextRepathAtGameMinutes = nowGameMinutes,
            volley = nil,
        }
    }

    activeBosses[bijuuId] = runtime
    log("materialized bijuu=" .. tostring(bijuuId) .. " tails=" .. tostring(tails) .. " hp=" .. tostring(maxHp) .. " runtime=" .. tostring(runtimeId) .. " (1 root proxy)")

    -- 4. Broadcast client shell presentation event
    local eventPayload = {
        bijuuId = bijuuId,
        runtimeId = runtimeId,
        proxyOnlineId = onlineId,
        x = x,
        y = y,
        z = z,
    }

    if NinjaLineages.isServer() then
        sendServerCommand("NinjaLineages", "bijuuShellSpawned", eventPayload)
    elseif NinjaLineages.BijuuRenderer and NinjaLineages.BijuuRenderer.addShell then
        NinjaLineages.BijuuRenderer.addShell(eventPayload)
    end

    return runtime, "ok"
end

function Server.dematerialize(bijuuId, runtimeId, reason)
    local runtime = activeBosses[bijuuId]
    if not runtime then return false, "no_active_runtime" end

    if runtimeId and runtime.runtimeId ~= runtimeId then
        log("rejected dematerialize: mismatched runtimeId=" .. tostring(runtimeId) .. " active=" .. tostring(runtime.runtimeId))
        return false, "mismatched_runtime"
    end

    -- 1. Remove single root proxy safely without calling proxy:remove()
    local rootProxy = runtime.proxy
    if rootProxy then
        pcall(function()
            if rootProxy.removeFromWorld then rootProxy:removeFromWorld() end
            if rootProxy.removeFromSquare then rootProxy:removeFromSquare() end
        end)
    end

    -- 2. Clean up active projectiles owned by this boss runtime
    if NinjaLineages.CombatRuntime and NinjaLineages.CombatRuntime.removeProjectilesByMeta then
        NinjaLineages.CombatRuntime.removeProjectilesByMeta("runtimeId", runtime.runtimeId)
    end

    -- 3. Clean up active telegraph if any
    if runtime.combat and runtime.combat.volley then
        local telPayload = {
            volleyId = runtime.combat.volley.volleyId,
            bijuuId = bijuuId,
            runtimeId = runtime.runtimeId,
        }
        if NinjaLineages.isServer() then
            sendServerCommand("NinjaLineages", "bijuuTelegraphEnded", telPayload)
        elseif NinjaLineages.BijuuRenderer and NinjaLineages.BijuuRenderer.removeTelegraph then
            NinjaLineages.BijuuRenderer.removeTelegraph(telPayload)
        end
    end

    activeBosses[bijuuId] = nil
    log("dematerialized bijuu=" .. tostring(bijuuId) .. " runtime=" .. tostring(runtime.runtimeId) .. " reason=" .. tostring(reason or "none"))

    -- 4. Broadcast removal event to clients
    local removePayload = {
        bijuuId = bijuuId,
        runtimeId = runtime.runtimeId,
    }

    if NinjaLineages.isServer() then
        sendServerCommand("NinjaLineages", "bijuuShellRemoved", removePayload)
    elseif NinjaLineages.BijuuRenderer and NinjaLineages.BijuuRenderer.removeShell then
        NinjaLineages.BijuuRenderer.removeShell(removePayload)
    end

    return true, "ok", runtime.debugOriginalState
end

function Server.resolveBossFromEntity(entity)
    if not entity or not entity.getModData then return nil end
    local modData = entity:getModData()

    if modData[Boss.KEY_BOSS_PROXY] == true then
        local bijuuId = modData[Boss.KEY_BIJUU_ID]
        local runtime = activeBosses[bijuuId]
        if runtime and runtime.runtimeId == modData[Boss.KEY_RUNTIME_ID] then
            return {
                bijuuId = bijuuId,
                runtimeId = runtime.runtimeId,
                rootProxy = runtime.proxy,
                surface = "root",
            }
        end
    end

    return nil
end

local function forEachCandidatePlayer(callback)
    if getOnlinePlayers then
        local players = getOnlinePlayers()
        if players then
            for i = 0, players:size() - 1 do
                local player = players:get(i)
                if player then callback(player) end
            end
            return
        end
    end
    if getNumActivePlayers and getSpecificPlayer then
        for i = 0, getNumActivePlayers() - 1 do
            local player = getSpecificPlayer(i)
            if player then callback(player) end
        end
    end
end

local function selectBossTarget(runtime, rootProxy, combatCfg)
    local rx = rootProxy:getX()
    local ry = rootProxy:getY()
    local rz = rootProxy:getZ()
    local acqRadius = combatCfg and combatCfg.ACQUISITION_RADIUS or 20.0
    local attackRange = combatCfg and combatCfg.ATTACK_RANGE or 14.0

    -- 1. Check last attacker strictly within ATTACK_RANGE (Slice 3 correction)
    if runtime.combat.lastAttackerOnlineId then
        local attacker = nil
        if getPlayerByOnlineID then
            attacker = getPlayerByOnlineID(runtime.combat.lastAttackerOnlineId)
        end
        if not attacker then
            forEachCandidatePlayer(function(p)
                if p and p.getOnlineID and p:getOnlineID() == runtime.combat.lastAttackerOnlineId then
                    attacker = p
                end
            end)
        end

        if attacker and not (attacker.isDead and attacker:isDead()) then
            if not (attacker.isGhostMode and attacker:isGhostMode()) then
                local ax = attacker:getX()
                local ay = attacker:getY()
                local az = attacker:getZ()
                if math.abs(az - rz) < 2.0 then
                    local dist = math.sqrt((ax - rx)^2 + (ay - ry)^2)
                    if dist <= attackRange then
                        return attacker, dist
                    end
                end
            end
        end
        runtime.combat.lastAttackerOnlineId = nil
    end

    -- 2. Fallback to nearest living non-ghost player within acquisition radius
    local nearestPlayer = nil
    local nearestDist = acqRadius + 1.0

    forEachCandidatePlayer(function(p)
        if p and not (p.isDead and p:isDead()) then
            if not (p.isGhostMode and p:isGhostMode()) then
                local pZ = p:getZ()
                if math.abs(pZ - rz) < 2.0 then
                    local px = p:getX()
                    local py = p:getY()
                    local dist = math.sqrt((px - rx)^2 + (py - ry)^2)
                    if dist <= acqRadius and dist < nearestDist then
                        nearestDist = dist
                        nearestPlayer = p
                    end
                end
            end
        end
    end)

    return nearestPlayer, nearestDist
end

function Server.update()
    local now = NinjaLineages.Utils.Time.gameMinutes()
    local combatCfg = NinjaLineages.Balance and NinjaLineages.Balance.Jinchuuriki and NinjaLineages.Balance.Jinchuuriki.BossCombat

    for bijuuId, runtime in pairs(activeBosses) do
        local rootProxy = runtime.proxy
        if rootProxy then
            local isDead = rootProxy.isDead and rootProxy:isDead()
            local curHp = rootProxy.getHealth and rootProxy:getHealth() or 0

            if isDead or curHp <= 0 then
                if runtime.combat and runtime.combat.phase ~= "defeated" then
                    runtime.combat.phase = "defeated"
                    runtime.combat.volley = nil
                    log("boss defeated bijuu=" .. tostring(bijuuId) .. " runtime=" .. tostring(runtime.runtimeId))
                end
            else
                local rx = rootProxy:getX()
                local ry = rootProxy:getY()
                local rz = rootProxy:getZ()
                runtime.x = rx
                runtime.y = ry
                runtime.z = rz

                -- Direct Damage & Aggro Tracking on Root Proxy
                if curHp < runtime.combat.lastObservedHealth then
                    local attacker = rootProxy.getAttackedBy and rootProxy:getAttackedBy()
                    if attacker and (type(attacker) == "table" or type(attacker) == "userdata") and instanceof(attacker, "IsoPlayer") and not (attacker.isDead and attacker:isDead()) then
                        runtime.combat.lastAttackerOnlineId = attacker.getOnlineID and attacker:getOnlineID()
                    end
                    runtime.combat.lastObservedHealth = curHp
                end

                -- Combat State Machine
                if curHp <= 0 then
                    runtime.combat.phase = "defeated"
                    runtime.combat.volley = nil
                else
                    local tails = runtime.tails or 1
                    local targetPlayer, targetDist = selectBossTarget(runtime, rootProxy, combatCfg)
                    runtime.combat.targetOnlineId = targetPlayer and targetPlayer.getOnlineID and targetPlayer:getOnlineID() or nil

                    local attackRange = combatCfg and combatCfg.ATTACK_RANGE or 14.0

                    if runtime.combat.phase == "idle" then
                        if targetPlayer then
                            if targetDist <= attackRange and now >= runtime.combat.nextAttackAtGameMinutes then
                                -- Start Telegraph Phase
                                local tx = targetPlayer:getX()
                                local ty = targetPlayer:getY()
                                local tz = targetPlayer:getZ()

                                local projRange = combatCfg and combatCfg.PROJECTILE_RANGE or 18.0
                                local fanStep = combatCfg and combatCfg.FAN_STEP_RADIANS or math.rad(9.0)
                                local trajectories = BijuuCombat.generateVolleyTrajectories(rx, ry, rz, tx, ty, tz, tails, projRange, fanStep)
                                local telDuration = BijuuCombat.getTelegraphDuration(tails)
                                local volleyId = "volley_" .. tostring(runtime.runtimeId) .. "_" .. tostring(now)

                                runtime.combat.phase = "telegraph"
                                runtime.combat.volley = {
                                    volleyId = volleyId,
                                    trajectories = trajectories,
                                    startedAtGameMinutes = now,
                                    endsAtGameMinutes = now + telDuration,
                                    nextShotIndex = 1,
                                    nextShotAtGameMinutes = now + telDuration,
                                    targetX = tx,
                                    targetY = ty,
                                    targetZ = tz,
                                }

                                local telEvent = {
                                    volleyId = volleyId,
                                    bijuuId = bijuuId,
                                    runtimeId = runtime.runtimeId,
                                    startedAtGameMinutes = now,
                                    endsAtGameMinutes = now + telDuration,
                                    trajectories = trajectories,
                                }

                                if NinjaLineages.isServer() then
                                    sendServerCommand("NinjaLineages", "bijuuTelegraphStarted", telEvent)
                                elseif NinjaLineages.BijuuRenderer and NinjaLineages.BijuuRenderer.addTelegraph then
                                    NinjaLineages.BijuuRenderer.addTelegraph(telEvent)
                                end
                                log("telegraph started bijuu=" .. tostring(bijuuId) .. " shots=" .. tostring(#trajectories) .. " duration=" .. tostring(telDuration))
                            elseif targetDist > attackRange then
                                -- Pursue Player
                                if now >= runtime.combat.nextRepathAtGameMinutes then
                                    local tx = targetPlayer:getX()
                                    local ty = targetPlayer:getY()
                                    local tz = targetPlayer:getZ()
                                    if rootProxy.pathToLocationF then
                                        pcall(function() rootProxy:pathToLocationF(tx, ty, tz) end)
                                    elseif rootProxy.pathToLocation then
                                        pcall(function() rootProxy:pathToLocation(math.floor(tx), math.floor(ty), math.floor(tz)) end)
                                    elseif rootProxy.pathToCharacter then
                                        pcall(function() rootProxy:pathToCharacter(targetPlayer) end)
                                    end
                                    runtime.combat.nextRepathAtGameMinutes = now + (combatCfg and combatCfg.REPATH_INTERVAL_MINUTES or 0.02)
                                end
                            end
                        end
                    elseif runtime.combat.phase == "telegraph" then
                        -- Stand ground during telegraph
                        local volley = runtime.combat.volley
                        if volley and now >= volley.endsAtGameMinutes then
                            runtime.combat.phase = "volley"
                            volley.nextShotAtGameMinutes = now

                            local endEvent = {
                                volleyId = volley.volleyId,
                                bijuuId = bijuuId,
                                runtimeId = runtime.runtimeId,
                            }
                            if NinjaLineages.isServer() then
                                sendServerCommand("NinjaLineages", "bijuuTelegraphEnded", endEvent)
                            elseif NinjaLineages.BijuuRenderer and NinjaLineages.BijuuRenderer.removeTelegraph then
                                NinjaLineages.BijuuRenderer.removeTelegraph(endEvent)
                            end
                            log("telegraph ended, volley starting bijuu=" .. tostring(bijuuId))
                        end
                    elseif runtime.combat.phase == "volley" then
                        -- Stand ground during volley firing
                        local volley = runtime.combat.volley
                        if volley then
                            local shotInterval = BijuuCombat.getShotInterval(tails)
                            local maxLoop = #volley.trajectories - volley.nextShotIndex + 1

                            while volley.nextShotIndex <= #volley.trajectories and now >= volley.nextShotAtGameMinutes and maxLoop > 0 do
                                maxLoop = maxLoop - 1
                                local traj = volley.trajectories[volley.nextShotIndex]
                                local damage = BijuuCombat.getProjectileDamage(tails)
                                local speed = combatCfg and combatCfg.PROJECTILE_SPEED or 28.0
                                local pRange = combatCfg and combatCfg.PROJECTILE_RANGE or 18.0
                                local hitRad = combatCfg and combatCfg.PROJECTILE_HIT_RADIUS or 0.65

                                local proj = NinjaLineages.CombatRuntime.createProjectile({
                                    abilityId = "bijuu_volley",
                                    casterObject = rootProxy,
                                    originX = traj.originX,
                                    originY = traj.originY,
                                    originZ = traj.originZ,
                                    targetX = traj.destinationX,
                                    targetY = traj.destinationY,
                                    speed = speed,
                                    maximumTravelDistance = pRange,
                                    trackingType = "fixed_path",
                                    spatialCollision = true,
                                    playerCollision = true,
                                    hitRadius = hitRad,
                                    isHostileNPC = true,
                                    damagePayload = {
                                        damage = damage,
                                        isHostileNPC = true,
                                        bijuuId = bijuuId,
                                        runtimeId = runtime.runtimeId,
                                    },
                                    meta = {
                                        bijuuId = bijuuId,
                                        runtimeId = runtime.runtimeId,
                                        volleyId = volley.volleyId,
                                    },
                                })

                                -- Broadcast visual projectile to clients
                                local color = Boss.getThemeColor(bijuuId)
                                local vfxPayload = {
                                    projectileId = proj.projectileId,
                                    fromX = traj.originX,
                                    fromY = traj.originY,
                                    fromZ = traj.originZ,
                                    toX = traj.destinationX,
                                    toY = traj.destinationY,
                                    toZ = traj.destinationZ,
                                    speed = speed,
                                    startGameMinutes = now,
                                    color = { R = color.r, G = color.g, B = color.b },
                                    thickness = 3.5,
                                }
                                if NinjaLineages.isServer() then
                                    sendServerCommand("NinjaLineages", "abilityEvent", {
                                        kind = "chakra_needle_line",
                                        projectileId = vfxPayload.projectileId,
                                        fromX = vfxPayload.fromX,
                                        fromY = vfxPayload.fromY,
                                        fromZ = vfxPayload.fromZ,
                                        toX = vfxPayload.toX,
                                        toY = vfxPayload.toY,
                                        toZ = vfxPayload.toZ,
                                        speed = vfxPayload.speed,
                                        startGameMinutes = vfxPayload.startGameMinutes,
                                        color = vfxPayload.color,
                                        thickness = vfxPayload.thickness,
                                    })
                                elseif NinjaLineages.VFX and NinjaLineages.VFX.addProjectile then
                                    NinjaLineages.VFX.addProjectile(vfxPayload)
                                end

                                volley.nextShotIndex = volley.nextShotIndex + 1
                                volley.nextShotAtGameMinutes = volley.nextShotAtGameMinutes + shotInterval
                            end

                            if volley.nextShotIndex > #volley.trajectories then
                                runtime.combat.phase = "idle"
                                runtime.combat.volley = nil
                                runtime.combat.nextAttackAtGameMinutes = now + BijuuCombat.getAttackCooldown(tails)
                                log("volley complete bijuu=" .. tostring(bijuuId) .. " cooldown until=" .. tostring(runtime.combat.nextAttackAtGameMinutes))
                            end
                        end
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- Debug Tooling & Lifecycle Helpers
-- ============================================================================

local function canUseDebugCommands(player)
    if not (SandboxVars
            and SandboxVars.NinjaLineages
            and SandboxVars.NinjaLineages.DebugMode == true) then
        return false
    end

    if NinjaLineages.isSinglePlayer and NinjaLineages.isSinglePlayer() then
        return true
    end

    local ok, accessLevel = pcall(function() return player:getAccessLevel() end)
    return ok and string.lower(tostring(accessLevel or "")) == "admin"
end

function Server.debugSpawnNearPlayer(player, bijuuId)
    if not player then return false, "no_player" end
    if not Definitions.isValidId(bijuuId) then return false, "invalid_bijuu_id" end

    if activeBosses[bijuuId] then
        return false, "already_materialized"
    end

    local forward = player:getForwardDirection()
    local fx = forward and forward:getX() or 0
    local fy = forward and forward:getY() or 1
    local dist = 4.0
    local spawnX = player:getX() + (fx * dist)
    local spawnY = player:getY() + (fy * dist)
    local spawnZ = player:getZ()

    -- 1. Read current canonical state
    local currentState = Registry.getBijuuState(bijuuId) or BijuuState.getInitialState(bijuuId)

    -- 2. Perform authoritative transition to BOSS_ACTIVE
    local okTrans, transReason = Registry.transition(
        bijuuId,
        currentState,
        BijuuState.BOSS_ACTIVE,
        { world = { x = spawnX, y = spawnY, z = spawnZ } },
        "debug_spawn"
    )

    if not okTrans then
        log("debug spawn transition failed for " .. tostring(bijuuId) .. ": " .. tostring(transReason))
        return false, transReason
    end

    -- 3. Materialize the physical boss proxy
    local runtime, matReason = Server.materialize(bijuuId, spawnX, spawnY, spawnZ, {
        debug = true,
        debugOriginalState = currentState,
    })

    if not runtime then
        -- Revert transition on spawn failure
        Registry.transition(bijuuId, BijuuState.BOSS_ACTIVE, currentState, { world = false }, "debug_spawn_revert")
        return false, matReason
    end

    return true, "ok", runtime
end

function Server.debugDespawnAll(player)
    local count = 0
    for bijuuId, runtime in pairs(activeBosses) do
        local originalState = runtime.debugOriginalState or BijuuState.getInitialState(bijuuId)
        local ok, _, orig = Server.dematerialize(bijuuId, runtime.runtimeId, "debug_despawn")
        if ok then
            Registry.transition(bijuuId, BijuuState.BOSS_ACTIVE, originalState, { world = false }, "debug_despawn")
            count = count + 1
        end
    end
    log("debug despawned " .. tostring(count) .. " active bijuu shells")
    return true, "ok", count
end

function Server.debugNudgeActive(player, dx, dy)
    local count = 0
    for bijuuId, runtime in pairs(activeBosses) do
        local proxy = runtime.proxy
        if proxy then
            local newX = proxy:getX() + (dx or 1.0)
            local newY = proxy:getY() + (dy or 0.0)
            local newZ = proxy:getZ()
            NinjaLineages.Utils.Movement.placeEntity(proxy, newX, newY, newZ)
            runtime.x = newX
            runtime.y = newY
            runtime.z = newZ
            count = count + 1
            log("nudged " .. tostring(bijuuId) .. " to (" .. tostring(newX) .. "," .. tostring(newY) .. "," .. tostring(newZ) .. ")")
        end
    end
    return count > 0, "ok", count
end

local function onClientCommand(module, command, player, args)
    if module ~= "NinjaLineages" then return end

    if command == "bijuuMeleeSwing" then
        -- Perimeter Reach Compensation Hit Command
        if not player or (player.isDead and player:isDead()) then return end
        local bijuuId = args and args.bijuuId
        local runtimeId = args and args.runtimeId
        local runtime = activeBosses[bijuuId]
        if not runtime or runtime.runtimeId ~= runtimeId then return end

        local rootProxy = runtime.proxy
        if not rootProxy or (rootProxy.isDead and rootProxy:isDead()) then return end

        -- Server proximity & LOS validation
        local px, py, pz = player:getX(), player:getY(), player:getZ()
        local rx, ry, rz = rootProxy:getX(), rootProxy:getY(), rootProxy:getZ()
        local dist = math.sqrt((px - rx)^2 + (py - ry)^2)
        local weapon = player:getPrimaryHandItem()
        local maxRange = (weapon and weapon.getMaxRange and weapon:getMaxRange(player)) or 1.5
        local allowedReach = 1.2 + maxRange + 1.0

        if dist <= allowedReach and math.abs(pz - rz) < 1.5 then
            -- Verify LOS
            local hit = NinjaLineages.Collision.traceSegment(px, py, pz, rx, ry, rz)
            if hit == nil then
                -- Invoke native engine Hit method on root zombie proxy!
                if weapon and instanceof(weapon, "HandWeapon") then
                    pcall(function() rootProxy:Hit(weapon, player, 1.0, false, 1.0) end)
                else
                    pcall(function() rootProxy:Hit(nil, player, 1.0, false, 1.0) end)
                end
                runtime.combat.lastAttackerOnlineId = player.getOnlineID and player:getOnlineID()
            end
        end
    elseif command == "debugBijuuSpawnShell" then
        if not canUseDebugCommands(player) then return end
        local bijuuId = args and args.bijuuId
        local ok, reason = Server.debugSpawnNearPlayer(player, bijuuId)
        if NinjaLineages.isServer() then
            sendServerCommand(player, "NinjaLineages", "debugResult", {
                ok = ok,
                action = "bijuuSpawnShell",
                bijuuId = bijuuId,
                reason = reason,
            })
        elseif player and player.Say then
            player:Say(ok and ("Spawned Bijū shell: " .. tostring(bijuuId)) or ("Spawn failed: " .. tostring(reason)))
        end
    elseif command == "debugBijuuDespawnShells" then
        if not canUseDebugCommands(player) then return end
        local ok, reason, count = Server.debugDespawnAll(player)
        if NinjaLineages.isServer() then
            sendServerCommand(player, "NinjaLineages", "debugResult", {
                ok = ok,
                action = "bijuuDespawnShells",
                count = count,
                reason = reason,
            })
        elseif player and player.Say then
            player:Say("Despawned all active Bijū shells (" .. tostring(count or 0) .. ").")
        end
    elseif command == "debugBijuuNudgeShell" then
        if not canUseDebugCommands(player) then return end
        local dx = tonumber(args and args.dx) or 1.0
        local dy = tonumber(args and args.dy) or 0.0
        local ok, reason, count = Server.debugNudgeActive(player, dx, dy)
        if NinjaLineages.isServer() then
            sendServerCommand(player, "NinjaLineages", "debugResult", {
                ok = ok,
                action = "bijuuNudgeShell",
                count = count,
                reason = reason,
            })
        elseif player and player.Say then
            player:Say("Nudged active Bijū shells by (" .. tostring(dx) .. "," .. tostring(dy) .. ").")
        end
    elseif command == "requestBijuuActiveShells" then
        local syncPayload = {}
        for bijuuId, runtime in pairs(activeBosses) do
            table.insert(syncPayload, {
                bijuuId = bijuuId,
                runtimeId = runtime.runtimeId,
                proxyOnlineId = runtime.proxyOnlineId,
                x = runtime.x,
                y = runtime.y,
                z = runtime.z,
            })
        end
        if NinjaLineages.isServer() then
            sendServerCommand(player, "NinjaLineages", "bijuuActiveShellsSync", syncPayload)
        end
    end
end

NinjaLineages.addEventOnce(
    "server.bijuuBoss.onClientCommand",
    Events.OnClientCommand,
    onClientCommand
)
