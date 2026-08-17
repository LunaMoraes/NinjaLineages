require "TimedActions/ISBaseTimedAction"
require "XpSystem/ISUI/ISHealthPanel"
require "NinjaLineages_Progression"
require "NinjaLineages_Utils"
require "NinjaLineages_Traits"
require "NinjaLineages_Constants"

NinjaLineages = NinjaLineages or {}
NinjaLineages.BloodTransfusionClient = NinjaLineages.BloodTransfusionClient or {}

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

local function getBloodSamples(doctor)
    local list = {}
    local inv = doctor and doctor:getInventory()
    if not inv then return list end
    local items = NinjaLineages.Utils.Inventory.collectItems(inv, "Base.NL_BloodSample")
    for _, item in ipairs(items) do
        if item and not (item.isRotten and item:isRotten()) then
            local freshness = getItemFreshness(item)
            if freshness > 0 then
                local label = getText("UI_NL_BloodSample_Label") .. " (" .. freshness .. "%)"
                table.insert(list, {
                    item = item,
                    label = label,
                    freshness = freshness,
                })
            end
        end
    end
    return list
end

-- Timed action for blood transfusion
NLBloodTransfusionAction = ISBaseTimedAction:derive("NLBloodTransfusionAction")

function NLBloodTransfusionAction:isValid()
    if not self.character or self.character:isDead() then return false end
    if not self.patient or self.patient:isDead() then return false end
    if self.character ~= self.patient and self.character:DistTo(self.patient) > 2.5 then return false end
    if not self.item or not self.character:getInventory():contains(self.item) then return false end
    if self.item.isRotten and self.item:isRotten() then return false end
    return true
end

function NLBloodTransfusionAction:start()
    self:setActionAnim("Medical")
    self.character:reportEvent("EventTakePills")
end

function NLBloodTransfusionAction:update()
    self.character:faceThisObject(self.patient)
end

function NLBloodTransfusionAction:stop()
    ISBaseTimedAction.stop(self)
end

function NLBloodTransfusionAction:perform()
    if NinjaLineages.isClient() then
        sendClientCommand(self.character, "NinjaLineages", "performBloodTransfusion", {
            patientOnlineId = self.patient:getOnlineID(),
            itemId = self.item:getID(),
        })
    else
        if NinjaLineages.GeneExperimentationServer and NinjaLineages.GeneExperimentationServer.transfuseBlood then
            NinjaLineages.GeneExperimentationServer.transfuseBlood(self.character, self.patient, self.item:getID())
        end
    end
    ISBaseTimedAction.perform(self)
end

function NLBloodTransfusionAction:new(character, patient, item)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.patient = patient
    o.item = item
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = 120
    return o
end

local function onPerformBloodTransfusion(doctor, patient, item)
    if not doctor or not patient or not item then return end
    if luautils.walkAdj(doctor, patient:getCurrentSquare()) then
        ISTimedActionQueue.add(NLBloodTransfusionAction:new(doctor, patient, item))
    end
end

-- Health Panel context menu hook
local original_doBodyPartContextMenu = ISHealthPanel.doBodyPartContextMenu

function ISHealthPanel:doBodyPartContextMenu(bodyPart, x, y)
    original_doBodyPartContextMenu(self, bodyPart, x, y)

    local doctor = self.character
    local patient = self.otherPlayer or doctor
    if not doctor or not patient then return end

    if not NinjaLineages.Progression.isCompleted(doctor, "blood_extraction") then
        return
    end

    local context = getPlayerContextMenu(self.playerNum)
    if not context then return end

    local bloodSamples = getBloodSamples(doctor)
    local transfusionOption = context:addOption(getText("UI_NL_Surgery_BloodTransfusion"))

    if #bloodSamples > 0 then
        local subMenu = context:getNew(context)
        context:addSubMenu(transfusionOption, subMenu)
        for _, sample in ipairs(bloodSamples) do
            subMenu:addOption(sample.label, doctor, onPerformBloodTransfusion, patient, sample.item)
        end
    else
        transfusionOption.notAvailable = true
        local tooltip = ISWorldObjectContextMenu.addToolTip()
        tooltip.description = getText("UI_NL_Surgery_NoBloodSamples")
        transfusionOption.toolTip = tooltip
    end
end
