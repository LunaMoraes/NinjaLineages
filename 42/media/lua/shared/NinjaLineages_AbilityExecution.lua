require "NinjaLineages_AbilityAuthority"
require "NinjaLineages_Progression"
require "NinjaLineages_Chakra"
require "NinjaLineages_Balance"
require "NinjaLineages_RinneganMechanics"
require "NinjaLineages_Items"

local Authority = NinjaLineages.AbilityAuthority
local Balance = NinjaLineages.Balance
local active = {}
local alarmSeals = {}
local boundZombies = {}
local nextAlarmScanAt = 0

local COMMON = {
    healing = { node = "minor_healing", cost = "STANDARD", cooldown = "STANDARD", key = "common.healing" },
    reinforcement = { node = "physical_reinforcement", cost = "STANDARD", cooldown = "LONG", key = "common.reinforcement" },
    quietstep = { node = "quiet_step", cost = "BASIC", cooldown = "STANDARD", key = "common.quiet_step" },
    focus = { node = "chakra_focus", cost = "BASIC", cooldown = "STANDARD", key = "common.chakra_focus" },
    grip = { node = "chakra_grip", cost = "BASIC", cooldown = "SHORT", key = "common.chakra_grip" },
    bodyflicker = { node = "body_flicker", cost = "ADVANCED", cooldown = "DASH", key = "common.body_flicker" },
}

local TREE = {
    false_sound = { cost = "BASIC", cooldown = "SHORT" },
    veil_presence = { cost = "STANDARD", cooldown = "LONG" },
    killing_intent = { cost = "MAJOR", cooldown = "VERY_LONG" },
    chakra_burst = { cost = "ADVANCED", cooldown = "LONG" },
    pressure_point_pulse = { cost = "ADVANCED", cooldown = "LONG" },
    shadow_close = { cost = "MAJOR", cooldown = "VERY_LONG" },
    chakra_needle = { cost = "STANDARD", cooldown = "SHORT" },
    cell_stimulation = { cost = "STANDARD", cooldown = "LONG" },
    nervous_system_shock = { cost = "ADVANCED", cooldown = "LONG" },
    field_surgery = { cost = "MAJOR", cooldown = "VERY_LONG" },
    bleeding_suppression = { cost = "MAJOR", cooldown = "VERY_LONG" },
}

local function validateNode(player, nodeId)
    if not NinjaLineages.Progression.isCompleted(player, nodeId) then return false, "not_learned" end
    return true
end

local function validateCommit(player, key, costTier, cooldownTier)
    local onCooldown, remaining = NinjaLineages.Cooldowns.isOnCooldown(player, key)
    if onCooldown then return false, "cooldown", remaining end
    local cost = Balance.getCost(costTier)
    if not NinjaLineages.Chakra.canAffordChakra(player, cost) then return false, "chakra" end
    return true, nil, nil, cost
end

local function commit(player, key, cost, cooldownTier)
    if not NinjaLineages.Chakra.spendChakra(player, cost) then return false end
    NinjaLineages.Cooldowns.set(player, key, Balance.getCooldown(cooldownTier))
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

local function executeCommon(player, id)
    local definition = COMMON[id]
    local learned, reason = validateNode(player, definition.node)
    if not learned then return false, reason end
    local valid, failure, remaining, cost = validateCommit(player, definition.key, definition.cost, definition.cooldown)
    if not valid then return false, failure, remaining end

    local data = NinjaLineages.getNLData(player)
    if id == "healing" then
        local part = mostDamagedPart(player)
        if not part then return false, "no_wounds" end
        local healing = Balance.getHealing(Balance.getJutsu("MINOR_HEALING").healing)
        local changed = NinjaLineages.Utils.Healing.healPart(player:getBodyDamage(), part, {
            health = healing.health, scratch = healing.wound, cut = healing.wound,
        })
        if not changed then return false, "no_wounds" end
    elseif id == "focus" then
        local stats = player:getStats()
        local mastery = Balance.getMastery(Balance.getJutsu("CHAKRA_FOCUS").mastery)
        local effectiveness = NinjaLineages.Skills.getJutsuEffectiveness(NinjaLineages.Skills.getJutsuProwessLevel(player))
        stats:set(CharacterStat.PANIC, math.max(0, stats:get(CharacterStat.PANIC) - mastery * effectiveness * 100))
        stats:set(CharacterStat.STRESS, math.max(0, stats:get(CharacterStat.STRESS) - mastery * effectiveness))
    elseif id == "bodyflicker" then
        local distance = Balance.getRadius(Balance.getJutsu("BODY_FLICKER").distance)
        local x, y = projectedPoint(player, distance)
        local square = getCell():getGridSquare(x, y, player:getZ())
        if not square or not player:getCurrentSquare() or square:isBlockedTo(player:getCurrentSquare()) then
            return false, "invalid_target"
        end
        player:setX(x)
        player:setY(y)
    else
        local configKey = ({
            reinforcement = "PHYSICAL_REINFORCEMENT",
            quietstep = "QUIET_STEP",
            grip = "CHAKRA_GRIP",
        })[id]
        local field = ({
            reinforcement = "reinforcementEndTime",
            quietstep = "quietStepEndTime",
            grip = "chakraGripEndTime",
        })[id]
        local duration = Balance.getDuration(Balance.getJutsu(configKey).duration)
            * NinjaLineages.Skills.getJutsuDuration(NinjaLineages.Skills.getJutsuProwessLevel(player))
        data[field] = NinjaLineages.Utils.Time.cooldownNowMs() + duration
    end

    commit(player, definition.key, cost, definition.cooldown)
    NinjaLineages.transmitPlayerData(player)
    return true
end

for id in pairs(COMMON) do
    local actionId = id
    Authority.register(actionId, function(player) return executeCommon(player, actionId) end)
end

local function executeTree(player, id)
    local learned, reason = validateNode(player, id)
    if not learned then return false, reason end
    local definition = TREE[id]
    local key = "tree." .. id
    local valid, failure, remaining, cost = validateCommit(player, key, definition.cost, definition.cooldown)
    if not valid then return false, failure, remaining end
    local config = Balance.getJutsu(string.upper(id))
    local data = NinjaLineages.getNLData(player)

    if id == "false_sound" or id == "veil_presence" then
        local radius = Balance.getRadius(config.radius)
        local x, y = projectedPoint(player, radius)
        addSound(player, x, y, player:getZ(), radius, radius)
        if id == "veil_presence" then
            local duration = Balance.getDuration(config.duration)
            local square = player:getSquare()
            if square and not square:isOutside() then duration = duration + Balance.getDuration("STANDARD_MS") end
            data.veilPresenceEndTime = NinjaLineages.Utils.Time.cooldownNowMs() + duration
        end
    elseif id == "killing_intent" then
        for _, entry in ipairs(NinjaLineages.Utils.Zombies.collectInRadius(player, Balance.getRadius(config.radius))) do
            NinjaLineages.Utils.Combat.applyControlTier(entry.zombie, config.control)
        end
    elseif id == "pressure_point_pulse" then
        local primary = NinjaLineages.Utils.Zombies.getFacingTarget(player, config.targeting)
        if not primary then return false, "no_target" end
        local targeting = Balance.getTargeting(config.targeting)
        local count = 0
        for _, entry in ipairs(NinjaLineages.Utils.Zombies.collectInRadius(primary, targeting.clusterRadius)) do
            if count >= targeting.maxTargets then break end
            NinjaLineages.Utils.Combat.applyZombieDamage(player, entry.zombie, Balance.rollDamage(config.damage))
            NinjaLineages.Utils.Combat.applyControlTier(entry.zombie, config.control)
            count = count + 1
        end
    elseif id == "shadow_close" then
        local target = NinjaLineages.Utils.Zombies.getFacingTarget(player, config.targeting)
        if not target then return false, "no_target" end
        local originX, originY = player:getX(), player:getY()
        local dx, dy = target:getX() - originX, target:getY() - originY
        local length = math.sqrt(dx * dx + dy * dy)
        local distance = math.min(length, Balance.getRadius(config.distance))
        if length > 0 then
            local x, y = originX + dx / length * distance, originY + dy / length * distance
            local square = getCell():getGridSquare(x, y, player:getZ())
            if not square or not player:getCurrentSquare() or square:isBlockedTo(player:getCurrentSquare()) then
                return false, "invalid_target"
            end
            player:setX(x)
            player:setY(y)
        end
        local radius = Balance.getRadius(config.decoyRadius)
        addSound(player, originX, originY, player:getZ(), radius, radius)
        NinjaLineages.Utils.Combat.applyControlTier(target, "GENIN")
    elseif id == "cell_stimulation" then
        local healing = Balance.getHealing(config.healing)
        local stats = player:getStats()
        stats:set(CharacterStat.FATIGUE, math.max(0, stats:get(CharacterStat.FATIGUE) - healing.fatigue))
        local parts = player:getBodyDamage():getBodyParts()
        for i = 0, parts:size() - 1 do
            local part = parts:get(i)
            pcall(function() part:setAdditionalPain(math.max(0, part:getAdditionalPain() - healing.pain)) end)
        end
    elseif id == "field_surgery" then
        local part = mostDamagedPart(player)
        if not part then return false, "no_wounds" end
        local healing = Balance.getHealing(config.healing)
        local changed = NinjaLineages.Utils.Healing.healPart(player:getBodyDamage(), part, {
            health = healing.health, bleeding = healing.wound, scratch = healing.wound,
            cut = healing.wound, deepWound = healing.wound, burn = healing.wound, fracture = healing.wound,
        })
        if not changed then return false, "no_wounds" end
    elseif id == "bleeding_suppression" then
        data.bleedingSuppressionEndTime = NinjaLineages.Utils.Time.cooldownNowMs()
            + Balance.getDuration(config.duration)
    else
        local target = NinjaLineages.Utils.Zombies.getFacingTarget(player, config.targeting)
        if not target then return false, "no_target" end
        NinjaLineages.Utils.Combat.applyZombieDamage(player, target, Balance.rollDamage(config.damage))
        NinjaLineages.Utils.Combat.applyControlTier(target, config.control)
    end

    commit(player, key, cost, definition.cooldown)
    NinjaLineages.transmitPlayerData(player)
    return true
end

for id in pairs(TREE) do
    local actionId = id
    Authority.register(actionId, function(player) return executeTree(player, actionId) end)
end

Authority.register("shinra_tensei", function(player)
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
end)

Authority.register("binding_roots", function(player)
    if not NinjaLineages.hasSenju(player) then return false, "lineage" end
    local valid, reason, remaining, cost = validateCommit(player, "senju.binding_roots", "MAJOR", "STANDARD")
    if not valid then return false, reason, remaining end
    for _, target in ipairs(NinjaLineages.Utils.Zombies.collectInRadius(player, Balance.getRadius("LARGE"))) do
        NinjaLineages.Utils.Combat.staggerZombie(target.zombie, {
            knockdown = ZombRand(1, 101) <= (target.distance <= NinjaLineages.Constants.Senju.BindingRoots.INNER_RADIUS and 65 or 35),
            position = "FRONT",
        })
        boundZombies[target.zombie] = NinjaLineages.Utils.Time.cooldownNowMs()
            + Balance.getDuration("BRIEF_MS")
    end
    commit(player, "senju.binding_roots", cost, "STANDARD")
    return true
end)

Authority.register("creation_rebirth", function(player)
    if not NinjaLineages.CreationRebirth.isUnlocked(player) then return false, "locked" end
    if NinjaLineages.Chakra.getChakra(player) <= 0 then return false, "chakra" end
    active[player] = active[player] or {}
    active[player].creationRebirthUntil = NinjaLineages.Utils.Time.cooldownNowMs() + Balance.getDuration("SHORT_MS")
    return true
end)

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

Authority.register("sharingan", function(player) return toggleEye(player, "sharingan") end)
Authority.register("byakugan", function(player) return toggleEye(player, "byakugan") end)

Authority.register("kamui", function(player)
    if not NinjaLineages.hasSharingan(player) or not NinjaLineages.getNLData(player).mangekyoUnlocked then
        return false, "locked"
    end
    active[player] = active[player] or {}
    if active[player].kamuiUntil then
        active[player].kamuiUntil = nil
        player:setGhostMode(active[player].wasGhostMode == true)
        player:setGodMod(active[player].wasGodMod == true)
        pcall(function() player:setNoClip(active[player].wasNoClip == true) end)
        return true, nil, nil, { messageKey = "UI_NL_Ability_Kamui_Cancelled" }
    end
    local valid, reason, remaining = validateCommit(player, "uchiha.kamui", "FREE", "STANDARD")
    if not valid then return false, reason, remaining end
    if NinjaLineages.Chakra.getChakra(player) < NinjaLineages.Constants.Uchiha.Kamui.MIN_CHAKRA_GATE then
        return false, "chakra"
    end
    active[player].kamuiUntil = NinjaLineages.Utils.Time.cooldownNowMs() + NinjaLineages.Constants.Uchiha.Kamui.DURATION_MS
    active[player].lastTick = NinjaLineages.Utils.Time.cooldownNowMs()
    local okGhost, wasGhost = pcall(function() return player:isGhostMode() end)
    local okGod, wasGod = pcall(function() return player:isGodMod() end)
    local okNoClip, wasNoClip = pcall(function() return player:isNoClip() end)
    active[player].wasGhostMode = okGhost and wasGhost == true
    active[player].wasGodMod = okGod and wasGod == true
    active[player].wasNoClip = okNoClip and wasNoClip == true
    player:setGhostMode(true)
    player:setGodMod(true)
    pcall(function() player:setNoClip(true) end)
    NinjaLineages.Cooldowns.set(player, "uchiha.kamui", Balance.getCooldown("STANDARD"))
    return true
end)

local function getInventoryItem(player, itemId)
    local inventory = player and player:getInventory()
    if not inventory or not itemId then return nil end
    return inventory:getItemById(tonumber(itemId) or -1)
end

local function getScrollInventory(scroll)
    local ok, inventory = pcall(function() return scroll and scroll:getInventory() end)
    return ok and inventory or nil
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

    local modData = square:getModData()
    modData.NinjaLineages = modData.NinjaLineages or {}
    if modData.NinjaLineages.alarmSeal then return false, "invalid_target" end
    modData.NinjaLineages.alarmSeal = {
        owner = player:getUsername() or "",
        x = square:getX(), y = square:getY(), z = square:getZ(),
    }
    if square.transmitModData then square:transmitModData() end
    alarmSeals[tostring(x) .. "," .. tostring(y) .. "," .. tostring(z)] = square
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
    local now = NinjaLineages.Utils.Time.cooldownNowMs()
    local data = NinjaLineages.getNLData(player)

    if not state.nextAlarmDiscoveryAt or now >= state.nextAlarmDiscoveryAt then
        state.nextAlarmDiscoveryAt = now + NinjaLineages.Constants.Uzumaki.AlarmSeal.DISCOVERY_MS
        local radius = NinjaLineages.Constants.Uzumaki.AlarmSeal.DISCOVERY_RADIUS
        local z = math.floor(player:getZ())
        for x = math.floor(player:getX() - radius), math.floor(player:getX() + radius) do
            for y = math.floor(player:getY() - radius), math.floor(player:getY() + radius) do
                local square = getCell():getGridSquare(x, y, z)
                local squareData = square and square:getModData()
                if squareData and squareData.NinjaLineages and squareData.NinjaLineages.alarmSeal then
                    alarmSeals[tostring(x) .. "," .. tostring(y) .. "," .. tostring(z)] = square
                end
            end
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

    if data.reinforcementEndTime and now < data.reinforcementEndTime then
        local stats = player:getStats()
        local recovery = Balance.getMastery("GENIN") * NinjaLineages.Constants.Chakra.BASE_REGEN_PCT_PER_MINUTE
        stats:set(CharacterStat.FATIGUE, math.max(0, stats:get(CharacterStat.FATIGUE) - recovery))
        stats:set(CharacterStat.ENDURANCE, math.min(1, stats:get(CharacterStat.ENDURANCE) + recovery))
    elseif data.reinforcementEndTime then
        data.reinforcementEndTime = nil
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
        local delta = math.max(0, (now - (state.lastTick or now)) / 1000)
        state.lastTick = now
        local chakra = NinjaLineages.Chakra.getChakra(player)
        chakra = math.max(0, chakra - Balance.getChannelDrain("HIGH") * delta)
        NinjaLineages.Chakra.setChakra(player, chakra)
        if now >= state.kamuiUntil or chakra <= 0 then
            state.kamuiUntil = nil
            player:setGhostMode(state.wasGhostMode == true)
            player:setGodMod(state.wasGodMod == true)
            pcall(function() player:setNoClip(state.wasNoClip == true) end)
        end
    end

    if state.creationRebirthUntil then
        if now >= state.creationRebirthUntil then
            state.creationRebirthUntil = nil
        elseif not state.nextRebirthTick or now >= state.nextRebirthTick then
            state.nextRebirthTick = now + NinjaLineages.Constants.Senju.CreationRebirth.TICK_MS
            local parts = player:getBodyDamage():getBodyParts()
            local step = Balance.getCostStep("HARSH")
            for i = 0, parts:size() - 1 do
                local part = parts:get(i)
                if NinjaLineages.Utils.Healing.getPartSeverity(part) > 0
                        and NinjaLineages.Chakra.getChakra(player) >= step then
                    local changed = NinjaLineages.Utils.Healing.healPart(player:getBodyDamage(), part, {
                        health = 3, bleeding = 4, scratch = 4, cut = 4,
                        deepWound = 3, burn = 2, fracture = 1,
                    })
                    if changed then NinjaLineages.Chakra.spendChakra(player, step) end
                end
            end
        end
    end
end

function NinjaLineages.AbilityAuthority.updateWorld()
    local zombies = getCell() and getCell():getZombieList()
    if not zombies then return end
    local now = NinjaLineages.Utils.Time.cooldownNowMs()
    for zombie, bindUntil in pairs(boundZombies) do
        if not zombie or zombie:isDead() or now >= bindUntil then
            boundZombies[zombie] = nil
        else
            zombie:setVariable("AttackOutcome", "fail")
            pcall(function() zombie:setStaggerBack(true) end)
        end
    end
    local wallNow = NinjaLineages.Utils.Time.nowMs()
    if wallNow < nextAlarmScanAt then return end
    nextAlarmScanAt = wallNow + NinjaLineages.Constants.Uzumaki.AlarmSeal.SCAN_MS
    for key, square in pairs(alarmSeals) do
        local modData = square and square:getModData()
        local seal = modData and modData.NinjaLineages and modData.NinjaLineages.alarmSeal
        if not seal then
            alarmSeals[key] = nil
        else
            for i = 0, zombies:size() - 1 do
                local zombie = zombies:get(i)
                local dx = zombie and zombie:getX() - (square:getX() + 0.5) or 999
                local dy = zombie and zombie:getY() - (square:getY() + 0.5) or 999
                local radius = NinjaLineages.Constants.Uzumaki.AlarmSeal.RADIUS
                if zombie and not zombie:isDead() and dx * dx + dy * dy <= radius * radius then
                    modData.NinjaLineages.alarmSeal = nil
                    if square.transmitModData then square:transmitModData() end
                    alarmSeals[key] = nil
                    local players = getOnlinePlayers and getOnlinePlayers()
                    if players then
                        for playerIndex = 0, players:size() - 1 do
                            local owner = players:get(playerIndex)
                            if owner and (owner:getUsername() or "") == seal.owner then
                                sendServerCommand(owner, "NinjaLineages", "abilityEvent", {
                                    kind = "alarm_triggered",
                                    casterOnlineId = owner:getOnlineID(),
                                })
                                break
                            end
                        end
                    end
                    break
                end
            end
        end
    end
end

function NinjaLineages.AbilityAuthority.everyMinute(player)
    local data = NinjaLineages.getNLData(player)
    local maxChakra = NinjaLineages.Chakra.getMaxChakra(player)
    local chakra = NinjaLineages.Chakra.getChakra(player)
    local skillLevel = NinjaLineages.Skills.getChakraControlLevel(player)
    local regen = maxChakra * NinjaLineages.Constants.Chakra.BASE_REGEN_PCT_PER_MINUTE
        * NinjaLineages.Skills.getRegenMultiplier(skillLevel)
    if data.isMeditating then regen = regen * NinjaLineages.Constants.Chakra.MEDITATION_REGEN_MULTIPLIER end
    chakra = math.min(maxChakra, chakra + regen)

    if data.eyePowerActive then
        local drain = 0
        if NinjaLineages.hasSharingan(player) then
            if data.mangekyoUnlocked then
                drain = NinjaLineages.Constants.Uchiha.MangekyoDrainPerMinute
            else
                drain = NinjaLineages.Constants.Uchiha.SharinganDrainPerMinute[NinjaLineages.getSharinganStage(player)] or 0
            end
        elseif NinjaLineages.hasByakugan(player) then
            drain = NinjaLineages.Constants.Hyuga.ByakuganDrainPerMinute
        end
        drain = drain * NinjaLineages.Skills.getDrainReduction(skillLevel)
        if data.isMeditating then drain = drain * NinjaLineages.Constants.Chakra.MEDITATION_DRAIN_MULTIPLIER end
        chakra = math.max(0, chakra - drain)
        if chakra <= 0 then data.eyePowerActive = false end
    end
    NinjaLineages.Chakra.setChakra(player, chakra)
end
