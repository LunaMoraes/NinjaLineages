require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "NinjaLineages_Balance"
require "disciplines/jinchuuriki/NinjaLineages_BijuuDefinitions"
require "disciplines/jinchuuriki/NinjaLineages_BijuuState"
require "disciplines/jinchuuriki/NinjaLineages_BijuuBoss"
require "jinchuuriki/NinjaLineages_BijuuRegistryServer"

NinjaLineages = NinjaLineages or {}
NinjaLineages.BijuuBossServer = NinjaLineages.BijuuBossServer or {}

local Server = NinjaLineages.BijuuBossServer
local Boss = NinjaLineages.BijuuBoss
local Definitions = NinjaLineages.BijuuDefinitions
local BijuuState = NinjaLineages.BijuuState
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

function Server.getActiveBoss(bijuuId)
    return activeBosses[bijuuId]
end

function Server.getAllActiveBosses()
    return activeBosses
end

local function spawnZombieProxy(x, y, z)
    local cell = getCell()
    if not cell then return nil end

    local square = cell:getGridSquare(math.floor(x), math.floor(y), math.floor(z))
    if not square then
        square = cell:getOrCreateGridSquare(math.floor(x), math.floor(y), math.floor(z))
    end

    local zombie = nil

    if createZombie then
        local ok, res = pcall(function()
            return createZombie(x, y, z, nil, 0, nil)
        end)
        if ok and res then zombie = res end
    end

    if not zombie and addZombiesInOutfit then
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

    if activeBosses[bijuuId] then
        log("rejected materialize: bijuu=" .. tostring(bijuuId) .. " already has active runtime=" .. tostring(activeBosses[bijuuId].runtimeId))
        return nil, "runtime_exists"
    end

    local runtimeId = nextRuntimeId(bijuuId)
    local proxy = spawnZombieProxy(x, y, z)
    if not proxy then
        log("failed materialize: could not spawn proxy zombie at (" .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(z) .. ")")
        return nil, "spawn_failed"
    end

    -- 1. Exclude from Zombie Ninja mutation and classify as Bijū proxy
    local modData = proxy:getModData()
    modData[Boss.KEY_BOSS_PROXY] = true
    modData[Boss.KEY_BIJUU_ID] = bijuuId
    modData[Boss.KEY_RUNTIME_ID] = runtimeId
    modData.zombieNinjaRolled = true
    modData.isZombieNinja = false

    -- 2. Probe and apply engine width
    local shellConfig = NinjaLineages.Balance.Jinchuuriki and NinjaLineages.Balance.Jinchuuriki.BossShell
    local targetWidth = shellConfig and shellConfig.PROXY_WIDTH or 2.4
    local defaultWidth = 0.3
    if proxy.getWidth then
        local okW, w = pcall(function() return proxy:getWidth() end)
        if okW and w then defaultWidth = w end
    end

    local actualWidth = defaultWidth
    if proxy.setWidth then
        pcall(function() proxy:setWidth(targetWidth) end)
        if proxy.getWidth then
            local okW, w = pcall(function() return proxy:getWidth() end)
            if okW and w then actualWidth = w end
        end
    end
    log("proxy width default=" .. tostring(defaultWidth) .. " requested=" .. tostring(targetWidth) .. " actual=" .. tostring(actualWidth))

    -- 3. Configure proxy attributes
    pcall(function()
        if proxy.setShootable then proxy:setShootable(true) end
        if proxy.setCollidable then proxy:setCollidable(true) end
        if proxy.setHealth then proxy:setHealth(shellConfig and shellConfig.DEBUG_HEALTH or 1000.0) end
    end)

    local onlineId = nil
    if proxy.getOnlineID then
        local okId, idVal = pcall(function() return proxy:getOnlineID() end)
        if okId and idVal and idVal >= 0 then
            onlineId = idVal
        end
    end

    local nowGameMinutes = NinjaLineages.Utils.Time.gameMinutes()
    local runtime = {
        bijuuId = bijuuId,
        runtimeId = runtimeId,
        proxy = proxy,
        proxyOnlineId = onlineId,
        spawnedAtGameMinutes = nowGameMinutes,
        x = x,
        y = y,
        z = z,
        debug = opts and opts.debug == true,
        debugOriginalState = opts and opts.debugOriginalState,
        secondaryProxies = {},
    }

    activeBosses[bijuuId] = runtime
    log("materialized bijuu=" .. tostring(bijuuId) .. " runtime=" .. tostring(runtimeId) .. " proxyOnlineId=" .. tostring(onlineId))

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

    -- 1. Remove secondary proxies if present
    for _, secProxy in ipairs(runtime.secondaryProxies or {}) do
        pcall(function()
            if secProxy.removeFromWorld then secProxy:removeFromWorld() end
            if secProxy.removeFromSquare then secProxy:removeFromSquare() end
            if secProxy.remove then secProxy:remove() end
        end)
    end

    -- 2. Remove root proxy
    local proxy = runtime.proxy
    if proxy then
        pcall(function()
            if proxy.removeFromWorld then proxy:removeFromWorld() end
            if proxy.removeFromSquare then proxy:removeFromSquare() end
            if proxy.remove then proxy:remove() end
        end)
    end

    activeBosses[bijuuId] = nil
    log("dematerialized bijuu=" .. tostring(bijuuId) .. " runtime=" .. tostring(runtime.runtimeId) .. " reason=" .. tostring(reason or "none"))

    -- 3. Broadcast removal event to clients
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
    elseif modData[Boss.KEY_HIT_PROXY] == true then
        local bijuuId = modData[Boss.KEY_BIJUU_ID]
        local runtime = activeBosses[bijuuId]
        if runtime and runtime.runtimeId == modData[Boss.KEY_RUNTIME_ID] then
            return {
                bijuuId = bijuuId,
                runtimeId = runtime.runtimeId,
                rootProxy = runtime.proxy,
                surface = modData.hitProxySurface or "secondary",
            }
        end
    end

    return nil
end

function Server.update()
    -- Spatial following loop for secondary hit proxies if multi-proxy fallback is active
    for bijuuId, runtime in pairs(activeBosses) do
        local root = runtime.proxy
        if root and not (root.isDead and root:isDead()) then
            local rx = root:getX()
            local ry = root:getY()
            local rz = root:getZ()
            runtime.x = rx
            runtime.y = ry
            runtime.z = rz

            -- If secondary proxies exist, keep them positioned relative to root
            local offsets = {
                { x = 0, y = -1.6, surface = "north" },
                { x = 0, y = 1.6, surface = "south" },
                { x = -1.6, y = 0, surface = "west" },
                { x = 1.6, y = 0, surface = "east" },
            }
            for i, secProxy in ipairs(runtime.secondaryProxies or {}) do
                local off = offsets[i]
                if off and secProxy and not (secProxy.isDead and secProxy:isDead()) then
                    NinjaLineages.Utils.Movement.placeEntity(secProxy, rx + off.x, ry + off.y, rz)
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

    if command == "debugBijuuSpawnShell" then
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
