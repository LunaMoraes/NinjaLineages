require "ISUI/ISPanelJoypad"
require "ISUI/ISButton"
require "NinjaLineages_TreeDefinitions"
require "NinjaLineages_Progression"
require "NinjaLineages_Training"

NLJutsuTreeUI = ISPanelJoypad:derive("NLJutsuTreeUI")
NLJutsuTreeUI.instances = NLJutsuTreeUI.instances or {}

local tierOrder = { GENIN = 1, CHUNIN = 2, JONIN = 3 }

local function text(key, ...)
    return getText(key, ...)
end

function NLJutsuTreeUI:initialise()
    ISPanelJoypad.initialise(self)
    self:createSelectionScreen()
end

function NLJutsuTreeUI:clearControls()
    local children = {}
    for _, child in ipairs(self.children or {}) do table.insert(children, child) end
    for _, child in ipairs(children) do
        self:removeChild(child)
    end
    self.joypadButtons = {}
end

function NLJutsuTreeUI:addButton(x, y, width, height, title, target, callback)
    local button = ISButton:new(x, y, width, height, title, target, callback)
    button:initialise()
    button:instantiate()
    self:addChild(button)
    table.insert(self.joypadButtons, button)
    return button
end

function NLJutsuTreeUI:createSelectionScreen()
    self:clearControls()
    self.screen = "selection"
    self.selectedDiscipline = nil
    self.selectedNode = nil

    local margin = math.floor(self.width * 0.03)
    local leftWidth = math.floor(self.width * 0.20)
    local cardGap = math.floor(self.width * 0.008)
    local cardsX = margin + leftWidth
    local cardWidth = math.floor((self.width - cardsX - margin - (cardGap * 6)) / 7)
    local cardHeight = math.floor(self.height * 0.64)
    local cardY = math.floor(self.height * 0.20)

    for index, disciplineId in ipairs(NinjaLineages.TreeDefinitions.DisciplineOrder) do
        local definition = NinjaLineages.TreeDefinitions.Disciplines[disciplineId]
        local title = text(definition.name)
        if definition.locked then title = title .. "\n" .. text("UI_NL_Tree_Locked") end
        local button = self:addButton(
            cardsX + ((index - 1) * (cardWidth + cardGap)),
            cardY,
            cardWidth,
            cardHeight,
            title,
            self,
            NLJutsuTreeUI.onDiscipline
        )
        button.internal = disciplineId
        button.enable = definition.locked ~= true
        button:setImage(getTexture(definition.card))
        button.backgroundColor = { r = 0.10, g = 0.10, b = 0.14, a = 0.95 }
        button.backgroundColorMouseOver = { r = 0.20, g = 0.20, b = 0.28, a = 0.95 }
    end

    self:addButton(
        self.width - margin - math.floor(self.width * 0.10),
        margin,
        math.floor(self.width * 0.10),
        math.floor(self.height * 0.05),
        text("UI_NL_Tree_Close"),
        self,
        NLJutsuTreeUI.close
    )
end

function NLJutsuTreeUI:onDiscipline(button)
    if not button or not button.internal then return end
    local definition = NinjaLineages.TreeDefinitions.Disciplines[button.internal]
    if not definition or definition.locked then return end
    self:createDisciplineScreen(button.internal)
end

function NLJutsuTreeUI:createDisciplineScreen(disciplineId)
    self:clearControls()
    self.screen = "discipline"
    self.selectedDiscipline = disciplineId
    self.selectedNode = nil
    self.nodeButtons = {}

    local margin = math.floor(self.width * 0.03)
    local treeX = math.floor(self.width * 0.18)
    local treeWidth = math.floor(self.width * 0.54)
    local detailsX = treeX + treeWidth + margin
    local rowHeight = math.floor(self.height * 0.22)
    local nodeWidth = math.floor(treeWidth * 0.22)
    local nodeHeight = math.floor(self.height * 0.09)
    local nodes = NinjaLineages.TreeDefinitions.getNodesForDiscipline(disciplineId)
    local grouped = { GENIN = {}, CHUNIN = {}, JONIN = {} }

    for _, definition in ipairs(nodes) do table.insert(grouped[definition.tier], definition) end

    for tier, definitions in pairs(grouped) do
        table.sort(definitions, function(a, b) return a.id < b.id end)
        local row = tierOrder[tier]
        local y = self.height - margin - (row * rowHeight)
        local gap = math.floor((treeWidth - (#definitions * nodeWidth)) / (#definitions + 1))
        for index, definition in ipairs(definitions) do
            local state = NinjaLineages.Progression.getNodeState(self.player, definition.id)
            local title = text(definition.name) .. "\n" .. text("UI_NL_Tree_State_" .. state)
            local button = self:addButton(
                treeX + gap + ((index - 1) * (nodeWidth + gap)),
                y,
                nodeWidth,
                nodeHeight,
                title,
                self,
                NLJutsuTreeUI.onNode
            )
            button.internal = definition.id
            button:setImage(getTexture(definition.icon))
            button.backgroundColor = self:getNodeColor(state)
            self.nodeButtons[definition.id] = button
        end
    end

    self.detailsX = detailsX
    self:addButton(margin, margin, math.floor(self.width * 0.10), math.floor(self.height * 0.05),
        text("UI_NL_Tree_Back"), self, NLJutsuTreeUI.createSelectionScreen)
    self.actionButton = self:addButton(
        detailsX,
        self.height - margin - math.floor(self.height * 0.08),
        self.width - detailsX - margin,
        math.floor(self.height * 0.06),
        text("UI_NL_Tree_SelectNode"),
        self,
        NLJutsuTreeUI.onAction
    )
    self.actionButton.enable = false
end

function NLJutsuTreeUI:getNodeColor(state)
    if state == "completed" then return { r = 0.12, g = 0.38, b = 0.18, a = 0.95 } end
    if state == "unlocked" then return { r = 0.35, g = 0.28, b = 0.08, a = 0.95 } end
    if state == "available" then return { r = 0.16, g = 0.24, b = 0.42, a = 0.95 } end
    return { r = 0.10, g = 0.10, b = 0.12, a = 0.95 }
end

function NLJutsuTreeUI:onNode(button)
    self.selectedNode = button.internal
    self:updateActionButton()
end

function NLJutsuTreeUI:updateActionButton()
    if not self.selectedNode then
        self.actionButton.enable = false
        return
    end
    local state = NinjaLineages.Progression.getNodeState(self.player, self.selectedNode)
    if state == "available" then
        self.actionButton.title = text(
            "UI_NL_Tree_Unlock",
            NinjaLineages.Progression.getNodeCost(self.player, self.selectedNode)
        )
        self.actionButton.enable = true
    elseif state == "unlocked" then
        local progress = NinjaLineages.Progression.getTrainingPagesRead(self.player, self.selectedNode)
        local required = NinjaLineages.Progression.getTrainingPages(self.player, self.selectedNode)
        self.actionButton.title = text("UI_NL_Tree_Train", math.floor(progress), required)
        self.actionButton.enable = true
    else
        self.actionButton.title = text("UI_NL_Tree_State_" .. state)
        self.actionButton.enable = false
    end
end

function NLJutsuTreeUI:onAction()
    if not self.selectedNode then return end
    local state = NinjaLineages.Progression.getNodeState(self.player, self.selectedNode)
    if state == "available" then
        NinjaLineages.Progression.requestUnlock(self.player, self.selectedNode)
    elseif state == "unlocked" then
        local action = NLJutsuTrainingAction:new(self.player, self.selectedNode)
        if action then
            ISTimedActionQueue.add(action)
            self:close()
        end
    end
    self:updateActionButton()
end

function NLJutsuTreeUI:prerender()
    ISPanelJoypad.prerender(self)
    self:drawRect(0, 0, self.width, self.height, 0.96, 0.035, 0.035, 0.05)
    self:drawTextCentre(text("UI_NL_Tree_Title"), self.width / 2, math.floor(self.height * 0.04), 1, 1, 1, 1, UIFont.Large)
    self:drawText(text("UI_NL_Tree_NinjaLevel", text("UI_NL_Rank_" .. NinjaLineages.Progression.getNinjaRank(self.player))),
        math.floor(self.width * 0.03), math.floor(self.height * 0.08), 1, 1, 1, 1, UIFont.Medium)
    self:drawText(text("UI_NL_Tree_XP", math.floor(NinjaLineages.Progression.getNinjaXP(self.player))),
        math.floor(self.width * 0.03), math.floor(self.height * 0.12), 1, 1, 1, 1, UIFont.Medium)

    if self.screen == "discipline" and self.selectedDiscipline then
        local discipline = NinjaLineages.TreeDefinitions.Disciplines[self.selectedDiscipline]
        self:drawTextCentre(text(discipline.name), self.width / 2, math.floor(self.height * 0.10), 1, 1, 1, 1, UIFont.Large)
        if self.selectedNode then
            local node = NinjaLineages.TreeDefinitions.getNode(self.selectedNode)
            self:drawText(text(node.name), self.detailsX, math.floor(self.height * 0.20), 1, 1, 1, 1, UIFont.Medium)
            self:drawText(text(node.description), self.detailsX, math.floor(self.height * 0.26), 0.85, 0.85, 0.9, 1, UIFont.Small)
        end
    end
end

function NLJutsuTreeUI:onGainJoypadFocus(joypadData)
    ISPanelJoypad.onGainJoypadFocus(self, joypadData)
    if self.joypadButtons[1] then joypadData.focus = self.joypadButtons[1] end
end

function NLJutsuTreeUI:close()
    self:setVisible(false)
    self:removeFromUIManager()
    NLJutsuTreeUI.instances[self.player:getPlayerNum()] = nil
end

function NLJutsuTreeUI:new(player)
    local playerNum = player:getPlayerNum()
    local width = getPlayerScreenWidth(playerNum)
    local height = getPlayerScreenHeight(playerNum)
    local x = getPlayerScreenLeft(playerNum)
    local y = getPlayerScreenTop(playerNum)
    local o = ISPanelJoypad.new(self, x, y, width, height)
    o.player = player
    o.playerNum = playerNum
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 1 }
    o.moveWithMouse = false
    o.joypadButtons = {}
    return o
end

function NLJutsuTreeUI.open(player)
    if not player then return end
    local playerNum = player:getPlayerNum()
    local existing = NLJutsuTreeUI.instances[playerNum]
    if existing then
        existing:close()
        return
    end
    local ui = NLJutsuTreeUI:new(player)
    ui:initialise()
    ui:addToUIManager()
    ui:setVisible(true)
    NLJutsuTreeUI.instances[playerNum] = ui
    if JoypadState.players[playerNum + 1] then setJoypadFocus(playerNum, ui) end
end
