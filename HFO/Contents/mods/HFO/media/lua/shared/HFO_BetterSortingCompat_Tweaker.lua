--============================================================--
--             HFO_BetterSortingCompat_Tweaker.lua            --
--============================================================--
-- Purpose:
--   Adds integration between with Better Sorting Mod by matching
--   DisplayCategory values to HFO items using DoParam at game load.
--
-- Overview:
--   This script dynamically classifies HFO items into BetterSort
--   display categories by referencing the HFO item structure 
--
-- Core Features:
--   - Maps HFO category types to BetterSortCC categories
--   - Applies DoParam("DisplayCategory = X") at runtime
--   - Handles conditional inclusion via sandbox checks
--
-- Dependencies:
--   -`BetterSortCC mod must be active
--   - Requires HFO_Constants, HFO_Utils, and HFO_SandboxUtils
--
-- Notes:
--   - Lightweight compatibility layer for user QOL improvements
--   - Does not affect balance or loot; only sorting metadata
--============================================================--

require "HFO_Utils"
require "HFO_SandboxUtils"
require "HFO_Constants"

HFO = HFO or {}


---===========================================---
--      MAPPING BETTER SORTING CATEGORIES      --
---===========================================---

-- Mapping HFO categorys to BetterSortCC display categories
local betterSortHFOItemsMap = {
    Ammo       = { "Ammo", "AmmoBox" },
    WepAmmoMag = { "AmmoMags" },
    WepFire    = { "Firearms" },
    WepPart    = { "Accessories" },
    Tool       = { "Mechanics" },
    Container  = { "SpecialItems" }
}

-- Applies DisplayCategory to items
local function applyDoParam(itemList, displayCategory)
    for _, itemName in ipairs(itemList) do
        local item = ScriptManager.instance:getItem("Base." .. itemName)
        if item then
            item:DoParam("DisplayCategory = " .. displayCategory)
        end
    end
end


---===========================================---
--   GRAB ALL HFO SPECIFIC ITEMS FOR DOPARAM   --
---===========================================---

-- Gathers items from the HFO.Constants.Items table 
local function collectItemsFromCategories(categoryList, sv)
    local collected = {}

    for _, category in ipairs(categoryList) do
        local subtypes = HFO.Constants.Items[category]
        if subtypes then
            for subtype, sources in pairs(subtypes) do
                for sourceMod, itemList in pairs(sources) do
                    if sourceMod == "Base" or sv[sourceMod] == true then
                        for _, itemName in ipairs(itemList) do
                            table.insert(collected, itemName)
                        end
                    end
                end
            end
        end
    end

    return collected
end

-- Finds _Melee variants of known firearms since they aren't listed for distribution in constants table
local function getMeleeVariants(itemList)
    local meleeItems = {}
    for _, item in ipairs(itemList) do
        local meleeName = item .. "_Melee"
        local scriptItem = ScriptManager.instance:getItem("Base." .. meleeName)
        if scriptItem then
            table.insert(meleeItems, meleeName)
        end
    end
    return meleeItems
end


---===========================================---
--                 EVENT HOOKS                 --
---===========================================---

Events.OnGameStart.Add(function()
    if not getActivatedMods():contains("BetterSortCC") then return end

    local sv = HFO.SandboxUtils.get() 
    HFO.Utils.debugLog("[HFO.BetterSort] BetterSortCC detected, applying category sorting...")

    -- Apply category mappings
    for displayCategory, itemCategories in pairs(betterSortHFOItemsMap) do
        local items = collectItemsFromCategories(itemCategories, sv)
        applyDoParam(items, displayCategory)
    end

    -- Handle _Melee weapons separately
    local fireWeapons = collectItemsFromCategories({ "Firearms" }, sv)
    local meleeWeapons = getMeleeVariants(fireWeapons)
    applyDoParam(meleeWeapons, "WepMelee")
end)