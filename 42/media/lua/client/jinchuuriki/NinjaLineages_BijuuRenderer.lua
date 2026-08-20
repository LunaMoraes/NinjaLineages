require "NinjaLineages_Utils"
require "NinjaLineages_Balance"
require "disciplines/jinchuuriki/NinjaLineages_BijuuDefinitions"
require "disciplines/jinchuuriki/NinjaLineages_BijuuBoss"

NinjaLineages = NinjaLineages or {}
NinjaLineages.BijuuRenderer = NinjaLineages.BijuuRenderer or {}

local Renderer = NinjaLineages.BijuuRenderer
local Boss = NinjaLineages.BijuuBoss

local activeShells = {}
local activeTelegraphs = {}

function Renderer.getActiveShells()
    return activeShells
end

function Renderer.getActiveTelegraphs()
    return activeTelegraphs
end

function Renderer.addShell(payload)
    if not payload or not payload.runtimeId or not payload.bijuuId then return end

    local config = Boss.getShellConfig(payload.bijuuId)
    activeShells[payload.runtimeId] = {
        runtimeId = payload.runtimeId,
        bijuuId = payload.bijuuId,
        proxyOnlineId = payload.proxyOnlineId,
        lastKnownX = payload.x or 0,
        lastKnownY = payload.y or 0,
        lastKnownZ = payload.z or 0,
        config = config,
    }
end

function Renderer.removeShell(payload)
    if not payload or not payload.runtimeId then return end

    if activeShells[payload.runtimeId] then
        activeShells[payload.runtimeId] = nil
    end
end

function Renderer.addTelegraph(payload)
    if not payload or not payload.volleyId or not payload.trajectories then return end

    local color = Boss.getThemeColor(payload.bijuuId)
    activeTelegraphs[payload.volleyId] = {
        volleyId = payload.volleyId,
        bijuuId = payload.bijuuId,
        runtimeId = payload.runtimeId,
        startedAtGameMinutes = payload.startedAtGameMinutes or NinjaLineages.Utils.Time.gameMinutes(),
        endsAtGameMinutes = payload.endsAtGameMinutes or (NinjaLineages.Utils.Time.gameMinutes() + 0.05),
        trajectories = payload.trajectories,
        color = color,
    }
end

function Renderer.removeTelegraph(payload)
    if not payload or not payload.volleyId then return end
    if activeTelegraphs[payload.volleyId] then
        activeTelegraphs[payload.volleyId] = nil
    end
end

function Renderer.clearAllShells()
    activeShells = {}
    activeTelegraphs = {}
end

local function renderIsoCircleSafe(x, y, z, radius, segments, thickness, r, g, b, alpha)
    if renderIsoCircle then
        renderIsoCircle(
            x, y, z,
            math.max(0.05, radius or 1.0),
            segments or 32,
            thickness or 2.0,
            r or 1.0, g or 1.0, b or 1.0,
            alpha or 1.0
        )
    end
end

local function renderIsoLineSafe(x1, y1, z1, x2, y2, z2, thickness, r, g, b, alpha)
    if renderIsoLine then
        renderIsoLine(
            x1, y1, z1,
            x2, y2, z2,
            thickness or 2.0,
            r or 1.0, g or 1.0, b or 1.0,
            alpha or 1.0
        )
    end
end

function Renderer.renderShell(shell, nowGameMinutes)
    if not shell or not shell.config then return end

    -- 1. Try resolving live proxy entity by online ID
    local proxy = nil
    if shell.proxyOnlineId and NinjaLineages.Utils.Zombies.getByOnlineID then
        proxy = NinjaLineages.Utils.Zombies.getByOnlineID(shell.proxyOnlineId)
    end

    if proxy and not (proxy.isDead and proxy:isDead()) then
        shell.lastKnownX = proxy:getX()
        shell.lastKnownY = proxy:getY()
        shell.lastKnownZ = proxy:getZ()
    end

    local x = shell.lastKnownX
    local y = shell.lastKnownY
    local z = shell.lastKnownZ

    local cfg = shell.config
    local baseColor = cfg.color or { r = 1.0, g = 0.6, b = 0.2 }
    local r, g, b = baseColor.r, baseColor.g, baseColor.b

    -- Game-time driven subtle breathing pulse
    local pulse = 0.85 + 0.15 * math.sin(nowGameMinutes * 70.0)
    local mainAlpha = 0.80 * pulse

    local radius = cfg.visualRadius or 2.4
    local height = cfg.visualHeight or 2.2
    local rings = cfg.ringsCount or 4

    -- 2. Base ground circle
    renderIsoCircleSafe(x, y, z, radius, 36, 3.0, r, g, b, mainAlpha)

    -- 3. Stacked elevation contour rings (dome / body shell)
    for i = 1, rings do
        local progress = i / rings
        local elevation = progress * height
        local ringRadius = radius * math.cos(progress * (math.pi / 2.2))
        local ringAlpha = mainAlpha * (1.0 - (progress * 0.35))
        renderIsoCircleSafe(x, y, z + elevation, ringRadius, 28, 2.0, r, g, b, ringAlpha)
    end

    -- 4. Meridian ribs (vertical lines shaping the body cage)
    local ribCount = 8
    for rib = 1, ribCount do
        local angle = (rib - 1) * (math.pi * 2 / ribCount)
        local cosA = math.cos(angle)
        local sinA = math.sin(angle)

        local prevX = x + (cosA * radius)
        local prevY = y + (sinA * radius)
        local prevZ = z

        for step = 1, rings do
            local progress = step / rings
            local elevation = progress * height
            local stepRadius = radius * math.cos(progress * (math.pi / 2.2))
            local nextX = x + (cosA * stepRadius)
            local nextY = y + (sinA * stepRadius)
            local nextZ = z + elevation

            renderIsoLineSafe(prevX, prevY, prevZ, nextX, nextY, nextZ, 1.8, r, g, b, mainAlpha * 0.7)
            prevX, prevY, prevZ = nextX, nextY, nextZ
        end
    end

    -- 5. Forward-facing head indicator
    local forward = nil
    if proxy and proxy.getForwardDirection then
        forward = proxy:getForwardDirection()
    end
    local fx = forward and forward:getX() or 0
    local fy = forward and forward:getY() or 1
    local fLen = math.sqrt(fx * fx + fy * fy)
    if fLen > 0.001 then
        fx, fy = fx / fLen, fy / fLen
    else
        fx, fy = 0, 1
    end

    local headDist = radius * 0.65
    local headX = x + (fx * headDist)
    local headY = y + (fy * headDist)
    local headZ = z + (height * 0.6)
    local headRadius = cfg.headRadius or 1.2
    renderIsoCircleSafe(headX, headY, headZ, headRadius, 24, 2.5, r, g, b, mainAlpha * 0.9)
    renderIsoLineSafe(x, y, headZ, headX, headY, headZ, 2.0, r, g, b, mainAlpha * 0.8)

    -- 6. Core underlying proxy marker
    renderIsoCircleSafe(x, y, z, 0.4, 16, 1.5, 1.0, 1.0, 1.0, 0.4)

    -- 7. Debug Hitbox Overlay (contrasting white/gold boundary at target width)
    local isDebug = (isDebugEnabled and isDebugEnabled())
        or (SandboxVars and SandboxVars.NinjaLineages and SandboxVars.NinjaLineages.DebugMode == true)
    if isDebug then
        local hitboxRadius = (cfg.proxyWidth or 2.4) / 2
        renderIsoCircleSafe(x, y, z + 0.05, hitboxRadius, 32, 2.0, 1.0, 0.95, 0.3, 0.75 * pulse)
    end
end

function Renderer.renderTelegraph(telegraph, nowGameMinutes)
    if not telegraph or not telegraph.trajectories then return end

    local color = telegraph.color or { r = 1.0, g = 0.2, b = 0.1 }
    local r, g, b = color.r, color.g, color.b

    -- Pulsing danger alpha
    local pulse = 0.65 + 0.35 * math.sin(nowGameMinutes * 90.0)
    local alpha = math.max(0.2, math.min(1.0, 0.75 * pulse))

    for _, traj in ipairs(telegraph.trajectories) do
        local oX = traj.originX
        local oY = traj.originY
        local oZ = (traj.originZ or 0) + 0.05
        local dX = traj.destinationX
        local dY = traj.destinationY
        local dZ = (traj.destinationZ or 0) + 0.05

        -- Draw telegraphed fixed-path lane
        renderIsoLineSafe(oX, oY, oZ, dX, dY, dZ, 3.5, r, g, b, alpha)
        -- Draw endpoint warning circle
        renderIsoCircleSafe(dX, dY, dZ, 0.6, 16, 2.0, r, g, b, alpha * 0.8)
    end
end

local function isWorldReady()
    if not getCell or not getCell() then return false end
    if not getSpecificPlayer or not getSpecificPlayer(0) then return false end
    if not IsoCamera or not IsoCamera.CamCharacter then return false end
    return true
end

function Renderer.renderAll(nowGameMinutes)
    if not isWorldReady() then return end

    -- 1. Render all active Bijū giant shells
    if activeShells then
        for _, shell in pairs(activeShells) do
            Renderer.renderShell(shell, nowGameMinutes)
        end
    end

    -- 2. Render all active telegraph threat lanes
    if activeTelegraphs then
        local expiredTelegraphs = {}
        for volleyId, telegraph in pairs(activeTelegraphs) do
            if nowGameMinutes >= telegraph.endsAtGameMinutes then
                table.insert(expiredTelegraphs, volleyId)
            else
                Renderer.renderTelegraph(telegraph, nowGameMinutes)
            end
        end
        for _, vId in ipairs(expiredTelegraphs) do
            activeTelegraphs[vId] = nil
        end
    end
end

-- ============================================================================
-- Network Event Handling & Client Sync
-- ============================================================================

local function onServerCommand(module, command, args)
    if module ~= "NinjaLineages" then return end

    if command == "bijuuShellSpawned" then
        Renderer.addShell(args)
    elseif command == "bijuuShellRemoved" then
        Renderer.removeShell(args)
    elseif command == "bijuuTelegraphStarted" then
        Renderer.addTelegraph(args)
    elseif command == "bijuuTelegraphEnded" then
        Renderer.removeTelegraph(args)
    elseif command == "bijuuActiveShellsSync" then
        Renderer.clearAllShells()
        if type(args) == "table" then
            for _, shellData in ipairs(args) do
                Renderer.addShell(shellData)
            end
        end
    end
end

local function onWeaponSwing(player, weapon)
    if not player or not player.isLocalPlayer or not player:isLocalPlayer() or (player.isDead and player:isDead()) then return end
    if weapon and weapon.isRanged and weapon:isRanged() then return end

    local px = player:getX()
    local py = player:getY()
    local pz = player:getZ()
    local forward = player:getForwardDirection()
    local fx = forward and forward:getX() or 0
    local fy = forward and forward:getY() or 1
    local fLen = math.sqrt(fx * fx + fy * fy)
    if fLen > 0.001 then fx, fy = fx / fLen, fy / fLen else fx, fy = 0, 1 end

    local maxRange = (weapon and weapon.getMaxRange and weapon:getMaxRange(player)) or 1.5
    local bossRadius = 1.2
    local allowedReach = bossRadius + maxRange + 0.35

    for runtimeId, shell in pairs(activeShells) do
        local bx = shell.lastKnownX
        local by = shell.lastKnownY
        local bz = shell.lastKnownZ
        if math.abs(pz - bz) < 1.5 then
            local dx = bx - px
            local dy = by - py
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist <= allowedReach and dist > (maxRange * 0.8) then
                local dirX = dx / (dist > 0.0001 and dist or 1)
                local dirY = dy / (dist > 0.0001 and dist or 1)
                local dot = (dirX * fx) + (dirY * fy)
                if dot >= 0.42 then
                    local hit = NinjaLineages.Collision and NinjaLineages.Collision.traceSegment(px, py, pz, bx, by, pz)
                    if hit == nil then
                        local swingId = tostring(NinjaLineages.Utils.Time.gameMinutes()) .. "_" .. tostring(player.getOnlineID and player:getOnlineID() or 0)
                        sendClientCommand(player, "NinjaLineages", "bijuuMeleeSwing", {
                            bijuuId = shell.bijuuId,
                            runtimeId = runtimeId,
                            swingId = swingId,
                        })
                    end
                end
            end
        end
    end
end

NinjaLineages.addEventOnce(
    "client.bijuuRenderer.onServerCommand",
    Events.OnServerCommand,
    onServerCommand
)

if Events and Events.OnWeaponSwing then
    NinjaLineages.addEventOnce(
        "client.bijuuRenderer.onWeaponSwing",
        Events.OnWeaponSwing,
        onWeaponSwing
    )
end
