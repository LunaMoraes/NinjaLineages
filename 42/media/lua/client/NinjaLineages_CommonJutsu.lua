require "NinjaLineages_Chakra"
require "NinjaLineages_Skills"
require "NinjaLineages_Utils"

NinjaLineages = NinjaLineages or {}
NinjaLineages.CommonJutsu = {}

local consts = NinjaLineages.Constants

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
    local cost = consts.CommonJutsu.Healing.COST
    if not NinjaLineages.Chakra.canAffordChakra(player, cost) then
        player:Say(getText("UI_NL_NotEnoughChakra"))
        return
    end

    local onCd, remaining = NinjaLineages.CommonJutsu.isOnCooldown(player, "healing")
    if onCd then
        player:Say(getText("UI_NL_OnCooldown", tostring(remaining)))
        return
    end

    -- Deduct chakra and set cooldown
    NinjaLineages.Chakra.spendChakra(player, cost)
    NinjaLineages.CommonJutsu.setCooldown(player, "healing", consts.CommonJutsu.Healing.COOLDOWN_SECONDS)

    -- Apply effect
    local prowess = NinjaLineages.Skills.getJutsuProwessLevel(player)
    local healAmount = consts.CommonJutsu.Healing.HEAL_BASE + (prowess * consts.CommonJutsu.Healing.HEAL_PER_PROWESS)

    local bodyDamage = player:getBodyDamage()
    local bodyParts = bodyDamage:getBodyParts()
    local mostDamagedPart = nil
    local maxDamage = 0

    for i = 0, bodyParts:size() - 1 do
        local part = bodyParts:get(i)
        local damage = 100.0 - part:getHealth()
        if damage > maxDamage then
            maxDamage = damage
            mostDamagedPart = part
        end
    end

    if mostDamagedPart and maxDamage > 0 then
        local currentHealth = mostDamagedPart:getHealth()
        mostDamagedPart:setHealth(math.min(100.0, currentHealth + healAmount))
        if mostDamagedPart:isCut() then
            mostDamagedPart:setCutTime(math.max(0.0, mostDamagedPart:getCutTime() - (10.0 + prowess * 2.0)))
        end
        if mostDamagedPart:isScratch() then
            mostDamagedPart:setScratchTime(math.max(0.0, mostDamagedPart:getScratchTime() - (10.0 + prowess * 2.0)))
        end
        bodyDamage:Recalculate()
        player:Say(getText("UI_NL_HealingCast"))
    else
        player:Say(getText("UI_NL_NoWounds"))
    end
end

-- 2. Physical Reinforcement
function NinjaLineages.CommonJutsu.castReinforcement(player)
    local cost = consts.CommonJutsu.Reinforcement.COST
    if not NinjaLineages.Chakra.canAffordChakra(player, cost) then
        player:Say(getText("UI_NL_NotEnoughChakra"))
        return
    end

    local onCd, remaining = NinjaLineages.CommonJutsu.isOnCooldown(player, "reinforcement")
    if onCd then
        player:Say(getText("UI_NL_OnCooldown", tostring(remaining)))
        return
    end

    NinjaLineages.Chakra.spendChakra(player, cost)
    NinjaLineages.CommonJutsu.setCooldown(player, "reinforcement", consts.CommonJutsu.Reinforcement.COOLDOWN_SECONDS)

    local prowess = NinjaLineages.Skills.getJutsuProwessLevel(player)
    local duration = (10 + prowess) * 1000 -- in ms

    local data = NinjaLineages.getNLData(player)
    data.reinforcementEndTime = NinjaLineages.Utils.Time.nowMs() + duration
    NinjaLineages.transmitPlayerData(player)

    player:Say(getText("UI_NL_ReinforcementCast"))
end

-- 3. Quiet Step
function NinjaLineages.CommonJutsu.castQuietStep(player)
    local cost = consts.CommonJutsu.QuietStep.COST
    if not NinjaLineages.Chakra.canAffordChakra(player, cost) then
        player:Say(getText("UI_NL_NotEnoughChakra"))
        return
    end

    local onCd, remaining = NinjaLineages.CommonJutsu.isOnCooldown(player, "quietstep")
    if onCd then
        player:Say(getText("UI_NL_OnCooldown", tostring(remaining)))
        return
    end

    NinjaLineages.Chakra.spendChakra(player, cost)
    NinjaLineages.CommonJutsu.setCooldown(player, "quietstep", consts.CommonJutsu.QuietStep.COOLDOWN_SECONDS)

    local prowess = NinjaLineages.Skills.getJutsuProwessLevel(player)
    local duration = (15 + prowess * 1.5) * 1000 -- in ms

    local data = NinjaLineages.getNLData(player)
    data.quietStepEndTime = NinjaLineages.Utils.Time.nowMs() + duration
    NinjaLineages.transmitPlayerData(player)

    player:Say(getText("UI_NL_QuietStepCast"))
end

-- 4. Chakra Focus
function NinjaLineages.CommonJutsu.castChakraFocus(player)
    local cost = consts.CommonJutsu.ChakraFocus.COST
    if not NinjaLineages.Chakra.canAffordChakra(player, cost) then
        player:Say(getText("UI_NL_NotEnoughChakra"))
        return
    end

    local onCd, remaining = NinjaLineages.CommonJutsu.isOnCooldown(player, "focus")
    if onCd then
        player:Say(getText("UI_NL_OnCooldown", tostring(remaining)))
        return
    end

    NinjaLineages.Chakra.spendChakra(player, cost)
    NinjaLineages.CommonJutsu.setCooldown(player, "focus", consts.CommonJutsu.ChakraFocus.COOLDOWN_SECONDS)

    local prowess = NinjaLineages.Skills.getJutsuProwessLevel(player)
    local stats = player:getStats()

    local panicReduction = 40.0 + (prowess * 5.0)
    local stressReduction = 0.20 + (prowess * 0.03)

    stats:set(CharacterStat.PANIC, math.max(0.0, stats:get(CharacterStat.PANIC) - panicReduction))
    stats:set(CharacterStat.STRESS, math.max(0.0, stats:get(CharacterStat.STRESS) - stressReduction))

    player:Say(getText("UI_NL_ChakraFocusCast"))
end

-- 5. Chakra Grip
function NinjaLineages.CommonJutsu.castChakraGrip(player)
    local cost = consts.CommonJutsu.ChakraGrip.COST
    if not NinjaLineages.Chakra.canAffordChakra(player, cost) then
        player:Say(getText("UI_NL_NotEnoughChakra"))
        return
    end

    local onCd, remaining = NinjaLineages.CommonJutsu.isOnCooldown(player, "grip")
    if onCd then
        player:Say(getText("UI_NL_OnCooldown", tostring(remaining)))
        return
    end

    NinjaLineages.Chakra.spendChakra(player, cost)
    NinjaLineages.CommonJutsu.setCooldown(player, "grip", consts.CommonJutsu.ChakraGrip.COOLDOWN_SECONDS)

    local prowess = NinjaLineages.Skills.getJutsuProwessLevel(player)
    local duration = (12 + prowess) * 1000 -- in ms

    local data = NinjaLineages.getNLData(player)
    data.chakraGripEndTime = NinjaLineages.Utils.Time.nowMs() + duration
    NinjaLineages.transmitPlayerData(player)

    player:Say(getText("UI_NL_ChakraGripCast"))
end

-- 6. Body Flicker Step
function NinjaLineages.CommonJutsu.castBodyFlicker(player)
    local cost = consts.CommonJutsu.BodyFlicker.COST
    if not NinjaLineages.Chakra.canAffordChakra(player, cost) then
        player:Say(getText("UI_NL_NotEnoughChakra"))
        return
    end

    local onCd, remaining = NinjaLineages.CommonJutsu.isOnCooldown(player, "bodyflicker")
    if onCd then
        player:Say(getText("UI_NL_OnCooldown", tostring(remaining)))
        return
    end

    NinjaLineages.Chakra.spendChakra(player, cost)
    NinjaLineages.CommonJutsu.setCooldown(player, "bodyflicker", consts.CommonJutsu.BodyFlicker.COOLDOWN_SECONDS)

    -- Sprint burst: set end time for speed boost (duration in ms)
    local data = NinjaLineages.getNLData(player)
    data.bodyFlickerEndTime = NinjaLineages.Utils.Time.nowMs() + consts.CommonJutsu.BodyFlicker.DURATION_MS
    NinjaLineages.transmitPlayerData(player)

    player:Say(getText("UI_NL_BodyFlickerCast"))
end

-- Update ticks for active buffs (called in Events.OnPlayerUpdate)
function NinjaLineages.CommonJutsu.update(player)
    local data = NinjaLineages.getNLData(player)
    local current = NinjaLineages.Utils.Time.nowMs()

    -- 1. Quiet Step
    if data.quietStepEndTime and current < data.quietStepEndTime then
        if not player:getTraits():contains("Graceful") then
            player:getTraits():add("Graceful")
            data.addedGracefulByJutsu = true
        end
    else
        if data.addedGracefulByJutsu then
            player:getTraits():remove("Graceful")
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
        if not player:getTraits():contains("Strong") then
            player:getTraits():add("Strong")
            data.addedStrongByJutsu = true
        end
    else
        if data.addedStrongByJutsu then
            player:getTraits():remove("Strong")
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
