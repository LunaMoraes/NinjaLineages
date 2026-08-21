require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISModalDialog"
require "NinjaLineages_Balance"
require "NinjaLineages_Progression"
require "NinjaLineages_Utils"
require "disciplines/jinchuuriki/NinjaLineages_BijuuDefinitions"
require "disciplines/jinchuuriki/NinjaLineages_BijuuSealing"

NinjaLineages = NinjaLineages or {}
NinjaLineages.JinchuurikiPanel = NinjaLineages.JinchuurikiPanel or {}

local PanelModule = NinjaLineages.JinchuurikiPanel
local Progression = NinjaLineages.Progression
local Definitions = NinjaLineages.BijuuDefinitions
local Sealing = NinjaLineages.BijuuSealing
local MAX_ACTION_ROWS = 9

local MILESTONES = {
    "bijuu_chakra_recognition",
    "containment_technique",
    "tailed_beast_locator",
    "seal_reinforcement",
    "bijuu_extraction_transfer",
    "tailed_beast_chakra",
    "chakra_cloak",
}

NLJinchuurikiPanelUI = ISCollapsableWindow:derive("NLJinchuurikiPanelUI")
NLJinchuurikiPanelUI.instances = NLJinchuurikiPanelUI.instances or {}

local function text(key, ...)
    return getText(key, ...)
end

local function rounded(value)
    return math.floor((tonumber(value) or 0) + 0.5)
end

local function directionTo(player, x, y)
    local dx, dy = x - player:getX(), y - player:getY()
    if math.abs(dx) < 0.5 and math.abs(dy) < 0.5 then return "-" end
    local horizontal = dx > 0 and "E" or "W"
    local vertical = dy > 0 and "S" or "N"
    if math.abs(dx) > math.abs(dy) * 2 then return horizontal end
    if math.abs(dy) > math.abs(dx) * 2 then return vertical end
    return vertical .. horizontal
end

local function remainingExtractionText(jinchuuriki)
    local deadline = tonumber(jinchuuriki and jinchuuriki.extractionDeathAt)
    if not deadline then return text("UI_NL_Jinchuuriki_None") end
    local remaining = math.max(0, deadline - NinjaLineages.Utils.Time.gameMinutes())
    local hours = math.floor(remaining / 60)
    local minutes = math.floor(remaining % 60)
    return text("UI_NL_Jinchuuriki_TimeRemaining", tostring(hours), tostring(minutes))
end

function NLJinchuurikiPanelUI:new(player)
    local playerNum = player:getPlayerNum()
    local screenWidth = getPlayerScreenWidth(playerNum)
    local screenHeight = getPlayerScreenHeight(playerNum)
    local width, height = 600, math.min(720, screenHeight - 40)
    local x = getPlayerScreenLeft(playerNum) + (screenWidth - width) / 2
    local y = getPlayerScreenTop(playerNum) + (screenHeight - height) / 2
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.playerNum = playerNum
    o.mode = "host"
    o.locatorSnapshot = nil
    o.locatorPending = false
    o.locatorError = nil
    o.hostActionRows = {}
    o.hostActionSignature = nil
    o.hostActionMessage = nil
    o.resizable = false
    o:setTitle(text("UI_NL_Jinchuuriki_PanelTitle"))
    return o
end

function NLJinchuurikiPanelUI:initialise()
    ISCollapsableWindow.initialise(self)
    if self.closeButton then self.closeButton.onclick = function() self:close() end end

    self.hostButton = ISButton:new(18, 38, 170, 30,
        text("UI_NL_Jinchuuriki_HostView"), self, NLJinchuurikiPanelUI.showHost)
    self.hostButton:initialise()
    self.hostButton:instantiate()
    self:addChild(self.hostButton)

    self.locatorButton = ISButton:new(198, 38, 190, 30,
        text("UI_NL_Jinchuuriki_LocatorView"), self, NLJinchuurikiPanelUI.showLocator)
    self.locatorButton:initialise()
    self.locatorButton:instantiate()
    self:addChild(self.locatorButton)

    self.refreshButton = ISButton:new(self.width - 138, 38, 120, 30,
        text("UI_NL_Jinchuuriki_Refresh"), self, NLJinchuurikiPanelUI.requestLocator)
    self.refreshButton:initialise()
    self.refreshButton:instantiate()
    self:addChild(self.refreshButton)

    self.hostActionButtons = {}
    for index = 1, MAX_ACTION_ROWS do
        local button = ISButton:new(160, 245, 120, 27,
            "", self, NLJinchuurikiPanelUI.onHostAction)
        button:initialise()
        button:instantiate()
        button:setVisible(false)
        self:addChild(button)
        self.hostActionButtons[index] = button
    end
    self:updateControls()
end

local function collectHostActionRows(player, hosted, capacity)
    local sealed, empty = {}, {}
    for _, item in ipairs(NinjaLineages.Utils.Inventory.collectItems(player)) do
        if Sealing.isVessel(item) then
            local seal = item.getModData and item:getModData().bijuuSeal or nil
            if type(seal) == "table" and Definitions.isValidId(seal.bijuuId) then
                table.insert(sealed, {
                    kind = "install",
                    itemId = Sealing.getVesselItemId(item),
                    bijuuId = seal.bijuuId,
                })
            elseif Sealing.isEmptyVessel(item) then
                table.insert(empty, {
                    kind = "extract",
                    itemId = Sealing.getVesselItemId(item),
                    bijuuId = hosted[1],
                })
            end
        end
    end
    if #hosted < capacity then return sealed end
    if #hosted > 0 and Progression.isCompleted(player, "bijuu_extraction_transfer") then
        return empty
    end
    return {}
end

function NLJinchuurikiPanelUI:refreshHostActions()
    local jinchuuriki = Progression.getJinchuurikiData(self.player) or {}
    local hosted = jinchuuriki.hostedBijuuIds or {}
    local capacity = NinjaLineages.Balance.Jinchuuriki.MAX_HOSTED_BIJUU or 1
    local rows = collectHostActionRows(self.player, hosted, capacity)
    local signatureParts = { tostring(#hosted), tostring(capacity) }
    for _, row in ipairs(rows) do
        table.insert(signatureParts, row.kind .. ":" .. tostring(row.itemId)
            .. ":" .. tostring(row.bijuuId))
    end
    local signature = table.concat(signatureParts, "|")
    if signature == self.hostActionSignature then return end
    self.hostActionSignature = signature
    self.hostActionRows = rows

    for index, button in ipairs(self.hostActionButtons or {}) do
        local row = rows[index]
        button:setVisible(self.mode == "host" and row ~= nil)
        if row then
            button.hostAction = row.kind
            button.vesselItemId = row.itemId
            button.bijuuId = row.bijuuId
            button:setTitle(text(row.kind == "install"
                and "UI_NL_Jinchuuriki_SealIntoSelf"
                or "UI_NL_Jinchuuriki_ExtractToVessel"))
        end
    end
end

function NLJinchuurikiPanelUI:sendHostAction(action, vesselItemId)
    self.hostActionMessage = nil
    if NinjaLineages.isClient and NinjaLineages.isClient() then
        sendClientCommand(self.player, "NinjaLineages",
            action == "install" and "installBijuuFromVessel" or "extractHostedBijuu",
            { vesselItemId = vesselItemId })
        return
    end
    local server = NinjaLineages.JinchuurikiServer
    if not server then
        self.hostActionMessage = text("UI_NL_Jinchuuriki_ActionFailed", "unavailable")
        return
    end
    local ok, reason
    if action == "install" then
        ok, reason = server.installFromVessel(self.player, vesselItemId)
    else
        ok, reason = server.extractHostedBijuu(self.player, vesselItemId)
    end
    self:receiveHostActionResult(action, ok, reason)
end

local function confirmExtraction(panel, button, request)
    if button.internal ~= "YES" then return end
    panel:sendHostAction("extract", request.vesselItemId)
end

function NLJinchuurikiPanelUI:onHostAction(button)
    if button.hostAction == "install" then
        self:sendHostAction("install", button.vesselItemId)
        return
    end
    if button.hostAction ~= "extract" then return end
    local warningKey = NinjaLineages.hasUzumaki(self.player)
        and "UI_NL_Jinchuuriki_ExtractWarningUzumaki"
        or "UI_NL_Jinchuuriki_ExtractWarningFatal"
    local modal = ISModalDialog:new(
        0, 0, 480, 180, text(warningKey), true, self,
        confirmExtraction, self.playerNum, { vesselItemId = button.vesselItemId })
    modal:initialise()
    modal:addToUIManager()
end

function NLJinchuurikiPanelUI:receiveHostActionResult(action, ok, reason)
    self.hostActionSignature = nil
    self.hostActionMessage = ok
        and text(action == "install" and "UI_NL_Jinchuuriki_InstallSuccess"
            or "UI_NL_Jinchuuriki_ExtractionSuccess")
        or text("UI_NL_Jinchuuriki_ActionFailed", tostring(reason or "unknown"))
end

function NLJinchuurikiPanelUI:updateControls()
    local locatorUnlocked = Progression.isCompleted(self.player, "tailed_beast_locator")
    self.hostButton.enable = self.mode ~= "host"
    self.locatorButton.enable = locatorUnlocked and self.mode ~= "locator"
    self.locatorButton.tooltip = locatorUnlocked and nil
        or text("UI_NL_Jinchuuriki_LocatorLocked")
    self.refreshButton:setVisible(self.mode == "locator")
    self.refreshButton.enable = locatorUnlocked and not self.locatorPending
    for index, button in ipairs(self.hostActionButtons or {}) do
        button:setVisible(self.mode == "host" and self.hostActionRows[index] ~= nil)
    end
end

function NLJinchuurikiPanelUI:showHost()
    self.mode = "host"
    self:updateControls()
end

function NLJinchuurikiPanelUI:showLocator()
    if not Progression.isCompleted(self.player, "tailed_beast_locator") then return end
    self.mode = "locator"
    self:updateControls()
    if not self.locatorSnapshot then self:requestLocator() end
end

function NLJinchuurikiPanelUI:requestLocator()
    if self.locatorPending or not Progression.isCompleted(self.player, "tailed_beast_locator") then return end
    self.locatorPending = true
    self.locatorError = nil
    self:updateControls()

    if NinjaLineages.isClient and NinjaLineages.isClient() then
        sendClientCommand(self.player, "NinjaLineages", "requestBijuuLocator", {})
        return
    end

    local server = NinjaLineages.ProgressionServer
    if server and server.getBijuuLocatorSnapshot then
        local snapshot, reason = server.getBijuuLocatorSnapshot(self.player)
        self:receiveLocatorSnapshot(snapshot, reason)
    else
        self:receiveLocatorSnapshot(nil, "unavailable")
    end
end

function NLJinchuurikiPanelUI:receiveLocatorSnapshot(snapshot, reason)
    self.locatorPending = false
    self.locatorSnapshot = snapshot
    self.locatorError = snapshot and nil or reason
    self:updateControls()
end

function NLJinchuurikiPanelUI:drawHostView()
    local jinchuuriki = Progression.getJinchuurikiData(self.player) or {}
    local hosted = jinchuuriki.hostedBijuuIds or {}
    local capacity = NinjaLineages.Balance.Jinchuuriki.MAX_HOSTED_BIJUU or 1
    local y = 92

    self:drawText(text("UI_NL_Jinchuuriki_CurrentHost"), 28, y, 1, 0.78, 0.35, 1, UIFont.Large)
    y = y + 42
    if #hosted == 0 then
        self:drawText(text("UI_NL_Jinchuuriki_HostedBijuu", text("UI_NL_Jinchuuriki_None")),
            38, y, 0.9, 0.9, 0.92, 1, UIFont.Medium)
        y = y + 28
    else
        for _, bijuuId in ipairs(hosted) do
            local definition = Definitions.get(bijuuId)
            local name = definition and text(definition.nameKey) or tostring(bijuuId)
            self:drawText(text("UI_NL_Jinchuuriki_HostedBijuu", name),
                38, y, 0.9, 0.9, 0.92, 1, UIFont.Medium)
            y = y + 25
            if definition then
                self:drawText(text("UI_NL_Jinchuuriki_Tails", tostring(definition.tails)),
                    58, y, 0.78, 0.78, 0.82, 1, UIFont.Small)
                y = y + 24
            end
        end
    end
    self:drawText(text("UI_NL_Jinchuuriki_HostCapacity", tostring(#hosted), tostring(capacity)),
        38, y, 0.78, 0.78, 0.82, 1, UIFont.Small)
    y = y + 30
    self:drawText(text("UI_NL_Jinchuuriki_ExtractionGrace", remainingExtractionText(jinchuuriki)),
        38, y, 0.78, 0.78, 0.82, 1, UIFont.Small)

    y = y + 38
    self:drawText(text("UI_NL_Jinchuuriki_VesselActions"), 28, y,
        1, 0.78, 0.35, 1, UIFont.Medium)
    y = y + 34
    if #self.hostActionRows == 0 then
        self:drawText(text(#hosted < capacity
            and "UI_NL_Jinchuuriki_NoSealedVessels"
            or (Progression.isCompleted(self.player, "bijuu_extraction_transfer")
                and "UI_NL_Jinchuuriki_NoEmptyVessels"
                or "UI_NL_Jinchuuriki_ExtractionLocked")),
            38, y, 0.7, 0.7, 0.74, 1, UIFont.Small)
        y = y + 32
    else
        for index, row in ipairs(self.hostActionRows) do
            if index > MAX_ACTION_ROWS then break end
            local definition = Definitions.get(row.bijuuId)
            local name = definition and text(definition.nameKey) or tostring(row.bijuuId)
            local column = (index - 1) % 2
            local rowIndex = math.floor((index - 1) / 2)
            local rowY = y + rowIndex * 31
            local columnX = 28 + column * 278
            self:drawText(text("UI_NL_Jinchuuriki_VesselRow", name,
                    tostring(definition and definition.tails or "?")),
                columnX, rowY + 5, 0.86, 0.84, 0.78, 1, UIFont.Small)
            local button = self.hostActionButtons[index]
            button:setX(columnX + 145)
            button:setY(rowY)
        end
        y = y + math.ceil(math.min(#self.hostActionRows, MAX_ACTION_ROWS) / 2) * 31
        if #self.hostActionRows > MAX_ACTION_ROWS then
            self:drawText(text("UI_NL_Jinchuuriki_MoreVessels",
                    tostring(#self.hostActionRows - MAX_ACTION_ROWS)),
                38, y, 0.7, 0.7, 0.74, 1, UIFont.Small)
            y = y + 25
        end
    end
    if self.hostActionMessage then
        self:drawText(self.hostActionMessage, 38, y, 0.82, 0.78, 0.6, 1, UIFont.Small)
        y = y + 28
    end

    y = y + 12
    self:drawText(text("UI_NL_Jinchuuriki_Milestones"), 28, y, 1, 0.78, 0.35, 1, UIFont.Large)
    y = y + 38
    for _, nodeId in ipairs(MILESTONES) do
        local complete = Progression.isCompleted(self.player, nodeId)
        local stateKey = complete and "UI_NL_Tree_State_completed" or "UI_NL_Tree_State_locked"
        self:drawText(text("UI_NL_Node_" .. nodeId .. "_Name"), 38, y,
            complete and 0.55 or 0.7, complete and 0.9 or 0.7, complete and 0.55 or 0.72, 1, UIFont.Small)
        self:drawTextRight(text(stateKey), self.width - 38, y,
            complete and 0.55 or 0.7, complete and 0.9 or 0.7, complete and 0.55 or 0.72, 1, UIFont.Small)
        y = y + 27
    end
end

function NLJinchuurikiPanelUI:drawLocatorView()
    local y = 90
    self:drawText(text("UI_NL_Jinchuuriki_LocatorTitle"), 28, y, 1, 0.78, 0.35, 1, UIFont.Large)
    y = y + 38
    if self.locatorPending then
        self:drawTextCentre(text("UI_NL_Jinchuuriki_LocatorLoading"), self.width / 2, y + 80,
            0.82, 0.82, 0.86, 1, UIFont.Medium)
        return
    end
    if not self.locatorSnapshot then
        self:drawTextCentre(text("UI_NL_Jinchuuriki_LocatorUnavailable"), self.width / 2, y + 80,
            0.82, 0.55, 0.5, 1, UIFont.Medium)
        return
    end

    for _, entry in ipairs(self.locatorSnapshot.entries or {}) do
        local definition = Definitions.get(entry.bijuuId)
        local name = definition and text(definition.nameKey) or tostring(entry.bijuuId)
        local tails = tonumber(entry.tails) or (definition and definition.tails) or 0
        self:drawText(text("UI_NL_Jinchuuriki_LocatorName", name, tostring(tails)),
            38, y, 0.94, 0.9, 0.84, 1, UIFont.Medium)

        local detail
        if entry.status == "trackable" and type(entry.x) == "number" and type(entry.y) == "number" then
            local dx, dy = entry.x - self.player:getX(), entry.y - self.player:getY()
            local distance = math.sqrt(dx * dx + dy * dy)
            detail = text("UI_NL_Jinchuuriki_LocatorPosition",
                tostring(rounded(entry.x)), tostring(rounded(entry.y)),
                tostring(rounded(distance)), directionTo(self.player, entry.x, entry.y))
        else
            local statusKey = entry.status == "sealed"
                and "UI_NL_Jinchuuriki_StatusSealed"
                or (entry.status == "unknown" and "UI_NL_Jinchuuriki_StatusUnknown"
                or "UI_NL_Jinchuuriki_StatusUnavailable")
            detail = text("UI_NL_Jinchuuriki_LocatorStatus", text(statusKey))
        end
        self:drawText(detail, 58, y + 23, 0.7, 0.74, 0.78, 1, UIFont.Small)
        y = y + 49
    end
end

function NLJinchuurikiPanelUI:prerender()
    ISCollapsableWindow.prerender(self)
    self:drawRect(12, 28, self.width - 24, self.height - 40, 0.94, 0.035, 0.03, 0.045)
    self:drawRectBorder(12, 28, self.width - 24, self.height - 40, 0.8, 0.72, 0.45, 0.2)
end

function NLJinchuurikiPanelUI:render()
    ISCollapsableWindow.render(self)
    if not self.player or (self.player.isDead and self.player:isDead()) then
        self:close()
        return
    end
    if self.mode == "host" then self:refreshHostActions() end
    self:updateControls()
    if self.mode == "locator" then self:drawLocatorView() else self:drawHostView() end
end

function NLJinchuurikiPanelUI:close()
    self:setVisible(false)
    self:removeFromUIManager()
    NLJinchuurikiPanelUI.instances[self.playerNum] = nil
end

function PanelModule.openPanel(player)
    player = player or (getPlayer and getPlayer())
    if not player
            or not Progression.isDisciplineVisible(player, "jinchuuriki")
            or Progression.isDisciplineLocked(player, "jinchuuriki") then
        return nil
    end

    local playerNum = player:getPlayerNum()
    local existing = NLJinchuurikiPanelUI.instances[playerNum]
    if existing then
        existing.player = player
        existing:setVisible(true)
        existing:bringToTop()
        return existing
    end

    local panel = NLJinchuurikiPanelUI:new(player)
    panel:initialise()
    panel:addToUIManager()
    panel:setVisible(true)
    panel:bringToTop()
    NLJinchuurikiPanelUI.instances[playerNum] = panel
    return panel
end

local function onServerCommand(module, command, args)
    if module ~= "NinjaLineages" then return end
    if command == "jinchuurikiActionResult" then
        for _, panel in pairs(NLJinchuurikiPanelUI.instances) do
            local onlineId = panel.player.getOnlineID and panel.player:getOnlineID() or -1
            if not args or args.playerOnlineId == nil or args.playerOnlineId == onlineId then
                panel:receiveHostActionResult(args and args.action, args and args.ok, args and args.reason)
            end
        end
        return
    end
    if command ~= "bijuuLocatorSnapshot" then return end
    for _, panel in pairs(NLJinchuurikiPanelUI.instances) do
        local onlineId = panel.player.getOnlineID and panel.player:getOnlineID() or -1
        if panel.locatorPending and (not args or args.playerOnlineId == nil or args.playerOnlineId == onlineId) then
            local snapshot = args and args.ok == true and {
                generatedAtGameMinutes = args.generatedAtGameMinutes,
                entries = args.entries or {},
            } or nil
            panel:receiveLocatorSnapshot(snapshot, args and args.reason)
        end
    end
end

NinjaLineages.addEventOnce(
    "client.jinchuurikiPanel.onServerCommand",
    Events.OnServerCommand,
    onServerCommand
)
