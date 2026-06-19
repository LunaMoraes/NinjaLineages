require "ISUI/ISContextMenu"
require "ISUI/ISModalDialog"
require "ISUI/ISTextBox"
require "NinjaLineages_UI"
require "NinjaLineages_Social"

NinjaLineages = NinjaLineages or {}
NinjaLineages.SocialClient = NinjaLineages.SocialClient or {}

local Client = NinjaLineages.SocialClient
local Social = NinjaLineages.Social
Client.shownInvites = Client.shownInvites or {}

local function translated(key, fallback, ...)
    local value = getText(key, ...)
    if value == key then return fallback or key end
    return value
end

local function localPlayer()
    return getSpecificPlayer and getSpecificPlayer(0) or getPlayer()
end

local function say(message)
    local player = localPlayer()
    if player and player.Say then player:Say(message) end
end

local function refreshSocialViews()
    if not NLJutsuTreeUI or not NLJutsuTreeUI.instances then return end
    for _, ui in pairs(NLJutsuTreeUI.instances) do
        if ui.refreshSocialState then ui:refreshSocialState() end
    end
end

local function respondToInvite(_, button, inviteID)
    local player = localPlayer()
    if not player then return end
    Social.request(player, "socialRespondInvite", {
        inviteID = inviteID,
        accept = button.internal == "YES",
    })
end

local function showPendingInvites()
    local player = localPlayer()
    if not player then return end
    local active = {}
    for _, invite in ipairs(Social.getPendingInvites(player)) do
        active[invite.id] = true
        if not Client.shownInvites[invite.id] then
            Client.shownInvites[invite.id] = true
            local label
            if invite.kind == "team" then
                label = translated(
                    "UI_NL_Social_TeamInvitePrompt",
                    "%1 invites you to join team \"%2\".",
                    invite.inviterName,
                    tostring(invite.proposedName or translated("UI_NL_Social_TheirTeam", "their team"))
                )
            else
                label = translated(
                    "UI_NL_Social_VillageInvitePrompt",
                    "%1 invites you to join their hidden village.",
                    invite.inviterName
                )
            end
            local modal = ISModalDialog:new(
                0, 0, 420, 160, label, true, nil, respondToInvite,
                player:getPlayerNum(), invite.id
            )
            modal:initialise()
            modal:addToUIManager()
        end
    end
    for inviteID in pairs(Client.shownInvites) do
        if not active[inviteID] then Client.shownInvites[inviteID] = nil end
    end
end

local function sendTeamInvite(player, target, teamName)
    Social.request(player, "socialInviteTeam", {
        targetOnlineID = target:getOnlineID(),
        teamName = teamName,
    })
end

local function onTeamNameEntered(target, button, player)
    if button.internal ~= "OK" then return end
    local name = button.parent.entry:getText()
    sendTeamInvite(player, target, name)
end

local function inviteToTeam(player, target)
    local team = Social.getMyTeam(player)
    if team then
        sendTeamInvite(player, target, nil)
        return
    end
    local box = ISTextBox:new(
        0, 0, 420, 160, translated("UI_NL_Social_NameTeam", "Name your new team:"), "",
        target, onTeamNameEntered, player:getPlayerNum(), player
    )
    box:initialise()
    box.entry:setMaxTextLength(32)
    box:addToUIManager()
end

local function inviteToVillage(player, target)
    Social.request(player, "socialInviteVillage", {
        targetOnlineID = target:getOnlineID(),
    })
end

local function collectNearbyPlayers(player)
    local result = {}
    local players = getOnlinePlayers and getOnlinePlayers()
    if not players then return result end
    for i = 0, players:size() - 1 do
        local target = players:get(i)
        if target and target ~= player then
            local ok, distance = pcall(function() return player:DistTo(target) end)
            if ok and distance <= Social.INVITE_RANGE then table.insert(result, target) end
        end
    end
    table.sort(result, function(a, b)
        return Social.getPlayerDisplayName(a) < Social.getPlayerDisplayName(b)
    end)
    return result
end

local function addSocialContextMenu(playerNum, context, worldObjects, test)
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end
    local nearby = collectNearbyPlayers(player)
    if #nearby == 0 then return end
    if test then return true end

    local root = NinjaLineages.UI.getOrCreateWorldSubMenu(context)
    local socialOption = root:addOption(translated("UI_NL_Social_Menu", "Social"))
    local socialMenu = ISContextMenu:getNew(root)
    root:addSubMenu(socialOption, socialMenu)

    local canTeamInvite = not Social.getMyTeam(player) or Social.isTeamLeader(player)
    local canVillageInvite = Social.isKage(player)
    for _, target in ipairs(nearby) do
        local targetOption = socialMenu:addOption(Social.getPlayerDisplayName(target))
        local targetMenu = ISContextMenu:getNew(socialMenu)
        socialMenu:addSubMenu(targetOption, targetMenu)
        if canTeamInvite and not Social.getMyTeam(target) then
            targetMenu:addOption(translated("UI_NL_Social_InviteTeam", "Invite to Team"), player, inviteToTeam, target)
        end
        if canVillageInvite and not Social.getMyVillage(target) then
            targetMenu:addOption(translated("UI_NL_Social_InviteVillage", "Invite to Village"), player, inviteToVillage, target)
        end
    end
end

local function onServerCommand(module, command, args)
    if module ~= "NinjaLineages" then return end
    if command == "socialSnapshot" then
        Social.setSnapshot(args or {})
        showPendingInvites()
        refreshSocialViews()
    elseif command == "socialResult" then
        if args and args.ok then
            if args.reason == "village_team_created" then
                say(translated("UI_NL_Social_PromptAddMembers", "Empty team created. Click the slots to add members."))
            elseif args.reason == "village_left" then
                say(translated("UI_NL_Social_VillageLeft", "You left the village."))
            elseif args.reason == "mission_deserted" then
                say(translated("UI_NL_Social_MissionDeserted", "You deserted your active mission."))
            elseif args.reason == "mission_betrayed" then
                say(translated("UI_NL_Social_MissionBetrayed", "You betrayed the active mission."))
            elseif args.reason == "village_disbanded" then
                say(translated("UI_NL_Social_VillageDisbanded", "The village was disbanded."))
            elseif args.reason ~= "declined" then
                say(translated("UI_NL_Social_ActionComplete", "Social action completed."))
            end
        else
            local reason = tostring(args and args.reason or "unknown")
            say(translated(
                "UI_NL_Social_Error_" .. reason,
                translated("UI_NL_Social_ActionFailed", "Social action failed: %1", reason)
            ))
        end
    end
end

local function requestSnapshot(playerNum, player)
    player = player or (getSpecificPlayer and getSpecificPlayer(playerNum or 0))
    if player then Social.request(player, "socialRequestSnapshot", {}) end
end

NinjaLineages.addEventOnce(
    "client.social.onServerCommand",
    Events.OnServerCommand,
    onServerCommand
)
NinjaLineages.addEventOnce(
    "client.social.onFillWorldObjectContextMenu",
    Events.OnFillWorldObjectContextMenu,
    addSocialContextMenu
)
NinjaLineages.addEventOnce(
    "client.social.onCreatePlayer",
    Events.OnCreatePlayer,
    requestSnapshot
)
