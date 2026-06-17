require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "lineages/NinjaLineages_ByakuganPassives"

NinjaLineages = NinjaLineages or {}
NinjaLineages.Hyuga = NinjaLineages.Hyuga or {}

-- Byakugan eye management is now centralized in NinjaLineages.ByakuganPassives (shared).
-- This file remains as a lineage marker for the mod loader.
NinjaLineages.registerPlayerUpdate("hyuga.applyByakugan", NinjaLineages.ByakuganPassives.applyByakugan)
NinjaLineages.registerCreatePlayer("hyuga.applyByakuganInit", NinjaLineages.ByakuganPassives.applyByakugan)
