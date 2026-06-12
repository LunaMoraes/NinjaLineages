require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "NinjaLineages_Items"
require "NinjaLineages_CreationRebirthScroll"
require "NinjaLineages_Chakra"
require "NinjaLineages_Skills"
require "NinjaLineages_Moodles"
require "NinjaLineages_UI"
require "NinjaLineages_CommonJutsu"
require "NinjaLineages_HandSigns"
require "NinjaLineages_Meditation"

-- Load modular lineages (dynamic registries)
require "client/lineages/NinjaLineages_Uchiha"
require "client/lineages/NinjaLineages_Hyuga"
require "client/lineages/NinjaLineages_Senju"
require "client/lineages/NinjaLineages_Rinnegan"
require "client/lineages/NinjaLineages_Uzumaki"

local consts = NinjaLineages.Constants

-- Ability selection logic
local function getAvailableAbilities(player)
    local abilities = {}
    for _, ability in ipairs(NinjaLineages.HandSigns.getAvailableAbilities(player)) do
            local displayName = ability.name
            if type(displayName) == "string" and displayName:sub(1, 3) == "UI_" then
                displayName = getText(displayName)
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

local function addAbilityContextMenu(playerNum, context, worldObjects, test)
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end
    if test then return true end

    local subMenu = NinjaLineages.UI.getOrCreateWorldSubMenu(context)

    -- Meditate
    subMenu:addOption(getText("UI_NL_MeditateOption"), player, function(p)
        ISTimedActionQueue.add(NLMeditationAction:new(p))
    end)
end

local function showAbilityRadial(player)
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

    menu:setX(getPlayerScreenLeft(player:getPlayerNum()) + getPlayerScreenWidth(player:getPlayerNum()) / 2 - menu:getWidth() / 2)
    menu:setY(getPlayerScreenTop(player:getPlayerNum()) + getPlayerScreenHeight(player:getPlayerNum()) / 2 - menu:getHeight() / 2)
    for _, ability in ipairs(abilities) do
        local sequence = NinjaLineages.HandSigns.formatSequence(ability)
        local text = ability.name .. "\n" .. sequence
        local command = selectAbility
        if NinjaLineages.HandSigns.isClassic() and not ability.sealFree then
            text = text .. "\n" .. getText("UI_NL_HandSigns_ClassicDisabled")
            command = nil
        end
        menu:addSlice(text, getTexture(ability.texture), command, player, ability)
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
    NinjaLineages.CommonJutsu.update(player)
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

    local data = NinjaLineages.getNLData(player)
    local maxChakra = NinjaLineages.Chakra.getMaxChakra(player)
    local currentChakra = NinjaLineages.Chakra.getChakra(player)

    -- 1. Chakra regeneration (2.0% of max chakra base per minute)
    local baseRegenPct = consts.Chakra.BASE_REGEN_PCT_PER_MINUTE
    local regenRate = maxChakra * baseRegenPct
    if data.isMeditating then
        regenRate = regenRate * consts.Chakra.MEDITATION_REGEN_MULTIPLIER
    end

    local skillLevel = NinjaLineages.Skills.getChakraControlLevel(player)
    local skillMult = NinjaLineages.Skills.getRegenMultiplier(skillLevel)
    regenRate = regenRate * skillMult

    local newChakra = math.min(maxChakra, currentChakra + regenRate)

    -- 2. Sustained eye power chakra drains (dynamically routed)
    if data.eyePowerActive then
        local drainRate = 0.0
        if NinjaLineages.Uchiha and NinjaLineages.Uchiha.getEyePowerDrain then
            drainRate = drainRate + NinjaLineages.Uchiha.getEyePowerDrain(player, data)
        end
        if NinjaLineages.Hyuga and NinjaLineages.Hyuga.getEyePowerDrain then
            drainRate = drainRate + NinjaLineages.Hyuga.getEyePowerDrain(player, data)
        end

        local drainReduction = NinjaLineages.Skills.getDrainReduction(skillLevel)
        drainRate = drainRate * drainReduction

        if data.isMeditating then
            drainRate = drainRate * consts.Chakra.MEDITATION_DRAIN_MULTIPLIER
        end

        if isEyeCovered(player) then
            drainRate = drainRate * consts.Chakra.COVERED_EYE_DRAIN_MULTIPLIER
        end

        newChakra = math.max(0.0, newChakra - drainRate)

        if newChakra <= 0.0 then
            newChakra = 0.0
            data.eyePowerActive = false
            player:Say(getText("UI_NL_EyePowerDeactivated"))
            if NinjaLineages.Uchiha and NinjaLineages.Uchiha.onEyePowerDeactivated then
                pcall(NinjaLineages.Uchiha.onEyePowerDeactivated, player)
            end
            if NinjaLineages.Hyuga and NinjaLineages.Hyuga.onEyePowerDeactivated then
                pcall(NinjaLineages.Hyuga.onEyePowerDeactivated, player)
            end
        end
    end

    -- Save chakra
    NinjaLineages.Chakra.setChakra(player, newChakra)

    -- 3. Moodle updates
    local pct = newChakra / maxChakra
    if pct < consts.Chakra.CRITICAL_THRESHOLD then
        NinjaLineages.Moodles.setValue("NLChakra", player, 0.3) -- Bad lvl 2 (Very Low)
    elseif pct < consts.Chakra.LOW_THRESHOLD then
        NinjaLineages.Moodles.setValue("NLChakra", player, 0.4) -- Bad lvl 1 (Low)
    else
        NinjaLineages.Moodles.setValue("NLChakra", player, 0.5) -- Hidden
    end

    -- 4. Invoke lineage EveryMinute listeners
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
