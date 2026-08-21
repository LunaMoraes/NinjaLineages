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
local activeRituals = {}
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
        currentHealth = tonumber(payload.currentHealth),
        maxHealth = tonumber(payload.maxHealth),
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

function Renderer.updateShellHealth(payload)
    if not payload or not payload.runtimeId then return end
    local shell = activeShells[payload.runtimeId]
    if not shell or (payload.bijuuId and payload.bijuuId ~= shell.bijuuId) then return end

    local currentHealth = tonumber(payload.currentHealth)
    local maxHealth = tonumber(payload.maxHealth)
    if currentHealth then shell.currentHealth = currentHealth end
    if maxHealth and maxHealth > 0 then shell.maxHealth = maxHealth end
end

function Renderer.addTelegraph(payload)
    if not payload or not payload.volleyId or type(payload.trajectories) ~= "table" then return end
    activeTelegraphs[payload.volleyId] = {
        volleyId = payload.volleyId,
        runtimeId = payload.runtimeId,
        bijuuId = payload.bijuuId,
        trajectories = payload.trajectories,
        startedAtGameMinutes = tonumber(payload.startedAtGameMinutes) or nowGameMinutes(),
        endsAtGameMinutes = tonumber(payload.endsAtGameMinutes) or (nowGameMinutes() + 0.05),
        projectileHitRadius = math.max(0.05, tonumber(payload.projectileHitRadius) or 0.65),
        color = Boss.getThemeColor(payload.bijuuId),
    }
end

function Renderer.removeTelegraph(payload)
    if payload and payload.volleyId then activeTelegraphs[payload.volleyId] = nil end
end

function Renderer.addSealingRitual(payload)
    if not payload or not payload.ritualId or not payload.bijuuRuntimeId then return end
    activeRituals[payload.ritualId] = {
        ritualId = payload.ritualId,
        bijuuId = payload.bijuuId,
        bijuuRuntimeId = payload.bijuuRuntimeId,
        vesselItemId = tonumber(payload.vesselItemId),
        vesselPower = tonumber(payload.vesselPower) or 0,
        vesselX = tonumber(payload.vesselX) or 0,
        vesselY = tonumber(payload.vesselY) or 0,
        vesselZ = tonumber(payload.vesselZ) or 0,
        ritualRadius = math.max(0, tonumber(payload.ritualRadius) or 0),
        progress = math.max(0, math.min(100, tonumber(payload.progress) or 0)),
        restraintStrength = math.max(0, tonumber(payload.restraintStrength) or 0),
        progressRate = math.max(0, tonumber(payload.progressRate) or 0),
        startedAtGameMinutes = tonumber(payload.startedAtGameMinutes) or nowGameMinutes(),
        color = Boss.getThemeColor(payload.bijuuId),
    }
end

function Renderer.updateSealingRitual(payload)
    if not payload or not payload.ritualId then return end
    local ritual = activeRituals[payload.ritualId]
    if not ritual or ritual.bijuuId ~= payload.bijuuId
            or ritual.bijuuRuntimeId ~= payload.bijuuRuntimeId then return end
    ritual.progress = math.max(ritual.progress,
        math.max(0, math.min(100, tonumber(payload.progress) or ritual.progress)))
    ritual.restraintStrength = math.max(0,
        tonumber(payload.restraintStrength) or ritual.restraintStrength)
    ritual.vesselPower = math.max(0,
        tonumber(payload.vesselPower) or ritual.vesselPower)
    ritual.progressRate = math.max(0,
        tonumber(payload.progressRate) or ritual.progressRate)
end

function Renderer.removeSealingRitual(payload)
    if payload and payload.ritualId then activeRituals[payload.ritualId] = nil end
end

local function ritualForRuntime(runtimeId)
    for _, ritual in pairs(activeRituals) do
        if ritual.bijuuRuntimeId == runtimeId then return ritual end
    end
    return nil
end

local function shellView(shell, distance)
    local ritual = ritualForRuntime(shell.runtimeId)
    return {
        bijuuId = shell.bijuuId,
        runtimeId = shell.runtimeId,
        x = shell.lastKnownX,
        y = shell.lastKnownY,
        z = shell.lastKnownZ,
        distance = distance,
        currentHealth = shell.currentHealth,
        maxHealth = shell.maxHealth,
        nameKey = shell.config and shell.config.nameKey,
        color = shell.config and shell.config.color,
        sealing = ritual and {
            ritualId = ritual.ritualId,
            progress = ritual.progress,
            vesselPower = ritual.vesselPower,
            restraintStrength = ritual.restraintStrength,
            progressRate = ritual.progressRate,
        } or nil,
    }
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

function Renderer.getNearestActiveShell(player, maximumDistance)
    if not player or (player.isDead and player:isDead()) then return nil end
    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local limit = tonumber(maximumDistance) or math.huge
    local nearest, nearestDistance = nil, limit

    for _, shell in pairs(activeShells) do
        local dx = shell.lastKnownX - px
        local dy = shell.lastKnownY - py
        local distance = math.sqrt(dx * dx + dy * dy)
        if math.abs((shell.lastKnownZ or 0) - pz) < 1.5 and distance <= nearestDistance then
            nearest = shell
            nearestDistance = distance
        end
    end

    if not nearest then return nil end
    return shellView(nearest, nearestDistance)
end


function Renderer.getNearestActiveSealingShell(player, maximumDistance)
    if not player or (player.isDead and player:isDead()) then return nil end
    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local nearest, nearestDistance = nil, tonumber(maximumDistance) or math.huge
    for _, shell in pairs(activeShells) do
        local ritual = ritualForRuntime(shell.runtimeId)
        if ritual then
            local dx = shell.lastKnownX - px
            local dy = shell.lastKnownY - py
            local distance = math.sqrt(dx * dx + dy * dy)
            if math.abs((shell.lastKnownZ or 0) - pz) < 1.5 and distance <= nearestDistance then
                nearest = shell
                nearestDistance = distance
            end
        end
    end
    if not nearest then return nil end
    return shellView(nearest, nearestDistance)
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

local function nearestLocalPlayerDistance(x, y, z)
    local nearest = math.huge
    local count = getNumActivePlayers and getNumActivePlayers() or 1
    for playerNum = 0, count - 1 do
        local player = getSpecificPlayer and getSpecificPlayer(playerNum)
        if player and not (player.isDead and player:isDead())
                and math.abs(player:getZ() - z) < 1.5 then
            local dx = player:getX() - x
            local dy = player:getY() - y
            nearest = math.min(nearest, math.sqrt(dx * dx + dy * dy))
        end
    end
    return nearest
end

local function sweepNode(x, y, z, width, height)
    return { x = x, y = y, z = z, width = width, height = height }
end

-- Dense adjacent cross-sections form one closed chakra skin. This deliberately
-- uses the same overlapping-line technique as Shinra Tensei: no centre stroke,
-- wire cage, mesh, texture, or model sits underneath the visible surface.
local function renderDenseSweep(nodes, quality, color, alpha)
    if not nodes or #nodes < 2 then return end
    local spacing = quality == "near" and 0.075 or 0.14
    local sides = quality == "near" and 16 or 11
    local thickness = quality == "near" and 5.5 or 6.4

    for nodeIndex = 1, #nodes - 1 do
        local first, second = nodes[nodeIndex], nodes[nodeIndex + 1]
        local dx, dy, dz = second.x - first.x, second.y - first.y, second.z - first.z
        local horizontalLength = math.sqrt(dx * dx + dy * dy)
        local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
        if distance > 0.001 then
            local sideX, sideY = 1, 0
            if horizontalLength > 0.001 then sideX, sideY = -dy / horizontalLength, dx / horizontalLength end
            local samples = math.max(1, math.ceil(distance / spacing))
            for sample = 0, samples do
                local amount = sample / samples
                local cx = first.x + dx * amount
                local cy = first.y + dy * amount
                local cz = first.z + dz * amount
                local width = first.width + (second.width - first.width) * amount
                local height = first.height + (second.height - first.height) * amount
                local previousX, previousY, previousZ = nil, nil, nil
                for side = 0, sides do
                    local angle = (side / sides) * math.pi * 2
                    local lateral = math.cos(angle)
                    local vertical = math.sin(angle)
                    local px = cx + sideX * width * lateral
                    local py = cy + sideY * width * lateral
                    local pz = cz + height * vertical
                    if previousX then
                        local light = 0.70 + math.max(0, vertical) * 0.34 + math.max(0, lateral) * 0.08
                        line(previousX, previousY, previousZ, px, py, pz, thickness,
                            math.min(1, color.r * light), math.min(1, color.g * light),
                            math.min(1, color.b * light), alpha)
                    end
                    previousX, previousY, previousZ = px, py, pz
                end
            end
        end
    end
end

local function drawBeast(shell, time)
    updateShellAnchor(shell)

    local x, y, z = shell.lastKnownX, shell.lastKnownY, shell.lastKnownZ
    local cfg = shell.config
    local color = cfg.color or { r = 1.0, g = 0.5, b = 0.1 }
    local fx, fy, sx, sy = normalizedFacing(shell)
    local pulse = 0.94 + math.sin(time * 72.0) * 0.04
    local ritual = ritualForRuntime(shell.runtimeId)
    local sealingProgress = ritual and math.max(0, math.min(1, ritual.progress / 100)) or 0
    local sealingFade = 1 - sealingProgress * 0.78
    local alpha = 0.72 * pulse * sealingFade
    local quality = nearestLocalPlayerDistance(x, y, z) <= 26.0 and "near" or "far"
    local breathe = math.sin(time * 42.0) * 0.035

    local bodyLength = math.max(1.55, (cfg.visualRadius or 2.4) * 0.72)
    local bodyWidth = bodyLength * 0.58
    local bodyHeight = math.max(1.0, (cfg.visualHeight or 2.2) * 0.62)
    local chestX = x + fx * bodyLength * 0.34
    local chestY = y + fy * bodyLength * 0.34
    local rumpX = x - fx * bodyLength * 0.34
    local rumpY = y - fy * bodyLength * 0.34
    local bodyCentreZ = z + bodyHeight * 0.72 + breathe

    renderDenseSweep({
        sweepNode(rumpX - fx * bodyLength * 0.34, rumpY - fy * bodyLength * 0.34,
            bodyCentreZ - bodyHeight * 0.08, bodyWidth * 0.58, bodyHeight * 0.46),
        sweepNode(rumpX, rumpY, bodyCentreZ, bodyWidth, bodyHeight * 0.61),
        sweepNode(x - fx * bodyLength * 0.06, y - fy * bodyLength * 0.06,
            bodyCentreZ + bodyHeight * 0.02, bodyWidth * 0.90, bodyHeight * 0.62),
        sweepNode(chestX, chestY, bodyCentreZ + bodyHeight * 0.08,
            bodyWidth * 0.96, bodyHeight * 0.67),
        sweepNode(chestX + fx * bodyLength * 0.34, chestY + fy * bodyLength * 0.34,
            bodyCentreZ + bodyHeight * 0.12, bodyWidth * 0.66, bodyHeight * 0.55),
    }, quality, color, alpha)

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
        renderDenseSweep({
            sweepNode(baseX, baseY, z + bodyHeight * 0.72, bodyWidth * 0.29, bodyWidth * 0.28),
            sweepNode(kneeX, kneeY, z + bodyHeight * 0.34, bodyWidth * 0.22, bodyWidth * 0.24),
            sweepNode(pawX, pawY, z + 0.15, bodyWidth * 0.17, bodyWidth * 0.17),
            sweepNode(pawX + fx * bodyLength * 0.22, pawY + fy * bodyLength * 0.22,
                z + 0.12, bodyWidth * 0.23, bodyWidth * 0.10),
            sweepNode(pawX + fx * bodyLength * 0.34, pawY + fy * bodyLength * 0.34,
                z + 0.11, bodyWidth * 0.05, bodyWidth * 0.04),
        }, quality, color, alpha * 0.96)
    end

    local neckX = x + fx * bodyLength * 0.78
    local neckY = y + fy * bodyLength * 0.78
    local headX = x + fx * bodyLength * 1.12
    local headY = y + fy * bodyLength * 1.12
    local headZ = z + bodyHeight * 1.12
    local browX = headX + fx * bodyLength * 0.24
    local browY = headY + fy * bodyLength * 0.24
    local muzzleX = headX + fx * bodyLength * 0.55
    local muzzleY = headY + fy * bodyLength * 0.55
    renderDenseSweep({
        sweepNode(chestX, chestY, z + bodyHeight * 1.00, bodyWidth * 0.49, bodyHeight * 0.42),
        sweepNode(neckX, neckY, headZ - bodyHeight * 0.06, bodyWidth * 0.38, bodyHeight * 0.42),
        sweepNode(headX, headY, headZ, bodyWidth * 0.62, bodyHeight * 0.46),
        sweepNode(browX, browY, headZ - bodyHeight * 0.02, bodyWidth * 0.56, bodyHeight * 0.37),
        sweepNode(muzzleX, muzzleY, headZ - bodyHeight * 0.16, bodyWidth * 0.37, bodyHeight * 0.24),
        sweepNode(muzzleX + fx * bodyLength * 0.20, muzzleY + fy * bodyLength * 0.20,
            headZ - bodyHeight * 0.18, bodyWidth * 0.23, bodyHeight * 0.16),
    }, quality, color, alpha)
    renderDenseSweep({
        sweepNode(headX + fx * bodyLength * 0.15, headY + fy * bodyLength * 0.15,
            headZ - bodyHeight * 0.23, bodyWidth * 0.42, bodyHeight * 0.14),
        sweepNode(muzzleX + fx * bodyLength * 0.13, muzzleY + fy * bodyLength * 0.13,
            headZ - bodyHeight * 0.31, bodyWidth * 0.20, bodyHeight * 0.08),
    }, quality, color, alpha * 0.92)

    for _, earSide in ipairs({ -1, 1 }) do
        local baseX = headX - fx * bodyLength * 0.05 + sx * bodyWidth * 0.43 * earSide
        local baseY = headY - fy * bodyLength * 0.05 + sy * bodyWidth * 0.43 * earSide
        renderDenseSweep({
            sweepNode(baseX, baseY, headZ + bodyHeight * 0.20, bodyWidth * 0.20, bodyWidth * 0.16),
            sweepNode(baseX - fx * bodyLength * 0.12 + sx * bodyWidth * 0.25 * earSide,
                baseY - fy * bodyLength * 0.12 + sy * bodyWidth * 0.25 * earSide,
                headZ + bodyHeight * 0.55, bodyWidth * 0.11, bodyWidth * 0.10),
            sweepNode(baseX - fx * bodyLength * 0.18 + sx * bodyWidth * 0.33 * earSide,
                baseY - fy * bodyLength * 0.18 + sy * bodyWidth * 0.33 * earSide,
                headZ + bodyHeight * 0.72, 0.025, 0.025),
        }, quality, color, alpha)
    end

    local eyeForward = bodyLength * 0.28
    for _, eyeSide in ipairs({ -1, 1 }) do
        local eyeX = headX + fx * eyeForward + sx * bodyWidth * 0.34 * eyeSide
        local eyeY = headY + fy * eyeForward + sy * bodyWidth * 0.34 * eyeSide
        line(eyeX - fx * 0.07 - sx * eyeSide * 0.06, eyeY - fy * 0.07 - sy * eyeSide * 0.06,
            headZ + bodyHeight * 0.08,
            eyeX + fx * 0.08 + sx * eyeSide * 0.05, eyeY + fy * 0.08 + sy * eyeSide * 0.05,
            headZ + bodyHeight * 0.04, 4.0,
            math.min(1, color.r + 0.28), math.min(1, color.g + 0.24),
            math.min(1, color.b + 0.18), sealingFade)
    end
    line(muzzleX + sx * bodyWidth * 0.17, muzzleY + sy * bodyWidth * 0.17,
        headZ - bodyHeight * 0.25,
        muzzleX - sx * bodyWidth * 0.17, muzzleY - sy * bodyWidth * 0.17,
        headZ - bodyHeight * 0.25, 3.0,
        math.max(0.08, color.r * 0.24), math.max(0.04, color.g * 0.18),
        math.max(0.03, color.b * 0.14), 0.92 * sealingFade)

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
        local segments = quality == "near" and 7 or 6
        local tailNodes = {
            sweepNode(currentX, currentY, currentZ, bodyWidth * 0.34, bodyWidth * 0.31),
        }
        for segment = 1, segments do
            local progress = segment / segments
            local angle = baseAngle + wave * (0.12 + progress * 0.25)
                + math.sin(time * 53.0 + tailIndex + segment * 0.7) * 0.07
            local length = bodyLength * (0.28 + progress * 0.035)
            local nextX = currentX + math.cos(angle) * length
            local nextY = currentY + math.sin(angle) * length
            local nextZ = currentZ + 0.10 + math.sin(progress * math.pi) * 0.20
                + wave * progress * 0.05
            local endWidth = bodyWidth * math.max(0.055, 0.31 - progress * 0.24)
            if segment == segments then endWidth = 0.025 end
            table.insert(tailNodes, sweepNode(nextX, nextY, nextZ, endWidth, endWidth * 0.92))
            currentX, currentY, currentZ = nextX, nextY, nextZ
        end
        renderDenseSweep(tailNodes, quality, color, alpha * 0.92)
    end

    local debugEnabled = (isDebugEnabled and isDebugEnabled())
        or (SandboxVars and SandboxVars.NinjaLineages and SandboxVars.NinjaLineages.DebugMode == true)
    if debugEnabled then
        ring(x, y, z + 0.04, cfg.perimeterHitboxRadius or 1.2, 32, 2.5, 1.0, 0.95, 0.25, 0.85)
    end
end

local function drawGroundCapsule(trajectory, radius, color, fillAlpha, edgeAlpha)
    local originX = tonumber(trajectory.originX) or 0
    local originY = tonumber(trajectory.originY) or 0
    local destinationX = tonumber(trajectory.destinationX) or originX
    local destinationY = tonumber(trajectory.destinationY) or originY
    local originZ = tonumber(trajectory.originZ) or 0
    local destinationZ = tonumber(trajectory.destinationZ) or tonumber(trajectory.originZ) or 0
    local dx, dy = destinationX - originX, destinationY - originY
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance < 0.001 then return end

    local forwardX, forwardY = dx / distance, dy / distance
    local sideX, sideY = -forwardY, forwardX
    local laneCount = math.max(4, math.ceil(radius / 0.05))
    local fillR = math.min(1, color.r + 0.10)
    local fillG = math.min(1, color.g + 0.10)
    local fillB = math.min(1, color.b + 0.10)

    for lane = -laneCount, laneCount do
        local sideFraction = lane / laneCount
        local offset = sideFraction * radius
        local capExtension = math.sqrt(math.max(0, radius * radius - offset * offset))
        line(originX + sideX * offset - forwardX * capExtension,
            originY + sideY * offset - forwardY * capExtension, originZ,
            destinationX + sideX * offset + forwardX * capExtension,
            destinationY + sideY * offset + forwardY * capExtension, destinationZ,
            5.5, fillR, fillG, fillB, fillAlpha)
    end

    line(originX + sideX * radius, originY + sideY * radius, originZ,
        destinationX + sideX * radius, destinationY + sideY * radius, destinationZ,
        3.1, color.r, color.g, color.b, edgeAlpha)
    line(originX - sideX * radius, originY - sideY * radius, originZ,
        destinationX - sideX * radius, destinationY - sideY * radius, destinationZ,
        3.1, color.r, color.g, color.b, edgeAlpha)
    local capRadius = radius
    while capRadius > 0.025 do
        ring(originX, originY, originZ, capRadius, 24, 5.5,
            fillR, fillG, fillB, fillAlpha)
        ring(destinationX, destinationY, destinationZ, capRadius, 24, 5.5,
            fillR, fillG, fillB, fillAlpha)
        capRadius = capRadius - 0.05
    end
    ring(originX, originY, originZ, radius, 24, 3.1,
        color.r, color.g, color.b, edgeAlpha * 0.82)
    ring(destinationX, destinationY, destinationZ, radius, 24, 3.1,
        color.r, color.g, color.b, edgeAlpha)
end

local function drawTelegraph(telegraph, time)
    local color = telegraph.color or { r = 1.0, g = 0.25, b = 0.1 }
    local duration = math.max(0.0001, telegraph.endsAtGameMinutes - telegraph.startedAtGameMinutes)
    local progress = math.max(0, math.min(1,
        (time - telegraph.startedAtGameMinutes) / duration))
    local trajectoryCount = math.max(1, #telegraph.trajectories)
    local overlapScale = 1 / (1 + (trajectoryCount - 1) * 0.08)
    local pulse = 0.82 + math.sin(time * 95.0) * 0.18
    local fillAlpha = (0.10 + progress * 0.12) * overlapScale * pulse
    local edgeAlpha = (0.48 + progress * 0.42) * pulse

    for _, trajectory in ipairs(telegraph.trajectories) do
        drawGroundCapsule(trajectory, telegraph.projectileHitRadius,
            color, fillAlpha, edgeAlpha)
    end
end

local function drawSealingRitual(ritual, time)
    if nearestLocalPlayerDistance(ritual.vesselX, ritual.vesselY, ritual.vesselZ)
            > ritual.ritualRadius + 10 then return end
    local color = ritual.color or { r = 0.72, g = 0.45, b = 1.0 }
    local pulse = 0.5 + 0.5 * math.sin((time - ritual.startedAtGameMinutes) * 22.0)
    local vesselAlpha = 0.20 + pulse * 0.14
    ring(ritual.vesselX, ritual.vesselY, ritual.vesselZ,
        1.15 + pulse * 0.08, 32, 2.0,
        color.r, color.g, color.b, vesselAlpha)
    ring(ritual.vesselX, ritual.vesselY, ritual.vesselZ,
        0.72, 24, 1.4,
        math.min(1, color.r + 0.2), math.min(1, color.g + 0.2), math.min(1, color.b + 0.2), 0.24)

    if ritual.ritualRadius > 0 then
        ring(ritual.vesselX, ritual.vesselY, ritual.vesselZ,
            ritual.ritualRadius, 96, 1.25,
            color.r, color.g, color.b, 0.12 + pulse * 0.05)
    end

    local shell = activeShells[ritual.bijuuRuntimeId]
    if shell then
        updateShellAnchor(shell)
        local progress = math.max(0, math.min(1, ritual.progress / 100))
        local streamCount = 5
        local streamAlpha = 0.20 + progress * 0.34
        local streamHeight = 0.72 + ((shell.config and shell.config.visualHeight) or 1.0) * 0.45
        for streamIndex = 1, streamCount do
            local phase = time * 54.0 + streamIndex * 1.37
            local offsetX = math.cos(phase) * (0.28 + streamIndex * 0.055)
            local offsetY = math.sin(phase) * (0.28 + streamIndex * 0.055)
            local startX = shell.lastKnownX + offsetX
            local startY = shell.lastKnownY + offsetY
            local startZ = shell.lastKnownZ + streamHeight
                + math.sin(phase * 0.73) * 0.16
            local previousX, previousY, previousZ = startX, startY, startZ
            local segments = 8
            for segment = 1, segments do
                local amount = segment / segments
                local arc = math.sin(amount * math.pi)
                local curl = math.sin(phase + amount * math.pi * 2) * 0.14 * arc
                local nextX = startX + (ritual.vesselX - startX) * amount + offsetY * curl
                local nextY = startY + (ritual.vesselY - startY) * amount - offsetX * curl
                local nextZ = startZ + (ritual.vesselZ + 0.10 - startZ) * amount
                    + arc * (0.24 + progress * 0.22)
                line(previousX, previousY, previousZ, nextX, nextY, nextZ,
                    3.2 + progress * 2.1,
                    math.min(1, color.r + 0.16), math.min(1, color.g + 0.16),
                    math.min(1, color.b + 0.16), streamAlpha)
                previousX, previousY, previousZ = nextX, nextY, nextZ
            end
        end
    end
end

function Renderer.renderAll(time)
    if not getCell or not getCell() then return end
    for _, ritual in pairs(activeRituals) do drawSealingRitual(ritual, time) end
    for volleyId, telegraph in pairs(activeTelegraphs) do
        if time >= telegraph.endsAtGameMinutes then
            activeTelegraphs[volleyId] = nil
        else
            drawTelegraph(telegraph, time)
        end
    end
    for _, shell in pairs(activeShells) do drawBeast(shell, time) end
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
        local sealingServer = NinjaLineages.BijuuSealingServer
        if sealingServer and sealingServer.getActiveRitualPayloads then
            for _, ritual in ipairs(sealingServer.getActiveRitualPayloads()) do
                Renderer.addSealingRitual(ritual)
            end
        end
    end
end

Authority.registerEventHandler("bijuu_shell_spawned", Renderer.addShell)
Authority.registerEventHandler("bijuu_shell_removed", Renderer.removeShell)
Authority.registerEventHandler("bijuu_shell_health", Renderer.updateShellHealth)
Authority.registerEventHandler("bijuu_telegraph_started", Renderer.addTelegraph)
Authority.registerEventHandler("bijuu_telegraph_ended", Renderer.removeTelegraph)
Authority.registerEventHandler("bijuu_active_shells", Renderer.replaceShells)
Authority.registerEventHandler("bijuu_sealing_started", Renderer.addSealingRitual)
Authority.registerEventHandler("bijuu_sealing_cancelled", Renderer.removeSealingRitual)
Authority.registerEventHandler("bijuu_sealing_progress", Renderer.updateSealingRitual)
Authority.registerEventHandler("bijuu_sealing_completed", Renderer.removeSealingRitual)

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
