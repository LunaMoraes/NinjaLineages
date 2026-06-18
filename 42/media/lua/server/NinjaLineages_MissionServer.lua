require "NinjaLineages_Missions"
require "NinjaLineages_Progression"
require "NinjaLineages_SocialServer"

NinjaLineages = NinjaLineages or {}
NinjaLineages.MissionServer = NinjaLineages.MissionServer or {}

local Server = NinjaLineages.MissionServer
local Missions = NinjaLineages.Missions
local Social = NinjaLineages.Social

local function state()
    return NinjaLineages.SocialServer.getState()
end

local function now()
    if getTimestamp then
        local ok, value = pcall(getTimestamp)
        if ok and value then return tonumber(value) or 0 end
    end
    return os.time()
end

local function copyRecord(source)
    local result = {}
    for key, value in pairs(source or {}) do
        if type(value) ~= "table" then result[key] = value end
    end
    return result
end

local function ensureMissionState()
    local current = state()
    current.missions = current.missions or {}
    current.pendingMissionXP = current.pendingMissionXP or {}
    current.nextMissionID = math.max(1, tonumber(current.nextMissionID) or 1)
    return current
end

local function isUnlocked(village, rank)
    for _, unlocked in ipairs(village.unlockedMissionRanks or {}) do
        if unlocked == rank then return true end
    end
    return false
end

local function updateUnlockedRanks(village)
    village.unlockedMissionRanks = village.unlockedMissionRanks or { "D", "C" }
    local thresholds = NinjaLineages.Balance.Missions.VillageRankUnlockXP
    for _, rank in ipairs({ "B", "A", "S" }) do
        if (tonumber(village.xp) or 0) >= (tonumber(thresholds[rank]) or math.huge)
                and not isUnlocked(village, rank) then
            table.insert(village.unlockedMissionRanks, rank)
        end
    end
end

local function normalize()
    local current = ensureMissionState()
    for _, village in pairs(current.villages or {}) do
        village.xp = math.max(0, tonumber(village.xp) or 0)
        village.unlockedMissionRanks = village.unlockedMissionRanks or { "D", "C" }
        updateUnlockedRanks(village)
    end

    local maximumID = 0
    for missionID, mission in pairs(current.missions) do
        local number = tonumber(tostring(missionID):match("^mission_(%d+)$"))
        if number and number > maximumID then maximumID = number end
        if type(mission) ~= "table"
                or not current.villages[mission.villageId]
                or not Missions.STATUSES[mission.status] then
            current.missions[missionID] = nil
        else
            mission.id = mission.id or missionID
            mission.type = "custom"
            if mission.status == "active" then
                local team = current.teams[mission.teamId]
                if not team or team.activeMissionId ~= missionID then
                    mission.status = "cancelled"
                    mission.resolvedAt = mission.resolvedAt or now()
                end
            end
        end
    end
    current.nextMissionID = math.max(current.nextMissionID, maximumID + 1)

    for _, team in pairs(current.teams or {}) do
        local mission = team.activeMissionId and current.missions[team.activeMissionId]
        if not mission or mission.status ~= "active" or mission.teamId ~= team.id then
            team.activeMissionId = nil
        end
    end
end

local function nextMissionID(current)
    local value = tonumber(current.nextMissionID) or 1
    current.nextMissionID = value + 1
    return "mission_" .. tostring(value)
end

local function leaderContext(player)
    local current = ensureMissionState()
    local playerKey = Social.getPlayerKey(player, false)
    if not playerKey then return nil, nil, nil, "unstable_identity" end
    local villageID = current.playerVillages[playerKey]
    local village = villageID and current.villages[villageID]
    if not village or village.kageKey ~= playerKey then
        return current, playerKey, nil, "not_kage"
    end
    return current, playerKey, village
end

local function missionSnapshot(player)
    local current = ensureMissionState()
    local playerKey = Social.getPlayerKey(player, true)
    local teamID = playerKey and current.playerTeams[playerKey]
    local villageID = playerKey and current.playerVillages[playerKey]
    local village = villageID and current.villages[villageID]
    local snapshot = {
        myMission = nil,
        managedTeams = {},
        unlockedRanks = {},
    }

    if teamID then
        local team = current.teams[teamID]
        local mission = team and team.activeMissionId and current.missions[team.activeMissionId]
        if mission and mission.status == "active" then
            snapshot.myMission = copyRecord(mission)
            snapshot.myMission.teamName = team.name
        end
    end

    if village and village.kageKey == playerKey then
        for _, rank in ipairs(village.unlockedMissionRanks or {}) do
            table.insert(snapshot.unlockedRanks, rank)
        end
        for _, managedTeamID in ipairs(village.teamIDs or {}) do
            local team = current.teams[managedTeamID]
            if team and team.villageID == village.id then
                local entry = {
                    teamId = team.id,
                    teamName = team.name,
                    memberCount = #(team.members or {}),
                }
                local mission = team.activeMissionId and current.missions[team.activeMissionId]
                if mission and mission.status == "active" then
                    entry.mission = copyRecord(mission)
                    entry.mission.teamName = team.name
                end
                table.insert(snapshot.managedTeams, entry)
            end
        end
        table.sort(snapshot.managedTeams, function(a, b)
            return tostring(a.teamName) < tostring(b.teamName)
        end)
    end
    return snapshot
end

local function sendSnapshot(player)
    local snapshot = missionSnapshot(player)
    if NinjaLineages.isServer() then
        sendServerCommand(player, "NinjaLineages", "missionSnapshot", snapshot)
    else
        Missions.setSnapshot(snapshot)
        if NLJutsuTreeUI and NLJutsuTreeUI.instances then
            for _, ui in pairs(NLJutsuTreeUI.instances) do
                if ui.refreshMissionState then ui:refreshMissionState() end
            end
        end
    end
end

local function sendResult(player, ok, reason, action)
    if NinjaLineages.isServer() then
        sendServerCommand(player, "NinjaLineages", "missionResult", {
            ok = ok == true,
            reason = reason,
            action = action,
        })
    elseif player and player.Say then
        if ok then
            player:Say(getText("UI_NL_Mission_ActionComplete"))
        else
            local key = "UI_NL_Mission_Error_" .. tostring(reason or "unknown")
            local message = getText(key)
            if message == key then
                message = getText("UI_NL_Mission_ActionFailed", tostring(reason or "unknown"))
            end
            player:Say(message)
        end
    end
end

local function forEachOnlinePlayer(callback)
    local players = getOnlinePlayers and getOnlinePlayers()
    if players and players:size() > 0 then
        for index = 0, players:size() - 1 do
            local player = players:get(index)
            if player then callback(player) end
        end
        return
    end
    if getNumActivePlayers and getSpecificPlayer then
        for index = 0, getNumActivePlayers() - 1 do
            local player = getSpecificPlayer(index)
            if player then callback(player) end
        end
    end
end

local function broadcastSnapshots()
    forEachOnlinePlayer(sendSnapshot)
end

local function findOnlinePlayer(playerKey)
    local found
    forEachOnlinePlayer(function(candidate)
        if not found and Social.getPlayerKey(candidate, false) == playerKey then found = candidate end
    end)
    return found
end

local function creditExactNinjaXP(player, amount)
    amount = math.max(0, tonumber(amount) or 0)
    if not player or amount <= 0 then return end
    NinjaLineages.Progression.setNinjaXP(
        player,
        NinjaLineages.Progression.getNinjaXP(player) + amount
    )
    if NinjaLineages.isServer() then
        sendServerCommand(player, "NinjaLineages", "progressionUpdated", {})
    end
end

local applyPendingReward
local handlers = {}

function handlers.missionRequestSnapshot(player)
    sendSnapshot(player)
    return true
end

function handlers.missionAssign(player, args)
    local current, _, village, reason = leaderContext(player)
    if not village then return false, reason end

    local teamID = args and args.teamId
    local team = teamID and current.teams[teamID]
    if not team or team.villageID ~= village.id then return false, "invalid_team" end
    if #(team.members or {}) < 1 then return false, "empty_team" end
    if team.activeMissionId then return false, "team_has_active_mission" end

    local rank = args and args.rank
    if not Missions.isValidRank(rank) or not isUnlocked(village, rank) then
        return false, "rank_locked"
    end
    local title = Missions.validateText(args and args.title, Missions.MAX_TITLE_LENGTH)
    if not title then return false, "invalid_title" end
    local description = Missions.validateText(
        args and args.description,
        Missions.MAX_DESCRIPTION_LENGTH
    )
    if not description then return false, "invalid_description" end

    local rawNinjaXP, villageXP = Missions.getBalance(rank)
    if not rawNinjaXP or not villageXP then return false, "invalid_rank" end
    local missionID = nextMissionID(current)
    current.missions[missionID] = {
        id = missionID,
        missionId = missionID,
        villageId = village.id,
        teamId = team.id,
        type = "custom",
        rank = rank,
        status = "active",
        title = title,
        description = description,
        ninjaXpReward = NinjaLineages.Balance.scaleNinjaXP(rawNinjaXP),
        villageXpReward = villageXP,
        assignedAt = now(),
    }
    team.activeMissionId = missionID
    return true, "assigned"
end

local function resolveActiveMission(player, args)
    local current, _, village, reason = leaderContext(player)
    if not village then return nil, nil, nil, reason end
    local missionID = args and args.missionId
    local mission = missionID and current.missions[missionID]
    if not mission or mission.villageId ~= village.id then
        return current, village, nil, "mission_not_found"
    end
    if mission.status ~= "active" then return current, village, nil, "mission_not_active" end
    local team = current.teams[mission.teamId]
    if not team or team.villageID ~= village.id or team.activeMissionId ~= mission.id then
        return current, village, nil, "mission_not_active"
    end
    return current, village, mission, nil, team
end

function handlers.missionComplete(player, args)
    local current, village, mission, reason, team = resolveActiveMission(player, args)
    if not mission then return false, reason end
    if #(team.members or {}) < 1 then return false, "empty_team" end

    mission.status = "completed"
    mission.resolvedAt = now()
    team.activeMissionId = nil

    local reward = math.max(0, tonumber(mission.ninjaXpReward) or 0)
    for _, memberKey in ipairs(team.members or {}) do
        current.pendingMissionXP[memberKey] =
            (tonumber(current.pendingMissionXP[memberKey]) or 0) + reward
    end
    for _, memberKey in ipairs(team.members or {}) do
        local onlinePlayer = findOnlinePlayer(memberKey)
        if onlinePlayer then applyPendingReward(onlinePlayer) end
    end

    village.xp = math.max(0, tonumber(village.xp) or 0)
        + math.max(0, tonumber(mission.villageXpReward) or 0)
    updateUnlockedRanks(village)
    return true, "completed"
end

local function resolveWithoutReward(player, args, status)
    local _, _, mission, reason, team = resolveActiveMission(player, args)
    if not mission then return false, reason end
    mission.status = status
    mission.resolvedAt = now()
    team.activeMissionId = nil
    return true, status
end

function handlers.missionFail(player, args)
    return resolveWithoutReward(player, args, "failed")
end

function handlers.missionCancel(player, args)
    return resolveWithoutReward(player, args, "cancelled")
end

function Server.handleCommand(command, player, args)
    ensureMissionState()
    local handler = handlers[command]
    if not handler then return false end
    local ok, success, reason = pcall(handler, player, args or {})
    if not ok then
        print("[NinjaLineages Missions] " .. tostring(command) .. " failed: " .. tostring(success))
        sendResult(player, false, "server_error", command)
        return true
    end
    if command ~= "missionRequestSnapshot" then
        sendResult(player, success, reason, command)
        if success then
            broadcastSnapshots()
            if NinjaLineages.SocialServer.broadcastSnapshots then
                NinjaLineages.SocialServer.broadcastSnapshots()
            end
        end
    end
    return true
end

local function onClientCommand(module, command, player, args)
    if module ~= "NinjaLineages" or not handlers[command] then return end
    Server.handleCommand(command, player, args)
end

applyPendingReward = function(player)
    local current = ensureMissionState()
    local playerKey = Social.getPlayerKey(player, false)
    local pending = playerKey and tonumber(current.pendingMissionXP[playerKey]) or 0
    if not playerKey or pending <= 0 then return end
    creditExactNinjaXP(player, pending)
    current.pendingMissionXP[playerKey] = nil
end

local function onPlayerConnected(player)
    normalize()
    applyPendingReward(player)
    sendSnapshot(player)
end

local function onInitGlobalModData()
    normalize()
end

NinjaLineages.addEventOnce(
    "server.missions.onInitGlobalModData",
    Events.OnInitGlobalModData,
    onInitGlobalModData
)
NinjaLineages.addEventOnce(
    "server.missions.onClientCommand",
    Events.OnClientCommand,
    onClientCommand
)
if Events.OnConnected then
    NinjaLineages.addEventOnce("server.missions.onConnected", Events.OnConnected, onPlayerConnected)
end
if Events.OnCreatePlayer then
    NinjaLineages.addEventOnce("server.missions.onCreatePlayer", Events.OnCreatePlayer, function(_, player)
        onPlayerConnected(player)
    end)
end
