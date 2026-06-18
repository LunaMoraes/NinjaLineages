NinjaLineages = NinjaLineages or {}
NinjaLineages.Social = NinjaLineages.Social or {}

local Social = NinjaLineages.Social

Social.DATA_KEY = "NinjaLineagesSocial"
Social.VERSION = 1
Social.INVITE_LIFETIME_SECONDS = 60
Social.INVITE_RANGE = 2
Social.MAX_TEAM_SIZE = 3

-- Add new village symbols here when their square texture is added.
Social.VillageSymbols = Social.VillageSymbols or {
    "media/ui/villages/icons/village_symbol_01.png",
    "media/ui/villages/icons/village_symbol_02.png",
    "media/ui/villages/icons/village_symbol_03.png",
    "media/ui/villages/icons/village_symbol_04.png",
    "media/ui/villages/icons/village_symbol_05.png",
    "media/ui/villages/icons/village_symbol_06.png",
    "media/ui/villages/icons/village_symbol_07.png",
    "media/ui/villages/icons/village_symbol_08.png",
    "media/ui/villages/icons/village_symbol_09.png",
    "media/ui/villages/icons/village_symbol_10.png",
    "media/ui/villages/icons/village_symbol_11.png",
    "media/ui/villages/icons/village_symbol_12.png",
    "media/ui/villages/icons/village_symbol_13.png",
}

local function safePlayerValue(player, method)
    if not player or not player[method] then return nil end
    local ok, value = pcall(function() return player[method](player) end)
    if not ok then return nil end
    return value
end

local function isLocalPlayer(player)
    if not player or not getSpecificPlayer then return false end
    local playerNum = safePlayerValue(player, "getPlayerNum")
    if playerNum == nil or tonumber(playerNum) == nil or tonumber(playerNum) < 0 then return false end
    return getSpecificPlayer(tonumber(playerNum)) == player
end

local function playerMatchesKey(player, wantedKey)
    if not player or not wantedKey then return false end
    local candidates = {}
    local primary = Social.getPlayerKey(player, true)
    if primary then candidates[primary] = true end
    local username = safePlayerValue(player, "getUsername")
    if username and tostring(username) ~= "" then candidates["user:" .. tostring(username)] = true end
    local onlineID = safePlayerValue(player, "getOnlineID")
    if onlineID ~= nil then candidates["online:" .. tostring(onlineID)] = true end
    local state = Social.getState()
    if isLocalPlayer(player) and state and state.me and state.me.playerKey then
        candidates[state.me.playerKey] = true
    end
    return candidates[wantedKey] == true
end

function Social.trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

function Social.normalizeName(value)
    return string.lower(Social.trim(value))
end

function Social.validateDisplayName(value)
    local name = Social.trim(value)
    if #name < 1 or #name > 32 then return nil end
    return name
end

function Social.getPlayerKey(player, allowRuntime)
    if not player then return nil end

    local steamID = safePlayerValue(player, "getSteamID")
    if steamID ~= nil then
        steamID = tostring(steamID)
        if steamID ~= "" and steamID ~= "0" then
            return "steam:" .. steamID
        end
    end

    local username = safePlayerValue(player, "getUsername")
    if username ~= nil and tostring(username) ~= "" then
        return "user:" .. tostring(username)
    end

    if allowRuntime then
        local onlineID = safePlayerValue(player, "getOnlineID")
        if onlineID ~= nil and tonumber(onlineID) and tonumber(onlineID) >= 0 then
            return "online:" .. tostring(onlineID)
        end
    end
    return nil
end

function Social.getPlayerDisplayName(player)
    return tostring(
        safePlayerValue(player, "getDisplayName")
        or safePlayerValue(player, "getUsername")
        or Social.getPlayerKey(player, true)
        or "Unknown"
    )
end

function Social.getSymbolID(texture)
    if not texture then return nil end
    return texture:match("([^/\\]+)%.png$")
end

function Social.getSymbol(symbolID)
    for _, texture in ipairs(Social.VillageSymbols) do
        if Social.getSymbolID(texture) == symbolID then return texture end
    end
    return nil
end

Social._snapshot = Social._snapshot or {
    version = Social.VERSION,
    teams = {},
    villages = {},
    playerTeams = {},
    playerVillages = {},
    pendingInvites = {},
}

function Social.setSnapshot(snapshot)
    if type(snapshot) ~= "table" then return false end
    snapshot.teams = snapshot.teams or {}
    snapshot.villages = snapshot.villages or {}
    snapshot.playerTeams = snapshot.playerTeams or {}
    snapshot.playerVillages = snapshot.playerVillages or {}
    snapshot.pendingInvites = snapshot.pendingInvites or {}
    Social._snapshot = snapshot
    return true
end

function Social.getSnapshot()
    return Social._snapshot
end

function Social.getState()
    if NinjaLineages.SocialServer and NinjaLineages.SocialServer.getState
            and not (isClient and isClient()) then
        return NinjaLineages.SocialServer.getState()
    end
    return Social._snapshot
end

function Social.getMembership(player, indexName)
    local state = Social.getState()
    local index = state and state[indexName]
    if not index or not player then return nil end

    local keys = {}
    local primary = Social.getPlayerKey(player, true)
    if primary then table.insert(keys, primary) end
    local username = safePlayerValue(player, "getUsername")
    if username and tostring(username) ~= "" then table.insert(keys, "user:" .. tostring(username)) end
    local onlineID = safePlayerValue(player, "getOnlineID")
    if onlineID ~= nil then table.insert(keys, "online:" .. tostring(onlineID)) end
    if isLocalPlayer(player) and state.me and state.me.playerKey then
        table.insert(keys, state.me.playerKey)
    end

    for _, key in ipairs(keys) do
        if index[key] ~= nil then return index[key] end
    end
    return nil
end

function Social.getMyTeam(player)
    local state = Social.getState()
    local id = Social.getMembership(player, "playerTeams")
    return id and state.teams and state.teams[id] or nil
end

function Social.getMyVillage(player)
    local state = Social.getState()
    local id = Social.getMembership(player, "playerVillages")
    return id and state.villages and state.villages[id] or nil
end

function Social.getPendingInvites(player)
    local result = {}
    local state = Social.getState()
    local keys = {}
    local key = Social.getPlayerKey(player, true)
    if key then keys[key] = true end
    local username = safePlayerValue(player, "getUsername")
    if username and tostring(username) ~= "" then keys["user:" .. tostring(username)] = true end
    local onlineID = safePlayerValue(player, "getOnlineID")
    if onlineID ~= nil then keys["online:" .. tostring(onlineID)] = true end
    if state and state.me and state.me.playerKey then keys[state.me.playerKey] = true end
    for _, invite in pairs((state and state.pendingInvites) or {}) do
        if keys[invite.targetKey] then table.insert(result, invite) end
    end
    table.sort(result, function(a, b)
        return (tonumber(a.createdAt) or 0) < (tonumber(b.createdAt) or 0)
    end)
    return result
end
function Social.isTeamLeader(player)
    local team = Social.getMyTeam(player)
    return team ~= nil and playerMatchesKey(player, team.leaderKey)
end

function Social.isKage(player)
    local village = Social.getMyVillage(player)
    return village ~= nil and playerMatchesKey(player, village.kageKey)
end

function Social.areSameTeam(playerA, playerB)
    if not playerA or not playerB then return false end
    local teamA = Social.getMembership(playerA, "playerTeams")
    local teamB = Social.getMembership(playerB, "playerTeams")
    return teamA ~= nil and teamB ~= nil and teamA == teamB
end

function Social.areSameVillage(playerA, playerB)
    if not playerA or not playerB then return false end
    local villageA = Social.getMembership(playerA, "playerVillages")
    local villageB = Social.getMembership(playerB, "playerVillages")
    return villageA ~= nil and villageB ~= nil and villageA == villageB
end

function Social.request(player, command, args)
    if not player or not command then return false end
    if isClient and isClient() then
        sendClientCommand(player, "NinjaLineages", command, args or {})
        return true
    end
    if NinjaLineages.SocialServer and NinjaLineages.SocialServer.handleCommand then
        NinjaLineages.SocialServer.handleCommand(command, player, args or {})
        if NLJutsuTreeUI and NLJutsuTreeUI.instances then
            for _, ui in pairs(NLJutsuTreeUI.instances) do
                if ui.refreshSocialState then ui:refreshSocialState() end
            end
        end
        return true
    end
    return false
end
