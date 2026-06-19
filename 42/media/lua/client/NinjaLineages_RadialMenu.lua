require "NinjaLineages_TreeDefinitions"
require "NinjaLineages_HandSigns"

NinjaLineages = NinjaLineages or {}
NinjaLineages.RadialMenu = NinjaLineages.RadialMenu or {}

local showAbilityRadial = nil
local showCategoryRadial = nil

showCategoryRadial = function(player, disciplineId, list)
    local menu = getPlayerRadialMenu(player:getPlayerNum())
    menu:clear()

    menu:setX(getPlayerScreenLeft(player:getPlayerNum()) + getPlayerScreenWidth(player:getPlayerNum()) / 2 - menu:getWidth() / 2)
    menu:setY(getPlayerScreenTop(player:getPlayerNum()) + getPlayerScreenHeight(player:getPlayerNum()) / 2 - menu:getHeight() / 2)

    menu:addSlice(getText("UI_NL_Tree_Back") or "Back", getTexture("media/ui/NLJutsu.png"), function(p)
        showAbilityRadial(p)
    end, player)

    for _, ability in ipairs(list) do
        local sequence = NinjaLineages.HandSigns.formatSequence(ability)
        local text = ability.name .. "\n" .. sequence
        local command = NinjaLineages.Effects.selectAbility
        if NinjaLineages.HandSigns.isClassic() and not ability.sealFree then
            text = text .. "\n" .. getText("UI_NL_HandSigns_ClassicDisabled")
            command = nil
        end
        menu:addSlice(
            text,
            getTexture(ability.texture) or getTexture(ability.fallbackTexture),
            command,
            player,
            ability
        )
    end

    menu:addToUIManager()
end

showAbilityRadial = function(player)
    local abilities = NinjaLineages.Effects.getAvailableAbilities(player)
    if #abilities < 2 then return false end

    local menu = getPlayerRadialMenu(player:getPlayerNum())
    menu:clear()
    if menu:isReallyVisible() then
        if menu.joyfocus then
            setJoypadFocus(player:getPlayerNum(), nil)
        end
        menu:undisplay()
        return true
    end

    local lineageAbilities = {}
    local categorized = {}
    local disciplines = NinjaLineages.TreeDefinitions.Disciplines
    local disciplineOrder = NinjaLineages.TreeDefinitions.DisciplineOrder or {
        "genjutsu", "ninjutsu", "taijutsu", "kenjutsu", "medical", "fuinjutsu", "chakra_transformation"
    }

    for _, discId in ipairs(disciplineOrder) do
        categorized[discId] = {}
    end

    for _, ability in ipairs(abilities) do
        local discId = ability.discipline
        if ability.nodeId then
            local node = NinjaLineages.TreeDefinitions.getNode(ability.nodeId)
            if node and node.discipline then
                discId = node.discipline
            end
        end

        if discId and categorized[discId] then
            table.insert(categorized[discId], ability)
        else
            table.insert(lineageAbilities, ability)
        end
    end

    menu:setX(getPlayerScreenLeft(player:getPlayerNum()) + getPlayerScreenWidth(player:getPlayerNum()) / 2 - menu:getWidth() / 2)
    menu:setY(getPlayerScreenTop(player:getPlayerNum()) + getPlayerScreenHeight(player:getPlayerNum()) / 2 - menu:getHeight() / 2)

    for _, discId in ipairs(disciplineOrder) do
        local list = categorized[discId]
        if #list > 0 then
            local def = disciplines[discId]
            local discName = def and def.name and getText(def.name) or discId
            local icon = getTexture("media/ui/jutsuTree/nodes/" .. discId .. ".png") or getTexture(list[1].fallbackTexture)
            menu:addSlice(discName, icon, function(p)
                showCategoryRadial(p, discId, list)
            end, player)
        end
    end

    for _, ability in ipairs(lineageAbilities) do
        local sequence = NinjaLineages.HandSigns.formatSequence(ability)
        local text = ability.name .. "\n" .. sequence
        local command = NinjaLineages.Effects.selectAbility
        if NinjaLineages.HandSigns.isClassic() and not ability.sealFree then
            text = text .. "\n" .. getText("UI_NL_HandSigns_ClassicDisabled")
            command = nil
        end
        menu:addSlice(
            text,
            getTexture(ability.texture) or getTexture(ability.fallbackTexture),
            command,
            player,
            ability
        )
    end

    menu:addToUIManager()
    getSoundManager():playUISound("UIVehicleMenuOpen")
    menu.sounds.undisplay = "UIVehicleMenuClose"
    return true
end

NinjaLineages.RadialMenu.showAbilityRadial = showAbilityRadial
NinjaLineages.RadialMenu.showCategoryRadial = showCategoryRadial
