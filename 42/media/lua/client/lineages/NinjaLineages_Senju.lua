require "NinjaLineages_Traits"
require "NinjaLineages_Utils"

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
    boundZombies[zombie] = NinjaLineages.Utils.Time.nowMs() + consts.Senju.BindingRoots.BIND_MS
end

local function useBindingRoots(player)
    if not NinjaLineages.hasSenju(player) then
        player:Say("Senju lineage is required")
        return
    end

    local data = NinjaLineages.getNLData(player)
    local onCd, remaining = NinjaLineages.Cooldowns.isOnCooldown(player, "senju.binding_roots")
    if onCd then
        player:Say("Binding Roots cooldown: " .. tostring(remaining) .. "s")
        return
    end

    if not NinjaLineages.Chakra.canAffordChakra(player, consts.Senju.BindingRoots.COST) then
        player:Say("Not enough chakra for Binding Roots")
        return
    end

    NinjaLineages.Chakra.spendChakra(player, consts.Senju.BindingRoots.COST)
    for _, target in ipairs(NinjaLineages.Utils.Zombies.collectInRadius(player, consts.Senju.BindingRoots.RADIUS)) do
        applyBindingRootsToZombie(player, target)
    end

    NinjaLineages.Cooldowns.set(player, "senju.binding_roots", consts.Senju.BindingRoots.COOLDOWN_SECONDS)
    player:Say("Mokuton")
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
    local chakra = NinjaLineages.Chakra.getChakra(player)
    for i = 0, parts:size() - 1 do
        if chakra <= 0 then
            NinjaLineages.Chakra.setChakra(player, 0)
            stopCreationRebirth(player)
            return
        end

        local bodypart = parts:get(i)
        if bodypart and healBodyPartForCreationRebirth(bodyDamage, bodypart) then
            chakra = math.max(0.0, chakra - consts.Senju.CreationRebirth.COST_PER_PART)
            NinjaLineages.Chakra.setChakra(player, chakra)
        end
    end
end

local function useCreationRebirth(player)
    if not NinjaLineages.hasSenju(player) then
        player:Say("Senju lineage is required")
        return
    end
    if NinjaLineages.Chakra.getChakra(player) <= 0 then
        player:Say("Too exhausted (low chakra) for Creation Rebirth")
        return
    end
    local nowMs = NinjaLineages.Utils.Time.nowMs()
    creationRebirthState[player] = {
        endsAt = nowMs + consts.Senju.CreationRebirth.DURATION_MS,
        nextTickAt = nowMs,
    }
    player:Say("Creation Rebirth")
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
    name = "Wood Release - Binding Roots",
    texture = "media/ui/Traits/trait_senju.png",
    condition = function(player) return NinjaLineages.hasSenju(player) end,
    action = useBindingRoots
})

NinjaLineages.registerAbility({
    id = "creation_rebirth",
    name = "Creation Rebirth",
    texture = "media/ui/Traits/trait_senju.png",
    condition = function(player) return NinjaLineages.hasSenju(player) end,
    action = useCreationRebirth
})

NinjaLineages.registerPlayerUpdate(function(player)
    applySenjuEndurance(player)
    updateCreationRebirth(player)
end)

NinjaLineages.registerZombieUpdate(enforceBindingRoots)

NinjaLineages.registerCreatePlayer(applySenjuEndurance)

NinjaLineages.registerEveryMinute(function(player)
    if NinjaLineages.hasSenju(player) then
        local stats = player:getStats()
        if stats then
            local currentEndurance = stats:get(CharacterStat.ENDURANCE)
            local boosted = math.min(1.0, currentEndurance + consts.Senju.Passive.ENDURANCE_PER_MINUTE)
            stats:set(CharacterStat.ENDURANCE, boosted)
        end
    end
end)
