require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "NinjaLineages_Items"
require "NinjaLineages_CreationRebirthScroll"
require "NinjaLineages_Chakra"
require "NinjaLineages_Skills"
require "NinjaLineages_Moodles"
require "NinjaLineages_UI"
require "NinjaLineages_HandSigns"
require "NinjaLineages_AbilityExecution"
require "NinjaLineages_JutsuCatalog"
require "NinjaLineages_Meditation"
require "NinjaLineages_Training"
require "NinjaLineages_TreePassives"
require "NinjaLineages_ChakraBandage"
require "NinjaLineages_JutsuTreeUI"

-- Load modular lineages (dynamic registries)
require "client/lineages/NinjaLineages_Uchiha"
require "client/lineages/NinjaLineages_Hyuga"
require "client/lineages/NinjaLineages_Senju"
require "client/lineages/NinjaLineages_Rinnegan"
require "client/lineages/NinjaLineages_Uzumaki"

NinjaLineages.JutsuCatalog.registerSelectableAbilities()

local consts = NinjaLineages.Constants

-- Ability selection logic
local function getAvailableAbilities(player)
    local abilities = {}
    for _, ability in ipairs(NinjaLineages.HandSigns.getAvailableAbilities(player)) do
            local displayName = ability.name
            if type(displayName) == "string" and displayName:sub(1, 3) == "UI_" then
                displayName = getText(displayName)
                if displayName == ability.name then displayName = ability.nameFallback or ability.id end
            end
            local copy = {}
            for k, v in pairs(ability) do
                copy[k] = v
            end
            copy.name = displayName
            table.insert(abilities, copy)
    end
    return abilities
end

local function getSelectedAbility(player, abilities)
    NinjaLineages.JutsuCatalog.migratePlayerData(player)
    local data = NinjaLineages.getNLData(player)
    for _, ability in ipairs(abilities) do
        if data.selectedAbilityId == ability.id
                and (not NinjaLineages.HandSigns.isClassic() or ability.sealFree) then
            return ability
        end
    end
    local fallback = nil
    for _, ability in ipairs(abilities) do
        if not NinjaLineages.HandSigns.isClassic() or ability.sealFree then
            fallback = ability
            break
        end
    end
    if fallback and data.selectedAbilityId ~= fallback.id then
        data.selectedAbilityId = fallback.id
        NinjaLineages.transmitPlayerData(player)
    end
    return fallback
end

local function selectAbility(player, ability)
    if not ability then return end
    if NinjaLineages.HandSigns.isClassic() and not ability.sealFree then
        player:Say(getText("UI_NL_HandSigns_ClassicDisabled"))
        return
    end
    local data = NinjaLineages.getNLData(player)
    data.selectedAbilityId = ability.id
    NinjaLineages.transmitPlayerData(player)
    player:Say(getText("UI_NL_Ability_Selected", ability.name))
end

local function useSelectedAbility(player)
    local abilities = getAvailableAbilities(player)
    if #abilities == 0 then
        player:Say(getText("UI_NL_Error_NoAbilityAvailable"))
        return
    end
    local ability = getSelectedAbility(player, abilities)
    NinjaLineages.HandSigns.activateAbility(player, ability)
end

local function addAbilityContextMenu(playerNum, context, worldObjects, test)
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end
    if test then return true end

    local subMenu = NinjaLineages.UI.getOrCreateWorldSubMenu(context)

    -- Meditate
    subMenu:addOption(getText("UI_NL_MeditateOption"), player, function(p)
        ISTimedActionQueue.add(NLMeditationAction:new(p))
    end)
    subMenu:addOption(getText("UI_NL_OpenJutsuTree"), player, NLJutsuTreeUI.open)

    -- Debug Menu
    if SandboxVars and SandboxVars.NinjaLineages and SandboxVars.NinjaLineages.DebugMode == true then
        local debugOption = subMenu:addOption(getText("UI_NL_DebugMenu"))
        local debugSubMenu = ISContextMenu:getNew(subMenu)
        subMenu:addSubMenu(debugOption, debugSubMenu)

        -- 1. Add 1000 Ninja XP
        debugSubMenu:addOption(getText("UI_NL_Debug_AddXP"), player, function(p)
            if NinjaLineages.Progression and NinjaLineages.Progression.setNinjaXP then
                local current = NinjaLineages.Progression.getNinjaXP(p)
                NinjaLineages.Progression.setNinjaXP(p, current + 1000)
                p:Say("Added 1000 Ninja XP!")
            end
        end)

        -- 2. Bypass Training Toggle
        local data = NinjaLineages.getNLData(player)
        local bypassText = "Bypass Training: " .. (data and data.bypassTraining and "ON" or "OFF")
        debugSubMenu:addOption(bypassText, player, function(p)
            local d = NinjaLineages.getNLData(p)
            if d then
                d.bypassTraining = not d.bypassTraining
                NinjaLineages.transmitPlayerData(p)
                p:Say("Bypass Training: " .. (d.bypassTraining and "Enabled" or "Disabled"))
            end
        end)

        -- 3. Unlock Mangekyo (moved from Uchiha)
        if NinjaLineages.Uchiha and NinjaLineages.Uchiha.canUseKamuiTestUnlock and NinjaLineages.Uchiha.canUseKamuiTestUnlock(player) then
            debugSubMenu:addOption(getText("UI_NL_Ability_Kamui_TestUnlock"), player, NinjaLineages.Uchiha.unlockKamuiForSinglePlayerTest)
        end
    end
end

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
        local command = selectAbility
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
    local abilities = getAvailableAbilities(player)
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
        local discId = nil
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
            local icon = getTexture(list[1].texture) or getTexture(list[1].fallbackTexture)
            menu:addSlice(discName, icon, function(p)
                showCategoryRadial(p, discId, list)
            end, player)
        end
    end

    for _, ability in ipairs(lineageAbilities) do
        local sequence = NinjaLineages.HandSigns.formatSequence(ability)
        local text = ability.name .. "\n" .. sequence
        local command = selectAbility
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

local function onKeyStartPressed(key)
    local player = getSpecificPlayer(0)
    if not player or player:isDead() then return end

    if NinjaLineages.HandSigns.handleKey(player, key) then return end

    if getCore():isKey("Ninja Ability", key) then
        useSelectedAbility(player)
        return
    end

    if getCore():isKey("Ninja Ability Radial", key) then
        showAbilityRadial(player)
    end
end

local function isEyeCovered(player)
    local wornItems = player:getWornItems()
    if not wornItems then return false end
    for i = 0, wornItems:size() - 1 do
        local wornItem = wornItems:getItemByIndex(i)
        if wornItem then
            local location = wornItem:getBodyLocation()
            local fullType = wornItem:getFullType()
            if (location == "lefteye" or location == "righteye") and fullType ~= "Base.NL_ByakuganSight" then
                return true
            end
        end
    end
    return false
end
NinjaLineages.isEyeCovered = isEyeCovered

local function runListeners(registry, kind, ...)
    for _, item in ipairs(registry) do
        if type(item) == "function" then
            NinjaLineages.safeCall(kind, "anonymous", item, ...)
        elseif type(item) == "table" then
            NinjaLineages.safeCall(kind, item.id, item.fn, ...)
        end
    end
end

-- Central Event Routing
local function onPlayerUpdate(player)
    if not player then return end
    if not player:isLocalPlayer() then return end

    if player:getPlayerNum() == 0 then
        NinjaLineages.Utils.Time.advanceGameplayClock(player)
    end

    runListeners(NinjaLineages.PlayerUpdates, "PlayerUpdate", player)

    NinjaLineages.HandSigns.update(player)
    NinjaLineages.AbilityAuthority.updatePending()
    if not (isClient and isClient()) then
        NinjaLineages.AbilityAuthority.updatePlayer(player)
        if player:getPlayerNum() == 0 then NinjaLineages.AbilityAuthority.updateWorld() end
    end
end

local function onZombieUpdate(zombie)
    runListeners(NinjaLineages.ZombieUpdates, "ZombieUpdate", zombie)
end

local function onHitZombie(zombie, attacker, bodyPartType, handWeapon)
    runListeners(NinjaLineages.HitZombieListeners, "HitZombie", zombie, attacker, bodyPartType, handWeapon)
end

local function onPlayerGetDamage(player, damageType, damage)
    if not player or not instanceof(player, "IsoPlayer") then return end
    if not player:isLocalPlayer() then return end

    runListeners(NinjaLineages.PlayerGetDamageListeners, "PlayerGetDamage", player, damageType, damage)
end

local function everyOneMinute()
    local player = getPlayer()
    if not player or player:isDead() then return end

    local maxChakra = NinjaLineages.Chakra.getMaxChakra(player)
    local currentChakra = NinjaLineages.Chakra.getChakra(player)
    if not (isClient and isClient()) then
        NinjaLineages.AbilityAuthority.everyMinute(player)
        currentChakra = NinjaLineages.Chakra.getChakra(player)
    end
    local pct = currentChakra / maxChakra
    if pct < consts.Chakra.CRITICAL_THRESHOLD then
        NinjaLineages.Moodles.setValue("NLChakra", player, 0.3) -- Bad lvl 2 (Very Low)
    elseif pct < consts.Chakra.LOW_THRESHOLD then
        NinjaLineages.Moodles.setValue("NLChakra", player, 0.4) -- Bad lvl 1 (Low)
    else
        NinjaLineages.Moodles.setValue("NLChakra", player, 0.5) -- Hidden
    end

    runListeners(NinjaLineages.EveryMinuteListeners, "EveryMinute", player)
end

local function initKeybinds()
    table.insert(keyBinding, { value = "[Ninja Lineages]" })
    table.insert(keyBinding, { value = "Ninja Ability", key = Keyboard.KEY_NONE })
    table.insert(keyBinding, { value = "Ninja Ability Radial", key = Keyboard.KEY_NONE })
end

Events.OnCreatePlayer.Add(function(playerIndex, player)
    if player then
        runListeners(NinjaLineages.CreatePlayerListeners, "CreatePlayer", player)
    end
end)

Events.OnGameBoot.Add(initKeybinds)
Events.OnPlayerUpdate.Add(onPlayerUpdate)
Events.OnZombieUpdate.Add(onZombieUpdate)
Events.OnHitZombie.Add(onHitZombie)
Events.OnFillWorldObjectContextMenu.Add(addAbilityContextMenu)
Events.OnKeyStartPressed.Add(onKeyStartPressed)
Events.OnPlayerGetDamage.Add(onPlayerGetDamage)
Events.EveryOneMinute.Add(everyOneMinute)
