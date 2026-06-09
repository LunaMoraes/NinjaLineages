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

function NinjaLineages.Utils.Combat.randomDamage(minDamage, maxDamage)
    local damageRoll = ZombRand(0, 1001) / 1000
    return minDamage + (damageRoll * (maxDamage - minDamage))
end

function NinjaLineages.Utils.Combat.applyZombieDamage(player, zombie, damage)
    if not zombie or zombie:isDead() then return end
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
    pcall(function() zombie:setHitForce(opts and opts.force or 2.0) end)
    pcall(function() zombie:reportEvent("wasHit") end)
end


-- 4. Centralized Cooldown Service
NinjaLineages.Cooldowns = NinjaLineages.Cooldowns or {}

function NinjaLineages.Cooldowns.isOnCooldown(player, key)
    local data = NinjaLineages.getNLData(player)
    local cooldowns = data.cooldowns or {}
    local current = NinjaLineages.Utils.Time.nowMs()
    if cooldowns[key] and current < cooldowns[key] then
        return true, math.ceil((cooldowns[key] - current) / 1000)
    end
    return false, 0
end

function NinjaLineages.Cooldowns.set(player, key, durationSeconds)
    local data = NinjaLineages.getNLData(player)
    data.cooldowns = data.cooldowns or {}
    data.cooldowns[key] = NinjaLineages.Utils.Time.nowMs() + (durationSeconds * 1000)
    NinjaLineages.transmitPlayerData(player)
end
