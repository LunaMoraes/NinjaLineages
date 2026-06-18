require "ISUI/ISContextMenu"
require "ISUI/ISModalDialog"
require "ISUI/ISTextBox"
require "ISUI/ISTextEntryBox"
require "ISUI/ISComboBox"
require "NinjaLineages_Social"

NinjaLineages = NinjaLineages or {}
NinjaLineages.SocialPanel = NinjaLineages.SocialPanel or {}

local SocialPanel = NinjaLineages.SocialPanel
SocialPanel.__index = SocialPanel

local VALID_SCREENS = {
    team = true,
    village = true,
    village_teams = true,
    village_create = true,
    reputation = true,
}

local function text(key, ...)
    return getText(key, ...)
end

local function drawMemberName(panel, name, x, y, w, h, r, g, b)
    local words = {}
    for word in string.gmatch(name, "%S+") do
        table.insert(words, word)
    end
    if #words == 1 then
        panel:drawTextCentre(words[1], x + w / 2, y + h / 2 - 8, r, g, b, 1, UIFont.Small)
    elseif #words >= 2 then
        panel:drawTextCentre(words[1], x + w / 2, y + h / 2 - 14, r, g, b, 1, UIFont.Small)
        panel:drawTextCentre(words[2], x + w / 2, y + h / 2 + 2, r, g, b, 1, UIFont.Small)
    end
end

local function getTeamCardPosition(index, teamCount, panelWidth, cardWidth, cardHeight, horizontalGap, verticalGap, top)
    local columns = 4
    local row = math.floor((index - 1) / columns)
    local column = (index - 1) % columns
    local rowStart = row * columns + 1
    local rowCount = math.min(columns, teamCount - rowStart + 1)
    local rowWidth = rowCount * cardWidth + (rowCount - 1) * horizontalGap
    local rowX = (panelWidth - rowWidth) / 2
    return rowX + column * (cardWidth + horizontalGap), top + row * (cardHeight + verticalGap)
end

local function getNextDefaultTeamName(village)
    local index = 1
    local snapshot = NinjaLineages.Social.getSnapshot()
    while true do
        local name = string.format("Team %02d", index)
        local taken = false
        for _, teamID in ipairs(village.teamIDs or {}) do
            local team = snapshot.teams[teamID]
            if team and team.name == name then
                taken = true
                break
            end
        end
        if not taken then return name end
        index = index + 1
    end
end

function SocialPanel:new(host)
    return setmetatable({
        host = host,
        screen = nil,
        availableSymbols = nil,
        availableTitles = nil,
        selectedVillageSymbolIndex = 1,
        nameEntry = nil,
        titleCombo = nil,
        slotButtons = nil,
        targetCombo = nil,
        flagTypeCombo = nil,
        pardonButtons = nil,
    }, self)
end

function SocialPanel:isActive()
    return self.screen ~= nil and self.host.screen == self.screen and VALID_SCREENS[self.screen] == true
end

function SocialPanel:clearState()
    self.nameEntry = nil
    self.titleCombo = nil
    self.slotButtons = nil
    self.targetCombo = nil
    self.flagTypeCombo = nil
    self.pardonButtons = nil
end

function SocialPanel:addButton(x, y, width, height, title, callback)
    return self.host:addButton(x, y, width, height, title, self, callback)
end

function SocialPanel:addBackButton(callback)
    return self:addButton(20, 20, 100, 32, text("UI_NL_Tree_Back"), callback or SocialPanel.onBack)
end

function SocialPanel:onBack()
    self.screen = nil
    self.host:createSelectionScreen()
end

function SocialPanel:open(screen)
    if not VALID_SCREENS[screen] then return false end
    self.host:clearControls()
    self:clearState()
    self.screen = screen
    self.host.screen = screen

    if screen == "team" then
        self:createTeamScreen()
    elseif screen == "village" then
        self:createVillageScreen()
    elseif screen == "village_teams" then
        self:createVillageTeamsScreen()
    elseif screen == "village_create" then
        self:createVillageCreationScreen()
    elseif screen == "reputation" then
        self:createReputationScreen()
    end
    return true
end

function SocialPanel:prerender(panel)
    if not self:isActive() then return end
    local w = panel.width

    if self.screen == "team" then
        self:drawTeam(panel, w)
    elseif self.screen == "village" then
        self:drawVillage(panel, w)
    elseif self.screen == "village_teams" then
        self:drawVillageTeams(panel, w)
    elseif self.screen == "village_create" then
        self:drawVillageCreation(panel, w)
    elseif self.screen == "reputation" then
        self:drawReputation(panel, w)
    end
end

function SocialPanel:drawTeam(panel, w)
    local team = NinjaLineages.Social.getMyTeam(self.host.player)
    panel:drawTextCentre(text("UI_NL_Social_TeamInspect"), w / 2, 28, 0.95, 0.85, 0.65, 1, UIFont.Large)
    if not team then
        panel:drawTextCentre(text("UI_NL_Social_NoTeam"), w / 2, 100, 0.8, 0.8, 0.85, 1, UIFont.Medium)
        return
    end

    panel:drawTextCentre(team.name or team.id, w / 2, 82, 1, 1, 1, 1, UIFont.Medium)
    panel:drawTextCentre("ID: " .. tostring(team.id), w / 2, 112, 0.6, 0.6, 0.7, 1, UIFont.Small)
    local y = 155
    for _, memberKey in ipairs(team.members or {}) do
        local suffix = team.leaderKey == memberKey and "  [Leader]" or ""
        panel:drawText(
            tostring((team.memberNames and team.memberNames[memberKey]) or memberKey) .. suffix,
            70, y, 0.88, 0.88, 0.92, 1, UIFont.Medium
        )
        y = y + 34
    end
    if team.villageID then
        panel:drawText(text("UI_NL_Social_VillageTeamNotice"), 70, y + 12, 0.72, 0.72, 0.8, 1, UIFont.Small)
    end
end

function SocialPanel:drawVillage(panel, w)
    local village = NinjaLineages.Social.getMyVillage(self.host.player)
    panel:drawTextCentre(text("UI_NL_Social_HiddenVillage"), w / 2, 28, 0.95, 0.85, 0.65, 1, UIFont.Large)
    if not village then return end

    local symbolTexture = NinjaLineages.Social.getSymbol(village.symbolID)
    local texture = symbolTexture and getTexture(symbolTexture)
    if texture then
        local iconX, iconY, iconSize = 60, 75, 128
        self.host:drawBandanaPlate(panel, iconX, iconY, iconSize)
        panel:drawTextureScaled(texture, iconX, iconY, iconSize, iconSize, 1, 1, 1, 1)
    end
    panel:drawText(village.name, 290, 78, 1, 1, 1, 1, UIFont.Large)
    panel:drawText(
        text("UI_NL_Social_VillageXP", tostring(village.xp or 0)),
        290, 115, 0.85, 0.85, 0.9, 1, UIFont.Medium
    )

    local highestRank = "None"
    local rankOrder = { D = 1, C = 2, B = 3, A = 4, S = 5 }
    local maxRank = 0
    for _, rank in ipairs(village.unlockedMissionRanks or {}) do
        local value = rankOrder[rank] or 0
        if value > maxRank then
            maxRank = value
            highestRank = rank
        end
    end
    panel:drawText(
        text("UI_NL_Social_MissionRanks", highestRank),
        290, 145, 0.85, 0.85, 0.9, 1, UIFont.Medium
    )

    local title = village.title or "Kage"
    panel:drawText(title .. ": " .. tostring(
        (village.memberNames and village.memberNames[village.kageKey]) or village.kageKey
    ), 60, 235, 0.95, 0.85, 0.65, 1, UIFont.Medium)
    panel:drawText("Members", 60, 280, 1, 1, 1, 1, UIFont.Medium)
    local y = 315
    for _, memberKey in ipairs(village.members or {}) do
        panel:drawText(
            tostring((village.memberNames and village.memberNames[memberKey]) or memberKey),
            80, y, 0.86, 0.86, 0.9, 1, UIFont.Small
        )
        y = y + 25
    end
end

function SocialPanel:drawVillageTeams(panel, w)
    local village = NinjaLineages.Social.getMyVillage(self.host.player)
    panel:drawTextCentre(text("UI_NL_Social_VillageTeams") or "Village Teams", w / 2, 28, 0.95, 0.85, 0.65, 1, UIFont.Large)
    if not village then return end

    local teamIDs = village.teamIDs or {}
    if #teamIDs == 0 then
        panel:drawTextCentre(text("UI_NL_Social_NoVillageTeams") or "No teams in this village.", w / 2, 120, 0.8, 0.8, 0.85, 1, UIFont.Medium)
        return
    end

    local boxW, boxH, slotSize, slotGap = 180, 215, 70, 10
    local spacing, rowSpacing, gridTop = 20, 20, 100
    for i, teamID in ipairs(teamIDs) do
        local team = NinjaLineages.Social.getSnapshot().teams[teamID]
        if team then
            local colX, colY = getTeamCardPosition(i, #teamIDs, w, boxW, boxH, spacing, rowSpacing, gridTop)
            panel:drawRectBorder(colX, colY, boxW, boxH, 0.85, 0.34, 0.34, 0.42)
            panel:drawTextCentre(team.name, colX + boxW / 2, colY + 10, 0.95, 0.85, 0.65, 1, UIFont.Medium)

            local leaderX = colX + (boxW - slotSize) / 2
            local leaderY = colY + 50
            self:drawTeamSlot(
                panel, teamID .. "_leader", team.leaderKey,
                village, leaderX, leaderY, slotSize, "No Leader"
            )

            local slotsWidth = slotSize * 2 + slotGap
            local member1X = colX + (boxW - slotsWidth) / 2
            local memberY = leaderY + slotSize + slotGap
            self:drawTeamSlot(
                panel, teamID .. "_member1", team.member1Key,
                village, member1X, memberY, slotSize, "No Member"
            )
            self:drawTeamSlot(
                panel, teamID .. "_member2", team.member2Key,
                village, member1X + slotSize + slotGap, memberY, slotSize, "No Member"
            )
        end
    end
end

function SocialPanel:drawTeamSlot(panel, buttonKey, memberKey, village, x, y, size, emptyLabel)
    local button = self.slotButtons and self.slotButtons[buttonKey]
    local hovered = button and button:isMouseOver()
    local br, bg, bb = 0.22, 0.22, 0.28
    if hovered then br, bg, bb = 0.50, 0.50, 0.62 end
    panel:drawRectBorder(x, y, size, size, 0.85, br, bg, bb)

    local name = emptyLabel
    local r, g, b = 0.5, 0.5, 0.5
    if memberKey and memberKey ~= "" then
        name = village.memberNames and village.memberNames[memberKey] or memberKey
        r, g, b = 0.9, 0.9, 0.95
    end
    drawMemberName(panel, name, x, y, size, size, r, g, b)
end

function SocialPanel:drawVillageCreation(panel, w)
    local symbolTexture = self.availableSymbols and self.availableSymbols[self.selectedVillageSymbolIndex or 1]
    panel:drawTextCentre(text("UI_NL_Tree_FoundHiddenVillage"), w / 2, 35, 0.95, 0.85, 0.65, 1, UIFont.Large)
    panel:drawTextCentre(text("UI_NL_Social_ChooseSymbol"), w / 2, 100, 0.9, 0.9, 0.95, 1, UIFont.Medium)
    if symbolTexture then
        local texture = getTexture(symbolTexture)
        local iconSize = 180
        local iconX = (w - iconSize) / 2
        local iconY = 145
        if texture then
            self.host:drawBandanaPlate(panel, iconX, iconY, iconSize)
            panel:drawTextureScaled(texture, iconX, iconY, iconSize, iconSize, 1, 1, 1, 1)
        else
            panel:drawRect(iconX, iconY, iconSize, iconSize, 0.9, 0.08, 0.08, 0.11)
            panel:drawRectBorder(iconX, iconY, iconSize, iconSize, 0.8, 0.6, 0.6, 0.7)
        end
    end
    panel:drawText("Village Name:", w / 2 - 130, 345, 0.9, 0.9, 0.95, 1, UIFont.Small)
    panel:drawText("Kage Title (Dropdown):", w / 2 - 130, 400, 0.9, 0.9, 0.95, 1, UIFont.Small)
end

local function stars(severity)
    return string.rep("★", math.max(1, math.min(5, tonumber(severity) or 1)))
end

function SocialPanel:drawReputation(panel, w)
    panel:drawTextCentre(
        text("UI_NL_Reputation_Title"),
        w / 2, 28, 0.95, 0.85, 0.65, 1, UIFont.Large
    )
    panel:drawText(text("UI_NL_Reputation_Target"), 70, 92, 0.9, 0.9, 0.95, 1, UIFont.Small)
    panel:drawText(text("UI_NL_Reputation_FlagType"), 70, 147, 0.9, 0.9, 0.95, 1, UIFont.Small)
    panel:drawText(text("UI_NL_Reputation_OwnedFlags"), 70, 235, 1, 1, 1, 1, UIFont.Medium)

    local flags = NinjaLineages.Social.getOwnedReputationFlags(self.host.player)
    if #flags == 0 then
        panel:drawText(text("UI_NL_Reputation_NoOwnedFlags"), 90, 275, 0.7, 0.7, 0.78, 1, UIFont.Small)
        return
    end
    local y = 275
    for _, flag in ipairs(flags) do
        panel:drawText(
            tostring(flag.targetPlayerName) .. " - " .. tostring(flag.flagType)
                .. " " .. stars(flag.severity),
            90, y, 0.86, 0.86, 0.92, 1, UIFont.Small
        )
        y = y + 36
    end
end

function SocialPanel:createVillageCreationScreen()
    local w = self.host.contentPanel.width
    self:addBackButton()

    local snapshot = NinjaLineages.Social.getSnapshot()
    local usedSymbols, usedTitles = {}, {}
    for _, village in pairs((snapshot and snapshot.villages) or {}) do
        if village.symbolID then usedSymbols[village.symbolID] = true end
        if village.title then usedTitles[village.title] = true end
    end

    self.availableSymbols = {}
    for _, symbolPath in ipairs(NinjaLineages.Social.VillageSymbols) do
        local symbolID = NinjaLineages.Social.getSymbolID(symbolPath)
        if not usedSymbols[symbolID] then table.insert(self.availableSymbols, symbolPath) end
    end

    self.availableTitles = {}
    for _, title in ipairs(NinjaLineages.Social.VillageTitles) do
        if not usedTitles[title] then table.insert(self.availableTitles, title) end
    end

    if self.selectedVillageSymbolIndex > #self.availableSymbols then
        self.selectedVillageSymbolIndex = 1
    end

    local previewX = (w - 180) / 2
    self:addButton(previewX - 105, 216, 50, 38, "<", SocialPanel.onPreviousVillageSymbol)
    self:addButton(previewX + 235, 216, 50, 38, ">", SocialPanel.onNextVillageSymbol)

    self.nameEntry = ISTextEntryBox:new("", w / 2 - 130, 365, 260, 24)
    self.nameEntry:initialise()
    self.nameEntry:instantiate()
    self.host.contentPanel:addChild(self.nameEntry)

    self.titleCombo = ISComboBox:new(w / 2 - 130, 420, 260, 24, self, nil)
    self.titleCombo:initialise()
    self.titleCombo:instantiate()
    self.host.contentPanel:addChild(self.titleCombo)
    for _, title in ipairs(self.availableTitles) do self.titleCombo:addOption(title) end

    local found = self:addButton(
        w / 2 - 130, 470, 260, 40,
        text("UI_NL_Tree_FoundHiddenVillage"),
        SocialPanel.onConfirmFoundVillage
    )
    found.enable = #self.availableSymbols > 0 and #self.availableTitles > 0
end

function SocialPanel:onPreviousVillageSymbol()
    local count = #(self.availableSymbols or {})
    if count == 0 then return end
    self.selectedVillageSymbolIndex = (self.selectedVillageSymbolIndex or 1) - 1
    if self.selectedVillageSymbolIndex < 1 then self.selectedVillageSymbolIndex = count end
end

function SocialPanel:onNextVillageSymbol()
    local count = #(self.availableSymbols or {})
    if count == 0 then return end
    self.selectedVillageSymbolIndex = (self.selectedVillageSymbolIndex or 1) + 1
    if self.selectedVillageSymbolIndex > count then self.selectedVillageSymbolIndex = 1 end
end

function SocialPanel:onConfirmFoundVillage()
    local name = self.nameEntry and self.nameEntry:getText()
    if not name or name:trim() == "" then return end

    local snapshot = NinjaLineages.Social.getSnapshot()
    local normalized = name:trim():lower()
    for _, village in pairs((snapshot and snapshot.villages) or {}) do
        if village.name and village.name:trim():lower() == normalized then
            self:showMessage(text("UI_NL_Social_Error_village_name_taken") or "That village name is already in use.")
            return
        end
    end

    local symbolTexture = self.availableSymbols[self.selectedVillageSymbolIndex or 1]
    NinjaLineages.Social.request(self.host.player, "socialCreateVillage", {
        name = name,
        symbolID = NinjaLineages.Social.getSymbolID(symbolTexture),
        title = self.titleCombo:getSelectedText(),
    })
end

function SocialPanel:createVillageScreen()
    self:addBackButton()
    local w = self.host.contentPanel.width
    self:addButton(
        math.floor(w * 0.55), 280, 160, 32,
        text("UI_NL_Social_VillageTeams") or "Village Teams",
        SocialPanel.onVillageTeams
    )

    local village = NinjaLineages.Social.getMyVillage(self.host.player)
    if village and NinjaLineages.Social.isKage(self.host.player) then
        self:addButton(
            math.floor(w * 0.55), 322, 160, 32,
            text("UI_NL_Reputation_Manage"),
            SocialPanel.onManageReputation
        )
        local textWidth = getTextManager():MeasureStringX(UIFont.Large, village.name)
        self:addButton(
            290 + textWidth + 15, 82, 70, 24,
            text("UI_NL_Social_Rename") or "Rename",
            SocialPanel.onRenameVillage
        )
    end
end

function SocialPanel:onManageReputation()
    self:open("reputation")
end

function SocialPanel:createReputationScreen()
    self:addBackButton(SocialPanel.onVillageBack)
    if not NinjaLineages.Social.isKage(self.host.player) then
        self:open("village")
        return
    end

    local w = self.host.contentPanel.width
    local snapshot = NinjaLineages.Social.getSnapshot()
    local targets = {}
    for playerID, displayName in pairs(snapshot.knownPlayers or {}) do
        table.insert(targets, { id = playerID, name = displayName })
    end
    table.sort(targets, function(a, b) return tostring(a.name) < tostring(b.name) end)

    self.targetCombo = ISComboBox:new(70, 110, 360, 28, self, nil)
    self.targetCombo:initialise()
    self.targetCombo:instantiate()
    self.host.contentPanel:addChild(self.targetCombo)
    for _, target in ipairs(targets) do
        self.targetCombo:addOptionWithData(target.name, target.id)
    end

    self.flagTypeCombo = ISComboBox:new(70, 165, 360, 28, self, nil)
    self.flagTypeCombo:initialise()
    self.flagTypeCombo:instantiate()
    self.host.contentPanel:addChild(self.flagTypeCombo)
    for _, flagType in ipairs(NinjaLineages.Social.ReputationFlagTypes) do
        self.flagTypeCombo:addOptionWithData(flagType, flagType)
    end

    local apply = self:addButton(450, 135, 150, 38, text("UI_NL_Reputation_Apply"), SocialPanel.onApplyFlag)
    apply.enable = #targets > 0

    self.pardonButtons = {}
    local flags = NinjaLineages.Social.getOwnedReputationFlags(self.host.player)
    local y = 270
    for _, flag in ipairs(flags) do
        local pardon = self:addButton(
            w - 190, y - 6, 120, 28,
            text("UI_NL_Reputation_Pardon"),
            SocialPanel.onPardonFlag
        )
        pardon.targetPlayerId = flag.targetPlayerId
        pardon.flagType = flag.flagType
        table.insert(self.pardonButtons, pardon)
        y = y + 36
    end
end

function SocialPanel:onApplyFlag()
    local targetPlayerId = self.targetCombo and self.targetCombo:getSelectedData()
    local flagType = self.flagTypeCombo and self.flagTypeCombo:getSelectedData()
    if not targetPlayerId or not flagType then return end
    NinjaLineages.Social.request(self.host.player, "socialApplyReputationFlag", {
        targetPlayerId = targetPlayerId,
        flagType = flagType,
    })
end

function SocialPanel:onPardonFlag(button)
    NinjaLineages.Social.request(self.host.player, "socialPardonReputationFlag", {
        targetPlayerId = button.targetPlayerId,
        flagType = button.flagType,
    })
end

function SocialPanel:onVillageTeams()
    self:open("village_teams")
end

function SocialPanel:onVillageBack()
    self:open("village")
end

function SocialPanel:createVillageTeamsScreen()
    self:addBackButton(SocialPanel.onVillageBack)
    local village = NinjaLineages.Social.getMyVillage(self.host.player)
    if not village then return end

    local isVillageKage = NinjaLineages.Social.isKage(self.host.player)
    local w = self.host.contentPanel.width
    if isVillageKage then
        self:addButton(
            w - 180, 20, 160, 32,
            text("UI_NL_Social_CreateTeam") or "Create Team",
            SocialPanel.onCreateVillageTeam
        )
    end

    local teamIDs = village.teamIDs or {}
    local boxW, boxH, slotSize, slotGap = 180, 215, 70, 10
    local spacing, rowSpacing, gridTop = 20, 20, 100
    self.slotButtons = {}
    for i, teamID in ipairs(teamIDs) do
        local team = NinjaLineages.Social.getSnapshot().teams[teamID]
        if team then
            local colX, colY = getTeamCardPosition(i, #teamIDs, w, boxW, boxH, spacing, rowSpacing, gridTop)
            local playerKey = NinjaLineages.Social.getPlayerKey(self.host.player, true)
            local isTeamLeader = team.leaderKey and playerKey == team.leaderKey
            if isVillageKage or isTeamLeader then
                local nameWidth = getTextManager():MeasureStringX(UIFont.Medium, team.name)
                local nameHeight = getTextManager():getFontHeight(UIFont.Medium)
                local nameButton = self:addButton(
                    colX + (boxW - nameWidth) / 2, colY + 10, nameWidth, nameHeight, "",
                    function() self:onRenameTeamName(teamID) end
                )
                nameButton.background = false
                nameButton.border = false
                nameButton.backgroundColor.a = 0
                nameButton.backgroundColorMouseOver.a = 0
                nameButton.borderColor.a = 0
            end

            if isVillageKage then
                local leaderX = colX + (boxW - slotSize) / 2
                local leaderY = colY + 50
                local slotsWidth = slotSize * 2 + slotGap
                local member1X = colX + (boxW - slotsWidth) / 2
                local memberY = leaderY + slotSize + slotGap
                self.slotButtons[teamID .. "_leader"] = self:createSlotButton(
                    leaderX, leaderY, slotSize, teamID, "leader"
                )
                self.slotButtons[teamID .. "_member1"] = self:createSlotButton(
                    member1X, memberY, slotSize, teamID, "member1"
                )
                self.slotButtons[teamID .. "_member2"] = self:createSlotButton(
                    member1X + slotSize + slotGap, memberY, slotSize, teamID, "member2"
                )
            end
        end
    end
end

function SocialPanel:createSlotButton(x, y, size, teamID, slot)
    local button = self:addButton(x, y, size, size, "", function() self:onSelectSlot(teamID, slot) end)
    button.background = false
    button.border = false
    return button
end

function SocialPanel:onCreateVillageTeam()
    local village = NinjaLineages.Social.getMyVillage(self.host.player)
    if not village then return end
    NinjaLineages.Social.request(self.host.player, "socialCreateVillageTeam", {
        name = getNextDefaultTeamName(village),
    })
end

function SocialPanel:onSelectSlot(teamID, slot)
    local village = NinjaLineages.Social.getMyVillage(self.host.player)
    if not village then return end
    local snapshot = NinjaLineages.Social.getSnapshot()
    local team = snapshot.teams[teamID]
    if not team then return end

    local currentOccupant
    if slot == "leader" then currentOccupant = team.leaderKey
    elseif slot == "member1" then currentOccupant = team.member1Key
    elseif slot == "member2" then currentOccupant = team.member2Key
    end

    local menu = ISContextMenu.get(self.host.playerNum, getMouseX(), getMouseY())
    if currentOccupant and currentOccupant ~= "" then
        local occupantName = village.memberNames and village.memberNames[currentOccupant] or currentOccupant
        menu:addOption("Remove " .. occupantName, self, self.assignSlot, teamID, slot, nil)
    end
    for _, memberKey in ipairs(village.members or {}) do
        if (not snapshot.playerTeams[memberKey] or snapshot.playerTeams[memberKey] == teamID)
                and memberKey ~= currentOccupant then
            local displayName = village.memberNames and village.memberNames[memberKey] or memberKey
            menu:addOption(displayName, self, self.assignSlot, teamID, slot, memberKey)
        end
    end
end

function SocialPanel:assignSlot(teamID, slot, targetKey)
    NinjaLineages.Social.request(self.host.player, "socialAssignTeamMember", {
        teamID = teamID,
        slot = slot,
        targetKey = targetKey,
    })
end

local function onTeamRenameEnteredFromTeams(socialPanel, button, teamID)
    if button.internal ~= "OK" then return end
    local name = button.parent.entry:getText()
    if not name or name:trim() == "" then return end
    NinjaLineages.Social.request(socialPanel.host.player, "socialRenameTeam", {
        teamID = teamID,
        name = name,
    })
end

function SocialPanel:onRenameTeamName(teamID)
    local team = NinjaLineages.Social.getSnapshot().teams[teamID]
    if not team then return end
    local box = ISTextBox:new(
        0, 0, 440, 160, text("UI_NL_Social_RenameTeam"), team.name or "",
        self, onTeamRenameEnteredFromTeams, self.host.playerNum, teamID
    )
    box:initialise()
    box.entry:setMaxTextLength(32)
    box:addToUIManager()
end

local function onVillageRenameEntered(socialPanel, button)
    if button.internal ~= "OK" then return end
    local name = button.parent.entry:getText()
    if not name or name:trim() == "" then return end

    local snapshot = NinjaLineages.Social.getSnapshot()
    local normalized = name:trim():lower()
    local currentVillage = NinjaLineages.Social.getMyVillage(socialPanel.host.player)
    local currentVillageID = currentVillage and currentVillage.id
    for villageID, village in pairs((snapshot and snapshot.villages) or {}) do
        if villageID ~= currentVillageID and village.name and village.name:trim():lower() == normalized then
            socialPanel:showMessage(text("UI_NL_Social_Error_village_name_taken") or "Name already chosen")
            return
        end
    end
    NinjaLineages.Social.request(socialPanel.host.player, "socialRenameVillage", { name = name })
end

function SocialPanel:onRenameVillage()
    local village = NinjaLineages.Social.getMyVillage(self.host.player)
    if not village then return end
    local box = ISTextBox:new(
        0, 0, 440, 160,
        text("UI_NL_Social_RenameVillage") or "Rename Hidden Village:",
        village.name or "", self, onVillageRenameEntered, self.host.playerNum
    )
    box:initialise()
    box.entry:setMaxTextLength(32)
    box:addToUIManager()
end

local function onTeamRenameEntered(socialPanel, button)
    if button.internal ~= "OK" then return end
    NinjaLineages.Social.request(socialPanel.host.player, "socialRenameTeam", {
        name = button.parent.entry:getText(),
    })
end

function SocialPanel:onRenameTeam()
    local team = NinjaLineages.Social.getMyTeam(self.host.player)
    if not team then return end
    local box = ISTextBox:new(
        0, 0, 440, 160, text("UI_NL_Social_RenameTeam"), team.name or "",
        self, onTeamRenameEntered, self.host.playerNum
    )
    box:initialise()
    box.entry:setMaxTextLength(32)
    box:addToUIManager()
end

function SocialPanel:onLeaveTeam()
    NinjaLineages.Social.request(self.host.player, "socialLeaveTeam", {})
end

function SocialPanel:onDisbandTeam()
    NinjaLineages.Social.request(self.host.player, "socialDisbandTeam", {})
end

function SocialPanel:onKickTeamMember(button)
    NinjaLineages.Social.request(self.host.player, "socialKickTeamMember", {
        targetKey = button.internal,
    })
end

function SocialPanel:createTeamScreen()
    local w, h = self.host.contentPanel.width, self.host.contentPanel.height
    self:addBackButton()
    local team = NinjaLineages.Social.getMyTeam(self.host.player)
    if not team then return end

    local snapshot = NinjaLineages.Social.getSnapshot()
    local playerKey = (snapshot.me and snapshot.me.playerKey)
        or NinjaLineages.Social.getPlayerKey(self.host.player, true)
    local isLeader = NinjaLineages.Social.isTeamLeader(self.host.player)
    if isLeader then
        self:addButton(w - 190, 75, 150, 34, text("UI_NL_Social_RenameTeam"), SocialPanel.onRenameTeam)
    end
    if not team.villageID and isLeader then
        self:addButton(w - 190, h - 65, 150, 34, text("UI_NL_Social_DisbandTeam"), SocialPanel.onDisbandTeam)
    else
        self:addButton(w - 190, h - 65, 150, 34, text("UI_NL_Social_LeaveTeam"), SocialPanel.onLeaveTeam)
    end
    if isLeader then
        local y = 155
        for _, memberKey in ipairs(team.members or {}) do
            if memberKey ~= playerKey then
                local kick = self:addButton(
                    w - 190, y, 150, 28,
                    text("UI_NL_Social_Kick"),
                    SocialPanel.onKickTeamMember
                )
                kick.internal = memberKey
            end
            y = y + 34
        end
    end
end

function SocialPanel:showMessage(message)
    local box = ISModalDialog:new(
        0, 0, 320, 120, message, false, nil, nil, self.host.playerNum
    )
    box:initialise()
    box:addToUIManager()
end

function SocialPanel:refresh()
    if not self:isActive() then
        if self.host.screen == "selection" then self.host:updateSelectionButtons() end
        return
    end

    if self.screen == "team" then
        self:open("team")
        return
    end

    local village = NinjaLineages.Social.getMyVillage(self.host.player)
    if self.screen == "village_create" then
        if village then self:open("village") end
    elseif (self.screen == "village" or self.screen == "village_teams" or self.screen == "reputation")
            and not village then
        self.screen = nil
        self.host:createSelectionScreen()
    elseif self.screen == "reputation" and not NinjaLineages.Social.isKage(self.host.player) then
        self:open("village")
    else
        self:open(self.screen)
    end
end
