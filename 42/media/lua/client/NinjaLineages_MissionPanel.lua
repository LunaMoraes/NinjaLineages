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
        selectedTeamId = nil,
        teamCombo = nil,
        rankCombo = nil,
        titleEntry = nil,
        descriptionEntry = nil,
    }, self)
end

function MissionPanel:isActive()
    return self.active == true and self.host.screen == "missions"
end

function MissionPanel:clearState()
    self.teamCombo = nil
    self.rankCombo = nil
    self.titleEntry = nil
    self.descriptionEntry = nil
end

function MissionPanel:addButton(x, y, width, height, title, callback)
    return self.host:addButton(x, y, width, height, title, self, callback)
end

function MissionPanel:open()
    self.host:clearControls()
    self:clearState()
    self.active = true
    self.host.screen = "missions"
    self:createScreen()
    NinjaLineages.Missions.request(self.host.player, "missionRequestSnapshot", {})
end

function MissionPanel:close()
    self.active = false
    self.host:createSelectionScreen()
end

function MissionPanel:getSelectedTeam()
    local snapshot = NinjaLineages.Missions.getSnapshot()
    local selectedID = self.teamCombo and self.teamCombo:getSelectedData() or self.selectedTeamId
    for _, team in ipairs(snapshot.managedTeams or {}) do
        if team.teamId == selectedID then return team end
    end
    return nil
end

function MissionPanel:createScreen()
    local w = self.host.contentPanel.width
    self:addButton(20, 20, 100, 32, text("UI_NL_Tree_Back"), MissionPanel.close)

    local snapshot = NinjaLineages.Missions.getSnapshot()
    local managedTeams = snapshot.managedTeams or {}
    if #managedTeams == 0 then return end

    self.teamCombo = ISComboBox:new(70, 92, 300, 28, self, MissionPanel.onTeamChanged)
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

    local team = self:getSelectedTeam()
    if not team or team.mission then
        if team and team.mission then self:createTerminalButtons(team.mission, w) end
        return
    end

    self.titleEntry = ISTextEntryBox:new("", 70, 180, math.floor(w * 0.58), 28)
    self.titleEntry:initialise()
    self.titleEntry:instantiate()
    self.titleEntry:setMaxTextLength(NinjaLineages.Missions.MAX_TITLE_LENGTH)
    self.host.contentPanel:addChild(self.titleEntry)

    self.descriptionEntry = ISTextEntryBox:new("", 70, 250, math.floor(w * 0.58), 150)
    self.descriptionEntry:initialise()
    self.descriptionEntry:instantiate()
    self.descriptionEntry:setMultipleLine(true)
    self.descriptionEntry:setMaxTextLength(NinjaLineages.Missions.MAX_DESCRIPTION_LENGTH)
    self.host.contentPanel:addChild(self.descriptionEntry)

    self.rankCombo = ISComboBox:new(70, 445, 160, 28, self, nil)
    self.rankCombo:initialise()
    self.rankCombo:instantiate()
    self.host.contentPanel:addChild(self.rankCombo)
    for _, rank in ipairs(snapshot.unlockedRanks or {}) do
        self.rankCombo:addOptionWithData(rank, rank)
    end

    local assign = self:addButton(
        250, 440, 180, 38,
        text("UI_NL_Mission_Assign"),
        MissionPanel.onAssign
    )
    assign.enable = (team.memberCount or 0) > 0 and #(snapshot.unlockedRanks or {}) > 0
end

function MissionPanel:createTerminalButtons(mission, w)
    local buttonWidth = 140
    local gap = 18
    local total = buttonWidth * 3 + gap * 2
    local startX = (w - total) / 2
    local y = self.host.contentPanel.height - 75
    local complete = self:addButton(
        startX, y, buttonWidth, 38,
        text("UI_NL_Mission_Complete"),
        MissionPanel.onTerminalAction
    )
    complete.action = "missionComplete"
    complete.missionId = mission.id
    local fail = self:addButton(
        startX + buttonWidth + gap, y, buttonWidth, 38,
        text("UI_NL_Mission_Fail"),
        MissionPanel.onTerminalAction
    )
    fail.action = "missionFail"
    fail.missionId = mission.id
    local cancel = self:addButton(
        startX + (buttonWidth + gap) * 2, y, buttonWidth, 38,
        text("UI_NL_Mission_Cancel"),
        MissionPanel.onTerminalAction
    )
    cancel.action = "missionCancel"
    cancel.missionId = mission.id
end

function MissionPanel:onTeamChanged()
    self.selectedTeamId = self.teamCombo and self.teamCombo:getSelectedData()
    self.host:clearControls()
    self:clearState()
    self.active = true
    self.host.screen = "missions"
    self:createScreen()
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

local function confirmTerminal(panel, button, request)
    if button.internal ~= "YES" then return end
    NinjaLineages.Missions.request(
        panel.host.player,
        request.action,
        { missionId = request.missionId }
    )
end

function MissionPanel:onTerminalAction(button)
    local promptKey = "UI_NL_Mission_Confirm_" .. tostring(button.action)
    local modal = ISModalDialog:new(
        0, 0, 420, 160, text(promptKey), true,
        self, confirmTerminal, self.host.playerNum, {
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
    panel:drawText(
        text("UI_NL_Mission_NinjaReward", tostring(mission.ninjaXpReward or 0)),
        90, y + 25, 0.75, 0.9, 0.75, 1, UIFont.Medium
    )
    panel:drawText(
        text("UI_NL_Mission_VillageReward", tostring(mission.villageXpReward or 0)),
        90, y + 57, 0.75, 0.9, 0.75, 1, UIFont.Medium
    )
end

function MissionPanel:prerender(panel)
    if not self:isActive() then return end
    local w = panel.width
    panel:drawTextCentre(text("UI_NL_Mission_Title"), w / 2, 28, 0.95, 0.85, 0.65, 1, UIFont.Large)

    local snapshot = NinjaLineages.Missions.getSnapshot()
    if #(snapshot.managedTeams or {}) > 0 then
        panel:drawText(text("UI_NL_Mission_SelectTeam"), 70, 70, 0.9, 0.9, 0.95, 1, UIFont.Small)
        local team = self:getSelectedTeam()
        if team and team.mission then
            self:drawMission(panel, team.mission, 145)
        elseif team then
            panel:drawText(text("UI_NL_Mission_CustomTitle"), 70, 155, 0.9, 0.9, 0.95, 1, UIFont.Small)
            panel:drawText(text("UI_NL_Mission_Description"), 70, 225, 0.9, 0.9, 0.95, 1, UIFont.Small)
            panel:drawText(text("UI_NL_Mission_Rank"), 70, 420, 0.9, 0.9, 0.95, 1, UIFont.Small)
            local rank = self.rankCombo and self.rankCombo:getSelectedData()
            local ninjaXP, villageXP = NinjaLineages.Missions.getBalance(rank)
            if ninjaXP and villageXP then
                ninjaXP = NinjaLineages.Balance.scaleNinjaXP(ninjaXP)
                panel:drawText(
                    text("UI_NL_Mission_RewardPreview", tostring(ninjaXP), tostring(villageXP)),
                    70, 485, 0.75, 0.9, 0.75, 1, UIFont.Small
                )
            end
            if (team.memberCount or 0) < 1 then
                panel:drawText(text("UI_NL_Mission_EmptyTeam"), 70, 515, 0.9, 0.55, 0.45, 1, UIFont.Small)
            end
        end
        return
    end

    if snapshot.myMission then
        panel:drawTextCentre(
            text("UI_NL_Mission_AssignedTeam", snapshot.myMission.teamName or ""),
            w / 2, 82, 0.8, 0.8, 0.88, 1, UIFont.Medium
        )
        self:drawMission(panel, snapshot.myMission, 130)
    else
        panel:drawTextCentre(text("UI_NL_Mission_NoActive"), w / 2, 130, 0.75, 0.75, 0.82, 1, UIFont.Medium)
    end
end

function MissionPanel:refresh()
    if not self:isActive() then return end
    self.host:clearControls()
    self:clearState()
    self.active = true
    self.host.screen = "missions"
    self:createScreen()
end
