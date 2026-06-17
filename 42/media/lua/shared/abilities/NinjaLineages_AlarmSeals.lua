require "NinjaLineages_Traits"
require "NinjaLineages_Balance"
require "NinjaLineages_AbilityAuthority"
require "NinjaLineages_Progression"
require "NinjaLineages_Utils"

NinjaLineages = NinjaLineages or {}
NinjaLineages.AbilityAuthority = NinjaLineages.AbilityAuthority or {}
local Authority = NinjaLineages.AbilityAuthority
local Balance = NinjaLineages.Balance

local ALARM_DATA_KEY = "NinjaLineagesAlarmSeals"

local function alarmRecords()
    return ModData.getOrCreate(ALARM_DATA_KEY)
end

local function alarmKey(x, y, z)
    return tostring(x) .. "," .. tostring(y) .. "," .. tostring(z)
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
    if NinjaLineages.isServer() then
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

function Authority.initAlarmSeals()
    alarmRecords()
end

function Authority.updateAlarmSeals()
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

-- Event registration
if not NinjaLineages.isClient() and Events and Events.OnInitGlobalModData then
    NinjaLineages.addEventOnce("shared.abilityExecution.onInitGlobalModData", Events.OnInitGlobalModData, Authority.initAlarmSeals)
end

-- Register "alarm_seal" ability
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
