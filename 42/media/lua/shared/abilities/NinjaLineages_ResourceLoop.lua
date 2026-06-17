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

local function applyKamuiVisionPenalty(player)
    local data = NinjaLineages.getNLData(player)
    local level = math.min(3, (data.kamuiVisionLevel or 0) + 1)
    data.kamuiVisionLevel = level
    data.kamuiVisionRecoverAt = NinjaLineages.Utils.Time.gameMinutes()
        + NinjaLineages.Constants.Uchiha.Vision.RECOVERY_MINUTES[level]
    NinjaLineages.transmitPlayerData(player)
end

function NinjaLineages.AbilityAuthority.updatePlayer(player)
    local state = active[player] or {}
    active[player] = state
    local now = NinjaLineages.Utils.Time.gameMinutes()
    local previousUpdateAt = state.lastUpdateAt or now
    state.lastUpdateAt = now
    local data = NinjaLineages.getNLData(player)

    local movement = state.forwardMovement
    if movement then
        local duration = movement.endsAt - movement.startedAt
        local progress = duration > 0
            and math.min(1, math.max(0, (now - movement.startedAt) / duration))
            or 1
        local targetDistance = movement.distance * progress
        local stepDistance = NinjaLineages.Constants.CommonJutsu.Dash.STEP_DISTANCE

        while movement.travelled < targetDistance do
            local distance = math.min(stepDistance, targetDistance - movement.travelled)
            local nextX = player:getX() + (movement.directionX * distance)
            local nextY = player:getY() + (movement.directionY * distance)
            local cell = getCell()
            local currentSquare = cell:getGridSquare(player:getX(), player:getY(), player:getZ())
            local nextSquare = cell:getGridSquare(nextX, nextY, player:getZ())
            if not currentSquare or not nextSquare or nextSquare:isBlockedTo(currentSquare) then
                state.forwardMovement = nil
                break
            end
            player:setX(nextX)
            player:setY(nextY)
            movement.travelled = movement.travelled + distance
        end

        if state.forwardMovement and progress >= 1 then
            state.forwardMovement = nil
        end
    end

    local function syncTrait(endField, addedField, trait)
        if data[endField] and now < data[endField] then
            if not player:hasTrait(trait) then
                player:getCharacterTraits():add(trait)
                data[addedField] = true
            end
        elseif data[endField] then
            if data[addedField] then player:getCharacterTraits():remove(trait) end
            data[endField] = nil
            data[addedField] = nil
        end
    end

    syncTrait("quietStepEndTime", "addedGracefulByJutsu", CharacterTrait.GRACEFUL)
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
        if data.veilAddedGraceful and not (data.quietStepEndTime and now < data.quietStepEndTime) then
            player:getCharacterTraits():remove(CharacterTrait.GRACEFUL)
        end
        if data.veilAddedInconspicuous then
            player:getCharacterTraits():remove(CharacterTrait.INCONSPICUOUS)
        end
        data.veilPresenceEndTime = nil
        data.veilAddedGraceful = nil
        data.veilAddedInconspicuous = nil
    end

    if data.reinforcementEndTime then
        local stats = player:getStats()
        local reinforcement = Catalog.resolveBalance("physical_reinforcement")
        local reinforcementElapsed = math.max(
            0,
            math.min(now, data.reinforcementEndTime) - previousUpdateAt
        )
        local recovery = (reinforcement.recovery or 0)
            * NinjaLineages.Constants.Chakra.BASE_REGEN_PCT_PER_MINUTE
            * reinforcementElapsed
        stats:set(CharacterStat.FATIGUE, math.max(0, stats:get(CharacterStat.FATIGUE) - recovery))
        stats:set(CharacterStat.ENDURANCE, math.min(1, stats:get(CharacterStat.ENDURANCE) + recovery))
        if now >= data.reinforcementEndTime then data.reinforcementEndTime = nil end
    end

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
            local kamuiDef = Catalog.get("kamui")
            local resolved = Catalog.resolveBalance(kamuiDef)
            NinjaLineages.Cooldowns.set(player, Catalog.getCooldownKey(kamuiDef), resolved.cooldown or 24)
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
                    local changed = NinjaLineages.Utils.Healing.healPart(
                        player:getBodyDamage(),
                        part,
                        rebirth.healing
                    )
                    if changed then NinjaLineages.Chakra.spendChakra(player, step) end
                end
            end
            state.nextRebirthTick = state.nextRebirthTick + rebirth.tickInterval
        end
        if now >= state.creationRebirthUntil then
            state.creationRebirthUntil = nil
            state.nextRebirthTick = nil
        end
    end

    if state.calorieControlUntil then
        local calorieDef = Catalog.get("calorie_control")
        local resolved = Catalog.resolveBalance(calorieDef)
        local processUntil = math.min(now, state.calorieControlUntil)

        while state.nextCalorieTick
                and state.nextCalorieTick <= processUntil
                and state.nextCalorieTick < state.calorieControlUntil do

            local stats = player:getStats()
            local currentHunger = stats:get(CharacterStat.HUNGER)
            local currentThirst = stats:get(CharacterStat.THIRST)

            if currentHunger > 0 or currentThirst > 0 then
                local step = resolved.costStep or 5
                if NinjaLineages.Chakra.getChakra(player) >= step then
                    NinjaLineages.Chakra.spendChakra(player, step)

                    local hungerRestore = step * NinjaLineages.Constants.CalorieControl.CHAKRA_TO_HUNGER
                    local thirstRestore = step * NinjaLineages.Constants.CalorieControl.CHAKRA_TO_THIRST

                    stats:set(CharacterStat.HUNGER, math.max(0, currentHunger - hungerRestore))
                    stats:set(CharacterStat.THIRST, math.max(0, currentThirst - thirstRestore))
                else
                    state.calorieControlUntil = now
                    break
                end
            else
                state.calorieControlUntil = now
                break
            end

            state.nextCalorieTick = state.nextCalorieTick + resolved.tickInterval
        end

        if now >= state.calorieControlUntil then
            state.calorieControlUntil = nil
            state.nextCalorieTick = nil
            player:Say(getText("UI_NL_Ability_calorie_control_Deactivated"))
        end
    end

    local visionLevel = data.kamuiVisionLevel or 0
    while visionLevel > 0
            and data.kamuiVisionRecoverAt
            and now >= data.kamuiVisionRecoverAt do
        visionLevel = visionLevel - 1
        data.kamuiVisionLevel = visionLevel
        if visionLevel > 0 then
            data.kamuiVisionRecoverAt = data.kamuiVisionRecoverAt
                + NinjaLineages.Constants.Uchiha.Vision.RECOVERY_MINUTES[visionLevel]
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
    local maxChakra = NinjaLineages.Chakra.getMaxChakra(player)
    local chakra = NinjaLineages.Chakra.getChakra(player)
    local skillLevel = NinjaLineages.Skills.getChakraControlLevel(player)
    local regen = maxChakra * NinjaLineages.Constants.Chakra.BASE_REGEN_PCT_PER_MINUTE
        * NinjaLineages.Skills.getRegenMultiplier(skillLevel)
    if data.isMeditating then regen = regen * NinjaLineages.Constants.Chakra.MEDITATION_REGEN_MULTIPLIER end
    chakra = math.min(maxChakra, chakra + (regen * elapsed))

    if data.eyePowerActive then
        local drain = 0
        if NinjaLineages.hasSharingan(player) then
            local sharingan = Catalog.resolveBalance("sharingan")
            if data.mangekyoUnlocked then
                drain = sharingan.evolvedDrain
            else
                drain = sharingan.sustainedDrains[
                    NinjaLineages.getSharinganStage(player)
                ] or 0
            end
        elseif NinjaLineages.hasByakugan(player) then
            drain = Catalog.resolveBalance("byakugan").sustainedDrain
        end
        drain = drain * NinjaLineages.Skills.getDrainReduction(skillLevel)
        if data.isMeditating then drain = drain * NinjaLineages.Constants.Chakra.MEDITATION_DRAIN_MULTIPLIER end
        chakra = math.max(0, chakra - (drain * elapsed))
        if chakra <= 0 then data.eyePowerActive = false end
    end
    NinjaLineages.Chakra.setChakra(player, chakra)
end

function NinjaLineages.AbilityAuthority.resetPlayerActiveState(player)
    if not player then return end
    local state = active[player]
    if state and state.kamuiUntil then
        state.kamuiUntil = nil
        NinjaLineages.KamuiState.restore(player, state)
    end
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
