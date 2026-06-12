require "ISUI/ISCollapsableWindow"
require "ISUI/ISPanelJoypad"
require "ISUI/ISButton"
require "NinjaLineages_TreeDefinitions"
require "NinjaLineages_Progression"
require "NinjaLineages_Training"

NLJutsuTreeUI = ISCollapsableWindow:derive("NLJutsuTreeUI")
NLJutsuTreeUI.instances = NLJutsuTreeUI.instances or {}

local tierOrder = { GENIN = 1, CHUNIN = 2, JONIN = 3 }

local function text(key, ...)
    return getText(key, ...)
end

function NLJutsuTreeUI:initialise()
    ISCollapsableWindow.initialise(self)
    
    local titleBarHeight = self.titleBarHeight and self:titleBarHeight() or 16
    self.contentPanel = ISPanelJoypad:new(0, titleBarHeight, self.width, self.height - titleBarHeight)
    self.contentPanel:initialise()
    self.contentPanel:instantiate()
    self.contentPanel.backgroundColor = { r = 0.05, g = 0.05, b = 0.07, a = 0.95 }
    self:addChild(self.contentPanel)

    if self.closeButton then
        self.closeButton.onclick = function(btn)
            self:close()
        end
    end
    
    self.contentPanel.prerender = function(panel)
        ISPanelJoypad.prerender(panel)
        
        local w = panel.width
        local h = panel.height
        local margin = math.floor(w * 0.03)
        local leftWidth = math.floor(w * 0.20)
        local cardHeight = math.floor(h * 0.64)
        local cardY = math.floor(h * 0.20)

        if self.screen == "selection" then
            -- Draw Selection Title Centered at the top
            panel:drawTextCentre(text("UI_NL_Tree_SelectionTitle") or "Shinobi Disciplines", w / 2, math.floor(h * 0.06), 1, 1, 1, 1, UIFont.Large)

            -- Draw a beautiful container box on the left side of the selection screen
            panel:drawRect(margin, cardY, leftWidth - margin, cardHeight, 0.92, 0.08, 0.08, 0.11)
            panel:drawRectBorder(margin, cardY, leftWidth - margin, cardHeight, 1.0, 0.22, 0.22, 0.32)
            
            local boxX = margin + 15
            local boxY = cardY + 20
            panel:drawText("STATUS", boxX, boxY, 1, 1, 1, 1, UIFont.Medium)
            panel:drawText("Rank: " .. text("UI_NL_Rank_" .. NinjaLineages.Progression.getNinjaRank(self.player)), boxX, boxY + 35, 0.85, 0.85, 0.9, 1, UIFont.Small)
            panel:drawText("Ninja XP: " .. math.floor(NinjaLineages.Progression.getNinjaXP(self.player)), boxX, boxY + 60, 0.85, 0.85, 0.9, 1, UIFont.Small)
        elseif self.screen == "discipline" and self.selectedDiscipline then
            -- Draw XP next to Back button on the discipline screen
            panel:drawText("Ninja XP: " .. math.floor(NinjaLineages.Progression.getNinjaXP(self.player)), margin + math.floor(w * 0.12), margin + 5, 0.85, 0.85, 0.9, 1, UIFont.Medium)

            local discipline = NinjaLineages.TreeDefinitions.Disciplines[self.selectedDiscipline]
            panel:drawTextCentre(text(discipline.name), w / 2, math.floor(h * 0.04), 1, 1, 1, 1, UIFont.Large)
            
            -- Draw icon next to centered title if available
            local iconTex = getTexture(discipline.icon)
            if iconTex then
                panel:drawTextureScaled(iconTex, w / 2 - 120, math.floor(h * 0.04) - 2, 32, 32, 1, 1, 1, 1)
            end

            -- Draw vertical separator line
            local detailsX = self.detailsX or (math.floor(w * 0.18) + math.floor(w * 0.54) + margin)
            local lineX = detailsX - math.floor(margin / 2)
            panel:drawLine(nil, lineX, math.floor(h * 0.05), lineX, h - margin, 1, 0.5, 0.22, 0.22, 0.32)

            -- Draw Genin / Chunin / Jonin labels on the left
            local treeX = self.treeX or math.floor(w * 0.18)
            local rowHeight = self.rowHeight or math.floor(h * 0.22)
            local nodeHeight = self.nodeHeight or math.floor(h * 0.09)
            local geninY = h - margin - (1 * rowHeight) + (nodeHeight / 2) - 8
            local chuninY = h - margin - (2 * rowHeight) + (nodeHeight / 2) - 8
            local joninY = h - margin - (3 * rowHeight) + (nodeHeight / 2) - 8

            panel:drawTextRight("GENIN", treeX - 20, geninY, 0.6, 0.6, 0.7, 1, UIFont.Medium)
            panel:drawTextRight("CHUNIN", treeX - 20, chuninY, 0.6, 0.6, 0.7, 1, UIFont.Medium)
            panel:drawTextRight("JONIN", treeX - 20, joninY, 0.6, 0.6, 0.7, 1, UIFont.Medium)

            -- Draw lines from child nodes to their prerequisites
            if self.nodeButtons then
                local nodes = NinjaLineages.TreeDefinitions.getNodesForDiscipline(self.selectedDiscipline)
                for _, definition in ipairs(nodes) do
                    local childBtn = self.nodeButtons[definition.id]
                    if childBtn and definition.prerequisites then
                        for _, reqId in ipairs(definition.prerequisites) do
                            local reqBtn = self.nodeButtons[reqId]
                            if reqBtn then
                                -- Start point: top center of the prerequisite node
                                local startX = reqBtn.x + reqBtn.width / 2
                                local startY = reqBtn.y
                                -- End point: bottom center of the child node
                                local endX = childBtn.x + childBtn.width / 2
                                local endY = childBtn.y + childBtn.height
                                
                                panel:drawLine(nil, startX, startY, endX, endY, 2, 0.4, 0.45, 0.45, 0.55)
                            end
                        end
                    end
                end
            end

            if self.selectedNode then
                local node = NinjaLineages.TreeDefinitions.getNode(self.selectedNode)
                panel:drawText(text(node.name), self.detailsX, math.floor(h * 0.18), 1, 1, 1, 1, UIFont.Medium)
                panel:drawText(text(node.description), self.detailsX, math.floor(h * 0.24), 0.85, 0.85, 0.9, 1, UIFont.Small)
            end
        end
    end
    self:createSelectionScreen()
end

function NLJutsuTreeUI:clearControls()
    if not self.contentPanel or not self.contentPanel.children then return end
    for id, child in pairs(self.contentPanel.children) do
        child:setVisible(false)
        if child.tooltipUI and child.tooltipUI:getIsVisible() then
            child.tooltipUI:setVisible(false)
            child.tooltipUI:removeFromUIManager()
        end
    end
    self.contentPanel:clearChildren()
    self.contentPanel.joypadButtons = {}
    self.joypadButtons = {}
end

function NLJutsuTreeUI:addButton(x, y, width, height, title, target, callback)
    local button = ISButton:new(x, y, width, height, title, target, callback)
    button:initialise()
    button:instantiate()
    self.contentPanel:addChild(button)
    table.insert(self.contentPanel.joypadButtons, button)
    return button
end

function NLJutsuTreeUI:createSelectionScreen()
    self:clearControls()
    self.screen = "selection"
    self.selectedDiscipline = nil
    self.selectedNode = nil

    local w = self.contentPanel.width
    local h = self.contentPanel.height
    local margin = math.floor(w * 0.03)
    local leftWidth = math.floor(w * 0.20)
    local cardGap = math.floor(w * 0.008)
    local cardsX = margin + leftWidth
    local cardWidth = math.floor((w - cardsX - margin - (cardGap * 6)) / 7)
    local cardHeight = math.floor(h * 0.64)
    local cardY = math.floor(h * 0.20)

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
        button.tooltip = text(definition.description)
        button.prerender = function(btn)
            ISButton.prerender(btn)
            local iconTex = getTexture(definition.icon)
            if iconTex then
                local iconSize = 96
                if btn.width < iconSize + 16 then
                    iconSize = math.max(32, btn.width - 16)
                end
                local iconX = (btn.width - iconSize) / 2
                local iconY = 30
                btn:drawTextureScaled(iconTex, iconX, iconY, iconSize, iconSize, 1, 1, 1, 1)
            end
        end
        button.updateTooltip = function(btn)
            if (btn:isMouseOver() or btn.joypadFocused) and btn.tooltip then
                local text = btn.tooltip
                if not btn.tooltipUI then
                    btn.tooltipUI = ISToolTip:new()
                    btn.tooltipUI:setOwner(btn)
                    btn.tooltipUI:setVisible(false)
                    btn.tooltipUI:setAlwaysOnTop(true)
                end
                if not btn.tooltipUI:getIsVisible() then
                    if string.contains(btn.tooltip, "\n") then
                        btn.tooltipUI.maxLineWidth = 1000
                    else
                        btn.tooltipUI.maxLineWidth = 300
                    end
                    btn.tooltipUI:addToUIManager()
                    btn.tooltipUI:setVisible(true)
                end
                btn.tooltipUI.description = text
                if btn:isMouseOver() then
                    btn.tooltipUI:setDesiredPosition(getMouseX(), getMouseY() + 8)
                else
                    btn.tooltipUI:setDesiredPosition(btn:getAbsoluteX(), btn:getAbsoluteY() + btn:getHeight() + 8)
                end
            else
                if btn.tooltipUI and btn.tooltipUI:getIsVisible() then
                    btn.tooltipUI:setVisible(false)
                    btn.tooltipUI:removeFromUIManager()
                end
            end
        end
    end
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

    local w = self.contentPanel.width
    local h = self.contentPanel.height
    local margin = math.floor(w * 0.03)
    local treeX = math.floor(w * 0.18)
    local treeWidth = math.floor(w * 0.54)
    local detailsX = treeX + treeWidth + margin
    local rowHeight = math.floor(h * 0.22)
    local nodeWidth = math.floor(treeWidth * 0.22)
    local nodeHeight = math.floor(h * 0.09)
    local nodes = NinjaLineages.TreeDefinitions.getNodesForDiscipline(disciplineId)
    local grouped = { GENIN = {}, CHUNIN = {}, JONIN = {} }

    for _, definition in ipairs(nodes) do table.insert(grouped[definition.tier], definition) end

    for tier, definitions in pairs(grouped) do
        table.sort(definitions, function(a, b) return a.id < b.id end)
        local row = tierOrder[tier]
        local y = h - margin - (row * rowHeight)
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
    self.treeX = treeX
    self.treeWidth = treeWidth
    self.rowHeight = rowHeight
    self.nodeHeight = nodeHeight
    self:addButton(margin, margin, math.floor(w * 0.10), math.floor(h * 0.05),
        text("UI_NL_Tree_Back"), self, NLJutsuTreeUI.createSelectionScreen)
    self.actionButton = self:addButton(
        detailsX,
        h - margin - math.floor(h * 0.08),
        w - detailsX - margin,
        math.floor(h * 0.06),
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
        local pct = 0
        if required > 0 then
            pct = math.floor((progress / required) * 100)
        end
        self.actionButton.title = text("UI_NL_Tree_Train", pct)
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
    ISCollapsableWindow.prerender(self)
end

function NLJutsuTreeUI:onGainJoypadFocus(joypadData)
    if self.contentPanel then
        self.contentPanel:onGainJoypadFocus(joypadData)
    end
end

function NLJutsuTreeUI:close()
    self:setVisible(false)
    self:removeFromUIManager()
    NLJutsuTreeUI.instances[self.player:getPlayerNum()] = nil
end

function NLJutsuTreeUI:new(player)
    local playerNum = player:getPlayerNum()
    local screenWidth = getPlayerScreenWidth(playerNum)
    local screenHeight = getPlayerScreenHeight(playerNum)
    local width = math.floor(screenWidth * 0.85)
    local height = math.floor(screenHeight * 0.85)
    local x = getPlayerScreenLeft(playerNum) + (screenWidth - width) / 2
    local y = getPlayerScreenTop(playerNum) + (screenHeight - height) / 2
    
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    
    o.player = player
    o.playerNum = playerNum
    o.resizable = false
    o:setTitle(text("UI_NL_Tree_Title") or "Jutsu Unlock Trees")
    o.clearFrame = true
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
