require "NinjaLineages_Constants"
require "NinjaLineages_Utils"
require "NinjaLineages_Progression"
require "NinjaLineages_Balance"
require "jinchuuriki/NinjaLineages_BijuuRenderer"

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
    local nowGameMinutes = NinjaLineages.Utils.Time.gameMinutes()

    -- 1. Very tight, subtle ground contact wisp at character feet
    local groundPulse = 0.18 + 0.08 * math.sin(nowGameMinutes * 80.0)
    VFX.renderRing(x, y, z, 0.28, 20, 1.8, r, g, b, (baseAlpha or 0.8) * groundPulse, 0.01)

    -- 2. Delicate chakra sparks/wisps drifting upward from feet to head
    local sparkCount = 7
    local cycleDuration = 0.05
    for idx = 1, sparkCount do
        local phaseOffset = (idx * (cycleDuration / sparkCount))
        local sparkTime = (nowGameMinutes + phaseOffset) % cycleDuration
        local progress = sparkTime / cycleDuration

        local sparkZ = z + 0.02 + (progress * 0.26)
        local baseAngle = (idx * (math.pi * 2 / sparkCount)) + (nowGameMinutes * 35.0)
        local radiusOffset = 0.22 + 0.06 * math.sin((nowGameMinutes * 90.0) + idx)
        local sparkX = x + math.cos(baseAngle) * radiusOffset
        local sparkY = y + math.sin(baseAngle) * radiusOffset

        local sparkAlpha = math.sin(progress * math.pi) * ((baseAlpha or 0.8) * 0.75)
        if sparkAlpha > 0.05 then
            renderIsoLine(
                sparkX, sparkY, sparkZ,
                sparkX, sparkY, sparkZ + 0.04,
                1.5,
                r, g, b,
                sparkAlpha
            )
        end
    end
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
local activeGenericPulses = {}
local activeSummonMarkers = {}
local activeSummonPoofs = {}
local activeToadSlams = {}
local activeSnakeStrikes = {}
local activeKatsuyuHealWaves = {}
local activeRasengans = {}
local activeRasenganWallImpacts = {}
local activeSnareTethers = {}

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
        startedAtGameMinutes = args.startedAtGameMinutes or NinjaLineages.Utils.Time.gameMinutes(),
        durationGameMinutes = args.durationGameMinutes or constsMedical.VISUAL_DURATION_GAME_MINUTES or 0.03,
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
        or ("proj_" .. tostring(NinjaLineages.Utils.Time.gameMinutes()))

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
    proj.resolvedAtGameMinutes = NinjaLineages.Utils.Time.gameMinutes()
end

function VFX.addKatonStream(args)
    if not args then return end
    local streamId = args.streamId or tostring(NinjaLineages.Utils.Time.gameMinutes())
    activeKatonStreams[streamId] = {
        streamId = streamId,
        originX = args.originX,
        originY = args.originY,
        originZ = args.originZ,
        directionX = args.directionX,
        directionY = args.directionY,
        range = args.range,
        minDot = args.minDot,
        durationGameMinutes = args.durationGameMinutes or (args.durationMs and (args.durationMs / 15000)) or 0.05,
        startedAtGameMinutes = args.startedAtGameMinutes or NinjaLineages.Utils.Time.gameMinutes(),
    }
end

function VFX.addBringerOfDarknessCircle(args)
    if not args or not args.x or not args.y or not args.z or not args.radius then return end
    table.insert(activeBringerOfDarknessCircles, {
        x = args.x,
        y = args.y,
        z = args.z,
        radius = args.radius,
        startedAtGameMinutes = args.startedAtGameMinutes or NinjaLineages.Utils.Time.gameMinutes(),
    })
end

function VFX.addDemonicFluteCircle(args)
    if not args or not args.x or not args.y or not args.z or not args.radius then return end
    table.insert(activeDemonicFluteCircles, {
        x = args.x,
        y = args.y,
        z = args.z,
        radius = args.radius,
        startedAtGameMinutes = args.startedAtGameMinutes or NinjaLineages.Utils.Time.gameMinutes(),
    })
end

function VFX.addGenericPulse(args)
    if not args then return end
    local preset = (args.abilityId and consts.AbilityPulsePresets and consts.AbilityPulsePresets[args.abilityId]) or {}
    local color = args.color or preset.color or { R = 0.2, G = 0.8, B = 1.0 }
    local radius = args.radius or preset.radius or 1.5
    local thickness = args.thickness or preset.thickness or 2.5
    local duration = args.durationGameMinutes or preset.durationGameMinutes or 0.05

    table.insert(activeGenericPulses, {
        casterOnlineId = args.casterOnlineId,
        zombieOnlineId = args.zombieOnlineId,
        zombie = args.zombie,
        x = args.x or 0,
        y = args.y or 0,
        z = args.z or 0,
        radius = radius,
        thickness = thickness,
        duration = duration,
        color = color,
        startedAtGameMinutes = args.startedAtGameMinutes or NinjaLineages.Utils.Time.gameMinutes(),
    })
end

function VFX.addSnareTether(args)
    if not args or not args.runtimeId then return end
    activeSnareTethers[args.runtimeId] = {
        runtimeId = args.runtimeId,
        zombie = args.zombie,
        zombieId = args.zombieId,
        targetPlayer = args.targetPlayer,
        targetOnlineId = args.targetOnlineId,
        startedAtGameMinutes = args.startedAtGameMinutes or NinjaLineages.Utils.Time.gameMinutes(),
        durationGameMinutes = args.durationGameMinutes or (NinjaLineages.Balance and NinjaLineages.Balance.getDuration("BURST")) or 0.015,
    }
end

function VFX.removeSnareTether(runtimeId)
    if runtimeId then
        activeSnareTethers[runtimeId] = nil
    end
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
        startGameMinutes = NinjaLineages.Utils.Time.gameMinutes(),
    })
end

function VFX.addSummonMarker(args)
    if not args or not args.animalId then return end
    activeSummonMarkers[args.animalId] = {
        animalId = args.animalId,
        contract = args.contract or "toad",
        x = args.x or 0,
        y = args.y or 0,
        z = args.z or 0,
        startedAtGameMinutes = args.startedAtGameMinutes or NinjaLineages.Utils.Time.gameMinutes(),
    }
end

function VFX.removeSummonMarker(args)
    local id = type(args) == "table" and args.animalId or args
    if id then
        activeSummonMarkers[id] = nil
    end
    if type(args) == "table" and args.x and args.y and args.z then
        VFX.addSummonPoof(args)
    end
end

function VFX.addSummonPoof(args)
    if not args or not args.x or not args.y or not args.z then return end
    table.insert(activeSummonPoofs, {
        x = args.x,
        y = args.y,
        z = args.z,
        contract = args.contract,
        startedAtGameMinutes = args.startedAtGameMinutes or NinjaLineages.Utils.Time.gameMinutes(),
    })
end

function VFX.addToadSlam(args, maybeY, maybeZ, maybeRadius)
    local x = type(args) == "table" and args.x or args
    local y = type(args) == "table" and args.y or maybeY
    local z = type(args) == "table" and args.z or maybeZ
    local radius = type(args) == "table" and args.radius or maybeRadius
    local started = type(args) == "table" and args.startedAtGameMinutes or NinjaLineages.Utils.Time.gameMinutes()

    if x and y and z then
        table.insert(activeToadSlams, {
            x = x,
            y = y,
            z = z,
            radius = radius or 3.5,
            startedAtGameMinutes = started,
        })
    end
end

function VFX.addSnakeStrike(args)
    if not args or not args.originX or not args.targetX then return end
    table.insert(activeSnakeStrikes, {
        originX = args.originX,
        originY = args.originY,
        targetX = args.targetX,
        targetY = args.targetY,
        z = args.z or 0,
        startedAtGameMinutes = args.startedAtGameMinutes or NinjaLineages.Utils.Time.gameMinutes(),
    })
end

function VFX.addKatsuyuHealWave(args, maybeY, maybeZ, maybeRadius)
    local x = type(args) == "table" and args.x or args
    local y = type(args) == "table" and args.y or maybeY
    local z = type(args) == "table" and args.z or maybeZ
    local radius = type(args) == "table" and args.radius or maybeRadius
    local started = type(args) == "table" and args.startedAtGameMinutes or NinjaLineages.Utils.Time.gameMinutes()

    if x and y and z then
        table.insert(activeKatsuyuHealWaves, {
            x = x,
            y = y,
            z = z,
            radius = radius or 6.0,
            startedAtGameMinutes = started,
        })
    end
end

function VFX.addRasengan(args)
    if not args or not args.runtimeId then return end
    activeRasengans[args.runtimeId] = {
        runtimeId = args.runtimeId,
        leadZombieOnlineId = args.leadZombieOnlineId,
        leadZombie = args.leadZombie or args.leadObject,
        dirX = args.dirX or 0,
        dirY = args.dirY or 1,
        startedAtGameMinutes = args.startedAtGameMinutes or NinjaLineages.Utils.Time.gameMinutes(),
        fading = false,
        fadeStartedGameMinutes = nil,
    }
end

function VFX.removeRasengan(runtimeId)
    local r = activeRasengans[runtimeId]
    if r then
        if not r.fading then
            r.fading = true
            r.fadeStartedGameMinutes = NinjaLineages.Utils.Time.gameMinutes()
        end
    end
end

function VFX.addRasenganWallImpact(args)
    if not args or not args.x or not args.y or not args.z then return end
    if args.runtimeId then
        activeRasengans[args.runtimeId] = nil
    end
    table.insert(activeRasenganWallImpacts, {
        x = args.x,
        y = args.y,
        z = args.z,
        startedAtGameMinutes = args.startedAtGameMinutes or NinjaLineages.Utils.Time.gameMinutes(),
    })
end

-- ============================================================================
-- Central Render Loop (Called once per frame on OnPostRender)
-- ============================================================================

local function renderKatonStreams(nowGameMinutes)
    local texture = resolveKatonTexture()
    local tileScale = Core and Core.getTileScale and Core.getTileScale() or 1

    for streamId, stream in pairs(activeKatonStreams) do
        local progress = (nowGameMinutes - stream.startedAtGameMinutes) / stream.durationGameMinutes
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
                            (nowGameMinutes * 6000 + distance * 190 + lateral * 130) * 0.025
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

local function renderStaticBeams(nowGameMinutes)
    for i = #activeLines, 1, -1 do
        local line = activeLines[i]
        local progress = (nowGameMinutes - line.startedAtGameMinutes) / line.durationGameMinutes
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

local function renderTravelingProjectiles(nowGameMinutes)
    for projectileId, proj in pairs(activeProjectiles) do
        if proj.resolvedAtGameMinutes then
            if nowGameMinutes - proj.resolvedAtGameMinutes >= 0.01 then
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

local function renderShinraTenseiShockwaves(nowGameMinutes)
    local pulseConsts = consts.Rinnegan and consts.Rinnegan.ShinraTensei or {
        PULSE_SEGMENTS = 48,
        PULSE_THICKNESS = 2.5,
        PULSE_COLOR = { R = 0.82, G = 0.88, B = 1.0 },
    }
    local duration = NinjaLineages.Balance.JutsuRuntime.ShinraTensei.PUSH_DURATION_MINUTES

    for i = #activeShinraTenseiPulses, 1, -1 do
        local pulse = activeShinraTenseiPulses[i]
        local progress = duration > 0 and math.min(1, math.max(0, (nowGameMinutes - pulse.startGameMinutes) / duration)) or 1
        if progress >= 1 then
            table.remove(activeShinraTenseiPulses, i)
        elseif progress >= 0 then
            local currentRadius = math.max(0.15, pulse.maxRadius * progress)
            local baseAlpha = 0.85 * (1.0 - (progress * 0.30))
            local c = pulseConsts.PULSE_COLOR
            local groundZ = pulse.z
            local rSq = currentRadius * currentRadius

            -- 1. Ultra-dense overlapping concentric bands filling every gap (strictly Z >= groundZ)
            local stepSize = 0.05
            local r = 0.04
            while r <= currentRadius do
                local h = math.sqrt(math.max(0, rSq - (r * r))) * 0.33
                local ringZ = groundZ + h
                local fillAlpha = baseAlpha * 0.22

                renderIsoCircle(
                    pulse.x, pulse.y, ringZ,
                    r,
                    32,
                    5.5,
                    c.R, c.G, c.B,
                    fillAlpha
                )
                r = r + stepSize
            end

            -- 2. Ground perimeter base ring (locked to floor plane)
            renderIsoCircle(
                pulse.x, pulse.y, groundZ,
                currentRadius,
                pulseConsts.PULSE_SEGMENTS or 48,
                3.2,
                c.R, c.G, c.B,
                baseAlpha * 0.90
            )

            -- 3. Outer boundary rim at mid-dome elevation
            local midH = currentRadius * 0.165
            local midR = math.sqrt(math.max(0, rSq - ((midH / 0.33) * (midH / 0.33))))
            renderIsoCircle(
                pulse.x, pulse.y, groundZ + midH,
                midR,
                pulseConsts.PULSE_SEGMENTS or 48,
                2.5,
                c.R, c.G, c.B,
                baseAlpha * 0.70
            )

            -- 4. Apex crown ring at the top of the dome
            local topH = currentRadius * 0.30
            local topR = math.max(0.1, math.sqrt(math.max(0, rSq - ((topH / 0.33) * (topH / 0.33)))))
            renderIsoCircle(
                pulse.x, pulse.y, groundZ + topH,
                topR,
                32,
                2.2,
                c.R, c.G, c.B,
                baseAlpha * 0.65
            )

            -- 5. Meridian surface energy ribs connecting ground to apex
            local meridianAngles = { 0, 45, 90, 135 }
            local ribAlpha = baseAlpha * 0.50
            for _, mDeg in ipairs(meridianAngles) do
                local mRad = math.rad(mDeg)
                local cosM = math.cos(mRad)
                local sinM = math.sin(mRad)

                local sampleStep = math.max(0.15, currentRadius / 10)
                local sR = 0
                while sR + sampleStep <= currentRadius do
                    local r1 = sR
                    local r2 = sR + sampleStep
                    local h1 = math.sqrt(math.max(0, rSq - (r1 * r1))) * 0.33
                    local h2 = math.sqrt(math.max(0, rSq - (r2 * r2))) * 0.33

                    -- Positive side rib
                    renderIsoLine(
                        pulse.x + (cosM * r1), pulse.y + (sinM * r1), groundZ + h1,
                        pulse.x + (cosM * r2), pulse.y + (sinM * r2), groundZ + h2,
                        2.0,
                        c.R, c.G, c.B,
                        ribAlpha
                    )

                    -- Negative side rib
                    renderIsoLine(
                        pulse.x - (cosM * r1), pulse.y - (sinM * r1), groundZ + h1,
                        pulse.x - (cosM * r2), pulse.y - (sinM * r2), groundZ + h2,
                        2.0,
                        c.R, c.G, c.B,
                        ribAlpha
                    )

                    sR = sR + sampleStep
                end
            end
        end
    end
end

local function renderGenjutsuCircles(nowGameMinutes)
    local bodConsts = consts.GenJutsu and consts.GenJutsu.BringerOfDarkness or {}
    for i = #activeBringerOfDarknessCircles, 1, -1 do
        local circle = activeBringerOfDarknessCircles[i]
        local elapsed = nowGameMinutes - circle.startedAtGameMinutes
        local maxDur = bodConsts.VISUAL_DURATION_GAME_MINUTES or 0.06
        local holdDur = bodConsts.VISUAL_HOLD_GAME_MINUTES or 0.035
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
        local elapsed = nowGameMinutes - circle.startedAtGameMinutes
        local maxDur = dfConsts.VISUAL_DURATION_GAME_MINUTES or 0.06
        local holdDur = dfConsts.VISUAL_HOLD_GAME_MINUTES or 0.035
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
end

local function renderGenericAbilityPulses(nowGameMinutes)
    for i = #activeGenericPulses, 1, -1 do
        local pulse = activeGenericPulses[i]
        local progress = pulse.duration > 0 and ((nowGameMinutes - pulse.startedAtGameMinutes) / pulse.duration) or 1
        if progress >= 1 then
            table.remove(activeGenericPulses, i)
        elseif progress >= 0 then
            local caster = (pulse.casterOnlineId and getPlayerByOnlineID and getPlayerByOnlineID(pulse.casterOnlineId))
                or (pulse.zombieOnlineId and NinjaLineages.Utils.Zombies.getByOnlineID(pulse.zombieOnlineId))
                or (pulse.zombie and not (pulse.zombie.isDead and pulse.zombie:isDead()) and pulse.zombie)
            local x = caster and caster:getX() or pulse.x
            local y = caster and caster:getY() or pulse.y
            local z = caster and caster:getZ() or pulse.z

            local currentRadius = math.max(0.15, pulse.radius * (0.25 + 0.75 * progress))
            local baseAlpha = 0.85 * (1.0 - progress)
            local c = pulse.color

            -- 1. Outer expanding primary chakra ring
            renderIsoCircle(
                x, y, z + 0.02,
                currentRadius,
                36,
                pulse.thickness,
                c.R, c.G, c.B,
                baseAlpha
            )

            -- 2. Concentric inner echo ring (trailing at 60% radius)
            local innerRadius = currentRadius * 0.60
            renderIsoCircle(
                x, y, z + 0.02,
                innerRadius,
                28,
                pulse.thickness * 0.8,
                c.R, c.G, c.B,
                baseAlpha * 0.65
            )

            -- 3. 4 vertical rising chakra wisps
            local wispCount = 4
            local wispHeight = 0.28 * progress
            local wispRadius = currentRadius * 0.85
            for idx = 1, wispCount do
                local angle = (idx * (math.pi * 2 / wispCount)) + (nowGameMinutes * 40.0)
                local wx = x + math.cos(angle) * wispRadius
                local wy = y + math.sin(angle) * wispRadius
                local wz = z + 0.02 + (wispHeight * 0.5)

                renderIsoLine(
                    wx, wy, wz,
                    wx, wy, wz + 0.08,
                    pulse.thickness * 0.75,
                    c.R, c.G, c.B,
                    baseAlpha * 0.75
                )
            end
        end
    end
end

local function renderSnareTethers(nowGameMinutes)
    local medConsts = consts.Medical and consts.Medical.ChakraNeedle or {}
    local color = medConsts.COLOR or { R = 0.25, G = 0.55, B = 1.0 }
    local thickness = medConsts.THICKNESS or 2.0

    for runtimeId, tether in pairs(activeSnareTethers) do
        local elapsed = nowGameMinutes - tether.startedAtGameMinutes
        if elapsed >= tether.durationGameMinutes or elapsed < 0 then
            activeSnareTethers[runtimeId] = nil
        else
            local zombie = (tether.zombie and not (tether.zombie.isDead and tether.zombie:isDead()) and tether.zombie)
                or (tether.zombieId and NinjaLineages.Utils.Zombies.getByOnlineID(tether.zombieId))
            local player = (tether.targetPlayer and not (tether.targetPlayer.isDead and tether.targetPlayer:isDead()) and tether.targetPlayer)
                or (tether.targetOnlineId and getPlayerByOnlineID and getPlayerByOnlineID(tether.targetOnlineId))

            if not zombie or not player or (player.isDead and player:isDead()) or (zombie.isDead and zombie:isDead()) then
                activeSnareTethers[runtimeId] = nil
            else
                local zx, zy, zz = VFX.getCharacterAnchor(zombie, "chest")
                local px, py, pz = VFX.getCharacterAnchor(player, "chest")
                local alpha = 0.85 * (1.0 - (elapsed / tether.durationGameMinutes) * 0.25)

                VFX.renderLine(
                    zx, zy, zz,
                    px, py, pz,
                    thickness * 1.5,
                    color.R, color.G, color.B,
                    alpha
                )
            end
        end
    end
end

local function renderSummonMarkers(nowGameMinutes)
    local colDef = consts.Summoning and consts.Summoning.Colors or {}
    local vfxDef = consts.Summoning and consts.Summoning.VFX or {}

    for animalId, marker in pairs(activeSummonMarkers) do
        local host = NinjaLineages.Summoning and NinjaLineages.Summoning.getAnimal(marker.animalId)
        local x = host and host:getX() or marker.x
        local y = host and host:getY() or marker.y
        local z = host and host:getZ() or marker.z

        local color = colDef[marker.contract] or colDef.toad or { R = 1.0, G = 0.5, B = 0.1 }
        local rot = (nowGameMinutes - marker.startedAtGameMinutes) * 40.0
        local pulse = (vfxDef.MARKER_ALPHA_BASE or 0.65) + ((vfxDef.MARKER_ALPHA_PULSE or 0.25) * math.sin(nowGameMinutes * 30.0))

        -- Ground contact disk
        VFX.renderRing(x, y, z, 0.14, 20, 1.2, color.R, color.G, color.B, pulse * 0.35, 0.01)

        -- Inner seal ring
        local innerR = vfxDef.MARKER_INNER_RADIUS or 0.22
        VFX.renderRing(x, y, z, innerR, 28, 1.8, color.R, color.G, color.B, pulse * 0.80, 0.02)
    end
end

local function renderSummonPoofs(nowGameMinutes)
    local vfxDef = consts.Summoning and consts.Summoning.VFX or {}
    local dur = vfxDef.POOF_DURATION_GAME_MINUTES or 0.05

    for i = #activeSummonPoofs, 1, -1 do
        local poof = activeSummonPoofs[i]
        local elapsed = nowGameMinutes - poof.startedAtGameMinutes
        if elapsed >= dur then
            table.remove(activeSummonPoofs, i)
        elseif elapsed >= 0 then
            local progress = elapsed / dur
            local innerR = 0.2 + (0.8 * progress)
            local outerR = 0.4 + (1.2 * progress)
            local alpha = (1.0 - progress) ^ 1.5

            VFX.renderRing(poof.x, poof.y, poof.z, innerR, 28, 2.0, 0.92, 0.92, 0.95, alpha * 0.7, 0.03)
            VFX.renderRing(poof.x, poof.y, poof.z, outerR, 36, 2.5, 0.88, 0.88, 0.92, alpha * 0.9, 0.05)

            for s = 1, 8 do
                local a = s * (math.pi * 2 / 8)
                local x1 = poof.x + (math.cos(a) * (0.2 + (0.3 * progress)))
                local y1 = poof.y + (math.sin(a) * (0.2 + (0.3 * progress)))
                local x2 = poof.x + (math.cos(a) * (0.4 + (1.2 * progress)))
                local y2 = poof.y + (math.sin(a) * (0.4 + (1.2 * progress)))
                VFX.renderLine(x1, y1, poof.z + 0.05, x2, y2, poof.z + 0.05, 2.0, 0.95, 0.95, 1.0, alpha * 0.8)
            end
        end
    end
end

local function renderToadSlams(nowGameMinutes)
    local vfxDef = consts.Summoning and consts.Summoning.VFX or {}
    local dur = vfxDef.TOAD_SLAM_DURATION_GAME_MINUTES or 0.06

    for i = #activeToadSlams, 1, -1 do
        local slam = activeToadSlams[i]
        local elapsed = nowGameMinutes - slam.startedAtGameMinutes
        if elapsed >= dur then
            table.remove(activeToadSlams, i)
        elseif elapsed >= 0 then
            local progress = elapsed / dur
            local maxR = slam.radius or (vfxDef.TOAD_SLAM_MAX_RADIUS or 3.5)

            local r1 = maxR * progress
            local r2 = maxR * math.max(0, progress - 0.15)
            local r3 = maxR * math.max(0, progress - 0.30)
            local a1 = (1.0 - progress) * 0.9
            local a2 = (1.0 - progress) * 0.7
            local a3 = (1.0 - progress) * 0.5

            VFX.renderRing(slam.x, slam.y, slam.z, r1, 36, 3.0, 1.0, 0.50, 0.08, a1, 0.03)
            if r2 > 0 then VFX.renderRing(slam.x, slam.y, slam.z, r2, 32, 2.2, 1.0, 0.65, 0.15, a2, 0.02) end
            if r3 > 0 then VFX.renderRing(slam.x, slam.y, slam.z, r3, 28, 1.8, 1.0, 0.80, 0.25, a3, 0.01) end

            for c = 1, 6 do
                local a = (c * (math.pi * 2 / 6)) + 0.25
                local lx = slam.x + (math.cos(a) * (maxR * 0.8 * progress))
                local ly = slam.y + (math.sin(a) * (maxR * 0.8 * progress))
                VFX.renderLine(slam.x, slam.y, slam.z + 0.02, lx, ly, slam.z + 0.02, 2.5, 1.0, 0.45, 0.05, a1 * 0.85)
            end
        end
    end
end

local function renderSnakeStrikes(nowGameMinutes)
    local vfxDef = consts.Summoning and consts.Summoning.VFX or {}
    local dur = vfxDef.SNAKE_STRIKE_DURATION_GAME_MINUTES or 0.03

    for i = #activeSnakeStrikes, 1, -1 do
        local strike = activeSnakeStrikes[i]
        local elapsed = nowGameMinutes - strike.startedAtGameMinutes
        if elapsed >= dur then
            table.remove(activeSnakeStrikes, i)
        elseif elapsed >= 0 then
            local progress = elapsed / dur
            local alpha = 1.0 - progress

            -- Double-tracer purple beam
            VFX.renderLine(strike.originX, strike.originY, strike.z + 0.15, strike.targetX, strike.targetY, strike.z + 0.15, vfxDef.SNAKE_STRIKE_THICKNESS or 4.0, 0.68, 0.15, 0.90, alpha * 0.85)
            VFX.renderLine(strike.originX, strike.originY, strike.z + 0.15, strike.targetX, strike.targetY, strike.z + 0.15, 1.8, 0.92, 0.80, 1.0, alpha)

            -- Puncture cross flare
            local crossSize = 0.35 * (1.0 - progress)
            local fa = alpha * 0.9
            VFX.renderLine(strike.targetX - crossSize, strike.targetY, strike.z + 0.15, strike.targetX + crossSize, strike.targetY, strike.z + 0.15, 2.5, 0.85, 0.3, 1.0, fa)
            VFX.renderLine(strike.targetX, strike.targetY - crossSize, strike.z + 0.15, strike.targetX, strike.targetY + crossSize, strike.z + 0.15, 2.5, 0.85, 0.3, 1.0, fa)
        end
    end
end

local function renderKatsuyuHealWaves(nowGameMinutes)
    local vfxDef = consts.Summoning and consts.Summoning.VFX or {}
    local dur = vfxDef.KATSUYU_WAVE_DURATION_GAME_MINUTES or 0.08

    for i = #activeKatsuyuHealWaves, 1, -1 do
        local wave = activeKatsuyuHealWaves[i]
        local elapsed = nowGameMinutes - wave.startedAtGameMinutes
        if elapsed >= dur then
            table.remove(activeKatsuyuHealWaves, i)
        elseif elapsed >= 0 then
            local progress = elapsed / dur
            local maxR = wave.radius or (vfxDef.KATSUYU_WAVE_MAX_RADIUS or 6.0)
            local alpha = (1.0 - progress) ^ 1.2

            local r1 = maxR * progress
            local r2 = maxR * math.max(0, progress - 0.20)

            VFX.renderRing(wave.x, wave.y, wave.z, r1, 48, 2.5, 0.15, 0.90, 0.95, alpha * 0.90, 0.05)
            if r2 > 0 then
                VFX.renderRing(wave.x, wave.y, wave.z, r2, 36, 2.0, 0.35, 0.75, 1.0, alpha * 0.70, 0.03)
            end
        end
    end
end

local function renderRasengans(nowGameMinutes)
    local rConsts = consts.Rasengan or {}
    local toRemove = {}

    for runtimeId, rasengan in pairs(activeRasengans) do
        local lead = (rasengan.leadZombie and not (rasengan.leadZombie.isDead and rasengan.leadZombie:isDead()) and rasengan.leadZombie)
            or (rasengan.leadZombieOnlineId and NinjaLineages.Utils.Zombies.getByOnlineID(rasengan.leadZombieOnlineId))
        local baseAlpha = 1.0
        local scale = 1.0

        if rasengan.fading then
            local fadeDur = rConsts.RASENGAN_FADEOUT_DURATION_GAME_MINUTES or 0.04
            local fadeProg = (nowGameMinutes - (rasengan.fadeStartedGameMinutes or nowGameMinutes)) / fadeDur
            if fadeProg >= 1.0 then
                table.insert(toRemove, runtimeId)
            else
                baseAlpha = 1.0 - fadeProg
                scale = 1.0 - (fadeProg * 0.6)
            end
        elseif not lead or (lead.isDead and lead:isDead()) then
            table.insert(toRemove, runtimeId)
        end

        if baseAlpha > 0.01 and lead then
            local lx = lead:getX()
            local ly = lead:getY()
            local lz = lead:getZ()
            local sx = lx + (rasengan.dirX * 0.40)
            local sy = ly + (rasengan.dirY * 0.40)
            local sz = lz + VFX.ANCHOR_CHEST

            -- Concentric dense luminous white-blue core micro-rings
            local coreColor = rConsts.CoreColor or { R = 0.90, G = 0.96, B = 1.0 }
            VFX.renderRing(sx, sy, sz, 0.08 * scale, 16, 2.0, coreColor.R, coreColor.G, coreColor.B, baseAlpha * 0.95, 0)
            VFX.renderRing(sx, sy, sz, 0.16 * scale, 24, 2.0, coreColor.R, coreColor.G, coreColor.B, baseAlpha * 0.85, 0)
            VFX.renderRing(sx, sy, sz, (rConsts.CORE_RADIUS or 0.25) * scale, 32, 2.2, coreColor.R, coreColor.G, coreColor.B, baseAlpha * 0.75, 0)

            -- Glowing blue containment shell
            local shellColor = rConsts.Color or { R = 0.15, G = 0.70, B = 1.0 }
            local shellR = (rConsts.SHELL_RADIUS or 0.40) * scale
            VFX.renderRing(sx, sy, sz, shellR, 40, 2.5, shellColor.R, shellColor.G, shellColor.B, baseAlpha * 0.85, 0)

            -- 4 rotating orbital swirl arcs
            local rot = (nowGameMinutes - rasengan.startedAtGameMinutes) * (rConsts.ROTATION_SPEED_RAD_PER_GAME_MINUTE or 50.0)
            local swirlR = (rConsts.SWIRL_RADIUS or 0.45) * scale
            local swirlThick = rConsts.SWIRL_THICKNESS or 2.0

            for i = 1, 4 do
                local aStart = rot + (i * (math.pi / 2))
                local aEnd = aStart + (math.pi * 0.45)
                local p1x = sx + (math.cos(aStart) * swirlR)
                local p1y = sy + (math.sin(aStart) * swirlR)
                local p2x = sx + (math.cos(aEnd) * (swirlR * 0.85))
                local p2y = sy + (math.sin(aEnd) * (swirlR * 0.85))
                VFX.renderLine(p1x, p1y, sz, p2x, p2y, sz, swirlThick, 0.40, 0.85, 1.0, baseAlpha * 0.85)
            end

            -- Grinding push stream connecting to lead torso
            if not rasengan.fading then
                VFX.renderLine(sx, sy, sz, lx, ly, sz, 2.0, 0.20, 0.75, 1.0, 0.50)
            end
        end
    end

    for _, id in ipairs(toRemove) do
        activeRasengans[id] = nil
    end
end

local function renderRasenganWallImpacts(nowGameMinutes)
    local rConsts = consts.Rasengan or {}
    local dur = rConsts.WALL_BURST_DURATION_GAME_MINUTES or 0.05
    local maxR = rConsts.WALL_BURST_MAX_RADIUS or 3.0

    for i = #activeRasenganWallImpacts, 1, -1 do
        local impact = activeRasenganWallImpacts[i]
        local elapsed = nowGameMinutes - impact.startedAtGameMinutes
        if elapsed >= dur then
            table.remove(activeRasenganWallImpacts, i)
        elseif elapsed >= 0 then
            local progress = elapsed / dur

            -- 4 expanding cyan-white shockwave rings
            for rIdx = 1, 4 do
                local offset = (rIdx - 1) * 0.12
                local ringProg = math.max(0, math.min(1.0, (progress - offset) / (1.0 - offset)))
                if ringProg > 0 then
                    local r = 0.2 + (maxR * ringProg)
                    local a = ((1.0 - ringProg) ^ 2.0) * 0.95
                    VFX.renderRing(impact.x, impact.y, impact.z, r, 40, 3.0, 0.25, 0.80, 1.0, a, 0.05)
                end
            end

            -- 12 radial explosive fracture shard lines
            for s = 1, 12 do
                local a = s * (math.pi * 2 / 12)
                local d1 = 0.2 + (maxR * 0.3 * progress)
                local d2 = 0.4 + (maxR * progress)
                local x1 = impact.x + (math.cos(a) * d1)
                local y1 = impact.y + (math.sin(a) * d1)
                local x2 = impact.x + (math.cos(a) * d2)
                local y2 = impact.y + (math.sin(a) * d2)
                local sa = (1.0 - progress) * 0.90
                VFX.renderLine(x1, y1, impact.z + 0.1, x2, y2, impact.z + 0.1, 2.5, 0.90, 0.96, 1.0, sa)
            end
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
    local nowGameMinutes = NinjaLineages.Utils.Time.gameMinutes()

    renderStaticBeams(nowGameMinutes)
    renderTravelingProjectiles(nowGameMinutes)
    renderKatonStreams(nowGameMinutes)
    renderShinraTenseiShockwaves(nowGameMinutes)
    renderGenjutsuCircles(nowGameMinutes)
    renderGenericAbilityPulses(nowGameMinutes)
    renderSnareTethers(nowGameMinutes)

    -- Summoning & Companion Renderers (game-time driven)
    renderSummonMarkers(nowGameMinutes)
    renderSummonPoofs(nowGameMinutes)
    renderToadSlams(nowGameMinutes)
    renderSnakeStrikes(nowGameMinutes)
    renderKatsuyuHealWaves(nowGameMinutes)

    -- Rasengan Renderers (game-time driven)
    renderRasengans(nowGameMinutes)
    renderRasenganWallImpacts(nowGameMinutes)

    -- Bijū Giant Boss Shell Renderers (game-time driven)
    if NinjaLineages.BijuuRenderer and NinjaLineages.BijuuRenderer.renderAll then
        NinjaLineages.BijuuRenderer.renderAll(nowGameMinutes)
    end

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

    NinjaLineages.AbilityAuthority.registerEventHandler("generic_ability_pulse", function(args)
        if args then
            VFX.addGenericPulse(args)
        end
    end)

    NinjaLineages.AbilityAuthority.registerEventHandler("summon_spawn", function(args)
        if args and args.animalId then
            VFX.addSummonMarker(args)
            VFX.addSummonPoof(args)
        end
    end)

    NinjaLineages.AbilityAuthority.registerEventHandler("summon_poof", function(args)
        if args then
            VFX.removeSummonMarker(args)
        end
    end)

    NinjaLineages.AbilityAuthority.registerEventHandler("toad_slam", function(args)
        if args then
            VFX.addToadSlam(args)
        end
    end)

    NinjaLineages.AbilityAuthority.registerEventHandler("snake_strike", function(args)
        if args then
            VFX.addSnakeStrike(args)
        end
    end)

    NinjaLineages.AbilityAuthority.registerEventHandler("katsuyu_heal_wave", function(args)
        if args then
            VFX.addKatsuyuHealWave(args)
        end
    end)

    NinjaLineages.AbilityAuthority.registerEventHandler("rasengan_started", function(args)
        if args then
            VFX.addRasengan(args)
        end
    end)

    NinjaLineages.AbilityAuthority.registerEventHandler("rasengan_ended", function(args)
        if args and args.runtimeId then
            VFX.removeRasengan(args.runtimeId)
        end
    end)

    NinjaLineages.AbilityAuthority.registerEventHandler("rasengan_wall_impact", function(args)
        if args then
            VFX.addRasenganWallImpact(args)
        end
    end)
end
