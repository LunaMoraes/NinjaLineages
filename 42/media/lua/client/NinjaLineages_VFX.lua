require "NinjaLineages_Constants"
require "NinjaLineages_Utils"
require "NinjaLineages_Progression"

NinjaLineages = NinjaLineages or {}
NinjaLineages.VFX = NinjaLineages.VFX or {}

local VFX = NinjaLineages.VFX
local consts = NinjaLineages.Constants

-- ============================================================================
-- Character / Body Anchor Constants & Height Offsets
-- (Uses screen/world visual height offsets since B42 AnimationPlayer bone APIs
--  are not exposed to Lua)
-- ============================================================================

VFX.ANCHOR_FEET = 0.0
VFX.ANCHOR_HAND = 0.12
VFX.ANCHOR_CHEST = 0.18
VFX.ANCHOR_HEAD = 0.30

function VFX.getCharacterAnchor(character, anchorName)
    if not character then return 0, 0, 0 end
    local x = character:getX()
    local y = character:getY()
    local z = character:getZ()
    local offset = VFX.ANCHOR_CHEST
    if anchorName == "hand" then
        offset = VFX.ANCHOR_HAND
    elseif anchorName == "head" then
        offset = VFX.ANCHOR_HEAD
    elseif anchorName == "feet" or anchorName == "ground" then
        offset = VFX.ANCHOR_FEET
    elseif type(anchorName) == "number" then
        offset = anchorName
    end
    return x, y, z + offset
end

-- ============================================================================
-- Core Rendering Primitives (Presentation only)
-- ============================================================================

function VFX.renderLine(x1, y1, z1, x2, y2, z2, thickness, r, g, b, alpha)
    renderIsoLine(
        x1, y1, z1,
        x2, y2, z2,
        thickness or 2.0,
        r or 1.0, g or 1.0, b or 1.0,
        alpha or 1.0
    )
end

function VFX.renderRing(x, y, z, radius, segments, thickness, r, g, b, alpha, heightOffset)
    local zVisual = z + (heightOffset or 0)
    renderIsoCircle(
        x, y, zVisual,
        math.max(0.05, radius or 1.0),
        segments or 32,
        thickness or 2.0,
        r or 1.0, g or 1.0, b or 1.0,
        alpha or 1.0
    )
end

function VFX.renderBeam(fromX, fromY, fromZ, toX, toY, toZ, thickness, r, g, b, alpha, fromHeight, toHeight)
    local fZ = fromZ + (fromHeight or VFX.ANCHOR_HAND)
    local tZ = toZ + (toHeight or VFX.ANCHOR_CHEST)
    VFX.renderLine(fromX, fromY, fZ, toX, toY, tZ, thickness, r, g, b, alpha)
end

function VFX.renderAura(character, r, g, b, baseAlpha, baseRadius)
    if not character or (character.isDead and character:isDead()) then return end
    local x = character:getX()
    local y = character:getY()
    local z = character:getZ()
    local nowMs = NinjaLineages.Utils.Time.realMilliseconds()

    local pulse = 0.25 + 0.15 * math.sin(nowMs / 250)
    local alpha = (baseAlpha or 0.8) * pulse
    local rad = (baseRadius or 0.85) + 0.1 * math.cos(nowMs / 300)

    -- Multi-height body aura rings (feet, chest, head) calibrated to PZ character scale
    VFX.renderRing(x, y, z, rad, 24, 2.0, r, g, b, alpha * 0.9, 0.02)
    VFX.renderRing(x, y, z, rad * 0.9, 24, 2.0, r, g, b, alpha * 0.75, 0.15)
    VFX.renderRing(x, y, z, rad * 0.75, 20, 2.0, r, g, b, alpha * 0.6, 0.28)
end

-- ============================================================================
-- Visual State Pools
-- ============================================================================

local activeLines = {}
local activeProjectiles = {}
local activeKatonStreams = {}
local activeBringerOfDarknessCircles = {}
local activeDemonicFluteCircles = {}
local activeShinraTenseiPulses = {}
local activeToadSlams = {}
local activeKatsuyuHealWaves = {}

local katonFireTexture = nil
local katonTextureProbed = false
local katonTextureRenderFailed = false

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

local function renderFireParticle(texture, x, y, z, size, alpha, screenYOffset)
    local sx = IsoUtils.XToScreen(x, y, z, 0) - IsoCamera.getOffX()
    local sy = IsoUtils.YToScreen(x, y, z, 0) - IsoCamera.getOffY() - (screenYOffset or 0)
    local half = size / 2

    if texture and not katonTextureRenderFailed and SpriteRenderer and SpriteRenderer.instance then
        local ok = pcall(function()
            SpriteRenderer.instance:render(
                texture,
                sx - half, sy - half,
                sx + half, sy - half,
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

-- ============================================================================
-- Public VFX Registration APIs
-- ============================================================================

function VFX.addLine(args)
    if not args then return end
    local constsMedical = consts.Medical and consts.Medical.ChakraNeedle or {}
    table.insert(activeLines, {
        fromX = args.fromX,
        fromY = args.fromY,
        fromZ = args.fromZ,
        toX = args.toX,
        toY = args.toY,
        toZ = args.toZ,
        fromHeight = args.fromHeight or VFX.ANCHOR_HAND,
        toHeight = args.toHeight or VFX.ANCHOR_CHEST,
        color = args.color or constsMedical.COLOR or { R = 0.2, G = 0.8, B = 1.0 },
        thickness = args.thickness or constsMedical.THICKNESS or 2.0,
        startedAt = NinjaLineages.Utils.Time.realMilliseconds(),
        durationMs = args.durationMs or constsMedical.VISUAL_DURATION_MS or 250,
    })
end

function VFX.addProjectile(args)
    if not args then return end
    local constsMedical = consts.Medical and consts.Medical.ChakraNeedle or {}
    local dx = args.toX - args.fromX
    local dy = args.toY - args.fromY
    local dz = args.toZ - args.fromZ
    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
    local projectileId = args.projectileId
        or ("proj_" .. tostring(NinjaLineages.Utils.Time.realMilliseconds()))

    activeProjectiles[projectileId] = {
        projectileId = projectileId,
        fromX = args.fromX,
        fromY = args.fromY,
        fromZ = args.fromZ,
        toX = args.toX,
        toY = args.toY,
        toZ = args.toZ,
        fromHeight = args.fromHeight or VFX.ANCHOR_HAND,
        toHeight = args.toHeight or VFX.ANCHOR_CHEST,
        speed = args.speed or 20,
        startGameMinutes = args.startGameMinutes or NinjaLineages.Utils.Time.gameMinutes(),
        distance = distance,
        color = args.color or constsMedical.COLOR or { R = 0.2, G = 0.8, B = 1.0 },
        thickness = args.thickness or constsMedical.THICKNESS or 2.0,
    }
end

function VFX.resolveProjectile(args)
    if not args or not args.projectileId then return end
    local proj = activeProjectiles[args.projectileId]
    if not proj then return end
    proj.resolvedX = args.x
    proj.resolvedY = args.y
    proj.resolvedZ = args.z
    proj.resolvedAtMs = NinjaLineages.Utils.Time.realMilliseconds()
end

function VFX.addKatonStream(args)
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

function VFX.addBringerOfDarknessCircle(args)
    if not args or not args.x or not args.y or not args.z or not args.radius then return end
    table.insert(activeBringerOfDarknessCircles, {
        x = args.x,
        y = args.y,
        z = args.z,
        radius = args.radius,
        startedAtMs = NinjaLineages.Utils.Time.realMilliseconds(),
    })
end

function VFX.addDemonicFluteCircle(args)
    if not args or not args.x or not args.y or not args.z or not args.radius then return end
    table.insert(activeDemonicFluteCircles, {
        x = args.x,
        y = args.y,
        z = args.z,
        radius = args.radius,
        startedAtMs = NinjaLineages.Utils.Time.realMilliseconds(),
    })
end

function VFX.addShinraTenseiPulse(x, y, z, maxRadius)
    local resolvedRadius = maxRadius or (NinjaLineages.JutsuCatalog
        and NinjaLineages.JutsuCatalog.resolveBalance("shinra_tensei")
        and NinjaLineages.JutsuCatalog.resolveBalance("shinra_tensei").radius) or 7.0

    table.insert(activeShinraTenseiPulses, {
        x = x,
        y = y,
        z = z,
        maxRadius = resolvedRadius,
        startedAt = NinjaLineages.Utils.Time.realMilliseconds(),
    })
end

function VFX.addToadSlam(x, y, z, radius)
    table.insert(activeToadSlams, {
        x = x,
        y = y,
        z = z,
        radius = radius or 3.5,
        startedAtMs = NinjaLineages.Utils.Time.realMilliseconds(),
    })
end

function VFX.addKatsuyuHealWave(x, y, z, radius)
    table.insert(activeKatsuyuHealWaves, {
        x = x,
        y = y,
        z = z,
        radius = radius or 6.0,
        startedAtMs = NinjaLineages.Utils.Time.realMilliseconds(),
    })
end

-- ============================================================================
-- Central Render Loop (Called once per frame on OnPostRender)
-- ============================================================================

local function renderKatonStreams(nowMs)
    local texture = resolveKatonTexture()
    local tileScale = Core and Core.getTileScale and Core.getTileScale() or 1

    for streamId, stream in pairs(activeKatonStreams) do
        local progress = (nowMs - stream.startedAtMs) / stream.durationMs
        if progress >= 1 then
            activeKatonStreams[streamId] = nil
        else
            local maxDistance = stream.range * math.max(0, progress)
            if maxDistance > 0 then
                local perpendicularX = -stream.directionY
                local perpendicularY = stream.directionX
                local minDot = math.max(0.01, math.min(0.999, stream.minDot or 0.82))
                local coneSlope = math.sqrt(1 - minDot * minDot) / minDot

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
                            (nowMs + distance * 190 + lateral * 130) * 0.025
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
        end
    end
end

local function renderStaticBeams(nowMs)
    for i = #activeLines, 1, -1 do
        local line = activeLines[i]
        local progress = (nowMs - line.startedAt) / line.durationMs
        if progress >= 1 then
            table.remove(activeLines, i)
        else
            local alpha = 0.85 * (1.0 - progress)
            VFX.renderBeam(
                line.fromX, line.fromY, line.fromZ,
                line.toX, line.toY, line.toZ,
                line.thickness,
                line.color.R, line.color.G, line.color.B,
                alpha,
                line.fromHeight, line.toHeight
            )
        end
    end
end

local function renderTravelingProjectiles(nowMs)
    local nowGameMinutes = NinjaLineages.Utils.Time.gameMinutes()
    for projectileId, proj in pairs(activeProjectiles) do
        if proj.resolvedAtMs then
            if nowMs - proj.resolvedAtMs >= 120 then
                activeProjectiles[projectileId] = nil
            else
                local dirX = proj.toX - proj.fromX
                local dirY = proj.toY - proj.fromY
                local dirLen = math.sqrt(dirX * dirX + dirY * dirY)
                if dirLen > 0 then
                    dirX = dirX / dirLen
                    dirY = dirY / dirLen
                end
                local hitZ = proj.resolvedZ + proj.toHeight
                VFX.renderLine(
                    proj.resolvedX, proj.resolvedY, hitZ,
                    proj.resolvedX + dirX * 0.18, proj.resolvedY + dirY * 0.18, hitZ,
                    proj.thickness * 1.6,
                    proj.color.R, proj.color.G, proj.color.B,
                    0.95
                )
            end
        else
            local elapsed = nowGameMinutes - proj.startGameMinutes
            local totalTime = proj.distance / proj.speed
            local progress = totalTime > 0 and (elapsed / totalTime) or 1

            if progress >= 1 then
                activeProjectiles[projectileId] = nil
            else
                local cx = proj.fromX + (proj.toX - proj.fromX) * progress
                local cy = proj.fromY + (proj.toY - proj.fromY) * progress
                local currentZ = proj.fromZ + (proj.toZ - proj.fromZ) * progress
                local currentHeight = proj.fromHeight + (proj.toHeight - proj.fromHeight) * progress
                local boltZ = currentZ + currentHeight

                local dirX = proj.toX - proj.fromX
                local dirY = proj.toY - proj.fromY
                local dirLen = math.sqrt(dirX * dirX + dirY * dirY)
                if dirLen > 0 then
                    dirX = dirX / dirLen
                    dirY = dirY / dirLen
                end

                local endX = cx + dirX * 0.18
                local endY = cy + dirY * 0.18

                VFX.renderLine(
                    cx, cy, boltZ,
                    endX, endY, boltZ,
                    proj.thickness * 1.6,
                    proj.color.R, proj.color.G, proj.color.B,
                    0.95
                )
            end
        end
    end
end

local function renderShinraTenseiShockwaves(nowMs)
    local pulseConsts = consts.Rinnegan and consts.Rinnegan.ShinraTensei or {
        VISUAL_DURATION_MS = 600,
        PULSE_SEGMENTS = 48,
        PULSE_THICKNESS = 2.2,
        PULSE_COLOR = { R = 0.9, G = 0.9, B = 1.0 },
    }

    local latitudeAngles = { -65, -45, -25, 0, 25, 45, 65 }
    local meridianAngles = { 0, 45, 90, 135 }

    for i = #activeShinraTenseiPulses, 1, -1 do
        local pulse = activeShinraTenseiPulses[i]
        local progress = (nowMs - pulse.startedAt) / pulseConsts.VISUAL_DURATION_MS
        if progress >= 1 then
            table.remove(activeShinraTenseiPulses, i)
        elseif progress >= 0 then
            local currentRadius = math.max(0.15, pulse.maxRadius * progress)
            local alpha = 0.85 * (1.0 - (progress * 0.35))
            local c = pulseConsts.PULSE_COLOR
            local centerZ = pulse.z + 0.18

            -- 1. Latitude Rings of the expanding sphere
            local ringPoints = {}
            for latIdx, deg in ipairs(latitudeAngles) do
                local radAngle = math.rad(deg)
                local cosP = math.cos(radAngle)
                local sinP = math.sin(radAngle)
                local ringRadius = math.max(0.05, currentRadius * cosP)
                local ringZ = centerZ + (sinP * currentRadius * 0.33)
                local ringAlpha = alpha * (0.6 + 0.4 * cosP)
                local thickness = deg == 0 and (pulseConsts.PULSE_THICKNESS * 1.3) or pulseConsts.PULSE_THICKNESS

                renderIsoCircle(
                    pulse.x, pulse.y, ringZ,
                    ringRadius,
                    pulseConsts.PULSE_SEGMENTS or 36,
                    thickness,
                    c.R, c.G, c.B,
                    ringAlpha
                )

                ringPoints[latIdx] = { radius = ringRadius, z = ringZ }
            end

            -- 2. Meridian Ribs connecting latitude tiers across the sphere
            local ribAlpha = alpha * 0.7
            for _, mDeg in ipairs(meridianAngles) do
                local mRad = math.rad(mDeg)
                local cosM = math.cos(mRad)
                local sinM = math.sin(mRad)

                for latIdx = 1, #ringPoints - 1 do
                    local p1 = ringPoints[latIdx]
                    local p2 = ringPoints[latIdx + 1]

                    -- Positive hemisphere rib
                    renderIsoLine(
                        pulse.x + (cosM * p1.radius), pulse.y + (sinM * p1.radius), p1.z,
                        pulse.x + (cosM * p2.radius), pulse.y + (sinM * p2.radius), p2.z,
                        pulseConsts.PULSE_THICKNESS,
                        c.R, c.G, c.B,
                        ribAlpha
                    )

                    -- Negative hemisphere rib
                    renderIsoLine(
                        pulse.x - (cosM * p1.radius), pulse.y - (sinM * p1.radius), p1.z,
                        pulse.x - (cosM * p2.radius), pulse.y - (sinM * p2.radius), p2.z,
                        pulseConsts.PULSE_THICKNESS,
                        c.R, c.G, c.B,
                        ribAlpha
                    )
                end
            end
        end
    end
end

local function renderGenjutsuCircles(nowMs)
    local bodConsts = consts.GenJutsu and consts.GenJutsu.BringerOfDarkness or {}
    for i = #activeBringerOfDarknessCircles, 1, -1 do
        local circle = activeBringerOfDarknessCircles[i]
        local elapsed = nowMs - circle.startedAtMs
        local maxDur = bodConsts.VISUAL_DURATION_MS or 1200
        local holdDur = bodConsts.VISUAL_HOLD_MS or 600
        if elapsed >= maxDur then
            table.remove(activeBringerOfDarknessCircles, i)
        elseif elapsed >= 0 then
            local alpha = bodConsts.CIRCLE_ALPHA or 0.85
            if elapsed > holdDur then
                alpha = alpha * math.max(0, 1 - ((elapsed - holdDur) / (maxDur - holdDur)))
            end
            local color = bodConsts.CIRCLE_COLOR or { R = 0.15, G = 0.15, B = 0.15 }
            VFX.renderRing(circle.x, circle.y, circle.z, circle.radius, bodConsts.CIRCLE_SEGMENTS or 48, bodConsts.CIRCLE_THICKNESS or 2.0, color.R, color.G, color.B, alpha, 0.05)
        end
    end

    local dfConsts = consts.GenJutsu and consts.GenJutsu.DemonicFlute or {}
    for i = #activeDemonicFluteCircles, 1, -1 do
        local circle = activeDemonicFluteCircles[i]
        local elapsed = nowMs - circle.startedAtMs
        local maxDur = dfConsts.VISUAL_DURATION_MS or 1300
        local holdDur = dfConsts.VISUAL_HOLD_MS or 650
        if elapsed >= maxDur then
            table.remove(activeDemonicFluteCircles, i)
        elseif elapsed >= 0 then
            local alpha = dfConsts.CIRCLE_ALPHA or 0.85
            if elapsed > holdDur then
                alpha = alpha * math.max(0, 1 - ((elapsed - holdDur) / (maxDur - holdDur)))
            end
            local color = dfConsts.CIRCLE_COLOR or { R = 0.75, G = 0.25, B = 0.80 }
            VFX.renderRing(circle.x, circle.y, circle.z, circle.radius, dfConsts.CIRCLE_SEGMENTS or 48, dfConsts.CIRCLE_THICKNESS or 2.0, color.R, color.G, color.B, alpha, 0.05)
        end
    end

    for i = #activeToadSlams, 1, -1 do
        local slam = activeToadSlams[i]
        local elapsed = nowMs - slam.startedAtMs
        if elapsed >= 700 then
            table.remove(activeToadSlams, i)
        else
            local progress = elapsed / 700
            local radius = slam.radius * progress
            local alpha = 0.8 * (1.0 - progress)
            VFX.renderRing(slam.x, slam.y, slam.z, radius, 32, 2.5, 0.85, 0.45, 0.1, alpha, 0.05)
        end
    end

    for i = #activeKatsuyuHealWaves, 1, -1 do
        local wave = activeKatsuyuHealWaves[i]
        local elapsed = nowMs - wave.startedAtMs
        if elapsed >= 1000 then
            table.remove(activeKatsuyuHealWaves, i)
        else
            local progress = elapsed / 1000
            local radius = wave.radius * progress
            local alpha = 0.85 * (1.0 - progress)
            VFX.renderRing(wave.x, wave.y, wave.z, radius, 36, 2.0, 0.2, 0.9, 0.7, alpha, 0.1)
        end
    end
end

local function renderSageModeAuras()
    local players = {}
    if IsoPlayer and IsoPlayer.getPlayers then
        local pList = IsoPlayer.getPlayers()
        if pList then
            for i = 0, pList:size() - 1 do
                local p = pList:get(i)
                if p and not p:isDead() then
                    table.insert(players, p)
                end
            end
        end
    end

    if #players == 0 then
        local localPlayer = getPlayer and getPlayer()
        if localPlayer and not localPlayer:isDead() then
            table.insert(players, localPlayer)
        end
    end

    for _, player in ipairs(players) do
        local data = NinjaLineages.getNLData(player)
        if data and data.sageModeActive then
            local chosen = NinjaLineages.Progression.getChosenContract(player)
            local r, g, b = 1.0, 0.55, 0.1 -- Toad orange
            if chosen == "snake" then
                r, g, b = 0.75, 0.2, 0.95 -- Snake purple
            elseif chosen == "snail" then
                r, g, b = 0.1, 0.85, 0.95 -- Snail cyan
            end
            VFX.renderAura(player, r, g, b, 0.85, 0.85)
        end
    end
end

function VFX.renderAll()
    local nowMs = NinjaLineages.Utils.Time.realMilliseconds()
    renderStaticBeams(nowMs)
    renderTravelingProjectiles(nowMs)
    renderKatonStreams(nowMs)
    renderShinraTenseiShockwaves(nowMs)
    renderGenjutsuCircles(nowMs)
    renderSageModeAuras()
end

-- ============================================================================
-- Central OnPostRender & Event Registration
-- ============================================================================

NinjaLineages.addEventOnce("client.vfx.onPostRender", Events.OnPostRender, VFX.renderAll)

if Events and Events.OnServerCommand then
    require "NinjaLineages_AbilityAuthority"

    NinjaLineages.AbilityAuthority.registerEventHandler("chakra_needle_line", function(args)
        if args.startGameMinutes then
            VFX.addProjectile(args)
        else
            VFX.addLine(args)
        end
    end)

    NinjaLineages.AbilityAuthority.registerEventHandler("projectile_resolved", function(args)
        VFX.resolveProjectile(args)
    end)

    NinjaLineages.AbilityAuthority.registerEventHandler("nervous_system_shock_projectiles", function(args)
        if not args or not args.projectiles then return end
        for _, projectile in pairs(args.projectiles) do
            if projectile.startGameMinutes then
                VFX.addProjectile(projectile)
            else
                VFX.addLine(projectile)
            end
        end
    end)

    NinjaLineages.AbilityAuthority.registerEventHandler("shinra_tensei_pulse", function(args)
        if args and args.x and args.y and args.z then
            VFX.addShinraTenseiPulse(args.x, args.y, args.z)
        end
    end)

    NinjaLineages.AbilityAuthority.registerEventHandler("katon_stream_started", function(args)
        VFX.addKatonStream(args)
    end)

    NinjaLineages.AbilityAuthority.registerEventHandler("bringer_of_darkness_circle", function(args)
        VFX.addBringerOfDarknessCircle(args)
    end)

    NinjaLineages.AbilityAuthority.registerEventHandler("demonic_flute_circle", function(args)
        VFX.addDemonicFluteCircle(args)
    end)

    NinjaLineages.AbilityAuthority.registerEventHandler("toad_slam", function(args)
        if args and args.x and args.y and args.z then
            VFX.addToadSlam(args.x, args.y, args.z, args.radius)
        end
    end)

    NinjaLineages.AbilityAuthority.registerEventHandler("katsuyu_heal_wave", function(args)
        if args and args.x and args.y and args.z then
            VFX.addKatsuyuHealWave(args.x, args.y, args.z, args.radius)
        end
    end)
end
