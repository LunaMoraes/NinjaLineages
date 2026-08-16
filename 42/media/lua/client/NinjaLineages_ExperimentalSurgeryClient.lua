require "TimedActions/ISBaseTimedAction"
require "XpSystem/ISUI/ISHealthPanel"
require "NinjaLineages_Progression"
require "NinjaLineages_Utils"
require "NinjaLineages_Traits"
require "NinjaLineages_Constants"

NinjaLineages = NinjaLineages or {}
NinjaLineages.ExperimentalSurgeryClient = NinjaLineages.ExperimentalSurgeryClient or {}

local SurgeryClient = NinjaLineages.ExperimentalSurgeryClient

local function getItemFreshness(item)
    if not item then return 100 end
    local offAgeMax = (item.getOffAgeMax and item:getOffAgeMax()) or 0
    local age = (item.getAge and item:getAge()) or 0
    if offAgeMax > 0 then
        if item.isRotten and item:isRotten() then return 0 end
        local remaining = math.max(0, math.min(1.0, 1.0 - (age / offAgeMax)))
        return math.floor(remaining * 100 + 0.5)
    end
    return item:getModData().freshness or 100
end

local function getOcularSamples(doctor)
    local list = {}
    local inv = doctor:getInventory()
    if not inv then return list end
    local items = inv:getItemsFromType("Base.NL_OcularTissueSample")
    if not items then return list end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and not (item.isRotten and item:isRotten()) then
            local freshness = getItemFreshness(item)
            local eyeType = item:getModData().eyeType or "sharingan"
            local typeName = eyeType == "sharingan" and getText("UI_NL_Ability_Sharingan_Name")
                or (eyeType == "byakugan" and getText("UI_NL_Ability_Byakugan_Name") or getText("UI_NL_Ability_ShinraTensei_Name"))
            local label = typeName .. " (" .. freshness .. "%)"
            table.insert(list, {
                item = item,
                label = label,
                freshness = freshness,
                eyeType = eyeType,
            })
        end
    end
    return list
end

local function getGeneSamples(doctor)
    local list = {}
    local inv = doctor:getInventory()
    if not inv then return list end
    local items = inv:getItemsFromType("Base.NL_GeneSample")
    if not items then return list end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
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
-- Timed Action Definition
-- ============================================================================

NLExperimentalSurgeryAction = ISBaseTimedAction:derive("NLExperimentalSurgeryAction")

function NLExperimentalSurgeryAction:isValid()
    if not self.character or self.character:isDead() then return false end
    if not self.patient or self.patient:isDead() then return false end
    if self.character ~= self.patient and self.character:DistTo(self.patient) > 2.5 then return false end
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
    o.maxTime = maxTime or 300
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
    local maxTime = math.max(120, 350 - (docLevel * 20))
    ISTimedActionQueue.add(NLExperimentalSurgeryAction:new(doctor, patient, surgeryType, eyeSlot, item, maxTime))
end

-- ============================================================================
-- Hook Health Panel Body Part Context Menu
-- ============================================================================

local original_doBodyPartContextMenu = ISHealthPanel.doBodyPartContextMenu
function ISHealthPanel:doBodyPartContextMenu(bodyPart, x, y)
    original_doBodyPartContextMenu(self, bodyPart, x, y)

    if not bodyPart or bodyPart:getType() ~= BodyPartType.Head then return end

    local doctor = self.otherPlayer or self.character
    local patient = self.character
    if not doctor or not patient or doctor:isDead() or patient:isDead() then return end

    if not NinjaLineages.Progression.isCompleted(doctor, "experimental_surgeries") then return end

    local playerNum = doctor:getPlayerNum()
    local context = ISContextMenu.get(playerNum, x + self:getAbsoluteX(), y + self:getAbsoluteY())
    if not context then return end

    NinjaLineages.initPlayerEyes(patient)
    local patientData = NinjaLineages.getNLData(patient)
    if not patientData or not patientData.eyes then return end

    local surgeryOption = context:addOption(getText("UI_NL_Surgery_Menu"))
    local surgerySubMenu = context:getNew(context)
    context:addSubMenu(surgeryOption, surgerySubMenu)

    -- Left eye removal (only shows if left eye is full/occupied)
    if patientData.eyes.left ~= nil then
        local freshness = patientData.eyes.left.freshness or 100
        local label = getText("UI_NL_Surgery_RemoveLeftEye")
        if freshness < 100 then
            label = label .. " (" .. math.floor(freshness) .. "%)"
        end
        surgerySubMenu:addOption(label, doctor, onPerformSurgery, patient, "remove_eye", "left")
    else
        -- Left eye implant (only shows if left eye is empty)
        local ocularSamples = getOcularSamples(doctor)
        local implantLeftOption = surgerySubMenu:addOption(getText("UI_NL_Surgery_ImplantLeftEye"))
        if #ocularSamples > 0 then
            local leftSubMenu = context:getNew(surgerySubMenu)
            surgerySubMenu:addSubMenu(implantLeftOption, leftSubMenu)
            for _, sample in ipairs(ocularSamples) do
                leftSubMenu:addOption(sample.label, doctor, onPerformSurgery, patient, "implant_eye", "left", sample.item)
            end
        else
            implantLeftOption.notAvailable = true
            local tooltip = ISWorldObjectContextMenu.addToolTip()
            tooltip.description = getText("UI_NL_Surgery_NoOcularSamples")
            implantLeftOption.toolTip = tooltip
        end
    end

    -- Right eye removal (only shows if right eye is full/occupied)
    if patientData.eyes.right ~= nil then
        local freshness = patientData.eyes.right.freshness or 100
        local label = getText("UI_NL_Surgery_RemoveRightEye")
        if freshness < 100 then
            label = label .. " (" .. math.floor(freshness) .. "%)"
        end
        surgerySubMenu:addOption(label, doctor, onPerformSurgery, patient, "remove_eye", "right")
    else
        -- Right eye implant (only shows if right eye is empty)
        local ocularSamples = getOcularSamples(doctor)
        local implantRightOption = surgerySubMenu:addOption(getText("UI_NL_Surgery_ImplantRightEye"))
        if #ocularSamples > 0 then
            local rightSubMenu = context:getNew(surgerySubMenu)
            surgerySubMenu:addSubMenu(implantRightOption, rightSubMenu)
            for _, sample in ipairs(ocularSamples) do
                rightSubMenu:addOption(sample.label, doctor, onPerformSurgery, patient, "implant_eye", "right", sample.item)
            end
        else
            implantRightOption.notAvailable = true
            local tooltip = ISWorldObjectContextMenu.addToolTip()
            tooltip.description = getText("UI_NL_Surgery_NoOcularSamples")
            implantRightOption.toolTip = tooltip
        end
    end

    -- Implant Genes
    local geneSamples = getGeneSamples(doctor)
    local implantGenesOption = surgerySubMenu:addOption(getText("UI_NL_Surgery_ImplantGenes"))
    if #geneSamples > 0 then
        local genesSubMenu = context:getNew(surgerySubMenu)
        surgerySubMenu:addSubMenu(implantGenesOption, genesSubMenu)
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
