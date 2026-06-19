require "ISUI/ISModalDialog"
require "ISUI/ISTextEntryBox"
require "ISUI/ISComboBox"
require "NinjaLineages_Missions"

NinjaLineages = NinjaLineages or {}
NinjaLineages.MissionPanel = NinjaLineages.MissionPanel or {}

local MissionPanel = NinjaLineages.MissionPanel
MissionPanel.__index = MissionPanel

local function text(key, ...)
    return getText(key, ...)
end

local function wrapText(value, maximumWidth, font)
    local lines = {}
    local current = ""
    for word in tostring(value or ""):gmatch("%S+") do
        local candidate = current == "" and word or (current .. " " .. word)
        if current ~= "" and getTextManager():MeasureStringX(font, candidate) > maximumWidth then
            table.insert(lines, current)
            current = word
        else
            current = candidate
        end
    end
    if current ~= "" then table.insert(lines, current) end
    return lines
end

function MissionPanel:new(host)
    return setmetatable({
        host = host,
        active = false,
        managementTab = "custom",
        selectedTeamId = nil,
        teamCombo = nil,
        rankCombo = nil,
        titleEntry = nil,
        descriptionEntry = nil,
        cardButtons = nil,
        selectedMissionId = nil,
        boardPage = 1,
    }, self)
end

function MissionPanel:isActive()
    return self.active == true
        and (self.host.screen == "mission_board" or self.host.screen == "mission_manage")
end

function MissionPanel:clearState()
    self.teamCombo = nil
    self.rankCombo = nil
    self.titleEntry = nil
    self.descriptionEntry = nil
    self.cardButtons = nil
end

function MissionPanel:addButton(x, y, width, height, title, callback)
    return self.host:addButton(x, y, width, height, title, self, callback)
end

local function makeCardHitbox(button)
    button.background = false
    button.border = false
    button.displayBackground = false
    button.isBaseBackgroundVisible = false
    button.isHighlightedBackgroundVisible = false
    button.isBorderVisible = false
end

function MissionPanel:openBoard()
    self.host:clearControls()
    self:clearState()
    self.active = true
    self.host.screen = "mission_board"
    self:createBoardScreen()
    NinjaLineages.Missions.request(self.host.player, "missionRequestSnapshot", {})
end

function MissionPanel:openManage()
    if not NinjaLineages.Social.isKage(self.host.player) then return end
    self.host:clearControls()
    self:clearState()
    self.active = true
    self.host.screen = "mission_manage"
    self:createManagementScreen()
    NinjaLineages.Missions.request(self.host.player, "missionRequestSnapshot", {})
end

function MissionPanel:closeBoard()
    self.active = false
    self.host:createSelectionScreen()
end

function MissionPanel:closeManagement()
    self.active = false
    self.host.socialPanel:open("village")
end

function MissionPanel:getSelectedTeam()
    local snapshot = NinjaLineages.Missions.getSnapshot()
    local selectedID = self.teamCombo and self.teamCombo:getSelectedData() or self.selectedTeamId
    for _, team in ipairs(snapshot.managedTeams or {}) do
        if team.teamId == selectedID then return team end
    end
    return nil
end

function MissionPanel:getSelectedMission(collection)
    for _, mission in ipairs(collection or {}) do
        if mission.id == self.selectedMissionId then return mission end
    end
    return nil
end

function MissionPanel:addTeamCombo(y, callback)
    local managedTeams = NinjaLineages.Missions.getSnapshot().managedTeams or {}
    if #managedTeams == 0 then return end
    self.teamCombo = ISComboBox:new(70, y, 300, 28, self, callback)
    self.teamCombo:initialise()
    self.teamCombo:instantiate()
    self.host.contentPanel:addChild(self.teamCombo)
    local selectedIndex = 1
    for index, team in ipairs(managedTeams) do
        self.teamCombo:addOptionWithData(team.teamName, team.teamId)
        if team.teamId == self.selectedTeamId then selectedIndex = index end
    end
    self.teamCombo.selected = selectedIndex
    self.selectedTeamId = self.teamCombo:getSelectedData()
end

function MissionPanel:createManagementScreen()
    local w = self.host.contentPanel.width
    self:addButton(20, 20, 100, 32, text("UI_NL_Tree_Back"), MissionPanel.closeManagement)

    local custom = self:addButton(
        w / 2 - 205, 70, 195, 34,
        text("UI_NL_Mission_CustomPanel"),
        MissionPanel.onCustomTab
    )
    local available = self:addButton(
        w / 2 + 10, 70, 195, 34,
        text("UI_NL_Mission_AvailablePanel"),
        MissionPanel.onAvailableTab
    )
    custom.enable = self.managementTab ~= "custom"
    available.enable = self.managementTab ~= "available"

    if self.managementTab == "available" then
        self:createAvailableManagement()
    else
        self:createCustomManagement()
    end
end

function MissionPanel:createCustomManagement()
    local w = self.host.contentPanel.width
    local snapshot = NinjaLineages.Missions.getSnapshot()
    if #(snapshot.managedTeams or {}) == 0 then return end

    self:addTeamCombo(132, MissionPanel.onTeamChanged)
    local team = self:getSelectedTeam()
    if not team or team.mission then
        if team and team.mission then self:createTerminalButtons(team.mission, w) end
        return
    end

    self.titleEntry = ISTextEntryBox:new("", 70, 210, math.floor(w * 0.58), 28)
    self.titleEntry:initialise()
    self.titleEntry:instantiate()
    self.titleEntry:setMaxTextLength(NinjaLineages.Missions.MAX_TITLE_LENGTH)
    self.host.contentPanel:addChild(self.titleEntry)

    self.descriptionEntry = ISTextEntryBox:new("", 70, 280, math.floor(w * 0.58), 135)
    self.descriptionEntry:initialise()
    self.descriptionEntry:instantiate()
    self.descriptionEntry:setMultipleLine(true)
    self.descriptionEntry:setMaxTextLength(NinjaLineages.Missions.MAX_DESCRIPTION_LENGTH)
    self.host.contentPanel:addChild(self.descriptionEntry)

    self.rankCombo = ISComboBox:new(70, 460, 160, 28, self, nil)
    self.rankCombo:initialise()
    self.rankCombo:instantiate()
    self.host.contentPanel:addChild(self.rankCombo)
    for _, rank in ipairs(snapshot.unlockedRanks or {}) do
        self.rankCombo:addOptionWithData(rank, rank)
    end

    local assign = self:addButton(250, 455, 180, 38, text("UI_NL_Mission_Assign"), MissionPanel.onAssign)
    assign.enable = (team.memberCount or 0) > 0 and #(snapshot.unlockedRanks or {}) > 0
end

local function getCardPosition(index, count, panelWidth, startY)
    local columns = 4
    local cardWidth, cardHeight = 190, 112
    local horizontalGap, verticalGap = 18, 18
    local row = math.floor((index - 1) / columns)
    local column = (index - 1) % columns
    local rowStart = row * columns + 1
    local rowCount = math.min(columns, count - rowStart + 1)
    local rowWidth = rowCount * cardWidth + (rowCount - 1) * horizontalGap
    local rowX = (panelWidth - rowWidth) / 2
    return rowX + column * (cardWidth + horizontalGap),
        startY + row * (cardHeight + verticalGap),
        cardWidth,
        cardHeight
end

function MissionPanel:createAvailableManagement()
    local snapshot = NinjaLineages.Missions.getSnapshot()
    local missions = snapshot.availableMissions or {}
    local w = self.host.contentPanel.width
    self.cardButtons = {}

    local selectedExists = false
    for index, mission in ipairs(missions) do
        local x, y, cardWidth, cardHeight = getCardPosition(index, #missions, w, 135)
        local button = self:addButton(x, y, cardWidth, cardHeight, "", MissionPanel.onAvailableCard)
        makeCardHitbox(button)
        button.missionId = mission.id
        self.cardButtons[mission.id] = button
        if mission.id == self.selectedMissionId then selectedExists = true end
    end
    if not selectedExists then self.selectedMissionId = missions[1] and missions[1].id or nil end

    if #missions > 0 then
        self:addTeamCombo(505, MissionPanel.onTeamChanged)
        local selected = self:getSelectedMission(missions) or missions[1]
        local team = self:getSelectedTeam()
        local assign = self:addButton(
            395, 500, 170, 38,
            text("UI_NL_Mission_Assign"),
            MissionPanel.onAssignGenerated
        )
        assign.enable = selected ~= nil
            and team ~= nil
            and (team.memberCount or 0) > 0
            and team.mission == nil
        local post = self:addButton(
            585, 500, 180, 38,
            text("UI_NL_Mission_DisplayOnBoard"),
            MissionPanel.onPostGenerated
        )
        post.enable = selected ~= nil and selected.status == "available"
    end
end

function MissionPanel:onCustomTab()
    self.managementTab = "custom"
    self.selectedMissionId = nil
    self:refresh()
end

function MissionPanel:onAvailableTab()
    self.managementTab = "available"
    self.selectedMissionId = nil
    self:refresh()
end

function MissionPanel:onAvailableCard(button)
    self.selectedMissionId = button.missionId
    self:refresh()
end

local BOARD_PAGE_SIZE = 8

function MissionPanel:getBoardPageMissions()
    local allMissions = NinjaLineages.Missions.getSnapshot().villageMissions or {}
    local pageCount = math.max(1, math.ceil(#allMissions / BOARD_PAGE_SIZE))
    self.boardPage = math.max(1, math.min(self.boardPage or 1, pageCount))
    local first = ((self.boardPage - 1) * BOARD_PAGE_SIZE) + 1
    local last = math.min(#allMissions, first + BOARD_PAGE_SIZE - 1)
    local pageMissions = {}
    for index = first, last do table.insert(pageMissions, allMissions[index]) end
    return pageMissions, pageCount
end

function MissionPanel:createBoardScreen()
    local w = self.host.contentPanel.width
    self:addButton(20, 20, 100, 32, text("UI_NL_Tree_Back"), MissionPanel.closeBoard)
    local missions, pageCount = self:getBoardPageMissions()
    if pageCount > 1 then
        local previous = self:addButton(w - 150, 20, 48, 32, "<", MissionPanel.onPreviousBoardPage)
        previous.enable = self.boardPage > 1
        local nextPage = self:addButton(w - 70, 20, 48, 32, ">", MissionPanel.onNextBoardPage)
        nextPage.enable = self.boardPage < pageCount
    end
    self.cardButtons = {}
    local selectedExists = false
    for index, mission in ipairs(missions) do
        local x, y, cardWidth, cardHeight = getCardPosition(index, #missions, w, 82)
        local button = self:addButton(x, y, cardWidth, cardHeight, "", MissionPanel.onBoardCard)
        makeCardHitbox(button)
        button.missionId = mission.id
        self.cardButtons[mission.id] = button
        if mission.id == self.selectedMissionId then selectedExists = true end
    end
    if not selectedExists and missions[1] then self.selectedMissionId = missions[1].id end

    local selected = self:getSelectedMission(missions) or missions[1]
    if selected and selected.status == "posted" then
        local accept = self:addButton(
            w - 270, self.host.contentPanel.height - 78, 200, 38,
            text("UI_NL_Mission_Accept"),
            MissionPanel.onAcceptPosted
        )
        accept.missionId = selected.id
        accept.enable = NinjaLineages.Missions.getSnapshot().canAcceptPosted == true
    end
end

function MissionPanel:onBoardCard(button)
    self.selectedMissionId = button.missionId
    self:refresh()
end

function MissionPanel:changeBoardPage(delta)
    self.boardPage = math.max(1, (self.boardPage or 1) + delta)
    self.selectedMissionId = nil
    self:refresh()
end

function MissionPanel:onPreviousBoardPage()
    self:changeBoardPage(-1)
end

function MissionPanel:onNextBoardPage()
    self:changeBoardPage(1)
end

function MissionPanel:createTerminalButtons(mission, w)
    local y = self.host.contentPanel.height - 75
    if mission.type == "kill_zombies" then
        local cancel = self:addButton(
            (w - 160) / 2, y, 160, 38,
            text("UI_NL_Mission_Cancel"),
            MissionPanel.onTerminalAction
        )
        cancel.action = "missionCancel"
        cancel.missionId = mission.id
        return
    end

    local buttonWidth, gap = 140, 18
    local startX = (w - (buttonWidth * 3 + gap * 2)) / 2
    for index, definition in ipairs({
        { title = "UI_NL_Mission_Complete", action = "missionComplete" },
        { title = "UI_NL_Mission_Fail", action = "missionFail" },
        { title = "UI_NL_Mission_Cancel", action = "missionCancel" },
    }) do
        local button = self:addButton(
            startX + (index - 1) * (buttonWidth + gap), y, buttonWidth, 38,
            text(definition.title),
            MissionPanel.onTerminalAction
        )
        button.action = definition.action
        button.missionId = mission.id
    end
end

function MissionPanel:onTeamChanged()
    self.selectedTeamId = self.teamCombo and self.teamCombo:getSelectedData()
    self:refresh()
end

function MissionPanel:onAssign()
    local team = self:getSelectedTeam()
    local rank = self.rankCombo and self.rankCombo:getSelectedData()
    if not team or not rank then return end
    NinjaLineages.Missions.request(self.host.player, "missionAssign", {
        teamId = team.teamId,
        rank = rank,
        title = self.titleEntry and self.titleEntry:getText(),
        description = self.descriptionEntry and self.descriptionEntry:getText(),
    })
end

function MissionPanel:onAssignGenerated()
    local team = self:getSelectedTeam()
    if not team or not self.selectedMissionId then return end
    NinjaLineages.Missions.request(self.host.player, "missionAssignGenerated", {
        teamId = team.teamId,
        missionId = self.selectedMissionId,
    })
end

function MissionPanel:onPostGenerated()
    if not self.selectedMissionId then return end
    NinjaLineages.Missions.request(self.host.player, "missionPostGenerated", {
        missionId = self.selectedMissionId,
    })
end

function MissionPanel:onAcceptPosted(button)
    NinjaLineages.Missions.request(self.host.player, "missionAcceptPosted", {
        missionId = button.missionId,
    })
end

local function confirmTerminal(panel, button, request)
    if button.internal ~= "YES" then return end
    NinjaLineages.Missions.request(
        panel.host.player,
        request.action,
        { missionId = request.missionId }
    )
end

function MissionPanel:onTerminalAction(button)
    local modal = ISModalDialog:new(
        0, 0, 420, 160,
        text("UI_NL_Mission_Confirm_" .. tostring(button.action)),
        true, self, confirmTerminal, self.host.playerNum, {
            action = button.action,
            missionId = button.missionId,
        }
    )
    modal:initialise()
    modal:addToUIManager()
end

function MissionPanel:drawMission(panel, mission, startY)
    local w = panel.width
    panel:drawTextCentre(mission.title or "", w / 2, startY, 1, 1, 1, 1, UIFont.Large)
    panel:drawTextCentre(
        text("UI_NL_Mission_RankValue", mission.rank or "?"),
        w / 2, startY + 42, 0.95, 0.85, 0.65, 1, UIFont.Medium
    )
    panel:drawTextCentre(
        text("UI_NL_Mission_StatusValue", text("UI_NL_Mission_Status_" .. tostring(mission.status))),
        w / 2, startY + 72, 0.75, 0.75, 0.82, 1, UIFont.Small
    )
    local y = startY + 110
    for _, line in ipairs(wrapText(mission.description, w - 180, UIFont.Small)) do
        panel:drawText(line, 90, y, 0.86, 0.86, 0.92, 1, UIFont.Small)
        y = y + 22
    end
    if mission.type == "kill_zombies" then
        panel:drawText(
            text(
                "UI_NL_Mission_KillProgress",
                tostring(mission.currentKillCount or 0),
                tostring(mission.targetKillCount or 0)
            ),
            90, y + 12, 0.95, 0.78, 0.45, 1, UIFont.Medium
        )
        y = y + 34
    end
    panel:drawText(
        text("UI_NL_Mission_NinjaReward", tostring(mission.ninjaXpReward or 0)),
        90, y + 25, 0.75, 0.9, 0.75, 1, UIFont.Medium
    )
    panel:drawText(
        text("UI_NL_Mission_VillageReward", tostring(mission.villageXpReward or 0)),
        90, y + 57, 0.75, 0.9, 0.75, 1, UIFont.Medium
    )
end

function MissionPanel:drawCompactMission(panel, mission, x, y, width, height, hovered, selected)
    local borderR, borderG, borderB = 0.34, 0.34, 0.42
    if hovered or selected then borderR, borderG, borderB = 0.95, 0.72, 0.32 end
    panel:drawRect(x, y, width, height, 0.94, 0.07, 0.07, 0.09)
    panel:drawRectBorder(x, y, width, height, 0.92, borderR, borderG, borderB)
    panel:drawTextCentre(mission.title or "", x + width / 2, y + 10, 0.95, 0.9, 0.78, 1, UIFont.Small)
    panel:drawText(
        text("UI_NL_Mission_BoardRank", mission.rank or "?"),
        x + 12, y + 42, 0.82, 0.82, 0.88, 1, UIFont.Small
    )
    if mission.status ~= "posted" then
        panel:drawText(
            text("UI_NL_Mission_BoardTeam", mission.teamName or ""),
            x + 12, y + 64, 0.82, 0.82, 0.88, 1, UIFont.Small
        )
    end
    panel:drawText(
        text("UI_NL_Mission_BoardStatus", text("UI_NL_Mission_Status_" .. tostring(mission.status))),
        x + 12, y + 86, 0.72, 0.86, 0.72, 1, UIFont.Small
    )
end

function MissionPanel:drawAvailableManagement(panel)
    local missions = NinjaLineages.Missions.getSnapshot().availableMissions or {}
    if #missions == 0 then
        panel:drawTextCentre(
            text("UI_NL_Mission_NoAvailable"),
            panel.width / 2, 170, 0.75, 0.75, 0.82, 1, UIFont.Medium
        )
        return
    end

    local selected = self:getSelectedMission(missions) or missions[1]
    for index, mission in ipairs(missions) do
        local x, y, cardWidth, cardHeight = getCardPosition(index, #missions, panel.width, 135)
        local button = self.cardButtons and self.cardButtons[mission.id]
        self:drawCompactMission(
            panel, mission, x, y, cardWidth, cardHeight,
            button and button:isMouseOver(), mission.id == selected.id
        )
    end

    local detailY = 285
    panel:drawRect(70, detailY, panel.width - 140, 185, 0.72, 0.04, 0.04, 0.06)
    panel:drawRectBorder(70, detailY, panel.width - 140, 185, 0.72, 0.30, 0.30, 0.38)
    panel:drawText(selected.title or "", 90, detailY + 14, 0.95, 0.85, 0.65, 1, UIFont.Medium)
    panel:drawText(selected.description or "", 90, detailY + 48, 0.86, 0.86, 0.92, 1, UIFont.Small)
    panel:drawText(
        text(
            "UI_NL_Mission_KillTarget",
            tostring(selected.targetKillCount or 0)
        ),
        90, detailY + 78, 0.95, 0.78, 0.45, 1, UIFont.Small
    )
    panel:drawText(
        text(
            "UI_NL_Mission_RewardPreview",
            tostring(selected.ninjaXpReward or 0),
            tostring(selected.villageXpReward or 0)
        ),
        90, detailY + 108, 0.72, 0.88, 0.72, 1, UIFont.Small
    )
    panel:drawText(text("UI_NL_Mission_SelectTeam"), 70, 480, 0.9, 0.9, 0.95, 1, UIFont.Small)
end

function MissionPanel:drawBoard(panel)
    local w = panel.width
    local missions, pageCount = self:getBoardPageMissions()
    panel:drawTextCentre(text("UI_NL_Mission_BoardTitle"), w / 2, 28, 0.95, 0.85, 0.65, 1, UIFont.Large)
    if #missions == 0 then
        panel:drawTextCentre(text("UI_NL_Mission_BoardEmpty"), w / 2, 130, 0.75, 0.75, 0.82, 1, UIFont.Medium)
        return
    end
    if pageCount > 1 then
        panel:drawTextRight(
            text("UI_NL_Mission_BoardPage", tostring(self.boardPage), tostring(pageCount)),
            w - 165, 28, 0.72, 0.72, 0.8, 1, UIFont.Small
        )
    end

    local selected = self:getSelectedMission(missions) or missions[1]
    for index, mission in ipairs(missions) do
        local x, y, cardWidth, cardHeight = getCardPosition(index, #missions, w, 82)
        local button = self.cardButtons and self.cardButtons[mission.id]
        self:drawCompactMission(
            panel, mission, x, y, cardWidth, cardHeight,
            button and button:isMouseOver(), mission.id == selected.id
        )
    end

    local detailsY = 350
    local detailsHeight = panel.height - detailsY - 28
    panel:drawRect(70, detailsY, w - 140, detailsHeight, 0.72, 0.04, 0.04, 0.06)
    panel:drawRectBorder(70, detailsY, w - 140, detailsHeight, 0.72, 0.30, 0.30, 0.38)
    panel:drawText(selected.title or "", 90, detailsY + 14, 0.95, 0.85, 0.65, 1, UIFont.Medium)
    local detail = selected.status == "posted"
        and text("UI_NL_Mission_BoardPostedDetail", selected.rank or "?")
        or text("UI_NL_Mission_BoardDetail", selected.teamName or "", selected.rank or "?")
    panel:drawText(detail, 90, detailsY + 45, 0.8, 0.8, 0.88, 1, UIFont.Small)
    local lineY = detailsY + 72
    for _, line in ipairs(wrapText(selected.description, w - 360, UIFont.Small)) do
        panel:drawText(line, 90, lineY, 0.86, 0.86, 0.92, 1, UIFont.Small)
        lineY = lineY + 20
    end
    if selected.type == "kill_zombies" and selected.status == "active" then
        panel:drawText(
            text(
                "UI_NL_Mission_KillProgress",
                tostring(selected.currentKillCount or 0),
                tostring(selected.targetKillCount or 0)
            ),
            90, lineY + 5, 0.95, 0.78, 0.45, 1, UIFont.Small
        )
        lineY = lineY + 25
    end
    panel:drawText(
        text(
            "UI_NL_Mission_RewardPreview",
            tostring(selected.ninjaXpReward or 0),
            tostring(selected.villageXpReward or 0)
        ),
        90, lineY + 8, 0.72, 0.88, 0.72, 1, UIFont.Small
    )
end

function MissionPanel:prerender(panel)
    if not self:isActive() then return end
    if self.host.screen == "mission_board" then
        self:drawBoard(panel)
        return
    end

    panel:drawTextCentre(
        text("UI_NL_Mission_ManageTitle"),
        panel.width / 2, 28, 0.95, 0.85, 0.65, 1, UIFont.Large
    )
    if self.managementTab == "available" then
        self:drawAvailableManagement(panel)
        return
    end

    local snapshot = NinjaLineages.Missions.getSnapshot()
    if #(snapshot.managedTeams or {}) == 0 then return end
    panel:drawText(text("UI_NL_Mission_SelectTeam"), 70, 110, 0.9, 0.9, 0.95, 1, UIFont.Small)
    local team = self:getSelectedTeam()
    if team and team.mission then
        self:drawMission(panel, team.mission, 185)
    elseif team then
        panel:drawText(text("UI_NL_Mission_CustomTitle"), 70, 185, 0.9, 0.9, 0.95, 1, UIFont.Small)
        panel:drawText(text("UI_NL_Mission_Description"), 70, 255, 0.9, 0.9, 0.95, 1, UIFont.Small)
        panel:drawText(text("UI_NL_Mission_Rank"), 70, 435, 0.9, 0.9, 0.95, 1, UIFont.Small)
        local rank = self.rankCombo and self.rankCombo:getSelectedData()
        local ninjaXP, villageXP = NinjaLineages.Missions.getBalance(rank)
        if ninjaXP and villageXP then
            ninjaXP = NinjaLineages.Balance.scaleNinjaXP(ninjaXP)
            panel:drawText(
                text("UI_NL_Mission_RewardPreview", tostring(ninjaXP), tostring(villageXP)),
                70, 505, 0.75, 0.9, 0.75, 1, UIFont.Small
            )
        end
        if (team.memberCount or 0) < 1 then
            panel:drawText(text("UI_NL_Mission_EmptyTeam"), 70, 535, 0.9, 0.55, 0.45, 1, UIFont.Small)
        end
    end
end

function MissionPanel:refresh()
    if not self:isActive() then return end
    local screen = self.host.screen
    self.host:clearControls()
    self:clearState()
    self.active = true
    self.host.screen = screen
    if screen == "mission_board" then
        self:createBoardScreen()
    else
        self:createManagementScreen()
    end
end
