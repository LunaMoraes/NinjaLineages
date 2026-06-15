require "NinjaLineages_AbilityAuthority"
require "NinjaLineages_Progression"
require "NinjaLineages_Chakra"
require "NinjaLineages_Balance"
require "NinjaLineages_JutsuCatalog"
require "NinjaLineages_RinneganMechanics"
require "NinjaLineages_Items"

local Authority = NinjaLineages.AbilityAuthority
local Balance = NinjaLineages.Balance
local Catalog = NinjaLineages.JutsuCatalog
local active = {}
local boundZombies = {}
local specializedExecutors = {}
local ALARM_DATA_KEY = "NinjaLineagesAlarmSeals"

local function cooldownKey(definition)
    return Catalog.getCooldownKey(definition)
end

local function validateCommit(player, definition, resolved)
    local key = cooldownKey(definition)
    local onCooldown, remaining = NinjaLineages.Cooldowns.isOnCooldown(player, key)
    if onCooldown then return false, "cooldown", remaining end
    local cost = resolved.cost or 0
    if not NinjaLineages.Chakra.canAffordChakra(player, cost) then return false, "chakra" end
    return true, nil, nil, cost
end

local function commit(player, definition, resolved, cost)
    if not NinjaLineages.Chakra.spendChakra(player, cost) then return false end
    if resolved.cooldown and resolved.cooldown > 0 then
        NinjaLineages.Cooldowns.set(player, cooldownKey(definition), resolved.cooldown)
    end
    return true
end

local function mostDamagedPart(player)
    local parts = player:getBodyDamage() and player:getBodyDamage():getBodyParts()
    local result, severity = nil, 0
    if not parts then return nil end
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        local value = NinjaLineages.Utils.Healing.getPartSeverity(part)
        if value > severity then result, severity = part, value end
    end
    return result
end

local function projectedPoint(player, distance)
    local forward = player:getForwardDirection()
    if not forward then return player:getX(), player:getY() end
    return player:getX() + forward:getX() * distance, player:getY() + forward:getY() * distance
end

local function rollDamage(resolved)
    local damage = resolved.damage
    if not damage then return 0 end
    if type(damage) == "number" then return damage end
    if damage.tier then return Balance.rollDamage(damage.tier) end
    local minimum, maximum = tonumber(damage.min) or 0, tonumber(damage.max) or 0
    return minimum + ((ZombRand(0, 1001) / 1000) * (maximum - minimum))
end

local function executeGenericEffect(player, definition, resolved)
    local effect = definition.effect
    local data = NinjaLineages.getNLData(player)
    if effect.kind == "heal_most_damaged" then
        local part = mostDamagedPart(player)
        if not part then return false, "no_wounds" end
        local values = {}
        for _, field in ipairs(effect.fields or {}) do
            values[field] = field == "health" and resolved.healing.health or resolved.healing.wound
        end
        local changed = NinjaLineages.Utils.Healing.healPart(player:getBodyDamage(), part, values)
        if not changed then return false, "no_wounds" end
    elseif effect.kind == "restore_focus" then
        local stats = player:getStats()
        local effectiveness = NinjaLineages.Skills.getJutsuEffectiveness(NinjaLineages.Skills.getJutsuProwessLevel(player))
        stats:set(CharacterStat.PANIC, math.max(0, stats:get(CharacterStat.PANIC) - resolved.mastery * effectiveness * 100))
        stats:set(CharacterStat.STRESS, math.max(0, stats:get(CharacterStat.STRESS) - resolved.mastery * effectiveness))
    elseif effect.kind == "forward_movement" then
        local forward = player:getForwardDirection()
        if not forward then return false, "invalid_target" end
        local now = NinjaLineages.Utils.Time.gameMinutes()
        active[player] = active[player] or {}
        active[player].forwardMovement = {
            startedAt = now,
            endsAt = now + resolved.duration,
            directionX = forward:getX(),
            directionY = forward:getY(),
            distance = resolved.distance,
            travelled = 0,
        }
    elseif effect.kind == "timed_state" then
        local duration = resolved.duration
        if effect.durationScale then
            duration = duration * NinjaLineages.Skills.getJutsuDuration(
                NinjaLineages.Skills.getJutsuProwessLevel(player)
            )
        end
        data[effect.stateField] = NinjaLineages.Utils.Time.gameMinutes() + duration
    elseif effect.kind == "world_sound" or effect.kind == "sound_timed_state" then
        local x, y = player:getX(), player:getY()
        if effect.projected or effect.kind == "sound_timed_state" then
            x, y = projectedPoint(player, resolved.radius)
        end
        addSound(player, x, y, player:getZ(), resolved.radius, resolved.radius)
        if effect.kind == "sound_timed_state" then
            local duration = resolved.duration
            local square = player:getSquare()
            if square and not square:isOutside() then
                duration = duration + (resolved.indoorBonusDuration or 0)
            end
            data[effect.stateField] = NinjaLineages.Utils.Time.gameMinutes() + duration
        end
    elseif effect.kind == "area_control" then
        for _, entry in ipairs(NinjaLineages.Utils.Zombies.collectInRadius(player, resolved.radius)) do
            NinjaLineages.Utils.Combat.applyControlTier(entry.zombie, resolved.control.tier)
        end
    elseif effect.kind == "cluster_damage" then
        local primary = NinjaLineages.Utils.Zombies.getFacingTarget(player, resolved.targeting)
        if not primary then return false, "no_target" end
        local count = 0
        for _, entry in ipairs(NinjaLineages.Utils.Zombies.collectInRadius(primary, resolved.targeting.clusterRadius)) do
            if count >= resolved.targeting.maxTargets then break end
            NinjaLineages.Utils.Combat.applyZombieDamage(player, entry.zombie, rollDamage(resolved))
            NinjaLineages.Utils.Combat.applyControlTier(entry.zombie, resolved.control.tier)
            count = count + 1
        end
    elseif effect.kind == "shadow_close" then
        local target = NinjaLineages.Utils.Zombies.getFacingTarget(player, resolved.targeting)
        if not target then return false, "no_target" end
        local originX, originY = player:getX(), player:getY()
        local dx, dy = target:getX() - originX, target:getY() - originY
        local length = math.sqrt(dx * dx + dy * dy)
        local distance = math.min(length, resolved.distance)
        if length > 0 then
            local x, y = originX + dx / length * distance, originY + dy / length * distance
            local square = getCell():getGridSquare(x, y, player:getZ())
            if not square or not player:getCurrentSquare() or square:isBlockedTo(player:getCurrentSquare()) then
                return false, "invalid_target"
            end
            player:setX(x)
            player:setY(y)
        end
        addSound(player, originX, originY, player:getZ(), resolved.decoyRadius, resolved.decoyRadius)
        NinjaLineages.Utils.Combat.applyControlTier(target, resolved.control.tier)
    elseif effect.kind == "cell_stimulation" then
        local stats = player:getStats()
        stats:set(CharacterStat.FATIGUE, math.max(0, stats:get(CharacterStat.FATIGUE) - resolved.healing.fatigue))
        local parts = player:getBodyDamage():getBodyParts()
        for i = 0, parts:size() - 1 do
            local part = parts:get(i)
            pcall(function()
                part:setAdditionalPain(math.max(0, part:getAdditionalPain() - resolved.healing.pain))
            end)
        end
    elseif effect.kind == "target_damage" then
        local target = NinjaLineages.Utils.Zombies.getFacingTarget(player, resolved.targeting)
        if not target then return false, "no_target" end
        NinjaLineages.Utils.Combat.applyZombieDamage(player, target, rollDamage(resolved))
        NinjaLineages.Utils.Combat.applyControlTier(target, resolved.control.tier)
    else
        return false, "server_error"
    end
    return true
end

local function executeCatalogAbility(player, definition)
    local valid, reason = Catalog.checkRequirements(player, definition)
    if not valid then return false, reason end
    local resolved = Catalog.resolveBalance(definition)
    local allowed, failure, remaining, cost = validateCommit(player, definition, resolved)
    if not allowed then return false, failure, remaining end
    local executed, executionReason = executeGenericEffect(player, definition, resolved)
    if not executed then return false, executionReason end
    if not commit(player, definition, resolved, cost) then return false, "chakra" end
    NinjaLineages.transmitPlayerData(player)
    return true
end

specializedExecutors.shinra_tensei = function(player, definition)
    local validRequirements, requirementReason = Catalog.checkRequirements(player, definition)
    if not validRequirements then return false, requirementReason end
    local ok, reason, remaining = NinjaLineages.RinneganMechanics.execute(player)
    if not ok then return false, reason, remaining end
    return true, nil, nil, {
        event = {
            kind = "shinra_tensei_pulse",
            x = player:getX(),
            y = player:getY(),
            z = math.floor(player:getZ()),
        },
    }
end

specializedExecutors.binding_roots = function(player, definition)
    local validRequirements, requirementReason = Catalog.checkRequirements(player, definition)
    if not validRequirements then return false, requirementReason end
    local resolved = Catalog.resolveBalance(definition)
    local valid, reason, remaining, cost = validateCommit(player, definition, resolved)
    if not valid then return false, reason, remaining end
    for _, target in ipairs(NinjaLineages.Utils.Zombies.collectInRadius(player, resolved.radius)) do
        NinjaLineages.Utils.Combat.staggerZombie(target.zombie, {
            knockdown = ZombRand(1, 101) <= (
                target.distance <= resolved.innerRadius
                    and resolved.innerKnockdownChance
                    or resolved.outerKnockdownChance
            ),
            position = "FRONT",
        })
        boundZombies[target.zombie] = NinjaLineages.Utils.Time.gameMinutes()
            + resolved.duration
    end
    commit(player, definition, resolved, cost)
    return true
end

specializedExecutors.creation_rebirth = function(player, definition)
    local validRequirements, requirementReason = Catalog.checkRequirements(player, definition)
    if not validRequirements then return false, requirementReason end
    if NinjaLineages.Chakra.getChakra(player) <= 0 then return false, "chakra" end
    local resolved = Catalog.resolveBalance(definition)
    active[player] = active[player] or {}
    local now = NinjaLineages.Utils.Time.gameMinutes()
    active[player].creationRebirthUntil = now + resolved.duration
    active[player].nextRebirthTick = now
    return true
end

local function toggleEye(player, lineage)
    local check = lineage == "sharingan" and NinjaLineages.hasSharingan or NinjaLineages.hasByakugan
    if not check(player) then return false, "lineage" end
    if lineage == "sharingan" and NinjaLineages.getSharinganStage(player) <= 0 then
        return false, "locked"
    end
    local data = NinjaLineages.getNLData(player)
    if not data.eyePowerActive and NinjaLineages.Chakra.getChakra(player) <= 0 then return false, "chakra" end
    data.eyePowerActive = not data.eyePowerActive
    NinjaLineages.transmitPlayerData(player)
    return true, nil, nil, {
        messageKey = data.eyePowerActive
            and (lineage == "sharingan" and "UI_NL_Ability_Sharingan_Cast" or "UI_NL_Ability_Byakugan_Cast")
            or (lineage == "sharingan" and "UI_NL_Ability_Sharingan_Deactivated" or "UI_NL_Ability_Byakugan_Deactivated"),
        voice = data.eyePowerActive
            and (lineage == "sharingan"
                and NinjaLineages.Constants.Uchiha.Audio.ACTIVATION_VOICE
                or NinjaLineages.Constants.Hyuga.Audio.ACTIVATION_VOICE)
            or nil,
    }
end

local function applyKamuiVisionPenalty(player)
    local data = NinjaLineages.getNLData(player)
    local level = math.min(3, (data.kamuiVisionLevel or 0) + 1)
    data.kamuiVisionLevel = level
    data.kamuiVisionRecoverAt = NinjaLineages.Utils.Time.gameMinutes()
        + NinjaLineages.Constants.Uchiha.Vision.RECOVERY_MINUTES[level]
    NinjaLineages.transmitPlayerData(player)
end

specializedExecutors.sharingan = function(player, definition)
    local validRequirements, requirementReason = Catalog.checkRequirements(player, definition)
    if not validRequirements then return false, requirementReason end
    return toggleEye(player, "sharingan")
end
specializedExecutors.byakugan = function(player, definition)
    local validRequirements, requirementReason = Catalog.checkRequirements(player, definition)
    if not validRequirements then return false, requirementReason end
    return toggleEye(player, "byakugan")
end

specializedExecutors.kamui = function(player, definition)
    local validRequirements, requirementReason = Catalog.checkRequirements(player, definition)
    if not validRequirements then return false, requirementReason end
    local resolved = Catalog.resolveBalance(definition)
    active[player] = active[player] or {}
    if active[player].kamuiUntil then
        active[player].kamuiUntil = nil
        player:setGhostMode(active[player].wasGhostMode == true)
        player:setGodMod(active[player].wasGodMod == true)
        pcall(function() player:setNoClip(active[player].wasNoClip == true) end)
        NinjaLineages.Cooldowns.set(player, cooldownKey(definition), resolved.cooldown)
        return true, nil, nil, { messageKey = "UI_NL_Ability_Kamui_Cancelled" }
    end
    local valid, reason, remaining = validateCommit(player, definition, resolved)
    if not valid then return false, reason, remaining end
    if NinjaLineages.Chakra.getChakra(player) < resolved.minimumChakra then
        return false, "chakra"
    end
    local now = NinjaLineages.Utils.Time.gameMinutes()
    active[player].kamuiUntil = now + resolved.duration
    active[player].lastUpdateAt = now
    local okGhost, wasGhost = pcall(function() return player:isGhostMode() end)
    local okGod, wasGod = pcall(function() return player:isGodMod() end)
    local okNoClip, wasNoClip = pcall(function() return player:isNoClip() end)
    active[player].wasGhostMode = okGhost and wasGhost == true
    active[player].wasGodMod = okGod and wasGod == true
    active[player].wasNoClip = okNoClip and wasNoClip == true
    player:setGhostMode(true)
    player:setGodMod(true)
    pcall(function() player:setNoClip(true) end)
    return true
end

for _, definition in ipairs(Catalog.getSelectable()) do
    local actionDefinition = definition
    if actionDefinition.effect then
        Authority.register(actionDefinition.id, function(player)
            return executeCatalogAbility(player, actionDefinition)
        end)
    else
        local executor = specializedExecutors[actionDefinition.executor]
        if not executor then
            error("[AbilityExecution] Missing specialized executor '" .. tostring(actionDefinition.executor) .. "'")
        end
        Authority.register(actionDefinition.id, function(player, args)
            return executor(player, actionDefinition, args)
        end)
    end
end

local function getInventoryItem(player, itemId)
    local inventory = player and player:getInventory()
    if not inventory or not itemId then return nil end
    return inventory:getItemById(tonumber(itemId) or -1)
end

local function getScrollInventory(scroll)
    local ok, inventory = pcall(function() return scroll and scroll:getInventory() end)
    return ok and inventory or nil
end

local function validateNode(player, nodeId)
    if not NinjaLineages.Progression.isCompleted(player, nodeId) then
        return false, "not_learned"
    end
    return true
end

local function alarmRecords()
    return ModData.getOrCreate(ALARM_DATA_KEY)
end

local function alarmKey(x, y, z)
    return tostring(x) .. "," .. tostring(y) .. "," .. tostring(z)
end

Authority.register("alarm_seal", function(player, args)
    local learned, reason = validateNode(player, "alarm_seal")
    if not learned then return false, reason end
    local x, y, z = tonumber(args.x), tonumber(args.y), tonumber(args.z)
    if not x or not y or not z or math.floor(player:getZ()) ~= math.floor(z) then
        return false, "invalid_target"
    end
    local dx, dy = player:getX() - x, player:getY() - y
    if dx * dx + dy * dy > 9 then return false, "invalid_target" end
    local square = getCell():getGridSquare(x, y, z)
    local seal = NinjaLineages.Utils.Inventory.getFirstInventoryItem(player, "Base.NL_AlarmSeal")
    if not square or not seal then return false, "invalid_item" end
    local cost = Balance.getCost("BASIC")
    if not NinjaLineages.Chakra.canAffordChakra(player, cost) then return false, "chakra" end

    local records = alarmRecords()
    local key = alarmKey(square:getX(), square:getY(), square:getZ())
    if records[key] then return false, "invalid_target" end
    records[key] = {
        owner = player:getUsername() or "",
        x = square:getX(), y = square:getY(), z = square:getZ(),
    }
    if ModData.transmit then ModData.transmit(ALARM_DATA_KEY) end
    NinjaLineages.Utils.Inventory.consumeInventoryItem(player, seal)
    NinjaLineages.Chakra.spendChakra(player, cost)
    return true
end)

Authority.register("storage_seal", function(player, args)
    local learned, reason = validateNode(player, "storage_seal")
    if not learned then return false, reason end
    local backpack = getInventoryItem(player, args.backpackItemId)
    local scroll = getInventoryItem(player, args.scrollItemId)
    if not backpack or not scroll or scroll:getFullType() ~= "Base.NL_SealedScroll" then
        return false, "invalid_item"
    end
    local scrollInventory = getScrollInventory(scroll)
    if not scrollInventory or scrollInventory:getItems():size() > 0 then return false, "invalid_item" end
    local okContainer, isContainer = pcall(function() return backpack:IsInventoryContainer() end)
    if not okContainer or not isContainer then return false, "invalid_item" end
    local cost = Balance.getCost("BASIC")
    if not NinjaLineages.Chakra.canAffordChakra(player, cost) then return false, "chakra" end
    if not NinjaLineages.Utils.Inventory.moveItemBetweenContainers(
            backpack, backpack:getContainer(), scrollInventory) then
        return false, "invalid_item"
    end
    NinjaLineages.Chakra.spendChakra(player, cost)
    return true
end)

Authority.register("storage_unseal", function(player, args)
    local learned, reason = validateNode(player, "storage_seal")
    if not learned then return false, reason end
    local scroll = getInventoryItem(player, args.scrollItemId)
    if not scroll or scroll:getFullType() ~= "Base.NL_SealedScroll" then return false, "invalid_item" end
    local scrollInventory = getScrollInventory(scroll)
    if not scrollInventory or scrollInventory:getItems():size() ~= 1 then return false, "invalid_item" end
    local backpack = scrollInventory:getItems():get(0)
    if not NinjaLineages.Utils.Inventory.moveItemBetweenContainers(
            backpack, scrollInventory, player:getInventory()) then
        return false, "invalid_item"
    end
    return true
end)

local function gentleFist(zombie, attacker, bodyPartType, weapon)
    if not attacker or not zombie or not instanceof(attacker, "IsoPlayer") then return end
    if not NinjaLineages.hasByakugan(attacker) then return end
    if not NinjaLineages.getNLData(attacker).eyePowerActive then return end
    if not weapon or weapon:getType() ~= "BareHands" or zombie:isDead() then return end
    local cost = Balance.getCost("TRIVIAL")
    if not NinjaLineages.Chakra.spendChakra(attacker, cost) then return end
    NinjaLineages.Utils.Combat.staggerZombie(zombie, { knockdown = true, position = "FRONT" })
    NinjaLineages.Utils.Combat.applyZombieDamage(attacker, zombie, Balance.rollDamage("LIGHT"))
end

if not (isClient and isClient()) and Events and Events.OnHitZombie then
    Events.OnHitZombie.Add(gentleFist)
end

local sharinganRolls = {}
local function sharinganEvade(zombie)
    if not zombie or zombie:isDead() then return end
    if zombie:getVariableString("AttackOutcome") ~= "success" then
        sharinganRolls[zombie] = nil
        return
    end
    if sharinganRolls[zombie] then return end
    local player = zombie:getTarget()
    if not player or not instanceof(player, "IsoPlayer") or player:isDead() then return end
    local data = NinjaLineages.getNLData(player)
    if not NinjaLineages.hasSharingan(player) or not data.eyePowerActive then return end
    sharinganRolls[zombie] = true
    if active[player] and active[player].kamuiUntil then
        zombie:setVariable("AttackOutcome", "fail")
        return
    end
    local stage = NinjaLineages.getSharinganStage(player)
    local chance = NinjaLineages.Constants.Uchiha.SharinganDodgeChance[stage] or 0
    if ZombRand(1, 101) <= chance then
        zombie:setVariable("AttackOutcome", "fail")
        sendServerCommand(player, "NinjaLineages", "abilityEvent", {
            kind = "sharingan_evade",
            casterOnlineId = player:getOnlineID(),
        })
    end
end

if not (isClient and isClient()) and Events and Events.OnZombieUpdate then
    Events.OnZombieUpdate.Add(sharinganEvade)
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
    syncTrait("chakraGripEndTime", "addedStrongByJutsu", CharacterTrait.STRONG)
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
            player:setGhostMode(state.wasGhostMode == true)
            player:setGodMod(state.wasGodMod == true)
            pcall(function() player:setNoClip(state.wasNoClip == true) end)
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
end

function NinjaLineages.AbilityAuthority.updateWorld()
    local now = NinjaLineages.Utils.Time.gameMinutes()
    for zombie, bindUntil in pairs(boundZombies) do
        if not zombie or zombie:isDead() or now >= bindUntil then
            boundZombies[zombie] = nil
        else
            zombie:setVariable("AttackOutcome", "fail")
            pcall(function() zombie:setStaggerBack(true) end)
        end
    end
    for zombie, _ in pairs(sharinganRolls) do
        if not zombie or zombie:isDead() then
            sharinganRolls[zombie] = nil
        end
    end
end

function NinjaLineages.AbilityAuthority.initAlarmSeals()
    alarmRecords()
end

local function findAlarmOwner(username)
    local players = getOnlinePlayers and getOnlinePlayers()
    if players then
        for i = 0, players:size() - 1 do
            local player = players:get(i)
            if player and (player:getUsername() or "") == username then return player end
        end
    end
    if getNumActivePlayers and getSpecificPlayer then
        for i = 0, getNumActivePlayers() - 1 do
            local player = getSpecificPlayer(i)
            if player and (player:getUsername() or "") == username then return player end
        end
    end
    return nil
end

local function notifyAlarmOwner(username)
    local owner = findAlarmOwner(username)
    if not owner then return end
    local event = {
        kind = "alarm_triggered",
        casterOnlineId = owner:getOnlineID(),
    }
    if isServer and isServer() then
        sendServerCommand(owner, "NinjaLineages", "abilityEvent", event)
    else
        NinjaLineages.AbilityAuthority.handleEvent(event)
    end
end

local function squareContainsZombieInRadius(square, centerX, centerY, radiusSquared)
    local movingObjects = square and square:getMovingObjects()
    if not movingObjects then return false end
    for i = 0, movingObjects:size() - 1 do
        local object = movingObjects:get(i)
        if object and instanceof(object, "IsoZombie") and not object:isDead() then
            local dx = object:getX() - centerX
            local dy = object:getY() - centerY
            if dx * dx + dy * dy <= radiusSquared then return true end
        end
    end
    return false
end

local function squareIntersectsRadius(x, y, centerX, centerY, radiusSquared)
    local nearestX = math.max(x, math.min(centerX, x + 1))
    local nearestY = math.max(y, math.min(centerY, y + 1))
    local dx, dy = centerX - nearestX, centerY - nearestY
    return dx * dx + dy * dy <= radiusSquared
end

function NinjaLineages.AbilityAuthority.updateAlarmSeals()
    local records = alarmRecords()
    local cell = getCell()
    if not cell then return end
    local radius = NinjaLineages.Constants.Uzumaki.AlarmSeal.RADIUS
    local radiusSquared = radius * radius
    local changed = false

    for key, seal in pairs(records) do
        local loadedSquare = cell:getGridSquare(seal.x, seal.y, seal.z)
        if loadedSquare then
            local centerX, centerY = seal.x + 0.5, seal.y + 0.5
            local triggered = false
            for x = math.floor(centerX - radius), math.floor(centerX + radius) do
                if triggered then break end
                for y = math.floor(centerY - radius), math.floor(centerY + radius) do
                    if squareIntersectsRadius(x, y, centerX, centerY, radiusSquared) then
                        local square = cell:getGridSquare(x, y, seal.z)
                        if squareContainsZombieInRadius(square, centerX, centerY, radiusSquared) then
                            triggered = true
                            break
                        end
                    end
                end
            end
            if triggered then
                local owner = seal.owner
                records[key] = nil
                changed = true
                notifyAlarmOwner(owner)
            end
        end
    end

    if changed and ModData.transmit then ModData.transmit(ALARM_DATA_KEY) end
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

if not (isClient and isClient()) and Events and Events.OnInitGlobalModData then
    Events.OnInitGlobalModData.Add(NinjaLineages.AbilityAuthority.initAlarmSeals)
end

function NinjaLineages.AbilityAuthority.resetPlayerActiveState(player)
    if not player then return end
    active[player] = nil
end

local function handlePlayerReset(playerIndex, player)
    if player then
        NinjaLineages.AbilityAuthority.resetPlayerActiveState(player)
    end
end

if Events then
    if Events.OnCreatePlayer then
        Events.OnCreatePlayer.Add(handlePlayerReset)
    end
    if Events.OnCharacterDeath then
        Events.OnCharacterDeath.Add(function(character)
            if instanceof(character, "IsoPlayer") then
                NinjaLineages.AbilityAuthority.resetPlayerActiveState(character)
            end
        end)
    end
end
