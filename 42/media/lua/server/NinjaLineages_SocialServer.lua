require "NinjaLineages_Traits"
require "NinjaLineages_Progression"
require "NinjaLineages_Social"

NinjaLineages = NinjaLineages or {}
NinjaLineages.SocialServer = NinjaLineages.SocialServer or {}

local Server = NinjaLineages.SocialServer
local Social = NinjaLineages.Social
local state

local function now()
    if getTimestamp then
        local ok, value = pcall(getTimestamp)
        if ok and value then return tonumber(value) or 0 end
    end
    return os.time()
end

local function defaultState()
    return {
        version = Social.VERSION,
        teams = {},
        villages = {},
        playerTeams = {},
        playerVillages = {},
        pendingInvites = {},
        knownPlayers = {},
        reputationFlags = {},
        missions = {},
        pendingMissionXP = {},
        nextTeamID = 1,
        nextVillageID = 1,
        nextInviteID = 1,
        nextMissionID = 1,
    }
end

local function ensureState()
    state = ModData.getOrCreate(Social.DATA_KEY)
    local defaults = defaultState()
    for key, value in pairs(defaults) do
        if state[key] == nil then state[key] = value end
    end
    state.teams = state.teams or {}
    state.villages = state.villages or {}
    state.playerTeams = state.playerTeams or {}
    state.playerVillages = state.playerVillages or {}
    state.pendingInvites = state.pendingInvites or {}
    state.knownPlayers = state.knownPlayers or {}
    state.reputationFlags = state.reputationFlags or {}
    state.missions = state.missions or {}
    state.pendingMissionXP = state.pendingMissionXP or {}
    return state
end

function Server.getState()
    return state or ensureState()
end

local function id(prefix, counterName)
    local value = tonumber(state[counterName]) or 1
    state[counterName] = value + 1
    return prefix .. tostring(value)
end

local function copyTable(source)
    local result = {}
    for key, value in pairs(source or {}) do
        result[key] = type(value) == "table" and copyTable(value) or value
    end
    return result
end

local function shallowRecord(source)
    local result = {}
    for key, value in pairs(source or {}) do
        result[key] = type(value) == "table" and copyTable(value) or value
    end
    return result
end

local function snapshotFor(player)
    local snapshot = {
        version = state.version,
        teams = {},
        villages = {},
        playerTeams = {},
        playerVillages = {},
        pendingInvites = {},
        reputationFlags = {},
        knownPlayers = {},
    }
    for teamID, team in pairs(state.teams) do snapshot.teams[teamID] = shallowRecord(team) end
    for villageID, village in pairs(state.villages) do snapshot.villages[villageID] = shallowRecord(village) end
    for key, value in pairs(state.playerTeams) do snapshot.playerTeams[key] = value end
    for key, value in pairs(state.playerVillages) do snapshot.playerVillages[key] = value end

    -- Runtime aliases let clients resolve remote IsoPlayers even when the
    -- engine does not expose their Steam ID on that client.
    local onlinePlayers = getOnlinePlayers and getOnlinePlayers()
    if onlinePlayers then
        for i = 0, onlinePlayers:size() - 1 do
            local candidate = onlinePlayers:get(i)
            local stableKey = Social.getPlayerKey(candidate, false)
            if stableKey then
                local username = candidate.getUsername and candidate:getUsername() or nil
                local onlineID = candidate.getOnlineID and candidate:getOnlineID() or nil
                local aliases = {}
                if username then table.insert(aliases, "user:" .. tostring(username)) end
                if onlineID ~= nil then table.insert(aliases, "online:" .. tostring(onlineID)) end
                for _, alias in ipairs(aliases) do
                    if state.playerTeams[stableKey] then snapshot.playerTeams[alias] = state.playerTeams[stableKey] end
                    if state.playerVillages[stableKey] then snapshot.playerVillages[alias] = state.playerVillages[stableKey] end
                end
            end
        end
    end

    local playerKey = Social.getPlayerKey(player, true)
    for inviteID, invite in pairs(state.pendingInvites) do
        if invite.targetKey == playerKey then
            snapshot.pendingInvites[inviteID] = shallowRecord(invite)
        end
    end
    snapshot.me = {
        playerKey = playerKey,
        teamID = playerKey and state.playerTeams[playerKey] or nil,
        villageID = playerKey and state.playerVillages[playerKey] or nil,
    }
    local team = snapshot.me.teamID and state.teams[snapshot.me.teamID] or nil
    local village = snapshot.me.villageID and state.villages[snapshot.me.villageID] or nil
    snapshot.me.isTeamLeader = team ~= nil and team.leaderKey == playerKey
    snapshot.me.isKage = village ~= nil and village.kageKey == playerKey
    if snapshot.me.isKage then
        for knownKey, displayName in pairs(state.knownPlayers) do
            if knownKey ~= playerKey then snapshot.knownPlayers[knownKey] = displayName end
        end
        for recordID, flag in pairs(state.reputationFlags) do
            if flag.sourceVillageId == village.id then
                snapshot.reputationFlags[recordID] = shallowRecord(flag)
            end
        end
    end
    return snapshot
end

local function publicReputationSnapshot()
    local grouped = {}
    for _, flag in pairs(state.reputationFlags) do
        local targetID = flag.targetPlayerId
        if targetID then
            local entry = grouped[targetID]
            if not entry then
                entry = {
                    playerName = flag.targetPlayerName or state.knownPlayers[targetID] or "Unknown",
                    flags = {},
                }
                grouped[targetID] = entry
            end
            table.insert(entry.flags, {
                flagType = flag.flagType,
                severity = flag.severity,
                sourceVillageName = flag.sourceVillageName,
            })
        end
    end

    local players = {}
    for _, entry in pairs(grouped) do
        table.sort(entry.flags, function(a, b)
            if a.sourceVillageName ~= b.sourceVillageName then
                return tostring(a.sourceVillageName) < tostring(b.sourceVillageName)
            end
            return tostring(a.flagType) < tostring(b.flagType)
        end)
        table.insert(players, entry)
    end
    table.sort(players, function(a, b)
        return tostring(a.playerName) < tostring(b.playerName)
    end)
    return { players = players }
end

local function forEachOnlinePlayer(callback)
    local players = getOnlinePlayers and getOnlinePlayers()
    if players and players:size() > 0 then
        for i = 0, players:size() - 1 do
            local player = players:get(i)
            if player then callback(player) end
        end
        return
    end
    if getNumActivePlayers and getSpecificPlayer then
        for i = 0, getNumActivePlayers() - 1 do
            local player = getSpecificPlayer(i)
            if player then callback(player) end
        end
    end
end

local function sendSnapshot(player)
    if not player then return end
    if NinjaLineages.isServer() then
        sendServerCommand(player, "NinjaLineages", "socialSnapshot", snapshotFor(player))
    else
        Social.setSnapshot(snapshotFor(player))
    end
end

local function sendReputationSnapshot(player)
    local snapshot = publicReputationSnapshot()
    if NinjaLineages.isServer() then
        sendServerCommand(player, "NinjaLineages", "reputationSnapshot", snapshot)
    elseif NinjaLineages.BingoBook and NinjaLineages.BingoBook.receiveSnapshot then
        NinjaLineages.BingoBook.receiveSnapshot(snapshot)
    end
end

local function broadcastSnapshots()
    forEachOnlinePlayer(sendSnapshot)
end

function Server.broadcastSnapshots()
    broadcastSnapshots()
end

local function result(player, ok, reason, action)
    local payload = { ok = ok == true, reason = reason, action = action }
    if NinjaLineages.isServer() then
        sendServerCommand(player, "NinjaLineages", "socialResult", payload)
    elseif player and player.Say then
        player:Say(ok and "Social action completed." or ("Social action failed: " .. tostring(reason)))
    end
end

local function findOnlinePlayerByID(onlineID)
    local found
    forEachOnlinePlayer(function(candidate)
        if found or not candidate.getOnlineID then return end
        local ok, candidateID = pcall(function() return candidate:getOnlineID() end)
        if ok and tonumber(candidateID) == tonumber(onlineID) then found = candidate end
    end)
    return found
end

local function findOnlinePlayerByKey(playerKey)
    local found
    forEachOnlinePlayer(function(candidate)
        if not found and Social.getPlayerKey(candidate, true) == playerKey then found = candidate end
    end)
    return found
end

local function isNear(a, b)
    if not a or not b or a == b then return false end
    local ok, distance = pcall(function() return a:DistTo(b) end)
    return ok and distance <= Social.INVITE_RANGE
end

local function removeFromArray(values, wanted)
    for index = #(values or {}), 1, -1 do
        if values[index] == wanted then table.remove(values, index) end
    end
end

local function reputationRecordID(targetPlayerId, sourceVillageId, flagType)
    return tostring(#targetPlayerId) .. ":" .. targetPlayerId
        .. tostring(#sourceVillageId) .. ":" .. sourceVillageId
        .. tostring(#flagType) .. ":" .. flagType
end

local function normalizeReputationState()
    for _, team in pairs(state.teams or {}) do
        for playerKey, displayName in pairs(team.memberNames or {}) do
            if not state.knownPlayers[playerKey] then state.knownPlayers[playerKey] = displayName end
        end
    end
    for _, village in pairs(state.villages or {}) do
        for playerKey, displayName in pairs(village.memberNames or {}) do
            if not state.knownPlayers[playerKey] then state.knownPlayers[playerKey] = displayName end
        end
    end

    local normalized = {}
    for _, flag in pairs(state.reputationFlags or {}) do
        local targetID = flag.targetPlayerId
        local villageID = flag.sourceVillageId
        local flagType = flag.flagType
        if targetID and villageID and Social.isValidReputationFlagType(flagType)
                and state.villages[villageID] then
            local village = state.villages[villageID]
            flag.targetPlayerName = state.knownPlayers[targetID] or flag.targetPlayerName or "Unknown"
            flag.sourceVillageName = village.name
            flag.severity = math.max(1, math.min(
                Social.MAX_FLAG_SEVERITY,
                math.floor(tonumber(flag.severity) or 1)
            ))
            normalized[reputationRecordID(targetID, villageID, flagType)] = flag
        end
    end
    state.reputationFlags = normalized
end

local function rebuildIndexes()
    state.playerTeams = {}
    state.playerVillages = {}
    local invalidNormalTeams = {}
    for teamID, team in pairs(state.teams) do
        team.id = team.id or teamID
        team.members = team.members or {}
        team.memberNames = team.memberNames or {}
        local uniqueMembers = {}
        for _, memberKey in ipairs(team.members) do
            if memberKey and not state.playerTeams[memberKey] then
                state.playerTeams[memberKey] = teamID
                table.insert(uniqueMembers, memberKey)
            end
        end
        team.members = uniqueMembers
        if team.leaderKey and state.playerTeams[team.leaderKey] ~= teamID then team.leaderKey = nil end
        if not team.villageID and (#team.members < 2 or not team.leaderKey) then
            table.insert(invalidNormalTeams, teamID)
        end
    end
    for _, teamID in ipairs(invalidNormalTeams) do
        local team = state.teams[teamID]
        for _, memberKey in ipairs((team and team.members) or {}) do
            if state.playerTeams[memberKey] == teamID then state.playerTeams[memberKey] = nil end
        end
        state.teams[teamID] = nil
    end
    for villageID, village in pairs(state.villages) do
        village.id = village.id or villageID
        village.members = village.members or {}
        village.memberNames = village.memberNames or {}
        village.teamIDs = village.teamIDs or {}
        village.unlockedMissionRanks = village.unlockedMissionRanks or { "D", "C" }
        village.xp = tonumber(village.xp) or 0
        local uniqueMembers = {}
        for _, memberKey in ipairs(village.members) do
            if memberKey and not state.playerVillages[memberKey] then
                state.playerVillages[memberKey] = villageID
                table.insert(uniqueMembers, memberKey)
            end
        end
        village.members = uniqueMembers
        local validTeamIDs = {}
        for _, teamID in ipairs(village.teamIDs) do
            local team = state.teams[teamID]
            if team and team.villageID == villageID then table.insert(validTeamIDs, teamID) end
        end
        village.teamIDs = validTeamIDs
    end
end

local function rebuildCounters()
    local function nextAfter(records, prefix)
        local maximum = 0
        for recordID in pairs(records or {}) do
            local number = tonumber(tostring(recordID):match("^" .. prefix .. "(%d+)$"))
            if number and number > maximum then maximum = number end
        end
        return maximum + 1
    end
    state.nextTeamID = math.max(tonumber(state.nextTeamID) or 1, nextAfter(state.teams, "team_"))
    state.nextVillageID = math.max(tonumber(state.nextVillageID) or 1, nextAfter(state.villages, "village_"))
    state.nextInviteID = math.max(tonumber(state.nextInviteID) or 1, nextAfter(state.pendingInvites, "invite_"))
end

local function pruneInvites()
    local changed = false
    local current = now()
    for inviteID, invite in pairs(state.pendingInvites) do
        local invalid = not invite.createdAt
            or current - (tonumber(invite.createdAt) or 0) >= Social.INVITE_LIFETIME_SECONDS
        if not invalid and invite.kind == "team" then
            local inviterTeamID = state.playerTeams[invite.inviterKey]
            local inviterTeam = inviterTeamID and state.teams[inviterTeamID] or nil
            invalid = state.playerTeams[invite.targetKey] ~= nil
                or (inviterTeam ~= nil and (
                    inviterTeam.villageID ~= nil
                    or inviterTeam.leaderKey ~= invite.inviterKey
                    or #(inviterTeam.members or {}) >= Social.MAX_TEAM_SIZE
                ))
        elseif not invalid and invite.kind == "village" then
            local inviterVillageID = state.playerVillages[invite.inviterKey]
            local inviterVillage = inviterVillageID and state.villages[inviterVillageID] or nil
            invalid = state.playerVillages[invite.targetKey] ~= nil
                or inviterVillage == nil
                or inviterVillage.kageKey ~= invite.inviterKey
        end
        if invalid then
            state.pendingInvites[inviteID] = nil
            changed = true
        end
    end
    return changed
end

local function disbandTeam(teamID)
    local team = state.teams[teamID]
    if not team then return end
    for _, memberKey in ipairs(team.members or {}) do
        if state.playerTeams[memberKey] == teamID then state.playerTeams[memberKey] = nil end
    end
    if team.villageID and state.villages[team.villageID] then
        removeFromArray(state.villages[team.villageID].teamIDs, teamID)
    end
    state.teams[teamID] = nil
end

local function removePlayerFromVillageTeam(targetKey)
    local teamID = state.playerTeams[targetKey]
    local team = teamID and state.teams[teamID]
    if not team or not team.villageID then return end
    removeFromArray(team.members, targetKey)
    if team.memberNames then team.memberNames[targetKey] = nil end
    if team.leaderKey == targetKey then team.leaderKey = nil end
    if team.member1Key == targetKey then team.member1Key = nil end
    if team.member2Key == targetKey then team.member2Key = nil end
    state.playerTeams[targetKey] = nil
end

local function expelVillageMember(village, targetKey)
    if not village or state.playerVillages[targetKey] ~= village.id then return false end
    removePlayerFromVillageTeam(targetKey)
    removeFromArray(village.members, targetKey)
    if village.memberNames then village.memberNames[targetKey] = nil end
    state.playerVillages[targetKey] = nil
    return true
end

local function createInvite(kind, inviter, target, proposedName)
    local inviterKey = Social.getPlayerKey(inviter, false)
    local targetKey = Social.getPlayerKey(target, false)
    if not inviterKey or not targetKey then return false, "unstable_identity" end
    if not isNear(inviter, target) then return false, "out_of_range" end

    for _, pending in pairs(state.pendingInvites) do
        if pending.kind == kind and pending.inviterKey == inviterKey and pending.targetKey == targetKey then
            return false, "invite_pending"
        end
    end

    if kind == "team" then
        if state.playerTeams[targetKey] then return false, "target_has_team" end
        local teamID = state.playerTeams[inviterKey]
        local team = teamID and state.teams[teamID] or nil
        if team then
            if team.villageID then return false, "village_team_locked" end
            if team.leaderKey ~= inviterKey then return false, "not_team_leader" end
            if #(team.members or {}) >= Social.MAX_TEAM_SIZE then return false, "team_full" end
        else
            proposedName = Social.validateDisplayName(proposedName)
            if not proposedName then return false, "invalid_name" end
        end
    elseif kind == "village" then
        if state.playerVillages[targetKey] then return false, "target_has_village" end
        local villageID = state.playerVillages[inviterKey]
        local village = villageID and state.villages[villageID] or nil
        if not village or village.kageKey ~= inviterKey then return false, "not_kage" end
    else
        return false, "invalid_invite"
    end

    local inviteID = id("invite_", "nextInviteID")
    state.pendingInvites[inviteID] = {
        id = inviteID,
        kind = kind,
        inviterKey = inviterKey,
        inviterName = Social.getPlayerDisplayName(inviter),
        targetKey = targetKey,
        targetName = Social.getPlayerDisplayName(target),
        proposedName = proposedName,
        createdAt = now(),
    }
    return true
end

local function acceptTeamInvite(invite, player)
    local targetKey = Social.getPlayerKey(player, false)
    local inviter = findOnlinePlayerByKey(invite.inviterKey)
    if targetKey ~= invite.targetKey then return false, "wrong_target" end
    if not inviter or not isNear(inviter, player) then return false, "out_of_range" end
    if state.playerTeams[targetKey] then return false, "already_has_team" end

    local inviterTeamID = state.playerTeams[invite.inviterKey]
    local inviterTeam = inviterTeamID and state.teams[inviterTeamID] or nil
    if inviterTeam then
        if inviterTeam.villageID then return false, "village_team_locked" end
        if inviterTeam.leaderKey ~= invite.inviterKey then return false, "not_team_leader" end
        if #inviterTeam.members >= Social.MAX_TEAM_SIZE then return false, "team_full" end
        table.insert(inviterTeam.members, targetKey)
        inviterTeam.memberNames[targetKey] = Social.getPlayerDisplayName(player)
        state.playerTeams[targetKey] = inviterTeamID
        return true
    end

    if state.playerTeams[invite.inviterKey] then return false, "inviter_team_changed" end
    local teamName = Social.validateDisplayName(invite.proposedName)
    if not teamName then return false, "invalid_name" end
    local teamID = id("team_", "nextTeamID")
    state.teams[teamID] = {
        id = teamID,
        name = teamName,
        leaderKey = invite.inviterKey,
        members = { invite.inviterKey, targetKey },
        memberNames = {
            [invite.inviterKey] = invite.inviterName,
            [targetKey] = Social.getPlayerDisplayName(player),
        },
        villageID = nil,
    }
    state.playerTeams[invite.inviterKey] = teamID
    state.playerTeams[targetKey] = teamID
    return true
end

local function acceptVillageInvite(invite, player)
    local targetKey = Social.getPlayerKey(player, false)
    if targetKey ~= invite.targetKey then return false, "wrong_target" end
    if state.playerVillages[targetKey] then return false, "already_has_village" end
    local villageID = state.playerVillages[invite.inviterKey]
    local village = villageID and state.villages[villageID] or nil
    if not village or village.kageKey ~= invite.inviterKey then return false, "not_kage" end
    local inviter = findOnlinePlayerByKey(invite.inviterKey)
    if not inviter or not isNear(inviter, player) then return false, "out_of_range" end
    table.insert(village.members, targetKey)
    village.memberNames[targetKey] = Social.getPlayerDisplayName(player)
    state.playerVillages[targetKey] = villageID
    return true
end

local handlers = {}

function handlers.socialRequestSnapshot(player)
    pruneInvites()
    sendSnapshot(player)
    return true
end

function handlers.socialRequestReputationSnapshot(player)
    sendReputationSnapshot(player)
    return true
end

function handlers.socialApplyReputationFlag(player, args)
    local actorKey = Social.getPlayerKey(player, false)
    if not actorKey then return false, "unstable_identity" end
    local villageID = state.playerVillages[actorKey]
    local village = villageID and state.villages[villageID]
    if not village or village.kageKey ~= actorKey then return false, "not_kage" end

    local targetKey = args and args.targetPlayerId
    local flagType = args and args.flagType
    if not targetKey or not state.knownPlayers[targetKey] then return false, "unknown_player" end
    if targetKey == actorKey then return false, "cannot_flag_self" end
    if not Social.isValidReputationFlagType(flagType) then return false, "invalid_flag_type" end

    local recordID = reputationRecordID(targetKey, villageID, flagType)
    local flag = state.reputationFlags[recordID]
    if flag then
        flag.severity = math.min(
            Social.MAX_FLAG_SEVERITY,
            math.max(1, tonumber(flag.severity) or 1) + 1
        )
        flag.targetPlayerName = state.knownPlayers[targetKey]
        flag.sourceVillageName = village.name
    else
        state.reputationFlags[recordID] = {
            targetPlayerId = targetKey,
            targetPlayerName = state.knownPlayers[targetKey],
            sourceVillageId = villageID,
            sourceVillageName = village.name,
            flagType = flagType,
            severity = 1,
        }
    end

    if state.playerVillages[targetKey] == villageID then
        expelVillageMember(village, targetKey)
        rebuildIndexes()
    end
    return true, "reputation_flag_applied"
end

function handlers.socialPardonReputationFlag(player, args)
    local actorKey = Social.getPlayerKey(player, false)
    if not actorKey then return false, "unstable_identity" end
    local villageID = state.playerVillages[actorKey]
    local village = villageID and state.villages[villageID]
    if not village or village.kageKey ~= actorKey then return false, "not_kage" end

    local targetKey = args and args.targetPlayerId
    local flagType = args and args.flagType
    if not targetKey or not Social.isValidReputationFlagType(flagType) then
        return false, "invalid_flag"
    end
    local recordID = reputationRecordID(targetKey, villageID, flagType)
    if not state.reputationFlags[recordID] then return false, "flag_not_found" end
    state.reputationFlags[recordID] = nil
    return true, "reputation_flag_pardoned"
end

function handlers.socialInviteTeam(player, args)
    local target = findOnlinePlayerByID(args and args.targetOnlineID)
    if not target then return false, "target_offline" end
    return createInvite("team", player, target, args and args.teamName)
end

function handlers.socialInviteVillage(player, args)
    local target = findOnlinePlayerByID(args and args.targetOnlineID)
    if not target then return false, "target_offline" end
    return createInvite("village", player, target)
end

function handlers.socialRespondInvite(player, args)
    pruneInvites()
    local inviteID = args and args.inviteID
    local invite = inviteID and state.pendingInvites[inviteID]
    if not invite then return false, "invite_expired" end
    if invite.targetKey ~= Social.getPlayerKey(player, false) then return false, "wrong_target" end
    state.pendingInvites[inviteID] = nil
    if args.accept ~= true then return true, "declined" end
    if invite.kind == "team" then return acceptTeamInvite(invite, player) end
    if invite.kind == "village" then return acceptVillageInvite(invite, player) end
    return false, "invalid_invite"
end

function handlers.socialRenameTeam(player, args)
    local playerKey = Social.getPlayerKey(player, false)
    local teamID = args and args.teamID
    local team = teamID and state.teams[teamID]

    if not team then
        teamID = playerKey and state.playerTeams[playerKey]
        team = teamID and state.teams[teamID]
    end

    if not team then return false, "no_team" end

    local isAuthorized = false
    if team.leaderKey == playerKey then
        isAuthorized = true
    else
        local villageID = team.villageID
        local village = villageID and state.villages[villageID]
        if village and village.kageKey == playerKey then
            isAuthorized = true
        end
    end

    if not isAuthorized then return false, "not_team_leader" end

    local name = Social.validateDisplayName(args and args.name)
    if not name then return false, "invalid_name" end
    team.name = name
    return true
end

function handlers.socialKickTeamMember(player, args)
    local playerKey = Social.getPlayerKey(player, false)
    local teamID = playerKey and state.playerTeams[playerKey]
    local team = teamID and state.teams[teamID]
    local targetKey = args and args.targetKey
    if not team or team.leaderKey ~= playerKey then return false, "not_team_leader" end
    if not targetKey or targetKey == playerKey or state.playerTeams[targetKey] ~= teamID then
        return false, "invalid_target"
    end
    removeFromArray(team.members, targetKey)
    team.memberNames[targetKey] = nil
    state.playerTeams[targetKey] = nil
    if not team.villageID and #team.members <= 1 then disbandTeam(teamID) end
    return true
end

function handlers.socialLeaveTeam(player)
    local playerKey = Social.getPlayerKey(player, false)
    local teamID = playerKey and state.playerTeams[playerKey]
    local team = teamID and state.teams[teamID]
    if not team then return false, "no_team" end
    if not team.villageID and team.leaderKey == playerKey then
        disbandTeam(teamID)
        return true
    end
    removeFromArray(team.members, playerKey)
    team.memberNames[playerKey] = nil
    state.playerTeams[playerKey] = nil
    if team.leaderKey == playerKey then team.leaderKey = nil end
    if not team.villageID and #team.members <= 1 then disbandTeam(teamID) end
    return true
end

function handlers.socialDisbandTeam(player)
    local playerKey = Social.getPlayerKey(player, false)
    local teamID = playerKey and state.playerTeams[playerKey]
    local team = teamID and state.teams[teamID]
    if not team or team.leaderKey ~= playerKey then return false, "not_team_leader" end
    if team.villageID then return false, "village_team_locked" end
    disbandTeam(teamID)
    return true
end

function handlers.socialCreateVillage(player, args)
    local playerKey = Social.getPlayerKey(player, false)
    if not playerKey then return false, "unstable_identity" end
    if state.playerVillages[playerKey] then return false, "already_has_village" end
    if NinjaLineages.Progression.getNinjaRank(player) ~= "KAGE" then return false, "rank_required" end

    local name = Social.validateDisplayName(args and args.name)
    local symbolID = args and args.symbolID
    local title = args and args.title
    if not name then return false, "invalid_name" end
    if not Social.getSymbol(symbolID) then return false, "invalid_symbol" end
    
    local titleValid = false
    if title then
        for _, t in ipairs(Social.VillageTitles) do
            if t == title then
                titleValid = true
                break
            end
        end
    end
    if not titleValid then return false, "invalid_title" end

    local normalized = Social.normalizeName(name)
    for _, village in pairs(state.villages) do
        if Social.normalizeName(village.name) == normalized then return false, "village_name_taken" end
        if village.symbolID == symbolID then return false, "village_symbol_taken" end
        if village.title == title then return false, "village_title_taken" end
    end

    local teamID = state.playerTeams[playerKey]
    local team = teamID and state.teams[teamID] or nil
    if team then
        for _, memberKey in ipairs(team.members or {}) do
            if state.playerVillages[memberKey] then return false, "teammate_has_village" end
        end
    end

    local villageID = id("village_", "nextVillageID")
    local members = team and copyTable(team.members) or { playerKey }
    local memberNames = {}
    if team then
        for key, displayName in pairs(team.memberNames or {}) do memberNames[key] = displayName end
    else
        memberNames[playerKey] = Social.getPlayerDisplayName(player)
    end
    state.villages[villageID] = {
        id = villageID,
        name = name,
        symbolID = symbolID,
        title = title,
        kageKey = playerKey,
        members = members,
        memberNames = memberNames,
        teamIDs = team and { teamID } or {},
        xp = 0,
        unlockedMissionRanks = { "D", "C" },
    }
    for _, memberKey in ipairs(members) do state.playerVillages[memberKey] = villageID end
    if team then team.villageID = villageID end
    return true
end

function handlers.socialRenameVillage(player, args)
    local playerKey = Social.getPlayerKey(player, false)
    local villageID = playerKey and state.playerVillages[playerKey]
    local village = villageID and state.villages[villageID]
    if not village or village.kageKey ~= playerKey then return false, "not_kage" end

    local name = Social.validateDisplayName(args and args.name)
    if not name then return false, "invalid_name" end

    local normalized = Social.normalizeName(name)
    for vid, v in pairs(state.villages) do
        if vid ~= villageID and Social.normalizeName(v.name) == normalized then
            return false, "village_name_taken"
        end
    end

    village.name = name
    for _, flag in pairs(state.reputationFlags) do
        if flag.sourceVillageId == villageID then flag.sourceVillageName = name end
    end
    return true
end

function handlers.socialCreateVillageTeam(player, args)
    local playerKey = Social.getPlayerKey(player, false)
    local villageID = playerKey and state.playerVillages[playerKey]
    local village = villageID and state.villages[villageID]
    if not village or village.kageKey ~= playerKey then return false, "not_kage" end

    local name = Social.validateDisplayName(args and args.name)
    if not name then return false, "invalid_name" end

    local teamID = id("team_", "nextTeamID")
    state.teams[teamID] = {
        id = teamID,
        name = name,
        leaderKey = nil,
        members = {},
        memberNames = {},
        villageID = villageID,
        member1Key = nil,
        member2Key = nil,
    }

    table.insert(village.teamIDs, teamID)
    return true, "village_team_created"
end

function handlers.socialAssignTeamMember(player, args)
    local playerKey = Social.getPlayerKey(player, false)
    local villageID = playerKey and state.playerVillages[playerKey]
    local village = villageID and state.villages[villageID]
    if not village or village.kageKey ~= playerKey then return false, "not_kage" end

    local teamID = args and args.teamID
    local team = teamID and state.teams[teamID]
    if not team or team.villageID ~= villageID then return false, "invalid_team" end

    local slot = args and args.slot -- "leader", "member1", "member2"
    local targetKey = args and args.targetKey

    if targetKey == "" then targetKey = nil end

    if targetKey then
        if state.playerVillages[targetKey] ~= villageID then return false, "target_not_in_village" end
        local existingTeamID = state.playerTeams[targetKey]
        if existingTeamID and existingTeamID ~= teamID then return false, "target_has_team" end
    end

    -- Remove target from their current slot in this team if they are already in the team in a different slot
    if targetKey then
        if slot ~= "leader" and team.leaderKey == targetKey then team.leaderKey = nil end
        if slot ~= "member1" and team.member1Key == targetKey then team.member1Key = nil end
        if slot ~= "member2" and team.member2Key == targetKey then team.member2Key = nil end
    end

    -- Assign slot and identify what key was replaced
    local oldKey
    if slot == "leader" then
        oldKey = team.leaderKey
        team.leaderKey = targetKey
    elseif slot == "member1" then
        oldKey = team.member1Key
        team.member1Key = targetKey
    elseif slot == "member2" then
        oldKey = team.member2Key
        team.member2Key = targetKey
    end

    if oldKey then
        state.playerTeams[oldKey] = nil
    end
    if targetKey then
        state.playerTeams[targetKey] = teamID
    end

    -- Reconstruct members array and memberNames mapping
    local members = {}
    local memberNames = {}
    if team.leaderKey then
        table.insert(members, team.leaderKey)
        memberNames[team.leaderKey] = village.memberNames[team.leaderKey] or "Unknown"
    end
    if team.member1Key then
        table.insert(members, team.member1Key)
        memberNames[team.member1Key] = village.memberNames[team.member1Key] or "Unknown"
    end
    if team.member2Key then
        table.insert(members, team.member2Key)
        memberNames[team.member2Key] = village.memberNames[team.member2Key] or "Unknown"
    end
    team.members = members
    team.memberNames = memberNames

    return true
end

function Server.handleCommand(command, player, args)
    ensureState()
    local playerKey = Social.getPlayerKey(player, false)
    if playerKey then state.knownPlayers[playerKey] = Social.getPlayerDisplayName(player) end
    pruneInvites()
    local handler = handlers[command]
    if not handler then return false end
    local ok, success, reason = pcall(handler, player, args or {})
    if not ok then
        print("[NinjaLineages Social] " .. tostring(command) .. " failed: " .. tostring(success))
        result(player, false, "server_error", command)
        return true
    end
    if command == "socialRequestReputationSnapshot" then
        return true
    end
    if command ~= "socialRequestSnapshot" then
        result(player, success, reason, command)
        broadcastSnapshots()
    end
    return true
end

local function onClientCommand(module, command, player, args)
    if module ~= "NinjaLineages" or not handlers[command] then return end
    Server.handleCommand(command, player, args)
end

local function onInitGlobalModData()
    ensureState()
    rebuildIndexes()
    rebuildCounters()
    normalizeReputationState()
    pruneInvites()
end

local function onPlayerConnected(player)
    ensureState()
    pruneInvites()
    local playerKey = Social.getPlayerKey(player, false)
    if playerKey then
        local displayName = Social.getPlayerDisplayName(player)
        state.knownPlayers[playerKey] = displayName
        for _, flag in pairs(state.reputationFlags) do
            if flag.targetPlayerId == playerKey then flag.targetPlayerName = displayName end
        end
        local teamID = state.playerTeams[playerKey]
        local team = teamID and state.teams[teamID]
        if team and team.memberNames then
            team.memberNames[playerKey] = displayName
        end
        local villageID = state.playerVillages[playerKey]
        local village = villageID and state.villages[villageID]
        if village and village.memberNames then
            village.memberNames[playerKey] = displayName
        end
    end
    sendSnapshot(player)
end

local function everyMinute()
    ensureState()
    if pruneInvites() then broadcastSnapshots() end
end

NinjaLineages.addEventOnce(
    "server.social.onInitGlobalModData",
    Events.OnInitGlobalModData,
    onInitGlobalModData
)
NinjaLineages.addEventOnce(
    "server.social.onClientCommand",
    Events.OnClientCommand,
    onClientCommand
)
if Events.OnConnected then
    NinjaLineages.addEventOnce("server.social.onConnected", Events.OnConnected, onPlayerConnected)
end
NinjaLineages.addEventOnce("server.social.everyMinute", Events.EveryOneMinute, everyMinute)
