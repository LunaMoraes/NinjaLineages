NinjaLineages = NinjaLineages or {}
NinjaLineages.Utils = NinjaLineages.Utils or {}

-- 1. Inventory Helpers
NinjaLineages.Utils.Inventory = NinjaLineages.Utils.Inventory or {}

function NinjaLineages.Utils.Inventory.findWornItem(player, predicate)
    if not player or not predicate then return nil end
    local wornItems = player:getWornItems()
    if not wornItems then return nil end

    for i = 0, wornItems:size() - 1 do
        local item = wornItems:getItemByIndex(i)
        if item and predicate(item) then
            return item
        end
    end
    return nil
end

function NinjaLineages.Utils.Inventory.wearItem(player, item)
    if not player or not item then return false end
    local ok = pcall(function() player:setWornItem(item:getBodyLocation(), item) end)
    return ok == true
end

function NinjaLineages.Utils.Inventory.removeWornItem(player, item)
    if not player or not item then return false end
    local ok = pcall(function() player:getWornItems():remove(item) end)
    if not ok then
        ok = pcall(function() player:removeWornItem(item, false) end)
        if not ok then
            ok = pcall(function() player:removeWornItem(item) end)
        end
    end
    return ok == true
end

function NinjaLineages.Utils.Inventory.removeInventoryItems(player, itemTypes)
    local inv = player:getInventory()
    if not inv then return false end
    local changed = false
    for _, itemType in ipairs(itemTypes) do
        local item = inv:getItemFromType(itemType)
        while item do
            NinjaLineages.Utils.Inventory.removeWornItem(player, item)
            inv:Remove(item)
            pcall(function() sendRemoveItemFromContainer(inv, item) end)
            changed = true
            item = inv:getItemFromType(itemType)
        end
    end
    return changed
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

function NinjaLineages.Utils.Time.realMilliseconds()
    if getTimestampMs then return getTimestampMs() end
    return 0
end

function NinjaLineages.Utils.Time.gameMinutes()
    local gameTime = getGameTime()
    if gameTime and gameTime.getWorldAgeHours then
        return gameTime:getWorldAgeHours() * 60
    end
    return 0
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

function NinjaLineages.Utils.Zombies.getByOnlineID(onlineID)
    if onlineID == nil then return nil end
    local zombies = getCell() and getCell():getZombieList()
    if not zombies then return nil end
    onlineID = tonumber(onlineID)
    for i = 0, zombies:size() - 1 do
        local zombie = zombies:get(i)
        if zombie and zombie.getOnlineID and zombie:getOnlineID() == onlineID then
            return zombie
        end
    end
    return nil
end

local function canPlayerSeeZombie(player, zombie)
    if not player or not zombie then return false end
    local square = zombie:getSquare()
    if not square then return false end
    local playerNum = player.getPlayerNum and player:getPlayerNum() or 0
    local ok, visible = pcall(function() return square:getCanSee(playerNum) end)
    if ok then return visible == true end
    return false
end

function NinjaLineages.Utils.Zombies.collectClosestVisible(player, radius, maxTargets)
    local targets = {}
    if not player or not radius then return targets end

    for _, entry in ipairs(NinjaLineages.Utils.Zombies.collectInRadius(player, radius)) do
        if canPlayerSeeZombie(player, entry.zombie) then
            table.insert(targets, entry)
        end
    end

    table.sort(targets, function(a, b) return a.distance < b.distance end)

    maxTargets = tonumber(maxTargets)
    if maxTargets and maxTargets > 0 then
        while #targets > maxTargets do table.remove(targets) end
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

function NinjaLineages.Utils.Combat.addWorldSound(player, x, y, z, radius, volume)
    if NinjaLineages.isClient() then
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

function NinjaLineages.Utils.Combat.applyDamageAndControl(player, zombie, damage, controlTier)
    NinjaLineages.Damage.applyZombieDamage(player, zombie, damage)
    NinjaLineages.Utils.Combat.applyControlTier(zombie, controlTier)
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


-- 4.5. Geometry Helpers
NinjaLineages.Utils.Geometry = NinjaLineages.Utils.Geometry or {}

function NinjaLineages.Utils.Geometry.collectConeSquares(player, radius, minDot)
    local squares = {}
    if not player then return squares end
    local forward = player:getForwardDirection()
    if not forward then return squares end
    local fx, fy = forward:getX(), forward:getY()
    local px, py, pz = player:getX(), player:getY(), math.floor(player:getZ())
    local iRadius = math.ceil(radius)
    for dx = -iRadius, iRadius do
        for dy = -iRadius, iRadius do
            if dx ~= 0 or dy ~= 0 then
                local len = math.sqrt(dx*dx + dy*dy)
                if len <= radius then
                    local dot = (dx/len)*fx + (dy/len)*fy
                    if dot >= minDot then
                        table.insert(squares, { x = math.floor(px)+dx, y = math.floor(py)+dy, z = pz })
                    end
                end
            end
        end
    end
    return squares
end


-- 5. Centralized Cooldown Service
NinjaLineages.Cooldowns = NinjaLineages.Cooldowns or {}

function NinjaLineages.Cooldowns.isOnCooldown(player, key)
    local data = NinjaLineages.getNLData(player)
    local cooldowns = data.cooldowns or {}
    local current = NinjaLineages.Utils.Time.gameMinutes()
    if cooldowns[key] and current < cooldowns[key] then
        return true, math.ceil(cooldowns[key] - current)
    end
    return false, 0
end

function NinjaLineages.Cooldowns.set(player, key, durationMinutes)
    local data = NinjaLineages.getNLData(player)
    data.cooldowns = data.cooldowns or {}
    data.cooldowns[key] = NinjaLineages.Utils.Time.gameMinutes() + durationMinutes
    NinjaLineages.transmitPlayerData(player)
end
