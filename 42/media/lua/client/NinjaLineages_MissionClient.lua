require "NinjaLineages_Missions"

NinjaLineages = NinjaLineages or {}
NinjaLineages.MissionClient = NinjaLineages.MissionClient or {}

local Missions = NinjaLineages.Missions

local function localPlayer()
    return getSpecificPlayer and getSpecificPlayer(0) or getPlayer()
end

local function translated(key, fallback, ...)
    local value = getText(key, ...)
    if value == key then return fallback or key end
    return value
end

local function refreshMissionViews()
    if not NLJutsuTreeUI or not NLJutsuTreeUI.instances then return end
    for _, ui in pairs(NLJutsuTreeUI.instances) do
        if ui.refreshMissionState then ui:refreshMissionState() end
    end
end

local function say(message)
    local player = localPlayer()
    if player and player.Say then player:Say(message) end
end

local function onServerCommand(module, command, args)
    if module ~= "NinjaLineages" then return end
    if command == "missionSnapshot" then
        Missions.setSnapshot(args or {})
        refreshMissionViews()
    elseif command == "missionResult" then
        if args and args.ok then
            say(translated("UI_NL_Mission_ActionComplete", "Mission action completed."))
        else
            local reason = tostring(args and args.reason or "unknown")
            say(translated(
                "UI_NL_Mission_Error_" .. reason,
                translated("UI_NL_Mission_ActionFailed", "Mission action failed: %1", reason)
            ))
        end
    elseif command == "socialSnapshot" then
        local player = localPlayer()
        if player then Missions.request(player, "missionRequestSnapshot", {}) end
    end
end

local function requestSnapshot(playerNum, player)
    player = player or (getSpecificPlayer and getSpecificPlayer(playerNum or 0))
    if player then Missions.request(player, "missionRequestSnapshot", {}) end
end

NinjaLineages.addEventOnce(
    "client.missions.onServerCommand",
    Events.OnServerCommand,
    onServerCommand
)
NinjaLineages.addEventOnce(
    "client.missions.onCreatePlayer",
    Events.OnCreatePlayer,
    requestSnapshot
)
