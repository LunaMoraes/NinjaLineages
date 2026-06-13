require "ISUI/ISCollapsableWindow"
require "ISUI/ISPanelJoypad"
require "ISUI/ISButton"
require "TimedActions/ISTimedActionQueue"
require "NinjaLineages_TreeDefinitions"
require "NinjaLineages_Progression"
require "NinjaLineages_Training"

NLJutsuTreeUI = ISCollapsableWindow:derive("NLJutsuTreeUI")
NLJutsuTreeUI.instances = NLJutsuTreeUI.instances or {}

local tierOrder = { GENIN = 1, CHUNIN = 2, JONIN = 3 }

local function text(key, ...)
    return getText(key, ...)
end

local function translated(key, fallback)
    local value = getText(key)
    if value == key then return fallback or key end
    return value
end

local function setMouseTooltip(button, tooltip)
    button.tooltip = tooltip
    button.updateTooltip = function(btn)
        if btn:isMouseOver() and btn.tooltip then
            if not btn.tooltipUI then
                btn.tooltipUI = ISToolTip:new()
                btn.tooltipUI:setOwner(btn)
                btn.tooltipUI:setVisible(false)
                btn.tooltipUI:setAlwaysOnTop(true)
                btn.tooltipUI.maxLineWidth = 300
            end
            if not btn.tooltipUI:getIsVisible() then
                btn.tooltipUI:addToUIManager()
                btn.tooltipUI:setVisible(true)
            end
            btn.tooltipUI.description = btn.tooltip
            btn.tooltipUI:setDesiredPosition(getMouseX(), getMouseY() + 8)
        elseif btn.tooltipUI and btn.tooltipUI:getIsVisible() then
            btn.tooltipUI:setVisible(false)
            btn.tooltipUI:removeFromUIManager()
        end
    end
end

local function drawDisabledSideButton(panel, button)
    if not button or not button:getIsVisible() then return end

    local hovered = button:isMouseOver()
    local background = hovered
        and { r = 0.18, g = 0.18, b = 0.24, a = 0.95 }
        or { r = 0.11, g = 0.11, b = 0.15, a = 0.95 }
    local border = hovered
        and { r = 0.50, g = 0.50, b = 0.62, a = 0.90 }
        or { r = 0.34, g = 0.34, b = 0.42, a = 0.85 }

    panel:drawRect(button.x, button.y, button.width, button.height,
        background.a, background.r, background.g, background.b)
    panel:drawRectBorder(button.x, button.y, button.width, button.height,
        border.a, border.r, border.g, border.b)

    local font = UIFont.Small
    local textHeight = getTextManager():MeasureStringY(font, button.title)
    panel:drawTextCentre(
        button.title,
        button.x + (button.width / 2),
        button.y + ((button.height - textHeight) / 2),
        0.58, 0.58, 0.64, 1,
        font
    )
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

        if self.screen == "selection" then
            local leftWidth = math.floor(w * 0.15)
            local cardGap = math.floor(w * 0.008)
            local cardsX = leftWidth + math.floor(w * 0.01)
            local cardHeight = math.floor(h * 0.76)
            local cardWidth = math.floor(cardHeight / 2)
            local cardY = math.floor((h - cardHeight) / 2)

            -- Smooth frame-rate independent scroll update
            local totalCardsWidth = #NinjaLineages.TreeDefinitions.DisciplineOrder * (cardWidth + cardGap) - cardGap
            local visibleWidth = w - cardsX - margin
            self.maxScrollOffset = math.max(0, totalCardsWidth - visibleWidth)
            local maxScroll = self.maxScrollOffset

            local dt = UIManager.getMillisSinceLastRender() / 16.66
            if dt > 5 then dt = 5 end -- Cap lag spikes

            local hoverSpeed = 25 * dt
            if self.leftArrowHovered then
                self.targetScrollOffset = math.max(0, self.targetScrollOffset - hoverSpeed)
            elseif self.rightArrowHovered then
                self.targetScrollOffset = math.min(maxScroll, self.targetScrollOffset + hoverSpeed)
            end

            self.targetScrollOffset = math.max(0, math.min(maxScroll, self.targetScrollOffset))

            local diff = self.targetScrollOffset - self.scrollOffset
            if math.abs(diff) > 0.5 then
                local lerpFactor = math.max(0, math.min(1, 0.20 * dt))
                self.scrollOffset = self.scrollOffset + diff * lerpFactor
                self:repositionCardButtons()
            else
                if self.scrollOffset ~= self.targetScrollOffset then
                    self.scrollOffset = self.targetScrollOffset
                    self:repositionCardButtons()
                end
            end

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

            local rank = NinjaLineages.Progression.getNinjaRank(self.player)
            local rankImage = nil
            if rank == "GENIN" then
                rankImage = "media/ui/jutsuTree/ranks/genin.png"
            elseif rank == "CHUNIN" then
                rankImage = "media/ui/jutsuTree/ranks/chunin.png"
            elseif rank == "JONIN" or rank == "KAGE" then
                rankImage = "media/ui/jutsuTree/ranks/jounin.png"
            end

            if rankImage then
                local tex = getTexture(rankImage)
                if tex then
                    local imgX = margin + math.floor((leftWidth - margin - 96) / 2)
                    panel:drawTextureScaled(tex, imgX, boxY + 95, 96, 96, 1.0, 1.0, 1.0, 1.0)
                end
            end

            -- Clip card buttons to scroll area
            panel:setStencilRect(cardsX, cardY, w - cardsX - margin, cardHeight)
        elseif self.screen == "discipline" and self.selectedDiscipline then
            -- Draw XP next to Back button on the discipline screen
            panel:drawText("Ninja XP: " .. math.floor(NinjaLineages.Progression.getNinjaXP(self.player)), margin + math.floor(w * 0.12), margin + 5, 0.85, 0.85, 0.9, 1, UIFont.Medium)

            local discipline = NinjaLineages.TreeDefinitions.Disciplines[self.selectedDiscipline]
            panel:drawTextCentre(text(discipline.name), w / 2, math.floor(h * 0.04), 1, 1, 1, 1, UIFont.Large)

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
                panel:drawText(translated(node.name, node.nameFallback), self.detailsX, math.floor(h * 0.18), 1, 1, 1, 1, UIFont.Medium)
                panel:drawText(translated(node.description, node.descriptionFallback), self.detailsX, math.floor(h * 0.24), 0.85, 0.85, 0.9, 1, UIFont.Small)
            end
        end
    end

    self.contentPanel.render = function(panel)
        ISPanelJoypad.render(panel)
        if self.screen == "selection" then
            panel:clearStencilRect()
            drawDisabledSideButton(panel, self.foundVillageButton)
            drawDisabledSideButton(panel, self.missionBoardButton)
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
    self.scrollOffset = self.scrollOffset or 0

    local w = self.contentPanel.width
    local h = self.contentPanel.height
    local margin = math.floor(w * 0.03)
    local leftWidth = math.floor(w * 0.15)
    local cardGap = math.floor(w * 0.008)
    local cardsX = leftWidth + math.floor(w * 0.01)
    local cardHeight = math.floor(h * 0.76)
    local cardWidth = math.floor(cardHeight / 2)
    local cardY = math.floor((h - cardHeight) / 2)

    self.cardButtons = {}
    for index, disciplineId in ipairs(NinjaLineages.TreeDefinitions.DisciplineOrder) do
        local definition = NinjaLineages.TreeDefinitions.Disciplines[disciplineId]
        local title = translated(definition.name, definition.nameFallback)
        if definition.locked then title = title .. "\n" .. text("UI_NL_Tree_Locked") end
        local button = self:addButton(
            cardsX + ((index - 1) * (cardWidth + cardGap)) - self.scrollOffset,
            cardY,
            cardWidth,
            cardHeight,
            "", -- Empty title so ISButton.render doesn't draw it in the middle
            self,
            NLJutsuTreeUI.onDiscipline
        )
        button.disciplineTitle = title
        button.internal = disciplineId
        button.enable = definition.locked ~= true
        button.backgroundColor = { r = 0.10, g = 0.10, b = 0.14, a = 0.95 }
        button.backgroundColorMouseOver = { r = 0.20, g = 0.20, b = 0.28, a = 0.95 }
        button.tooltip = translated(definition.description, definition.descriptionFallback)
        button.render = function(btn)
            -- 1. Draw card texture scaled to fill the entire button
            local cardTex = getTexture(definition.card)
            if cardTex then
                btn:drawTextureScaled(cardTex, 0, 0, btn.width, btn.height, btn.textureColor.a, btn.textureColor.r, btn.textureColor.g, btn.textureColor.b)
            end

            -- 2. Draw hover overlay if hovered/focused
            if btn:isMouseOver() or btn.joypadFocused then
                btn:drawRect(0, 0, btn.width, btn.height, 0.15, 1.0, 1.0, 1.0)
            end

            -- 3. Draw border on top of the card image
            if btn:shouldDrawBorder() then
                btn:drawRectBorder(0, 0, btn.width, btn.height, btn.borderColor.a, btn.borderColor.r, btn.borderColor.g, btn.borderColor.b)
            end

            -- 5. Call ISButton.render(btn) to handle standard rendering
            ISButton.render(btn)

            -- 6. Draw the title text centered horizontally right below the icon
            if btn.disciplineTitle and btn.disciplineTitle ~= "" then
                local iconSize = 96
                if btn.width < iconSize + 16 then
                    iconSize = math.max(32, btn.width - 16)
                end
                local textY = 30 + iconSize + 10 -- 10px below the icon
                local font = btn.font or UIFont.Small
                
                local lines = {}
                local nlIndex = string.find(btn.disciplineTitle, "\n")
                if nlIndex then
                    table.insert(lines, string.sub(btn.disciplineTitle, 1, nlIndex - 1))
                    table.insert(lines, string.sub(btn.disciplineTitle, nlIndex + 1))
                else
                    table.insert(lines, btn.disciplineTitle)
                end
                
                local lineHeight = getTextManager():MeasureStringY(font, "A")
                for i, line in ipairs(lines) do
                    local lineW = getTextManager():MeasureStringX(font, line)
                    local lineX = (btn.width - lineW) / 2
                    if btn.enable then
                        btn:drawText(line, lineX, textY + (i - 1) * (lineHeight + 2), btn.textColor.r, btn.textColor.g, btn.textColor.b, btn.textColor.a, font)
                    else
                        btn:drawText(line, lineX, textY + (i - 1) * (lineHeight + 2), 0.3, 0.3, 0.3, 1.0, font)
                    end
                end
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
        table.insert(self.cardButtons, button)
    end

    -- Calculate scroll offset boundaries
    local totalCardsWidth = #NinjaLineages.TreeDefinitions.DisciplineOrder * (cardWidth + cardGap) - cardGap
    local visibleWidth = w - cardsX - margin
    self.maxScrollOffset = math.max(0, totalCardsWidth - visibleWidth)

    -- Add left/right hover arrows
    local arrowWidth = 32
    local arrowHeight = 80
    local arrowY = cardY + (cardHeight - arrowHeight) / 2
    
    self.leftArrowBtn = self:addButton(cardsX + 5, arrowY, arrowWidth, arrowHeight, "<", self, nil)
    self.leftArrowBtn.internal = "left"
    self.leftArrowBtn.backgroundColor = { r = 0.05, g = 0.05, b = 0.07, a = 0.7 }
    self.leftArrowBtn.borderColor = { r = 0.7, g = 0.7, b = 0.7, a = 0.8 }
    self.leftArrowBtn.font = UIFont.Large
    self.leftArrowBtn.update = function(btn)
        ISButton.update(btn)
        self.leftArrowHovered = btn:isMouseOver()
    end
    
    self.rightArrowBtn = self:addButton(w - margin - arrowWidth - 5, arrowY, arrowWidth, arrowHeight, ">", self, nil)
    self.rightArrowBtn.internal = "right"
    self.rightArrowBtn.backgroundColor = { r = 0.05, g = 0.05, b = 0.07, a = 0.7 }
    self.rightArrowBtn.borderColor = { r = 0.7, g = 0.7, b = 0.7, a = 0.8 }
    self.rightArrowBtn.font = UIFont.Large
    self.rightArrowBtn.update = function(btn)
        ISButton.update(btn)
        self.rightArrowHovered = btn:isMouseOver()
    end

    self.leftArrowHovered = false
    self.rightArrowHovered = false
    self:repositionCardButtons()

    local sideButtonX = margin + 10
    local sideButtonWidth = leftWidth - margin - 20
    local sideButtonHeight = math.floor(h * 0.055)
    local sideButtonGap = 8
    local sideButtonY = cardY + cardHeight - (sideButtonHeight * 2) - sideButtonGap - 15
    local comingSoon = text("UI_NL_Tree_ComingSoon")

    self.foundVillageButton = self:addButton(
        sideButtonX,
        sideButtonY,
        sideButtonWidth,
        sideButtonHeight,
        text("UI_NL_Tree_FoundHiddenVillage"),
        self,
        nil
    )
    self.foundVillageButton.enable = false
    setMouseTooltip(self.foundVillageButton, comingSoon)

    self.missionBoardButton = self:addButton(
        sideButtonX,
        sideButtonY + sideButtonHeight + sideButtonGap,
        sideButtonWidth,
        sideButtonHeight,
        text("UI_NL_Tree_OpenMissionBoard"),
        self,
        nil
    )
    self.missionBoardButton.enable = false
    setMouseTooltip(self.missionBoardButton, comingSoon)
    self:updateSelectionButtons()
end

function NLJutsuTreeUI:onDiscipline(button)
    if not button or not button.internal then return end
    local definition = NinjaLineages.TreeDefinitions.Disciplines[button.internal]
    if not definition or definition.locked then return end
    self:createDisciplineScreen(button.internal)
end

function NLJutsuTreeUI:repositionCardButtons()
    if self.screen ~= "selection" or not self.cardButtons then return end
    
    local w = self.contentPanel.width
    local margin = math.floor(w * 0.03)
    local leftWidth = math.floor(w * 0.15)
    local cardGap = math.floor(w * 0.008)
    local cardsX = leftWidth + math.floor(w * 0.01)
    local cardHeight = math.floor(self.contentPanel.height * 0.76)
    local cardWidth = math.floor(cardHeight / 2)
    
    for index, button in ipairs(self.cardButtons) do
        local btnX = cardsX + ((index - 1) * (cardWidth + cardGap)) - self.scrollOffset
        button:setX(btnX)
        
        -- Hide cards that are completely scrolled out of the visible screen area
        local isVisible = (btnX + cardWidth >= cardsX) and (btnX <= w - margin)
        button:setVisible(isVisible)
    end
    
    if self.leftArrowBtn then
        self.leftArrowBtn:setVisible(self.scrollOffset > 0)
    end
    if self.rightArrowBtn then
        local maxScroll = self.maxScrollOffset or 0
        self.rightArrowBtn:setVisible(self.scrollOffset < maxScroll)
    end
end

function NLJutsuTreeUI:update()
    ISCollapsableWindow.update(self)
    if self.screen == "selection" then
        self:updateSelectionButtons()
    elseif self.screen == "discipline" then
        self:refreshDisciplineState()
    end
end

function NLJutsuTreeUI:updateSelectionButtons()
    if self.foundVillageButton then
        self.foundVillageButton:setVisible(
            NinjaLineages.Progression.getNinjaRank(self.player) == "KAGE"
        )
    end
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
        local row = tierOrder[tier]
        local y = h - margin - (row * rowHeight)
        local gap = math.floor((treeWidth - (#definitions * nodeWidth)) / (#definitions + 1))
        for index, definition in ipairs(definitions) do
            local state = NinjaLineages.Progression.getNodeState(self.player, definition.id)
            local title = translated(definition.name, definition.nameFallback) .. "\n" .. text("UI_NL_Tree_State_" .. state)
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
            button:setImage(getTexture(definition.icon) or getTexture(definition.fallbackIcon))
            button.backgroundColor = self:getNodeColor(state)
            button.nodeState = state
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

function NLJutsuTreeUI:getTrainingProgress(nodeId)
    local required = NinjaLineages.Progression.getTrainingPages(self.player, nodeId)
    if required <= 0 then return 0 end

    local persisted = NinjaLineages.Progression.getTrainingPagesRead(self.player, nodeId) / required
    local live = 0
    local queue = ISTimedActionQueue.getTimedActionQueue(self.player)
    local action = queue and queue.current
    if action and action.Type == "NLJutsuTrainingAction" and action.nodeId == nodeId and action.action then
        live = action:getJobDelta()
    end
    return math.max(0, math.min(1, math.max(persisted, live)))
end

function NLJutsuTreeUI:updateActionButton()
    if not self.selectedNode then
        self.actionButton.enable = false
        return
    end
    local state = NinjaLineages.Progression.getNodeState(self.player, self.selectedNode)
    if self.pendingUnlockNode == self.selectedNode and state ~= "available" then
        self.pendingUnlockNode = nil
    end
    if state == "available" then
        self.actionButton.title = text(
            "UI_NL_Tree_Unlock",
            NinjaLineages.Progression.getNodeCost(self.player, self.selectedNode)
        )
        self.actionButton.enable = self.pendingUnlockNode ~= self.selectedNode
    elseif state == "unlocked" then
        local pct = math.floor(self:getTrainingProgress(self.selectedNode) * 100)
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
        if self.pendingUnlockNode == self.selectedNode then return end
        self.pendingUnlockNode = self.selectedNode
        self:updateActionButton()
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

function NLJutsuTreeUI:refreshDisciplineState()
    if not self.selectedDiscipline or not self.nodeButtons then return end

    local nodes = NinjaLineages.TreeDefinitions.getNodesForDiscipline(self.selectedDiscipline)
    for _, definition in ipairs(nodes) do
        local button = self.nodeButtons[definition.id]
        if button then
            local state = NinjaLineages.Progression.getNodeState(self.player, definition.id)
            if button.nodeState ~= state then
                button.nodeState = state
                button.title = translated(definition.name, definition.nameFallback)
                    .. "\n" .. text("UI_NL_Tree_State_" .. state)
                button.backgroundColor = self:getNodeColor(state)
            end
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
    o.scrollOffset = 0
    o.targetScrollOffset = 0
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

function NLJutsuTreeUI.onServerCommand(module, command, args)
    if module ~= "NinjaLineages" then return end
    if command ~= "unlockResult"
            and command ~= "trainingResult"
            and command ~= "progressionUpdated" then
        return
    end

    for _, ui in pairs(NLJutsuTreeUI.instances) do
        if command == "unlockResult"
                and args
                and args.ok ~= true
                and ui.pendingUnlockNode == args.nodeId then
            ui.pendingUnlockNode = nil
        end
        if ui.screen == "selection" then
            ui:updateSelectionButtons()
        elseif ui.screen == "discipline" then
            ui:refreshDisciplineState()
        end
    end
end

Events.OnServerCommand.Add(NLJutsuTreeUI.onServerCommand)
