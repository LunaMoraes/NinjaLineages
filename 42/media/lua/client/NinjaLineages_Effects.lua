require "NinjaLineages_Traits"
require "NinjaLineages_Items"
require "NinjaLineages_Chakra"
require "NinjaLineages_Skills"
require "NinjaLineages_CommonJutsu"
require "NinjaLineages_Meditation"

-- Load modular lineages (dynamic registries)
require "client/lineages/NinjaLineages_Uchiha"
require "client/lineages/NinjaLineages_Hyuga"
require "client/lineages/NinjaLineages_Senju"
require "client/lineages/NinjaLineages_Rinnegan"
require "client/lineages/NinjaLineages_Uzumaki"

pcall(require, "MF_ISMoodle")
pcall(require, "ISUI/ISContextMenu")
pcall(require, "ISUI/ISRadialMenu")
pcall(require, "TimedActions/ISBaseTimedAction")
pcall(require, "TimedActions/ISTimedActionQueue")

if MF and MF.createMoodle then
    MF.createMoodle("NLSharinganTomoe")
    MF.createMoodle("NLKamuiVision")
    MF.createMoodle("NLChakra")
end

local MOODLE_BAD = 2
local MOODLE_TEXT = {
    NLChakra = {
        [MOODLE_BAD] = {
            [1] = { "Low Chakra", "Your chakra is low (<30%). Consider meditating." },
            [2] = { "Very Low Chakra", "Your chakra is critical (<10%). Sustained powers will fail soon." },
        },
    },
}

local function setMoodleValue(name, player, value)
    if not MF or not MF.getMoodle then return end
    local playerNum = player:getPlayerNum()
    local ok, moodle = pcall(function() return MF.getMoodle(name, playerNum) end)
    if ok and moodle then
        local text = MOODLE_TEXT[name]
        if text and not moodle.NinjaLineagesTextConfigured then
            for moodleType, levels in pairs(text) do
                for level, moodleText in pairs(levels) do
                    pcall(function() moodle:setTitle(moodleType, level, moodleText[1]) end)
                    pcall(function() moodle:setDescription(moodleType, level, moodleText[2]) end)
                end
            end
            moodle.NinjaLineagesTextConfigured = true
        end
        moodle:setValue(value)
    end
end

-- Ability selection logic
local function getAvailableAbilities(player)
    local abilities = {}
    for _, ability in ipairs(NinjaLineages.Abilities) do
        if ability.condition(player) then
            table.insert(abilities, ability)
        end
    end
    -- Common Jutsus (always available)
    table.insert(abilities, { id = "healing", name = getText("UI_NL_HealingJutsu"), action = NinjaLineages.CommonJutsu.castHealing, texture = "media/ui/NLJutsu.png" })
    table.insert(abilities, { id = "reinforcement", name = getText("UI_NL_ReinforcementJutsu"), action = NinjaLineages.CommonJutsu.castReinforcement, texture = "media/ui/NLJutsu.png" })
    table.insert(abilities, { id = "quietstep", name = getText("UI_NL_QuietStepJutsu"), action = NinjaLineages.CommonJutsu.castQuietStep, texture = "media/ui/NLJutsu.png" })
    table.insert(abilities, { id = "focus", name = getText("UI_NL_FocusJutsu"), action = NinjaLineages.CommonJutsu.castChakraFocus, texture = "media/ui/NLJutsu.png" })
    table.insert(abilities, { id = "grip", name = getText("UI_NL_GripJutsu"), action = NinjaLineages.CommonJutsu.castChakraGrip, texture = "media/ui/NLJutsu.png" })
    table.insert(abilities, { id = "bodyflicker", name = getText("UI_NL_BodyFlickerJutsu"), action = NinjaLineages.CommonJutsu.castBodyFlicker, texture = "media/ui/NLJutsu.png" })
    return abilities
end

local function getSelectedAbility(player, abilities)
    local data = NinjaLineages.getNLData(player)
    for _, ability in ipairs(abilities) do
        if data.selectedAbilityId == ability.id then
            return ability
        end
    end
    local fallback = abilities[1]
    if fallback and data.selectedAbilityId ~= fallback.id then
        data.selectedAbilityId = fallback.id
        NinjaLineages.transmitPlayerData(player)
    end
    return fallback
end

local function selectAbility(player, ability)
    if not ability then return end
    local data = NinjaLineages.getNLData(player)
    data.selectedAbilityId = ability.id
    NinjaLineages.transmitPlayerData(player)
    player:Say(ability.name .. " selected")
end

local function useSelectedAbility(player)
    local abilities = getAvailableAbilities(player)
    if #abilities == 0 then
        player:Say("No ninja ability available")
        return
    end
    local ability = getSelectedAbility(player, abilities)
    if ability and ability.action then
        ability.action(player)
    end
end

local function addAbilityContextMenu(playerNum, context, worldObjects, test)
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end
    if test then return true end

    -- Find or create the common Ninja Lineages sub-context option
    local option = nil
    for i = 1, #context.options do
        if context.options[i].name == getText("UI_NL_NinjaLineagesMenu") then
            option = context.options[i]
            break
        end
    end

    local subMenu = nil
    if option then
        subMenu = context:getSubMenu(option)
    else
        option = context:addOption(getText("UI_NL_NinjaLineagesMenu"))
        subMenu = ISContextMenu:getNew(context)
        context:addSubMenu(option, subMenu)
    end

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
        menu:addSlice(ability.name, getTexture(ability.texture), selectAbility, player, ability)
    end
    menu:addToUIManager()
    getSoundManager():playUISound("UIVehicleMenuOpen")
    menu.sounds.undisplay = "UIVehicleMenuClose"
    return true
end

local function onKeyStartPressed(key)
    local player = getSpecificPlayer(0)
    if not player or player:isDead() then return end

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

-- Central Event Routing
local function onPlayerUpdate(player)
    if not player then return end
    if not player:isLocalPlayer() then return end

    for _, fn in ipairs(NinjaLineages.PlayerUpdates) do
        pcall(fn, player)
    end

    NinjaLineages.CommonJutsu.update(player)
end

local function onZombieUpdate(zombie)
    for _, fn in ipairs(NinjaLineages.ZombieUpdates) do
        pcall(fn, zombie)
    end
end

local function onHitZombie(zombie, attacker, bodyPartType, handWeapon)
    for _, fn in ipairs(NinjaLineages.HitZombieListeners) do
        pcall(fn, zombie, attacker, bodyPartType, handWeapon)
    end
end

local function onPlayerGetDamage(player, damageType, damage)
    if not player or not instanceof(player, "IsoPlayer") then return end
    if not player:isLocalPlayer() then return end

    for _, fn in ipairs(NinjaLineages.PlayerGetDamageListeners) do
        pcall(fn, player, damageType, damage)
    end
end

local function everyOneMinute()
    local player = getPlayer()
    if not player or player:isDead() then return end

    local data = NinjaLineages.getNLData(player)
    local maxChakra = NinjaLineages.Chakra.getMaxChakra(player)
    local currentChakra = NinjaLineages.Chakra.getChakra(player)

    -- 1. Chakra regeneration (2.0% of max chakra base per minute)
    local baseRegenPct = 0.02
    local regenRate = maxChakra * baseRegenPct
    if data.isMeditating then
        regenRate = regenRate * 3.0
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
            drainRate = drainRate * 0.25
        end

        if isEyeCovered(player) then
            drainRate = drainRate * 0.5
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
    if pct < 0.10 then
        setMoodleValue("NLChakra", player, 0.3) -- Bad lvl 2 (Very Low)
    elseif pct < 0.30 then
        setMoodleValue("NLChakra", player, 0.4) -- Bad lvl 1 (Low)
    else
        setMoodleValue("NLChakra", player, 0.5) -- Hidden
    end

    -- 4. Invoke lineage EveryMinute listeners
    for _, fn in ipairs(NinjaLineages.EveryMinuteListeners) do
        pcall(fn, player)
    end
end

local function initKeybinds()
    table.insert(keyBinding, { value = "[Ninja Lineages]" })
    table.insert(keyBinding, { value = "Ninja Ability", key = Keyboard.KEY_NONE })
    table.insert(keyBinding, { value = "Ninja Ability Radial", key = Keyboard.KEY_NONE })
end

Events.OnCreatePlayer.Add(function(playerIndex, player)
    if player then
        for _, fn in ipairs(NinjaLineages.CreatePlayerListeners) do
            pcall(fn, player)
        end
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
