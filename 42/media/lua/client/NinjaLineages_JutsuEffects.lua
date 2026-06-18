NinjaLineages = NinjaLineages or {}
NinjaLineages.JutsuEffects = NinjaLineages.JutsuEffects or {}

local activeKatonStreams = {}
local katonFireTexture = nil
local katonTextureProbed = false
local katonTextureRenderFailed = false

function NinjaLineages.JutsuEffects.addKatonStream(args)
    if not args then return end
    local streamId = args.streamId or tostring(NinjaLineages.Utils.Time.realMilliseconds())
    activeKatonStreams[streamId] = {
        streamId = streamId,
        originX = args.originX,
        originY = args.originY,
        originZ = args.originZ,
        directionX = args.directionX,
        directionY = args.directionY,
        range = args.range,
        minDot = args.minDot,
        durationMs = args.durationMs or 750,
        startedAtMs = NinjaLineages.Utils.Time.realMilliseconds(),
    }
end

local function resolveKatonTexture()
    if katonTextureProbed then return katonFireTexture end
    katonTextureProbed = true
    pcall(function()
        if ParticlesFire and ParticlesFire.getInstance then
            katonFireTexture = ParticlesFire.getInstance():getFireFlameTexture()
        end
    end)
    if not katonFireTexture and getTexture then
        pcall(function() katonFireTexture = getTexture("Fire") end)
    end
    return katonFireTexture
end

local function worldToScreen(x, y, z)
    local sx = IsoUtils.XToScreen(x, y, z, 0) - IsoCamera.getOffX()
    local sy = IsoUtils.YToScreen(x, y, z, 0) - IsoCamera.getOffY()
    return sx, sy
end

local function renderFireParticle(texture, x, y, z, size, alpha, heightOffset)
    local sx, sy = worldToScreen(x, y, z)
    sy = sy - (heightOffset or 0)
    if texture and not katonTextureRenderFailed then
        local half = size * 0.5
        local ok = pcall(function()
            SpriteRenderer.instance:render(
                texture,
                sx - half, sy - size,
                sx + half, sy - size,
                sx + half, sy,
                sx - half, sy,
                1.0, 0.38, 0.05, alpha,
                1.0, 0.70, 0.08, alpha,
                0.95, 0.18, 0.02, alpha,
                1.0, 0.55, 0.04, alpha,
                nil
            )
        end)
        if ok then return end
        katonTextureRenderFailed = true
    end

    renderIsoLine(
        x, y, z,
        x + 0.04, y + 0.04, z,
        math.max(2, size * 0.18),
        1.0, 0.32, 0.02,
        alpha
    )
end

local function renderKatonStream(stream, progress)
    local texture = resolveKatonTexture()
    local maxDistance = stream.range * progress
    if maxDistance <= 0 then return end
    local perpendicularX = -stream.directionY
    local perpendicularY = stream.directionX
    local minDot = math.max(0.01, math.min(0.999, stream.minDot or 0.82))
    local coneSlope = math.sqrt(1 - minDot * minDot) / minDot
    local tileScale = Core and Core.getTileScale and Core.getTileScale() or 1

    local distance = 0.15
    while distance <= maxDistance do
        local halfWidth = math.max(0.05, distance * coneSlope)
        local lateralStep = math.max(0.22, halfWidth / 2)
        local lateral = -halfWidth
        while lateral <= halfWidth + 0.001 do
            local x = stream.originX + stream.directionX * distance
                + perpendicularX * lateral
            local y = stream.originY + stream.directionY * distance
                + perpendicularY * lateral
            local edge = halfWidth > 0 and math.abs(lateral) / halfWidth or 0
            local flicker = 0.85 + 0.15 * math.sin(
                (NinjaLineages.Utils.Time.realMilliseconds() + distance * 190 + lateral * 130)
                    * 0.025
            )
            local alpha = math.max(0.18, (1 - edge * 0.5) * flicker)
            local size = (16 + distance * 5) * tileScale
            local mouthHeight = 42 * tileScale * math.max(0, 1 - distance / stream.range)
            renderFireParticle(texture, x, y, stream.originZ, size, alpha, mouthHeight)
            lateral = lateral + lateralStep
        end
        distance = distance + 0.28
    end
end

local function renderEffects()
    local nowMs = NinjaLineages.Utils.Time.realMilliseconds()
    for streamId, stream in pairs(activeKatonStreams) do
        local progress = (nowMs - stream.startedAtMs) / stream.durationMs
        if progress >= 1 then
            activeKatonStreams[streamId] = nil
        else
            renderKatonStream(stream, math.max(0, progress))
        end
    end
end

NinjaLineages.addEventOnce("client.jutsuEffects.onPostRender", Events.OnPostRender, renderEffects)
