require "NinjaLineages_Traits"

pcall(require, "MF_ISMoodle")
pcall(require, "ISUI/ISContextMenu")
pcall(require, "ISUI/ISRadialMenu")

if MF and MF.createMoodle then
    MF.createMoodle("NLSharinganTomoe")
    MF.createMoodle("NLKamuiVision")
end

local SENJU_ENDURANCE_RECOVERY_PER_SECOND = 0.01
local KAMUI_DURATION_MS = 10000
local KAMUI_ENDURANCE_MIN = 0.20
local KAMUI_ENDURANCE_DRAIN_PER_SECOND = 0.08
local KAMUI_COOLDOWN_SECONDS = 240
local SHINRA_COOLDOWN_SECONDS = 15
local SHINRA_RADIUS = 4.0
local SHINRA_BASE_ENDURANCE_COST = 0.35
local SHINRA_ENDURANCE_COST_PER_ZOMBIE = 0.03
local SHINRA_ENDURANCE_COST_CAP = 0.75
local VISION_RECOVERY_HOURS = { 1, 6, 24 }
local VISION_ITEMS = {
    "Base.NL_KamuiVision_L1",
    "Base.NL_KamuiVision_L2",
    "Base.NL_KamuiVision_L3",
}

local sharinganAttackRolls = {}
local senjuLastRecoveryAt = {}
local kamuiState = {}

local function getByakuganTrait()
    return NinjaLineages.CharacterTrait
        and NinjaLineages.CharacterTrait.BYAKUGAN
end

local function getSharinganTrait()
    return NinjaLineages.CharacterTrait
        and NinjaLineages.CharacterTrait.SHARINGAN
end

local function getSenjuTrait()
    return NinjaLineages.CharacterTrait
        and NinjaLineages.CharacterTrait.SENJU
end

local function getRinneganTrait()
    return NinjaLineages.CharacterTrait
        and NinjaLineages.CharacterTrait.RINNEGAN
end

local function getNLData(player)
    local modData = player:getModData()
    modData.NinjaLineages = modData.NinjaLineages or {}
    return modData.NinjaLineages
end

local function transmitPlayerData(player)
    if player and player.transmitModData then
        pcall(function() player:transmitModData() end)
    end
end

local function getTimestampSeconds()
    if getTimestamp then return getTimestamp() end
    return math.floor(getTimestampMs() / 1000)
end

local function getWorldAgeHours()
    local gameTime = getGameTime()
    if gameTime and gameTime.getWorldAgeHours then
        return gameTime:getWorldAgeHours()
    end
    return 0
end

local function hasTrait(player, trait)
    return player and trait and player:hasTrait(trait)
end

local function hasSharingan(player)
    return hasTrait(player, getSharinganTrait())
end

local function hasRinnegan(player)
    return hasTrait(player, getRinneganTrait())
end

local function getSharinganStage(player)
    if not hasSharingan(player) then return 0 end
    local kills = player:getZombieKills() or 0
    if kills >= 500 then return 3 end
    if kills >= 100 then return 2 end
    if kills >= 1 then return 1 end
    return 0
end

local function getSharinganDodgeChance(player)
    local stage = getSharinganStage(player)
    if stage == 1 then return 30 end
    if stage == 2 then return 60 end
    if stage == 3 then return 90 end
    return 0
end

local function setMoodleValue(name, player, value)
    if not MF or not MF.getMoodle then return end
    local playerNum = player:getPlayerNum()
    local ok, moodle = pcall(function() return MF.getMoodle(name, playerNum) end)
    if ok and moodle then
        moodle:setValue(value)
    end
end

local function updateSharinganMoodle(player)
    local data = getNLData(player)
    if not hasSharingan(player) then
        setMoodleValue("NLSharinganTomoe", player, 0.5)
        data.lastSharinganStage = nil
        return
    end

    local stage = getSharinganStage(player)
    if data.mangekyoUnlocked then
        setMoodleValue("NLSharinganTomoe", player, 0.9)
    elseif stage == 3 then
        setMoodleValue("NLSharinganTomoe", player, 0.8)
    elseif stage == 2 then
        setMoodleValue("NLSharinganTomoe", player, 0.7)
    elseif stage == 1 then
        setMoodleValue("NLSharinganTomoe", player, 0.6)
    else
        setMoodleValue("NLSharinganTomoe", player, 0.5)
    end

    local lastStage = data.lastSharinganStage or 0
    if stage > lastStage then
        if stage == 1 then
            player:Say("Sharingan unlocked")
        elseif stage == 2 then
            player:Say("Second Tomoe released")
        elseif stage == 3 then
            player:Say("Third Tomoe released")
        end
        data.lastSharinganStage = stage
        transmitPlayerData(player)
    elseif stage < lastStage then
        data.lastSharinganStage = stage
        transmitPlayerData(player)
    end
end

local function getWornItemByType(player, itemTypes)
    local wornItems = player:getWornItems()
    if not wornItems then return nil end
    for i = 0, wornItems:size() - 1 do
        local wornItem = wornItems:getItemByIndex(i)
        if wornItem then
            local fullType = wornItem:getFullType()
            local typeName = wornItem:getType()
            for _, itemType in ipairs(itemTypes) do
                if fullType == itemType or typeName == itemType:gsub("^Base%.", "") then
                    return wornItem
                end
            end
        end
    end
    return nil
end

local function getWornByakuganSight(player)
    return getWornItemByType(player, { "Base.NL_ByakuganSight" })
end

local function removeInventoryItems(player, itemTypes)
    local inv = player:getInventory()
    if not inv then return end
    for _, itemType in ipairs(itemTypes) do
        local item = inv:getItemFromType(itemType)
        while item do
            inv:Remove(item)
            item = inv:getItemFromType(itemType)
        end
    end
end

local function applyByakugan(player)
    if not player then return end
    local byakuganTrait = getByakuganTrait()
    if not byakuganTrait then return end

    if player:hasTrait(byakuganTrait) then
        local equipped = getWornByakuganSight(player)
        if not equipped then
            local inv = player:getInventory()
            if inv then
                local item = inv:getItemFromType("Base.NL_ByakuganSight")
                if not item then
                    item = inv:AddItem("Base.NL_ByakuganSight")
                end
                if item then
                    player:setWornItem(item:getBodyLocation(), item)
                end
            end
        end
        if not player:hasTrait(CharacterTrait.EAGLE_EYED) then
            player:getCharacterTraits():add(CharacterTrait.EAGLE_EYED)
        end
        if not player:hasTrait(CharacterTrait.KEEN_HEARING) then
            player:getCharacterTraits():add(CharacterTrait.KEEN_HEARING)
        end
    else
        local equipped = getWornByakuganSight(player)
        if equipped then
            player:setWornItem(equipped:getBodyLocation(), nil)
        end
        removeInventoryItems(player, { "Base.NL_ByakuganSight" })
    end
end

local function applyKamuiVisionItem(player)
    local data = getNLData(player)
    local level = data.kamuiVisionLevel or 0
    local equipped = getWornItemByType(player, VISION_ITEMS)
    local desiredType = level > 0 and VISION_ITEMS[level] or nil
    if equipped and desiredType and equipped:getFullType() == desiredType then
        if level == 1 then
            setMoodleValue("NLKamuiVision", player, 0.4)
        elseif level == 2 then
            setMoodleValue("NLKamuiVision", player, 0.3)
        else
            setMoodleValue("NLKamuiVision", player, 0.2)
        end
        return
    end

    if equipped then
        player:setWornItem(equipped:getBodyLocation(), nil)
    end

    if level <= 0 then
        removeInventoryItems(player, VISION_ITEMS)
        setMoodleValue("NLKamuiVision", player, 0.5)
        return
    end

    removeInventoryItems(player, VISION_ITEMS)
    local inv = player:getInventory()
    if not inv then return end
    local item = inv:AddItem(desiredType)
    if item then
        player:setWornItem(item:getBodyLocation(), item)
    end

    if level == 1 then
        setMoodleValue("NLKamuiVision", player, 0.4)
    elseif level == 2 then
        setMoodleValue("NLKamuiVision", player, 0.3)
    else
        setMoodleValue("NLKamuiVision", player, 0.2)
    end
end

local function recoverKamuiVision(player)
    local data = getNLData(player)
    local level = data.kamuiVisionLevel or 0
    if level <= 0 then
        data.kamuiVisionLevel = 0
        data.kamuiVisionRecoverAt = nil
        applyKamuiVisionItem(player)
        return
    end

    local now = getWorldAgeHours()
    if data.kamuiVisionRecoverAt and now >= data.kamuiVisionRecoverAt then
        level = math.max(0, level - 1)
        data.kamuiVisionLevel = level
        if level > 0 then
            data.kamuiVisionRecoverAt = now + VISION_RECOVERY_HOURS[level]
        else
            data.kamuiVisionRecoverAt = nil
        end
        transmitPlayerData(player)
    end
    applyKamuiVisionItem(player)
end

local function addKamuiVisionPenalty(player)
    local data = getNLData(player)
    local now = getWorldAgeHours()
    local level = math.min(3, (data.kamuiVisionLevel or 0) + 1)
    data.kamuiVisionLevel = level
    data.kamuiVisionRecoverAt = now + VISION_RECOVERY_HOURS[level]
    applyKamuiVisionItem(player)
    transmitPlayerData(player)
end

local function applySenjuEndurance(player)
    if not player then return end

    local senjuTrait = getSenjuTrait()
    if not senjuTrait then return end
    if not player:hasTrait(senjuTrait) then
        senjuLastRecoveryAt[player] = nil
        return
    end

    local currentTime = getTimestampMs()
    local lastRecovery = senjuLastRecoveryAt[player]
    if lastRecovery and currentTime < lastRecovery + 1000 then return end
    senjuLastRecoveryAt[player] = currentTime

    local stats = player:getStats()
    if not stats then return end

    local current = stats:get(CharacterStat.ENDURANCE)
    local boosted = math.min(1.0, current + SENJU_ENDURANCE_RECOVERY_PER_SECOND)
    stats:set(CharacterStat.ENDURANCE, boosted)
end

local function safeGetBool(player, getterName)
    local ok, value = pcall(function()
        if getterName == "isGhostMode" then return player:isGhostMode() end
        if getterName == "isGodMod" then return player:isGodMod() end
        if getterName == "isNoClip" then return player:isNoClip() end
        return false
    end)
    return ok and value == true
end

local function safeSetBool(player, setterName, value)
    pcall(function()
        if setterName == "setGhostMode" then
            player:setGhostMode(value)
        elseif setterName == "setGodMod" then
            player:setGodMod(value)
        end
    end)
end

local function safeSetNoClip(player, value)
    pcall(function() player:setNoClip(value, true) end)
    pcall(function() player:setNoClip(value) end)
end

local function stopKamui(player, applyPenalty)
    local state = kamuiState[player]
    if not state then return end

    safeSetBool(player, "setGhostMode", state.wasGhostMode)
    safeSetBool(player, "setGodMod", state.wasGodMod)
    safeSetNoClip(player, state.wasNoClip)
    kamuiState[player] = nil

    if applyPenalty then
        addKamuiVisionPenalty(player)
    end
end

local function failNearbyZombieAttacks(player)
    local zombies = getCell() and getCell():getZombieList()
    if not zombies then return end
    for i = 0, zombies:size() - 1 do
        local zombie = zombies:get(i)
        if zombie and not zombie:isDead() and zombie:DistTo(player) <= 3.0 then
            local target = zombie:getTarget()
            if target == player then
                zombie:setVariable("AttackOutcome", "fail")
            end
        end
    end
end

local function updateKamui(player)
    local state = kamuiState[player]
    if not state then return end

    local nowMs = getTimestampMs()
    local stats = player:getStats()
    if not stats then
        stopKamui(player, true)
        return
    end

    local elapsedMs = nowMs - state.startedAt
    local deltaSeconds = math.max(0, (nowMs - state.lastTick) / 1000)
    state.lastTick = nowMs

    local endurance = stats:get(CharacterStat.ENDURANCE)
    endurance = math.max(0, endurance - (KAMUI_ENDURANCE_DRAIN_PER_SECOND * deltaSeconds))
    stats:set(CharacterStat.ENDURANCE, endurance)

    failNearbyZombieAttacks(player)

    if elapsedMs >= KAMUI_DURATION_MS or endurance <= 0 then
        stopKamui(player, true)
    end
end

local function canUseKamui(player)
    local data = getNLData(player)
    return hasSharingan(player) and data.mangekyoUnlocked == true
end

local function startKamui(player)
    local data = getNLData(player)
    if not canUseKamui(player) then
        player:Say("Mangekyo Sharingan is not unlocked")
        return
    end

    if kamuiState[player] then
        stopKamui(player, false)
        player:Say("Kamui cancelled")
        return
    end

    local now = getTimestampSeconds()
    if data.kamuiCooldownUntil and now < data.kamuiCooldownUntil then
        player:Say("Kamui cooldown: " .. tostring(math.ceil(data.kamuiCooldownUntil - now)) .. "s")
        return
    end

    local stats = player:getStats()
    if not stats or stats:get(CharacterStat.ENDURANCE) < KAMUI_ENDURANCE_MIN then
        player:Say("Too exhausted for Kamui")
        return
    end

    local nowMs = getTimestampMs()
    kamuiState[player] = {
        startedAt = nowMs,
        lastTick = nowMs,
        wasGhostMode = safeGetBool(player, "isGhostMode"),
        wasGodMod = safeGetBool(player, "isGodMod"),
        wasNoClip = safeGetBool(player, "isNoClip"),
    }

    safeSetBool(player, "setGhostMode", true)
    safeSetBool(player, "setGodMod", true)
    safeSetNoClip(player, true)

    data.kamuiCooldownUntil = now + KAMUI_COOLDOWN_SECONDS
    transmitPlayerData(player)
    player:Say("Kamui")
end

local function collectShinraTargets(player)
    local targets = {}
    local zombies = getCell() and getCell():getZombieList()
    if not zombies then return targets end
    for i = 0, zombies:size() - 1 do
        local zombie = zombies:get(i)
        if zombie and not zombie:isDead() then
            local distance = zombie:DistTo(player)
            if distance <= SHINRA_RADIUS then
                table.insert(targets, { zombie = zombie, distance = distance })
            end
        end
    end
    return targets
end

local function applyShinraToZombie(target)
    local zombie = target.zombie
    if not zombie or zombie:isDead() then return end

    zombie:setVariable("AttackOutcome", "fail")
    zombie:setStaggerBack(true)
    if target.distance <= 2.0 or ZombRand(1, 101) <= 60 then
        zombie:setKnockedDown(true)
    end
    pcall(function() zombie:setHitReaction("") end)
    pcall(function() zombie:setPlayerAttackPosition("FRONT") end)
    pcall(function() zombie:setHitForce(math.max(1.0, SHINRA_RADIUS - target.distance)) end)
    pcall(function() zombie:reportEvent("wasHit") end)
end

local function useShinraTensei(player)
    if not hasRinnegan(player) then
        player:Say("Rinnegan is required")
        return
    end

    local data = getNLData(player)
    local now = getTimestampSeconds()
    if data.shinraCooldownUntil and now < data.shinraCooldownUntil then
        player:Say("Shinra Tensei cooldown: " .. tostring(math.ceil(data.shinraCooldownUntil - now)) .. "s")
        return
    end

    local stats = player:getStats()
    if not stats then return end

    local targets = collectShinraTargets(player)
    local cost = math.min(
        SHINRA_ENDURANCE_COST_CAP,
        SHINRA_BASE_ENDURANCE_COST + (#targets * SHINRA_ENDURANCE_COST_PER_ZOMBIE)
    )
    local endurance = stats:get(CharacterStat.ENDURANCE)
    if endurance < cost then
        player:Say("Too exhausted for Shinra Tensei")
        return
    end

    stats:set(CharacterStat.ENDURANCE, math.max(0, endurance - cost))
    for _, target in ipairs(targets) do
        applyShinraToZombie(target)
    end

    data.shinraCooldownUntil = now + SHINRA_COOLDOWN_SECONDS
    transmitPlayerData(player)
    player:Say("Shinra Tensei")
end

local function unlockMangekyoIfEligible(victim)
    if not victim or not instanceof(victim, "IsoPlayer") then return end
    local attacker = victim:getAttackedBy()
    if not attacker or not instanceof(attacker, "IsoPlayer") then return end
    if not attacker:isLocalPlayer() then return end
    if not hasSharingan(attacker) or getSharinganStage(attacker) < 3 then return end

    local data = getNLData(attacker)
    if data.mangekyoUnlocked then return end
    data.mangekyoUnlocked = true
    transmitPlayerData(attacker)
    attacker:Say("Mangekyo Sharingan awakened")
    updateSharinganMoodle(attacker)
end

local function sharinganEvade(zombie)
    if not zombie or zombie:isDead() then return end

    local attackOutcome = zombie:getVariableString("AttackOutcome")
    if attackOutcome ~= "success" then
        sharinganAttackRolls[zombie] = nil
        return
    end

    if sharinganAttackRolls[zombie] then return end

    local player = zombie:getTarget()
    if not player or not instanceof(player, "IsoPlayer") then return end
    if player:isDead() or player:isZombie() then return end
    if not player:isLocalPlayer() then return end

    if kamuiState[player] then
        sharinganAttackRolls[zombie] = true
        zombie:setVariable("AttackOutcome", "fail")
        return
    end

    local dodgeChance = getSharinganDodgeChance(player)
    if dodgeChance <= 0 then return end

    sharinganAttackRolls[zombie] = true
    if ZombRand(1, 101) <= dodgeChance then
        zombie:setVariable("AttackOutcome", "fail")
        player:setHitReaction("EvasiveBlocked")
        player:Say("Sharingan!")
    end
end

local function getAvailableAbilities(player)
    local abilities = {}
    if canUseKamui(player) then
        table.insert(abilities, { name = "Kamui", action = startKamui, texture = "media/ui/Traits/trait_sharingan.png" })
    end
    if hasRinnegan(player) then
        table.insert(abilities, { name = "Shinra Tensei", action = useShinraTensei, texture = "media/ui/Traits/trait_rinnegan.png" })
    end
    return abilities
end

local function useDefaultAbility(player)
    local abilities = getAvailableAbilities(player)
    if #abilities == 0 then
        player:Say("No ninja ability available")
        return
    end
    if #abilities == 1 then
        abilities[1].action(player)
        return
    end
    player:Say("Use the Ninja Lineages radial menu")
end

local function addAbilityContextMenu(playerNum, context, worldObjects, test)
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end
    local abilities = getAvailableAbilities(player)
    if #abilities == 0 then return end
    if test then return true end

    local option = context:addOption("Ninja Lineages")
    local subMenu = ISContextMenu:getNew(context)
    context:addSubMenu(option, subMenu)
    for _, ability in ipairs(abilities) do
        subMenu:addOption(ability.name, player, ability.action)
    end
end

local function showAbilityRadial(player)
    local abilities = getAvailableAbilities(player)
    if #abilities == 0 then return false end

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
        menu:addSlice(ability.name, getTexture(ability.texture), ability.action, player)
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
        useDefaultAbility(player)
        return
    end

    if getCore():isKey("VehicleRadialMenu", key) and not player:getVehicle() then
        local hasVehicle = ISVehicleMenu and ISVehicleMenu.getVehicleToInteractWith and ISVehicleMenu.getVehicleToInteractWith(player)
        local hasAnimal = AnimalContextMenu and AnimalContextMenu.getAnimalToInteractWith and AnimalContextMenu.getAnimalToInteractWith(player)
        if not hasVehicle and not hasAnimal then
            showAbilityRadial(player)
        end
    end
end

local function initKeybinds()
    table.insert(keyBinding, { value = "[Ninja Lineages]" })
    table.insert(keyBinding, { value = "Ninja Ability", key = Keyboard.KEY_NONE })
end

local function onPlayerUpdate(player)
    if not player then return end
    if not player:isLocalPlayer() then return end

    applyByakugan(player)
    applySenjuEndurance(player)
    updateSharinganMoodle(player)
    recoverKamuiVision(player)
    updateKamui(player)
end

Events.OnCreatePlayer.Add(function(playerIndex, player)
    if player then
        applyByakugan(player)
        recoverKamuiVision(player)
        updateSharinganMoodle(player)
    end
end)

Events.OnGameBoot.Add(initKeybinds)
Events.OnPlayerUpdate.Add(onPlayerUpdate)
Events.OnZombieUpdate.Add(sharinganEvade)
Events.OnCharacterDeath.Add(unlockMangekyoIfEligible)
Events.OnFillWorldObjectContextMenu.Add(addAbilityContextMenu)
Events.OnKeyStartPressed.Add(onKeyStartPressed)
