--============================================================--
--                        HFO_Loot.lua                        --
--============================================================--
-- Purpose:
--   Handles all loot logic for  including tiered item generation,
--    loot filtering, item enablement by settings, and orphaned item detection.
--
-- Overview:
--   This module acts as the backbone for managing loot presence and rarity
--   across the mod. It dynamically selects valid item pools based on enabled
--   sandbox settings and prepares categorized data for loot roll systems,
--   containers, caches, and location-based drops.
--
-- Core Features:
--   - Parses HFO.Constants.Items based on HFO.SandboxUtils.get() state
--   - Supports dynamic filtering and inclusion of extension mod items (HFE)
--   - Generates valid item pools for loot spawns by type and tier
--   - Provides orphaned item detection for debug and cleanup
--   - Defines tier-based weighted loot roll structures
--   - Ensures only registered and available items are used at runtime
--
-- Responsibilities:
--   - Guarantee sandbox-driven loot control across firearms, ammo, parts
--   - Enable flexibility for modpack creators and server admins
--
-- Dependencies:
--   - HFO_SandboxUtils (to get active mod config)
--   - HFO_Constants (for categorized item lists)
--   - HFO_Utils (for logging and weighted random selection)
--
-- Usage:
--   - HFO.Loot.getEnabledItems() for a master table of all valid spawnables
--   - HFO.Loot.getOrphanedItemsList() for safe mod maintenance
--   - HFO.Loot.getItemsFromTier("rare") to roll for a tiered loot category
--
-- Notes:
--   - This module should only be modified for loot logic
--   - Tier weights can be fine-tuned independently without altering core logic
--============================================================--


require "HFO_SandboxUtils"

HFO = HFO or {}
HFO.Loot = HFO.Loot or {}


---===========================================---
--    GATHER AND CREATE ENABLED LOOT TABLES    --
---===========================================---

-- Get all enabled items from a specific category based on sandbox settings
function HFO.Loot.getEnabledItems()
    local sv = HFO.SandboxUtils.get()
    if not HFO.SandboxUtils.isEnumEnabled(sv.Loot) then return {} end

    local result = {
        FirearmsHandguns = {},
        FirearmsSMGs = {},
        FirearmsRifles = {},
        FirearmsSnipers = {},
        FirearmsShotguns = {},        
        FirearmsOther = {},
        Ammo = {},
        AmmoBoxHandguns = {},
        AmmoBoxRifles = {},
        AmmoBoxShotguns = {},
        AmmoBoxOther = {},
        AmmoMagsHandguns = {},
        AmmoMagsRifles = {},
        AmmoMagsShotguns = {},
        AmmoMagsOther = {},
        AccessoriesSuppressors = {},
        AccessoriesScopes = {},
        AccessoriesOther = {},
        FirearmSkins = {},
        ExtendedSmall = {},
        ExtendedLarge = {},
        ExtendedDrum = {},
        SpeedLoaders = {},
        RepairKits = {},
        Cleaning = {},
        FirearmCache = {},
        Cases = {}  
    }
    
    local items = HFO.Constants.Items
    
    local function AddItemsToTable(targetTable, sourceTable)
        if not sourceTable then return end
        
        for _, item in ipairs(sourceTable) do
            if item ~= "empty" then  -- Skip "empty" placeholders
                table.insert(targetTable, item)
            end
        end
    end
    
    local function ProcessSection(section, mainToggle, resultTable, specialCases)
        if mainToggle and not sv[mainToggle] then return end
        
        -- Add base items
        if section.Base then
            AddItemsToTable(result[resultTable], section.Base)
        end
        
        -- Add HFE items if enabled
        if sv.HFE and section.HFE then
            AddItemsToTable(result[resultTable], section.HFE)
        end
        
        -- Process special cases
        if specialCases then
            for item, toggle in pairs(specialCases) do
                if sv[toggle] and section[item] then
                    AddItemsToTable(result[resultTable], section[item])
                end
            end
        end
    end

    -- Define a mapping of sections to process based on toggled sandbox settings
    local sections = {
        -- Format: {mainToggle, section, subsectionToggle, resultTable, specialCases}
        {"Firearms", "FirearmsHandguns", items.Firearms.Handguns, "FirearmsHandguns", {ColtCavalry = "ColtCavalry"}},
        {"Firearms", "FirearmsSMGs", items.Firearms.SMGs, "FirearmsSMGs"},
        {"Firearms", "FirearmsRifles", items.Firearms.Rifles, "FirearmsRifles", {FGMG = "FGMG42"}},
        {"Firearms", "FirearmsSnipers", items.Firearms.Snipers, "FirearmsSnipers"},
        {"Firearms", "FirearmsShotguns", items.Firearms.Shotguns, "FirearmsShotguns"},
        {"Firearms", "FirearmsOther", items.Firearms.Other, "FirearmsOther", {TShirt = "TShirtLauncher"}},
        
        {"Ammo", "AmmoHandguns", items.Ammo.Handguns, "Ammo"},
        {"Ammo", "AmmoHandguns", items.AmmoBox.Handguns, "AmmoBoxHandguns"},
        {"Ammo", "AmmoHandguns", items.AmmoMags.Handguns, "AmmoMagsHandguns"},
        
        {"Ammo", "AmmoRifles", items.Ammo.Rifles, "Ammo", {FGMG = "FGMG42"}},
        {"Ammo", "AmmoRifles", items.AmmoBox.Rifles, "AmmoBoxRifles", {FGMG = "FGMG42"}},
        {"Ammo", "AmmoRifles", items.AmmoMags.Rifles, "AmmoMagsRifles", {FGMG = "FGMG42"}},
        
        {"Ammo", "AmmoShotguns", items.Ammo.Shotguns, "Ammo"},
        {"Ammo", "AmmoShotguns", items.AmmoBox.Shotguns, "AmmoBoxShotguns"},
        
        {"Ammo", "AmmoOther", items.Ammo.Other, "Ammo"},
        {"Ammo", "AmmoOther", items.AmmoBox.Other, "AmmoBoxOther"},
        {"Ammo", "AmmoOther", items.AmmoMags.Other, "AmmoMagsOther"},
        
        {"Accessories", "AccessoriesSuppressors", items.Accessories.Suppressors, "AccessoriesSuppressors"},
        {"Accessories", "AccessoriesScopes", items.Accessories.Scopes, "AccessoriesScopes", {FGMG = "FGMG42"}},
        {"Accessories", "AccessoriesOther", items.Accessories.Other, "AccessoriesOther"},
        
        {"FirearmSkins", nil, items.FirearmSkins, "FirearmSkins", {Exclusive = "ExclusiveFirearmSkins", Server = "ServerFirearmSkins"}}
    }
    
    for _, section in ipairs(sections) do
        local mainToggle = section[1]
        local subToggle = section[2]
        local itemSection = section[3]
        local resultTable = section[4]
        local specialCases = section[5]
        
        -- Check if the main toggle is enabled using isEnumEnabled
        local mainToggleEnabled = HFO.SandboxUtils.isEnumEnabled(sv[mainToggle])
        
        if mainToggleEnabled and (not subToggle or sv[subToggle]) then
            ProcessSection(itemSection, nil, resultTable, specialCases)
        end
    end
    
    if HFO.SandboxUtils.isEnumEnabled(sv.Extended) then
        if sv.ExtendedSmall and items.Extended.ExtendedSmall then
            AddItemsToTable(result.ExtendedSmall, items.Extended.ExtendedSmall)
        end
        
        if sv.ExtendedLarge and items.Extended.ExtendedLarge then
            AddItemsToTable(result.ExtendedLarge, items.Extended.ExtendedLarge)
        end
        
        if sv.ExtendedDrum and items.Extended.ExtendedDrum then
            AddItemsToTable(result.ExtendedDrum, items.Extended.ExtendedDrum)
        end
        
        if sv.SpeedLoaders and items.Extended.SpeedLoaders then
            AddItemsToTable(result.SpeedLoaders, items.Extended.SpeedLoaders)
        end
    end
    
    if sv.RepairKits then
        ProcessSection(items.Mechanics.RepairKits, nil, "RepairKits")
    end
    
    if sv.Cleaning then
        ProcessSection(items.Mechanics.Cleaning, nil, "Cleaning")
    end
    
    if HFO.SandboxUtils.isEnumEnabled(sv.FirearmCache) then
        ProcessSection(items.SpecialItems.FirearmCache, nil, "FirearmCache")
    end
    
    local caseTypes = {"RifleCases", "ShotgunCases", "PistolCases", "RevolverCases"}
    for _, caseType in ipairs(caseTypes) do
        if items.SpecialItems[caseType] then
            AddItemsToTable(result.Cases, items.SpecialItems[caseType].Base)
            
            if sv.HFE and items.SpecialItems[caseType].HFE then
                AddItemsToTable(result.Cases, items.SpecialItems[caseType].HFE)
            end
        end
    end

    local prefix = "Base."
    for category, itemList in pairs(result) do
        for i = #itemList, 1, -1 do
            local fullName = prefix .. itemList[i]
            if not ScriptManager.instance:FindItem(fullName) then
                HFO.Utils.debugLog("[HFO.Loot] Removing invalid enabled item: " .. fullName)
                table.remove(itemList, i)
            end
        end
    end

    return result
end

-- Check if a specific feature is enabled in the sandbox settings
function HFO.Loot.isFeatureEnabled(feature)
    local sv = HFO.SandboxUtils.get()
    return sv[feature] == true
end

-- Flatten all known HFO items across categories for cleanup/debugging
function HFO.Loot.getAllKnownItems()
    local allKnownHFOItems = {}
    local items = HFO.Constants.Items
    
    local function processItemTable(tbl)
        if type(tbl) ~= "table" then return end
        
        for k, v in pairs(tbl) do
            if type(v) == "table" then
                if #v > 0 then
                    for i = 1, #v do
                        if v[i] ~= "empty" then
                            allKnownHFOItems[v[i]] = true
                        end
                    end
                else
                    processItemTable(v)
                end
            end
        end
    end
    
    processItemTable(items)
    
    return allKnownHFOItems
end

-- Get items that are known to the mod but not currently enabled by sandbox settings
function HFO.Loot.getOrphanedItems()
    local allKnownItems = HFO.Loot.getAllKnownItems()
    
    -- Get all currently enabled items
    local enabledItems = {}
    local enabledTables = HFO.Loot.getEnabledItems()
    
    -- Process each category of enabled items
    for _, categoryItems in pairs(enabledTables) do
        for _, item in ipairs(categoryItems) do
            enabledItems[item] = true
        end
    end
    
    -- Find orphaned items (known but not enabled)
    local orphanedItems = {}
    for item, _ in pairs(allKnownItems) do
        if not enabledItems[item] then
            orphanedItems[item] = true
        end
    end
    
    return orphanedItems
end

-- Alternative version that returns array 
function HFO.Loot.getOrphanedItemsList()
    local orphanedItemsMap = HFO.Loot.getOrphanedItems()
    local orphanedItemsList = {}
    
    for item, _ in pairs(orphanedItemsMap) do
        table.insert(orphanedItemsList, item)
    end
    
    table.sort(orphanedItemsList)
    return orphanedItemsList
end

function HFO.Loot.getAllVanillaItems()
    local vanillaItems = {}
    local items = HFO.Constants.Items

    for category, subcategories in pairs(items) do
        for subcategory, entry in pairs(subcategories) do
            if type(entry) == "table" and entry.Base then
                for _, item in ipairs(entry.Base) do
                    if item ~= "empty" then
                        vanillaItems[item] = true
                    end
                end
            end
        end
    end

    return vanillaItems
end

function HFO.Loot.getAllLocations() -- helper to intentionally iterate over known distribution spots 
    local allLocs = {}
    local seen = {}

    for category, locs in pairs(HFO.Constants.LootLocations) do
        for _, loc in ipairs(locs) do
            if not seen[loc] then
                table.insert(allLocs, loc)
                seen[loc] = true
            end
        end
    end

    return allLocs
end


---===========================================---
--      LOOT ROLL WEIGHT AND TIER UTILITY      --
---===========================================---

-- Utility for randomizing loot for weapon caches and ammo boxes
function HFO.Loot.getWeightedRandom(weights)
    local total = 0
    for _, entry in ipairs(weights) do
        total = total + entry.weight
    end

    local rand = ZombRand(total) + 1
    local cumulative = 0

    for _, entry in ipairs(weights) do
        cumulative = cumulative + entry.weight
        if rand <= cumulative then
            return entry
        end
    end
end

HFO.TierWeights = {
    common = {
        { type = "Ammo", weight = 60 },
        { type = "AmmoMags", weight = 20 },
        { type = "Attachments", weight = 10 },
        { type = "Skins", weight = 5 },
        { type = "Firearms", weight = 5 },
    },
    uncommon = {
        { type = "Ammo", weight = 25 },
        { type = "AmmoMags", weight = 15 },
        { type = "Attachments", weight = 15 },
        { type = "Skins", weight = 10 },
        { type = "Firearms", weight = 15 },
        { type = "RepairItems", weight = 20 },
    },
    rare = {
        { type = "Ammo", weight = 15 },
        { type = "AmmoMags", weight = 10 },
        { type = "Attachments", weight = 20 },
        { type = "Skins", weight = 15 },
        { type = "Firearms", weight = 20 },
        { type = "ExtensionFirearms", weight = 10 },
        { type = "RepairItems", weight = 10 },
    },
    premium = {
        { type = "Attachments", weight = 15 },
        { type = "Skins", weight = 30 },
        { type = "Firearms", weight = 15 },
        { type = "ExtensionFirearms", weight = 25 },
        { type = "RareExtensionFirearms", weight = 15 },
    },
    legendary = {
        { type = "Attachments", weight = 5 },
        { type = "Skins", weight = 15 },
        { type = "Firearms", weight = 15 },
        { type = "ExtensionFirearms", weight = 30 },
        { type = "RareExtensionFirearms", weight = 35 },
    }
}

function HFO.Loot.getItemsFromTier(tier)
    local weights = HFO.TierWeights[tier]
    if not weights then return nil end
    local selected = HFO.Loot.getWeightedRandom(weights)
    return selected and selected.type
end


function HFO.Loot.filterExistingFromCache(cacheKey, typelist)
	local result = {}
	local pool = HFO.Recipe.cacheOptions[cacheKey]
	if not pool then return result end

	for _, item in ipairs(typelist) do
		for _, cached in ipairs(pool) do
			if cached:match("%." .. item .. "$") then
				table.insert(result, cached)
				break -- Stop searching once found
			end
		end
	end

	return result
end