require "ISUI/ISCollapsableWindow"
require "ISUI/ISPanelJoypad"
require "ISUI/ISButton"
require "TimedActions/ISTimedActionQueue"
require "NinjaLineages_TreeDefinitions"
require "NinjaLineages_Progression"
require "NinjaLineages_Training"
require "NinjaLineages_Social"
require "NinjaLineages_SocialPanel"
require "NinjaLineages_MissionPanel"

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

function NLJutsuTreeUI:drawBandanaPlate(panel, iconX, iconY, iconSize)
    local plateW = iconSize + 80
    local plateH = iconSize + 30
    local plateX = iconX - (plateW - iconSize) / 2
    local plateY = iconY - (plateH - iconSize) / 2

    -- 1. Draw metallic brushed gradient
    local step = 2
    for y = 0, plateH - 1, step do
        local pct
        local r, g, b
        if y < plateH * 0.45 then
            pct = y / (plateH * 0.45)
            r = 0.42 + (0.85 - 0.42) * pct
            g = 0.42 + (0.85 - 0.42) * pct
            b = 0.45 + (0.88 - 0.45) * pct
        else
            pct = (y - plateH * 0.45) / (plateH * 0.55)
            r = 0.85 + (0.45 - 0.85) * pct
            g = 0.85 + (0.45 - 0.85) * pct
            b = 0.88 + (0.48 - 0.88) * pct
        end
        local h = math.min(step, plateH - y)
        panel:drawRect(plateX, plateY + y, plateW, h, 1.0, r, g, b)
    end

    -- 2. Draw 3D Bevel borders
    -- Top & Left edge highlights (white)
    panel:drawLine(nil, plateX, plateY, plateX + plateW, plateY, 1, 0.90, 0.90, 0.95, 0.7)
    panel:drawLine(nil, plateX, plateY, plateX, plateY + plateH, 1, 0.90, 0.90, 0.95, 0.7)
    -- Bottom & Right edge shadows (dark grey)
    panel:drawLine(nil, plateX, plateY + plateH - 1, plateX + plateW, plateY + plateH - 1, 1, 0.2, 0.2, 0.22, 0.8)
    panel:drawLine(nil, plateX + plateW - 1, plateY, plateX + plateW - 1, plateY + plateH, 1, 0.2, 0.2, 0.22, 0.8)

    -- 3. Draw strong double outer border
    panel:drawRectBorder(plateX - 2, plateY - 2, plateW + 4, plateH + 4, 1.0, 0.1, 0.1, 0.12)
    panel:drawRectBorder(plateX - 1, plateY - 1, plateW + 2, plateH + 2, 1.0, 0.35, 0.35, 0.38)

    -- 4. Draw corner screws
    local screwTex = getTexture("media/ui/NLScrew.png")
    local screwSize = 14
    local margin = 8
    local positions = {
        { x = plateX + margin, y = plateY + margin },
        { x = plateX + plateW - margin - screwSize, y = plateY + margin },
        { x = plateX + margin, y = plateY + plateH - margin - screwSize },
        { x = plateX + plateW - margin - screwSize, y = plateY + plateH - margin - screwSize }
    }
    for _, pos in ipairs(positions) do
        if screwTex then
            panel:drawTextureScaled(screwTex, pos.x, pos.y, screwSize, screwSize, 1.0, 1.0, 1.0, 1.0)
        else
            -- Procedural rivet fallback (raised look)
            panel:drawRect(pos.x, pos.y, screwSize, screwSize, 1.0, 0.6, 0.6, 0.62)
            panel:drawRectBorder(pos.x, pos.y, screwSize, screwSize, 1.0, 0.2, 0.2, 0.22)
            panel:drawRectBorder(pos.x + 1, pos.y + 1, screwSize - 2, screwSize - 2, 1.0, 0.8, 0.8, 0.82)
        end
    end
end

function NLJutsuTreeUI:initialise()
    ISCollapsableWindow.initialise(self)
    
    local titleBarHeight = self.titleBarHeight and self:titleBarHeight() or 16
    self.contentPanel = ISPanelJoypad:new(0, titleBarHeight, self.width, self.height - titleBarHeight)
    self.contentPanel:initialise()
    self.contentPanel:instantiate()
    self.contentPanel.backgroundColor = { r = 0.05, g = 0.05, b = 0.07, a = 0.95 }
    self:addChild(self.contentPanel)
    self.socialPanel = NinjaLineages.SocialPanel:new(self)
    self.missionPanel = NinjaLineages.MissionPanel:new(self)

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
            local margin = 20
            local leftWidth = 250
            local statusHeight = math.floor(h * 0.76)
            local statusY = math.floor((h - statusHeight) / 2)

            -- Draw Selection Title Centered at the top (with a warm amber/gold color)
            panel:drawTextCentre(text("UI_NL_Tree_SelectionTitle") or "Shinobi Disciplines", w / 2, math.floor(h * 0.06), 0.95, 0.85, 0.65, 1, UIFont.Large)

            -- Draw a beautiful container box on the left side of the selection screen
            panel:drawRect(margin, statusY, leftWidth - margin, statusHeight, 0.92, 0.08, 0.08, 0.11)
            panel:drawRectBorder(margin, statusY, leftWidth - margin, statusHeight, 0.6, 1.0, 1.0, 1.0)
            
            local boxX = margin + 15
            local boxY = statusY + 20
            panel:drawText("STATUS", boxX, boxY, 1, 1, 1, 1, UIFont.Medium)
            panel:drawText("Rank: " .. text("UI_NL_Rank_" .. NinjaLineages.Progression.getNinjaRank(self.player)), boxX, boxY + 30, 0.85, 0.85, 0.9, 1, UIFont.Small)

            local rank = NinjaLineages.Progression.getNinjaRank(self.player)
            local rankImage = nil
            if rank == "GENIN" then
                rankImage = "media/ui/jutsuTree/ranks/genin.png"
            elseif rank == "CHUNIN" then
                rankImage = "media/ui/jutsuTree/ranks/chunin.png"
            elseif rank == "JONIN" or rank == "KAGE" then
                rankImage = "media/ui/jutsuTree/ranks/jounin.png"
            end

            local imgSize = 96
            local imgX = margin + math.floor((leftWidth - margin - imgSize) / 2)

            if rankImage then
                local tex = getTexture(rankImage)
                if tex then
                    panel:drawTextureScaled(tex, imgX, boxY + 50, imgSize, imgSize, 1.0, 1.0, 1.0, 1.0)
                end
            end

            panel:drawText("Ninja XP: " .. math.floor(NinjaLineages.Progression.getNinjaXP(self.player)), boxX, boxY + 155, 0.85, 0.85, 0.9, 1, UIFont.Small)

            local village = NinjaLineages.Social.getMyVillage(self.player)
            if village then
                panel:drawText("Village: " .. village.name, boxX, boxY + 180, 0.85, 0.85, 0.9, 1, UIFont.Small)

                local symbolTexture = NinjaLineages.Social.getSymbol(village.symbolID)
                local texture = symbolTexture and getTexture(symbolTexture)
                if texture then
                    self:drawBandanaPlate(panel, imgX, boxY + 220, imgSize)
                    panel:drawTextureScaled(texture, imgX, boxY + 220, imgSize, imgSize, 1.0, 1.0, 1.0, 1.0)
                end
            end

            -- Draw cards area background frame
            if self.gridX and self.gridY and self.gridW and self.gridH then
                local frameMargin = 10
                panel:drawRect(self.gridX - frameMargin, self.gridY - frameMargin, self.gridW + (frameMargin * 2), self.gridH + (frameMargin * 2), 0.95, 0.03, 0.03, 0.04)
                panel:drawRectBorder(self.gridX - frameMargin, self.gridY - frameMargin, self.gridW + (frameMargin * 2), self.gridH + (frameMargin * 2), 0.6, 1.0, 1.0, 1.0)
            end

            -- Draw page indicator text
            if self.controlX and self.controlY and self.arrowWidth and self.indicatorW and self.arrowHeight then
                local totalDisciplines = self.visibleDisciplines and #self.visibleDisciplines or #NinjaLineages.TreeDefinitions.DisciplineOrder
                local totalPages = math.max(1, math.ceil(totalDisciplines / 6))
                local pageText = tostring(self.currentPage) .. " / " .. tostring(totalPages)
                local font = UIFont.Medium
                local textWidth = getTextManager():MeasureStringX(font, pageText)
                local textHeight = getTextManager():MeasureStringY(font, pageText)
                panel:drawText(
                    pageText,
                    self.controlX + self.arrowWidth + 10 + math.floor((self.indicatorW - textWidth) / 2),
                    self.controlY + math.floor((self.arrowHeight - textHeight) / 2),
                    0.95, 0.85, 0.65, 1,
                    font
                )
            end
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
        elseif self.socialPanel and self.socialPanel:isActive() then
            self.socialPanel:prerender(panel)
        elseif self.missionPanel and self.missionPanel:isActive() then
            self.missionPanel:prerender(panel)
        end
    end

    self.contentPanel.render = function(panel)
        ISPanelJoypad.render(panel)
        if self.screen == "selection" then
            if self.foundVillageButton and not self.foundVillageButton.enable then
                drawDisabledSideButton(panel, self.foundVillageButton)
            end
            if self.missionBoardButton and not self.missionBoardButton.enable then
                drawDisabledSideButton(panel, self.missionBoardButton)
            end
        end
    end

    self:createSelectionScreen()
end

function NLJutsuTreeUI:clearControls()
    if not self.contentPanel or not self.contentPanel.children then return end
    for id, child in pairs(self.contentPanel.children) do
        if child.expanded and child.hidePopup then
            child.expanded = false
            child.hidePopup(child)
        end
        child:setVisible(false)
        if child.tooltipUI and child.tooltipUI:getIsVisible() then
            child.tooltipUI:setVisible(false)
            child.tooltipUI:removeFromUIManager()
        end
    end
    if self.socialPanel then self.socialPanel:clearState() end
    if self.missionPanel then self.missionPanel:clearState() end

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
    self.currentPage = self.currentPage or 1

    -- Use fixed layout parameters for the selection screen to maximize space and prevent clipping
    local margin = 20
    local leftWidth = 250
    local cardsX = leftWidth + margin

    -- Temporarily restore original width to calculate relative panels sizing
    local origW = self.originalWidth or self.width
    local h = self.contentPanel.height
    local availableH = math.floor(h * 0.72) -- Adjusted from 0.76 to leave more room for title and controls
    local cardGap = math.floor(origW * 0.008)

    local cardHeightByH = math.floor((availableH - cardGap) / 2)
    local cardWidth = math.floor(cardHeightByH / 2)
    local gridW = (cardWidth * 3) + (cardGap * 2)

    -- Dynamically resize the window width to perfectly fit: left panel + card grid + padding
    local targetWidth = leftWidth + gridW + margin * 2
    
    local screenWidth = getPlayerScreenWidth(self.playerNum)
    local screenLeft = getPlayerScreenLeft(self.playerNum)
    local currentCenterX = self.x + self.width / 2
    local newX = currentCenterX - targetWidth / 2
    newX = math.max(screenLeft, math.min(screenLeft + screenWidth - targetWidth, newX))
    self:setX(newX)
    self:setWidth(targetWidth)
    if self.contentPanel then
        self.contentPanel:setWidth(targetWidth)
    end

    -- Re-fetch panel metrics based on the resized width
    local w = self.contentPanel.width
    margin = 20
    leftWidth = 250
    cardsX = leftWidth + margin

    local statusHeight = math.floor(h * 0.76)
    local statusY = math.floor((h - statusHeight) / 2)

    self.maxAreaW = w - cardsX - margin
    self.maxAreaH = availableH
    self.cardGap = cardGap
    self.cardHeight = cardHeightByH
    self.cardWidth = cardWidth

    self.gridW = gridW
    self.gridH = (self.cardHeight * 2) + cardGap

    self.gridX = cardsX + math.floor((self.maxAreaW - self.gridW) / 2)
    local gridAreaY = math.floor(h * 0.13) -- Pushed down from 0.09 to prevent overlap with title
    self.gridY = gridAreaY + math.floor((availableH - self.gridH) / 2)

    local disciplineOrder = NinjaLineages.TreeDefinitions.DisciplineOrder
    local visibleDisciplines = {}
    for _, id in ipairs(disciplineOrder) do
        if NinjaLineages.Progression.isDisciplineVisible(self.player, id) then
            table.insert(visibleDisciplines, id)
        end
    end
    self.visibleDisciplines = visibleDisciplines

    local totalPages = math.max(1, math.ceil(#visibleDisciplines / 6))
    if self.currentPage > totalPages then self.currentPage = totalPages end
    if self.currentPage < 1 then self.currentPage = 1 end

    local startIndex = (self.currentPage - 1) * 6 + 1
    local endIndex = math.min(startIndex + 5, #visibleDisciplines)

    self.cardButtons = {}
    for index = startIndex, endIndex do
        local disciplineId = visibleDisciplines[index]
        local definition = NinjaLineages.TreeDefinitions.Disciplines[disciplineId]
        local isLocked = NinjaLineages.Progression.isDisciplineLocked(self.player, disciplineId)
        local title = translated(definition.name, definition.nameFallback)
        if isLocked then title = title .. "\n" .. text("UI_NL_Tree_Locked") end

        local localIndex = index - startIndex
        local col = localIndex % 3
        local row = math.floor(localIndex / 3)

        local btnX = self.gridX + col * (self.cardWidth + cardGap)
        local btnY = self.gridY + row * (self.cardHeight + cardGap)

        local button = self:addButton(
            btnX,
            btnY,
            self.cardWidth,
            self.cardHeight,
            "", -- Empty title so ISButton.render doesn't draw it in the middle
            self,
            NLJutsuTreeUI.onDiscipline
        )
        button.disciplineTitle = title
        button.internal = disciplineId
        button.enable = not isLocked
        button.backgroundColor = { r = 0.10, g = 0.10, b = 0.14, a = 0.95 }
        button.backgroundColorMouseOver = { r = 0.20, g = 0.20, b = 0.28, a = 0.95 }
        
        local descKey = definition.description
        if isLocked then
            descKey = "UI_NL_Discipline_StandardLockedDesc"
        end
        button.tooltip = translated(descKey, definition.descriptionFallback)
        button.render = function(btn)
            -- 1. Draw card texture scaled to fill the entire button
            local cardTex = getTexture(definition.card)
            local texCol = btn.textureColor or { r = 1, g = 1, b = 1, a = 1 }
            if not btn.enable then
                texCol = { r = 0.35, g = 0.35, b = 0.35, a = 1.0 }
            end
            if cardTex then
                btn:drawTextureScaled(cardTex, 0, 0, btn.width, btn.height, texCol.a, texCol.r, texCol.g, texCol.b)
            end

            -- 2. Draw hover overlay if hovered/focused
            if btn.enable and (btn:isMouseOver() or btn.joypadFocused) then
                btn:drawRect(0, 0, btn.width, btn.height, 0.15, 1.0, 1.0, 1.0)
            end

            -- 3. Draw border on top of the card image
            local borderCol = { r = 1, g = 1, b = 1, a = 0.6 }
            if btn.enable and (btn:isMouseOver() or btn.joypadFocused) then
                borderCol = { r = 0.8, g = 0.65, b = 0.2, a = 1.0 } -- Gold hover border
            end
            if btn:shouldDrawBorder() then
                btn:drawRectBorder(0, 0, btn.width, btn.height, borderCol.a, borderCol.r, borderCol.g, borderCol.b)
            end

            -- 5. Call ISButton.render(btn) to handle standard rendering
            ISButton.render(btn)

            -- 6. Draw the title text centered horizontally near the bottom of the card (Bannerlord style)
            if btn.disciplineTitle and btn.disciplineTitle ~= "" then
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
                local totalTextHeight = #lines * (lineHeight + 2)
                local startTextY = btn.height - totalTextHeight - 20
                
                for i, line in ipairs(lines) do
                    local lineW = getTextManager():MeasureStringX(font, line)
                    local lineX = (btn.width - lineW) / 2
                    local lineY = startTextY + (i - 1) * (lineHeight + 2)
                    if btn.enable then
                        -- Draw drop shadow for readability
                        btn:drawText(line, lineX + 1, lineY + 1, 0.0, 0.0, 0.0, 1.0, font)
                        local r, g, b = btn.textColor.r, btn.textColor.g, btn.textColor.b
                        if btn:isMouseOver() or btn.joypadFocused then
                            r, g, b = 0.95, 0.85, 0.65 -- Warm amber text on hover
                        end
                        btn:drawText(line, lineX, lineY, r, g, b, btn.textColor.a, font)
                    else
                        -- Locked text greyed out
                        btn:drawText(line, lineX + 1, lineY + 1, 0.0, 0.0, 0.0, 1.0, font)
                        btn:drawText(line, lineX, lineY, 0.4, 0.4, 0.4, 1.0, font)
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

    -- Add centered page navigation arrows below the grid
    self.arrowWidth = 32
    self.arrowHeight = 32
    self.indicatorW = 80
    self.controlW = self.arrowWidth * 2 + self.indicatorW + 20
    self.controlX = self.gridX + math.floor((self.gridW - self.controlW) / 2)
    self.controlY = self.gridY + self.gridH + math.floor((h - margin - (self.gridY + self.gridH) - self.arrowHeight) / 2)

    if self.currentPage > 1 then
        self.leftArrowBtn = self:addButton(self.controlX, self.controlY, self.arrowWidth, self.arrowHeight, "<", self, NLJutsuTreeUI.onPrevPage)
        self.leftArrowBtn.backgroundColor = { r = 0.11, g = 0.11, b = 0.15, a = 0.95 }
        self.leftArrowBtn.borderColor = { r = 0.34, g = 0.34, b = 0.42, a = 0.85 }
        self.leftArrowBtn.font = UIFont.Medium
    end

    if self.currentPage < totalPages then
        self.rightArrowBtn = self:addButton(self.controlX + self.arrowWidth + self.indicatorW + 20, self.controlY, self.arrowWidth, self.arrowHeight, ">", self, NLJutsuTreeUI.onNextPage)
        self.rightArrowBtn.backgroundColor = { r = 0.11, g = 0.11, b = 0.15, a = 0.95 }
        self.rightArrowBtn.borderColor = { r = 0.34, g = 0.34, b = 0.42, a = 0.85 }
        self.rightArrowBtn.font = UIFont.Medium
    end

    local sideButtonX = margin + 10
    local sideButtonWidth = leftWidth - margin - 20
    local sideButtonHeight = math.floor(h * 0.055)
    local sideButtonGap = 8
    local sideButtonY = statusY + statusHeight - (sideButtonHeight * 4) - (sideButtonGap * 3) - 15
    self.foundVillageButton = self:addButton(
        sideButtonX,
        sideButtonY,
        sideButtonWidth,
        sideButtonHeight,
        text("UI_NL_Tree_FoundHiddenVillage"),
        self,
        NLJutsuTreeUI.onFoundVillage
    )

    self.viewVillageButton = self:addButton(
        sideButtonX,
        sideButtonY + sideButtonHeight + sideButtonGap,
        sideButtonWidth,
        sideButtonHeight,
        text("UI_NL_Social_SeeVillage"),
        self,
        NLJutsuTreeUI.onViewVillage
    )

    self.teamInspectButton = self:addButton(
        sideButtonX,
        sideButtonY + (sideButtonHeight + sideButtonGap) * 2,
        sideButtonWidth,
        sideButtonHeight,
        text("UI_NL_Social_TeamInspect"),
        self,
        NLJutsuTreeUI.onTeamInspect
    )

    self.missionBoardButton = self:addButton(
        sideButtonX,
        sideButtonY + (sideButtonHeight + sideButtonGap) * 3,
        sideButtonWidth,
        sideButtonHeight,
        text("UI_NL_Tree_OpenMissionBoard"),
        self,
        NLJutsuTreeUI.onMissionBoard
    )
    self:updateSelectionButtons()
end

function NLJutsuTreeUI:onDiscipline(button)
    if not button or not button.internal then return end
    local definition = NinjaLineages.TreeDefinitions.Disciplines[button.internal]
    if not definition or NinjaLineages.Progression.isDisciplineLocked(self.player, button.internal) then return end
    self:createDisciplineScreen(button.internal)
end

function NLJutsuTreeUI:onPrevPage()
    if self.currentPage > 1 then
        self.currentPage = self.currentPage - 1
        self:createSelectionScreen()
    end
end

function NLJutsuTreeUI:onNextPage()
    local totalDisciplines = self.visibleDisciplines and #self.visibleDisciplines or #NinjaLineages.TreeDefinitions.DisciplineOrder
    local totalPages = math.max(1, math.ceil(totalDisciplines / 6))
    if self.currentPage < totalPages then
        self.currentPage = self.currentPage + 1
        self:createSelectionScreen()
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
    local village = NinjaLineages.Social.getMyVillage(self.player)
    local isKageRank = NinjaLineages.Progression.getNinjaRank(self.player) == "KAGE"
    if self.foundVillageButton then self.foundVillageButton:setVisible(isKageRank and not village) end
    if self.viewVillageButton then self.viewVillageButton:setVisible(village ~= nil) end
    if self.teamInspectButton then self.teamInspectButton:setVisible(true) end
    if self.missionBoardButton then
        self.missionBoardButton:setVisible(village ~= nil)
        self.missionBoardButton.enable = village ~= nil
    end
end

function NLJutsuTreeUI:onFoundVillage()
    self.socialPanel:open("village_create")
end

function NLJutsuTreeUI:onViewVillage()
    self.socialPanel:open("village")
end

function NLJutsuTreeUI:onTeamInspect()
    self.socialPanel:open("team")
end

function NLJutsuTreeUI:onMissionBoard()
    self.missionPanel:openBoard()
end

function NLJutsuTreeUI:refreshSocialState()
    self.socialPanel:refresh()
end

function NLJutsuTreeUI:refreshMissionState()
    self.missionPanel:refresh()
    if self.socialPanel
            and self.socialPanel:isActive()
            and self.socialPanel.screen == "team" then
        self.socialPanel:refresh()
    end
end

function NLJutsuTreeUI:createDisciplineScreen(disciplineId)
    -- Restore original window size for the tree screen
    if self.originalWidth then
        local screenWidth = getPlayerScreenWidth(self.playerNum)
        local screenLeft = getPlayerScreenLeft(self.playerNum)
        local currentCenterX = self.x + self.width / 2
        local newX = currentCenterX - self.originalWidth / 2
        newX = math.max(screenLeft, math.min(screenLeft + screenWidth - self.originalWidth, newX))
        self:setX(newX)
        self:setWidth(self.originalWidth)
        if self.contentPanel then
            self.contentPanel:setWidth(self.originalWidth)
        end
    end

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
    local height = math.max(680, math.floor(screenHeight * 0.85))
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
    o.currentPage = 1
    o.originalWidth = width
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

NinjaLineages.addEventOnce("client.jutsuTreeUI.onServerCommand", Events.OnServerCommand, NLJutsuTreeUI.onServerCommand)
