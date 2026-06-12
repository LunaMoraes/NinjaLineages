require "NinjaLineages_Chakra"
require "NinjaLineages_Skills"
require "NinjaLineages_Utils"
require "NinjaLineages_Balance"
require "NinjaLineages_Progression"
require "NinjaLineages_HandSigns"

NinjaLineages = NinjaLineages or {}
NinjaLineages.TreeAbilities = NinjaLineages.TreeAbilities or {}

local TreeAbilities = NinjaLineages.TreeAbilities
local Balance = NinjaLineages.Balance

local function cooldownKey(id)
    return "tree." .. id
end

local function canUse(player, id, costTier, showFeedback, targetingTier)
    if not NinjaLineages.Progression.isCompleted(player, id) then
        if showFeedback then player:Say(getText("UI_NL_Error_JutsuNotLearned")) end
        return false
    end
    if not NinjaLineages.Chakra.canAffordChakra(player, Balance.getCost(costTier)) then
        if showFeedback then player:Say(getText("UI_NL_Error_NotEnoughChakra")) end
        return false
    end
    local onCooldown, remaining = NinjaLineages.Cooldowns.isOnCooldown(player, cooldownKey(id))
    if onCooldown then
        if showFeedback then
            player:Say(getText("UI_NL_Error_AbilityOnCooldown", getText("UI_NL_Node_" .. id .. "_Name"), tostring(remaining)))
        end
        return false
    end
    if targetingTier and not NinjaLineages.Utils.Zombies.getFacingTarget(player, targetingTier) then
        if showFeedback then player:Say(getText("UI_NL_Error_NoFacingTarget")) end
        return false
    end
    return true
end

local function commit(player, id, costTier, cooldownTier)
    if not NinjaLineages.Chakra.spendChakra(player, Balance.getCost(costTier)) then return false end
    NinjaLineages.Cooldowns.set(player, cooldownKey(id), Balance.getCooldown(cooldownTier))
    return true
end

local function projectedPoint(player, distance)
    local forward = player:getForwardDirection()
    if not forward then return player:getX(), player:getY() end
    return player:getX() + forward:getX() * distance,
        player:getY() + forward:getY() * distance
end

local function castFalseSound(player)
    local config = Balance.getJutsu("FALSE_SOUND")
    local radius = Balance.getRadius(config.radius)
    if not commit(player, "false_sound", "BASIC", "SHORT") then return false end
    local x, y = projectedPoint(player, radius)
    NinjaLineages.Utils.Combat.addWorldSound(player, x, y, player:getZ(), radius, radius)
    return true
end

local function castVeilPresence(player)
    local config = Balance.getJutsu("VEIL_PRESENCE")
    if not commit(player, "veil_presence", "STANDARD", "LONG") then return false end
    local data = NinjaLineages.getNLData(player)
    local duration = Balance.getDuration(config.duration)
    local square = player:getSquare()
    if square and (not square:isOutside()) then
        duration = duration + Balance.getDuration("STANDARD_MS")
    end
    data.veilPresenceEndTime = NinjaLineages.Utils.Time.nowGameMs(player) + duration
    local radius = Balance.getRadius(config.radius)
    local x, y = projectedPoint(player, radius)
    NinjaLineages.Utils.Combat.addWorldSound(player, x, y, player:getZ(), radius, radius)
    return true
end

local function castKillingIntent(player)
    local config = Balance.getJutsu("KILLING_INTENT")
    if not commit(player, "killing_intent", "MAJOR", "VERY_LONG") then return false end
    for _, entry in ipairs(NinjaLineages.Utils.Zombies.collectInRadius(player, Balance.getRadius(config.radius))) do
        NinjaLineages.Utils.Combat.applyControlTier(entry.zombie, config.control)
    end
    return true
end

local function castTargetDamage(player, id, jutsuKey, costTier, cooldownTier)
    local config = Balance.getJutsu(jutsuKey)
    local target = NinjaLineages.Utils.Zombies.getFacingTarget(player, config.targeting)
    if not target then return false end
    if not commit(player, id, costTier, cooldownTier) then return false end
    NinjaLineages.Utils.Combat.applyZombieDamage(player, target, Balance.rollDamage(config.damage))
    NinjaLineages.Utils.Combat.applyControlTier(target, config.control)
    return true
end

local function castPressurePointPulse(player)
    local config = Balance.getJutsu("PRESSURE_POINT_PULSE")
    local primary = NinjaLineages.Utils.Zombies.getFacingTarget(player, config.targeting)
    if not primary then return false end
    if not commit(player, "pressure_point_pulse", "ADVANCED", "LONG") then return false end
    local targeting = Balance.getTargeting(config.targeting)
    local count = 0
    for _, entry in ipairs(NinjaLineages.Utils.Zombies.collectInRadius(primary, targeting.clusterRadius)) do
        if count >= targeting.maxTargets then break end
        NinjaLineages.Utils.Combat.applyZombieDamage(player, entry.zombie, Balance.rollDamage(config.damage))
        NinjaLineages.Utils.Combat.applyControlTier(entry.zombie, config.control)
        count = count + 1
    end
    return true
end

local function castShadowClose(player)
    local config = Balance.getJutsu("SHADOW_CLOSE")
    local target = NinjaLineages.Utils.Zombies.getFacingTarget(player, config.targeting)
    if not target then return false end
    if not commit(player, "shadow_close", "MAJOR", "VERY_LONG") then return false end

    local originX, originY = player:getX(), player:getY()
    local dx, dy = target:getX() - originX, target:getY() - originY
    local length = math.sqrt((dx * dx) + (dy * dy))
    local distance = math.min(length, Balance.getRadius(config.distance))
    if length > 0 then
        local nextX = originX + (dx / length) * distance
        local nextY = originY + (dy / length) * distance
        local square = getCell():getGridSquare(nextX, nextY, player:getZ())
        if square and player:getCurrentSquare() and not square:isBlockedTo(player:getCurrentSquare()) then
            player:setX(nextX)
            player:setY(nextY)
        end
    end
    local radius = Balance.getRadius(config.decoyRadius)
    NinjaLineages.Utils.Combat.addWorldSound(player, originX, originY, player:getZ(), radius, radius)
    NinjaLineages.Utils.Combat.applyControlTier(target, "GENIN")
    return true
end

local function reduceStat(player, stat, amount)
    local stats = player:getStats()
    stats:set(stat, math.max(0, stats:get(stat) - amount))
end

local function castCellStimulation(player)
    local config = Balance.getJutsu("CELL_STIMULATION")
    if not commit(player, "cell_stimulation", "STANDARD", "LONG") then return false end
    local healing = Balance.getHealing(config.healing)
    reduceStat(player, CharacterStat.FATIGUE, healing.fatigue)
    local bodyDamage = player:getBodyDamage()
    local parts = bodyDamage and bodyDamage:getBodyParts()
    if parts then
        for i = 0, parts:size() - 1 do
            local part = parts:get(i)
            pcall(function()
                part:setAdditionalPain(math.max(0, part:getAdditionalPain() - healing.pain))
            end)
        end
    end
    return true
end

local function mostDamagedPart(player)
    local bodyDamage = player:getBodyDamage()
    local parts = bodyDamage and bodyDamage:getBodyParts()
    local result, severity = nil, 0
    if not parts then return nil end
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        local value = NinjaLineages.Utils.Healing.getPartSeverity(part)
        if value > severity then result, severity = part, value end
    end
    return result
end

local function applyChakraBandage(player, bodyPart, healing)
    if not bodyPart then return end
    player:getBodyDamage():SetBandaged(
        bodyPart:getIndex(),
        true,
        healing.wound,
        true,
        "Base.NL_ChakraBandage"
    )
    if syncBodyPart then pcall(function() syncBodyPart(bodyPart, 0xc001966b8e) end) end
end

local function castFieldSurgery(player)
    if not commit(player, "field_surgery", "MAJOR", "VERY_LONG") then return false end
    local healing = Balance.getHealing(Balance.getJutsu("FIELD_SURGERY").healing)
    local part = mostDamagedPart(player)
    if not part then return false end
    local bodyDamage = player:getBodyDamage()
    local changed = NinjaLineages.Utils.Healing.healPart(bodyDamage, part, {
        health = healing.health,
        bleeding = healing.wound,
        scratch = healing.wound,
        cut = healing.wound,
        deepWound = healing.wound,
        burn = healing.wound,
        fracture = healing.wound,
    })
    pcall(function() part:setHaveGlass(false) end)
    pcall(function() part:setHaveBullet(false, 0) end)
    if changed then applyChakraBandage(player, part, healing) end
    return changed
end

local function castBleedingSuppression(player)
    if not commit(player, "bleeding_suppression", "MAJOR", "VERY_LONG") then return false end
    local healing = Balance.getHealing(Balance.getJutsu("BLEEDING_SUPPRESSION").healing)
    local bodyDamage = player:getBodyDamage()
    local parts = bodyDamage and bodyDamage:getBodyParts()
    local changed = false
    if parts then
        for i = 0, parts:size() - 1 do
            local part = parts:get(i)
            local bleeding = 0
            pcall(function() bleeding = part:getBleedingTime() end)
            if bleeding > 0 then
                pcall(function() part:setBleedingTime(math.max(0, bleeding - healing.wound)) end)
                pcall(function() part:setBleeding(false) end)
                applyChakraBandage(player, part, healing)
                changed = true
            end
        end
    end
    if changed then
        local data = NinjaLineages.getNLData(player)
        data.bleedingSuppressionEndTime = NinjaLineages.Utils.Time.nowGameMs(player)
            + Balance.getDuration(Balance.getJutsu("BLEEDING_SUPPRESSION").duration)
    end
    return changed
end

local function updateEffects(player)
    local data = NinjaLineages.getNLData(player)
    local now = NinjaLineages.Utils.Time.nowGameMs(player)
    if data.veilPresenceEndTime and now < data.veilPresenceEndTime then
        if not player:hasTrait(CharacterTrait.GRACEFUL) then
            player:getCharacterTraits():add(CharacterTrait.GRACEFUL)
            data.veilAddedGraceful = true
        end
        if not player:hasTrait(CharacterTrait.INCONSPICUOUS) then
            player:getCharacterTraits():add(CharacterTrait.INCONSPICUOUS)
            data.veilAddedInconspicuous = true
        end
    elseif data.veilPresenceEndTime then
        if data.veilAddedGraceful then player:getCharacterTraits():remove(CharacterTrait.GRACEFUL) end
        if data.veilAddedInconspicuous then player:getCharacterTraits():remove(CharacterTrait.INCONSPICUOUS) end
        data.veilPresenceEndTime = nil
        data.veilAddedGraceful = nil
        data.veilAddedInconspicuous = nil
    end

    if data.bleedingSuppressionEndTime and now < data.bleedingSuppressionEndTime then
        local parts = player:getBodyDamage():getBodyParts()
        for i = 0, parts:size() - 1 do
            local part = parts:get(i)
            pcall(function()
                if part:getBleedingTime() > 0 then
                    part:setBleedingTime(0)
                    part:setBleeding(false)
                end
            end)
        end
    else
        data.bleedingSuppressionEndTime = nil
    end
end

local function register(definition)
    NinjaLineages.registerAbility(definition)
end

register({
    id = "false_sound", lineage = "common", nodeId = "false_sound",
    name = "UI_NL_Node_false_sound_Name", descriptionKey = "UI_NL_Node_false_sound_Desc",
    texture = "media/ui/jutsuTree/nodes/false_sound.png", costTier = "BASIC",
    cooldownTier = "SHORT", handSigns = { "rat", "hare", "snake" },
    preCast = function(player, feedback) return canUse(player, "false_sound", "BASIC", feedback) end,
    action = castFalseSound,
})

register({
    id = "veil_presence", lineage = "common", nodeId = "veil_presence",
    name = "UI_NL_Node_veil_presence_Name", descriptionKey = "UI_NL_Node_veil_presence_Desc",
    texture = "media/ui/jutsuTree/nodes/veil_presence.png", costTier = "STANDARD",
    cooldownTier = "LONG", handSigns = { "snake", "rat", "tiger" },
    preCast = function(player, feedback) return canUse(player, "veil_presence", "STANDARD", feedback) end,
    action = castVeilPresence,
})

register({
    id = "killing_intent", lineage = "common", nodeId = "killing_intent",
    name = "UI_NL_Node_killing_intent_Name", descriptionKey = "UI_NL_Node_killing_intent_Desc",
    texture = "media/ui/jutsuTree/nodes/killing_intent.png", costTier = "MAJOR",
    cooldownTier = "VERY_LONG", handSigns = { "tiger", "dragon", "tiger" },
    preCast = function(player, feedback) return canUse(player, "killing_intent", "MAJOR", feedback) end,
    action = castKillingIntent,
})

register({
    id = "chakra_burst", lineage = "common", nodeId = "chakra_burst",
    name = "UI_NL_Node_chakra_burst_Name", descriptionKey = "UI_NL_Node_chakra_burst_Desc",
    texture = "media/ui/jutsuTree/nodes/chakra_burst.png", costTier = "ADVANCED",
    cooldownTier = "LONG", handSigns = { "ox", "tiger", "ram" },
    preCast = function(player, feedback)
        return canUse(player, "chakra_burst", "ADVANCED", feedback, Balance.getJutsu("CHAKRA_BURST").targeting)
    end,
    action = function(player) return castTargetDamage(player, "chakra_burst", "CHAKRA_BURST", "ADVANCED", "LONG") end,
})

register({
    id = "pressure_point_pulse", lineage = "common", nodeId = "pressure_point_pulse",
    name = "UI_NL_Node_pressure_point_pulse_Name", descriptionKey = "UI_NL_Node_pressure_point_pulse_Desc",
    texture = "media/ui/jutsuTree/nodes/pressure_point_pulse.png", costTier = "ADVANCED",
    cooldownTier = "LONG", handSigns = { "ram", "ox", "snake" },
    preCast = function(player, feedback)
        return canUse(player, "pressure_point_pulse", "ADVANCED", feedback, Balance.getJutsu("PRESSURE_POINT_PULSE").targeting)
    end,
    action = castPressurePointPulse,
})

register({
    id = "shadow_close", lineage = "common", nodeId = "shadow_close",
    name = "UI_NL_Node_shadow_close_Name", descriptionKey = "UI_NL_Node_shadow_close_Desc",
    texture = "media/ui/jutsuTree/nodes/shadow_close.png", costTier = "MAJOR",
    cooldownTier = "VERY_LONG", handSigns = { "bird", "rat", "tiger" },
    preCast = function(player, feedback)
        return canUse(player, "shadow_close", "MAJOR", feedback, Balance.getJutsu("SHADOW_CLOSE").targeting)
    end,
    action = castShadowClose,
})

register({
    id = "chakra_needle", lineage = "common", nodeId = "chakra_needle",
    name = "UI_NL_Node_chakra_needle_Name", descriptionKey = "UI_NL_Node_chakra_needle_Desc",
    texture = "media/ui/jutsuTree/nodes/chakra_needle.png", costTier = "STANDARD",
    cooldownTier = "SHORT", handSigns = { "snake", "ram", "bird" },
    preCast = function(player, feedback)
        return canUse(player, "chakra_needle", "STANDARD", feedback, Balance.getJutsu("CHAKRA_NEEDLE").targeting)
    end,
    action = function(player) return castTargetDamage(player, "chakra_needle", "CHAKRA_NEEDLE", "STANDARD", "SHORT") end,
})

register({
    id = "cell_stimulation", lineage = "common", nodeId = "cell_stimulation",
    name = "UI_NL_Node_cell_stimulation_Name", descriptionKey = "UI_NL_Node_cell_stimulation_Desc",
    texture = "media/ui/jutsuTree/nodes/cell_stimulation.png", costTier = "STANDARD",
    cooldownTier = "LONG", handSigns = { "boar", "ram", "tiger" },
    preCast = function(player, feedback) return canUse(player, "cell_stimulation", "STANDARD", feedback) end,
    action = castCellStimulation,
})

register({
    id = "nervous_system_shock", lineage = "common", nodeId = "nervous_system_shock",
    name = "UI_NL_Node_nervous_system_shock_Name", descriptionKey = "UI_NL_Node_nervous_system_shock_Desc",
    texture = "media/ui/jutsuTree/nodes/nervous_system_shock.png", costTier = "ADVANCED",
    cooldownTier = "LONG", handSigns = { "snake", "dragon", "ram" },
    preCast = function(player, feedback)
        return canUse(player, "nervous_system_shock", "ADVANCED", feedback, Balance.getJutsu("NERVOUS_SYSTEM_SHOCK").targeting)
    end,
    action = function(player)
        return castTargetDamage(player, "nervous_system_shock", "NERVOUS_SYSTEM_SHOCK", "ADVANCED", "LONG")
    end,
})

register({
    id = "field_surgery", lineage = "common", nodeId = "field_surgery",
    name = "UI_NL_Node_field_surgery_Name", descriptionKey = "UI_NL_Node_field_surgery_Desc",
    texture = "media/ui/jutsuTree/nodes/field_surgery.png", costTier = "MAJOR",
    cooldownTier = "VERY_LONG", handSigns = { "boar", "snake", "ram" },
    preCast = function(player, feedback) return canUse(player, "field_surgery", "MAJOR", feedback) end,
    action = castFieldSurgery,
})

register({
    id = "bleeding_suppression", lineage = "common", nodeId = "bleeding_suppression",
    name = "UI_NL_Node_bleeding_suppression_Name", descriptionKey = "UI_NL_Node_bleeding_suppression_Desc",
    texture = "media/ui/jutsuTree/nodes/bleeding_suppression.png", costTier = "MAJOR",
    cooldownTier = "VERY_LONG", handSigns = { "ram", "boar", "dragon" },
    preCast = function(player, feedback) return canUse(player, "bleeding_suppression", "MAJOR", feedback) end,
    action = castBleedingSuppression,
})

NinjaLineages.registerPlayerUpdate("treeAbilities.update", updateEffects)
