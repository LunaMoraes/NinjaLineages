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
        startedAt = NinjaLineages.Utils.Time.nowMs(),
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
    local now = NinjaLineages.Utils.Time.nowMs()
    local pulseConsts = consts.Rinnegan.ShinraTensei

    for i = #pulses, 1, -1 do
        local pulse = pulses[i]
        local progress = (now - pulse.startedAt) / pulseConsts.PULSE_DURATION_MS
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

local function finishLocalCast(player)
    addPulse(player:getX(), player:getY(), math.floor(player:getZ()))
    pcall(function()
        player:playerVoiceSound(consts.Rinnegan.ShinraTensei.ACTIVATION_VOICE)
    end)
    player:Say(getText("UI_NL_Ability_ShinraTensei_Cast"))
end

local function useShinraTensei(player)
    return NinjaLineages.AbilityAuthority.request(player, "shinra_tensei", {})
end

NinjaLineages.registerAbility({
    id = "shinra_tensei",
    lineage = "rinnegan",
    name = "UI_NL_Ability_ShinraTensei_Name",
    descriptionKey = "UI_NL_Ability_ShinraTensei_Desc",
    texture = "media/ui/Traits/trait_rinnegan.png",
    condition = function(player) return NinjaLineages.hasRinnegan(player) end,
    costTier = "MAJOR",
    cooldownTier = "STANDARD",
    radiusTier = "STANDARD",
    damageTier = "HEAVY",
    action = useShinraTensei
})

NinjaLineages.registerPlayerUpdate("rinnegan.shinraTenseiPush", function()
    if not (isClient and isClient()) then
        mechanics.update()
    end
end)

Events.OnPostRender.Add(renderPulses)
