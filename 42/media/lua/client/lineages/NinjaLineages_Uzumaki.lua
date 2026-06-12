require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "NinjaLineages_UI"
require "NinjaLineages_Balance"
require "NinjaLineages_HandSigns"

NinjaLineages = NinjaLineages or {}
NinjaLineages.Uzumaki = NinjaLineages.Uzumaki or {}

local consts = NinjaLineages.Constants

local uzumakiHealthState = {}
local alarmSeals = {}
local nextAlarmScanAt = 0
local nextAlarmDiscoveryAt = 0

local function getBodyPartSnapshot(player)
    local snapshot = {}
    local bodyDamage = player and player:getBodyDamage()
    local parts = bodyDamage and bodyDamage:getBodyParts()
    if not parts then return snapshot end
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        local health = 100
        local bleed = 0
        pcall(function() health = part:getHealth() end)
        pcall(function() bleed = part:getBleedingTime() end)
        snapshot[i] = { health = health, bleed = bleed }
    end
    return snapshot
end

local function captureUzumakiHealthState(player)
    local bodyDamage = player and player:getBodyDamage()
    if not bodyDamage then return end
    local data = uzumakiHealthState[player] or {}
    pcall(function() data.generalHealth = bodyDamage:getHealth() end)
    data.parts = getBodyPartSnapshot(player)
    data.lastPassiveAt = NinjaLineages.Utils.Time.nowGameMs(player)
    uzumakiHealthState[player] = data
end

local function refundUzumakiDamage(player)
    if not NinjaLineages.hasUzumaki(player) then return end
    local data = uzumakiHealthState[player]
    if not data then
        captureUzumakiHealthState(player)
        return
    end

    local bodyDamage = player:getBodyDamage()
    if not bodyDamage then return end

    local ok, currentGeneral = pcall(function() return bodyDamage:getHealth() end)
    if ok and data.generalHealth and currentGeneral and currentGeneral < data.generalHealth then
        pcall(function() bodyDamage:AddGeneralHealth((data.generalHealth - currentGeneral) * consts.Uzumaki.Passive.DAMAGE_REFUND) end)
    end

    captureUzumakiHealthState(player)
end

local function applyUzumakiBleedSlow(player)
    if not NinjaLineages.hasUzumaki(player) then
        uzumakiHealthState[player] = nil
        return
    end

    local nowMs = NinjaLineages.Utils.Time.nowGameMs(player)
    local data = uzumakiHealthState[player]
    if not data then
        captureUzumakiHealthState(player)
        return
    end
    if data.lastPassiveAt and nowMs < data.lastPassiveAt + consts.Uzumaki.Passive.TICK_MS then return end

    local bodyDamage = player:getBodyDamage()
    local parts = bodyDamage and bodyDamage:getBodyParts()
    if not parts then return end

    for i = 0, parts:size() - 1 do
        local previous = data.parts and data.parts[i]
        local part = parts:get(i)
        if previous and part then
            local okBleed, currentBleed = pcall(function() return part:getBleedingTime() end)
            if okBleed and currentBleed and currentBleed > 0 and previous.bleed and currentBleed < previous.bleed then
                local restored = currentBleed + ((previous.bleed - currentBleed) * consts.Uzumaki.Passive.BLEED_REFUND)
                pcall(function() part:setBleedingTime(restored) end)
            end
        end
    end
    captureUzumakiHealthState(player)
end

-- Alarm Seal Logic
local function getActualInventoryItem(item)
    if not item then return nil end
    if item.items and item.items[1] then return item.items[1] end
    return item
end

local function getSquareKey(square)
    if not square then return nil end
    return tostring(square:getX()) .. "," .. tostring(square:getY()) .. "," .. tostring(square:getZ())
end

local function transmitSquareModData(square)
    if not square then return end
    if square.transmitModData then
        pcall(function() square:transmitModData() end)
    elseif square.transmitModdata then
        pcall(function() square:transmitModdata() end)
    end
end

local function registerAlarmSeal(square, player)
    if not square then return end
    local owner = ""
    pcall(function() owner = player and player:getUsername() or "" end)
    local modData = square:getModData()
    modData.NinjaLineages = modData.NinjaLineages or {}
    modData.NinjaLineages.alarmSeal = {
        owner = owner,
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
    }
    transmitSquareModData(square)
    alarmSeals[getSquareKey(square)] = square
end

local function removeAlarmSeal(square)
    if not square then return end
    local modData = square:getModData()
    if modData.NinjaLineages then
        modData.NinjaLineages.alarmSeal = nil
    end
    transmitSquareModData(square)
    alarmSeals[getSquareKey(square)] = nil
end

local function placeAlarmSeal(player, square)
    if not NinjaLineages.hasUzumaki(player) then
        player:Say(getText("UI_NL_Error_LineageRequired", "Uzumaki lineage"))
        return
    end
    local cost = NinjaLineages.Balance.getCost("BASIC")
    if not NinjaLineages.Chakra.canAffordChakra(player, cost) then
        player:Say(getText("UI_NL_Error_NotEnoughChakra_PlaceAlarmSeal"))
        return
    end
    local seal = NinjaLineages.Utils.Inventory.getFirstInventoryItem(player, "Base.NL_AlarmSeal")
    if not seal then
        player:Say(getText("UI_NL_Error_NoAlarmSealItem"))
        return
    end
    if not square then square = player:getSquare() end
    NinjaLineages.Chakra.spendChakra(player, cost)
    registerAlarmSeal(square, player)
    NinjaLineages.Utils.Inventory.consumeInventoryItem(player, seal)
    player:Say(getText("UI_NL_Ability_AlarmSeal_Cast"))
    NinjaLineages.HandSigns.playSeal(player)
    return true
end

local function discoverAlarmSealsNearPlayer(player)
    if not player or not player:getSquare() then return end
    local cell = getCell()
    if not cell then return end
    local px = player:getX()
    local py = player:getY()
    local z = player:getZ()
    local radius = consts.Uzumaki.AlarmSeal.DISCOVERY_RADIUS
    for x = math.floor(px - radius), math.floor(px + radius) do
        for y = math.floor(py - radius), math.floor(py + radius) do
            local square = cell:getGridSquare(x, y, z)
            local modData = square and square:getModData()
            if modData and modData.NinjaLineages and modData.NinjaLineages.alarmSeal then
                alarmSeals[getSquareKey(square)] = square
            end
        end
    end
end

local function triggerAlarmSeal(player, square)
    removeAlarmSeal(square)
    if player and not player:isDead() then
        player:Say(getText("UI_NL_Ability_AlarmSeal_Triggered"))
    end
end

local function updateAlarmSeals(player)
    local nowMs = NinjaLineages.Utils.Time.nowGameMs(player)
    if nowMs >= nextAlarmDiscoveryAt then
        nextAlarmDiscoveryAt = nowMs + consts.Uzumaki.AlarmSeal.DISCOVERY_MS
        discoverAlarmSealsNearPlayer(player)
    end
    if nowMs < nextAlarmScanAt then return end
    nextAlarmScanAt = nowMs + consts.Uzumaki.AlarmSeal.SCAN_MS

    local zombies = getCell() and getCell():getZombieList()
    if not zombies then return end
    for key, square in pairs(alarmSeals) do
        if not square then
            alarmSeals[key] = nil
        else
            for i = 0, zombies:size() - 1 do
                local zombie = zombies:get(i)
                local dx = zombie and (zombie:getX() - (square:getX() + 0.5)) or 999
                local dy = zombie and (zombie:getY() - (square:getY() + 0.5)) or 999
                if zombie and not zombie:isDead() and ((dx * dx) + (dy * dy)) <= (consts.Uzumaki.AlarmSeal.RADIUS * consts.Uzumaki.AlarmSeal.RADIUS) then
                    triggerAlarmSeal(player, square)
                    break
                end
            end
        end
    end
end

-- Storage Seal logic
local function isSealedScrollItem(item)
    local ok, fullType = pcall(function() return item and item:getFullType() end)
    return ok and fullType == "Base.NL_SealedScroll"
end

local function isBackpackContainer(item)
    if not item or isSealedScrollItem(item) then return false end
    local okContainer, isContainer = pcall(function() return item:IsInventoryContainer() end)
    if not okContainer or not isContainer then return false end

    local okEquip, equipLocation = pcall(function() return item:canBeEquipped() end)
    if okEquip and equipLocation and tostring(equipLocation) ~= "" then return true end

    local okCategory, category = pcall(function() return item:getDisplayCategory() end)
    if okCategory and tostring(category) == "Bag" then return true end

    return false
end

local function getScrollInventory(scroll)
    local ok, inv = pcall(function() return scroll and scroll:getInventory() end)
    if ok then return inv end
    return nil
end

local function getContainedBackpack(scroll)
    local inv = getScrollInventory(scroll)
    if not inv or inv:getItems():size() == 0 then return nil end
    return inv:getItems():get(0)
end

local function sealBackpackInScroll(player, backpack, scroll)
    if not NinjaLineages.hasUzumaki(player) then
        player:Say(getText("UI_NL_Error_LineageRequired", "Uzumaki lineage"))
        return
    end
    local cost = NinjaLineages.Balance.getCost("BASIC")
    if not NinjaLineages.Chakra.canAffordChakra(player, cost) then
        player:Say(getText("UI_NL_Error_NotEnoughChakra_StorageSeal"))
        return
    end
    if not isBackpackContainer(backpack) then return end
    local scrollInv = getScrollInventory(scroll)
    if not scrollInv or scrollInv:getItems():size() > 0 then
        player:Say(getText("UI_NL_Ability_StorageSeal_AlreadySealed"))
        return
    end
    NinjaLineages.Chakra.spendChakra(player, cost)
    if not NinjaLineages.Utils.Inventory.moveItemBetweenContainers(backpack, backpack:getContainer(), scrollInv) then
        return false
    end
    player:Say(getText("UI_NL_Ability_StorageSeal_Cast"))
    NinjaLineages.HandSigns.playSeal(player)
    return true
end

NLUnsealScrollAction = ISBaseTimedAction and ISBaseTimedAction:derive("NLUnsealScrollAction") or {}

function NLUnsealScrollAction:isValid()
    return self.scroll and getContainedBackpack(self.scroll) ~= nil
end

function NLUnsealScrollAction:perform()
    local backpack = getContainedBackpack(self.scroll)
    if backpack then
        NinjaLineages.Utils.Inventory.moveItemBetweenContainers(backpack, getScrollInventory(self.scroll), self.character:getInventory())
        self.character:Say(getText("UI_NL_Ability_StorageSeal_Unsealed"))
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
    if not NinjaLineages.hasUzumaki(player) then
        player:Say(getText("UI_NL_Error_LineageRequired", "Uzumaki lineage"))
        return
    end
    local backpack = getContainedBackpack(scroll)
    if not backpack then return end
    if ISTimedActionQueue and ISBaseTimedAction then
        ISTimedActionQueue.add(NLUnsealScrollAction:new(player, scroll))
        NinjaLineages.HandSigns.playSeal(player)
    else
        if NinjaLineages.Utils.Inventory.moveItemBetweenContainers(
                backpack,
                getScrollInventory(scroll),
                player:getInventory()) then
            NinjaLineages.HandSigns.playSeal(player)
        end
    end
end

local function collectEmptyScrolls(player)
    local scrolls = {}
    local inv = player and player:getInventory()
    if not inv then return scrolls end
    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if isSealedScrollItem(item) then
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
    if not NinjaLineages.hasUzumaki(player) then return end

    local selected = nil
    if items then
        selected = getActualInventoryItem(items[1])
    end
    if not selected then return end

    if isSealedScrollItem(selected) then
        if getContainedBackpack(selected) then
            context:addOption(getText("UI_NL_Ability_StorageSeal_Unseal"), player, unsealScroll, selected)
        end
        return
    end

    if not isBackpackContainer(selected) then return end
    local scrolls = collectEmptyScrolls(player)
    if #scrolls == 0 then return end

    local option = context:addOption(getText("UI_NL_Ability_StorageSeal_Seal"))
    local subMenu = ISContextMenu:getNew(context)
    context:addSubMenu(option, subMenu)
    for _, scroll in ipairs(scrolls) do
        subMenu:addOption(scroll:getName(), player, sealBackpackInScroll, selected, scroll)
    end
end

-- Dynamic Registration
NinjaLineages.registerPlayerUpdate("uzumaki.update", function(player)
    applyUzumakiBleedSlow(player)
    updateAlarmSeals(player)
end)

NinjaLineages.registerPlayerGetDamage("uzumaki.getDamage", refundUzumakiDamage)

NinjaLineages.registerCreatePlayer("uzumaki.init", captureUzumakiHealthState)

-- Hook context menus
if Events.OnFillInventoryObjectContextMenu then
    Events.OnFillInventoryObjectContextMenu.Add(addStorageSealContextMenu)
end

if Events.OnFillWorldObjectContextMenu then
    Events.OnFillWorldObjectContextMenu.Add(function(playerNum, context, worldObjects, test)
        local player = getSpecificPlayer(playerNum)
        if not player or player:isDead() then return end
        if test then return true end

        local alarmSeal = NinjaLineages.Utils.Inventory.getFirstInventoryItem(player, "Base.NL_AlarmSeal")
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
    end)
end
