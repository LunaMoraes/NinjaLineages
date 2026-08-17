require "NinjaLineages_Progression"
require "NinjaLineages_Balance"
require "NinjaLineages_Utils"

NinjaLineages = NinjaLineages or {}
NinjaLineages.NinjaTools = NinjaLineages.NinjaTools or {}

local NinjaTools = NinjaLineages.NinjaTools

local TOOL_AMMO_MAP = {
    ["Base.NL_KunaiShooter"] = "Base.NL_KunaiAmmo",
    ["Base.NL_ShurikenShooter"] = "Base.NL_ShurikenAmmo",
}

function NinjaTools.onWeaponHit(attacker, target, weapon, damage)
    if not attacker or not target or not weapon then return end
    if not instanceof(attacker, "IsoPlayer") then return end

    local fullType = weapon:getFullType()
    local ammoType = TOOL_AMMO_MAP[fullType]
    if not ammoType then return end

    -- Maintenance skill recovery scaling: up to 80% at level 10 (never 100%)
    local maintLevel = attacker:getPerkLevel(Perks.Maintenance) or 0
    local tuning = NinjaLineages.Balance.NinjaTools
    local recoveryChance = (maintLevel / tuning.MAINTENANCE_LEVEL_CAP)
        * tuning.MAXIMUM_RECOVERY_CHANCE
    local roll = ZombRand(1, 101)

    if roll <= math.floor(recoveryChance * 100 + 0.5) then
        local inv = target.getInventory and target:getInventory()
        if inv then
            inv:AddItem(ammoType)
            attacker:getXp():AddXP(Perks.Maintenance, tuning.MAINTENANCE_XP)
        end
    end
end

if Events and Events.OnWeaponHitCharacter then
    NinjaLineages.addEventOnce(
        "shared.ninjaTools.onWeaponHitCharacter",
        Events.OnWeaponHitCharacter,
        function(attacker, target, weapon, damage)
            NinjaTools.onWeaponHit(attacker, target, weapon, damage)
        end
    )
end
