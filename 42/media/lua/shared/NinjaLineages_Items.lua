require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "NinjaLineages_Chakra"
require "NinjaLineages_Progression"
require "NinjaLineages_RareScrolls"
require "disciplines/NinjaLineages_ScrollUtils"

NinjaLineages = NinjaLineages or {}
AcceptItemFunction = AcceptItemFunction or {}
RecipeCodeOnTest = RecipeCodeOnTest or {}

function RecipeCodeOnTest.NinjaLineagesUzumakiOnly(recipe, player)
    if not player then
        pcall(function()
            if getPlayer then player = getPlayer() end
        end)
        if not player then
            pcall(function()
                if getSpecificPlayer then player = getSpecificPlayer(0) end
            end)
        end
    end
    if not player then return false end
    
    local name = ""
    if type(recipe) == "userdata" and recipe.getName then
        name = recipe:getName()
    elseif type(recipe) == "string" then
        name = recipe
    end

    if string.find(name, "AlarmSeal") then
        return NinjaLineages.Progression.isCompleted(player, "alarm_seal")
    end
    return NinjaLineages.Progression.isCompleted(player, "storage_seal")
end

local BINGO_BOOK_RECIPES = {
    "MakeNLBingoBook",
    "MakeNLBingoBookFromPaper",
}
local bingoBookRecipesUnlocked = setmetatable({}, { __mode = "k" })

local function unlockBingoBookRecipesAtKage(player)
    if not player then return end
    if bingoBookRecipesUnlocked[player] then return end
    if NinjaLineages.Progression.getNinjaRank(player) ~= "KAGE" then return end
    for _, recipeName in ipairs(BINGO_BOOK_RECIPES) do
        local known = false
        pcall(function() known = player:isRecipeActuallyKnown(recipeName) end)
        if not known then pcall(function() player:learnRecipe(recipeName) end) end
    end
    bingoBookRecipesUnlocked[player] = true
end

NinjaLineages.registerCreatePlayer("items.unlockBingoBookRecipes", unlockBingoBookRecipesAtKage)
NinjaLineages.registerPlayerUpdate("items.unlockBingoBookRecipes", unlockBingoBookRecipesAtKage)

-- (NinjaLineages.ScrollUtils.isSealedScroll now in NinjaLineages.ScrollUtils)

function AcceptItemFunction.NinjaLineagesSealedScroll(container, item)
    if not container or not item then return false end
    if container:getItems():size() >= 1 then return false end
    if NinjaLineages.ScrollUtils.isSealedScroll(item) then return false end
    local ok, isContainer = pcall(function() return item:IsInventoryContainer() end)
    if not ok or isContainer ~= true then return false end

    local okEquip, equipLocation = pcall(function() return item:canBeEquipped() end)
    if okEquip and equipLocation and tostring(equipLocation) ~= "" then return true end

    local okCategory, category = pcall(function() return item:getDisplayCategory() end)
    return okCategory and tostring(category) == "Bag"
end
