require "NinjaLineages_Utils"
require "NinjaLineages_Balance"
require "disciplines/jinchuuriki/NinjaLineages_BijuuDefinitions"
require "disciplines/jinchuuriki/NinjaLineages_BijuuBoss"

NinjaLineages = NinjaLineages or {}
NinjaLineages.BijuuRenderer = NinjaLineages.BijuuRenderer or {}

local Renderer = NinjaLineages.BijuuRenderer
local Boss = NinjaLineages.BijuuBoss

local activeShells = {}

function Renderer.getActiveShells()
    return activeShells
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

function Renderer.clearAllShells()
    activeShells = {}
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

function Renderer.renderAll(nowGameMinutes)
    if not activeShells then return end
    for runtimeId, shell in pairs(activeShells) do
        Renderer.renderShell(shell, nowGameMinutes)
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
    elseif command == "bijuuActiveShellsSync" then
        Renderer.clearAllShells()
        if type(args) == "table" then
            for _, shellData in ipairs(args) do
                Renderer.addShell(shellData)
            end
        end
    end
end

NinjaLineages.addEventOnce(
    "client.bijuuRenderer.onServerCommand",
    Events.OnServerCommand,
    onServerCommand
)
