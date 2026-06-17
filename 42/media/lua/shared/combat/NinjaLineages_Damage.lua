require "NinjaLineages_Utils"
require "combat/NinjaLineages_Targeting"

NinjaLineages = NinjaLineages or {}
NinjaLineages.Damage = NinjaLineages.Damage or {}

local function notifyDamagePresentation(caster, target, damage)
    if not caster or not target or not triggerEvent then return end
    pcall(function() triggerEvent("OnWeaponHitCharacter", caster, target, nil, damage or 0) end)
end

function NinjaLineages.Damage.applyZombieDamage(caster, zombie, damage)
    if not zombie or zombie:isDead() then return end
    if NinjaLineages.isClient() then
        return false
    end

    pcall(function() zombie:setAttackedBy(caster) end)
    local ok, health = pcall(function() return zombie:getHealth() end)
    if ok and health then
        local newHealth = math.max(0, health - damage)
        notifyDamagePresentation(caster, zombie, damage)
        pcall(function() zombie:setHealth(newHealth) end)
        if newHealth <= 0 then
            pcall(function() zombie:Kill(caster) end)
        end
    end
end

function NinjaLineages.Damage.applyPlayerDamage(caster, targetPlayer, payload)
    if not NinjaLineages.Targeting.isHostilePlayer(caster, targetPlayer) then return false end
    return false
end

function NinjaLineages.Damage.applyBarrierDamage(caster, barrier, payload)
    return false
end

function NinjaLineages.Damage.applyControlToTarget(caster, target, controlTier)
    if not target or not target.kind then return end

    if target.kind == "zombie" then
        NinjaLineages.Utils.Combat.applyControlTier(target.object, controlTier)
    elseif target.kind == "player" then
    end
end

function NinjaLineages.Damage.applyTargetDamage(caster, target, payload)
    if not target or not target.kind then return false end

    if target.kind == "zombie" then
        if not target.object then return false end
        if target.object:isDead() then return false end
        NinjaLineages.Damage.applyZombieDamage(caster, target.object, payload.damage or 0)
        return true
    elseif target.kind == "player" then
        return NinjaLineages.Damage.applyPlayerDamage(caster, target.object, payload)
    elseif target.kind == "barrier" then
        return NinjaLineages.Damage.applyBarrierDamage(caster, target.object, payload)
    end

    return false
end

function NinjaLineages.Damage.applyTargetDamageAndControl(caster, target, payload)
    NinjaLineages.Damage.applyTargetDamage(caster, target, payload)
    if payload and payload.controlTier then
        NinjaLineages.Damage.applyControlToTarget(caster, target, payload.controlTier)
    end
end
