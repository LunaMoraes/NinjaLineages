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
local restraintContributions = {}
local ritualCounter = 1

local function log(message)
    print("[NL-BIJUU-SEALING] " .. tostring(message))
end

local function sealingConfig()
    return Balance.Jinchuuriki.Sealing
end

local function nowGameMinutes()
    return NinjaLineages.Utils.Time.gameMinutes()
end

local function isPhysicalBossState(state)
    return state == BijuuState.WILD_ACTIVE or state == BijuuState.BOSS_ACTIVE
end

local function isSealableBossState(state)
    return isPhysicalBossState(state) or state == BijuuState.SEALING
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

local function restraintPlayerKey(player)
    local onlineId = playerOnlineId(player)
    if onlineId and onlineId >= 0 then return "online:" .. tostring(onlineId) end
    if player and player.getUsername then
        local ok, username = pcall(function() return player:getUsername() end)
        if ok and username and username ~= "" then return "user:" .. tostring(username) end
    end
    local number = playerNumber(player)
    return number >= 0 and ("local:" .. tostring(number)) or nil
end

local function nextRitualId()
    local id = "bijuu_ritual_" .. tostring(ritualCounter)
    ritualCounter = ritualCounter + 1
    return id
end

local function findEmptyVessel(player, requestedId)
    local requested = requestedId ~= nil and tonumber(requestedId) or nil
    if requestedId ~= nil and not requested then return nil end
    for _, item in ipairs(NinjaLineages.Utils.Inventory.collectItems(player)) do
        if (not requested or Sealing.getVesselItemId(item) == requested)
                and Sealing.isEmptyVessel(item) then
            return item
        end
    end
    return nil
end

local function nearestBossTarget(player, allowSealing)
    local radius = sealingConfig().ACQUISITION_RADIUS
    local nearest, nearestDistance = nil, math.huge
    for _, bijuuId in ipairs(Definitions.Order) do
        local snapshot = BossServer.getActiveBossSnapshot(bijuuId)
        local state = Registry.getBijuuState(bijuuId)
        local validState = allowSealing and isSealableBossState(state) or isPhysicalBossState(state)
        if snapshot and snapshot.runtimeId and (tonumber(snapshot.health) or 0) > 0
                and snapshot.phase ~= "defeated" and validState then
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

local function syncVesselItem(item)
    if not item then return end
    if item.syncItemFields then pcall(function() item:syncItemFields() end) end
    local worldItem = item.getWorldItem and item:getWorldItem() or nil
    if worldItem and worldItem.transmitCompleteItemToClients then
        pcall(function() worldItem:transmitCompleteItemToClients() end)
    elseif sendItemStats then
        pcall(function() sendItemStats(item) end)
    end
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
        progress = ritual.progress or 0,
        restraintStrength = ritual.restraintStrength or 0,
        progressRate = ritual.progressRate or 0,
        startedAtGameMinutes = ritual.startedAtGameMinutes,
    }
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

local function registryOwnsRitual(ritual)
    local record = Registry.getRecord(ritual.bijuuId)
    local sealing = record and record.sealing
    return record and record.state == BijuuState.SEALING
        and type(sealing) == "table"
        and sealing.sourceState == ritual.sourceState
        and sealing.runtimeId == ritual.bijuuRuntimeId
        and sealing.ritualId == ritual.ritualId
end

local function restoreSourceCustody(ritual, reason)
    if not ritual or not registryOwnsRitual(ritual) then return false, "state_mismatch" end
    return Registry.transition(
        ritual.bijuuId,
        BijuuState.SEALING,
        ritual.sourceState,
        { sealing = false },
        reason or "sealing_cancelled"
    )
end

local function emitCancellation(ritual, reason)
    Support.emit("bijuu_sealing_cancelled", {
        ritualId = ritual.ritualId,
        bijuuId = ritual.bijuuId,
        bijuuRuntimeId = ritual.bijuuRuntimeId,
        reason = reason,
    })
end

local function cancelRitual(ritual, reason)
    if not ritual or activeRituals[ritual.bijuuId] ~= ritual then return false end
    if ritual.status == "claimed" or ritual.status == "active" then
        local restored, restoreReason = restoreSourceCustody(ritual, reason)
        if not restored then
            log("custody rollback failed bijuu=" .. tostring(ritual.bijuuId)
                .. " ritual=" .. tostring(ritual.ritualId)
                .. " reason=" .. tostring(restoreReason))
        end
    end
    activeRituals[ritual.bijuuId] = nil
    emitCancellation(ritual, reason)
    return true
end

local function pruneRestraints(bijuuId, runtimeId, now)
    local contributions = restraintContributions[bijuuId]
    if not contributions then return 0 end
    local total = 0
    for key, contribution in pairs(contributions) do
        if contribution.runtimeId ~= runtimeId
                or contribution.expiresAtGameMinutes <= now then
            contributions[key] = nil
        else
            total = total + contribution.strength
        end
    end
    if not next(contributions) then restraintContributions[bijuuId] = nil end
    return total
end

function Server.addOrRefreshRestraint(bijuuId, runtimeId, sourceKey, player,
        strength, expiresAtGameMinutes)
    if not Definitions.isValidId(bijuuId) then return false, "invalid_bijuu_id" end
    if type(runtimeId) ~= "string" or runtimeId == "" then return false, "invalid_runtime" end
    if type(sourceKey) ~= "string" or sourceKey == "" then return false, "invalid_source" end
    local playerKey = restraintPlayerKey(player)
    if not playerKey then return false, "invalid_player" end
    local contributionStrength = math.max(0, tonumber(strength) or 0)
    local expiresAt = tonumber(expiresAtGameMinutes) or 0
    local now = nowGameMinutes()
    if contributionStrength <= 0 or expiresAt <= now then return false, "invalid_restraint" end
    local snapshot = BossServer.getActiveBossSnapshot(bijuuId)
    if not snapshot or snapshot.runtimeId ~= runtimeId
            or not isSealableBossState(Registry.getBijuuState(bijuuId)) then
        return false, "target_runtime_changed"
    end
    local contributions = restraintContributions[bijuuId] or {}
    restraintContributions[bijuuId] = contributions
    contributions[playerKey .. "|" .. sourceKey] = {
        sourceKey = sourceKey,
        playerKey = playerKey,
        runtimeId = runtimeId,
        strength = contributionStrength,
        expiresAtGameMinutes = expiresAt,
    }
    return true, "ok"
end

function Server.applyBossRestraint(player, target, sourceKey, options)
    options = options or {}
    if not target or not target.bijuuId or not target.runtimeId then
        return false, "invalid_target"
    end
    local expiresAt = tonumber(options.expiresAtGameMinutes) or 0
    local suppressed, suppressionReason = BossServer.addOrRefreshSuppression(
        target.bijuuId, target.runtimeId, sourceKey, player, {
            movement = options.suppressMovement == true,
            attacks = options.suppressAttacks == true,
            expiresAtGameMinutes = expiresAt,
        })
    if not suppressed then return false, suppressionReason end

    local restrained, restraintReason = Server.addOrRefreshRestraint(
        target.bijuuId, target.runtimeId, sourceKey, player,
        options.sealingPower, expiresAt)
    if not restrained then
        BossServer.removeSuppression(
            target.bijuuId, target.runtimeId, sourceKey, player)
        return false, restraintReason
    end

    local damage = math.max(0, tonumber(options.damage) or 0)
    if damage > 0 then
        local damaged, damageReason = BossServer.applyDamage(
            target.bijuuId, target.runtimeId, player, damage, sourceKey)
        if not damaged then return false, damageReason end
    end
    return true, "ok"
end

function Server.getTotalRestraintStrength(bijuuId, runtimeId)
    if not Definitions.isValidId(bijuuId) or not runtimeId then return 0 end
    return pruneRestraints(bijuuId, runtimeId, nowGameMinutes())
end

function Server.clearRestraints(bijuuId, runtimeId)
    local contributions = restraintContributions[bijuuId]
    if not contributions then return end
    if not runtimeId then
        restraintContributions[bijuuId] = nil
        return
    end
    for key, contribution in pairs(contributions) do
        if contribution.runtimeId == runtimeId then contributions[key] = nil end
    end
    if not next(contributions) then restraintContributions[bijuuId] = nil end
end

function Server.prepareRitual(player, options)
    options = options or {}
    local vessel = findEmptyVessel(player, options.vesselItemId)
    if not vessel then return false, "no_empty_vessel" end
    local target = nearestBossTarget(player, true)
    if not target then return false, "no_bijuu_nearby" end
    if activeRituals[target.bijuuId]
            or Registry.getBijuuState(target.bijuuId) == BijuuState.SEALING then
        return false, "bijuu_reserved"
    end
    local sourceState = Registry.getBijuuState(target.bijuuId)
    if not isPhysicalBossState(sourceState) then return false, "target_custody_changed" end
    local ritual = {
        ritualId = nextRitualId(),
        bijuuId = target.bijuuId,
        bijuuRuntimeId = target.runtimeId,
        sourceState = sourceState,
        casterOnlineId = playerOnlineId(player),
        casterPlayerNum = playerNumber(player),
        vesselItem = vessel,
        vesselItemId = Sealing.getVesselItemId(vessel),
        vesselPower = Sealing.getVesselPower(vessel),
        startedAtGameMinutes = nowGameMinutes(),
        progress = 0,
        restraintStrength = 0,
        progressRate = 0,
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

function Server.claimPreparedRitual(ritual)
    if not ritual or activeRituals[ritual.bijuuId] ~= ritual
            or ritual.status ~= "prepared" or not vesselIsPresent(ritual) then
        return false, "ritual_invalid"
    end
    local target = BossServer.getActiveBossSnapshot(ritual.bijuuId)
    if not target or target.runtimeId ~= ritual.bijuuRuntimeId
            or (tonumber(target.health) or 0) <= 0 or target.phase == "defeated" then
        return false, "target_runtime_changed"
    end
    local transitioned, reason = Registry.transition(
        ritual.bijuuId,
        ritual.sourceState,
        BijuuState.SEALING,
        {
            sealing = {
                sourceState = ritual.sourceState,
                runtimeId = ritual.bijuuRuntimeId,
                ritualId = ritual.ritualId,
            },
        },
        "sealing_started"
    )
    if not transitioned then return false, reason end
    ritual.status = "claimed"
    return true, "ok"
end

function Server.activatePreparedRitual(ritual)
    if not ritual or activeRituals[ritual.bijuuId] ~= ritual
            or ritual.status ~= "claimed" or not registryOwnsRitual(ritual) then
        return false
    end
    ritual.status = "active"
    ritual.lastUpdateGameMinutes = nowGameMinutes()
    ritual.lastProgressSent = ritual.progress
    ritual.lastProgressSentAt = ritual.lastUpdateGameMinutes
    Support.emit("bijuu_sealing_started", ritualPayload(ritual))
    return true
end

function Server.rollbackPreparedRitual(player, ritual)
    if not ritual or activeRituals[ritual.bijuuId] ~= ritual
            or (ritual.status ~= "prepared" and ritual.status ~= "claimed") then return false end
    if ritual.status == "claimed" then
        local restored, reason = restoreSourceCustody(ritual, "sealing_commit_rollback")
        if not restored then
            log("prepared custody rollback failed bijuu=" .. tostring(ritual.bijuuId)
                .. " reason=" .. tostring(reason))
        end
    end
    activeRituals[ritual.bijuuId] = nil
    return restoreInventoryItem(player, ritual.vesselItem, ritual.originalContainer)
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
    if not registryOwnsRitual(ritual) then return "target_custody_changed" end
    return nil, caster, target
end

local function progressPayload(ritual)
    return {
        ritualId = ritual.ritualId,
        bijuuId = ritual.bijuuId,
        bijuuRuntimeId = ritual.bijuuRuntimeId,
        progress = ritual.progress,
        restraintStrength = ritual.restraintStrength,
        vesselPower = ritual.vesselPower,
        progressRate = ritual.progressRate,
    }
end

local function shouldSyncProgress(ritual, now)
    local config = sealingConfig()
    local delta = math.max(0.01, tonumber(config.PROGRESS_SYNC_DELTA) or 0.25)
    local interval = math.max(0.01,
        tonumber(config.PROGRESS_SYNC_INTERVAL_GAME_MINUTES) or 0.25)
    local changed = ritual.progress > (ritual.lastProgressSent or 0)
    return ritual.progress - (ritual.lastProgressSent or 0) >= delta
        or (changed and now - (ritual.lastProgressSentAt or 0) >= interval)
end

local function setItemSeal(item, seal)
    if not item or not item.getModData then return false end
    item:getModData().bijuuSeal = seal
    syncVesselItem(item)
    return true
end

function Server.resolveInventoryVessel(player, requestedId, requireEmpty)
    local requested = tonumber(requestedId)
    if not requested then return nil, "invalid_vessel_item_id" end
    local item = nil
    for _, candidate in ipairs(NinjaLineages.Utils.Inventory.collectItems(player)) do
        if tonumber(Sealing.getVesselItemId(candidate)) == requested then
            item = candidate
            break
        end
    end
    if not item or not Sealing.isVessel(item) then return nil, "vessel_not_found" end
    if requireEmpty == true and not Sealing.isEmptyVessel(item) then
        return nil, "vessel_not_empty"
    end
    return item, "ok"
end

function Server.setVesselSeal(item, seal)
    if not Sealing.isVessel(item) then return false, "invalid_vessel" end
    if seal ~= nil and type(seal) ~= "table" then return false, "invalid_seal" end
    if not setItemSeal(item, seal) then return false, "item_sync_failed" end
    return true, "ok"
end

local function completeRitual(ritual)
    if not ritual or activeRituals[ritual.bijuuId] ~= ritual
            or ritual.status ~= "active" or ritual.progress < 100 then return false end
    local reason, caster, target = cancellationReason(ritual)
    if reason or not caster or not target or not vesselIsPresent(ritual) then return false end
    if not Definitions.get(ritual.bijuuId) then return false end
    local sealToken = tostring(getRandomUUID())
    local seal = {
        bijuuId = ritual.bijuuId,
        sealToken = sealToken,
        vesselPower = ritual.vesselPower,
    }
    if not setItemSeal(ritual.vesselItem, seal) then return false end
    local transitioned, transitionReason = Registry.transition(
        ritual.bijuuId,
        BijuuState.SEALING,
        BijuuState.SEALED_VESSEL,
        {
            world = false,
            host = false,
            sealing = false,
            vessel = {
                token = sealToken,
                vesselPower = ritual.vesselPower,
                itemId = ritual.vesselItemId,
                itemType = ritual.vesselItem:getFullType(),
            },
        },
        "sealing_completed"
    )
    if not transitioned then
        setItemSeal(ritual.vesselItem, nil)
        log("completion custody transition failed bijuu=" .. tostring(ritual.bijuuId)
            .. " reason=" .. tostring(transitionReason))
        return false
    end
    local removed, removalReason = BossServer.dematerialize(
        ritual.bijuuId, ritual.bijuuRuntimeId, "sealed_into_vessel")
    if not removed and removalReason ~= "no_active_runtime" then
        log("WARNING: canonical seal completed but exact runtime removal failed bijuu="
            .. tostring(ritual.bijuuId) .. " reason=" .. tostring(removalReason))
        BossServer.dematerialize(ritual.bijuuId, nil, "sealed_custody_cleanup")
    end
    activeRituals[ritual.bijuuId] = nil
    Server.clearRestraints(ritual.bijuuId, ritual.bijuuRuntimeId)
    Support.emit("bijuu_sealing_completed", {
        ritualId = ritual.ritualId,
        bijuuId = ritual.bijuuId,
        bijuuRuntimeId = ritual.bijuuRuntimeId,
        vesselItemId = ritual.vesselItemId,
        vesselPower = ritual.vesselPower,
        vesselX = ritual.vesselX,
        vesselY = ritual.vesselY,
        vesselZ = ritual.vesselZ,
    })
    log("completed bijuu=" .. tostring(ritual.bijuuId)
        .. " ritual=" .. tostring(ritual.ritualId)
        .. " vesselItemId=" .. tostring(ritual.vesselItemId))
    return true
end

local function updateRitual(ritual, now)
    local reason, caster, target = cancellationReason(ritual)
    if reason then return reason end
    local elapsed = math.max(0, now - (ritual.lastUpdateGameMinutes or now))
    ritual.lastUpdateGameMinutes = now
    ritual.restraintStrength = Server.getTotalRestraintStrength(
        ritual.bijuuId, ritual.bijuuRuntimeId)
    local definition = Definitions.get(ritual.bijuuId)
    local progress, rate = Sealing.advanceProgress(ritual.progress, elapsed, {
        currentHealth = target.health,
        maximumHealth = target.maxHealth,
        restraintStrength = ritual.restraintStrength,
        vesselPower = ritual.vesselPower,
        progressionMultiplier = Sealing.getProgressionMultiplier(caster),
        tails = definition and definition.tails or 1,
    }, sealingConfig())
    ritual.progress = progress
    ritual.progressRate = rate
    if shouldSyncProgress(ritual, now) then
        Support.emit("bijuu_sealing_progress", progressPayload(ritual))
        ritual.lastProgressSent = ritual.progress
        ritual.lastProgressSentAt = now
    end
    if ritual.progress >= 100 and not completeRitual(ritual) then
        return "completion_revalidation_failed"
    end
    return nil
end

function Server.update()
    local now = nowGameMinutes()
    local cancellations = {}
    local restrainedIds = {}
    for bijuuId in pairs(restraintContributions) do
        table.insert(restrainedIds, bijuuId)
    end
    for _, bijuuId in ipairs(restrainedIds) do
        local snapshot = BossServer.getActiveBossSnapshot(bijuuId)
        pruneRestraints(bijuuId, snapshot and snapshot.runtimeId or nil, now)
    end
    local rituals = {}
    for _, ritual in pairs(activeRituals) do table.insert(rituals, ritual) end
    for _, ritual in ipairs(rituals) do
        if ritual.status == "active" then
            local reason = updateRitual(ritual, now)
            if reason then table.insert(cancellations, { ritual = ritual, reason = reason }) end
        end
    end
    for _, cancellation in ipairs(cancellations) do
        cancelRitual(cancellation.ritual, cancellation.reason)
    end
end

function Server.cancelForBossDefeat(bijuuId, runtimeId)
    local ritual = activeRituals[bijuuId]
    if not ritual or ritual.bijuuRuntimeId ~= runtimeId then return nil end
    local sourceState = ritual.sourceState
    cancelRitual(ritual, "target_defeated")
    Server.clearRestraints(bijuuId, runtimeId)
    return sourceState
end

function Server.reconcileOrphanedSealing()
    for _, bijuuId in ipairs(Definitions.Order) do
        local record = Registry.getRecord(bijuuId)
        if record and record.state == BijuuState.SEALING then
            local sourceState = record.sealing and record.sealing.sourceState
            if isPhysicalBossState(sourceState) then
                local ok, reason = Registry.transition(
                    bijuuId, BijuuState.SEALING, sourceState,
                    { sealing = false }, "startup_cancel_orphaned_sealing")
                if not ok then
                    log("startup sealing recovery failed bijuu=" .. tostring(bijuuId)
                        .. " reason=" .. tostring(reason))
                end
            else
                log("startup sealing recovery rejected invalid source bijuu="
                    .. tostring(bijuuId) .. " source=" .. tostring(sourceState))
            end
        end
    end
end

function Server.validateSealedVessel(item)
    if not Sealing.isVessel(item) or not item.getModData then
        return false, "invalid_vessel"
    end
    local seal = item:getModData().bijuuSeal
    if type(seal) ~= "table" or not Definitions.isValidId(seal.bijuuId)
            or type(seal.sealToken) ~= "string" or seal.sealToken == "" then
        return false, "stale_vessel"
    end
    local record = Registry.getRecord(seal.bijuuId)
    local vessel = record and record.vessel
    if not record or record.state ~= BijuuState.SEALED_VESSEL
            or type(vessel) ~= "table"
            or vessel.token ~= seal.sealToken
            or tonumber(vessel.itemId) ~= tonumber(Sealing.getVesselItemId(item))
            or vessel.itemType ~= item:getFullType() then
        return false, "stale_vessel"
    end
    return true, "ok", {
        bijuuId = seal.bijuuId,
        sealToken = seal.sealToken,
        vesselPower = tonumber(vessel.vesselPower) or tonumber(seal.vesselPower) or 0,
        itemId = vessel.itemId,
        itemType = vessel.itemType,
    }
end

local function removeExactItem(item)
    if not item then return false end
    local worldItem = item.getWorldItem and item:getWorldItem() or nil
    local square = worldItem and worldItem.getSquare and worldItem:getSquare() or nil
    if square then
        pcall(function() square:transmitRemoveItemFromSquare(worldItem) end)
        pcall(function() square:removeWorldObject(worldItem) end)
        return true
    end
    local container = item.getContainer and item:getContainer() or nil
    if container then
        container:Remove(item)
        pcall(function() sendRemoveItemFromContainer(container, item) end)
        return true
    end
    return false
end

function Server.releaseFromVessel(item, x, y, z, reason)
    local valid, validationReason, custody = Server.validateSealedVessel(item)
    if not valid then return false, validationReason end
    local worldItem = item:getWorldItem()
    local square = worldItem and worldItem.getSquare and worldItem:getSquare() or nil
    local releaseX = tonumber(x) or (square and square:getX() + 0.5)
    local releaseY = tonumber(y) or (square and square:getY() + 0.5)
    local releaseZ = tonumber(z) or (square and square:getZ())
    if not releaseX or not releaseY or not releaseZ then return false, "invalid_release_location" end
    local transitioned, transitionReason = Registry.transition(
        custody.bijuuId, BijuuState.SEALED_VESSEL, BijuuState.BOSS_ACTIVE,
        {
            vessel = false,
            sealing = false,
            host = false,
            world = { x = releaseX, y = releaseY, z = releaseZ },
        },
        reason or "sealed_vessel_released"
    )
    if not transitioned then return false, transitionReason end
    local originalSeal = item:getModData().bijuuSeal
    setItemSeal(item, nil)
    local runtime, materializeReason = BossServer.materialize(
        custody.bijuuId, releaseX, releaseY, releaseZ)
    if not runtime then
        setItemSeal(item, originalSeal)
        local rolledBack, rollbackReason = Registry.transition(
            custody.bijuuId, BijuuState.BOSS_ACTIVE, BijuuState.SEALED_VESSEL,
            {
                world = false,
                vessel = {
                    token = custody.sealToken,
                    vesselPower = custody.vesselPower,
                    itemId = custody.itemId,
                    itemType = custody.itemType,
                },
            },
            "sealed_vessel_release_rollback"
        )
        if not rolledBack then
            log("release rollback failed bijuu=" .. tostring(custody.bijuuId)
                .. " reason=" .. tostring(rollbackReason))
        end
        return false, materializeReason
    end
    if reason == "destroyed" then removeExactItem(item) end
    return true, "ok", runtime
end

function Server.recoverCanonicalVesselLoss(bijuuId, sealToken, reason)
    if not Definitions.isValidId(bijuuId) or type(sealToken) ~= "string" then
        return false, "invalid_custody"
    end
    local record = Registry.getRecord(bijuuId)
    if not record or record.state ~= BijuuState.SEALED_VESSEL
            or not record.vessel or record.vessel.token ~= sealToken then
        return false, "state_mismatch"
    end
    local definition = Definitions.get(bijuuId)
    local targetState = definition.nativeSpawnType == "host"
        and BijuuState.HOST_POOL or BijuuState.RESPAWNING
    local ok, transitionReason = Registry.transition(
        bijuuId, BijuuState.SEALED_VESSEL, targetState,
        { vessel = false, sealing = false, world = false, host = false },
        reason or "canonical_vessel_loss_recovery"
    )
    if ok and targetState == BijuuState.RESPAWNING
            and NinjaLineages.BijuuLifecycleServer
            and NinjaLineages.BijuuLifecycleServer.recoverRespawningBijuu then
        NinjaLineages.BijuuLifecycleServer.recoverRespawningBijuu(bijuuId)
    end
    return ok, transitionReason
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

function Server.debugApplyTestRestraint(player, args)
    args = args or {}
    local target = args.bijuuId and BossServer.getActiveBossSnapshot(args.bijuuId)
        or nearestBossTarget(player, true)
    if not target then return false, "no_bijuu_nearby" end
    local config = sealingConfig()
    local strength = tonumber(args.strength) or config.DEBUG_RESTRAINT_STRENGTH or 0.5
    local duration = tonumber(args.durationGameMinutes)
        or config.DEBUG_RESTRAINT_DURATION_GAME_MINUTES or 5.0
    local ok, reason = Server.addOrRefreshRestraint(
        target.bijuuId, target.runtimeId, "debug_test_restraint", player,
        strength, nowGameMinutes() + duration)
    return ok, reason, {
        bijuuId = target.bijuuId,
        strength = strength,
        durationGameMinutes = duration,
    }
end

function Server.debugReleaseFirstVessel(player)
    local sealedItem, custody = nil, nil
    for _, item in ipairs(NinjaLineages.Utils.Inventory.collectItems(player)) do
        local valid, _, candidateCustody = Server.validateSealedVessel(item)
        if valid then
            sealedItem, custody = item, candidateCustody
            break
        end
    end
    if not sealedItem then return false, "no_canonical_sealed_vessel" end
    local forward = player:getForwardDirection()
    local releaseX = player:getX() + (forward and forward:getX() or 0) * 4
    local releaseY = player:getY() + (forward and forward:getY() or 1) * 4
    local ok, reason = Server.releaseFromVessel(
        sealedItem, releaseX, releaseY, player:getZ(), "debug_release")
    return ok, reason, { bijuuId = custody.bijuuId }
end

Support.registerDebugAction("apply_test_restraint", Server.debugApplyTestRestraint)
Support.registerDebugAction("release_test_vessel", Server.debugReleaseFirstVessel)

return Server
