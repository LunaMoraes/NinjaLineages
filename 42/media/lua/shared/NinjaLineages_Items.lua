require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "NinjaLineages_Chakra"
require "NinjaLineages_Progression"
require "NinjaLineages_RareScrolls"
require "disciplines/NinjaLineages_ScrollUtils"

NinjaLineages = NinjaLineages or {}
AcceptItemFunction = AcceptItemFunction or {}
RecipeCodeOnTest = RecipeCodeOnTest or {}

-- Register custom ammunition types into Build 42's Registries.AMMO_TYPE
local function registerCustomAmmoTypes()
    if not AmmoType or not AmmoType.register or not AmmoType.get or not ResourceLocation or not ResourceLocation.of then return end
    local kunaiLoc = ResourceLocation.of("ninjalineages:kunai_ammo")
    if not AmmoType.get(kunaiLoc) then
        pcall(function() AmmoType.register("ninjalineages:kunai_ammo", "Base.NL_KunaiAmmo") end)
    end
    local shurikenLoc = ResourceLocation.of("ninjalineages:shuriken_ammo")
    if not AmmoType.get(shurikenLoc) then
        pcall(function() AmmoType.register("ninjalineages:shuriken_ammo", "Base.NL_ShurikenAmmo") end)
    end
end

registerCustomAmmoTypes()

local function ensureShooterAmmoTypes()
    registerCustomAmmoTypes()
    if not ScriptManager or not ScriptManager.instance then return end

    local kunaiAmmo = AmmoType and AmmoType.get and AmmoType.get(ResourceLocation.of("ninjalineages:kunai_ammo"))
    local shurikenAmmo = AmmoType and AmmoType.get and AmmoType.get(ResourceLocation.of("ninjalineages:shuriken_ammo"))

    local kunaiShooter = ScriptManager.instance:FindItem("Base.NL_KunaiShooter")
    if kunaiShooter then
        if kunaiAmmo then pcall(function() kunaiShooter:setAmmoType(kunaiAmmo) end) end
        pcall(function() kunaiShooter:resolveItemTypes() end)
    end

    local shurikenShooter = ScriptManager.instance:FindItem("Base.NL_ShurikenShooter")
    if shurikenShooter then
        if shurikenAmmo then pcall(function() shurikenShooter:setAmmoType(shurikenAmmo) end) end
        pcall(function() shurikenShooter:resolveItemTypes() end)
    end
end

if Events then
    NinjaLineages.addEventOnce("shared.items.onGameBoot.ammoTypes", Events.OnGameBoot, ensureShooterAmmoTypes)
    NinjaLineages.addEventOnce("shared.items.onInitGlobalModData.ammoTypes", Events.OnInitGlobalModData, ensureShooterAmmoTypes)
end

NinjaLineages.registerCreatePlayer("items.ensureShooterAmmoTypes", ensureShooterAmmoTypes)

-- Recipe test condition for Uzumaki Fuinjutsu seal crafting recipes (NinjaLineages_recipes.txt).
-- Gated on progression node completion: 'alarm_seal' or 'storage_seal'.
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

RecipeCodeOnTest.NinjaLineagesSealCraftable = RecipeCodeOnTest.NinjaLineagesUzumakiOnly

function RecipeCodeOnTest.NinjaLineagesNinjaToolOnly(recipe, player)
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
    return NinjaLineages.Progression.isCompleted(player, "ninja_tool_crafting")
end

function RecipeCodeOnTest.NinjaLineagesKunaiOnly(recipe, player)
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
    return NinjaLineages.Progression.isCompleted(player, "kunai_crafting")
end

function RecipeCodeOnTest.NinjaLineagesShurikenOnly(recipe, player)
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
    return NinjaLineages.Progression.isCompleted(player, "shuriken_crafting")
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
