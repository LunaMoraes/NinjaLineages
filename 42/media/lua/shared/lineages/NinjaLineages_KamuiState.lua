require "NinjaLineages_Traits"
require "NinjaLineages_JutsuCatalog"
require "NinjaLineages_AbilityAuthority"

NinjaLineages = NinjaLineages or {}
NinjaLineages.KamuiState = NinjaLineages.KamuiState or {}

local KamuiState = NinjaLineages.KamuiState
local kamuiLocalState = setmetatable({}, { __mode = "k" })
local KAMUI_ALPHA = 0.55

local function setForcedNoClip(player, active)
    pcall(function() player:setNoClip(active == true, true) end)
end

function KamuiState.save(player)
    local state = {
        wasCollidable = true,
        wasNoClip = false,
        wasGhostMode = false,
        wasGodMod = false,
        wasAlpha = 1,
        wasTargetAlpha = 1,
    }

    local okCollidable, wasCollidable = pcall(function() return player:isCollidable() end)
    if okCollidable then state.wasCollidable = wasCollidable == true end

    local okNoClip, wasNoClip = pcall(function() return player:isNoClip() end)
    if okNoClip then state.wasNoClip = wasNoClip == true end

    local okGhost, wasGhost = pcall(function() return player:isGhostMode() end)
    if okGhost then state.wasGhostMode = wasGhost == true end

    local okGod, wasGod = pcall(function() return player:isGodMod() end)
    if okGod then state.wasGodMod = wasGod == true end

    local okAlpha, wasAlpha = pcall(function() return player:getAlpha() end)
    if okAlpha and wasAlpha then state.wasAlpha = wasAlpha end

    local okTargetAlpha, wasTargetAlpha = pcall(function() return player:getTargetAlpha() end)
    if okTargetAlpha and wasTargetAlpha then state.wasTargetAlpha = wasTargetAlpha end

    state.kamuiLastSafeX = player:getX()
    state.kamuiLastSafeY = player:getY()
    state.kamuiLastSafeZ = player:getZ()

    return state
end

function KamuiState.applyFlags(player)
    pcall(function() player:setGhostMode(true) end)
    pcall(function() player:setGodMod(true, true) end)
    if NinjaLineages.isClient() or NinjaLineages.isServer() then
        pcall(function() player:setNoClip(true, true) end)
    end
end

function KamuiState.emitEvent(player, active, restoreX, restoreY, restoreZ)
    if not player then return end
    local event = {
        kind = "kamui_noclip",
        active = active == true,
        casterOnlineId = player:getOnlineID(),
        restoreX = restoreX,
        restoreY = restoreY,
        restoreZ = restoreZ,
    }
    if NinjaLineages.isServer() then
        sendServerCommand(player, "NinjaLineages", "abilityEvent", event)
    else
        NinjaLineages.AbilityAuthority.handleEvent(event)
    end
end

function KamuiState.restore(player, state)
    if not player or not state then return end

    local currentSquare = player:getSquare()
    local restoreX, restoreY, restoreZ = player:getX(), player:getY(), player:getZ()
    if not KamuiState.isSafeExitSquare(currentSquare) then
        restoreX = state.kamuiLastSafeX or restoreX
        restoreY = state.kamuiLastSafeY or restoreY
        restoreZ = state.kamuiLastSafeZ or restoreZ
        player:setX(restoreX)
        player:setY(restoreY)
        player:setZ(restoreZ)
    end

    pcall(function() player:setGhostMode(state.wasGhostMode == true) end)
    pcall(function() player:setGodMod(state.wasGodMod == true, true) end)
    pcall(function() player:setNoClip(state.wasNoClip == true, true) end)
    pcall(function() player:setCollidable(state.wasCollidable == true) end)
    pcall(function()
        player:setAlpha(state.wasAlpha)
        player:setTargetAlpha(state.wasTargetAlpha)
    end)

    KamuiState.emitEvent(player, false, restoreX, restoreY, restoreZ)
end

function KamuiState.maintain(player)
    if not player or not kamuiLocalState[player] then return end
    if NinjaLineages.isClient() or NinjaLineages.isServer() then
        setForcedNoClip(player, true)
    end
    pcall(function() player:setGhostMode(true) end)
    pcall(function() player:setAlphaAndTarget(KAMUI_ALPHA) end)
end

function KamuiState.applyLocal(player, args)
    if not player then return end
    local active = args and args.active == true

    if active then
        if not kamuiLocalState[player] then
            kamuiLocalState[player] = KamuiState.save(player)
        end
        if NinjaLineages.isClient() or NinjaLineages.isServer() then
            setForcedNoClip(player, true)
        end
        pcall(function() player:setGhostMode(true) end)
        pcall(function() player:setAlphaAndTarget(KAMUI_ALPHA) end)
        return
    end

    local state = kamuiLocalState[player]
    if state then
        if args and args.restoreX and args.restoreY and args.restoreZ then
            pcall(function()
                player:setX(args.restoreX)
                player:setY(args.restoreY)
                player:setZ(args.restoreZ)
            end)
        end
        setForcedNoClip(player, state.wasNoClip == true)
        pcall(function() player:setGhostMode(state.wasGhostMode == true) end)
        pcall(function() player:setCollidable(state.wasCollidable == true) end)
        pcall(function()
            player:setAlpha(state.wasAlpha)
            player:setTargetAlpha(state.wasTargetAlpha)
        end)
        kamuiLocalState[player] = nil
        return
    end

    setForcedNoClip(player, false)
    pcall(function() player:setCollidable(true) end)
end

function KamuiState.isSafeExitSquare(square)
    if not square then return false end
    if square:isSolid() or square:isSolidTrans() then return false end
    return square:isFree(false)
end

function KamuiState.placePhasedPlayer(player, x, y, z)
    player:setX(x)
    player:setY(y)
    player:setZ(z)
    pcall(function() player:setLastX(x) end)
    pcall(function() player:setLastY(y) end)
    pcall(function() player:setLastZ(z) end)
    pcall(function() player:setCurrentSquareFromPosition(x, y, z) end)
    pcall(function() player:setMovingSquareNow() end)
end

function KamuiState.getLocalState(player)
    return kamuiLocalState[player]
end

NinjaLineages.AbilityAuthority.registerEventHandler("kamui_noclip", function(args)
    local player = NinjaLineages.AbilityAuthority.findLocalPlayer(args.casterOnlineId)
    if player then
        KamuiState.applyLocal(player, args)
    end
end)

