require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISInventoryPaneContextMenu"
require "ISUI/ISUI3DModel"
require "NinjaLineages_Social"

NinjaLineages = NinjaLineages or {}
NinjaLineages.BingoBook = NinjaLineages.BingoBook or {}

local BingoBook = NinjaLineages.BingoBook
local ITEM_TYPE = "Base.NL_BingoBook"

NLBingoBookUI = ISCollapsableWindow:derive("NLBingoBookUI")
NLBingoBookUI.instances = NLBingoBookUI.instances or {}

local function text(key, ...)
    return getText(key, ...)
end

local function isBingoBook(item)
    local ok, fullType = pcall(function() return item and item:getFullType() end)
    return ok and fullType == ITEM_TYPE
end

function NLBingoBookUI:initialise()
    ISCollapsableWindow.initialise(self)
    if self.closeButton then
        self.closeButton.onclick = function() self:close() end
    end
    self.previousButton = ISButton:new(25, self.height - 55, 100, 30, "<", self, NLBingoBookUI.onPrevious)
    self.previousButton:initialise()
    self.previousButton:instantiate()
    self:addChild(self.previousButton)
    self.nextButton = ISButton:new(self.width - 125, self.height - 55, 100, 30, ">", self, NLBingoBookUI.onNext)
    self.nextButton:initialise()
    self.nextButton:instantiate()
    self:addChild(self.nextButton)
    
    self.starTexture = getTexture("media/ui/FavoriteStar.png")
    
    self.avatarPanel = ISUI3DModel:new(self.width / 2 - 75, 80, 150, 220)
    self.avatarPanel.backgroundColor = {r=0, g=0, b=0, a=0.0}
    self.avatarPanel.borderColor = {r=0, g=0, b=0, a=0.0}
    self.avatarPanel:initialise()
    self.avatarPanel:instantiate()
    self.avatarPanel:setDirection(IsoDirections.S)
    self.avatarPanel:setIsometric(false)
    self.avatarPanel:setZoom(1.5)
    self.avatarPanel:setYOffset(-0.6)
    self.avatarPanel:setVisible(false)
    self:addChild(self.avatarPanel)
    
    self:updateButtons()
end

function NLBingoBookUI:updateButtons()
    local count = #(self.snapshot.players or {})
    self.previousButton.enable = count > 0 and self.page > 1
    self.nextButton.enable = count > 0 and self.page < count
    self:updateAvatar()
end

function NLBingoBookUI:updateAvatar()
    if not self.avatarPanel then return end
    self.avatarPanel:setVisible(false)
    local players = self.snapshot.players or {}
    if #players == 0 then return end
    
    local entry = players[self.page]
    if entry and entry.playerName then
        local targetPlayer = getPlayerFromUsername(entry.playerName)
        if targetPlayer then
            self.avatarPanel:setCharacter(targetPlayer)
            self.avatarPanel:setVisible(true)
        end
    end
end

function NLBingoBookUI:onPrevious()
    if self.page > 1 then
        self.page = self.page - 1
        self:updateButtons()
    end
end

function NLBingoBookUI:onNext()
    if self.page < #(self.snapshot.players or {}) then
        self.page = self.page + 1
        self:updateButtons()
    end
end

function NLBingoBookUI:prerender()
    ISCollapsableWindow.prerender(self)
    self:drawRect(12, 25, self.width - 24, self.height - 85, 0.96, 0.12, 0.09, 0.06)
    self:drawRectBorder(12, 25, self.width - 24, self.height - 85, 0.9, 0.72, 0.58, 0.35)
    self:drawTextCentre(text("UI_NL_BingoBook_Title"), self.width / 2, 45, 0.86, 0.18, 0.12, 1, UIFont.Large)

    local players = self.snapshot.players or {}
    if #players == 0 then
        self:drawTextCentre(text("UI_NL_BingoBook_Empty"), self.width / 2, 155, 0.85, 0.8, 0.75, 1, UIFont.Medium)
        return
    end

    local entry = players[self.page]
    self:drawTextCentre(tostring(entry.playerName), self.width / 2, 310, 0.85, 0.8, 0.75, 1, UIFont.Large)
    local y = 350
    for _, flag in ipairs(entry.flags or {}) do
        local line = tostring(flag.flagType) .. "           " .. text("UI_NL_BingoBook_By") .. " " .. tostring(flag.sourceVillageName)
        self:drawTextCentre(line, self.width / 2, y, 0.85, 0.8, 0.75, 1, UIFont.Medium)
        
        local severity = math.max(1, math.min(5, tonumber(flag.severity) or 1))
        local starWidth = 16
        local startX = (self.width / 2) - 80
        for i = 1, severity do
            if self.starTexture then
                self:drawTextureScaled(self.starTexture, startX + (i * starWidth), y + 2, 14, 14, 1, 1, 1, 1)
            end
        end
        y = y + 42
    end
    self:drawTextCentre(
        tostring(self.page) .. " / " .. tostring(#players),
        self.width / 2, self.height - 48, 0.75, 0.75, 0.78, 1, UIFont.Small
    )
end

function NLBingoBookUI:close()
    self:setVisible(false)
    self:removeFromUIManager()
    NLBingoBookUI.instances[self.playerNum] = nil
end

function NLBingoBookUI:new(playerNum, snapshot)
    local screenWidth = getPlayerScreenWidth(playerNum)
    local screenHeight = getPlayerScreenHeight(playerNum)
    local width, height = 640, 520
    local x = getPlayerScreenLeft(playerNum) + (screenWidth - width) / 2
    local y = getPlayerScreenTop(playerNum) + (screenHeight - height) / 2
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum
    o.snapshot = snapshot or { players = {} }
    o.page = 1
    o.resizable = false
    o:setTitle(text("UI_NL_BingoBook_Title"))
    return o
end

function BingoBook.open(snapshot)
    local player = getSpecificPlayer and getSpecificPlayer(0) or getPlayer()
    if not player then return end
    local playerNum = player:getPlayerNum()
    local existing = NLBingoBookUI.instances[playerNum]
    if existing then existing:close() end
    local ui = NLBingoBookUI:new(playerNum, snapshot)
    ui:initialise()
    ui:addToUIManager()
    ui:setVisible(true)
    NLBingoBookUI.instances[playerNum] = ui
end

function BingoBook.receiveSnapshot(snapshot)
    snapshot = snapshot or { players = {} }
    if BingoBook.awaitingSnapshot then
        BingoBook.awaitingSnapshot = false
        BingoBook.open(snapshot)
        return
    end

    for _, ui in pairs(NLBingoBookUI.instances) do
        ui.snapshot = snapshot
        local count = #(snapshot.players or {})
        ui.page = math.max(1, math.min(ui.page or 1, math.max(1, count)))
        ui:updateButtons()
    end
end

local previousReadItem = ISInventoryPaneContextMenu.readItem
ISInventoryPaneContextMenu.readItem = function(item, playerNum)
    if not isBingoBook(item) then return previousReadItem(item, playerNum) end
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    BingoBook.awaitingSnapshot = true
    NinjaLineages.Social.request(player, "socialRequestReputationSnapshot", {})
end

local function onServerCommand(module, command, args)
    if module == "NinjaLineages" and command == "reputationSnapshot" then
        BingoBook.receiveSnapshot(args)
    end
end

NinjaLineages.addEventOnce(
    "client.bingoBook.onServerCommand",
    Events.OnServerCommand,
    onServerCommand
)
