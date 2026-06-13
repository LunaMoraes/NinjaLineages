NinjaLineages = NinjaLineages or {}
NinjaLineages.Utils = NinjaLineages.Utils or {}

-- 1. Inventory Helpers
NinjaLineages.Utils.Inventory = NinjaLineages.Utils.Inventory or {}

function NinjaLineages.Utils.Inventory.getWornItemByType(player, itemTypes)
    local wornItems = player:getWornItems()
    if not wornItems then return nil end
    for i = 0, wornItems:size() - 1 do
        local wornItem = wornItems:getItemByIndex(i)
        if wornItem then
            local fullType = wornItem:getFullType()
            local typeName = wornItem:getType()
            for _, itemType in ipairs(itemTypes) do
                if fullType == itemType or typeName == itemType:gsub("^Base%.", "") then
                    return wornItem
                end
            end
        end
    end
    return nil
end

function NinjaLineages.Utils.Inventory.removeInventoryItems(player, itemTypes)
    local inv = player:getInventory()
    if not inv then return end
    for _, itemType in ipairs(itemTypes) do
        local item = inv:getItemFromType(itemType)
        while item do
            inv:Remove(item)
            pcall(function() sendRemoveItemFromContainer(inv, item) end)
            item = inv:getItemFromType(itemType)
        end
    end
end

function NinjaLineages.Utils.Inventory.getFirstInventoryItem(player, fullType)
    local inv = player and player:getInventory()
    if not inv then return nil end
    return inv:getItemFromType(fullType)
end

function NinjaLineages.Utils.Inventory.consumeInventoryItem(player, item)
    local inv = player and player:getInventory()
    if not inv or not item then return false end
    inv:Remove(item)
    pcall(function() sendRemoveItemFromContainer(inv, item) end)
    return true
end

function NinjaLineages.Utils.Inventory.moveItemBetweenContainers(item, srcContainer, destContainer)
    if not item or not destContainer then return false end
    if srcContainer then
        srcContainer:Remove(item)
        pcall(function() sendRemoveItemFromContainer(srcContainer, item) end)
    end
    destContainer:AddItem(item)
    pcall(function() sendAddItemToContainer(destContainer, item) end)
    pcall(function() destContainer:setDrawDirty(true) end)
    return true
end


-- 2. Time Helpers
NinjaLineages.Utils.Time = NinjaLineages.Utils.Time or {}

function NinjaLineages.Utils.Time.nowMs()
    if getTimestampMs then return getTimestampMs() end
    return 0
end

function NinjaLineages.Utils.Time.nowSeconds()
    if getTimestamp then return getTimestamp() end
    return math.floor(NinjaLineages.Utils.Time.nowMs() / 1000)
end

function NinjaLineages.Utils.Time.worldAgeHours()
    local gameTime = getGameTime()
    if gameTime and gameTime.getWorldAgeHours then
        return gameTime:getWorldAgeHours()
    end
    return 0
end

function NinjaLineages.Utils.Time.cooldownNowMs()
    return math.floor(NinjaLineages.Utils.Time.worldAgeHours() * 60 * 60 * 1000)
end

function NinjaLineages.Utils.Time.advanceGameplayClock(player)
    local nowWallMs = NinjaLineages.Utils.Time.nowMs()
    local lastWallMs = NinjaLineages.Utils.Time.lastWallMs

    NinjaLineages.Utils.Time.lastWallMs = nowWallMs

    if not lastWallMs or nowWallMs <= lastWallMs then return end

    local gameTime = getGameTime and getGameTime() or nil
    local multiplier = gameTime and gameTime.getMultiplier and gameTime:getMultiplier() or 0

    if not multiplier or multiplier <= 0 then return end

    local rawDeltaMs = nowWallMs - lastWallMs

    -- Drop suspicious gaps from pause, alt-tab, loading, etc.
    if rawDeltaMs > 1000 then return end

    local deltaMs = rawDeltaMs * multiplier

    -- Bootstrap gameplayMs from player data if not set yet
    if not NinjaLineages.Utils.Time.gameplayMs and player then
        local data = NinjaLineages.getNLData(player)
        if data and data.gameplayMs then
            NinjaLineages.Utils.Time.gameplayMs = data.gameplayMs
        end
    end

    NinjaLineages.Utils.Time.gameplayMs = (NinjaLineages.Utils.Time.gameplayMs or 0) + deltaMs

    local data = player and NinjaLineages.getNLData(player)
    if data then
        data.gameplayMs = NinjaLineages.Utils.Time.gameplayMs
    end
end

function NinjaLineages.Utils.Time.nowGameMs(player)
    if not NinjaLineages.Utils.Time.gameplayMs then
        local p = player
        if not p and getSpecificPlayer then
            p = getSpecificPlayer(0)
        end
        local data = p and NinjaLineages.getNLData(p)
        if data and data.gameplayMs then
            NinjaLineages.Utils.Time.gameplayMs = data.gameplayMs
        end
    end
    return NinjaLineages.Utils.Time.gameplayMs or 0
end


-- 3. Zombie/Combat Helpers
NinjaLineages.Utils.Zombies = NinjaLineages.Utils.Zombies or {}
NinjaLineages.Utils.Combat = NinjaLineages.Utils.Combat or {}

function NinjaLineages.Utils.Zombies.collectInRadius(player, radius)
    local targets = {}
    local zombies = getCell() and getCell():getZombieList()
    if not zombies then return targets end
    for i = 0, zombies:size() - 1 do
        local zombie = zombies:get(i)
        if zombie and not zombie:isDead() then
            local distance = zombie:DistTo(player)
            if distance <= radius then
                table.insert(targets, { zombie = zombie, distance = distance })
            end
        end
    end
    return targets
end

function NinjaLineages.Utils.Zombies.collectInFacingCone(player, targetingTier)
    local config = NinjaLineages.Balance.getTargeting(targetingTier)
    local targets = {}
    if not player or not config then return targets end
    local forward = player:getForwardDirection()
    if not forward then return targets end

    for _, entry in ipairs(NinjaLineages.Utils.Zombies.collectInRadius(player, config.range)) do
        local zombie = entry.zombie
        local dx = zombie:getX() - player:getX()
        local dy = zombie:getY() - player:getY()
        local length = math.sqrt((dx * dx) + (dy * dy))
        if length > 0 then
            local dot = ((dx / length) * forward:getX()) + ((dy / length) * forward:getY())
            if dot >= config.minDot then table.insert(targets, entry) end
        end
    end

    table.sort(targets, function(a, b) return a.distance < b.distance end)
    while #targets > config.maxTargets do table.remove(targets) end
    return targets
end

function NinjaLineages.Utils.Zombies.getFacingTarget(player, targetingTier)
    local targets = NinjaLineages.Utils.Zombies.collectInFacingCone(player, targetingTier)
    return targets[1] and targets[1].zombie or nil
end

function NinjaLineages.Utils.Combat.randomDamage(minDamage, maxDamage)
    local damageRoll = ZombRand(0, 1001) / 1000
    return minDamage + (damageRoll * (maxDamage - minDamage))
end

function NinjaLineages.Utils.Combat.applyZombieDamage(player, zombie, damage)
    if not zombie or zombie:isDead() then return end
    if isClient and isClient() then
        return false
    end

    pcall(function() zombie:setAttackedBy(player) end)
    local ok, health = pcall(function() return zombie:getHealth() end)
    if ok and health then
        local newHealth = math.max(0, health - damage)
        pcall(function() zombie:setHealth(newHealth) end)
        if newHealth <= 0 then
            pcall(function() zombie:Kill(player) end)
        end
    end
end

function NinjaLineages.Utils.Combat.addWorldSound(player, x, y, z, radius, volume)
    if isClient and isClient() then
        return false
    end
    addSound(player, x, y, z, radius, volume)
end

function NinjaLineages.Utils.Combat.failZombieAttack(zombie)
    if zombie then
        zombie:setVariable("AttackOutcome", "fail")
    end
end

function NinjaLineages.Utils.Combat.staggerZombie(zombie, opts)
    if not zombie or zombie:isDead() then return end
    zombie:setVariable("AttackOutcome", "fail")
    zombie:setStaggerBack(true)
    if opts and opts.knockdown then
        zombie:setKnockedDown(true)
    end
    pcall(function() zombie:setHitReaction("") end)
    pcall(function() zombie:setPlayerAttackPosition(opts and opts.position or "FRONT") end)
    pcall(function() zombie:reportEvent("wasHit") end)
end

function NinjaLineages.Utils.Combat.applyControlTier(zombie, tier)
    if NinjaLineages.Balance.getMastery(tier) <= 0 then return end
    NinjaLineages.Utils.Combat.staggerZombie(zombie, {
        knockdown = tier == "JONIN",
    })
end


-- 4. Body Damage Helpers
NinjaLineages.Utils.Healing = NinjaLineages.Utils.Healing or {}

local function getBodyPartValue(bodypart, valueName)
    local ok, value = pcall(function()
        if valueName == "health" then return bodypart:getHealth() end
        if valueName == "bleeding" then return bodypart:getBleedingTime() end
        if valueName == "scratch" then return bodypart:getScratchTime() end
        if valueName == "cut" then return bodypart:getCutTime() end
        if valueName == "deepWound" then return bodypart:getDeepWoundTime() end
        if valueName == "burn" then return bodypart:getBurnTime() end
        if valueName == "fracture" then return bodypart:getFractureTime() end
        return nil
    end)
    if ok and type(value) == "number" then
        return value
    end
    return nil
end

local function getBodyPartFlag(bodypart, flagName)
    local ok, value = pcall(function()
        if flagName == "glass" then return bodypart:haveGlass() end
        if flagName == "bullet" then return bodypart:haveBullet() end
        return false
    end)
    return ok and value == true
end

local function clearResolvedWound(bodypart, woundName)
    return pcall(function()
        if woundName == "bleeding" then
            bodypart:setBleeding(false)
        elseif woundName == "scratch" then
            bodypart:setScratched(false, true)
        elseif woundName == "cut" then
            bodypart:setCut(false)
        elseif woundName == "deepWound" then
            bodypart:setDeepWounded(false)
        end
    end)
end

local function reduceBodyPartTimer(bodypart, woundName, amount, clearAtFullHealth)
    if not amount or amount <= 0 then return false end

    local current = getBodyPartValue(bodypart, woundName)
    if not current or current <= 0 then return false end

    local nextValue = math.max(0, current - amount)
    local isSurfaceWound = woundName == "scratch" or woundName == "cut"
    if clearAtFullHealth and isSurfaceWound then
        nextValue = 0
    end

    local ok = pcall(function()
        if woundName == "bleeding" then bodypart:setBleedingTime(nextValue) end
        if woundName == "scratch" then bodypart:setScratchTime(nextValue) end
        if woundName == "cut" then bodypart:setCutTime(nextValue) end
        if woundName == "deepWound" then bodypart:setDeepWoundTime(nextValue) end
        if woundName == "burn" then bodypart:setBurnTime(nextValue) end
        if woundName == "fracture" then bodypart:setFractureTime(nextValue) end
    end)
    if not ok then return false end

    local applied = getBodyPartValue(bodypart, woundName)
    if not applied or applied >= current then return false end

    if applied <= 0 then
        clearResolvedWound(bodypart, woundName)
    end
    return true
end

function NinjaLineages.Utils.Healing.getPartSeverity(bodypart)
    if not bodypart then return 0 end

    local health = getBodyPartValue(bodypart, "health")
    local severity = health and math.max(0, 100.0 - health) or 0
    local woundNames = { "bleeding", "scratch", "cut", "deepWound", "burn", "fracture" }

    for _, woundName in ipairs(woundNames) do
        severity = math.max(severity, getBodyPartValue(bodypart, woundName) or 0)
    end
    if getBodyPartFlag(bodypart, "glass") or getBodyPartFlag(bodypart, "bullet") then
        severity = math.max(severity, 1)
    end
    return severity
end

function NinjaLineages.Utils.Healing.healPart(bodyDamage, bodypart, options)
    if not bodyDamage or not bodypart or not options then return false end

    local changed = false
    local health = getBodyPartValue(bodypart, "health")
    local healthAmount = options.health or 0

    if health and health < 100 and healthAmount > 0 then
        local ok = pcall(function() bodypart:AddHealth(healthAmount) end)
        local nextHealth = getBodyPartValue(bodypart, "health")
        changed = ok and nextHealth ~= nil and nextHealth > health
    end

    if not changed and health and health < 100 and healthAmount > 0 then
        local before = nil
        pcall(function() before = bodyDamage:getOverallBodyHealth() end)
        local ok = pcall(function() bodyDamage:AddGeneralHealth(healthAmount) end)
        local after = nil
        pcall(function() after = bodyDamage:getOverallBodyHealth() end)
        changed = ok and before ~= nil and after ~= nil and after > before
    end

    local currentHealth = getBodyPartValue(bodypart, "health")
    local clearAtFullHealth = currentHealth ~= nil and currentHealth >= 100
    local woundNames = { "bleeding", "scratch", "cut", "deepWound", "burn", "fracture" }

    for _, woundName in ipairs(woundNames) do
        changed = reduceBodyPartTimer(
            bodypart,
            woundName,
            options[woundName],
            clearAtFullHealth
        ) or changed
    end

    currentHealth = getBodyPartValue(bodypart, "health")
    if currentHealth and currentHealth >= 100 then
        local removedForeignObject = false
        if getBodyPartFlag(bodypart, "glass") then
            removedForeignObject = pcall(function() bodypart:setHaveGlass(false) end) or removedForeignObject
        end
        if getBodyPartFlag(bodypart, "bullet") then
            removedForeignObject = pcall(function() bodypart:setHaveBullet(false, 0) end) or removedForeignObject
        end
        if removedForeignObject then
            changed = true
            pcall(function() bodypart:setAdditionalPain(0) end)
            pcall(function() bodypart:setDeepWoundTime(0) end)
            pcall(function() bodypart:setDeepWounded(false) end)
            pcall(function() bodypart:setBleedingTime(0) end)
            pcall(function() bodypart:setBleeding(false) end)
            if syncBodyPart then
                pcall(function() syncBodyPart(bodypart, 0x404e0108) end)
            end
        end
    end

    pcall(function() bodyDamage:calculateOverallHealth() end)
    return changed
end


-- 5. Centralized Cooldown Service
NinjaLineages.Cooldowns = NinjaLineages.Cooldowns or {}

function NinjaLineages.Cooldowns.isOnCooldown(player, key)
    local data = NinjaLineages.getNLData(player)
    if data.cooldownSchema ~= 2 then
        data.cooldowns = {}
        data.cooldownSchema = 2
        NinjaLineages.transmitPlayerData(player)
    end
    local cooldowns = data.cooldowns or {}
    local current = NinjaLineages.Utils.Time.cooldownNowMs()
    if cooldowns[key] and current < cooldowns[key] then
        return true, math.ceil((cooldowns[key] - current) / 1000)
    end
    return false, 0
end

function NinjaLineages.Cooldowns.set(player, key, durationSeconds)
    local data = NinjaLineages.getNLData(player)
    if data.cooldownSchema ~= 2 then
        data.cooldowns = {}
        data.cooldownSchema = 2
    end
    data.cooldowns = data.cooldowns or {}
    data.cooldowns[key] = NinjaLineages.Utils.Time.cooldownNowMs() + (durationSeconds * 1000)
    NinjaLineages.transmitPlayerData(player)
end
