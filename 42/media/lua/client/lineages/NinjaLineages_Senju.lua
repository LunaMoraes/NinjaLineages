require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "NinjaLineages_Balance"

NinjaLineages = NinjaLineages or {}
NinjaLineages.Senju = NinjaLineages.Senju or {}

local consts = NinjaLineages.Constants

local senjuLastRecoveryAt = {}
local boundZombies = {}
local creationRebirthState = {}

local function updateCreationRebirthUnlock(player)
    if not NinjaLineages.hasSenju(player) then return end
    if NinjaLineages.CreationRebirth.isUnlocked(player) then return end

    local requiredLevel = consts.Senju.CreationRebirth.SENJU_UNLOCK_LEVEL
    if NinjaLineages.Skills.getChakraControlLevel(player) >= requiredLevel then
        NinjaLineages.CreationRebirth.unlock(player, "UI_NL_Unlock_CreationRebirth")
    end
end

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
    boundZombies[zombie] = NinjaLineages.Utils.Time.nowGameMs(player) + NinjaLineages.Balance.getDuration("BRIEF_MS")
end

local function useBindingRoots(player)
    if not NinjaLineages.hasSenju(player) then
        player:Say(getText("UI_NL_Error_LineageRequired", "Senju lineage"))
        return false
    end

    local data = NinjaLineages.getNLData(player)
    local onCd, remaining = NinjaLineages.Cooldowns.isOnCooldown(player, "senju.binding_roots")
    if onCd then
        player:Say(getText("UI_NL_Error_AbilityOnCooldown", getText("UI_NL_Ability_BindingRoots_Name"), tostring(remaining)))
        return false
    end

    local cost = NinjaLineages.Balance.getCost("MAJOR")
    if not NinjaLineages.Chakra.canAffordChakra(player, cost) then
        player:Say(getText("UI_NL_Error_NotEnoughChakra_BindingRoots"))
        return false
    end

    NinjaLineages.Chakra.spendChakra(player, cost)
    local radius = NinjaLineages.Balance.getRadius("LARGE")
    for _, target in ipairs(NinjaLineages.Utils.Zombies.collectInRadius(player, radius)) do
        applyBindingRootsToZombie(player, target)
    end

    NinjaLineages.Cooldowns.set(player, "senju.binding_roots", NinjaLineages.Balance.getCooldown("STANDARD"))
    player:Say(getText("UI_NL_Ability_BindingRoots_Cast"))
    return true
end

local function stopCreationRebirth(player)
    creationRebirthState[player] = nil
end

local function updateCreationRebirth(player)
    local state = creationRebirthState[player]
    if not state then return end

    local nowMs = NinjaLineages.Utils.Time.nowGameMs(player)
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
        if NinjaLineages.Utils.Healing.getPartSeverity(bodypart) > 0 then
            if NinjaLineages.Chakra.getChakra(player) < costStep then
                stopCreationRebirth(player)
                return
            end

            local changed = NinjaLineages.Utils.Healing.healPart(bodyDamage, bodypart, {
                health = 3.0,
                bleeding = 4.0,
                scratch = 4.0,
                cut = 4.0,
                deepWound = 3.0,
                burn = 2.0,
                fracture = 1.0,
            })
            if changed then
                NinjaLineages.Chakra.spendChakra(player, costStep)
            end
        end
    end
end

local function useCreationRebirth(player)
    if not NinjaLineages.CreationRebirth.isUnlocked(player) then
        player:Say(getText("UI_NL_Error_CreationRebirthLocked"))
        return false
    end
    if NinjaLineages.Chakra.getChakra(player) <= 0 then
        player:Say(getText("UI_NL_Error_NotEnoughChakra_CreationRebirth"))
        return false
    end
    local nowMs = NinjaLineages.Utils.Time.nowGameMs(player)
    creationRebirthState[player] = {
        endsAt = nowMs + NinjaLineages.Balance.getDuration("SHORT_MS"),
        nextTickAt = nowMs,
    }
    player:Say(getText("UI_NL_Ability_CreationRebirth_Cast"))
    return true
end

-- Zombie Update Bind
local function enforceBindingRoots(zombie)
    local bindUntil = boundZombies[zombie]
    if not bindUntil then return end
    if not zombie or zombie:isDead() or NinjaLineages.Utils.Time.nowGameMs() > bindUntil then
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
    condition = function(player) return NinjaLineages.CreationRebirth.isUnlocked(player) end,
    costStepTier = "HARSH",
    durationTier = "SHORT_MS",
    action = useCreationRebirth
})

NinjaLineages.registerPlayerUpdate("senju.update", function(player)
    applySenjuEndurance(player)
    updateCreationRebirth(player)
end)

NinjaLineages.registerZombieUpdate("senju.zombieUpdate", enforceBindingRoots)

NinjaLineages.registerCreatePlayer("senju.init", function(player)
    applySenjuEndurance(player)
    updateCreationRebirthUnlock(player)
end)

Events.LevelPerk.Add(function(player, perk)
    local chakraControl = Perks.FromString("ChakraControl")
    if perk == chakraControl then
        updateCreationRebirthUnlock(player)
    end
end)

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
