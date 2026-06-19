require "NinjaLineages_Constants"
require "NinjaLineages_Utils"

NinjaLineages = NinjaLineages or {}
NinjaLineages.BringerOfDarkness = NinjaLineages.BringerOfDarkness or {}

local BringerOfDarkness = NinjaLineages.BringerOfDarkness
local blindRecords = BringerOfDarkness.blindRecords
    or setmetatable({}, { __mode = "k" })
BringerOfDarkness.blindRecords = blindRecords

local BLIND_ITEM = NinjaLineages.Constants.GenJutsu.BringerOfDarkness.BLIND_ITEM
local BLIND_ITEMS = { BLIND_ITEM }

function BringerOfDarkness.apply(character, expiresAt)
    if not character or not expiresAt then return false end
    if character.isDead and character:isDead() then return false end

    local record = blindRecords[character]
    if record then
        record.expiresAt = math.max(record.expiresAt or 0, expiresAt)
        if record.item then
            NinjaLineages.Utils.Inventory.wearItem(character, record.item)
        end
        return true
    end

    local inventory = character:getInventory()
    if not inventory then return false end

    NinjaLineages.Utils.Inventory.removeInventoryItems(character, BLIND_ITEMS)
    local item = inventory:AddItem(BLIND_ITEM)
    if not item then return false end
    if not NinjaLineages.Utils.Inventory.wearItem(character, item) then
        NinjaLineages.Utils.Inventory.removeInventoryItems(character, BLIND_ITEMS)
        return false
    end

    blindRecords[character] = {
        expiresAt = expiresAt,
        item = item,
    }
    if instanceof(character, "IsoZombie") then
        pcall(function() character:setTarget(nil) end)
    end
    return true
end

function BringerOfDarkness.updatePlayer(player)
    if not player then return end
    local record = blindRecords[player]
    if not record then return end

    if player:isDead() or NinjaLineages.Utils.Time.gameMinutes() >= record.expiresAt then
        BringerOfDarkness.clear(player)
        return
    end
    if record.item then
        NinjaLineages.Utils.Inventory.wearItem(player, record.item)
    end
end

function BringerOfDarkness.updateZombies()
    local now = NinjaLineages.Utils.Time.gameMinutes()
    for character, record in pairs(blindRecords) do
        if instanceof(character, "IsoZombie") then
            if not character or character:isDead() or now >= record.expiresAt then
                BringerOfDarkness.clear(character)
            elseif record.item then
                NinjaLineages.Utils.Inventory.wearItem(character, record.item)
            end
        end
    end
end

function BringerOfDarkness.clear(character)
    if not character then return end
    NinjaLineages.Utils.Inventory.removeInventoryItems(character, BLIND_ITEMS)
    blindRecords[character] = nil
end
