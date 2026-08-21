require "NinjaLineages_Balance"
require "NinjaLineages_Utils"
require "NinjaLineages_Progression"
require "jinchuuriki/NinjaLineages_BijuuRenderer"

NinjaLineages = NinjaLineages or {}

local BAR_HEIGHT = 22
local TOP_MARGIN = 42
local MIN_WIDTH = 300
local MAX_WIDTH = 720
local VIEWPORT_WIDTH_FACTOR = 0.58
local TRAIL_DRAIN_PER_SECOND = 0.28
local playerStates = {}
local discoveryClaims = {}

local function clamp01(value)
    return math.max(0, math.min(1, tonumber(value) or 0))
end

local function nearestBoss(player)
    if not player or (player.isDead and player:isDead()) then return nil end
    local combat = NinjaLineages.Balance.Jinchuuriki
        and NinjaLineages.Balance.Jinchuuriki.BossCombat or {}
    local shell = NinjaLineages.BijuuRenderer.getNearestActiveShell(
        player,
        combat.ACQUISITION_RADIUS or 20.0
    )
    if shell then return shell end
    local sealing = NinjaLineages.Balance.Jinchuuriki
        and NinjaLineages.Balance.Jinchuuriki.Sealing or {}
    return NinjaLineages.BijuuRenderer.getNearestActiveSealingShell(
        player,
        sealing.RITUAL_RADIUS or 50.0
    )
end

local function claimDiscoveryIfNeeded(playerNum, player, shell)
    local jinchuuriki = NinjaLineages.Progression.getJinchuurikiData(player)
    if not jinchuuriki or jinchuuriki.discovered == true then
        discoveryClaims[playerNum] = nil
        return
    end

    local now = NinjaLineages.Utils.Time.realMilliseconds()
    local pending = discoveryClaims[playerNum]
    if pending and pending.runtimeId == shell.runtimeId and pending.accepted == true then return end
    if pending and pending.runtimeId == shell.runtimeId and now - pending.sentAt < 5000 then
        return
    end
    discoveryClaims[playerNum] = {
        runtimeId = shell.runtimeId,
        playerOnlineId = player.getOnlineID and player:getOnlineID() or -1,
        sentAt = now,
    }

    local args = { bijuuId = shell.bijuuId, runtimeId = shell.runtimeId }
    if NinjaLineages.isClient and NinjaLineages.isClient() then
        sendClientCommand(player, "NinjaLineages", "claimJinchuurikiDiscovery", args)
    elseif NinjaLineages.ProgressionServer
            and NinjaLineages.ProgressionServer.tryDiscoverJinchuuriki then
        NinjaLineages.ProgressionServer.tryDiscoverJinchuuriki(player, args)
        discoveryClaims[playerNum] = nil
    end
end

local function updateState(playerNum, shell)
    local now = NinjaLineages.Utils.Time.realMilliseconds()
    local state = playerStates[playerNum]
    if not state then
        state = { runtimeId = nil, healthRatio = 0, trailRatio = 0, lastRealMilliseconds = now }
        playerStates[playerNum] = state
    end

    local maximum = tonumber(shell.maxHealth)
    local current = tonumber(shell.currentHealth)
    if not maximum or maximum <= 0 or not current then
        state.runtimeId = nil
        return nil
    end

    local ratio = clamp01(current / maximum)
    local deltaSeconds = math.max(0, math.min(0.1, (now - state.lastRealMilliseconds) / 1000))
    state.lastRealMilliseconds = now
    if state.runtimeId ~= shell.runtimeId then
        state.runtimeId = shell.runtimeId
        state.healthRatio = ratio
        state.trailRatio = ratio
    else
        if ratio > state.healthRatio then state.trailRatio = ratio end
        state.healthRatio = ratio
        state.trailRatio = math.max(ratio, state.trailRatio - TRAIL_DRAIN_PER_SECOND * deltaSeconds)
    end
    return state
end

local function rect(renderer, x, y, width, height, r, g, b, alpha)
    if width > 0 and height > 0 then
        renderer:renderRect(math.floor(x), math.floor(y), math.floor(width), math.floor(height), r, g, b, alpha)
    end
end

local function drawBarForPlayer(renderer, textManager, playerNum, player)
    local shell = nearestBoss(player)
    if not shell then
        if playerStates[playerNum] then playerStates[playerNum].runtimeId = nil end
        return
    end
    local state = updateState(playerNum, shell)
    if not state then return end
    claimDiscoveryIfNeeded(playerNum, player, shell)

    local screenLeft = getPlayerScreenLeft(playerNum)
    local screenTop = getPlayerScreenTop(playerNum)
    local screenWidth = getPlayerScreenWidth(playerNum)
    local width = math.floor(math.min(MAX_WIDTH, math.max(MIN_WIDTH, screenWidth * VIEWPORT_WIDTH_FACTOR)))
    local x = math.floor(screenLeft + (screenWidth - width) * 0.5)
    local y = math.floor(screenTop + TOP_MARGIN)
    local innerX, innerY = x + 4, y + 4
    local innerWidth, innerHeight = width - 8, BAR_HEIGHT - 8
    local color = shell.color or { r = 1.0, g = 0.45, b = 0.05 }

    rect(renderer, x - 2, y - 2, width + 4, BAR_HEIGHT + 4, 0.01, 0.01, 0.015, 0.88)
    rect(renderer, x, y, width, BAR_HEIGHT, 0.07, 0.055, 0.06, 0.98)
    rect(renderer, innerX, innerY, innerWidth * state.trailRatio, innerHeight, 0.82, 0.68, 0.38, 0.88)
    rect(renderer, innerX, innerY, innerWidth * state.healthRatio, innerHeight,
        color.r * 0.72, color.g * 0.72, color.b * 0.72, 0.98)
    rect(renderer, innerX, innerY, innerWidth * state.healthRatio, 2,
        math.min(1, color.r + 0.25), math.min(1, color.g + 0.25), math.min(1, color.b + 0.25), 1.0)

    local name = shell.nameKey and getText(shell.nameKey) or tostring(shell.bijuuId)
    local current = math.max(0, math.floor(shell.currentHealth + 0.5))
    local maximum = math.max(1, math.floor(shell.maxHealth + 0.5))
    textManager:DrawStringCentre(UIFont.Medium, x + width * 0.5, y - 22,
        name, 0.96, 0.93, 0.88, 1.0)
    textManager:DrawStringCentre(UIFont.Small, x + width * 0.5, y + 3,
        tostring(current) .. " / " .. tostring(maximum), 1.0, 1.0, 1.0, 1.0)

    if shell.sealing then
        local sealingY = y + BAR_HEIGHT + 7
        local sealingHeight = 18
        local sealingInnerX = x + 4
        local sealingInnerY = sealingY + 4
        local sealingInnerWidth = width - 8
        local progress = math.max(0, math.min(100, tonumber(shell.sealing.progress) or 0))
        local progressRatio = progress / 100
        local power = math.max(0, tonumber(shell.sealing.vesselPower) or 0)

        rect(renderer, x - 2, sealingY - 2, width + 4, sealingHeight + 4,
            0.01, 0.01, 0.015, 0.82)
        rect(renderer, x, sealingY, width, sealingHeight,
            0.055, 0.045, 0.075, 0.94)
        rect(renderer, sealingInnerX, sealingInnerY,
            sealingInnerWidth * progressRatio, sealingHeight - 8,
            math.min(1, color.r + 0.12), math.min(1, color.g + 0.12), math.min(1, color.b + 0.12), 0.92)

        local progressText = getText(
            "UI_NL_Sealing_Power",
            tostring(math.floor(progress + 0.5)),
            string.format("%.2f", power)
        )
        textManager:DrawStringCentre(UIFont.Small, x + width * 0.5, sealingY + 1,
            getText("UI_NL_Sealing_Process") .. ": " .. progressText,
            0.96, 0.93, 1.0, 1.0)
    end
end

local function onServerCommand(module, command, args)
    if module ~= "NinjaLineages" or command ~= "jinchuurikiDiscoveryResult" then return end
    for playerNum, pending in pairs(discoveryClaims) do
        local sameRuntime = not args or not args.runtimeId or pending.runtimeId == args.runtimeId
        local samePlayer = not args or args.playerOnlineId == nil
            or pending.playerOnlineId == args.playerOnlineId
        if sameRuntime and samePlayer then
            if args and args.ok == true then
                pending.accepted = true
            else
                discoveryClaims[playerNum] = nil
            end
        end
    end
end

local function drawBossHealthBars()
    local renderer = getRenderer and getRenderer()
    local textManager = getTextManager and getTextManager()
    if not renderer or not textManager then return end

    local count = getNumActivePlayers and getNumActivePlayers() or 1
    for playerNum = 0, count - 1 do
        local player = getSpecificPlayer and getSpecificPlayer(playerNum)
        if player then drawBarForPlayer(renderer, textManager, playerNum, player) end
    end
end

if Events and Events.OnPostUIDraw then
    NinjaLineages.addEventOnce(
        "client.bijuuBossHealthBar.onPostUIDraw",
        Events.OnPostUIDraw,
        drawBossHealthBars
    )
end


if Events and Events.OnServerCommand then
    NinjaLineages.addEventOnce(
        "client.bijuuBossHealthBar.onServerCommand",
        Events.OnServerCommand,
        onServerCommand
    )
end
