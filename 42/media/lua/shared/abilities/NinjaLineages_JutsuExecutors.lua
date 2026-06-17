require "NinjaLineages_Traits"
require "NinjaLineages_Balance"
require "NinjaLineages_AbilityAuthority"
require "NinjaLineages_JutsuCatalog"
require "NinjaLineages_RinneganMechanics"
require "NinjaLineages_Utils"
require "lineages/NinjaLineages_KamuiState"
require "disciplines/NinjaLineages_ScrollUtils"

NinjaLineages = NinjaLineages or {}
NinjaLineages.AbilityAuthority = NinjaLineages.AbilityAuthority or {}
NinjaLineages.AbilityExecution = NinjaLineages.AbilityExecution or {}
NinjaLineages.AbilityExecution.active = NinjaLineages.AbilityExecution.active or {}
NinjaLineages.AbilityExecution.boundZombies = NinjaLineages.AbilityExecution.boundZombies or {}
NinjaLineages.AbilityExecution.sharinganRolls = NinjaLineages.AbilityExecution.sharinganRolls or {}

local Authority = NinjaLineages.AbilityAuthority
local Balance = NinjaLineages.Balance
local Catalog = NinjaLineages.JutsuCatalog

local active = NinjaLineages.AbilityExecution.active
local boundZombies = NinjaLineages.AbilityExecution.boundZombies
local sharinganRolls = NinjaLineages.AbilityExecution.sharinganRolls

local specializedExecutors = {}
local KAMUI_SP_STEP_DISTANCE = 0.055
local kamuiMoveVector = Vector2.new()

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

local function refreshOdorMask(item)
    if not item then return end
    pcall(function()
        if item:getConditionMax() and item:getConditionMax() > 0 then
            item:setCondition(item:getConditionMax())
        end
    end)
    pcall(function() item:setUsedDelta(1.0) end)
end

function NinjaLineages.AbilityExecution.wearOdorMask(player, data)
    local inv = player:getInventory()
    if not inv then return end

    if data.odorMaskItemId then
        local trackedItem = inv:getItemById(data.odorMaskItemId)
        if trackedItem and trackedItem:getFullType() == "Base.NL_OdorConditioningMask" then
            refreshOdorMask(trackedItem)
            NinjaLineages.Utils.Inventory.wearItem(player, trackedItem)
            return
        end
    end
    
    local wornItem = NinjaLineages.Utils.Inventory.findWornItem(player, function(item)
        return item:getFullType() == "Base.NL_OdorConditioningMask"
    end)
    if wornItem then
        refreshOdorMask(wornItem)
        NinjaLineages.Utils.Inventory.wearItem(player, wornItem)
        data.odorMaskItemId = wornItem:getID()
        return
    end
    
    local item = inv:AddItem("Base.NL_OdorConditioningMask")
    if item then
        refreshOdorMask(item)
        NinjaLineages.Utils.Inventory.wearItem(player, item)
        data.odorMaskItemId = item:getID()
    end
end

function NinjaLineages.AbilityExecution.removeOdorMask(player, data)
    local inv = player:getInventory()
    if inv then
        local wornItem = NinjaLineages.Utils.Inventory.findWornItem(player, function(item)
            return item:getFullType() == "Base.NL_OdorConditioningMask"
        end)
        if wornItem then
            NinjaLineages.Utils.Inventory.removeWornItem(player, wornItem)
        end
        local item = data.odorMaskItemId and inv:getItemById(data.odorMaskItemId) or nil
        if item then
            NinjaLineages.Utils.Inventory.removeWornItem(player, item)
            inv:Remove(item)
            pcall(function() sendRemoveItemFromContainer(inv, item) end)
        else
            local items = inv:getItems()
            if items then
                for i = 0, items:size() - 1 do
                    local it = items:get(i)
                    if it and it:getFullType() == "Base.NL_OdorConditioningMask" then
                        NinjaLineages.Utils.Inventory.removeWornItem(player, it)
                        inv:Remove(it)
                        pcall(function() sendRemoveItemFromContainer(inv, it) end)
                        break
                    end
                end
            end
        end
    end
    data.odorMaskItemId = nil
end

specializedExecutors.corpse_odor_conditioning = function(player, definition)
    local validRequirements, requirementReason = Catalog.checkRequirements(player, definition)
    if not validRequirements then return false, requirementReason end
    local data = NinjaLineages.getNLData(player)
    if not data.corpseOdorConditioningActive and NinjaLineages.Chakra.getChakra(player) <= 0 then
        return false, "chakra"
    end
    data.corpseOdorConditioningActive = not data.corpseOdorConditioningActive
    
    if data.corpseOdorConditioningActive then
        NinjaLineages.AbilityExecution.wearOdorMask(player, data)
    else
        NinjaLineages.AbilityExecution.removeOdorMask(player, data)
    end
    
    NinjaLineages.transmitPlayerData(player)
    return true, nil, nil, {
        messageKey = data.corpseOdorConditioningActive and "UI_NL_Ability_CorpseOdorConditioning_Cast" or "UI_NL_Ability_CorpseOdorConditioning_Deactivated"
    }
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
    local state = active[player]

    if state.kamuiUntil then
        state.kamuiUntil = nil
        NinjaLineages.KamuiState.restore(player, state)
        NinjaLineages.Cooldowns.set(player, cooldownKey(definition), resolved.cooldown)
        return true, nil, nil, { messageKey = "UI_NL_Ability_Kamui_Cancelled" }
    end

    local valid, reason, remaining = validateCommit(player, definition, resolved)
    if not valid then return false, reason, remaining end

    if NinjaLineages.Chakra.getChakra(player) < resolved.minimumChakra then
        return false, "chakra"
    end

    local now = NinjaLineages.Utils.Time.gameMinutes()
    state.kamuiUntil = now + resolved.duration
    state.lastUpdateAt = now

    for k, v in pairs(NinjaLineages.KamuiState.save(player)) do state[k] = v end
    NinjaLineages.KamuiState.applyFlags(player)

    return true
end

function NinjaLineages.AbilityAuthority.updateLocalKamuiPhaseMovement(player)
    if not player or NinjaLineages.isClient() or NinjaLineages.isServer() then return end
    local state = active[player]
    if not state or not state.kamuiUntil or player:isDead() or player:getVehicle() then return end

    local direction = player:getInputMoveVector(kamuiMoveVector)
    if not direction then return end
    local inputX, inputY = direction:getX(), direction:getY()
    local dx = inputY + inputX
    local dy = inputY - inputX
    local lengthSquared = dx * dx + dy * dy
    if lengthSquared <= 0.0001 then return end

    local length = math.sqrt(lengthSquared)
    dx, dy = dx / length, dy / length

    local blocked = (dx < 0 and player:isCollidedW())
        or (dx > 0 and player:isCollidedE())
        or (dy < 0 and player:isCollidedN())
        or (dy > 0 and player:isCollidedS())
    if not blocked then return end

    local nextX = player:getX() + dx * KAMUI_SP_STEP_DISTANCE
    local nextY = player:getY() + dy * KAMUI_SP_STEP_DISTANCE
    local z = player:getZ()
    local targetSquare = getCell() and getCell():getGridSquare(nextX, nextY, z)
    if not targetSquare or not targetSquare:TreatAsSolidFloor() then return end

    NinjaLineages.KamuiState.placePhasedPlayer(player, nextX, nextY, z)
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

local function validateNode(player, nodeId)
    if not NinjaLineages.Progression.isCompleted(player, nodeId) then
        return false, "not_learned"
    end
    return true
end

Authority.register("storage_seal", function(player, args)
    local learned, reason = validateNode(player, "storage_seal")
    if not learned then return false, reason end
    local backpack = getInventoryItem(player, args.backpackItemId)
    local scroll = getInventoryItem(player, args.scrollItemId)
    if not backpack or not scroll or scroll:getFullType() ~= "Base.NL_SealedScroll" then
        return false, "invalid_item"
    end
    local scrollInventory = NinjaLineages.ScrollUtils.getScrollInventory(scroll)
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
    local scrollInventory = NinjaLineages.ScrollUtils.getScrollInventory(scroll)
    if not scrollInventory or scrollInventory:getItems():size() ~= 1 then return false, "invalid_item" end
    local backpack = scrollInventory:getItems():get(0)
    if not NinjaLineages.Utils.Inventory.moveItemBetweenContainers(
            backpack, scrollInventory, player:getInventory()) then
        return false, "invalid_item"
    end
    return true
end)
