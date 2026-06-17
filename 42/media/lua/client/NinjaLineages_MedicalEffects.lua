NinjaLineages = NinjaLineages or {}
NinjaLineages.MedicalEffects = NinjaLineages.MedicalEffects or {}

local activeLines = {}
local activeProjectiles = {}

local function addLineInternal(fromX, fromY, fromZ, toX, toY, toZ, color, thickness, durationMs)
    table.insert(activeLines, {
        fromX = fromX,
        fromY = fromY,
        fromZ = fromZ,
        toX = toX,
        toY = toY,
        toZ = toZ,
        color = color,
        thickness = thickness,
        startedAt = NinjaLineages.Utils.Time.realMilliseconds(),
        durationMs = durationMs,
    })
end

function NinjaLineages.MedicalEffects.addLine(args)
    if not args then return end
    local consts = NinjaLineages.Constants.Medical.ChakraNeedle
    addLineInternal(
        args.fromX, args.fromY, args.fromZ,
        args.toX, args.toY, args.toZ,
        consts.COLOR,
        consts.THICKNESS,
        consts.VISUAL_DURATION_MS
    )
end

function NinjaLineages.MedicalEffects.addLines(args)
    if not args or not args.lines then return end
    local consts = NinjaLineages.Constants.Medical.NervousSystemShock
    for _, line in ipairs(args.lines) do
        addLineInternal(
            args.fromX, args.fromY, args.fromZ,
            line.toX, line.toY, line.toZ,
            consts.COLOR,
            consts.THICKNESS,
            consts.VISUAL_DURATION_MS
        )
    end
end

function NinjaLineages.MedicalEffects.addProjectile(args)
    if not args then return end
    local consts = NinjaLineages.Constants.Medical.ChakraNeedle
    local dx = args.toX - args.fromX
    local dy = args.toY - args.fromY
    local dz = args.toZ - args.fromZ
    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
    table.insert(activeProjectiles, {
        fromX = args.fromX,
        fromY = args.fromY,
        fromZ = args.fromZ,
        toX = args.toX,
        toY = args.toY,
        toZ = args.toZ,
        speed = args.speed or 20,
        startGameMinutes = args.startGameMinutes,
        distance = distance,
        color = consts.COLOR,
        thickness = consts.THICKNESS,
    })
end

local function renderEffects()
    local nowMs = NinjaLineages.Utils.Time.realMilliseconds()
    local nowGameMinutes = NinjaLineages.Utils.Time.gameMinutes()

    for i = #activeLines, 1, -1 do
        local line = activeLines[i]
        local progress = (nowMs - line.startedAt) / line.durationMs
        if progress >= 1 then
            table.remove(activeLines, i)
        else
            local alpha = 0.8 * (1.0 - progress)
            renderIsoLine(
                line.fromX, line.fromY, line.fromZ,
                line.toX, line.toY, line.toZ,
                line.thickness,
                line.color.R, line.color.G, line.color.B,
                alpha
            )
        end
    end

    for i = #activeProjectiles, 1, -1 do
        local proj = activeProjectiles[i]
        local elapsed = nowGameMinutes - proj.startGameMinutes
        local totalTime = proj.distance / proj.speed
        local progress = totalTime > 0 and (elapsed / totalTime) or 1

        if progress >= 1 then
            table.remove(activeProjectiles, i)
        else
            local cx = proj.fromX + (proj.toX - proj.fromX) * progress
            local cy = proj.fromY + (proj.toY - proj.fromY) * progress
            local cz = proj.fromZ + (proj.toZ - proj.fromZ) * progress

            local dirX = proj.toX - proj.fromX
            local dirY = proj.toY - proj.fromY
            local dirLen = math.sqrt(dirX * dirX + dirY * dirY)
            if dirLen > 0 then
                dirX = dirX / dirLen
                dirY = dirY / dirLen
            end

            local endX = cx + dirX * 0.15
            local endY = cy + dirY * 0.15

            renderIsoLine(
                cx, cy, cz,
                endX, endY, cz,
                proj.thickness * 1.5,
                proj.color.R, proj.color.G, proj.color.B,
                0.95
            )
        end
    end
end

NinjaLineages.addEventOnce("client.medicalEffects.onPostRender", Events.OnPostRender, renderEffects)
