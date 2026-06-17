NinjaLineages = NinjaLineages or {}
NinjaLineages.ScrollUtils = NinjaLineages.ScrollUtils or {}

local ScrollUtils = NinjaLineages.ScrollUtils

function ScrollUtils.isSealedScroll(item)
    local ok, fullType = pcall(function() return item and item:getFullType() end)
    return ok and fullType == "Base.NL_SealedScroll"
end

function ScrollUtils.isBackpackContainer(item)
    if not item or ScrollUtils.isSealedScroll(item) then return false end
    local okContainer, isContainer = pcall(function() return item:IsInventoryContainer() end)
    if not okContainer or not isContainer then return false end

    local okEquip, equipLocation = pcall(function() return item:canBeEquipped() end)
    if okEquip and equipLocation and tostring(equipLocation) ~= "" then return true end

    local okCategory, category = pcall(function() return item:getDisplayCategory() end)
    if okCategory and tostring(category) == "Bag" then return true end

    return false
end

function ScrollUtils.getScrollInventory(scroll)
    local ok, inv = pcall(function() return scroll and scroll:getInventory() end)
    if ok then return inv end
    return nil
end
