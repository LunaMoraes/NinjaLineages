require "NinjaLineages_Traits"
require "NinjaLineages_Balance"
require "NinjaLineages_AbilityAuthority"
require "NinjaLineages_JutsuCatalog"
require "NinjaLineages_Utils"
require "lineages/NinjaLineages_KamuiState"

NinjaLineages = NinjaLineages or {}
NinjaLineages.AbilityAuthority = NinjaLineages.AbilityAuthority or {}
NinjaLineages.AbilityExecution = NinjaLineages.AbilityExecution or {}
NinjaLineages.AbilityExecution.active = NinjaLineages.AbilityExecution.active or {}

local active = NinjaLineages.AbilityExecution.active
local Catalog = NinjaLineages.JutsuCatalog
local Balance = NinjaLineages.Balance

local function spendChakraTowardStat(player, stats, stat, target, statPerChakra,
        maximumSpend, abilityId)
    local current = stats:get(stat)
    local direction = target >= current and 1 or -1
    local chakraSpent = math.min(
        maximumSpend,
        NinjaLineages.Chakra.getChakra(player),
        math.abs(target - current) / statPerChakra
    )
    if chakraSpent <= 0 or not NinjaLineages.Chakra.spendChakra(player, chakraSpent, {
            jutsuSpend = true,
            abilityId = abilityId,
        }) then return end
    local adjusted = current + (direction * chakraSpent * statPerChakra)
    stats:set(stat, direction > 0 and math.min(target, adjusted) or math.max(target, adjusted))
end

local function isStatMet(current, target)
    if target == 0 then return current <= 0.01 end
    if target == 1 then return current >= 0.99 end
    return math.abs(current - target) <= 0.01
end

local function processStatRestorationLoop(player, state, now, actionId, stateUntilKey, stateNextTickKey, messageKey, statsToRestore)
    if not state[stateUntilKey] then return end
    
    local resolved = Catalog.resolveBalance(actionId)
    local processUntil = math.min(now, state[stateUntilKey])
    
    while state[stateNextTickKey]
            and state[stateNextTickKey] <= processUntil
            and state[stateNextTickKey] < state[stateUntilKey] do
        
        local stats = player:getStats()
        local allDone = true
        
        for _, config in ipairs(statsToRestore) do
            local current = stats:get(config.stat)
            if not isStatMet(current, config.targetValue) then
                allDone = false
                break
            end
        end
        
        if allDone then
            state[stateUntilKey] = now
            break
        end
        
        local step = resolved.costStep or Balance.getCostStep("STANDARD")
        for _, config in ipairs(statsToRestore) do
            local current = stats:get(config.stat)
            if not isStatMet(current, config.targetValue) then
                spendChakraTowardStat(
                    player, stats, config.stat, config.targetValue,
                    config.conversionRate, step, actionId
                )
            end
        end
        
        allDone = true
        for _, config in ipairs(statsToRestore) do
            local current = stats:get(config.stat)
            if not isStatMet(current, config.targetValue) then
                allDone = false
                break
            end
        end
        
        if allDone then
            state[stateUntilKey] = now
            break
        end
        
        state[stateNextTickKey] = state[stateNextTickKey] + resolved.tickInterval
        
        if NinjaLineages.Chakra.getChakra(player) <= 0 then
            state[stateUntilKey] = now
            break
        end
    end
    
    if now >= state[stateUntilKey] then
        state[stateUntilKey] = nil
        state[stateNextTickKey] = nil
        if NinjaLineages.isServer() then
            sendServerCommand("NinjaLineages", "abilityEvent", {
                kind = "stat_restoration_completed",
                targetId = player:getOnlineID(),
                messageKey = messageKey
            })
        else
            player:Say(getText(messageKey))
        end
    end
end

local function applyKamuiVisionPenalty(player)
    local data = NinjaLineages.getNLData(player)
    local level = math.min(3, (data.kamuiVisionLevel or 0) + 1)
    data.kamuiVisionLevel = level
    data.kamuiVisionRecoverAt = NinjaLineages.Utils.Time.gameMinutes()
        + Balance.Lineages.Uchiha.VisionRecoveryMinutes[level]
    NinjaLineages.transmitPlayerData(player)
end

function NinjaLineages.AbilityAuthority.updateLocalMovement(player)
    if not player then return end
    local state = active[player]
    if not state then return end
    
    local movement = state.forwardMovement
    if movement then
        local now = NinjaLineages.Utils.Time.gameMinutes()
        local activeState, progress = NinjaLineages.Utils.Movement.updateDash(
            player,
            movement,
            now,
            Balance.CommonJutsu.Dash.STEP_DISTANCE,
            function() state.forwardMovement = nil end
        )
        if not activeState then
            state.forwardMovement = nil
        end
    end
end

function NinjaLineages.AbilityAuthority.updatePlayer(player)
    local state = active[player] or {}
    active[player] = state
    local now = NinjaLineages.Utils.Time.gameMinutes()
    local previousUpdateAt = state.lastUpdateAt or now
    state.lastUpdateAt = now
    local elapsed = math.max(0, now - previousUpdateAt)
    local data = NinjaLineages.getNLData(player)

    if NinjaLineages.ChakraCloak and NinjaLineages.ChakraCloak.update then
        NinjaLineages.ChakraCloak.update(player, elapsed)
    end
    if NinjaLineages.CombatModifiers and NinjaLineages.CombatModifiers.updatePlayer then
        NinjaLineages.CombatModifiers.updatePlayer(player)
    end

    NinjaLineages.BringerOfDarkness.updatePlayer(player)
    NinjaLineages.DemonicFlute.updatePlayer(player)

    if data.bleedingSuppressionEndTime and now < data.bleedingSuppressionEndTime then
        local parts = player:getBodyDamage():getBodyParts()
        for i = 0, parts:size() - 1 do
            local part = parts:get(i)
            pcall(function()
                part:setBleedingTime(0)
                part:setBleeding(false)
            end)
        end
    elseif data.bleedingSuppressionEndTime then
        data.bleedingSuppressionEndTime = nil
    end

    if state.kamuiUntil then
        pcall(function() player:setGhostMode(true) end)
        pcall(function() player:setGodMod(true, true) end)
        if NinjaLineages.isClient() or NinjaLineages.isServer() then
            pcall(function() player:setNoClip(true, true) end)
        end

        local square = player:getSquare()
        if NinjaLineages.KamuiState.isSafeExitSquare(square) then
            state.kamuiLastSafeX = player:getX()
            state.kamuiLastSafeY = player:getY()
            state.kamuiLastSafeZ = player:getZ()
        end

        local chakra = NinjaLineages.Chakra.getChakra(player)
        local kamui = Catalog.resolveBalance("kamui")
        local kamuiElapsed = math.max(
            0,
            math.min(now, state.kamuiUntil) - previousUpdateAt
        )
        chakra = math.max(0, chakra - kamui.channelDrain * kamuiElapsed)
        NinjaLineages.Chakra.setChakra(player, chakra)
        if now >= state.kamuiUntil or chakra <= 0 then
            state.kamuiUntil = nil
            NinjaLineages.KamuiState.restore(player, state)
            applyKamuiVisionPenalty(player)
            local cost = Balance.GeneExperimentation.Surgery.MANGEKYO_FRESHNESS_COST
            if data.eyes then
                if data.eyes.left and data.eyes.left.type == "sharingan" and (data.eyes.left.freshness or 0) > 0 then
                    data.eyes.left.freshness = math.max(0, (data.eyes.left.freshness or Balance.GeneExperimentation.Extraction.MAX_ROLL_FRESHNESS) - cost)
                elseif data.eyes.right and data.eyes.right.type == "sharingan" and (data.eyes.right.freshness or 0) > 0 then
                    data.eyes.right.freshness = math.max(0, (data.eyes.right.freshness or Balance.GeneExperimentation.Extraction.MAX_ROLL_FRESHNESS) - cost)
                end
                NinjaLineages.transmitPlayerData(player)
            end
            local kamuiDef = Catalog.get("kamui")
            local resolved = Catalog.resolveBalance(kamuiDef)
            NinjaLineages.Cooldowns.set(
                player,
                Catalog.getCooldownKey(kamuiDef),
                resolved.cooldown or Balance.getCooldown("STANDARD")
            )
        end
    end

    if state.creationRebirthUntil then
        local rebirth = Catalog.resolveBalance("creation_rebirth")
        local processUntil = math.min(now, state.creationRebirthUntil)
        while state.nextRebirthTick
                and state.nextRebirthTick <= processUntil
                and state.nextRebirthTick < state.creationRebirthUntil do
            local parts = player:getBodyDamage():getBodyParts()
            local step = rebirth.costStep
            for i = 0, parts:size() - 1 do
                local part = parts:get(i)
                if NinjaLineages.Utils.Healing.getPartSeverity(part) > 0
                        and NinjaLineages.Chakra.getChakra(player) >= step then
                    local healing = {}
                    for key, value in pairs(rebirth.healing) do
                        healing[key] = type(value) == "number"
                            and NinjaLineages.CombatModifiers
                            and NinjaLineages.CombatModifiers.applyJutsuHealing(player, value)
                            or value
                    end
                    local changed = NinjaLineages.Utils.Healing.healPart(
                        player:getBodyDamage(),
                        part,
                        healing
                    )
                    if changed then
                        NinjaLineages.Chakra.spendChakra(player, step, {
                            jutsuSpend = true,
                            abilityId = "creation_rebirth",
                        })
                    end
                end
            end
            state.nextRebirthTick = state.nextRebirthTick + rebirth.tickInterval
        end
        if now >= state.creationRebirthUntil then
            state.creationRebirthUntil = nil
            state.nextRebirthTick = nil
        end
    end

    processStatRestorationLoop(
        player, state, now, "chakra_focus",
        "chakraFocusUntil", "nextChakraFocusTick",
        "UI_NL_Ability_chakra_focus_Deactivated",
        {
            { stat = CharacterStat.PANIC, targetValue = 0, conversionRate = Balance.ResourceConversion.ChakraFocus.CHAKRA_TO_PANIC },
            { stat = CharacterStat.STRESS, targetValue = 0, conversionRate = Balance.ResourceConversion.ChakraFocus.CHAKRA_TO_STRESS },
        }
    )

    processStatRestorationLoop(
        player, state, now, "calorie_control",
        "calorieControlUntil", "nextCalorieTick",
        "UI_NL_Ability_calorie_control_Deactivated",
        {
            { stat = CharacterStat.HUNGER, targetValue = 0, conversionRate = Balance.ResourceConversion.CalorieControl.CHAKRA_TO_HUNGER },
            { stat = CharacterStat.THIRST, targetValue = 0, conversionRate = Balance.ResourceConversion.CalorieControl.CHAKRA_TO_THIRST },
        }
    )

    processStatRestorationLoop(
        player, state, now, "physical_reinforcement",
        "physicalReinforcementUntil", "nextPhysicalReinforcementTick",
        "UI_NL_ReinforcementExpired",
        {
            { stat = CharacterStat.ENDURANCE, targetValue = 1, conversionRate = Balance.ResourceConversion.PhysicalReinforcement.CHAKRA_TO_ENDURANCE },
            { stat = CharacterStat.FATIGUE, targetValue = 0, conversionRate = Balance.ResourceConversion.PhysicalReinforcement.CHAKRA_TO_FATIGUE },
        }
    )

    local visionLevel = data.kamuiVisionLevel or 0
    while visionLevel > 0
            and data.kamuiVisionRecoverAt
            and now >= data.kamuiVisionRecoverAt do
        visionLevel = visionLevel - 1
        data.kamuiVisionLevel = visionLevel
        if visionLevel > 0 then
            data.kamuiVisionRecoverAt = data.kamuiVisionRecoverAt
                + Balance.Lineages.Uchiha.VisionRecoveryMinutes[visionLevel]
        else
            data.kamuiVisionRecoverAt = nil
        end
        NinjaLineages.transmitPlayerData(player)
    end

    if data.corpseOdorConditioningActive then
        local elapsed = math.max(0, now - previousUpdateAt)
        local drain = Balance.getSustainedDrain("TRACE") * elapsed
        local chakra = NinjaLineages.Chakra.getChakra(player)
        chakra = math.max(0, chakra - drain)
        NinjaLineages.Chakra.setChakra(player, chakra)
        if chakra <= 0 then
            data.corpseOdorConditioningActive = nil
            if NinjaLineages.AbilityExecution.removeOdorMask then
                NinjaLineages.AbilityExecution.removeOdorMask(player, data)
            end
            player:Say(getText("UI_NL_Ability_CorpseOdorConditioning_Deactivated"))
            NinjaLineages.transmitPlayerData(player)
        else
            if NinjaLineages.AbilityExecution.wearOdorMask then
                NinjaLineages.AbilityExecution.wearOdorMask(player, data)
            end
        end
    else
        if data.odorMaskItemId then
            if NinjaLineages.AbilityExecution.removeOdorMask then
                NinjaLineages.AbilityExecution.removeOdorMask(player, data)
            end
        end
    end
end

function NinjaLineages.AbilityAuthority.everyMinute(player)
    local state = active[player] or {}
    active[player] = state
    local now = NinjaLineages.Utils.Time.gameMinutes()
    local elapsed = math.max(0, now - (state.lastResourceUpdateAt or (now - 1)))
    state.lastResourceUpdateAt = now
    if elapsed <= 0 then return end

    local data = NinjaLineages.getNLData(player)
    if not data then return end

    -- Check temporary gene effect expiration
    if data.activeGeneEffect then
        if data.activeGeneEffect.expiresAt and now >= data.activeGeneEffect.expiresAt then
            data.activeGeneEffect = nil
            NinjaLineages.transmitPlayerData(player)
            if NinjaLineages.isServer() then
                sendServerCommand(player, "NinjaLineages", "geneExperimentationMessage", {
                    textKey = "UI_NL_GeneEffect_Expired",
                    casterOnlineId = player:getOnlineID(),
                })
            else
                player:Say(getText("UI_NL_GeneEffect_Expired"))
            end
        else
            -- Apply continuous gene effect passive benefits/debuffs
            local stats = player:getStats()
            local effect = Balance.getGeneEffect(data.activeGeneEffect.id)
            if data.activeGeneEffect.id == "vitality_surge" and effect then
                local bodyDamage = player:getBodyDamage()
                if bodyDamage and bodyDamage:getOverallBodyHealth() < 100 then
                    local currentHealth = bodyDamage:getOverallBodyHealth()
                    pcall(function()
                        bodyDamage:setOverallBodyHealth(math.min(
                            Balance.Progression.ProbabilityMaximum,
                            currentHealth + (effect.healthRegenPerMinute * elapsed)
                        ))
                    end)
                end
            elseif data.activeGeneEffect.id == "physical_vigor" and effect then
                if stats then
                    local currentFatigue = stats:get(CharacterStat.FATIGUE) or 0
                    local currentEndurance = stats:get(CharacterStat.ENDURANCE) or 0
                    stats:set(CharacterStat.FATIGUE, math.max(0, currentFatigue - (effect.fatigueRecoveryPerMinute * elapsed)))
                    stats:set(CharacterStat.ENDURANCE, math.min(1, currentEndurance + (effect.enduranceRecoveryPerMinute * elapsed)))
                end
            elseif data.activeGeneEffect.id == "cellular_rejection" and effect then
                if stats then
                    local currentFatigue = stats:get(CharacterStat.FATIGUE) or 0
                    stats:set(CharacterStat.FATIGUE, math.min(1, currentFatigue + (effect.fatigueGainPerMinute * elapsed)))
                end
            end
        end
    end

    local maxChakra = NinjaLineages.Chakra.getMaxChakra(player)
    local chakra = NinjaLineages.Chakra.getChakra(player)
    local skillLevel = NinjaLineages.Skills.getChakraControlLevel(player)
    local regen = maxChakra * Balance.Chakra.BASE_REGEN_PCT_PER_MINUTE
        * NinjaLineages.Skills.getRegenMultiplier(skillLevel)
    if data.isMeditating then regen = regen * Balance.Chakra.MEDITATION_REGEN_MULTIPLIER end
    if data.activeGeneEffect and data.activeGeneEffect.id == "chakra_surge" then
        local effect = Balance.getGeneEffect("chakra_surge")
        regen = regen * effect.chakraRegenMultiplier
    end
    if data.bloodTransfusionRegenUntil then
        if now < data.bloodTransfusionRegenUntil then
            regen = regen * Balance.GeneExperimentation.BloodTransfusion.REGEN_MULTIPLIER
        else
            data.bloodTransfusionRegenUntil = nil
        end
    end
    chakra = math.min(maxChakra, chakra + (regen * elapsed))

    if data.eyePowerActive then
        local totalDrain = 0
        local sharinganCount = NinjaLineages.getInstalledEyeCount(player, "sharingan")
        if sharinganCount > 0 then
            local sharingan = Catalog.resolveBalance("sharingan")
            local sDrain = 0
            if data.mangekyoUnlocked then
                sDrain = sharingan.evolvedDrain
            else
                sDrain = sharingan.sustainedDrains[
                    NinjaLineages.getSharinganStage(player)
                ] or 0
            end
            sDrain = sDrain * NinjaLineages.getEyePowerMultiplier(player, "sharingan")
            totalDrain = totalDrain + sDrain
        end
        local byakuganCount = NinjaLineages.getInstalledEyeCount(player, "byakugan")
        if byakuganCount > 0 then
            local bDrain = Catalog.resolveBalance("byakugan").sustainedDrain * NinjaLineages.getEyePowerMultiplier(player, "byakugan")
            totalDrain = totalDrain + bDrain
        end
        totalDrain = totalDrain * NinjaLineages.Skills.getDrainReduction(skillLevel)
        if data.isMeditating then totalDrain = totalDrain * Balance.Chakra.MEDITATION_DRAIN_MULTIPLIER end
        chakra = math.max(0, chakra - (totalDrain * elapsed))
        if chakra <= 0 then data.eyePowerActive = false end
    end
    NinjaLineages.Chakra.setChakra(player, chakra)
end

function NinjaLineages.AbilityAuthority.pruneDeadPlayers(deadPlayerIDs)
    if not deadPlayerIDs then return end
    local dead = {}
    for _, id in ipairs(deadPlayerIDs) do
        dead[tostring(id)] = true
    end
    for player in pairs(active) do
        if player and player.getOnlineID and dead[tostring(player:getOnlineID())] then
            active[player] = nil
        end
    end
end

if NinjaLineages.isClient() then
    NinjaLineages.AbilityAuthority.registerEventHandler("stat_restoration_completed", function(args)
        if not args or not args.targetId or not args.messageKey then return end
        local player = getPlayerByOnlineID(args.targetId)
        if player and player.Say then
            player:Say(getText(args.messageKey))
        end
    end)
end

function NinjaLineages.AbilityAuthority.resetPlayerActiveState(player)
    if not player then return end
    local state = active[player]
    if state and state.kamuiUntil then
        state.kamuiUntil = nil
        NinjaLineages.KamuiState.restore(player, state)
    end
    NinjaLineages.BringerOfDarkness.clear(player)
    active[player] = nil
end

local function handlePlayerReset(playerIndex, player)
    if player then
        NinjaLineages.AbilityAuthority.resetPlayerActiveState(player)
    end
end

local function handleCharacterDeath(character)
    if instanceof(character, "IsoPlayer") then
        NinjaLineages.AbilityAuthority.resetPlayerActiveState(character)
    end
end

if Events then
    if Events.OnCreatePlayer then
        NinjaLineages.addEventOnce("shared.abilityExecution.onCreatePlayer", Events.OnCreatePlayer, handlePlayerReset)
    end
    if Events.OnCharacterDeath then
        NinjaLineages.addEventOnce("shared.abilityExecution.onCharacterDeath", Events.OnCharacterDeath, handleCharacterDeath)
    end
end
