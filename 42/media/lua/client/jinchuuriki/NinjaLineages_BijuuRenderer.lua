require "NinjaLineages_Utils"
require "NinjaLineages_AbilityAuthority"
require "disciplines/jinchuuriki/NinjaLineages_BijuuBoss"

NinjaLineages = NinjaLineages or {}
NinjaLineages.BijuuRenderer = NinjaLineages.BijuuRenderer or {}

local Renderer = NinjaLineages.BijuuRenderer
local Authority = NinjaLineages.AbilityAuthority
local Boss = NinjaLineages.BijuuBoss

local activeShells = {}
local activeTelegraphs = {}
local swingCounter = 0

local function nowGameMinutes()
    return NinjaLineages.Utils.Time.gameMinutes()
end

local function copyShellPayload(payload)
    if not payload or not payload.runtimeId or not payload.bijuuId then return nil end
    return {
        bijuuId = payload.bijuuId,
        runtimeId = payload.runtimeId,
        proxyOnlineId = tonumber(payload.proxyOnlineId),
        lastKnownX = tonumber(payload.x) or 0,
        lastKnownY = tonumber(payload.y) or 0,
        lastKnownZ = tonumber(payload.z) or 0,
        facingX = tonumber(payload.facingX) or 0,
        facingY = tonumber(payload.facingY) or 1,
        config = Boss.getShellConfig(payload.bijuuId),
    }
end

function Renderer.addShell(payload)
    local shell = copyShellPayload(payload)
    if shell then activeShells[shell.runtimeId] = shell end
end

function Renderer.removeShell(payload)
    if payload and payload.runtimeId then activeShells[payload.runtimeId] = nil end
end

function Renderer.addTelegraph(payload)
    if not payload or not payload.volleyId or type(payload.trajectories) ~= "table" then return end
    activeTelegraphs[payload.volleyId] = {
        volleyId = payload.volleyId,
        runtimeId = payload.runtimeId,
        bijuuId = payload.bijuuId,
        trajectories = payload.trajectories,
        endsAtGameMinutes = tonumber(payload.endsAtGameMinutes) or (nowGameMinutes() + 0.05),
        color = Boss.getThemeColor(payload.bijuuId),
    }
end

function Renderer.removeTelegraph(payload)
    if payload and payload.volleyId then activeTelegraphs[payload.volleyId] = nil end
end

function Renderer.replaceShells(payload)
    activeShells = {}
    activeTelegraphs = {}
    local shells = payload and payload.shells or payload
    if type(shells) ~= "table" then return end
    for _, shell in ipairs(shells) do Renderer.addShell(shell) end
end

local function matchesShell(proxy, shell)
    if not proxy or not proxy.getModData or (proxy.isDead and proxy:isDead()) then return false end
    if shell.proxyOnlineId and shell.proxyOnlineId >= 0 and proxy.getOnlineID then
        local ok, onlineId = pcall(function() return proxy:getOnlineID() end)
        if ok and onlineId == shell.proxyOnlineId then return true end
    end
    return Boss.isBossProxy(proxy)
        and Boss.getBijuuId(proxy) == shell.bijuuId
        and Boss.getRuntimeId(proxy) == shell.runtimeId
end

local function findTaggedProxyNear(shell)
    local cell = getCell and getCell()
    if not cell then return nil end

    local baseX = math.floor(shell.lastKnownX)
    local baseY = math.floor(shell.lastKnownY)
    local baseZ = math.floor(shell.lastKnownZ)
    for offsetX = -2, 2 do
        for offsetY = -2, 2 do
            local square = cell:getGridSquare(baseX + offsetX, baseY + offsetY, baseZ)
            local moving = square and square.getMovingObjects and square:getMovingObjects()
            if moving then
                for index = 0, moving:size() - 1 do
                    local candidate = moving:get(index)
                    if candidate and instanceof(candidate, "IsoZombie") and matchesShell(candidate, shell) then
                        return candidate
                    end
                end
            end
        end
    end
    return nil
end

local function resolveProxy(shell)
    if matchesShell(shell.proxy, shell) then return shell.proxy end
    shell.proxy = nil

    if shell.proxyOnlineId and shell.proxyOnlineId >= 0 and NinjaLineages.Utils.Zombies.getByOnlineID then
        local byId = NinjaLineages.Utils.Zombies.getByOnlineID(shell.proxyOnlineId)
        if matchesShell(byId, shell) then shell.proxy = byId end
    end
    if not shell.proxy then shell.proxy = findTaggedProxyNear(shell) end
    return shell.proxy
end

local function hideProxy(proxy)
    if not proxy then return end
    local hidden = false
    if proxy.setAlphaAndTarget then
        hidden = pcall(function() proxy:setAlphaAndTarget(0.0) end)
    end
    if not hidden then
        if proxy.setAlpha then pcall(function() proxy:setAlpha(0.0) end) end
        if proxy.setTargetAlpha then pcall(function() proxy:setTargetAlpha(0.0) end) end
    end
end

local function updateShellAnchor(shell)
    local proxy = resolveProxy(shell)
    if proxy then
        hideProxy(proxy)
        shell.lastKnownX = proxy:getX()
        shell.lastKnownY = proxy:getY()
        shell.lastKnownZ = proxy:getZ()
        if proxy.getForwardDirection then
            local forward = proxy:getForwardDirection()
            if forward then
                shell.facingX = forward:getX()
                shell.facingY = forward:getY()
            end
        end
    end
    return proxy
end

local function normalizedFacing(shell)
    local fx = tonumber(shell.facingX) or 0
    local fy = tonumber(shell.facingY) or 1
    local length = math.sqrt(fx * fx + fy * fy)
    if length < 0.001 then return 0, 1, -1, 0 end
    fx, fy = fx / length, fy / length
    return fx, fy, -fy, fx
end

local function line(x1, y1, z1, x2, y2, z2, thickness, r, g, b, alpha)
    local vfx = NinjaLineages.VFX
    if vfx and vfx.renderLine then
        vfx.renderLine(x1, y1, z1, x2, y2, z2, thickness, r, g, b, alpha)
    end
end

local function ring(x, y, z, radius, segments, thickness, r, g, b, alpha)
    local vfx = NinjaLineages.VFX
    if vfx and vfx.renderRing then
        vfx.renderRing(x, y, z, radius, segments, thickness, r, g, b, alpha, 0)
    end
end

local function ellipse(cx, cy, cz, forwardX, forwardY, sideX, sideY, halfLength, halfWidth, segments, thickness, r, g, b, alpha)
    local previousX, previousY = nil, nil
    for step = 0, segments do
        local angle = (step / segments) * math.pi * 2
        local along = math.cos(angle) * halfLength
        local across = math.sin(angle) * halfWidth
        local x = cx + forwardX * along + sideX * across
        local y = cy + forwardY * along + sideY * across
        if previousX then line(previousX, previousY, cz, x, y, cz, thickness, r, g, b, alpha) end
        previousX, previousY = x, y
    end
end

local function limb(baseX, baseY, baseZ, kneeX, kneeY, kneeZ, pawX, pawY, groundZ, r, g, b, alpha)
    line(baseX, baseY, baseZ, kneeX, kneeY, kneeZ, 4.2, r, g, b, alpha)
    line(kneeX, kneeY, kneeZ, pawX, pawY, groundZ + 0.08, 4.0, r, g, b, alpha)
    ring(pawX, pawY, groundZ + 0.06, 0.25, 12, 3.0, r, g, b, alpha)
end

local function drawBeast(shell, time)
    updateShellAnchor(shell)

    local x, y, z = shell.lastKnownX, shell.lastKnownY, shell.lastKnownZ
    local cfg = shell.config
    local color = cfg.color or { r = 1.0, g = 0.5, b = 0.1 }
    local r, g, b = color.r, color.g, color.b
    local fx, fy, sx, sy = normalizedFacing(shell)
    local pulse = 0.88 + math.sin(time * 72.0) * 0.08
    local alpha = 0.88 * pulse

    local bodyLength = math.max(1.7, (cfg.visualRadius or 2.4) * 0.92)
    local bodyWidth = bodyLength * 0.55
    local bodyHeight = math.max(1.05, (cfg.visualHeight or 2.2) * 0.62)
    local chestX = x + fx * bodyLength * 0.34
    local chestY = y + fy * bodyLength * 0.34
    local rumpX = x - fx * bodyLength * 0.34
    local rumpY = y - fy * bodyLength * 0.34

    for layer = 0, 4 do
        local t = layer / 4
        local widthScale = 1.0 - math.abs(t - 0.45) * 0.45
        ellipse(x, y, z + 0.38 + t * bodyHeight, fx, fy, sx, sy,
            bodyLength, bodyWidth * widthScale, 28, 3.3, r, g, b, alpha * (0.82 + t * 0.12))
    end

    ellipse(chestX, chestY, z + bodyHeight * 0.72, fx, fy, sx, sy,
        bodyLength * 0.48, bodyWidth * 0.84, 22, 3.6, r, g, b, alpha)
    ellipse(rumpX, rumpY, z + bodyHeight * 0.66, fx, fy, sx, sy,
        bodyLength * 0.48, bodyWidth * 0.90, 22, 3.6, r, g, b, alpha)
    line(rumpX - fx * 0.35, rumpY - fy * 0.35, z + bodyHeight * 0.95,
        chestX + fx * 0.45, chestY + fy * 0.45, z + bodyHeight * 1.12,
        4.2, r, g, b, alpha)
    for ribIndex = -2, 2 do
        local along = ribIndex * bodyLength * 0.27
        local ribX = x + fx * along
        local ribY = y + fy * along
        line(ribX + sx * bodyWidth * 0.82, ribY + sy * bodyWidth * 0.82, z + bodyHeight * 0.55,
            ribX, ribY, z + bodyHeight * 1.03, 2.6, r, g, b, alpha * 0.72)
        line(ribX, ribY, z + bodyHeight * 1.03,
            ribX - sx * bodyWidth * 0.82, ribY - sy * bodyWidth * 0.82, z + bodyHeight * 0.55,
            2.6, r, g, b, alpha * 0.72)
    end

    local frontAlong = bodyLength * 0.55
    local rearAlong = -bodyLength * 0.48
    for _, legSpec in ipairs({
        { frontAlong,  0.72 }, { frontAlong, -0.72 },
        { rearAlong,   0.72 }, { rearAlong,  -0.72 },
    }) do
        local along, sideSign = legSpec[1], legSpec[2]
        local baseX = x + fx * along + sx * bodyWidth * sideSign
        local baseY = y + fy * along + sy * bodyWidth * sideSign
        local kneeX = baseX + fx * 0.18 + sx * sideSign * 0.16
        local kneeY = baseY + fy * 0.18 + sy * sideSign * 0.16
        local pawX = kneeX + fx * 0.28
        local pawY = kneeY + fy * 0.28
        limb(baseX, baseY, z + bodyHeight * 0.58,
            kneeX, kneeY, z + bodyHeight * 0.24,
            pawX, pawY, z, r, g, b, alpha)
    end

    local neckX = x + fx * bodyLength * 0.78
    local neckY = y + fy * bodyLength * 0.78
    local headX = x + fx * bodyLength * 1.12
    local headY = y + fy * bodyLength * 1.12
    local headZ = z + bodyHeight * 1.05
    line(chestX, chestY, z + bodyHeight * 0.92, neckX, neckY, headZ, 4.5, r, g, b, alpha)
    ellipse(headX, headY, headZ, fx, fy, sx, sy, bodyLength * 0.38, bodyWidth * 0.58,
        22, 3.8, r, g, b, alpha)
    local muzzleX = headX + fx * bodyLength * 0.40
    local muzzleY = headY + fy * bodyLength * 0.40
    ellipse(muzzleX, muzzleY, headZ - 0.08, fx, fy, sx, sy, bodyLength * 0.28,
        bodyWidth * 0.34, 16, 3.3, r, g, b, alpha)
    line(headX + sx * bodyWidth * 0.42, headY + sy * bodyWidth * 0.42, headZ + 0.05,
        headX + sx * bodyWidth * 0.72 - fx * 0.15, headY + sy * bodyWidth * 0.72 - fy * 0.15,
        headZ + 0.48, 3.5, r, g, b, alpha)
    line(headX - sx * bodyWidth * 0.42, headY - sy * bodyWidth * 0.42, headZ + 0.05,
        headX - sx * bodyWidth * 0.72 - fx * 0.15, headY - sy * bodyWidth * 0.72 - fy * 0.15,
        headZ + 0.48, 3.5, r, g, b, alpha)
    local eyeForward = bodyLength * 0.18
    for _, eyeSide in ipairs({ -1, 1 }) do
        ring(headX + fx * eyeForward + sx * bodyWidth * 0.29 * eyeSide,
            headY + fy * eyeForward + sy * bodyWidth * 0.29 * eyeSide,
            headZ + 0.04, 0.08, 10, 2.5, 1.0, 0.95, 0.72, 1.0)
    end

    local tails = math.max(1, math.min(9, tonumber(cfg.tails) or 1))
    local rearAngle = (math.atan2 or math.atan)(-fy, -fx)
    local spread = math.rad(92)
    for tailIndex = 1, tails do
        local fraction = tails == 1 and 0 or ((tailIndex - 1) / (tails - 1) - 0.5)
        local baseAngle = rearAngle + fraction * spread
        local wave = math.sin(time * 68.0 + tailIndex * 0.91)
        local currentX = rumpX + math.cos(baseAngle) * bodyWidth * 0.55
        local currentY = rumpY + math.sin(baseAngle) * bodyWidth * 0.55
        local currentZ = z + bodyHeight * 0.78
        local segments = 6
        for segment = 1, segments do
            local progress = segment / segments
            local angle = baseAngle + wave * (0.12 + progress * 0.25)
                + math.sin(time * 53.0 + tailIndex + segment * 0.7) * 0.07
            local length = bodyLength * (0.24 + progress * 0.035)
            local nextX = currentX + math.cos(angle) * length
            local nextY = currentY + math.sin(angle) * length
            local nextZ = currentZ + 0.10 + math.sin(progress * math.pi) * 0.20
                + wave * progress * 0.05
            line(currentX, currentY, currentZ, nextX, nextY, nextZ,
                5.0 - progress * 2.2, r, g, b, alpha * (1.0 - progress * 0.16))
            currentX, currentY, currentZ = nextX, nextY, nextZ
        end
        ring(currentX, currentY, currentZ, 0.12, 10, 2.2, r, g, b, alpha)
    end

    for wisp = 1, 7 do
        local angle = time * 35.0 + wisp * (math.pi * 2 / 7)
        local distance = bodyWidth * (0.65 + (wisp % 3) * 0.12)
        local wx = x + math.cos(angle) * distance
        local wy = y + math.sin(angle) * distance
        local phase = (time * 18.0 + wisp * 0.13) % 1
        line(wx, wy, z + 0.12 + phase * bodyHeight,
            wx, wy, z + 0.28 + phase * bodyHeight, 2.2, r, g, b,
            alpha * math.sin(phase * math.pi) * 0.65)
    end

    local debugEnabled = (isDebugEnabled and isDebugEnabled())
        or (SandboxVars and SandboxVars.NinjaLineages and SandboxVars.NinjaLineages.DebugMode == true)
    if debugEnabled then
        ring(x, y, z + 0.04, cfg.perimeterHitboxRadius or 1.2, 32, 2.5, 1.0, 0.95, 0.25, 0.85)
    end
end

local function drawTelegraph(telegraph, time)
    local color = telegraph.color or { r = 1.0, g = 0.25, b = 0.1 }
    local alpha = 0.58 + math.sin(time * 95.0) * 0.25
    for _, trajectory in ipairs(telegraph.trajectories) do
        line(trajectory.originX, trajectory.originY, (trajectory.originZ or 0) + 0.10,
            trajectory.destinationX, trajectory.destinationY, (trajectory.destinationZ or 0) + 0.10,
            3.5, color.r, color.g, color.b, alpha)
        ring(trajectory.destinationX, trajectory.destinationY, (trajectory.destinationZ or 0) + 0.05,
            0.60, 18, 2.4, color.r, color.g, color.b, alpha * 0.82)
    end
end

function Renderer.renderAll(time)
    if not getCell or not getCell() then return end
    for _, shell in pairs(activeShells) do drawBeast(shell, time) end
    for volleyId, telegraph in pairs(activeTelegraphs) do
        if time >= telegraph.endsAtGameMinutes then
            activeTelegraphs[volleyId] = nil
        else
            drawTelegraph(telegraph, time)
        end
    end
end

local function nextSwingId(player)
    swingCounter = swingCounter + 1
    local playerId = player.getOnlineID and player:getOnlineID() or -1
    return tostring(playerId) .. ":" .. tostring(NinjaLineages.Utils.Time.realMilliseconds()) .. ":" .. tostring(swingCounter)
end

local function sendCompensatedMelee(player, shell)
    local payload = {
        bijuuId = shell.bijuuId,
        runtimeId = shell.runtimeId,
        swingId = nextSwingId(player),
    }
    if NinjaLineages.isClient and NinjaLineages.isClient() then
        sendClientCommand(player, "NinjaLineages", "bijuuMeleeSwing", payload)
    elseif NinjaLineages.BijuuBossServer and NinjaLineages.BijuuBossServer.handleMeleeSwing then
        NinjaLineages.BijuuBossServer.handleMeleeSwing(player, payload)
    end
end

local function onWeaponSwing(player, weapon)
    if not player or (player.isLocalPlayer and not player:isLocalPlayer())
            or (player.isDead and player:isDead()) then return end
    if weapon and weapon.isRanged and weapon:isRanged() then return end

    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local forward = player:getForwardDirection()
    local fx = forward and forward:getX() or 0
    local fy = forward and forward:getY() or 1
    local fLength = math.sqrt(fx * fx + fy * fy)
    if fLength > 0.001 then fx, fy = fx / fLength, fy / fLength end

    local weaponRange = (weapon and weapon.getMaxRange and weapon:getMaxRange(player)) or 1.5
    local closestShell, closestDistance = nil, math.huge
    for _, shell in pairs(activeShells) do
        updateShellAnchor(shell)
        local dx = shell.lastKnownX - px
        local dy = shell.lastKnownY - py
        local distance = math.sqrt(dx * dx + dy * dy)
        local radius = (shell.config and shell.config.perimeterHitboxRadius) or 1.2
        if math.abs(pz - shell.lastKnownZ) < 1.5
                and distance <= radius + weaponRange + 0.35
                and distance < closestDistance then
            local unitX = dx / math.max(distance, 0.0001)
            local unitY = dy / math.max(distance, 0.0001)
            if unitX * fx + unitY * fy >= 0.42 then
                local obstruction = NinjaLineages.Collision
                    and NinjaLineages.Collision.traceSegment(px, py, pz, shell.lastKnownX, shell.lastKnownY, pz)
                if obstruction == nil then closestShell, closestDistance = shell, distance end
            end
        end
    end

    if closestShell then sendCompensatedMelee(player, closestShell) end
end

local function requestActiveShells(_, player)
    player = player or (getPlayer and getPlayer())
    if not player then return end
    if NinjaLineages.isClient and NinjaLineages.isClient() then
        sendClientCommand(player, "NinjaLineages", "requestBijuuActiveShells", {})
    elseif NinjaLineages.BijuuBossServer and NinjaLineages.BijuuBossServer.getActiveShellPayloads then
        Renderer.replaceShells({ shells = NinjaLineages.BijuuBossServer.getActiveShellPayloads() })
    end
end

Authority.registerEventHandler("bijuu_shell_spawned", Renderer.addShell)
Authority.registerEventHandler("bijuu_shell_removed", Renderer.removeShell)
Authority.registerEventHandler("bijuu_telegraph_started", Renderer.addTelegraph)
Authority.registerEventHandler("bijuu_telegraph_ended", Renderer.removeTelegraph)
Authority.registerEventHandler("bijuu_active_shells", Renderer.replaceShells)

if Events and Events.OnWeaponSwing then
    NinjaLineages.addEventOnce("client.bijuuRenderer.onWeaponSwing", Events.OnWeaponSwing, onWeaponSwing)
end
if Events and Events.OnCreatePlayer then
    NinjaLineages.addEventOnce("client.bijuuRenderer.onCreatePlayer", Events.OnCreatePlayer, requestActiveShells)
end
if Events and Events.OnGameTimeLoaded then
    NinjaLineages.addEventOnce(
        "client.bijuuRenderer.onGameTimeLoaded",
        Events.OnGameTimeLoaded,
        function()
            if NinjaLineages.isSinglePlayer and NinjaLineages.isSinglePlayer() then
                requestActiveShells(nil, getPlayer and getPlayer())
            end
        end
    )
end
