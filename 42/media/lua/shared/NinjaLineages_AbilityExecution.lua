require "NinjaLineages_Traits"
require "NinjaLineages_AbilityAuthority"
require "NinjaLineages_Progression"
require "NinjaLineages_Chakra"
require "NinjaLineages_Balance"
require "NinjaLineages_JutsuCatalog"
require "NinjaLineages_RinneganMechanics"
require "NinjaLineages_Items"
require "lineages/NinjaLineages_KamuiState"
require "disciplines/NinjaLineages_ScrollUtils"
require "combat/NinjaLineages_EarthWall"

NinjaLineages = NinjaLineages or {}
NinjaLineages.AbilityExecution = NinjaLineages.AbilityExecution or {}
NinjaLineages.AbilityExecution.active = NinjaLineages.AbilityExecution.active or {}
NinjaLineages.AbilityExecution.boundZombies = NinjaLineages.AbilityExecution.boundZombies or {}
NinjaLineages.AbilityExecution.sharinganRolls = NinjaLineages.AbilityExecution.sharinganRolls or {}

NinjaLineages.AbilityExecution.specializedExecutors = NinjaLineages.AbilityExecution.specializedExecutors or {}
NinjaLineages.AbilityExecution.genericEffects = NinjaLineages.AbilityExecution.genericEffects or {}

function NinjaLineages.AbilityExecution.registerSpecializedExecutor(name, func)
    NinjaLineages.AbilityExecution.specializedExecutors[name] = func
end

function NinjaLineages.AbilityExecution.registerGenericEffect(kind, func)
    NinjaLineages.AbilityExecution.genericEffects[kind] = func
end


-- Load refactored ability submodules
require "abilities/NinjaLineages_BringerOfDarkness"
require "abilities/NinjaLineages_Kirigakure"
require "abilities/NinjaLineages_AlarmSeals"
require "abilities/NinjaLineages_CombatHooks"
require "abilities/NinjaLineages_ResourceLoop"
require "abilities/NinjaLineages_JutsuExecutors"
