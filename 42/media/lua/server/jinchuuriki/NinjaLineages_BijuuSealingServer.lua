require "NinjaLineages_Balance"
require "NinjaLineages_Utils"
require "disciplines/jinchuuriki/NinjaLineages_BijuuDefinitions"
require "disciplines/jinchuuriki/NinjaLineages_BijuuState"
require "disciplines/jinchuuriki/NinjaLineages_BijuuSealing"
require "jinchuuriki/NinjaLineages_BijuuBossServer"
require "jinchuuriki/NinjaLineages_BijuuRegistryServer"
require "jinchuuriki/NinjaLineages_BijuuServerSupport"

NinjaLineages = NinjaLineages or {}
NinjaLineages.BijuuSealingServer = NinjaLineages.BijuuSealingServer or {}

local Server = NinjaLineages.BijuuSealingServer
local Balance = NinjaLineages.Balance
local Definitions = NinjaLineages.BijuuDefinitions
local BijuuState = NinjaLineages.BijuuState
local Sealing = NinjaLineages.BijuuSealing
local BossServer = NinjaLineages.BijuuBossServer
local Registry = NinjaLineages.BijuuRegistryServer
local Support = NinjaLineages.BijuuServerSupport

local activeRituals = {}
local ritualCounter = 1

local function sealingConfig()
    return Balance.Jinchuuriki.Sealing
end

local function isPhysicalBossState(state)
    return state == BijuuState.WILD_ACTIVE or state == BijuuState.BOSS_ACTIVE
end

local function playerOnlineId(player)
    if not player or not player.getOnlineID then return -1 end
    local ok, id = pcall(function() return player:getOnlineID() end)
    return ok and tonumber(id) or -1
end

local function playerNumber(player)
    if not player or not player.getPlayerNum then return -1 end
    local ok, number = pcall(function() return player:getPlayerNum() end)
    return ok and tonumber(number) or -1
end

local function nextRitualId()
    local id = "bijuu_ritual_" .. tostring(ritualCounter)
    ritualCounter = ritualCounter + 1
    return id
end

local function findEmptyVessel(player, requestedId)
    local requested = requestedId ~= nil and tonumber(requestedId) or nil
    if requestedId ~= nil and not requested then return nil end

    if requested then
        for _, item in ipairs(NinjaLineages.Utils.Inventory.collectItems(player)) do
            if Sealing.getVesselItemId(item) == requested then
                return Sealing.isEmptyVessel(item) and item or nil
            end
        end
        return nil
    end

    for _, item in ipairs(NinjaLineages.Utils.Inventory.collectItems(player)) do
        if Sealing.isEmptyVessel(item) then return item end
    end
    return nil
end

local function nearestBossTarget(player)
    local radius = sealingConfig().ACQUISITION_RADIUS
    local nearest, nearestDistance = nil, math.huge
    for _, bijuuId in ipairs(Definitions.Order) do
        local snapshot = BossServer.getActiveBossSnapshot(bijuuId)
        if snapshot and snapshot.runtimeId and (tonumber(snapshot.health) or 0) > 0
                and snapshot.phase ~= "defeated"
                and isPhysicalBossState(Registry.getBijuuState(bijuuId)) then
            local dx = snapshot.x - player:getX()
            local dy = snapshot.y - player:getY()
            local distance = math.sqrt(dx * dx + dy * dy)
            if math.abs((snapshot.z or 0) - player:getZ()) < 1.5
                    and distance <= radius and distance < nearestDistance then
                nearest = snapshot
                nearestDistance = distance
            end
        end
    end
    return nearest
end

local function restoreInventoryItem(player, item, originalContainer)
    if not item then return false end
    local worldItem = item.getWorldItem and item:getWorldItem() or nil
    if worldItem and worldItem.getSquare and worldItem:getSquare() then
        local square = worldItem:getSquare()
        pcall(function() square:transmitRemoveItemFromSquare(worldItem) end)
        pcall(function() square:removeWorldObject(worldItem) end)
        pcall(function() item:setWorldItem(nil) end)
    end

    local destination = originalContainer or (player and player:getInventory())
    if not destination then return false end
    local ok = pcall(function() destination:AddItem(item) end)
    if not ok then return false end
    pcall(function() sendAddItemToContainer(destination, item) end)
    return true
end

local function placeVessel(player, item)
    local square = player and player:getCurrentSquare()
    local sourceContainer = item and item:getContainer()
    if not square or not sourceContainer then return nil, nil, "vessel_placement_failed" end

    pcall(function() player:removeFromHands(item) end)
    sourceContainer:Remove(item)
    pcall(function() sendRemoveItemFromContainer(sourceContainer, item) end)

    local placed = pcall(function()
        square:AddWorldInventoryItem(item, 0.5, 0.5, 0.0)
    end)
    local worldItem = placed and item.getWorldItem and item:getWorldItem() or nil
    if not worldItem or not worldItem.getSquare or not worldItem:getSquare() then
        restoreInventoryItem(player, item, sourceContainer)
        return nil, nil, "vessel_placement_failed"
    end
    return worldItem, sourceContainer, nil
end

local function ritualPayload(ritual)
    return {
        ritualId = ritual.ritualId,
        bijuuId = ritual.bijuuId,
        bijuuRuntimeId = ritual.bijuuRuntimeId,
        casterOnlineId = ritual.casterOnlineId,
        vesselItemId = ritual.vesselItemId,
        vesselPower = ritual.vesselPower,
        vesselX = ritual.vesselX,
        vesselY = ritual.vesselY,
        vesselZ = ritual.vesselZ,
        ritualRadius = sealingConfig().RITUAL_RADIUS,
        progress = 0,
        startedAtGameMinutes = ritual.startedAtGameMinutes,
    }
end

function Server.prepareRitual(player, options)
    options = options or {}
    local vessel = findEmptyVessel(player, options.vesselItemId)
    if not vessel then return false, "no_empty_vessel" end

    local target = nearestBossTarget(player)
    if not target then return false, "no_bijuu_nearby" end
    if activeRituals[target.bijuuId] then return false, "bijuu_reserved" end

    local ritual = {
        ritualId = nextRitualId(),
        bijuuId = target.bijuuId,
        bijuuRuntimeId = target.runtimeId,
        casterOnlineId = playerOnlineId(player),
        casterPlayerNum = playerNumber(player),
        vesselItem = vessel,
        vesselItemId = Sealing.getVesselItemId(vessel),
        vesselPower = Sealing.getVesselPower(vessel),
        startedAtGameMinutes = NinjaLineages.Utils.Time.gameMinutes(),
        status = "prepared",
    }
    activeRituals[target.bijuuId] = ritual

    local worldItem, originalContainer, placementReason = placeVessel(player, vessel)
    if not worldItem then
        activeRituals[target.bijuuId] = nil
        return false, placementReason
    end

    local square = worldItem:getSquare()
    ritual.vesselWorldItem = worldItem
    ritual.originalContainer = originalContainer
    ritual.vesselX = square:getX() + 0.5
    ritual.vesselY = square:getY() + 0.5
    ritual.vesselZ = square:getZ()
    return true, nil, ritual
end

function Server.activatePreparedRitual(ritual)
    if not ritual or activeRituals[ritual.bijuuId] ~= ritual
            or ritual.status ~= "prepared" then return false end
    ritual.status = "active"
    Support.emit("bijuu_sealing_started", ritualPayload(ritual))
    return true
end

function Server.rollbackPreparedRitual(player, ritual)
    if not ritual or activeRituals[ritual.bijuuId] ~= ritual
            or ritual.status ~= "prepared" then return false end
    activeRituals[ritual.bijuuId] = nil
    return restoreInventoryItem(player, ritual.vesselItem, ritual.originalContainer)
end

local function cancelRitual(ritual, reason)
    if not ritual or activeRituals[ritual.bijuuId] ~= ritual then return end
    activeRituals[ritual.bijuuId] = nil
    Support.emit("bijuu_sealing_cancelled", {
        ritualId = ritual.ritualId,
        bijuuId = ritual.bijuuId,
        bijuuRuntimeId = ritual.bijuuRuntimeId,
        reason = reason,
    })
end

local function resolveCaster(ritual)
    local found = nil
    NinjaLineages.Utils.Players.forEach(function(player)
        if found then return end
        local onlineId = playerOnlineId(player)
        if ritual.casterOnlineId and ritual.casterOnlineId >= 0 then
            if onlineId == ritual.casterOnlineId then found = player end
        elseif playerNumber(player) == ritual.casterPlayerNum then
            found = player
        end
    end)
    return found
end

local function vesselIsPresent(ritual)
    local item = ritual.vesselItem
    if not item or Sealing.getVesselItemId(item) ~= ritual.vesselItemId
            or not Sealing.isEmptyVessel(item) then return false end
    local worldItem = item.getWorldItem and item:getWorldItem() or nil
    local square = worldItem and worldItem.getSquare and worldItem:getSquare() or nil
    if not square or worldItem ~= ritual.vesselWorldItem then return false end
    return square:getX() + 0.5 == ritual.vesselX
        and square:getY() + 0.5 == ritual.vesselY
        and square:getZ() == ritual.vesselZ
end

local function cancellationReason(ritual)
    local caster = resolveCaster(ritual)
    if not caster then return "caster_unavailable" end
    if caster.isDead and caster:isDead() then return "caster_dead" end

    local dx = caster:getX() - ritual.vesselX
    local dy = caster:getY() - ritual.vesselY
    if math.abs(caster:getZ() - ritual.vesselZ) >= 1.5
            or dx * dx + dy * dy > sealingConfig().RITUAL_RADIUS ^ 2 then
        return "caster_left_ritual"
    end
    if not vesselIsPresent(ritual) then return "vessel_missing" end

    local target = BossServer.getActiveBossSnapshot(ritual.bijuuId)
    if not target or target.runtimeId ~= ritual.bijuuRuntimeId then
        return "target_runtime_changed"
    end
    if (tonumber(target.health) or 0) <= 0 or target.phase == "defeated" then
        return "target_defeated"
    end
    if not isPhysicalBossState(Registry.getBijuuState(ritual.bijuuId)) then
        return "target_custody_changed"
    end
    return nil
end

function Server.update()
    local cancellations = {}
    for _, ritual in pairs(activeRituals) do
        if ritual.status == "active" then
            local reason = cancellationReason(ritual)
            if reason then table.insert(cancellations, { ritual = ritual, reason = reason }) end
        end
    end
    for _, cancellation in ipairs(cancellations) do
        cancelRitual(cancellation.ritual, cancellation.reason)
    end
end

function Server.getActiveRitualSnapshot(bijuuId)
    local ritual = activeRituals[bijuuId]
    if not ritual or ritual.status ~= "active" then return nil end
    return ritualPayload(ritual)
end

function Server.getActiveRitualPayloads()
    local payloads = {}
    for _, ritual in pairs(activeRituals) do
        if ritual.status == "active" then table.insert(payloads, ritualPayload(ritual)) end
    end
    return payloads
end

return Server
