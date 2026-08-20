require "NinjaLineages_Utils"
require "NinjaLineages_AbilityAuthority"

NinjaLineages = NinjaLineages or {}
NinjaLineages.BijuuServerSupport = NinjaLineages.BijuuServerSupport or {}

local Support = NinjaLineages.BijuuServerSupport
Support.debugHandlers = Support.debugHandlers or {}

function Support.isAuthoritative()
    return not (isClient and isClient() and not (isServer and isServer()))
end

function Support.emit(kind, payload, player)
    payload = payload or {}
    payload.kind = kind

    if NinjaLineages.isServer and NinjaLineages.isServer() then
        if player then
            sendServerCommand(player, "NinjaLineages", "abilityEvent", payload)
        else
            sendServerCommand("NinjaLineages", "abilityEvent", payload)
        end
    elseif NinjaLineages.AbilityAuthority and NinjaLineages.AbilityAuthority.handleEvent then
        NinjaLineages.AbilityAuthority.handleEvent(payload)
    end
end

function Support.canUseDebug(player)
    local enabled = (isDebugEnabled and isDebugEnabled())
        or (SandboxVars and SandboxVars.NinjaLineages and SandboxVars.NinjaLineages.DebugMode == true)
    if not enabled or not player then return false end
    if NinjaLineages.isSinglePlayer and NinjaLineages.isSinglePlayer() then return true end
    local ok, accessLevel = pcall(function() return player:getAccessLevel() end)
    return ok and string.lower(tostring(accessLevel or "")) == "admin"
end

function Support.sendDebugResult(player, action, ok, reason, extra)
    if not player then return end
    local payload = extra or {}
    payload.ok = ok == true
    payload.action = action
    payload.reason = reason
    if NinjaLineages.isServer and NinjaLineages.isServer() then
        sendServerCommand(player, "NinjaLineages", "debugResult", payload)
    end
end

function Support.registerDebugAction(action, handler)
    if type(action) == "string" and type(handler) == "function" then
        Support.debugHandlers[action] = handler
    end
end

local function onClientCommand(module, command, player, args)
    if module ~= "NinjaLineages" or command ~= "bijuuDebug" then return end
    local action = args and args.action
    if not Support.canUseDebug(player) then
        Support.sendDebugResult(player, action, false, "unauthorized")
        return
    end

    local handler = action and Support.debugHandlers[action]
    if not handler then
        Support.sendDebugResult(player, action, false, "unknown_action")
        return
    end

    local called, ok, reason, extra = pcall(handler, player, args or {})
    if not called then
        print("ERROR: [NL-BIJUU-DEBUG] action=" .. tostring(action) .. " failed: " .. tostring(ok))
        Support.sendDebugResult(player, action, false, "server_error")
        return
    end
    Support.sendDebugResult(player, action, ok, reason, extra)
end

NinjaLineages.addEventOnce(
    "server.bijuuDebug.onClientCommand",
    Events.OnClientCommand,
    onClientCommand
)
