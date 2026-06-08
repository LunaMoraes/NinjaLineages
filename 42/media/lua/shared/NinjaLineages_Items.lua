NinjaLineages = NinjaLineages or {}
AcceptItemFunction = AcceptItemFunction or {}
RecipeCodeOnTest = RecipeCodeOnTest or {}

local function hasUzumakiTrait(player)
    if not player then return false end
    local trait = NinjaLineages.CharacterTrait and NinjaLineages.CharacterTrait.UZUMAKI
    if trait and player:hasTrait(trait) then return true end

    local ok, registeredTrait = pcall(function()
        return CharacterTrait.get(ResourceLocation.of("NinjaLineages:uzumaki"))
    end)
    return ok and registeredTrait and player:hasTrait(registeredTrait)
end

function RecipeCodeOnTest.NinjaLineagesUzumakiOnly(item, result)
    local player = nil
    pcall(function()
        if getPlayer then player = getPlayer() end
    end)
    if not player then
        pcall(function()
            if getSpecificPlayer then player = getSpecificPlayer(0) end
        end)
    end
    return hasUzumakiTrait(player)
end

local function isSealedScroll(item)
    local ok, fullType = pcall(function() return item and item:getFullType() end)
    return ok and fullType == "Base.NL_SealedScroll"
end

function AcceptItemFunction.NinjaLineagesSealedScroll(container, item)
    if not container or not item then return false end
    if container:getItems():size() >= 1 then return false end
    if isSealedScroll(item) then return false end
    local ok, isContainer = pcall(function() return item:IsInventoryContainer() end)
    if not ok or isContainer ~= true then return false end

    local okEquip, equipLocation = pcall(function() return item:canBeEquipped() end)
    if okEquip and equipLocation and tostring(equipLocation) ~= "" then return true end

    local okCategory, category = pcall(function() return item:getDisplayCategory() end)
    return okCategory and tostring(category) == "Bag"
end
