require "NinjaLineages_Chakra"
require "NinjaLineages_Skills"
require "NinjaLineages_Utils"
require "NinjaLineages_Balance"

NinjaLineages = NinjaLineages or {}
NinjaLineages.CommonJutsu = NinjaLineages.CommonJutsu or {}

local consts = NinjaLineages.Constants

local function checkCostAndCooldown(player, id, costTier, cooldownNameKey, showFeedback)
    local cost = NinjaLineages.Balance.getCost(costTier)
    if not NinjaLineages.Chakra.canAffordChakra(player, cost) then
        if showFeedback then player:Say(getText("UI_NL_Error_NotEnoughChakra")) end
        return false
    end

    local onCd, remaining = NinjaLineages.CommonJutsu.isOnCooldown(player, id)
    if onCd then
        if showFeedback then
            player:Say(getText("UI_NL_Error_AbilityOnCooldown", getText(cooldownNameKey), tostring(remaining)))
        end
        return false
    end
    return true
end

function NinjaLineages.CommonJutsu.canCast(player, id, showFeedback)
    if id == "healing" then
        if not checkCostAndCooldown(player, id, "STANDARD", "UI_NL_Ability_Healing_Name", showFeedback) then
            return false
        end
        local bodyDamage = player:getBodyDamage()
        local bodyParts = bodyDamage and bodyDamage:getBodyParts()
        if bodyParts then
            for i = 0, bodyParts:size() - 1 do
                if NinjaLineages.Utils.Healing.getPartSeverity(bodyParts:get(i)) > 0 then
                    return true
                end
            end
        end
        if showFeedback then player:Say(getText("UI_NL_NoWounds")) end
        return false
    elseif id == "reinforcement" then
        return checkCostAndCooldown(player, id, "STANDARD", "UI_NL_Ability_PhysicalReinforcement_Name", showFeedback)
    elseif id == "quietstep" then
        return checkCostAndCooldown(player, id, "BASIC", "UI_NL_Ability_QuietStep_Name", showFeedback)
    elseif id == "focus" then
        return checkCostAndCooldown(player, id, "BASIC", "UI_NL_Ability_ChakraFocus_Name", showFeedback)
    elseif id == "grip" then
        return checkCostAndCooldown(player, id, "BASIC", "UI_NL_Ability_ChakraGrip_Name", showFeedback)
    elseif id == "bodyflicker" then
        return checkCostAndCooldown(player, id, "ADVANCED", "UI_NL_Ability_Dash_Name", showFeedback)
    end
    return true
end

-- Helper to check cooldowns
function NinjaLineages.CommonJutsu.isOnCooldown(player, jutsuKey)
    local mapping = {
        healing = "common.healing",
        reinforcement = "common.reinforcement",
        quietstep = "common.quiet_step",
        focus = "common.chakra_focus",
        grip = "common.chakra_grip",
        bodyflicker = "common.body_flicker",
    }
    local mappedKey = mapping[jutsuKey] or jutsuKey
    return NinjaLineages.Cooldowns.isOnCooldown(player, mappedKey)
end

-- Helper to set cooldowns
function NinjaLineages.CommonJutsu.setCooldown(player, jutsuKey, durationSeconds)
    local mapping = {
        healing = "common.healing",
        reinforcement = "common.reinforcement",
        quietstep = "common.quiet_step",
        focus = "common.chakra_focus",
        grip = "common.chakra_grip",
        bodyflicker = "common.body_flicker",
    }
    local mappedKey = mapping[jutsuKey] or jutsuKey
    NinjaLineages.Cooldowns.set(player, mappedKey, durationSeconds)
end

-- 1. Minor Healing Jutsu
function NinjaLineages.CommonJutsu.castHealing(player)
    local cost = NinjaLineages.Balance.getCost("STANDARD")
    if not NinjaLineages.Chakra.canAffordChakra(player, cost) then
        player:Say(getText("UI_NL_Error_NotEnoughChakra"))
        return
    end

    local onCd, remaining = NinjaLineages.CommonJutsu.isOnCooldown(player, "healing")
    if onCd then
        player:Say(getText("UI_NL_Error_AbilityOnCooldown", getText("UI_NL_Ability_Healing_Name"), tostring(remaining)))
        return
    end

    local prowess = NinjaLineages.Skills.getJutsuProwessLevel(player)
    local healAmount = consts.CommonJutsu.Healing.HEAL_BASE + (prowess * consts.CommonJutsu.Healing.HEAL_PER_PROWESS)

    local bodyDamage = player:getBodyDamage()
    if not bodyDamage then
        return
    end

    local bodyParts = bodyDamage:getBodyParts()
    if not bodyParts then
        return
    end

    local mostDamagedPart = nil
    local maxDamage = 0

    for i = 0, bodyParts:size() - 1 do
        local part = bodyParts:get(i)
        local woundSeverity = NinjaLineages.Utils.Healing.getPartSeverity(part)

        if woundSeverity > maxDamage then
            maxDamage = woundSeverity
            mostDamagedPart = part
        end
    end

    if not mostDamagedPart or maxDamage <= 0 then
        player:Say(getText("UI_NL_NoWounds"))
        return
    end

    local timerReduction = 10.0 + prowess * 2.0
    local changed = NinjaLineages.Utils.Healing.healPart(bodyDamage, mostDamagedPart, {
        health = healAmount,
        scratch = timerReduction,
        cut = timerReduction,
    })

    if not changed then
        player:Say(getText("UI_NL_NoWounds"))
        return
    end

    NinjaLineages.Chakra.spendChakra(player, cost)
    NinjaLineages.CommonJutsu.setCooldown(player, "healing", NinjaLineages.Balance.getCooldown("STANDARD"))

    player:Say(getText("UI_NL_Ability_Healing_Cast"))
end

-- 2. Physical Reinforcement
function NinjaLineages.CommonJutsu.castReinforcement(player)
    local cost = NinjaLineages.Balance.getCost("STANDARD")
    if not NinjaLineages.Chakra.canAffordChakra(player, cost) then
        player:Say(getText("UI_NL_Error_NotEnoughChakra"))
        return
    end

    local onCd, remaining = NinjaLineages.CommonJutsu.isOnCooldown(player, "reinforcement")
    if onCd then
        player:Say(getText("UI_NL_Error_AbilityOnCooldown", getText("UI_NL_Ability_PhysicalReinforcement_Name"), tostring(remaining)))
        return
    end

    NinjaLineages.Chakra.spendChakra(player, cost)
    NinjaLineages.CommonJutsu.setCooldown(player, "reinforcement", NinjaLineages.Balance.getCooldown("LONG"))

    local prowess = NinjaLineages.Skills.getJutsuProwessLevel(player)
    local duration = (10 + prowess) * 1000 -- in ms

    local data = NinjaLineages.getNLData(player)
    data.reinforcementEndTime = NinjaLineages.Utils.Time.nowGameMs(player) + duration
    NinjaLineages.transmitPlayerData(player)

    player:Say(getText("UI_NL_Ability_PhysicalReinforcement_Cast"))
end

-- 3. Quiet Step
function NinjaLineages.CommonJutsu.castQuietStep(player)
    local cost = NinjaLineages.Balance.getCost("BASIC")
    if not NinjaLineages.Chakra.canAffordChakra(player, cost) then
        player:Say(getText("UI_NL_Error_NotEnoughChakra"))
        return
    end

    local onCd, remaining = NinjaLineages.CommonJutsu.isOnCooldown(player, "quietstep")
    if onCd then
        player:Say(getText("UI_NL_Error_AbilityOnCooldown", getText("UI_NL_Ability_QuietStep_Name"), tostring(remaining)))
        return
    end

    NinjaLineages.Chakra.spendChakra(player, cost)
    NinjaLineages.CommonJutsu.setCooldown(player, "quietstep", NinjaLineages.Balance.getCooldown("STANDARD"))

    local prowess = NinjaLineages.Skills.getJutsuProwessLevel(player)
    local duration = (15 + prowess * 1.5) * 1000 -- in ms

    local data = NinjaLineages.getNLData(player)
    data.quietStepEndTime = NinjaLineages.Utils.Time.nowGameMs(player) + duration
    NinjaLineages.transmitPlayerData(player)

    player:Say(getText("UI_NL_Ability_QuietStep_Cast"))
end

-- 4. Chakra Focus
function NinjaLineages.CommonJutsu.castChakraFocus(player)
    local cost = NinjaLineages.Balance.getCost("BASIC")
    if not NinjaLineages.Chakra.canAffordChakra(player, cost) then
        player:Say(getText("UI_NL_Error_NotEnoughChakra"))
        return
    end

    local onCd, remaining = NinjaLineages.CommonJutsu.isOnCooldown(player, "focus")
    if onCd then
        player:Say(getText("UI_NL_Error_AbilityOnCooldown", getText("UI_NL_Ability_ChakraFocus_Name"), tostring(remaining)))
        return
    end

    NinjaLineages.Chakra.spendChakra(player, cost)
    NinjaLineages.CommonJutsu.setCooldown(player, "focus", NinjaLineages.Balance.getCooldown("STANDARD"))

    local prowess = NinjaLineages.Skills.getJutsuProwessLevel(player)
    local stats = player:getStats()

    local panicReduction = 40.0 + (prowess * 5.0)
    local stressReduction = 0.20 + (prowess * 0.03)

    stats:set(CharacterStat.PANIC, math.max(0.0, stats:get(CharacterStat.PANIC) - panicReduction))
    stats:set(CharacterStat.STRESS, math.max(0.0, stats:get(CharacterStat.STRESS) - stressReduction))

    player:Say(getText("UI_NL_Ability_ChakraFocus_Cast"))
end

-- 5. Chakra Grip
function NinjaLineages.CommonJutsu.castChakraGrip(player)
    local cost = NinjaLineages.Balance.getCost("BASIC")
    if not NinjaLineages.Chakra.canAffordChakra(player, cost) then
        player:Say(getText("UI_NL_Error_NotEnoughChakra"))
        return
    end

    local onCd, remaining = NinjaLineages.CommonJutsu.isOnCooldown(player, "grip")
    if onCd then
        player:Say(getText("UI_NL_Error_AbilityOnCooldown", getText("UI_NL_Ability_ChakraGrip_Name"), tostring(remaining)))
        return
    end

    NinjaLineages.Chakra.spendChakra(player, cost)
    NinjaLineages.CommonJutsu.setCooldown(player, "grip", NinjaLineages.Balance.getCooldown("SHORT"))

    local prowess = NinjaLineages.Skills.getJutsuProwessLevel(player)
    local duration = (12 + prowess) * 1000 -- in ms

    local data = NinjaLineages.getNLData(player)
    data.chakraGripEndTime = NinjaLineages.Utils.Time.nowGameMs(player) + duration
    NinjaLineages.transmitPlayerData(player)

    player:Say(getText("UI_NL_Ability_ChakraGrip_Cast"))
end

-- 6. Body Flicker Step
function NinjaLineages.CommonJutsu.castBodyFlicker(player)
    local cost = NinjaLineages.Balance.getCost("ADVANCED")
    if not NinjaLineages.Chakra.canAffordChakra(player, cost) then
        player:Say(getText("UI_NL_Error_NotEnoughChakra"))
        return
    end

    local onCd, remaining = NinjaLineages.CommonJutsu.isOnCooldown(player, "bodyflicker")
    if onCd then
        player:Say(getText("UI_NL_Error_AbilityOnCooldown", getText("UI_NL_Ability_Dash_Name"), tostring(remaining)))
        return
    end

    NinjaLineages.Chakra.spendChakra(player, cost)
    NinjaLineages.CommonJutsu.setCooldown(player, "bodyflicker", NinjaLineages.Balance.getCooldown("DASH"))

    -- Sprint burst: set end time for speed boost (duration in ms)
    local data = NinjaLineages.getNLData(player)
    data.bodyFlickerEndTime = NinjaLineages.Utils.Time.nowGameMs(player) + NinjaLineages.Balance.getDuration("BURST_MS")
    NinjaLineages.transmitPlayerData(player)

    player:Say(getText("UI_NL_Ability_Dash_Cast"))
end

-- Update ticks for active buffs (called in Events.OnPlayerUpdate)
function NinjaLineages.CommonJutsu.update(player)
    local data = NinjaLineages.getNLData(player)
    local current = NinjaLineages.Utils.Time.nowGameMs(player)

    -- 1. Quiet Step
    if data.quietStepEndTime and current < data.quietStepEndTime then
        if not player:hasTrait(CharacterTrait.GRACEFUL) then
            player:getCharacterTraits():add(CharacterTrait.GRACEFUL)
            data.addedGracefulByJutsu = true
        end
    else
        if data.addedGracefulByJutsu then
            player:getCharacterTraits():remove(CharacterTrait.GRACEFUL)
            data.addedGracefulByJutsu = nil
            player:Say(getText("UI_NL_QuietStepExpired"))
        end
        data.quietStepEndTime = nil
    end

    -- 2. Physical Reinforcement
    if data.reinforcementEndTime and current < data.reinforcementEndTime then
        local stats = player:getStats()
        stats:set(CharacterStat.FATIGUE, math.max(0.0, stats:get(CharacterStat.FATIGUE) - 0.0005))
        stats:set(CharacterStat.ENDURANCE, math.min(1.0, stats:get(CharacterStat.ENDURANCE) + 0.005))
    else
        if data.reinforcementEndTime then
            player:Say(getText("UI_NL_ReinforcementExpired"))
        end
        data.reinforcementEndTime = nil
    end

    -- 3. Chakra Grip
    if data.chakraGripEndTime and current < data.chakraGripEndTime then
        if not player:hasTrait(CharacterTrait.STRONG) then
            player:getCharacterTraits():add(CharacterTrait.STRONG)
            data.addedStrongByJutsu = true
        end
    else
        if data.addedStrongByJutsu then
            player:getCharacterTraits():remove(CharacterTrait.STRONG)
            data.addedStrongByJutsu = nil
            player:Say(getText("UI_NL_ChakraGripExpired"))
        end
        data.chakraGripEndTime = nil
    end

    -- 4. Body Flicker sprint burst
    if data.bodyFlickerEndTime and current < data.bodyFlickerEndTime then
        local fwd = player:getForwardDirection()
        if fwd then
            local dx = fwd:getX()
            local dy = fwd:getY()
            
            -- Apply a massive boost forward
            local boostMultiplier = consts.CommonJutsu.BodyFlicker.BOOST_MULTIPLIER
            local nextX = player:getX() + dx * boostMultiplier
            local nextY = player:getY() + dy * boostMultiplier
            
            local currentSq = player:getCurrentSquare()
            local nextSq = getCell():getGridSquare(nextX, nextY, player:getZ())
            
            if nextSq and currentSq and not nextSq:isBlockedTo(currentSq) then
                player:setX(nextX)
                player:setY(nextY)
            end
        end
    else
        data.bodyFlickerEndTime = nil
    end
end

-- Dynamic Registration of Common Jutsus
NinjaLineages.registerAbility({
    id = "healing",
    lineage = "common",
    name = "UI_NL_Ability_Healing_Name",
    descriptionKey = "UI_NL_Ability_Healing_Desc",
    texture = "media/ui/NLJutsu.png",
    costTier = "STANDARD",
    cooldownTier = "STANDARD",
    handSigns = { "boar", "ram", "snake" },
    preCast = function(player, showFeedback)
        return NinjaLineages.CommonJutsu.canCast(player, "healing", showFeedback)
    end,
    action = NinjaLineages.CommonJutsu.castHealing
})

NinjaLineages.registerAbility({
    id = "reinforcement",
    lineage = "common",
    name = "UI_NL_Ability_PhysicalReinforcement_Name",
    descriptionKey = "UI_NL_Ability_PhysicalReinforcement_Desc",
    texture = "media/ui/NLJutsu.png",
    costTier = "STANDARD",
    cooldownTier = "LONG",
    handSigns = { "tiger", "horse", "ox" },
    preCast = function(player, showFeedback)
        return NinjaLineages.CommonJutsu.canCast(player, "reinforcement", showFeedback)
    end,
    action = NinjaLineages.CommonJutsu.castReinforcement
})

NinjaLineages.registerAbility({
    id = "quietstep",
    lineage = "common",
    name = "UI_NL_Ability_QuietStep_Name",
    descriptionKey = "UI_NL_Ability_QuietStep_Desc",
    texture = "media/ui/NLJutsu.png",
    costTier = "BASIC",
    cooldownTier = "STANDARD",
    handSigns = { "rat", "snake", "hare" },
    preCast = function(player, showFeedback)
        return NinjaLineages.CommonJutsu.canCast(player, "quietstep", showFeedback)
    end,
    action = NinjaLineages.CommonJutsu.castQuietStep
})

NinjaLineages.registerAbility({
    id = "focus",
    lineage = "common",
    name = "UI_NL_Ability_ChakraFocus_Name",
    descriptionKey = "UI_NL_Ability_ChakraFocus_Desc",
    texture = "media/ui/NLJutsu.png",
    costTier = "BASIC",
    cooldownTier = "STANDARD",
    handSigns = { "ram", "dragon", "tiger" },
    preCast = function(player, showFeedback)
        return NinjaLineages.CommonJutsu.canCast(player, "focus", showFeedback)
    end,
    action = NinjaLineages.CommonJutsu.castChakraFocus
})

NinjaLineages.registerAbility({
    id = "grip",
    lineage = "common",
    name = "UI_NL_Ability_ChakraGrip_Name",
    descriptionKey = "UI_NL_Ability_ChakraGrip_Desc",
    texture = "media/ui/NLJutsu.png",
    costTier = "BASIC",
    cooldownTier = "SHORT",
    handSigns = { "dog", "ox", "horse" },
    preCast = function(player, showFeedback)
        return NinjaLineages.CommonJutsu.canCast(player, "grip", showFeedback)
    end,
    action = NinjaLineages.CommonJutsu.castChakraGrip
})

NinjaLineages.registerAbility({
    id = "bodyflicker",
    lineage = "common",
    name = "UI_NL_Ability_Dash_Name",
    descriptionKey = "UI_NL_Ability_Dash_Desc",
    texture = "media/ui/NLJutsu.png",
    costTier = "ADVANCED",
    cooldownTier = "DASH",
    durationTier = "BURST_MS",
    handSigns = { "bird", "hare", "rat" },
    preCast = function(player, showFeedback)
        return NinjaLineages.CommonJutsu.canCast(player, "bodyflicker", showFeedback)
    end,
    action = NinjaLineages.CommonJutsu.castBodyFlicker
})
