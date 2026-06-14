require "NinjaLineages_Traits"
require "NinjaLineages_JutsuCatalog"

NinjaLineages = NinjaLineages or {}
NinjaLineages.AbilityAuthority = NinjaLineages.AbilityAuthority or {}

local Authority = NinjaLineages.AbilityAuthority

Authority.REQUEST_TIMEOUT_MS = 5000
Authority.handlers = Authority.handlers or {}
Authority.pending = Authority.pending or {}
Authority.seenRequests = Authority.seenRequests or {}
Authority.nextRequestId = Authority.nextRequestId or 0
Authority.lastSeenPruneAt = Authority.lastSeenPruneAt or 0

local function playerKey(player)
    if not player then return "unknown" end
    if player.getOnlineID then
        local ok, id = pcall(function() return player:getOnlineID() end)
        if ok and id and id >= 0 then return "online:" .. tostring(id) end
    end
    if player.getPlayerNum then
        local ok, num = pcall(function() return player:getPlayerNum() end)
        if ok and num then return "local:" .. tostring(num) end
    end
    return tostring(player)
end

local function pendingKey(player, actionId)
    return playerKey(player) .. ":" .. tostring(actionId)
end

function Authority.register(actionId, handler)
    if not actionId or type(handler) ~= "function" then return end
    Authority.handlers[actionId] = handler
end

function Authority.isPending(player, actionId)
    local key = pendingKey(player, actionId)
    local pending = Authority.pending[key]
    if not pending then return false end
    if NinjaLineages.Utils.Time.realMilliseconds() - pending.startedAt >= Authority.REQUEST_TIMEOUT_MS then
        Authority.pending[key] = nil
        return false
    end
    return true
end

function Authority.request(player, actionId, args, presentation)
    if not player or not actionId or Authority.isPending(player, actionId) then return false end

    Authority.nextRequestId = Authority.nextRequestId + 1
    local requestId = tostring(playerKey(player)) .. ":" .. tostring(Authority.nextRequestId)
    local key = pendingKey(player, actionId)
    Authority.pending[key] = {
        requestId = requestId,
        actionId = actionId,
        startedAt = NinjaLineages.Utils.Time.realMilliseconds(),
        player = player,
        skipSeal = presentation and presentation.skipSeal == true,
    }

    if isClient and isClient() then
        sendClientCommand(player, "NinjaLineages", "abilityRequest", {
            requestId = requestId,
            actionId = actionId,
            args = args or {},
        })
        return true
    end

    local result = Authority.execute(player, requestId, actionId, args or {})
    result.localPlayerNum = player.getPlayerNum and player:getPlayerNum() or 0
    Authority.handleResult(result)
    if result.ok and result.state and result.state.event then
        Authority.handleEvent(result.state.event)
    end
    return result.ok == true
end

function Authority.updatePending()
    local now = NinjaLineages.Utils.Time.realMilliseconds()
    for key, pending in pairs(Authority.pending) do
        if now - pending.startedAt >= Authority.REQUEST_TIMEOUT_MS then
            Authority.pending[key] = nil
            if pending.player then
                pending.player:Say(getText("UI_NL_Error_AbilityRequestTimedOut"))
            end
        end
    end
end

function Authority.execute(player, requestId, actionId, args)
    local result = {
        requestId = requestId,
        actionId = actionId,
        ok = false,
    }

    if type(requestId) ~= "string" or requestId == "" or #requestId > 128
            or type(actionId) ~= "string" or actionId == "" or #actionId > 64
            or type(args) ~= "table" then
        result.reason = "malformed"
        return result
    end
    if not player or player:isDead() then
        result.reason = "invalid_player"
        return result
    end
    if player:getVehicle() then
        result.reason = "busy"
        return result
    end

    local seenKey = playerKey(player) .. ":" .. tostring(requestId)
    if Authority.seenRequests[seenKey] then
        result.reason = "duplicate"
        return result
    end
    Authority.seenRequests[seenKey] = NinjaLineages.Utils.Time.realMilliseconds()

    local handler = Authority.handlers[actionId]
    if not handler then
        result.reason = "unknown_action"
        return result
    end

    local ok, executed, reason, remaining, state = pcall(handler, player, args or {})
    if not ok then
        result.reason = "server_error"
        print("ERROR: [AbilityAuthority] '" .. tostring(actionId) .. "' failed: " .. tostring(executed))
        return result
    end

    result.ok = executed == true
    result.reason = reason
    result.remaining = remaining
    result.state = state
    return result
end

local externalSuccessMessages = {
    alarm_seal = "UI_NL_Ability_AlarmSeal_Cast",
    storage_seal = "UI_NL_Ability_StorageSeal_Cast",
    storage_unseal = "UI_NL_Ability_StorageSeal_Unsealed",
}

local errorMessages = {
    chakra = "UI_NL_Error_NotEnoughChakra",
    no_target = "UI_NL_Error_NoFacingTarget",
    not_learned = "UI_NL_Error_JutsuNotLearned",
    busy = "UI_NL_HandSigns_Busy",
    locked = "UI_NL_Error_MangekyoLocked",
    no_wounds = "UI_NL_NoWounds",
    invalid_item = "UI_NL_Error_NoAlarmSealItem",
}

local function abilityDisplayName(actionId)
    local definition = NinjaLineages.JutsuCatalog.get(actionId)
    if definition then
        local ability = NinjaLineages.JutsuCatalog.toAbility(definition)
        local translated = getText(ability.name)
        if translated ~= ability.name then return translated end
        return ability.nameFallback or actionId
    end
    return tostring(actionId)
end

local function findLocalPlayer(onlineId, localPlayerNum)
    if localPlayerNum ~= nil and getSpecificPlayer then
        local localPlayer = getSpecificPlayer(localPlayerNum)
        if localPlayer then return localPlayer end
    end
    if not getNumActivePlayers or not getSpecificPlayer then return getPlayer and getPlayer() or nil end
    for index = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(index)
        if player and (onlineId == nil or player:getOnlineID() == onlineId) then return player end
    end
    return nil
end

function Authority.handleResult(result)
    if not result then return end
    local player = findLocalPlayer(result.casterOnlineId, result.localPlayerNum)
    if not player then return end

    local key = pendingKey(player, result.actionId)
    local pending = Authority.pending[key]
    if pending and pending.requestId ~= result.requestId then return end
    Authority.pending[key] = nil

    if result.ok then
        if result.state and result.state.voice then
            pcall(function() player:playerVoiceSound(result.state.voice) end)
        end
        if result.state and result.state.messageKey then
            player:Say(getText(result.state.messageKey))
        else
            local definition = NinjaLineages.JutsuCatalog.get(result.actionId)
            local messageKey = definition
                and definition.presentation
                and definition.presentation.castMessageKey
                or externalSuccessMessages[result.actionId]
            if not messageKey and definition then
                messageKey = "UI_NL_Ability_" .. definition.id .. "_Cast"
            end
            if messageKey then
                local message = getText(messageKey)
                if message ~= messageKey then player:Say(message) end
            end
        end
        if NinjaLineages.HandSigns
                and result.actionId ~= "storage_unseal"
                and not (pending and pending.skipSeal) then
            NinjaLineages.HandSigns.playAbilitySeal(player, result.actionId)
        end
    elseif result.reason == "cooldown" then
        player:Say(getText(
            "UI_NL_Error_AbilityOnCooldown",
            abilityDisplayName(result.actionId),
            tostring(result.remaining or 0)
        ))
    elseif errorMessages[result.reason] then
        player:Say(getText(errorMessages[result.reason]))
    end
end

function Authority.pruneSeenRequests()
    local now = NinjaLineages.Utils.Time.realMilliseconds()
    if now - Authority.lastSeenPruneAt < 60000 then return end
    Authority.lastSeenPruneAt = now
    for key, seenAt in pairs(Authority.seenRequests) do
        if now - seenAt >= 60000 then Authority.seenRequests[key] = nil end
    end
end

function Authority.handleEvent(args)
    if not args then return end
    if args.kind == "shinra_tensei_pulse"
            and NinjaLineages.Rinnegan
            and NinjaLineages.Rinnegan.addPulse then
        NinjaLineages.Rinnegan.addPulse(args.x, args.y, args.z)
        local caster = findLocalPlayer(args.casterOnlineId)
        if caster then
            pcall(function()
                caster:playerVoiceSound(NinjaLineages.Constants.Rinnegan.ShinraTensei.ACTIVATION_VOICE)
            end)
        end
    elseif args.kind == "alarm_triggered" then
        local player = findLocalPlayer(args.casterOnlineId)
        if player then player:Say(getText("UI_NL_Ability_AlarmSeal_Triggered")) end
    elseif args.kind == "sharingan_evade" then
        local player = findLocalPlayer(args.casterOnlineId)
        if player then
            player:setHitReaction("EvasiveBlocked")
            pcall(function() player:playSound(NinjaLineages.Constants.Uchiha.Audio.DODGE_EFFECT) end)
            player:Say(getText("UI_NL_Ability_Sharingan_Evade"))
        end
    end
end

function Authority.onServerCommand(module, command, args)
    if module ~= "NinjaLineages" then return end
    if command == "abilityResult" then
        Authority.handleResult(args)
    elseif command == "abilityEvent" then
        Authority.handleEvent(args)
    end
end

if Events and Events.OnServerCommand then
    Events.OnServerCommand.Add(Authority.onServerCommand)
end
