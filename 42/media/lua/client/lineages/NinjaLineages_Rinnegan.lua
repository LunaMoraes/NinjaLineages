require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "NinjaLineages_Balance"
require "NinjaLineages_RinneganMechanics"
require "NinjaLineages_AbilityAuthority"

NinjaLineages = NinjaLineages or {}
NinjaLineages.Rinnegan = NinjaLineages.Rinnegan or {}

local consts = NinjaLineages.Constants
local mechanics = NinjaLineages.RinneganMechanics
local pulses = {}

local function addPulse(x, y, z)
    table.insert(pulses, {
        x = x,
        y = y,
        z = z,
        startedAt = NinjaLineages.Utils.Time.realMilliseconds(),
    })
end
NinjaLineages.Rinnegan.addPulse = addPulse

local function sayCastError(player, reason, remaining)
    if reason == "lineage" then
        player:Say(getText("UI_NL_Error_LineageRequired", "Rinnegan"))
    elseif reason == "cooldown" then
        player:Say(getText(
            "UI_NL_Error_AbilityOnCooldown",
            getText("UI_NL_Ability_ShinraTensei_Name"),
            tostring(remaining)
        ))
    elseif reason == "chakra" then
        player:Say(getText("UI_NL_Error_NotEnoughChakra_ShinraTensei"))
    end
end

local function renderPulses()
    local now = NinjaLineages.Utils.Time.realMilliseconds()
    local pulseConsts = consts.Rinnegan.ShinraTensei

    for i = #pulses, 1, -1 do
        local pulse = pulses[i]
        local progress = (now - pulse.startedAt) / pulseConsts.VISUAL_DURATION_MS
        if progress >= 1 then
            table.remove(pulses, i)
        elseif progress >= 0 then
            local radius = math.max(0.1, mechanics.getRadius() * progress)
            local alpha = 0.8 * (1.0 - (progress * 0.35))
            renderIsoCircle(
                pulse.x,
                pulse.y,
                pulse.z,
                radius,
                pulseConsts.PULSE_SEGMENTS,
                pulseConsts.PULSE_THICKNESS,
                pulseConsts.PULSE_COLOR.R,
                pulseConsts.PULSE_COLOR.G,
                pulseConsts.PULSE_COLOR.B,
                alpha
            )
        end
    end
end

NinjaLineages.registerPlayerUpdate("rinnegan.shinraTenseiPush", function()
    if not (isClient and isClient()) then
        mechanics.update()
    end
end)

Events.OnPostRender.Add(renderPulses)
