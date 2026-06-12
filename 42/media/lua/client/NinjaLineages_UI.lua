NinjaLineages = NinjaLineages or {}
NinjaLineages.UI = NinjaLineages.UI or {}

function NinjaLineages.UI.getOrCreateWorldSubMenu(context)
    if not context then return nil end
    local option = nil
    for i = 1, #context.options do
        if context.options[i].name == getText("UI_NL_ShinobiTrainingMenu") then
            option = context.options[i]
            break
        end
    end

    local subMenu = nil
    if option then
        subMenu = context:getSubMenu(option)
    else
        option = context:addOption(getText("UI_NL_ShinobiTrainingMenu"))
        subMenu = ISContextMenu:getNew(context)
        context:addSubMenu(option, subMenu)
    end
    return subMenu
end
