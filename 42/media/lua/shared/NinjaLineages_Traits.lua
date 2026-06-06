NinjaLineages = NinjaLineages or {}

NinjaLineages.TRAIT_BYAKUGAN = "NinjaLineages:byakugan"
NinjaLineages.TRAIT_SHARINGAN = "NinjaLineages:sharingan"
NinjaLineages.TRAIT_SENJU = "NinjaLineages:senju"

-- Traits are registered via NinjaLineages_traits.txt in Build 42


-- Hook into foraging system to register Byakugan vision bonuses
local function addForageSkillDefs(forageSystemInstance)
    if forageSystemInstance and forageSystemInstance.forageSkillDefinitions then
        forageSystemInstance.forageSkillDefinitions[NinjaLineages.TRAIT_BYAKUGAN] = {
            name = NinjaLineages.TRAIT_BYAKUGAN,
            type = "trait",
            visionBonus = 5.0,      -- Substantial search radius expansion
            weatherEffect = 100,    -- Immune to weather foraging penalty
            darknessEffect = 100,   -- Immune to darkness foraging penalty
            specialisations = {}
        }
    end
end

-- Use the foraging system's initialization hook
if Events.preAddSkillDefs then
    Events.preAddSkillDefs.Add(addForageSkillDefs)
end
