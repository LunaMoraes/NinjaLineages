require "NinjaLineages_Utils"
require "combat/NinjaLineages_Targeting"

NinjaLineages = NinjaLineages or {}
NinjaLineages.Damage = NinjaLineages.Damage or {}

local LOG_PREFIX = "[DEBUG-NL-PVP-DAMAGE] "

local function debugLog(message)
    if SandboxVars
            and SandboxVars.NinjaLineages
            and SandboxVars.NinjaLineages.DebugMode == true then
        print(LOG_PREFIX .. message)
    end
end

local function safeRead(fn, fallback)
    local ok, value = pcall(fn)
    if ok then return value end
    return fallback
end

local function syncPart(bodyPart, mask)
    if not bodyPart or not syncBodyPart then return false end
    local ok = pcall(function()
        syncBodyPart(bodyPart, mask or 0xFFFFFFFFFFF)
    end)
    return ok == true
end

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
    if NinjaLineages.isClient() and not NinjaLineages.isServer() then
        return false, { reason = "client_not_authoritative" }
    end

    local eligible, reason = NinjaLineages.Targeting.canDamagePlayer(caster, targetPlayer)
    if not eligible then
        debugLog("REJECTED reason=" .. tostring(reason))
        return false, { reason = reason }
    end

    -- Check Sharingan PvP dodge (server-authoritative jutsu dodge)
    local targetData = NinjaLineages.getNLData(targetPlayer)
    if NinjaLineages.hasSharingan(targetPlayer) and targetData.eyePowerActive then
        local stage = NinjaLineages.getSharinganStage(targetPlayer)
        local chance = NinjaLineages.Constants.Uchiha.SharinganDodgeChance[stage] or 0
        local active = NinjaLineages.AbilityExecution and NinjaLineages.AbilityExecution.active or {}
        local kamuiActive = active[targetPlayer] and active[targetPlayer].kamuiUntil
        local dodged = kamuiActive or ZombRand(1, 101) <= chance
        if dodged then
            sendServerCommand("NinjaLineages", "abilityEvent", {
                kind = "sharingan_evade",
                casterOnlineId = targetPlayer:getOnlineID(),
            })
            debugLog("DODGED_PVP_JUTSU target=" .. tostring(targetPlayer:getUsername()))
            return false, { reason = "dodged" }
        end
    end

    local damage = math.max(0, tonumber(payload and payload.damage) or 0)
    local bodyDamage = targetPlayer:getBodyDamage()
    local parts = bodyDamage and bodyDamage:getBodyParts()
    if damage <= 0 or not parts or parts:size() <= 0 then
        return false, { reason = "invalid_damage" }
    end

    -- Re-check immediately before the authoritative mutation.
    eligible, reason = NinjaLineages.Targeting.canDamagePlayer(caster, targetPlayer)
    if not eligible then
        debugLog("REJECTED_LATE reason=" .. tostring(reason))
        return false, { reason = reason }
    end

    local partIndex = ZombRand(parts:size())
    local bodyPart = parts:get(partIndex)
    local healthBefore = safeRead(function() return bodyPart:getHealth() end, nil)
    local applied = pcall(function() bodyPart:AddDamage(damage) end)
    if not applied then return false, { reason = "body_part_damage_failed" } end

    pcall(function() targetPlayer:setAttackedBy(caster) end)
    pcall(function() bodyDamage:calculateOverallHealth() end)
    local syncMask = BodyPartSyncPacket and BodyPartSyncPacket.BD_Health or 0x1
    local synced = syncPart(bodyPart, syncMask)
    local healthAfter = safeRead(function() return bodyPart:getHealth() end, nil)
    notifyDamagePresentation(caster, targetPlayer, damage)

    local result = {
        bodyPartIndex = partIndex,
        bodyPartType = safeRead(function() return tostring(bodyPart:getType()) end, "unknown"),
        damage = damage,
        healthBefore = healthBefore,
        healthAfter = healthAfter,
        synced = synced,
    }
    debugLog(string.format(
        "APPLIED caster=%s target=%s part=%s index=%d damage=%.3f before=%s after=%s synced=%s",
        tostring(safeRead(function() return caster:getUsername() end, "unknown")),
        tostring(safeRead(function() return targetPlayer:getUsername() end, "unknown")),
        tostring(result.bodyPartType),
        partIndex,
        damage,
        tostring(healthBefore),
        tostring(healthAfter),
        tostring(synced)
    ))
    return true, result
end

function NinjaLineages.Damage.applyBarrierDamage(caster, barrier, payload)
    if not barrier or not barrier.Damage then return false, 0 end
    local structuralDamage = math.max(0, tonumber(payload and payload.damage) or 0) * 100
    if structuralDamage <= 0 then return false, 0 end
    local ok = pcall(function() barrier:Damage(structuralDamage) end)
    return ok, structuralDamage
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
    local applied, result = NinjaLineages.Damage.applyTargetDamage(caster, target, payload)
    if applied and payload and payload.controlTier then
        NinjaLineages.Damage.applyControlToTarget(caster, target, payload.controlTier)
    end
    return applied, result
end
