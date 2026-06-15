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
require "NinjaLineages_RadialMenu"
require "NinjaLineages_JutsuTreeUI"

-- Load modular lineages (dynamic registries)
require "client/lineages/NinjaLineages_Uchiha"
require "client/lineages/NinjaLineages_Hyuga"
require "client/lineages/NinjaLineages_Senju"
require "client/lineages/NinjaLineages_Rinnegan"
require "client/lineages/NinjaLineages_Uzumaki"

NinjaLineages.JutsuCatalog.registerSelectableAbilities()

local consts = NinjaLineages.Constants
local lastMinuteUpdateAt = {}

local function updateChakraMoodle(player)
    local maxChakra = NinjaLineages.Chakra.getMaxChakra(player)
    local currentChakra = NinjaLineages.Chakra.getChakra(player)
    local pct = maxChakra > 0 and (currentChakra / maxChakra) or 0

    if pct < consts.Chakra.CRITICAL_THRESHOLD then
        NinjaLineages.Moodles.setValue("NLChakra", player, 0.3)
    elseif pct < consts.Chakra.LOW_THRESHOLD then
        NinjaLineages.Moodles.setValue("NLChakra", player, 0.4)
    else
        NinjaLineages.Moodles.setValue("NLChakra", player, 0.5)
    end
end

NinjaLineages.registerPlayerUpdate("chakra.moodle", updateChakraMoodle)

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

NinjaLineages.Effects = NinjaLineages.Effects or {}
NinjaLineages.Effects.getAvailableAbilities = getAvailableAbilities
NinjaLineages.Effects.selectAbility = selectAbility

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
            if NinjaLineages.Progression and NinjaLineages.Progression.requestDebugAddXP then
                local requested = NinjaLineages.Progression.requestDebugAddXP(p, 1000)
                if requested and not (isClient and isClient()) then
                    p:Say("Added 1000 Ninja XP!")
                end
            end
        end)

        -- 2. Bypass Training Toggle
        local data = NinjaLineages.getNLData(player)
        local bypassText = "Bypass Training: " .. (data and data.bypassTraining and "ON" or "OFF")
        debugSubMenu:addOption(bypassText, player, function(p)
            if NinjaLineages.Progression and NinjaLineages.Progression.requestDebugToggleBypass then
                local enabled = NinjaLineages.Progression.requestDebugToggleBypass(p)
                if not (isClient and isClient()) then
                    p:Say("Bypass Training: " .. (enabled and "Enabled" or "Disabled"))
                end
            end
        end)

        -- 3. Reveal All Disciplines
        local visibilityText = getText("UI_NL_Debug_ToggleAllVisible")
        local opt1 = debugSubMenu:addOption(visibilityText, player, function(p)
            if NinjaLineages.Progression and NinjaLineages.Progression.requestDebugSetAllVisible then
                local requested = NinjaLineages.Progression.requestDebugSetAllVisible(p)
                if requested and not (isClient and isClient()) then
                    p:Say("All Disciplines Revealed!")
                    for _, ui in pairs(NLJutsuTreeUI.instances) do
                        if ui.screen == "selection" then
                            ui:createSelectionScreen()
                        end
                    end
                end
            end
        end)
        if data and data.allDisciplinesVisible then
            opt1.enable = false
        end

        -- 4. Unlock All Disciplines
        local unlockedText = getText("UI_NL_Debug_ToggleAllUnlocked")
        local opt2 = debugSubMenu:addOption(unlockedText, player, function(p)
            if NinjaLineages.Progression and NinjaLineages.Progression.requestDebugSetAllUnlocked then
                local requested = NinjaLineages.Progression.requestDebugSetAllUnlocked(p)
                if requested and not (isClient and isClient()) then
                    p:Say("All Disciplines Unlocked!")
                    for _, ui in pairs(NLJutsuTreeUI.instances) do
                        if ui.screen == "selection" then
                            ui:createSelectionScreen()
                        end
                    end
                end
            end
        end)
        if data and data.allDisciplinesUnlocked then
            opt2.enable = false
        end

        -- 5. Unlock Mangekyo (moved from Uchiha)
        if NinjaLineages.Uchiha and NinjaLineages.Uchiha.canUseKamuiTestUnlock and NinjaLineages.Uchiha.canUseKamuiTestUnlock(player) then
            debugSubMenu:addOption(getText("UI_NL_Ability_Kamui_TestUnlock"), player, NinjaLineages.Uchiha.unlockKamuiForSinglePlayerTest)
        end
    end
end

local function onDebugServerCommand(module, command, args)
    if module ~= "NinjaLineages" or command ~= "debugResult" then return end
    local player = getSpecificPlayer(0)
    if not player then return end

    if not args or args.ok ~= true then
        player:Say("Ninja Lineages debug command denied.")
    elseif args.action == "addXP" then
        player:Say("Added " .. tostring(args.amount or 0) .. " Ninja XP!")
    elseif args.action == "toggleBypass" then
        player:Say("Bypass Training: " .. (args.enabled and "Enabled" or "Disabled"))
    elseif args.action == "toggleAllVisible" then
        player:Say("All Disciplines Revealed!")
        for _, ui in pairs(NLJutsuTreeUI.instances) do
            if ui.screen == "selection" then
                ui:createSelectionScreen()
            end
        end
    elseif args.action == "toggleAllUnlocked" then
        player:Say("All Disciplines Unlocked!")
        for _, ui in pairs(NLJutsuTreeUI.instances) do
            if ui.screen == "selection" then
                ui:createSelectionScreen()
            end
        end
    end
end

Events.OnServerCommand.Add(onDebugServerCommand)

local function onKeyStartPressed(key)
    local player = getSpecificPlayer(0)
    if not player or player:isDead() then return end

    if NinjaLineages.HandSigns.handleKey(player, key) then return end

    if getCore():isKey("Ninja Ability", key) then
        useSelectedAbility(player)
        return
    end

    if getCore():isKey("Ninja Ability Radial", key) then
        if NinjaLineages.RadialMenu and NinjaLineages.RadialMenu.showAbilityRadial then
            NinjaLineages.RadialMenu.showAbilityRadial(player)
        end
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

local function updatePlayerMinute(player)
    if not player or player:isDead() then return end
    local now = NinjaLineages.Utils.Time.gameMinutes()
    local elapsed = math.max(0, now - (lastMinuteUpdateAt[player] or (now - 1)))
    lastMinuteUpdateAt[player] = now
    if elapsed <= 0 then return end

    if not (isClient and isClient()) then
        NinjaLineages.AbilityAuthority.everyMinute(player)
    end

    runListeners(NinjaLineages.EveryMinuteListeners, "EveryMinute", player, elapsed)
end

local function everyOneMinute()
    if not (isClient and isClient()) then
        NinjaLineages.AbilityAuthority.updateAlarmSeals()
    end
    if getNumActivePlayers and getSpecificPlayer then
        for playerIndex = 0, getNumActivePlayers() - 1 do
            updatePlayerMinute(getSpecificPlayer(playerIndex))
        end
    else
        updatePlayerMinute(getPlayer())
    end
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
