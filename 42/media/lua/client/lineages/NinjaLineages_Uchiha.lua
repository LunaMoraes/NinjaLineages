require "NinjaLineages_Traits"

NinjaLineages = NinjaLineages or {}
NinjaLineages.Uchiha = {}

local consts = NinjaLineages.Constants

local sharinganAttackRolls = {}
local kamuiState = {}

local MOODLE_GOOD = 1
local MOODLE_BAD = 2
local MOODLE_TEXT = {
    NLSharinganTomoe = {
        [MOODLE_GOOD] = {
            [1] = { "Sharingan", "First Tomoe awakened. Dodge chance: 30%." },
            [2] = { "Sharingan", "Second Tomoe released. Dodge chance: 60%." },
            [3] = { "Sharingan", "Third Tomoe released. Dodge chance: 90%." },
            [4] = { "Mangekyo Sharingan", "Mangekyo Sharingan awakened. Kamui is available." },
        },
    },
    NLKamuiVision = {
        [MOODLE_BAD] = {
            [1] = { "Vision Impaired", "Kamui has strained your vision. Recovery: 1 in-game hour." },
            [2] = { "Vision Impaired", "Repeated Kamui use has damaged your vision. Recovery: 6 in-game hours." },
            [3] = { "Vision Impaired", "Kamui overuse has severely damaged your vision. Recovery: 1 full in-game day." },
            [4] = { "Vision Impaired", "Kamui overuse has severely damaged your vision. Recovery: 1 full in-game day." },
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

local function getSharinganDodgeChance(player)
    local data = NinjaLineages.getNLData(player)
    if not data.eyePowerActive then return 0 end
    local stage = NinjaLineages.getSharinganStage(player)
    if stage == 1 then return 30 end
    if stage == 2 then return 60 end
    if stage == 3 then return 90 end
    return 0
end

local function updateSharinganMoodle(player)
    local data = NinjaLineages.getNLData(player)
    if not NinjaLineages.hasSharingan(player) or not data.eyePowerActive then
        setMoodleValue("NLSharinganTomoe", player, 0.5)
        data.lastSharinganStage = nil
        return
    end

    local stage = NinjaLineages.getSharinganStage(player)
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
        NinjaLineages.transmitPlayerData(player)
    elseif stage < lastStage then
        data.lastSharinganStage = stage
        NinjaLineages.transmitPlayerData(player)
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

local function applyKamuiVisionItem(player)
    local data = NinjaLineages.getNLData(player)
    local level = data.kamuiVisionLevel or 0
    local equipped = getWornItemByType(player, consts.VISION_ITEMS)
    local desiredType = level > 0 and consts.VISION_ITEMS[level] or nil
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
        removeInventoryItems(player, consts.VISION_ITEMS)
        setMoodleValue("NLKamuiVision", player, 0.5)
        return
    end

    removeInventoryItems(player, consts.VISION_ITEMS)
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

local function getWorldAgeHours()
    local gameTime = getGameTime()
    if gameTime and gameTime.getWorldAgeHours then
        return gameTime:getWorldAgeHours()
    end
    return 0
end

local function recoverKamuiVision(player)
    local data = NinjaLineages.getNLData(player)
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
            data.kamuiVisionRecoverAt = now + consts.VISION_RECOVERY_HOURS[level]
        else
            data.kamuiVisionRecoverAt = nil
        end
        NinjaLineages.transmitPlayerData(player)
    end
    applyKamuiVisionItem(player)
end

local function addKamuiVisionPenalty(player)
    local data = NinjaLineages.getNLData(player)
    local now = getWorldAgeHours()
    local level = math.min(3, (data.kamuiVisionLevel or 0) + 1)
    data.kamuiVisionLevel = level
    data.kamuiVisionRecoverAt = now + consts.VISION_RECOVERY_HOURS[level]
    applyKamuiVisionItem(player)
    NinjaLineages.transmitPlayerData(player)
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

    -- Drain chakra
    local chakra = NinjaLineages.Chakra.getChakra(player)
    chakra = math.max(0.0, chakra - (NinjaLineages.Chakra.KAMUI_DRAIN_PER_SECOND * deltaSeconds))
    NinjaLineages.Chakra.setChakra(player, chakra)

    failNearbyZombieAttacks(player)

    if elapsedMs >= consts.KAMUI_DURATION_MS or chakra <= 0 then
        stopKamui(player, true)
    end
end

local function canUseKamui(player)
    local data = NinjaLineages.getNLData(player)
    return NinjaLineages.hasSharingan(player) and data.mangekyoUnlocked == true
end

local function getTimestampSeconds()
    if getTimestamp then return getTimestamp() end
    return math.floor(getTimestampMs() / 1000)
end

function NinjaLineages.Uchiha.startKamui(player)
    local data = NinjaLineages.getNLData(player)
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

    if not NinjaLineages.Chakra.canAffordChakra(player, NinjaLineages.Chakra.KAMUI_MIN_GATE) then
        player:Say("Too exhausted (low chakra) for Kamui")
        return
    end

    -- Automatically activate Sharingan if not already active
    if not data.eyePowerActive then
        data.eyePowerActive = true
        updateSharinganMoodle(player)
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

    data.kamuiCooldownUntil = now + consts.KAMUI_COOLDOWN_SECONDS
    NinjaLineages.transmitPlayerData(player)
    player:Say("Kamui")
end

function NinjaLineages.Uchiha.toggleSharingan(player)
    local data = NinjaLineages.getNLData(player)
    if data.eyePowerActive then
        data.eyePowerActive = false
        updateSharinganMoodle(player)
        player:Say("Sharingan Deactivated")
    else
        if NinjaLineages.getSharinganStage(player) == 0 then
            player:Say(getText("UI_NL_SharinganLocked"))
            return
        end
        if NinjaLineages.Chakra.getChakra(player) > 0 then
            data.eyePowerActive = true
            updateSharinganMoodle(player)
            player:Say("Sharingan Activated")
        else
            player:Say("Not enough chakra!")
        end
    end
end

-- Evasion
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

local function isSinglePlayerGame()
    if isClient and isClient() then return false end
    if isServer and isServer() then return false end
    return true
end

local function canUseKamuiTestUnlock(player)
    if not isSinglePlayerGame() then return false end
    if not NinjaLineages.hasSharingan(player) then return false end
    if NinjaLineages.getSharinganStage(player) < 3 then return false end
    return NinjaLineages.getNLData(player).mangekyoUnlocked ~= true
end

local function unlockKamuiForSinglePlayerTest(player)
    if not canUseKamuiTestUnlock(player) then
        player:Say("Third Tomoe is required")
        return
    end

    local data = NinjaLineages.getNLData(player)
    data.mangekyoUnlocked = true
    NinjaLineages.transmitPlayerData(player)
    updateSharinganMoodle(player)
    player:Say("Mangekyo Sharingan awakened")
end

local function unlockMangekyoIfEligible(victim)
    if not victim or not instanceof(victim, "IsoPlayer") then return end
    local attacker = victim:getAttackedBy()
    if not attacker or not instanceof(attacker, "IsoPlayer") then return end
    if not attacker:isLocalPlayer() then return end
    if not NinjaLineages.hasSharingan(attacker) or NinjaLineages.getSharinganStage(attacker) < 3 then return end

    local data = NinjaLineages.getNLData(attacker)
    if data.mangekyoUnlocked then return end
    data.mangekyoUnlocked = true
    NinjaLineages.transmitPlayerData(attacker)
    attacker:Say("Mangekyo Sharingan awakened")
    updateSharinganMoodle(attacker)
end

-- Modular eye drain implementation
function NinjaLineages.Uchiha.getEyePowerDrain(player, data)
    if data.eyePowerActive and NinjaLineages.hasSharingan(player) then
        local tomoe = data.sharinganTomoe or 1
        if tomoe == 4 or data.mangekyoUnlocked then
            return consts.MANGEKYO_DRAIN_PER_MINUTE
        else
            return consts.SHARINGAN_DRAIN_PER_MINUTE[tomoe] or 48.0
        end
    end
    return 0.0
end

function NinjaLineages.Uchiha.onEyePowerDeactivated(player)
    -- clean up moodles or state if needed
    updateSharinganMoodle(player)
end

-- Dynamic Registration
NinjaLineages.registerAbility({
    id = "sharingan",
    name = "Toggle Sharingan",
    texture = "media/ui/Traits/trait_sharingan.png",
    condition = function(player) return NinjaLineages.hasSharingan(player) end,
    action = NinjaLineages.Uchiha.toggleSharingan
})

NinjaLineages.registerAbility({
    id = "kamui",
    name = "Kamui",
    texture = "media/ui/Traits/trait_sharingan.png",
    condition = function(player) return canUseKamui(player) end,
    action = NinjaLineages.Uchiha.startKamui
})

NinjaLineages.registerPlayerUpdate(function(player)
    updateSharinganMoodle(player)
    recoverKamuiVision(player)
    updateKamui(player)
end)

NinjaLineages.registerZombieUpdate(sharinganEvade)

NinjaLineages.registerCreatePlayer(function(player)
    recoverKamuiVision(player)
    updateSharinganMoodle(player)
end)

-- Hook for test unlock Mangekyo context option
if Events.OnFillWorldObjectContextMenu then
    Events.OnFillWorldObjectContextMenu.Add(function(playerNum, context, worldObjects, test)
        local player = getSpecificPlayer(playerNum)
        if not player or player:isDead() then return end
        if test then return true end

        if canUseKamuiTestUnlock(player) then
            -- Find or add NinjaLineages context menu
            local nLOption = nil
            for i = 1, #context.options do
                if context.options[i].name == getText("UI_NL_NinjaLineagesMenu") then
                    nLOption = context.options[i]
                    break
                end
            end

            local subMenu = nil
            if nLOption then
                subMenu = context:getSubMenu(nLOption)
            else
                nLOption = context:addOption(getText("UI_NL_NinjaLineagesMenu"))
                subMenu = ISContextMenu:getNew(context)
                context:addSubMenu(nLOption, subMenu)
            end

            if subMenu then
                subMenu:addOption("Kamui Test: Unlock Mangekyo", player, unlockKamuiForSinglePlayerTest)
            end
        end
    end)
end

if Events.OnCharacterDeath then
    Events.OnCharacterDeath.Add(unlockMangekyoIfEligible)
end
