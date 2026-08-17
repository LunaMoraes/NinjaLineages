require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "NinjaLineages_Balance"
require "NinjaLineages_Constants"
require "NinjaLineages_RinneganMechanics"
require "NinjaLineages_AbilityAuthority"
require "NinjaLineages_VFX"

NinjaLineages = NinjaLineages or {}
NinjaLineages.Rinnegan = NinjaLineages.Rinnegan or {}

local consts = NinjaLineages.Constants
local mechanics = NinjaLineages.RinneganMechanics
local VFX = NinjaLineages.VFX

function NinjaLineages.Rinnegan.addPulse(x, y, z)
    return VFX.addShinraTenseiPulse(x, y, z)
end

NinjaLineages.registerPlayerUpdate("rinnegan.shinraTenseiPush", function()
    mechanics.update()
end)

NinjaLineages.AbilityAuthority.registerEventHandler("shinra_tensei_pulse", function(args)
    if args and args.x and args.y and args.z then
        VFX.addShinraTenseiPulse(args.x, args.y, args.z)
    end
    local caster = nil
    if args and args.casterOnlineId and getPlayerByOnlineID then
        caster = getPlayerByOnlineID(args.casterOnlineId)
    end
    if not caster and args and args.casterOnlineId then
        caster = NinjaLineages.AbilityAuthority.findLocalPlayer(args.casterOnlineId)
    end
    if caster then
        pcall(function()
            caster:playerVoiceSound(consts.Rinnegan.ShinraTensei.ACTIVATION_VOICE)
        end)
    end
end)
