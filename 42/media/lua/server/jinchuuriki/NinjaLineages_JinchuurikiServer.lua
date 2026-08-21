require "NinjaLineages_Balance"
require "NinjaLineages_Progression"
require "NinjaLineages_Chakra"
require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "disciplines/jinchuuriki/NinjaLineages_BijuuDefinitions"
require "disciplines/jinchuuriki/NinjaLineages_BijuuSealing"
require "disciplines/jinchuuriki/NinjaLineages_BijuuState"
require "jinchuuriki/NinjaLineages_BijuuBossServer"
require "jinchuuriki/NinjaLineages_BijuuRegistryServer"
require "jinchuuriki/NinjaLineages_BijuuSealingServer"
require "jinchuuriki/NinjaLineages_BijuuServerSupport"
require "disciplines/jinchuuriki/NinjaLineages_ChakraCloak"

NinjaLineages = NinjaLineages or {}
NinjaLineages.JinchuurikiServer = NinjaLineages.JinchuurikiServer or {}

local Server = NinjaLineages.JinchuurikiServer
local Balance = NinjaLineages.Balance
local Definitions = NinjaLineages.BijuuDefinitions
local Progression = NinjaLineages.Progression
local Registry = NinjaLineages.BijuuRegistryServer
local Sealing = NinjaLineages.BijuuSealing
local SealingServer = NinjaLineages.BijuuSealingServer
local BossServer = NinjaLineages.BijuuBossServer
local BijuuState = NinjaLineages.BijuuState
local Support = NinjaLineages.BijuuServerSupport

local initializedPlayers = {}
local lastSynchronizationUpdateAt = setmetatable({}, { __mode = "k" })
local lastSynchronizationBroadcastAt = setmetatable({}, { __mode = "k" })

local function log(message)
    print("[NL-JINCHUURIKI] " .. tostring(message))
end

local function nowGameMinutes()
    return NinjaLineages.Utils.Time.gameMinutes()
end

local function isLivingPlayer(player)
    return player ~= nil
        and instanceof(player, "IsoPlayer")
        and not (player.isDead and player:isDead())
end

local function arraysEqual(left, right)
    if #left ~= #right then return false end
    for index = 1, #left do
        if left[index] ~= right[index] then return false end
    end
    return true
end

local function playerName(player)
    if not player or not player.getUsername then return "unknown" end
    local ok, name = pcall(function() return player:getUsername() end)
    return ok and tostring(name or "unknown") or "unknown"
end

local function sendResult(player, action, ok, reason, extra)
    if not player then return end
    local payload = extra or {}
    payload.action = action
    payload.ok = ok == true
    payload.reason = reason
    payload.playerOnlineId = player.getOnlineID and player:getOnlineID() or -1
    if NinjaLineages.isServer and NinjaLineages.isServer() then
        sendServerCommand(player, "NinjaLineages", "jinchuurikiActionResult", payload)
    elseif player.Say then
        player:Say((ok and "Jinchūriki action completed: " or "Jinchūriki action failed: ")
            .. tostring(reason or action))
    end
end

function Server.getHostKey(player, create)
    if not player then return nil end
    local data = Progression.getJinchuurikiData(player)
    if not data then return nil end
    if type(data.hostKey) == "string" and data.hostKey ~= "" then
        return data.hostKey
    end
    if create ~= true then return nil end
    data.hostKey = tostring(getRandomUUID())
    NinjaLineages.transmitPlayerData(player)
    return data.hostKey
end

function Server.getCanonicalHostedBijuuIds(player)
    local hostKey = Server.getHostKey(player, false)
    return hostKey and Registry.getHostedBijuuIds(hostKey) or {}
end

local function syncProjection(player, canonicalIds)
    local data = Progression.getJinchuurikiData(player)
    if not data then return false end
    canonicalIds = canonicalIds or {}
    local projected = data.hostedBijuuIds or {}
    local oldBijuuId = projected[1]
    local newBijuuId = canonicalIds[1]
    local chakraBefore = NinjaLineages.Chakra.getChakra(player)
    if arraysEqual(projected, canonicalIds) then
        Progression.onHostedBijuuChanged(player, oldBijuuId, newBijuuId)
        return false
    end
    data.hostedBijuuIds = canonicalIds
    Progression.onHostedBijuuChanged(player, oldBijuuId, newBijuuId)
    if oldBijuuId ~= newBijuuId and NinjaLineages.ChakraCloak then
        NinjaLineages.ChakraCloak.deactivate(player, "host_lost")
    end
    NinjaLineages.Chakra.setChakra(player, chakraBefore)
    NinjaLineages.transmitPlayerData(player)
    log("host_projection_repaired host=" .. tostring(data.hostKey)
        .. " count=" .. tostring(#canonicalIds))
    return true
end

local function killForExtraction(player, hostKey, reason)
    if not isLivingPlayer(player) then return false end
    local bodyDamage = player.getBodyDamage and player:getBodyDamage() or nil
    if not bodyDamage then
        log("ERROR: unable to apply extraction death host=" .. tostring(hostKey)
            .. " reason=no_body_damage")
        return false
    end
    local health = tonumber(bodyDamage:getOverallBodyHealth()) or 100
    bodyDamage:ReduceGeneralHealth(math.max(1000, health + 100))
    log("extraction_death_applied host=" .. tostring(hostKey)
        .. " reason=" .. tostring(reason))
    return true
end

function Server.reconcilePlayer(player)
    if not player or not instanceof(player, "IsoPlayer") then return false, "invalid_player" end
    local hostKey = Server.getHostKey(player, true)
    if not hostKey then return false, "host_key_unavailable" end

    local canonicalIds = Registry.getHostedBijuuIds(hostKey)
    local data = Progression.getJinchuurikiData(player)
    local projectionChanged = syncProjection(player, canonicalIds)
    if #canonicalIds > 0 then
        if data.extractionDeathAt ~= nil then
            data.extractionDeathAt = nil
            NinjaLineages.transmitPlayerData(player)
        end
        return true, projectionChanged and "projection_repaired" or "ok", canonicalIds
    end

    local deadline = tonumber(data.extractionDeathAt)
    if deadline and nowGameMinutes() >= deadline then
        data.extractionDeathAt = nil
        NinjaLineages.transmitPlayerData(player)
        killForExtraction(player, hostKey, "grace_expired")
        return false, "extraction_grace_expired", canonicalIds
    end
    return true, projectionChanged and "projection_repaired" or "ok", canonicalIds
end

function Server.updatePlayer(player)
    if not player or not instanceof(player, "IsoPlayer") then return end
    if not initializedPlayers[player] then
        initializedPlayers[player] = true
        Server.reconcilePlayer(player)
        lastSynchronizationUpdateAt[player] = nowGameMinutes()
        return
    end
    local data = Progression.getJinchuurikiData(player)
    local deadline = data and tonumber(data.extractionDeathAt)
    if deadline and nowGameMinutes() >= deadline then
        Server.reconcilePlayer(player)
    end
    local now = nowGameMinutes()
    local previous = lastSynchronizationUpdateAt[player] or now
    lastSynchronizationUpdateAt[player] = now
    local hosted = data and data.hostedBijuuIds or {}
    local changed, completed = Progression.updateBijuuSynchronization(
        player, hosted[1], math.max(0, now - previous))
    if changed and not completed
            and now - (lastSynchronizationBroadcastAt[player] or 0) >= 0.25 then
        lastSynchronizationBroadcastAt[player] = now
        NinjaLineages.transmitPlayerData(player)
    end
end

function Server.recordJutsuChakraSpend(player, actualAmount, abilityId)
    if not Support.isAuthoritative() or not isLivingPlayer(player) then return false end
    local canonicalIds = Server.getCanonicalHostedBijuuIds(player)
    if #canonicalIds ~= 1 then return false end
    local data = Progression.getJinchuurikiData(player)
    if not data or not data.hostedBijuuIds
            or data.hostedBijuuIds[1] ~= canonicalIds[1] then
        syncProjection(player, canonicalIds)
    end
    return Progression.recordBijuuSynchronizationChakra(player, actualAmount, abilityId)
end

function Server.installFromVessel(player, vesselItemId)
    if not Support.isAuthoritative() then return false, "client_unauthorized" end
    if not isLivingPlayer(player) then return false, "player_not_alive" end
    local reconciled, reconcileReason, canonicalIds = Server.reconcilePlayer(player)
    if not reconciled and reconcileReason == "extraction_grace_expired" then
        return false, reconcileReason
    end
    if not Progression.isDisciplineVisible(player, "jinchuuriki")
            or Progression.isDisciplineLocked(player, "jinchuuriki") then
        return false, "discipline_locked"
    end

    local capacity = math.max(1, tonumber(Balance.Jinchuuriki.MAX_HOSTED_BIJUU) or 1)
    if #canonicalIds >= capacity then return false, "host_capacity_full" end

    local item, itemReason = SealingServer.resolveInventoryVessel(player, vesselItemId, false)
    if not item then return false, itemReason end
    local valid, validationReason, custody = SealingServer.validateSealedVessel(item)
    if not valid then return false, validationReason end

    local hostKey = Server.getHostKey(player, true)
    local transitioned, transitionReason = Registry.transition(
        custody.bijuuId,
        BijuuState.SEALED_VESSEL,
        BijuuState.SEALED_PLAYER,
        {
            vessel = false,
            world = false,
            sealing = false,
            host = {
                playerKey = hostKey,
                playerName = playerName(player),
                enteredAtGameMinutes = nowGameMinutes(),
            },
        },
        "vessel_installed_into_player"
    )
    if not transitioned then return false, transitionReason end

    local cleared, clearReason = SealingServer.setVesselSeal(item, nil)
    if not cleared then
        log("WARNING: canonical installation succeeded but vessel cleanup failed bijuu="
            .. tostring(custody.bijuuId) .. " reason=" .. tostring(clearReason))
    end
    local data = Progression.getJinchuurikiData(player)
    data.extractionDeathAt = nil
    Server.reconcilePlayer(player)
    NinjaLineages.transmitPlayerData(player)
    log("installed bijuu=" .. tostring(custody.bijuuId) .. " host=" .. tostring(hostKey))
    return true, "ok", custody.bijuuId
end

function Server.extractHostedBijuu(player, vesselItemId)
    if not Support.isAuthoritative() then return false, "client_unauthorized" end
    if not isLivingPlayer(player) then return false, "player_not_alive" end
    if not Progression.isCompleted(player, "bijuu_extraction_transfer") then
        return false, "technique_locked"
    end
    local reconciled, reconcileReason, canonicalIds = Server.reconcilePlayer(player)
    if not reconciled then return false, reconcileReason end
    if #canonicalIds ~= 1 then return false, #canonicalIds == 0 and "no_hosted_bijuu" or "ambiguous_host_custody" end

    local item, itemReason = SealingServer.resolveInventoryVessel(player, vesselItemId, true)
    if not item then return false, itemReason end
    local vesselPower = tonumber(Sealing.getVesselPower(item))
    local itemId = Sealing.getVesselItemId(item)
    if not vesselPower or not itemId then return false, "invalid_vessel" end

    local bijuuId = canonicalIds[1]
    local hostKey = Server.getHostKey(player, true)
    local record = Registry.getRecord(bijuuId)
    if not record or record.state ~= BijuuState.SEALED_PLAYER
            or not record.host or record.host.playerKey ~= hostKey then
        return false, "host_custody_changed"
    end

    local sealToken = tostring(getRandomUUID())
    local candidateSeal = {
        bijuuId = bijuuId,
        sealToken = sealToken,
        vesselPower = vesselPower,
    }
    local wroteSeal, writeReason = SealingServer.setVesselSeal(item, candidateSeal)
    if not wroteSeal then return false, writeReason end

    local transitioned, transitionReason = Registry.transition(
        bijuuId,
        BijuuState.SEALED_PLAYER,
        BijuuState.SEALED_VESSEL,
        {
            host = false,
            world = false,
            sealing = false,
            vessel = {
                token = sealToken,
                vesselPower = vesselPower,
                itemId = itemId,
                itemType = item:getFullType(),
            },
        },
        "player_extracted_into_vessel"
    )
    if not transitioned then
        SealingServer.setVesselSeal(item, nil)
        return false, transitionReason
    end

    local data = Progression.getJinchuurikiData(player)
    syncProjection(player, {})
    local uzumaki = NinjaLineages.hasUzumaki(player)
    if uzumaki then
        data.extractionDeathAt = nowGameMinutes() + 1440
        log("extraction_grace_started host=" .. tostring(hostKey)
            .. " deadline=" .. tostring(data.extractionDeathAt))
    else
        data.extractionDeathAt = nil
    end
    NinjaLineages.transmitPlayerData(player)
    log("extracted bijuu=" .. tostring(bijuuId) .. " host=" .. tostring(hostKey)
        .. " uzumaki=" .. tostring(uzumaki))
    if not uzumaki then killForExtraction(player, hostKey, "living_extraction") end
    return true, "ok", bijuuId
end

function Server.releaseHostedBijuuOnDeath(character)
    if not Support.isAuthoritative() then return end
    if not character or not instanceof(character, "IsoPlayer") then return end
    local hostKey = Server.getHostKey(character, false)
    if not hostKey then return end
    local hostedIds = Registry.getHostedBijuuIds(hostKey)
    if #hostedIds == 0 then return end

    local x, y, z = character:getX(), character:getY(), character:getZ()
    local released = 0
    for _, bijuuId in ipairs(hostedIds) do
        local transitioned, reason = Registry.transition(
            bijuuId,
            BijuuState.SEALED_PLAYER,
            BijuuState.BOSS_ACTIVE,
            {
                host = false,
                vessel = false,
                sealing = false,
                world = { x = x, y = y, z = z, source = "player_host_death" },
            },
            "player_host_death_release"
        )
        if transitioned then
            released = released + 1
            local runtime, materializeReason = BossServer.materialize(bijuuId, x, y, z)
            if not runtime then
                log("host death release pending materialization bijuu=" .. tostring(bijuuId)
                    .. " reason=" .. tostring(materializeReason))
            end
            log("host_death_release bijuu=" .. tostring(bijuuId)
                .. " x=" .. tostring(x) .. " y=" .. tostring(y))
        else
            log("host death release CAS failed bijuu=" .. tostring(bijuuId)
                .. " reason=" .. tostring(reason))
        end
    end
    local data = Progression.getJinchuurikiData(character)
    syncProjection(character, {})
    data.extractionDeathAt = nil
    NinjaLineages.transmitPlayerData(character)
    return released
end

function Server.debugInstallFirstVessel(player)
    for _, item in ipairs(NinjaLineages.Utils.Inventory.collectItems(player)) do
        if SealingServer.validateSealedVessel(item) then
            return Server.installFromVessel(player, Sealing.getVesselItemId(item))
        end
    end
    return false, "no_valid_sealed_vessel"
end

function Server.debugExtractHosted(player)
    for _, item in ipairs(NinjaLineages.Utils.Inventory.collectItems(player)) do
        if Sealing.isEmptyVessel(item) then
            return Server.extractHostedBijuu(player, Sealing.getVesselItemId(item))
        end
    end
    return false, "no_empty_vessel"
end

function Server.debugExpireGrace(player)
    local data = Progression.getJinchuurikiData(player)
    if not data or not data.extractionDeathAt then return false, "no_active_grace" end
    data.extractionDeathAt = nowGameMinutes() - 1
    local _, reason = Server.reconcilePlayer(player)
    return true, reason
end

function Server.debugUnlockAllJinchuuriki(player)
    return Progression.debugUnlockAllJinchuuriki(player)
end

local function onClientCommand(module, command, player, args)
    if module ~= "NinjaLineages" then return end
    if command == "installBijuuFromVessel" then
        local ok, reason, bijuuId = Server.installFromVessel(player, args and args.vesselItemId)
        sendResult(player, "install", ok, reason, { bijuuId = bijuuId })
    elseif command == "extractHostedBijuu" then
        local ok, reason, bijuuId = Server.extractHostedBijuu(player, args and args.vesselItemId)
        sendResult(player, "extract", ok, reason, { bijuuId = bijuuId })
    end
end

Support.registerDebugAction("install_host_vessel", function(player)
    local ok, reason, bijuuId = Server.debugInstallFirstVessel(player)
    return ok, reason, { bijuuId = bijuuId }
end)

Support.registerDebugAction("extract_hosted_bijuu", function(player)
    local ok, reason, bijuuId = Server.debugExtractHosted(player)
    return ok, reason, { bijuuId = bijuuId }
end)

Support.registerDebugAction("expire_extraction_grace", function(player)
    return Server.debugExpireGrace(player)
end)

Support.registerDebugAction("reconcile_jinchuuriki", function(player)
    local ok, reason, ids = Server.reconcilePlayer(player)
    return ok, reason, { hostedCount = ids and #ids or 0 }
end)

Support.registerDebugAction("unlock_jinchuuriki_tree", function(player)
    return Server.debugUnlockAllJinchuuriki(player)
end)

NinjaLineages.addEventOnce(
    "server.jinchuuriki.onClientCommand",
    Events.OnClientCommand,
    onClientCommand
)

NinjaLineages.addEventOnce(
    "server.jinchuuriki.onCharacterDeath",
    Events.OnCharacterDeath,
    Server.releaseHostedBijuuOnDeath
)

if Events.OnCreatePlayer then
    NinjaLineages.addEventOnce(
        "server.jinchuuriki.onCreatePlayer",
        Events.OnCreatePlayer,
        function(_, player)
            if player then Server.reconcilePlayer(player) end
        end
    )
end

return Server
