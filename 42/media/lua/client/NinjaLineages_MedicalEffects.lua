NinjaLineages = NinjaLineages or {}
NinjaLineages.MedicalEffects = NinjaLineages.MedicalEffects or {}

local activeLines = {}

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

local function renderLines()
    local now = NinjaLineages.Utils.Time.realMilliseconds()
    for i = #activeLines, 1, -1 do
        local line = activeLines[i]
        local progress = (now - line.startedAt) / line.durationMs
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
end

Events.OnPostRender.Add(renderLines)
