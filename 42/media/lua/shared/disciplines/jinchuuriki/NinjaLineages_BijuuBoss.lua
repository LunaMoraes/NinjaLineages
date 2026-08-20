require "NinjaLineages_Balance"
require "disciplines/jinchuuriki/NinjaLineages_BijuuDefinitions"
require "disciplines/jinchuuriki/NinjaLineages_BijuuState"

NinjaLineages = NinjaLineages or {}
NinjaLineages.BijuuBoss = NinjaLineages.BijuuBoss or {}

local Boss = NinjaLineages.BijuuBoss
local Definitions = NinjaLineages.BijuuDefinitions

Boss.KEY_BOSS_PROXY = "isBijuuBossProxy"
Boss.KEY_BIJUU_ID   = "bijuuId"
Boss.KEY_RUNTIME_ID = "bijuuRuntimeId"

Boss.ThemeColors = {
    shukaku  = { r = 0.85, g = 0.72, b = 0.45 }, -- Sand / Tan
    matatabi = { r = 0.15, g = 0.55, b = 1.00 }, -- Cobalt / Blue Fire
    isobu    = { r = 0.35, g = 0.65, b = 0.70 }, -- Ocean / Turtle Teal
    son_goku = { r = 0.95, g = 0.30, b = 0.10 }, -- Lava Red-Orange
    kokuo    = { r = 0.90, g = 0.92, b = 0.95 }, -- Steam White / Platinum
    saiken   = { r = 0.70, g = 0.85, b = 0.95 }, -- Slime White-Cyan
    chomei   = { r = 0.30, g = 0.80, b = 0.40 }, -- Beetle Jade Green
    gyuki    = { r = 0.65, g = 0.15, b = 0.35 }, -- Deep Bull Crimson
    kurama   = { r = 1.00, g = 0.45, b = 0.05 }, -- Nine-Tails Fox Orange
}

function Boss.isBossProxy(entity)
    if not entity or not entity.getModData then return false end
    local modData = entity:getModData()
    return modData and modData[Boss.KEY_BOSS_PROXY] == true
end

function Boss.getBijuuId(entity)
    if not entity or not entity.getModData then return nil end
    local modData = entity:getModData()
    return modData and modData[Boss.KEY_BIJUU_ID] or nil
end

function Boss.getRuntimeId(entity)
    if not entity or not entity.getModData then return nil end
    local modData = entity:getModData()
    return modData and modData[Boss.KEY_RUNTIME_ID] or nil
end

function Boss.getThemeColor(bijuuId)
    return Boss.ThemeColors[bijuuId] or { r = 1.0, g = 0.6, b = 0.2 }
end

function Boss.getShellConfig(bijuuId)
    local def = Definitions.get(bijuuId)
    local shell = NinjaLineages.Balance.Jinchuuriki and NinjaLineages.Balance.Jinchuuriki.BossShell
    local color = Boss.getThemeColor(bijuuId)
    return {
        bijuuId = bijuuId,
        tails = def and def.tails or 1,
        nameKey = def and def.nameKey or "UI_NL_Bijuu_" .. tostring(bijuuId),
        visualRadius = shell and shell.VISUAL_RADIUS or 2.4,
        visualHeight = shell and shell.VISUAL_HEIGHT or 0.45,
        proxyWidth = shell and shell.PROXY_WIDTH or 2.4,
        perimeterHitboxRadius = shell and shell.PERIMETER_HITBOX_RADIUS or 1.2,
        color = color,
    }
end
