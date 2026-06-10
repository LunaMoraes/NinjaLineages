require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "NinjaLineages_Balance"

NinjaLineages = NinjaLineages or {}
NinjaLineages.Senju = {}

local consts = NinjaLineages.Constants

local senjuLastRecoveryAt = {}
local boundZombies = {}
local creationRebirthState = {}

local function applySenjuEndurance(player)
    if not player then return end

    local senjuTrait = NinjaLineages.getTraitObject(NinjaLineages.TRAIT_SENJU)
    if not senjuTrait then return end
    local data = NinjaLineages.getNLData(player)
    local fastHealer = NinjaLineages.getTraitObject("base:fasthealer")
    if not player:hasTrait(senjuTrait) then
        senjuLastRecoveryAt[player] = nil
        if data.senjuAddedFastHealer and fastHealer then
            pcall(function() player:getCharacterTraits():remove(fastHealer) end)
            data.senjuAddedFastHealer = nil
            NinjaLineages.transmitPlayerData(player)
        end
        return
    end

    if fastHealer and not player:hasTrait(fastHealer) then
        pcall(function() player:getCharacterTraits():add(fastHealer) end)
        data.senjuAddedFastHealer = true
        NinjaLineages.transmitPlayerData(player)
    end
end

local function applyBindingRootsToZombie(player, target)
    local zombie = target.zombie
    if not zombie or zombie:isDead() then return end

    local knockdownChance = target.distance <= consts.Senju.BindingRoots.INNER_RADIUS and consts.Senju.BindingRoots.INNER_KNOCKDOWN_CHANCE or consts.Senju.BindingRoots.OUTER_KNOCKDOWN_CHANCE
    local shouldKnockdown = ZombRand(1, 101) <= knockdownChance
    NinjaLineages.Utils.Combat.staggerZombie(zombie, { knockdown = shouldKnockdown, position = "FRONT", force = 2.0 })
    boundZombies[zombie] = NinjaLineages.Utils.Time.nowMs() + NinjaLineages.Balance.getDuration("BRIEF_MS")
end

local function useBindingRoots(player)
    if not NinjaLineages.hasSenju(player) then
        player:Say(getText("UI_NL_Error_LineageRequired", "Senju lineage"))
        return
    end

    local data = NinjaLineages.getNLData(player)
    local onCd, remaining = NinjaLineages.Cooldowns.isOnCooldown(player, "senju.binding_roots")
    if onCd then
        player:Say(getText("UI_NL_Error_AbilityOnCooldown", getText("UI_NL_Ability_BindingRoots_Name"), tostring(remaining)))
        return
    end

    local cost = NinjaLineages.Balance.getCost("MAJOR")
    if not NinjaLineages.Chakra.canAffordChakra(player, cost) then
        player:Say(getText("UI_NL_Error_NotEnoughChakra_BindingRoots"))
        return
    end

    NinjaLineages.Chakra.spendChakra(player, cost)
    local radius = NinjaLineages.Balance.getRadius("LARGE")
    for _, target in ipairs(NinjaLineages.Utils.Zombies.collectInRadius(player, radius)) do
        applyBindingRootsToZombie(player, target)
    end

    NinjaLineages.Cooldowns.set(player, "senju.binding_roots", NinjaLineages.Balance.getCooldown("STANDARD"))
    player:Say(getText("UI_NL_Ability_BindingRoots_Cast"))
end

-- Creation Rebirth
local function reducePartTimer(bodypart, getter, setter, amount)
    local ok, value = pcall(function()
        if getter == "getBleedingTime" then return bodypart:getBleedingTime() end
        if getter == "getScratchTime" then return bodypart:getScratchTime() end
        if getter == "getCutTime" then return bodypart:getCutTime() end
        if getter == "getDeepWoundTime" then return bodypart:getDeepWoundTime() end
        if getter == "getBurnTime" then return bodypart:getBurnTime() end
        if getter == "getFractureTime" then return bodypart:getFractureTime() end
        return 0
    end)
    if not ok or not value or value <= 0 then return false end
    local nextValue = math.max(0, value - amount)
    pcall(function()
        if setter == "setBleedingTime" then bodypart:setBleedingTime(nextValue) end
        if setter == "setScratchTime" then bodypart:setScratchTime(nextValue) end
        if setter == "setCutTime" then bodypart:setCutTime(nextValue) end
        if setter == "setDeepWoundTime" then bodypart:setDeepWoundTime(nextValue) end
        if setter == "setBurnTime" then bodypart:setBurnTime(nextValue) end
        if setter == "setFractureTime" then bodypart:setFractureTime(nextValue) end
    end)
    return nextValue < value
end

local function restoreBodyPartHealth(bodyDamage, bodypart, amount)
    local ok, health = pcall(function() return bodypart:getHealth() end)
    if ok and health and health < 100 then
        pcall(function() bodyDamage:AddGeneralHealth(amount) end)
        return true
    end
    return false
end

local function healBodyPartForCreationRebirth(bodyDamage, bodypart)
    if not bodypart then return false end
    local changed = false

    changed = reducePartTimer(bodypart, "getBleedingTime", "setBleedingTime", 4.0) or changed
    changed = reducePartTimer(bodypart, "getScratchTime", "setScratchTime", 4.0) or changed
    changed = reducePartTimer(bodypart, "getCutTime", "setCutTime", 4.0) or changed
    changed = reducePartTimer(bodypart, "getDeepWoundTime", "setDeepWoundTime", 3.0) or changed
    changed = reducePartTimer(bodypart, "getBurnTime", "setBurnTime", 2.0) or changed
    changed = reducePartTimer(bodypart, "getFractureTime", "setFractureTime", 1.0) or changed

    if changed then
        pcall(function()
            if bodypart:getBleedingTime() <= 0 then
                bodypart:setBleeding(false)
            end
        end)
    end

    changed = restoreBodyPartHealth(bodyDamage, bodypart, 3.0) or changed
    return changed
end

local function stopCreationRebirth(player)
    creationRebirthState[player] = nil
end

local function isBodyPartDamagedOrInjured(bodypart)
    if not bodypart then return false end

    local okHealth, health = pcall(function() return bodypart:getHealth() end)
    if okHealth and health and health < 100 then return true end

    local okBleed, bleed = pcall(function() return bodypart:getBleedingTime() end)
    if okBleed and bleed and bleed > 0 then return true end

    local okScratch, scratch = pcall(function() return bodypart:getScratchTime() end)
    if okScratch and scratch and scratch > 0 then return true end

    local okCut, cut = pcall(function() return bodypart:getCutTime() end)
    if okCut and cut and cut > 0 then return true end

    local okDeep, deep = pcall(function() return bodypart:getDeepWoundTime() end)
    if okDeep and deep and deep > 0 then return true end

    local okBurn, burn = pcall(function() return bodypart:getBurnTime() end)
    if okBurn and burn and burn > 0 then return true end

    local okFrac, frac = pcall(function() return bodypart:getFractureTime() end)
    if okFrac and frac and frac > 0 then return true end

    return false
end

local function updateCreationRebirth(player)
    local state = creationRebirthState[player]
    if not state then return end

    local nowMs = NinjaLineages.Utils.Time.nowMs()
    if nowMs >= state.endsAt then
        stopCreationRebirth(player)
        return
    end
    if nowMs < state.nextTickAt then return end
    state.nextTickAt = nowMs + consts.Senju.CreationRebirth.TICK_MS

    local stats = player:getStats()
    local bodyDamage = player:getBodyDamage()
    if not stats or not bodyDamage then
        stopCreationRebirth(player)
        return
    end

    local parts = bodyDamage:getBodyParts()
    if not parts then return end
    
    local costStep = NinjaLineages.Balance.getCostStep("HARSH")

    for i = 0, parts:size() - 1 do
        local bodypart = parts:get(i)
        if bodypart and isBodyPartDamagedOrInjured(bodypart) then
            if NinjaLineages.Chakra.getChakra(player) < costStep then
                stopCreationRebirth(player)
                return
            end

            local changed = healBodyPartForCreationRebirth(bodyDamage, bodypart)
            if changed then
                NinjaLineages.Chakra.spendChakra(player, costStep)
            end
        end
    end
end

local function useCreationRebirth(player)
    if not NinjaLineages.hasSenju(player) then
        player:Say(getText("UI_NL_Error_LineageRequired", "Senju lineage"))
        return
    end
    if NinjaLineages.Chakra.getChakra(player) <= 0 then
        player:Say(getText("UI_NL_Error_NotEnoughChakra_CreationRebirth"))
        return
    end
    local nowMs = NinjaLineages.Utils.Time.nowMs()
    creationRebirthState[player] = {
        endsAt = nowMs + NinjaLineages.Balance.getDuration("SHORT_MS"),
        nextTickAt = nowMs,
    }
    player:Say(getText("UI_NL_Ability_CreationRebirth_Cast"))
end

-- Zombie Update Bind
local function enforceBindingRoots(zombie)
    local bindUntil = boundZombies[zombie]
    if not bindUntil then return end
    if not zombie or zombie:isDead() or NinjaLineages.Utils.Time.nowMs() > bindUntil then
        boundZombies[zombie] = nil
        return
    end
    zombie:setVariable("AttackOutcome", "fail")
    pcall(function() zombie:setStaggerBack(true) end)
end

-- Dynamic Registration
NinjaLineages.registerAbility({
    id = "binding_roots",
    lineage = "senju",
    name = "UI_NL_Ability_BindingRoots_Name",
    descriptionKey = "UI_NL_Ability_BindingRoots_Desc",
    texture = "media/ui/Traits/trait_senju.png",
    condition = function(player) return NinjaLineages.hasSenju(player) end,
    costTier = "MAJOR",
    cooldownTier = "STANDARD",
    radiusTier = "LARGE",
    durationTier = "BRIEF_MS",
    action = useBindingRoots
})

NinjaLineages.registerAbility({
    id = "creation_rebirth",
    lineage = "senju",
    name = "UI_NL_Ability_CreationRebirth_Name",
    descriptionKey = "UI_NL_Ability_CreationRebirth_Desc",
    texture = "media/ui/Traits/trait_senju.png",
    condition = function(player) return NinjaLineages.hasSenju(player) end,
    costStepTier = "HARSH",
    durationTier = "SHORT_MS",
    action = useCreationRebirth
})

NinjaLineages.registerPlayerUpdate("senju.update", function(player)
    applySenjuEndurance(player)
    updateCreationRebirth(player)
end)

NinjaLineages.registerZombieUpdate("senju.zombieUpdate", enforceBindingRoots)

NinjaLineages.registerCreatePlayer("senju.init", applySenjuEndurance)

NinjaLineages.registerEveryMinute("senju.passive", function(player)
    if NinjaLineages.hasSenju(player) then
        local stats = player:getStats()
        if stats then
            local currentEndurance = stats:get(CharacterStat.ENDURANCE)
            local boosted = math.min(1.0, currentEndurance + consts.Senju.Passive.ENDURANCE_PER_MINUTE)
            stats:set(CharacterStat.ENDURANCE, boosted)
        end
    end
end)
