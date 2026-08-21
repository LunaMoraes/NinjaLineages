require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "NinjaLineages_Balance"
require "NinjaLineages_Progression"
require "NinjaLineages_Utils"
require "disciplines/jinchuuriki/NinjaLineages_BijuuDefinitions"

NinjaLineages = NinjaLineages or {}
NinjaLineages.JinchuurikiPanel = NinjaLineages.JinchuurikiPanel or {}

local PanelModule = NinjaLineages.JinchuurikiPanel
local Progression = NinjaLineages.Progression
local Definitions = NinjaLineages.BijuuDefinitions

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
    local width, height = 600, 610
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
    self:updateControls()
end

function NLJinchuurikiPanelUI:updateControls()
    local locatorUnlocked = Progression.isCompleted(self.player, "tailed_beast_locator")
    self.hostButton.enable = self.mode ~= "host"
    self.locatorButton.enable = locatorUnlocked and self.mode ~= "locator"
    self.locatorButton.tooltip = locatorUnlocked and nil
        or text("UI_NL_Jinchuuriki_LocatorLocked")
    self.refreshButton:setVisible(self.mode == "locator")
    self.refreshButton.enable = locatorUnlocked and not self.locatorPending
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

    y = y + 42
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
    if module ~= "NinjaLineages" or command ~= "bijuuLocatorSnapshot" then return end
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
