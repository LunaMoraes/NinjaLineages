NinjaLineages = NinjaLineages or {}
NinjaLineages.UI = NinjaLineages.UI or {}

function NinjaLineages.UI.getOrCreateWorldSubMenu(context)
    if not context then return nil end
    local option = nil
    if context.options then
        for _, existingOption in ipairs(context.options) do
            if existingOption.name == getText("UI_NL_ShinobiTrainingMenu") then
                option = existingOption
                break
            end
        end
    end

    local subMenu = nil
    if option then
        subMenu = option.subOption and context:getSubMenu(option.subOption) or nil
    end
    if not option or not subMenu then
        option = context:addOption(getText("UI_NL_ShinobiTrainingMenu"))
        subMenu = ISContextMenu:getNew(context)
        context:addSubMenu(option, subMenu)
    end
    return subMenu
end

function NinjaLineages.UI.getOrCreateSubMenu(context, label)
    if not context or not label then return nil end
    local option = nil
    if context.options then
        for _, existingOption in ipairs(context.options) do
            if existingOption.name == label then
                option = existingOption
                break
            end
        end
    end

    local subMenu = nil
    if option then
        subMenu = option.subOption and context:getSubMenu(option.subOption) or nil
    end
    if not option or not subMenu then
        option = context:addOption(label)
        subMenu = ISContextMenu:getNew(context)
        context:addSubMenu(option, subMenu)
    end
    return subMenu
end
