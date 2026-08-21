require "TimedActions/ISBaseTimedAction"
require "XpSystem/ISUI/ISHealthPanel"
require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISContextMenu"
require "NinjaLineages_Progression"
require "NinjaLineages_Utils"
require "NinjaLineages_Traits"
require "NinjaLineages_Balance"
require "disciplines/medicine/NinjaLineages_MedicineUtils"
require "jinchuuriki/NinjaLineages_JinchuurikiPanel"

NinjaLineages = NinjaLineages or {}
NinjaLineages.ExperimentalSurgeryClient = NinjaLineages.ExperimentalSurgeryClient or {}

local surgeryBalance = NinjaLineages.Balance.GeneExperimentation.Surgery
local patientRange = NinjaLineages.MedicineUtils.getPatientMaxDistance()

local SurgeryClient = NinjaLineages.ExperimentalSurgeryClient
local getItemFreshness = NinjaLineages.MedicineUtils.getItemFreshness

local function getOcularSamples(doctor)
    local list = {}
    local inv = doctor and doctor:getInventory()
    if not inv then return list end
    local items = NinjaLineages.Utils.Inventory.collectItems(inv, "Base.NL_OcularTissueSample")
    for _, item in ipairs(items) do
        if item and not (item.isRotten and item:isRotten()) then
            local freshness = getItemFreshness(item)
            local eyeType = item:getModData().eyeType
            if eyeType == "sharingan" or eyeType == "byakugan" or eyeType == "rinnegan" then
                local typeName = eyeType == "sharingan" and getText("UI_NL_Ability_Sharingan_Name")
                    or (eyeType == "byakugan" and getText("UI_NL_Ability_Byakugan_Name")
                    or getText("UI_NL_Eye_Rinnegan"))
                local label = typeName .. " (" .. freshness .. "%)"
                table.insert(list, {
                    item = item,
                    label = label,
                    freshness = freshness,
                    eyeType = eyeType,
                })
            end
        end
    end
    return list
end

local function getGeneSamples(doctor)
    local list = {}
    local inv = doctor and doctor:getInventory()
    if not inv then return list end
    local items = NinjaLineages.Utils.Inventory.collectItems(inv, "Base.NL_GeneSample")
    for _, item in ipairs(items) do
        if item and not (item.isRotten and item:isRotten()) then
            local freshness = getItemFreshness(item)
            local label = getText("UI_item_NL_GeneSample") .. " (" .. freshness .. "%)"
            table.insert(list, {
                item = item,
                label = label,
                freshness = freshness,
            })
        end
    end
    return list
end

-- ============================================================================
-- 2. Timed Action Definition
-- ============================================================================

NLExperimentalSurgeryAction = ISBaseTimedAction:derive("NLExperimentalSurgeryAction")

function NLExperimentalSurgeryAction:isValid()
    if not self.character or self.character:isDead() then return false end
    if not self.patient or self.patient:isDead() then return false end
    if self.character ~= self.patient and self.character:DistTo(self.patient) > patientRange then return false end
    return true
end

function NLExperimentalSurgeryAction:start()
    self:setActionAnim("Loot")
end

function NLExperimentalSurgeryAction:stop()
    ISBaseTimedAction.stop(self)
end

function NLExperimentalSurgeryAction:perform()
    if NinjaLineages.isClient() then
        sendClientCommand(self.character, "NinjaLineages", "performExperimentalSurgery", {
            surgeryType = self.surgeryType,
            eyeSlot = self.eyeSlot,
            itemId = self.item and self.item:getID(),
            patientOnlineId = self.patient:getOnlineID(),
        })
    else
        -- Singleplayer
        local ServerLogic = NinjaLineages.GeneExperimentationServer
        if ServerLogic then
            if self.surgeryType == "remove_eye" then
                ServerLogic.removeEye(self.character, self.patient, self.eyeSlot)
            elseif self.surgeryType == "implant_eye" then
                ServerLogic.implantEye(self.character, self.patient, self.eyeSlot, self.item and self.item:getID())
            elseif self.surgeryType == "implant_genes" then
                ServerLogic.implantGenes(self.character, self.patient, self.item and self.item:getID())
            end
        end
    end

    if NLEyePanelUI.instance and NLEyePanelUI.instance:isVisible() then
        NLEyePanelUI.instance:refreshData()
    end

    ISBaseTimedAction.perform(self)
end

function NLExperimentalSurgeryAction:new(doctor, patient, surgeryType, eyeSlot, item, maxTime)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = doctor
    o.patient = patient
    o.surgeryType = surgeryType
    o.eyeSlot = eyeSlot
    o.item = item
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = maxTime or surgeryBalance.TIMED_ACTION_MIN
    return o
end

local function onPerformSurgery(doctor, patient, surgeryType, eyeSlot, item)
    if not doctor or not patient then return end
    local docLevel = 0
    if Perks.Doctor then
        docLevel = doctor:getPerkLevel(Perks.Doctor)
    elseif Perks.FirstAid then
        docLevel = doctor:getPerkLevel(Perks.FirstAid)
    end
    local maxTime = math.max(
        surgeryBalance.TIMED_ACTION_MIN,
        surgeryBalance.TIMED_ACTION_BASE
            - (docLevel * surgeryBalance.TIMED_ACTION_REDUCTION_PER_DOCTOR_LEVEL)
    )
    ISTimedActionQueue.add(NLExperimentalSurgeryAction:new(doctor, patient, surgeryType, eyeSlot, item, maxTime))
end

-- ============================================================================
-- 3. Dedicated Eye Panel UI (Pure Local Geometric Vector Art)
-- ============================================================================

NLEyePanelUI = ISCollapsableWindow:derive("NLEyePanelUI")
NLEyePanelUI.instance = nil

function NLEyePanelUI.openPanel(doctor, patient)
    doctor = doctor or getPlayer()
    patient = patient or doctor
    if not doctor or not patient then return end

    if NLEyePanelUI.instance then
        NLEyePanelUI.instance.doctor = doctor
        NLEyePanelUI.instance.patient = patient
        NLEyePanelUI.instance:setVisible(true)
        NLEyePanelUI.instance:bringToTop()
        NLEyePanelUI.instance:refreshData()
        return NLEyePanelUI.instance
    end

    local width = 480
    local height = 370
    local x = (getCore():getScreenWidth() - width) / 2
    local y = (getCore():getScreenHeight() - height) / 2

    local ui = NLEyePanelUI:new(x, y, width, height, doctor, patient)
    ui:initialise()
    ui:addToUIManager()
    ui:setVisible(true)
    ui:bringToTop()
    NLEyePanelUI.instance = ui
    return ui
end

function NLEyePanelUI:new(x, y, width, height, doctor, patient)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.doctor = doctor
    o.patient = patient
    o.title = getText("UI_NL_EyePanel_Title")
    o.resizable = false
    o.drawFrame = true
    return o
end

function NLEyePanelUI:initialise()
    ISCollapsableWindow.initialise(self)
end

function NLEyePanelUI:refreshData()
    if self.patient then
        NinjaLineages.initPlayerEyes(self.patient)
    end
end

function NLEyePanelUI:close()
    self:setVisible(false)
    self:removeFromUIManager()
    NLEyePanelUI.instance = nil
end

-- ----------------------------------------------------------------------------
-- Local Coordinate Vector Primitives (Bresenham & Scanlines using drawRect)
-- ----------------------------------------------------------------------------

function NLEyePanelUI:drawLocalLine(x0, y0, x1, y1, a, r, g, b, thickness)
    a = a or 1.0
    thickness = thickness or 1
    x0 = math.floor(x0 + 0.5)
    y0 = math.floor(y0 + 0.5)
    x1 = math.floor(x1 + 0.5)
    y1 = math.floor(y1 + 0.5)

    local dx = math.abs(x1 - x0)
    local dy = math.abs(y1 - y0)
    local sx = x0 < x1 and 1 or -1
    local sy = y0 < y1 and 1 or -1
    local err = dx - dy

    while true do
        self:drawRect(x0, y0, thickness, thickness, a, r, g, b)
        if x0 == x1 and y0 == y1 then break end
        local e2 = 2 * err
        if e2 > -dy then
            err = err - dy
            x0 = x0 + sx
        end
        if e2 < dx then
            err = err + dx
            y0 = y0 + sy
        end
    end
end

function NLEyePanelUI:drawSolidCircle(cx, cy, radius, r, g, b, a)
    a = a or 1.0
    for dy = -radius, radius do
        local dx = math.floor(math.sqrt(math.max(0, radius * radius - dy * dy)))
        self:drawRect(cx - dx, cy + dy, dx * 2 + 1, 1, a, r, g, b)
    end
end

function NLEyePanelUI:drawLocalRing(cx, cy, radius, r, g, b, a, thickness)
    a = a or 1.0
    thickness = thickness or 1
    local steps = math.max(24, math.floor(radius * 3.5))
    local prevX = cx + radius
    local prevY = cy
    for i = 1, steps do
        local angle = (i / steps) * math.pi * 2
        local nextX = cx + math.cos(angle) * radius
        local nextY = cy + math.sin(angle) * radius
        self:drawLocalLine(prevX, prevY, nextX, nextY, a, r, g, b, thickness)
        prevX = nextX
        prevY = nextY
    end
end

function NLEyePanelUI:drawAlmondSclera(cx, cy, rx, ry, r, g, b, a)
    a = a or 1.0
    -- Sclera Fill with subtle depth gradient
    for dy = -ry, ry do
        local normY = dy / ry
        local halfW = math.floor(rx * math.sqrt(math.max(0, 1.0 - normY * normY)))
        local shade = 0.96 - (normY < 0 and math.abs(normY) * 0.10 or 0)
        self:drawRect(cx - halfW, cy + dy, halfW * 2 + 1, 1, a, r * shade, g * shade, b * shade)
    end

    -- Soft pink inner canthus (tear duct)
    self:drawSolidCircle(cx - rx + 5, cy, 3, 0.86, 0.58, 0.58, a * 0.75)

    -- Upper Eyeliner & Lash Shade (thickness 2)
    local steps = 36
    local prevX = cx - rx
    local prevY = cy
    for i = 1, steps do
        local progress = (i / steps) * 2 - 1
        local currX = cx + progress * rx
        local topY = cy - ry * math.sqrt(math.max(0, 1.0 - progress * progress))
        self:drawLocalLine(prevX, prevY, currX, topY, a * 0.95, 0.12, 0.12, 0.16, 2)
        prevX = currX
        prevY = topY
    end

    -- Lower Eyelid Border (thickness 1)
    prevX = cx - rx
    prevY = cy
    for i = 1, steps do
        local progress = (i / steps) * 2 - 1
        local currX = cx + progress * rx
        local botY = cy + ry * math.sqrt(math.max(0, 1.0 - progress * progress))
        self:drawLocalLine(prevX, prevY, currX, botY, a * 0.75, 0.22, 0.22, 0.28, 1)
        prevX = currX
        prevY = botY
    end
end

-- ----------------------------------------------------------------------------
-- Ocular Artworks (Strictly Local)
-- ----------------------------------------------------------------------------

-- 1. Empty Socket
function NLEyePanelUI:drawEmptyArt(cx, cy, cardW, cardH)
    -- Dark recessed anatomical socket cavity
    self:drawRect(cx - 56, cy - 32, 112, 64, 0.95, 0.04, 0.04, 0.06)
    self:drawRectBorder(cx - 56, cy - 32, 112, 64, 0.9, 0.35, 0.15, 0.15)
    self:drawRectBorder(cx - 54, cy - 30, 108, 60, 0.4, 0.15, 0.08, 0.08)

    -- Surgical suture crosshatch
    for i = -36, 36, 18 do
        self:drawLocalLine(cx + i - 8, cy - 22, cx + i + 8, cy + 22, 0.35, 0.55, 0.25, 0.25, 1)
        self:drawLocalLine(cx + i + 8, cy - 22, cx + i - 8, cy + 22, 0.35, 0.55, 0.25, 0.25, 1)
        -- Suture knots
        self:drawSolidCircle(cx + i - 8, cy - 22, 1, 0.7, 0.3, 0.3, 0.5)
        self:drawSolidCircle(cx + i + 8, cy + 22, 1, 0.7, 0.3, 0.3, 0.5)
    end

    self:drawTextCentre(getText("UI_NL_Eye_Empty"), cx, cy - 8, 0.88, 0.30, 0.30, 1.0, UIFont.Small)
end

-- 2. Normal Eye
function NLEyePanelUI:drawNormalArt(cx, cy)
    self:drawAlmondSclera(cx, cy, 54, 28, 0.93, 0.93, 0.90, 1.0)
    
    -- Iris (Hazel / Amber)
    self:drawSolidCircle(cx, cy, 23, 0.42, 0.26, 0.14, 1.0)
    self:drawLocalRing(cx, cy, 23, 0.18, 0.10, 0.05, 1.0, 1)
    self:drawLocalRing(cx, cy, 22, 0.55, 0.35, 0.18, 0.8, 1)

    -- Radial iris fibers
    for a = 0, 11 do
        local rad = (a / 12) * math.pi * 2
        local x1 = cx + math.cos(rad) * 9
        local y1 = cy + math.sin(rad) * 9
        local x2 = cx + math.cos(rad) * 21
        local y2 = cy + math.sin(rad) * 21
        self:drawLocalLine(x1, y1, x2, y2, 0.45, 0.60, 0.40, 0.20, 1)
    end

    -- Pupil (Jet Black)
    self:drawSolidCircle(cx, cy, 9, 0.04, 0.04, 0.05, 1.0)

    -- Specular gloss glints
    self:drawSolidCircle(cx - 5, cy - 5, 3, 1.0, 1.0, 1.0, 0.92)
    self:drawSolidCircle(cx + 4, cy + 4, 1, 1.0, 1.0, 1.0, 0.65)
end

-- 3. Sharingan (Crimson Iris + Geometric Tomoes)
function NLEyePanelUI:drawSharinganArt(cx, cy, stage)
    self:drawAlmondSclera(cx, cy, 54, 28, 0.95, 0.95, 0.92, 1.0)

    -- Crimson Iris
    self:drawSolidCircle(cx, cy, 24, 0.92, 0.08, 0.12, 1.0)
    self:drawLocalRing(cx, cy, 24, 0.10, 0.02, 0.02, 1.0, 1)
    self:drawLocalRing(cx, cy, 16, 0.22, 0.03, 0.04, 0.85, 1)

    -- Center Black Pupil
    self:drawSolidCircle(cx, cy, 7, 0.03, 0.02, 0.02, 1.0)

    -- Tomoe marks (1, 2, or 3)
    local tomoeCount = math.max(1, math.min(3, stage or 3))
    local orbitRadius = 15
    for i = 1, tomoeCount do
        local angle = ((i - 1) * (2 * math.pi / tomoeCount)) - (math.pi / 2)
        local tx = cx + math.cos(angle) * orbitRadius
        local ty = cy + math.sin(angle) * orbitRadius
        
        -- Tomoe Head (Round)
        self:drawSolidCircle(tx, ty, 3, 0.03, 0.02, 0.02, 1.0)
        
        -- Tomoe Curved Tail
        for t = 1, 4 do
            local tailAngle = angle + (t * 0.18)
            local tailRad = orbitRadius + (t * 0.5)
            local ptx = cx + math.cos(tailAngle) * tailRad
            local pty = cy + math.sin(tailAngle) * tailRad
            local tailSize = math.max(1, 3 - t)
            self:drawSolidCircle(ptx, pty, tailSize, 0.03, 0.02, 0.02, 1.0)
        end
    end

    -- Specular Gloss Reflection
    self:drawSolidCircle(cx - 5, cy - 5, 3, 1.0, 1.0, 1.0, 0.90)
    self:drawSolidCircle(cx + 4, cy + 4, 1, 1.0, 1.0, 1.0, 0.60)
end

-- 4. Byakugan (Lilac Iris + Radiance + Bulging Hyuga Veins)
function NLEyePanelUI:drawByakuganArt(cx, cy)
    -- Branching Hyuga Ocular Vein Line Art (Left temple)
    local vColor = { r = 0.58, g = 0.52, b = 0.72, a = 0.85 }
    self:drawLocalLine(cx - 54, cy - 6,  cx - 72, cy - 18, vColor.a, vColor.r, vColor.g, vColor.b, 2)
    self:drawLocalLine(cx - 72, cy - 18, cx - 88, cy - 24, vColor.a * 0.8, vColor.r, vColor.g, vColor.b, 1)
    self:drawLocalLine(cx - 72, cy - 18, cx - 82, cy - 8,  vColor.a * 0.7, vColor.r, vColor.g, vColor.b, 1)
    self:drawLocalLine(cx - 54, cy + 6,  cx - 70, cy + 18, vColor.a, vColor.r, vColor.g, vColor.b, 2)
    self:drawLocalLine(cx - 70, cy + 18, cx - 86, cy + 24, vColor.a * 0.8, vColor.r, vColor.g, vColor.b, 1)

    -- Right temple veins
    self:drawLocalLine(cx + 54, cy - 6,  cx + 72, cy - 18, vColor.a, vColor.r, vColor.g, vColor.b, 2)
    self:drawLocalLine(cx + 72, cy - 18, cx + 88, cy - 24, vColor.a * 0.8, vColor.r, vColor.g, vColor.b, 1)
    self:drawLocalLine(cx + 72, cy - 18, cx + 82, cy - 8,  vColor.a * 0.7, vColor.r, vColor.g, vColor.b, 1)
    self:drawLocalLine(cx + 54, cy + 6,  cx + 70, cy + 18, vColor.a, vColor.r, vColor.g, vColor.b, 2)
    self:drawLocalLine(cx + 70, cy + 18, cx + 86, cy + 24, vColor.a * 0.8, vColor.r, vColor.g, vColor.b, 1)

    -- Sclera (Lavender/White Tint)
    self:drawAlmondSclera(cx, cy, 54, 28, 0.94, 0.94, 0.98, 1.0)

    -- Pearlescent Lilac Iris
    self:drawSolidCircle(cx, cy, 24, 0.88, 0.88, 0.97, 1.0)
    self:drawLocalRing(cx, cy, 24, 0.62, 0.60, 0.76, 1.0, 1)
    self:drawLocalRing(cx, cy, 23, 0.75, 0.74, 0.88, 0.8, 1)

    -- Pale Center Pupil
    self:drawSolidCircle(cx, cy, 11, 0.76, 0.76, 0.89, 1.0)
    self:drawLocalRing(cx, cy, 11, 0.58, 0.55, 0.72, 0.9, 1)

    -- Delicate Radial Chakra Striations
    for a = 0, 15 do
        local rad = (a / 16) * math.pi * 2
        local x1 = cx + math.cos(rad) * 11
        local y1 = cy + math.sin(rad) * 11
        local x2 = cx + math.cos(rad) * 23
        local y2 = cy + math.sin(rad) * 23
        self:drawLocalLine(x1, y1, x2, y2, 0.40, 0.65, 0.62, 0.80, 1)
    end
end

-- 5. Rinnegan (Sacred Ripple Rings)
function NLEyePanelUI:drawRinneganArt(cx, cy)
    self:drawAlmondSclera(cx, cy, 54, 28, 0.92, 0.92, 0.95, 1.0)

    -- Iris Base (Slate Violet)
    self:drawSolidCircle(cx, cy, 25, 0.64, 0.52, 0.78, 1.0)
    self:drawLocalRing(cx, cy, 25, 0.22, 0.15, 0.32, 1.0, 1)

    -- 4 Concentric Ripple Rings
    self:drawLocalRing(cx, cy, 19, 0.18, 0.12, 0.28, 0.95, 1)
    self:drawLocalRing(cx, cy, 13, 0.18, 0.12, 0.28, 0.95, 1)
    self:drawLocalRing(cx, cy, 7,  0.18, 0.12, 0.28, 0.95, 1)

    -- Center Black Pupil
    self:drawSolidCircle(cx, cy, 3, 0.04, 0.04, 0.06, 1.0)

    -- Specular Gloss Reflection
    self:drawSolidCircle(cx - 5, cy - 5, 2, 1.0, 1.0, 1.0, 0.75)
end

-- ----------------------------------------------------------------------------
-- UI Layout & Slot Rendering
-- ----------------------------------------------------------------------------

function NLEyePanelUI:renderEyeSlot(slotName, x, y, w, h, eyeData, stage)
    local isOccupied = eyeData ~= nil and eyeData.type ~= nil
    local eyeType = isOccupied and eyeData.type or "empty"
    local freshness = isOccupied and (
        eyeData.freshness
        or NinjaLineages.Balance.GeneExperimentation.Extraction.MAX_ROLL_FRESHNESS
    ) or 0

    -- Background Card Box
    local isHovered = self:isMouseOverSlot(x, y, w, h)
    local bgAlpha = isHovered and 0.96 or 0.88
    self:drawRect(x, y, w, h, bgAlpha, 0.09, 0.09, 0.13)
    local borderColor = isHovered and { r = 0.58, g = 0.68, b = 0.88 } or { r = 0.28, g = 0.30, b = 0.38 }
    self:drawRectBorder(x, y, w, h, 1.0, borderColor.r, borderColor.g, borderColor.b)

    -- Slot Title (Left Eye / Right Eye)
    local slotLabel = slotName == "left" and getText("UI_NL_Eye_Left") or getText("UI_NL_Eye_Right")
    self:drawTextCentre(slotLabel, x + w / 2, y + 10, 1.0, 1.0, 1.0, 1.0, UIFont.Medium)

    -- Eye Vector Art Center
    local artCenterX = x + w / 2
    local artCenterY = y + 84

    if not isOccupied or eyeType == "empty" then
        self:drawEmptyArt(artCenterX, artCenterY, w, h)
    elseif eyeType == "sharingan" then
        self:drawSharinganArt(artCenterX, artCenterY, stage)
    elseif eyeType == "byakugan" then
        self:drawByakuganArt(artCenterX, artCenterY)
    elseif eyeType == "rinnegan" then
        self:drawRinneganArt(artCenterX, artCenterY)
    else
        self:drawNormalArt(artCenterX, artCenterY)
    end

    -- Eye Type Label
    local typeLabel = getText("UI_NL_Eye_Normal")
    if not isOccupied or eyeType == "empty" then
        typeLabel = getText("UI_NL_Eye_Empty")
    elseif eyeType == "sharingan" then
        typeLabel = getText("UI_NL_Eye_Sharingan")
    elseif eyeType == "byakugan" then
        typeLabel = getText("UI_NL_Eye_Byakugan")
    elseif eyeType == "rinnegan" then
        typeLabel = getText("UI_NL_Eye_Rinnegan")
    end
    self:drawTextCentre(typeLabel, x + w / 2, y + 140, 0.92, 0.92, 0.92, 1.0, UIFont.Small)

    -- Freshness % or Empty Indicator
    if isOccupied then
        local freshStr = string.format(getText("UI_NL_Eye_Freshness"), math.floor(freshness))
        local fr, fg, fb = 0.4, 0.85, 0.4
        if freshness < 50 then
            fr, fg, fb = 0.9, 0.3, 0.3
        elseif freshness < 75 then
            fr, fg, fb = 0.9, 0.8, 0.3
        end
        self:drawTextCentre(freshStr, x + w / 2, y + 158, fr, fg, fb, 1.0, UIFont.Small)
    else
        self:drawTextCentre(getText("UI_NL_Eye_Empty"), x + w / 2, y + 158, 0.55, 0.55, 0.65, 0.8, UIFont.Small)
    end

    -- Action Hint
    local hintText = isOccupied and "(Right-Click: Remove)" or "(Right-Click: Implant)"
    self:drawTextCentre(hintText, x + w / 2, y + 184, 0.65, 0.70, 0.80, 0.9, UIFont.Small)
end

function NLEyePanelUI:isMouseOverSlot(x, y, w, h)
    local mouseX = self:getMouseX()
    local mouseY = self:getMouseY()
    return mouseX >= x and mouseX <= x + w and mouseY >= y and mouseY <= y + h
end

function NLEyePanelUI:prerender()
    ISCollapsableWindow.prerender(self)
end

function NLEyePanelUI:render()
    ISCollapsableWindow.render(self)

    if not self.patient or self.patient:isDead() then return end
    NinjaLineages.initPlayerEyes(self.patient)
    local data = NinjaLineages.getNLData(self.patient) or {}
    local eyes = data.eyes or {}
    local stage = NinjaLineages.getSharinganStage and NinjaLineages.getSharinganStage(self.patient) or 3

    -- Header Info: Centered Patient Name
    local patientName = self.patient:getDescriptor() and self.patient:getDescriptor():getForename() .. " " .. self.patient:getDescriptor():getSurname() or "Patient"
    self:drawTextCentre(patientName, self.width / 2, 28, 1.0, 1.0, 1.0, 1.0, UIFont.Medium)

    -- Surgeon Status Badge
    local isUnlocked = NinjaLineages.Progression.isCompleted(self.doctor, "experimental_surgeries")
    local statusText = isUnlocked and "[Surgeon: Qualified]" or "[Surgeon: Locked]"
    local statusColor = isUnlocked and { r = 0.4, g = 0.85, b = 0.4 } or { r = 0.85, g = 0.35, b = 0.35 }
    self:drawTextRight(statusText, self.width - 25, 30, statusColor.r, statusColor.g, statusColor.b, 1.0, UIFont.Small)

    -- Symmetrically balanced Left and Right Eye Slots
    local cardW = 205
    local cardH = 220
    local slotY = 56
    local leftX = 25
    local rightX = self.width - 25 - cardW

    self:renderEyeSlot("left", leftX, slotY, cardW, cardH, eyes.left, stage)
    self:renderEyeSlot("right", rightX, slotY, cardW, cardH, eyes.right, stage)

    -- Footer Hint
    self:drawTextCentre(getText("UI_NL_EyePanel_Hint"), self.width / 2, self.height - 30, 0.75, 0.75, 0.80, 1.0, UIFont.Small)
end

function NLEyePanelUI:onRightMouseUp(x, y)
    local cardW = 205
    local cardH = 220
    local slotY = 56
    local leftX = 25
    local rightX = self.width - 25 - cardW

    local slot = nil
    if x >= leftX and x <= leftX + cardW and y >= slotY and y <= slotY + cardH then
        slot = "left"
    elseif x >= rightX and x <= rightX + cardW and y >= slotY and y <= slotY + cardH then
        slot = "right"
    end

    if slot then
        self:openEyeContextMenu(slot, self:getX() + x, self:getY() + y)
        return true
    end
    return false
end

function NLEyePanelUI:openEyeContextMenu(eyeSlot, screenX, screenY)
    local doctor = self.doctor
    local patient = self.patient
    if not doctor or not patient or doctor:isDead() or patient:isDead() then return end

    local playerNum = doctor:getPlayerNum()
    local context = ISContextMenu.get(playerNum, screenX, screenY)
    if not context then return end

    local isUnlocked = NinjaLineages.Progression.isCompleted(doctor, "experimental_surgeries")
    if not isUnlocked then
        local lockedOpt = context:addOption(getText("UI_NL_Surgery_Menu"))
        lockedOpt.notAvailable = true
        local tooltip = ISWorldObjectContextMenu.addToolTip()
        tooltip.description = getText("UI_NL_EyePanel_LockedTooltip")
        lockedOpt.toolTip = tooltip
        return
    end

    NinjaLineages.initPlayerEyes(patient)
    local patientData = NinjaLineages.getNLData(patient)
    if not patientData or not patientData.eyes then return end

    local currentEye = patientData.eyes[eyeSlot]

    if currentEye ~= nil then
        -- 1. Remove Eye Option
        local freshness = currentEye.freshness
            or NinjaLineages.Balance.GeneExperimentation.Extraction.MAX_ROLL_FRESHNESS
        local typeName = currentEye.type == "sharingan" and getText("UI_NL_Ability_Sharingan_Name")
            or (currentEye.type == "byakugan" and getText("UI_NL_Ability_Byakugan_Name")
            or (currentEye.type == "rinnegan" and getText("UI_NL_Eye_Rinnegan") or getText("UI_NL_Eye_Normal")))
        local removeLabel = (eyeSlot == "left" and getText("UI_NL_Surgery_RemoveLeftEye") or getText("UI_NL_Surgery_RemoveRightEye"))
            .. " (" .. typeName .. " " .. math.floor(freshness) .. "%)"

        context:addOption(removeLabel, doctor, onPerformSurgery, patient, "remove_eye", eyeSlot)
    else
        -- 2. Implant Eye Option
        local ocularSamples = getOcularSamples(doctor)
        local implantLabel = eyeSlot == "left" and getText("UI_NL_Surgery_ImplantLeftEye") or getText("UI_NL_Surgery_ImplantRightEye")
        local implantOption = context:addOption(implantLabel)

        if #ocularSamples > 0 then
            local subMenu = context:getNew(context)
            context:addSubMenu(implantOption, subMenu)
            for _, sample in ipairs(ocularSamples) do
                subMenu:addOption(sample.label, doctor, onPerformSurgery, patient, "implant_eye", eyeSlot, sample.item)
            end
        else
            implantOption.notAvailable = true
            local tooltip = ISWorldObjectContextMenu.addToolTip()
            tooltip.description = getText("UI_NL_Surgery_NoOcularSamples")
            implantOption.toolTip = tooltip
        end
    end

    -- 3. Implant Genes Option
    local geneSamples = getGeneSamples(doctor)
    local implantGenesOption = context:addOption(getText("UI_NL_Surgery_ImplantGenes"))
    if #geneSamples > 0 then
        local genesSubMenu = context:getNew(context)
        context:addSubMenu(implantGenesOption, genesSubMenu)
        for _, sample in ipairs(geneSamples) do
            genesSubMenu:addOption(sample.label, doctor, onPerformSurgery, patient, "implant_genes", nil, sample.item)
        end
    else
        implantGenesOption.notAvailable = true
        local tooltip = ISWorldObjectContextMenu.addToolTip()
        tooltip.description = getText("UI_NL_Surgery_NoGeneSamples")
        implantGenesOption.toolTip = tooltip
    end
end

-- ============================================================================
-- 4. Hook Health Panel Button Integration & Clean Single-Pass Height Calculation
-- ============================================================================

local UI_BORDER_SPACING = 10
local function getFontHgtSmall()
    if getTextManager() and UIFont and UIFont.Small then
        return getTextManager():getFontHeight(UIFont.Small)
    end
    return 14
end

local original_createChildren = ISHealthPanel.createChildren
function ISHealthPanel:createChildren()
    original_createChildren(self)

    local btnX = self.fitness and self.fitness:getX() or (self.listbox and self.listbox.x or 10)
    local btnY = self.fitness and (self.fitness:getY() + self.fitness:getHeight() + 4) or 40
    local btnW = self.fitness and self.fitness:getWidth() or 100
    local btnH = self.fitness and self.fitness:getHeight() or 24

    self.nlEyePanelBtn = ISButton:new(btnX, btnY, btnW, btnH, getText("UI_NL_EyePanel_Button"), self, function(healthPanel)
        local doc = healthPanel.otherPlayer or healthPanel.character
        local patient = healthPanel.character
        NLEyePanelUI.openPanel(doc, patient)
    end)
    self.nlEyePanelBtn.internal = "NL_EYE_PANEL"
    self.nlEyePanelBtn.anchorTop = false
    self.nlEyePanelBtn.anchorBottom = true
    self.nlEyePanelBtn:initialise()
    self.nlEyePanelBtn:instantiate()
    self:addChild(self.nlEyePanelBtn)

    self.nlJinchuurikiPanelBtn = ISButton:new(btnX, btnY + btnH + 4, btnW, btnH,
        getText("UI_NL_Jinchuuriki_PanelButton"), self, function(healthPanel)
            NinjaLineages.JinchuurikiPanel.openPanel(healthPanel.character)
        end)
    self.nlJinchuurikiPanelBtn.internal = "NL_JINCHUURIKI_PANEL"
    self.nlJinchuurikiPanelBtn.anchorTop = false
    self.nlJinchuurikiPanelBtn.anchorBottom = true
    self.nlJinchuurikiPanelBtn:initialise()
    self.nlJinchuurikiPanelBtn:instantiate()
    self:addChild(self.nlJinchuurikiPanelBtn)
end

function ISHealthPanel:render()
    if self.otherPlayer then
        self.fitness:setVisible(false)
        if self.nlEyePanelBtn then self.nlEyePanelBtn:setVisible(false) end
        if self.nlJinchuurikiPanelBtn then self.nlJinchuurikiPanelBtn:setVisible(false) end
    end

    local fontHgt = getFontHgtSmall()
    local spacing = UI_BORDER_SPACING
    local y = self.healthPanel.y

    self.fitness:setY(y)

    if self.nlEyePanelBtn and not self.otherPlayer then
        self.nlEyePanelBtn:setVisible(true)
        self.nlEyePanelBtn:setX(self.fitness:getX())
        self.nlEyePanelBtn:setY(self.fitness:getY() + self.fitness:getHeight() + 4)
        self.nlEyePanelBtn:setWidth(self.fitness:getWidth())

        local doctor = self.otherPlayer or self.character
        local isUnlocked = NinjaLineages.Progression.isCompleted(doctor, "experimental_surgeries")
        self.nlEyePanelBtn.enable = isUnlocked
        if not isUnlocked then
            self.nlEyePanelBtn.tooltip = getText("UI_NL_EyePanel_LockedTooltip")
        else
            self.nlEyePanelBtn.tooltip = nil
        end

        y = self.nlEyePanelBtn:getY() + self.nlEyePanelBtn:getHeight() + 6
    else
        y = y + spacing + fontHgt + 6
    end

    if self.nlJinchuurikiPanelBtn and not self.otherPlayer then
        local showJinchuuriki = NinjaLineages.Progression.isDisciplineVisible(self.character, "jinchuuriki")
            and not NinjaLineages.Progression.isDisciplineLocked(self.character, "jinchuuriki")
        self.nlJinchuurikiPanelBtn:setVisible(showJinchuuriki)
        if showJinchuuriki then
            self.nlJinchuurikiPanelBtn:setX(self.fitness:getX())
            self.nlJinchuurikiPanelBtn:setY(y)
            self.nlJinchuurikiPanelBtn:setWidth(self.fitness:getWidth())
            self.nlJinchuurikiPanelBtn.enable = true
            self.nlJinchuurikiPanelBtn.tooltip = nil
            y = self.nlJinchuurikiPanelBtn:getY() + self.nlJinchuurikiPanelBtn:getHeight() + 6
        end
    end

    self:drawText(getText("IGUI_health_Overall_Body_Status"), self.healthPanel:getRight() + spacing, y, 1.0, 1.0, 1.0, 1.0, UIFont.Small)
    y = y + fontHgt

    local InjuryRedTextTint = (100 - self:getPatient():getBodyDamage():getHealth()) / 100
    InjuryRedTextTint = math.max(InjuryRedTextTint, 0.2)
    local str = self.healthPanel.javaObject:getDamageStatusString()
    self:drawText(str, self.healthPanel:getRight() + spacing, y, 1.0, 1.0 - InjuryRedTextTint, 1.0 - InjuryRedTextTint, 1.0, UIFont.Small)
    y = y + fontHgt

    local x = self.healthPanel:getRight() + spacing
    local doctor = self.otherPlayer or self.character

    if doctor:getJoypadBind() ~= -1 then
        self:drawTextureScaled(self.abutton, spacing, self.height - spacing - fontHgt, fontHgt, fontHgt, 1.0, 1.0, 1.0, 1.0)
        self:drawText(getText("IGUI_health_JoypadTreatment"), spacing + fontHgt + 2, self.height - spacing - fontHgt, 1, 1, 1, 1, UIFont.Small)
    else
        self:drawText(getText("IGUI_health_RightClickTreatement"), spacing, self.height - spacing - fontHgt, 1, 1, 1, 1, UIFont.Small)
    end

    local painLevel = self:getPatient():getMoodles():getMoodleLevel(MoodleType.PAIN)
    if isClient() and not self:getPatient():isLocalPlayer() then
        painLevel = self:getPatient():getBodyDamageRemote():getRemotePainLevel()
    end
    if (ISHealthPanel.cheat or (doctor == self.otherPlayer and (self.doctorLevel or 0) > 4)) and painLevel > 0 then
        self:drawText(getText("Moodles_Pain_lvl" .. painLevel), x, y, 1, 1, 1, 1, UIFont.Small)
        y = y + fontHgt
    end
    if self.cheat and self.character:getStats():get(CharacterStat.ZOMBIE_FEVER) > 0 then
        self:drawText("Zombie Fever " .. self.character:getStats():get(CharacterStat.ZOMBIE_FEVER), x, y, 1, 1, 1, 1, UIFont.Small)
        y = y + fontHgt
    end
    if self.cheat and self.character:getReduceInfectionPower() > 0 then
        self:drawText("Antibiotic level " .. self.character:getReduceInfectionPower(), x, y, 1, 1, 1, 1, UIFont.Small)
        y = y + fontHgt
    end

    local listItemsHeight = self.listbox:getScrollHeight()
    local myHeight = y + listItemsHeight + fontHgt + spacing * 2
    local myY = self:getY()
    local parent = self.parent
    while parent and parent.parent do
        myY = myY + parent:getY()
        parent = parent.parent
    end
    if myY + myHeight > getCore():getScreenHeight() then
        myHeight = getCore():getScreenHeight() - myY
    end
    self.listbox:setY(y)
    self.listbox:setHeight(myHeight - (fontHgt + spacing * 2) - y)
    self.listbox.vscroll:setHeight(self.listbox:getHeight())
    self.allTextHeight = myHeight - (fontHgt + spacing * 2)

    if self.blockingMessage then
        self:drawRect(0, 0, self.width, self.height, 0.9 * (self.blockingAlpha or 1.0), 0, 0, 0)
        self:drawText(self.blockingMessage, self.width / 2 - (getTextManager():MeasureStringX(UIFont.Medium, self.blockingMessage) / 2), (self.height / 2) - 5, 1, 1, 1, 1, UIFont.Medium)
    end
end

function ISHealthPanel:update()
    ISPanelJoypad.update(self)
    if self.otherPlayer then
        local dist = self.character:DistToProper(self.otherPlayer)
        if dist > patientRange then
            if not self.blockingMessage then 
                self:getDoctor():stopReceivingBodyDamageUpdates(self:getPatient())
                self:getPatient():getBodyDamageRemote():RestoreToFullHealth() 
                self.listbox:clear()
                self.damagedParts = {}
                self.textRight = 0
                self.listbox.textRight = 0
            end
            self.blockingMessage = getText("IGUI_TradingUI_TooFarAway", self.character:getDisplayName())
            self.blockingAlpha = math.min(1.0, self.blockingAlpha + 0.05)
            return
        else
            if self.blockingMessage then self:getDoctor():startReceivingBodyDamageUpdates(self:getPatient()) end
            self.blockingMessage = nil
            self.blockingAlpha = math.max(0.0, self.blockingAlpha - 0.05)
        end
    end
    if self:isReallyVisible() then
        self:updateBodyPartList()
        self.listbox:setWidth(self.width - self.listbox.x - UI_BORDER_SPACING - 1)

        local width = math.max(self.tabtotalwidth, self.healthPanel:getRight(), self.fitness:getRight(), self.listbox.x + self.listbox.textRight)
        self:setWidthAndParentWidth(width + UI_BORDER_SPACING + 1)

        local fontHgt = getFontHgtSmall()
        local extraH = (self.nlEyePanelBtn and self.nlEyePanelBtn:isVisible() and not self.otherPlayer) and (self.nlEyePanelBtn:getHeight() + 6) or 0
        if self.nlJinchuurikiPanelBtn and self.nlJinchuurikiPanelBtn:isVisible() and not self.otherPlayer then
            extraH = extraH + self.nlJinchuurikiPanelBtn:getHeight() + 6
        end
        local totalH = math.max(self.healthPanel:getBottom(), self.allTextHeight or 0) + fontHgt + UI_BORDER_SPACING * 2 + extraH
        self:setHeightAndParentHeight(totalH)

        MusicIntensityConfig.getInstance():checkHealthPanelVisible(self.otherPlayer or self.character)
    else
        self.textRight = 0
        self.listbox.textRight = 0
    end
end
