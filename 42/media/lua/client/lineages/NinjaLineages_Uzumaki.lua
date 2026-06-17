require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "NinjaLineages_UI"
require "NinjaLineages_Balance"
require "NinjaLineages_HandSigns"
require "NinjaLineages_Progression"
require "NinjaLineages_AbilityAuthority"
require "NinjaLineages_UzumakiPassives"
require "NinjaLineages_ScrollUtils"

NinjaLineages = NinjaLineages or {}
NinjaLineages.Uzumaki = NinjaLineages.Uzumaki or {}

local consts = NinjaLineages.Constants

-- Alarm Seal Logic
local function getActualInventoryItem(item)
    if not item then return nil end
    if item.items and item.items[1] then return item.items[1] end
    return item
end

local function placeAlarmSeal(player, square)
    if not square then square = player:getSquare() end
    if not square then return false end
    return NinjaLineages.AbilityAuthority.request(player, "alarm_seal", {
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
    })
end

-- Storage Seal logic
-- (isSealedScroll, NinjaLineages.ScrollUtils.isBackpackContainer, getScrollInventory now in NinjaLineages.ScrollUtils)

local function getContainedBackpack(scroll)
    local inv = NinjaLineages.ScrollUtils.getScrollInventory(scroll)
    if not inv or inv:getItems():size() == 0 then return nil end
    return inv:getItems():get(0)
end

local function sealBackpackInScroll(player, backpack, scroll)
    if not backpack or not scroll then return false end
    return NinjaLineages.AbilityAuthority.request(player, "storage_seal", {
        backpackItemId = backpack:getID(),
        scrollItemId = scroll:getID(),
    })
end

NLUnsealScrollAction = ISBaseTimedAction and ISBaseTimedAction:derive("NLUnsealScrollAction") or {}

function NLUnsealScrollAction:isValid()
    return self.scroll and getContainedBackpack(self.scroll) ~= nil
end

function NLUnsealScrollAction:perform()
    if self.scroll then
        NinjaLineages.AbilityAuthority.request(self.character, "storage_unseal", {
            scrollItemId = self.scroll:getID(),
        })
    end
    if ISBaseTimedAction then
        ISBaseTimedAction.perform(self)
    end
end

function NLUnsealScrollAction:new(character, scroll)
    local o = ISBaseTimedAction and ISBaseTimedAction.new(self, character) or {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.scroll = scroll
    o.maxTime = character:isTimedActionInstant() and 1 or consts.Uzumaki.StorageSeal.UNSEAL_TIME
    return o
end

local function unsealScroll(player, scroll)
    if not NinjaLineages.Progression.isCompleted(player, "storage_seal") then
        player:Say(getText("UI_NL_Error_JutsuNotLearned"))
        return
    end
    local backpack = getContainedBackpack(scroll)
    if not backpack then return end
    if ISTimedActionQueue and ISBaseTimedAction then
        ISTimedActionQueue.add(NLUnsealScrollAction:new(player, scroll))
        NinjaLineages.HandSigns.playSeal(player, "tiger")
    else
        NinjaLineages.AbilityAuthority.request(player, "storage_unseal", {
            scrollItemId = scroll:getID(),
        })
    end
end

local function collectEmptyScrolls(player)
    local scrolls = {}
    local inv = player and player:getInventory()
    if not inv then return scrolls end
    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if NinjaLineages.ScrollUtils.isSealedScroll(item) then
            local scrollInv = getScrollInventory(item)
            if scrollInv and scrollInv:getItems():size() == 0 then
                table.insert(scrolls, item)
            end
        end
    end
    return scrolls
end

local function addStorageSealContextMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end
    if not NinjaLineages.Progression.isCompleted(player, "storage_seal") then return end

    local selected = nil
    if items then
        selected = getActualInventoryItem(items[1])
    end
    if not selected then return end

    if NinjaLineages.ScrollUtils.isSealedScroll(selected) then
        if getContainedBackpack(selected) then
            context:addOption(getText("UI_NL_Ability_StorageSeal_Unseal"), player, unsealScroll, selected)
        end
        return
    end

    if not NinjaLineages.ScrollUtils.isBackpackContainer(selected) then return end
    local scrolls = collectEmptyScrolls(player)
    if #scrolls == 0 then return end

    local option = context:addOption(getText("UI_NL_Ability_StorageSeal_Seal"))
    local subMenu = ISContextMenu:getNew(context)
    context:addSubMenu(option, subMenu)
    for _, scroll in ipairs(scrolls) do
        subMenu:addOption(scroll:getName(), player, sealBackpackInScroll, selected, scroll)
    end
end

-- Hook context menus
if Events.OnFillInventoryObjectContextMenu then
    NinjaLineages.addEventOnce(
        "client.uzumaki.onFillInventoryObjectContextMenu.storageSeal",
        Events.OnFillInventoryObjectContextMenu,
        addStorageSealContextMenu
    )
end

local function addAlarmSealWorldContextMenu(playerNum, context, worldObjects, test)
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end
    if test then return true end

    local alarmSeal = NinjaLineages.Utils.Inventory.getFirstInventoryItem(player, "Base.NL_AlarmSeal")
    if not NinjaLineages.Progression.isCompleted(player, "alarm_seal") then return end

    if alarmSeal then
        local subMenu = NinjaLineages.UI.getOrCreateWorldSubMenu(context)
        if subMenu then
            local square = player:getSquare()
            for _, worldObject in ipairs(worldObjects or {}) do
                if worldObject and worldObject.getSquare and worldObject:getSquare() then
                    square = worldObject:getSquare()
                    break
                end
            end
            subMenu:addOption(getText("UI_NL_Ability_AlarmSeal_Place"), player, placeAlarmSeal, square)
        end
    end
end

if Events.OnFillWorldObjectContextMenu then
    NinjaLineages.addEventOnce(
        "client.uzumaki.onFillWorldObjectContextMenu.alarmSeal",
        Events.OnFillWorldObjectContextMenu,
        addAlarmSealWorldContextMenu
    )
end