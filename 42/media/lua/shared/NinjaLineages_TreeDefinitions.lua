require "NinjaLineages_JutsuCatalog"

NinjaLineages = NinjaLineages or {}
NinjaLineages.TreeDefinitions = NinjaLineages.TreeDefinitions or {}

local Trees = NinjaLineages.TreeDefinitions
local Catalog = NinjaLineages.JutsuCatalog

Trees.Disciplines = Catalog.Disciplines
Trees.DisciplineOrder = Catalog.DisciplineOrder
Trees.Nodes = {}

for _, definition in ipairs(Catalog.getAll()) do
    if definition.node then
        local node = definition.node
        local view = definition.presentation or {}
        Trees.Nodes[definition.id] = {
            id = definition.id,
            discipline = node.discipline,
            tier = node.rank,
            order = node.order,
            prerequisites = node.prerequisites or {},
            effectType = node.effectType,
            name = "UI_NL_Node_" .. definition.id .. "_Name",
            description = "UI_NL_Node_" .. definition.id .. "_Desc",
            nameFallback = view.nameFallback or definition.id,
            descriptionFallback = view.descriptionFallback or "",
            icon = "media/ui/jutsuTree/nodes/" .. definition.id .. ".png",
            fallbackIcon = "media/ui/NLJutsu.png",
            trainingItem = "Base.NL_Training_" .. definition.id,
            abilityId = definition.selectable ~= false and definition.id or nil,
        }
    end
end

function Trees.getNode(id)
    return Trees.Nodes[id]
end

function Trees.getNodesForDiscipline(disciplineId)
    local result = {}
    for _, catalogDefinition in ipairs(Catalog.getNodesForDiscipline(disciplineId)) do
        table.insert(result, Trees.Nodes[catalogDefinition.id])
    end
    return result
end
