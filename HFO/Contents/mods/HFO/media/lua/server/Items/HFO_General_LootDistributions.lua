--============================================================--
--                  HFO_LootDistribution.lua                  --
--============================================================--
-- Purpose:
--   Centralized loot spawning logic for Hayes Firearms Overhaul (HFO).
--   Dynamically injects all enabled mod content into appropriate loot
--   tables using scalable rarity curves, sandbox multipliers, and tiered
--   category definitions. Removes vanilla firearms default spawns.
--
-- Overview:
--   - Adds items to distributions using procedural weighting.
--   - Maps sandbox settings and rarity curves to final spawn rates.
--   - Categorizes items by function (Ammo, Firearms, Parts, Skins, etc.).
--   - Prunes invalid/orphaned loot from world generation.
--   - Cleans up vanilla weapons if configured.
--
-- Core Features:
--   - Curve-based scaling using sandbox sliders and rarity profiles
--   - Full item category-to-location mapping 
--   - Dynamic integration with Procedural, Suburbs, and Vehicle distributions
--   - Cleanup system for orphaned or deprecated HFO items
--   - Debug functions for listing loot and sandbox settings
--
-- Responsibilities:
--   - Inject only enabled items into proper loot zones
--   - Ensure loot rates scale naturally with sandbox settings
--   - Protect world generation from invalid or removed item entries
--
-- Dependencies:
--   - HFO_Loot, HFO_Utils, HFO_SandboxUtils, HFO_Constants
--   - Project Zomboid item distribution systems (`ProceduralDistributions`, etc.)
--
-- Notes:
--   - All loot tuning is centralized here for consistency and modularity
--   - Sandbox curve engine normalizes behavior across loot types
--============================================================--

require "Items/ItemPicker"
require "Items/Distributions"
require "Items/SuburbsDistributions"
require "Items/ProceduralDistributions"
require "Vehicles/VehicleDistributions"
require "HFO_Utils"
require "HFO_SandboxUtils"
require "HFO_Constants"
require "HFO_Loot"


HFO = HFO or {}


---===========================================---
--             CENTRAL LOOT MANAGER            --
---===========================================---

HFO.LootDistro = HFO.LootDistro or {
    AddedItems = {},
    CategoryConfig = {},
    RemovedItems = {},
}

HFO.LootDistro.RemovedVanillaCount = 0


---===========================================---
--      ADD OUR ENABLED ITEMS TO LOCATIONS     --
---===========================================---

function HFO.LootDistro:add(itemsAndChances, locations)
    local prefix = "Base."
    for item, chance in pairs(itemsAndChances) do
        for _, loc in ipairs(locations) do
            local dist = ProceduralDistributions.list[loc]
            if dist and dist.items then
                local fullName = prefix .. item
                if ScriptManager.instance:FindItem(fullName) then
                    table.insert(dist.items, item)
                    table.insert(dist.items, chance)
                    self.AddedItems[item] = true
                end
            end
        end
    end
end

-- if needing to pull out single item from bigger loot pools and influence their final rate
HFO.LootDistro.specialItemMultipliers = {
    ["50BMGBox"] = 0.7,
    ["50BMGClip"] = 0.7,
}

function HFO.LootDistro:buildRateMap(itemList, baseChance)
    local rateMap = {}
    for _, item in ipairs(itemList) do
        local multiplier = self.specialItemMultipliers[item] or 1.0
        rateMap[item] = baseChance * multiplier
    end
    return rateMap
end


---===========================================---
--           PROGRESSIVE LOOT SCALING          --
---===========================================---

HFO.LootDistro.spawnRateEngine = {
    -- Base values that define the scaling curve
    scalingFactor = 2.0,  
    minMultiplier = 0.05, 
    maxMultiplier = 20.0,
    
    -- Curve profiles with predefined modifiers
    curveProfiles = {
        common = 0.7,    -- Flatter curve
        standard = 1.0,  -- Standard curve
        rare = 1.5,      -- Steeper curve
        veryRare = 2.0   -- Steepest curve
    }
}

function HFO.LootDistro.spawnRateEngine:getMultiplierFromSetting(lootSetting, curveName)
    lootSetting = lootSetting or 4
    lootSetting = math.max(1, math.min(lootSetting, 7))
    local curveModifier = self.curveProfiles[curveName] or self.curveProfiles.standard    
    local normalizedSetting = (lootSetting - 1) / 6
    
    -- Calculate multiplier with curve
    local range = self.maxMultiplier - self.minMultiplier
    local rawMultiplier = self.minMultiplier + (math.pow(normalizedSetting, curveModifier) * range)
    
    -- Normalize to make level 4 = 1.0
    local baselineMultiplier = self:getBaselineMultiplier(4, curveName)
    return rawMultiplier / baselineMultiplier
end

function HFO.LootDistro.spawnRateEngine:getBaselineMultiplier(lootSetting, curveName)
    lootSetting = lootSetting or 4
    lootSetting = math.max(1, math.min(lootSetting, 7))
    local curveModifier = self.curveProfiles[curveName] or self.curveProfiles.standard
    local normalizedSetting = (lootSetting - 1) / 6

    local range = self.maxMultiplier - self.minMultiplier
    return self.minMultiplier + (math.pow(normalizedSetting, curveModifier) * range)
end

function HFO.LootDistro.spawnRateEngine:calculateRate(options)
    -- Extract options with defaults
    local baseRate = options.baseRate or 1.0
    local globalLootSetting = options.globalLoot or 4
    local categorySetting = options.categorySetting or 4
    local spawnRateSlider = options.spawnRateSlider
    local rarity = options.rarity or "standard"
    
    -- Calculate multipliers
    local globalMultiplier = self:getMultiplierFromSetting(globalLootSetting, "standard")
    local categoryMultiplier = self:getMultiplierFromSetting(categorySetting, rarity)
    
    -- Apply slider if present
    local spawnRateMultiplier = 1.0
    if spawnRateSlider then
        spawnRateMultiplier = (spawnRateSlider / 50) ^ 1.5
    end
    
    -- Return final rate
    return baseRate * globalMultiplier * categoryMultiplier * spawnRateMultiplier
end

function HFO.LootDistro:processCategory(config)
    local itemList = config.itemList
    if not itemList or #itemList == 0 then return end

    local mappedLocationType = HFO.LootDistro.CategoryLocations[config.locationType] or config.locationType
    local locs = HFO.Constants.LootLocations[mappedLocationType]
    
    -- Calculate baseRate using the new system
    local baseRate = HFO.LootDistro.spawnRateEngine:calculateRate({
        baseRate = config.baseRate,                     
        categorySetting = config.categorySetting or 4,  
        globalLoot = SandboxVars.HFO.Loot,                           
        spawnRateSlider = config.spawnRateSlider, 
        rarity = config.rarity or "standard",           
    })

    -- Build and apply rate map
    local rateMap = self:buildRateMap(itemList, baseRate)
    self:add(rateMap, locs)
end


---===========================================---
--        NORMALIZING CATEGORY LOCATIONS       --
---===========================================---

-- Category to location mapping aligned with HFO.Constants.LootLocations
HFO.LootDistro.CategoryLocations = {
    Firearms = "FirearmsAccessoriesExtended",
    Ammo = "AmmoandMags",
    Accessories = "FirearmsAccessoriesExtended",
    Extended = "FirearmsAccessoriesExtended",
    FirearmSkins = "FirearmSkins",
    Cleaning = "Mechanics",
    RepairKits = "Mechanics",
    FirearmCache = "CacheandCases",
    Cases = "CacheandCases"
}


---===========================================---
--                   FIREARMS                  --
---===========================================---
function HFO.LootDistro.CategoryConfig.FirearmsHandguns(enabledTables)
    HFO.LootDistro:processCategory({                                       -- Connect to sandbox settings
        itemList = enabledTables.FirearmsHandguns,      -- Grab from enabled Loot Table Firearms Handguns
        locationType = "Firearms",                      -- Connect to mapped location for Firearms
        baseRate = 2.5,                                 -- Establish base rate for spawns for this category
        categorySetting = SandboxVars.HFO.Firearms,                  -- Grab overall category sandbox loot setting
        spawnRateSlider  = SandboxVars.HFO.FirearmsHandgunsRates,    -- Grab Handgun specific sandbox loot setting
        rarity = "standard",                            -- Curve used for impact of global and category multipliers from defaults
    })
end

function HFO.LootDistro.CategoryConfig.FirearmsSMGs(enabledTables)
    HFO.LootDistro:processCategory({
        itemList = enabledTables.FirearmsSMGs,
        locationType = "Firearms",
        baseRate = 1.4,
        categorySetting = SandboxVars.HFO.Firearms,
        spawnRateSlider  = SandboxVars.HFO.FirearmsSMGsRates,
        rarity = "rare",
    })
end

function HFO.LootDistro.CategoryConfig.FirearmsRifles(enabledTables)
    HFO.LootDistro:processCategory({
        itemList = enabledTables.FirearmsRifles,
        locationType = "Firearms",
        baseRate = 2.0,
        categorySetting = SandboxVars.HFO.Firearms,
        spawnRateSlider  = SandboxVars.HFO.FirearmsRiflesRates,
        rarity = "standard",
    })
end

function HFO.LootDistro.CategoryConfig.FirearmsSnipers(enabledTables)
    HFO.LootDistro:processCategory({
        itemList = enabledTables.FirearmsSnipers,
        locationType = "Firearms",
        baseRate = 1.2,
        categorySetting = SandboxVars.HFO.Firearms,
        spawnRateSlider  = SandboxVars.HFO.FirearmsSnipersRates,
        rarity = "rare",
    })
end

function HFO.LootDistro.CategoryConfig.FirearmsShotguns(enabledTables)
    HFO.LootDistro:processCategory({
        itemList = enabledTables.FirearmsShotguns,
        locationType = "Firearms",
        baseRate = 1.6,
        categorySetting = SandboxVars.HFO.Firearms,
        spawnRateSlider  = SandboxVars.HFO.FirearmsShotgunsRates,
        rarity = "rare",
    })
end

function HFO.LootDistro.CategoryConfig.FirearmsOther(enabledTables)
    HFO.LootDistro:processCategory({
        itemList = enabledTables.FirearmsOther,
        locationType = "Firearms",
        baseRate = 0.5,
        categorySetting = SandboxVars.HFO.Firearms,
        spawnRateSlider  = SandboxVars.HFO.FirearmsOtherRates,
        rarity = "veryRare",
    })
end

---===========================================---
--        AMMO BOXES AND AMMO MAGAZINES        --
---===========================================---
function HFO.LootDistro.CategoryConfig.AmmoBoxHandguns(enabledTables)
    HFO.LootDistro:processCategory({
        itemList = enabledTables.AmmoBoxHandguns,
        locationType = "Ammo",
        baseRate = 2.0,
        categorySetting = SandboxVars.HFO.Ammo,
        spawnRateSlider  = SandboxVars.HFO.AmmoHandgunsRates,
        rarity = "standard",
    })
end

function HFO.LootDistro.CategoryConfig.AmmoMagsHandguns(enabledTables)
    HFO.LootDistro:processCategory({
        itemList = enabledTables.AmmoMagsHandguns,
        locationType = "Ammo",
        baseRate = 2.0,
        categorySetting = SandboxVars.HFO.Ammo,
        spawnRateSlider  = SandboxVars.HFO.AmmoHandgunsRates,
        rarity = "standard",
    })
end

function HFO.LootDistro.CategoryConfig.AmmoBoxRifles(enabledTables)
    HFO.LootDistro:processCategory({
        itemList = enabledTables.AmmoBoxRifles,
        locationType = "Ammo",
        baseRate = 1.6,
        categorySetting = SandboxVars.HFO.Ammo,
        spawnRateSlider  = SandboxVars.HFO.AmmoRiflesRates,
        rarity = "standard",
    })
end

function HFO.LootDistro.CategoryConfig.AmmoMagsRifles(enabledTables)
    HFO.LootDistro:processCategory({
        itemList = enabledTables.AmmoMagsRifles,
        locationType = "Ammo",
        baseRate = 1.6,
        categorySetting = SandboxVars.HFO.Ammo,
        spawnRateSlider  = SandboxVars.HFO.AmmoRiflesRates,
        rarity = "standard",
    })
end

function HFO.LootDistro.CategoryConfig.AmmoBoxShotguns(enabledTables)
    HFO.LootDistro:processCategory({
        itemList = enabledTables.AmmoBoxShotguns,
        locationType = "Ammo",
        baseRate = 1.2,
        categorySetting = SandboxVars.HFO.Ammo,
        spawnRateSlider  = SandboxVars.HFO.AmmoShotgunsRates,
        rarity = "standard",
    })
end

function HFO.LootDistro.CategoryConfig.AmmoBoxOther(enabledTables)
    HFO.LootDistro:processCategory({
        itemList = enabledTables.AmmoBoxOther,
        locationType = "Ammo",
        baseRate = 0.3,
        categorySetting = SandboxVars.HFO.Ammo,
        spawnRateSlider  = SandboxVars.HFO.AmmoOtherRates,
        rarity = "veryRare",
    })
end

function HFO.LootDistro.CategoryConfig.AmmoMagsOther(enabledTables)
    HFO.LootDistro:processCategory({
        itemList = enabledTables.AmmoMagsOther,
        locationType = "Ammo",
        baseRate = 0.3,
        categorySetting = SandboxVars.HFO.Ammo,
        spawnRateSlider  = SandboxVars.HFO.AmmoOtherRates,
        rarity = "veryRare",
    })
end

---===========================================---
--    ACCESSORIES / WEAPON PART ATTACHMENTS    --
---===========================================---
function HFO.LootDistro.CategoryConfig.AccessoriesSuppressors(enabledTables)
    HFO.LootDistro:processCategory({
        itemList = enabledTables.AccessoriesSuppressors,
        locationType = "Accessories",
        baseRate = 0.6,
        categorySetting = SandboxVars.HFO.Accessories,
        spawnRateSlider  = SandboxVars.HFO.AccessoriesSuppressorsRates,
        rarity = "veryRare",
    })
end

function HFO.LootDistro.CategoryConfig.AccessoriesScopes(enabledTables)
    HFO.LootDistro:processCategory({
        itemList = enabledTables.AccessoriesScopes,
        locationType = "Accessories",
        baseRate = 0.8,
        categorySetting = SandboxVars.HFO.Accessories,
        spawnRateSlider  = SandboxVars.HFO.AccessoriesScopesRates,
        rarity = "rare",
    })
end

function HFO.LootDistro.CategoryConfig.AccessoriesOther(enabledTables)
    HFO.LootDistro:processCategory({
        itemList = enabledTables.AccessoriesOther,
        locationType = "Accessories",
        baseRate = 0.9,
        categorySetting = SandboxVars.HFO.Accessories,
        spawnRateSlider  = SandboxVars.HFO.AccessoriesOtherRates,
        rarity = "rare",
    })
end

---===========================================---
--        EXTENDED MAGS AND SPEEDLOADERS       --
---===========================================---
function HFO.LootDistro.CategoryConfig.ExtendedSmall(enabledTables)
    HFO.LootDistro:processCategory({
        itemList = enabledTables.ExtendedSmall,
        locationType = "Extended",
        baseRate = 0.2,
        categorySetting = SandboxVars.HFO.Extended,
        rarity = "rare",
    })
end

function HFO.LootDistro.CategoryConfig.ExtendedLarge(enabledTables)
    HFO.LootDistro:processCategory({
        itemList = enabledTables.ExtendedLarge,
        locationType = "Extended",
        baseRate = 0.1,
        categorySetting = SandboxVars.HFO.Extended,
        rarity = "veryRare",
    })
end

function HFO.LootDistro.CategoryConfig.ExtendedDrum(enabledTables)
    HFO.LootDistro:processCategory({
        itemList = enabledTables.ExtendedDrum,
        locationType = "Extended",
        baseRate = 0.05,
        categorySetting = SandboxVars.HFO.Extended,
        rarity = "veryRare",
    })
end

function HFO.LootDistro.CategoryConfig.SpeedLoaders(enabledTables)
    HFO.LootDistro:processCategory({
        itemList = enabledTables.SpeedLoaders,
        locationType = "Extended",
        baseRate = 0.3,
        categorySetting = SandboxVars.HFO.Loot,
        rarity = "rare",
    })
end

---===========================================---
--                FIREARM SKINS                --
---===========================================---
function HFO.LootDistro.CategoryConfig.FirearmSkins(enabledTables)
    HFO.LootDistro:processCategory({
        itemList = enabledTables.FirearmSkins,
        locationType = "FirearmSkins",
        baseRate = 0.5,
        categorySetting = SandboxVars.HFO.FirearmSkins,
        rarity = "rare",
    })
end

---===========================================---
--               CLEANING ITEMS                --
---===========================================---
function HFO.LootDistro.CategoryConfig.Cleaning(enabledTables)
    HFO.LootDistro:processCategory({
        itemList = enabledTables.Cleaning,
        locationType = "Cleaning",
        baseRate = 2.5,
        categorySetting = SandboxVars.HFO.CleanRepairSpawns,
        rarity = "standard",
    })
end

---===========================================---
--                 REPAIR KITS                 --
---===========================================---
function HFO.LootDistro.CategoryConfig.RepairKits(enabledTables)
    HFO.LootDistro:processCategory({
        itemList = enabledTables.RepairKits,
        locationType = "RepairKits",
        baseRate = 1.0,
        categorySetting = SandboxVars.HFO.CleanRepairSpawns,
        rarity = "standard",
    })
end

---===========================================---
--               FIREARM CACHES                --
---===========================================---
function HFO.LootDistro.CategoryConfig.FirearmCache(enabledTables)
    HFO.LootDistro:processCategory({
        itemList = enabledTables.FirearmCache,
        locationType = "FirearmCache",
        baseRate = 0.4,
        categorySetting = SandboxVars.HFO.FirearmCache,
        rarity = "rare",
    })
end

---===========================================---
--                    CASES                    --
---===========================================---
function HFO.LootDistro.CategoryConfig.Cases(enabledTables)
    HFO.LootDistro:processCategory({
        itemList = enabledTables.Cases,
        locationType = "Cases",
        baseRate = 0.5,
        categorySetting = SandboxVars.HFO.Loot,
        rarity = "rare",
    })
end


---==============================================---
-- CLEANUP: REMOVE ORPHANED HFO ITEMS FROM DISTRO --
---==============================================---

function HFO.LootDistro:cleanup()
    local orphanedItems = HFO.Loot.getOrphanedItems()
    local allLocs = HFO.Loot.getAllLocations()

    for _, loc in ipairs(allLocs) do
        local dist = ProceduralDistributions.list[loc]
        if dist and dist.items then
            self:cleanupItemsInTable(dist, orphanedItems)
        end
    end
    
    self:cleanupDistributionTable(ProceduralDistributions.list)
    self:cleanupDistributionTable(SuburbsDistributions)
    self:cleanupDistributionTable(VehicleDistributions)
    if Distributions and Distributions[1] then
        self:cleanupDistributionTable(Distributions[1])
    end
end

function HFO.LootDistro:getRemovedItemsList()
    local result = {}
    for item in pairs(self.RemovedItems) do
        table.insert(result, item)
    end
    return result
end

function HFO.LootDistro:cleanupItemsInTable(distTable, orphanedItems)
    if not distTable or not distTable.items then return end

    local i = 1
    while i <= #distTable.items do
        local item = distTable.items[i]
        if type(item) == "string" and orphanedItems[item] then
            table.remove(distTable.items, i) 
            table.remove(distTable.items, i)
            self.RemovedItems[item] = true
        else
            i = i + 2
        end
    end
end

function HFO.LootDistro:cleanupDistributionTable(rootTable)
    if not rootTable or type(rootTable) ~= "table" then return end

    for _, v in pairs(rootTable) do
        if type(v) == "table" then
            if v.items and type(v.items) == "table" then
                self:cleanupItemsInTable(v, self.RemovedItems)
            else
                self:cleanupDistributionTable(v)
            end
        end
    end
end


---===========================================---
--            REMOVE VANILLA SPAWNS            --
---===========================================---

function HFO.LootDistro:removeVanillaItems()
    if not (HFO.Loot and HFO.Loot.getAllVanillaItems) then return end

    local vanillaItems = HFO.Loot.getAllVanillaItems()
    self.RemovedVanillaCount = 0

    -- Convert vanilla items table to the format used in the original code
    local itemSet = {}
    for item, _ in pairs(vanillaItems) do
        itemSet[item] = true
    end

    local function removeItemsFromDistribution(distributions, itemSet)
        for _, dist in pairs(distributions) do
            if type(dist) == "table" then
                if dist.items then
                    local i = 1
                    while i <= #dist.items do
                        if type(dist.items[i]) == "string" and itemSet[dist.items[i]] then
                            table.remove(dist.items, i)
                            table.remove(dist.items, i)
                            self.RemovedVanillaCount = self.RemovedVanillaCount + 1
                        else
                            i = i + 2
                        end
                    end
                end
                
                if dist.junk then
                    removeItemsFromDistribution({dist.junk}, itemSet)
                end
                
                -- Process specific subcategories that are known to contain items
                for _, subcategory in pairs({
                    "clothingdryer", "clothingdryerbasic", "clothingwasher", 
                    "counter", "crate", "freezer", "fridge", 
                    "metal_shelves", "shelves"
                }) do
                    if dist[subcategory] then
                        removeItemsFromDistribution({dist[subcategory]}, itemSet)
                    end
                end
            end
        end
    end

    -- Apply the removal to all distribution tables
    removeItemsFromDistribution(ProceduralDistributions.list, itemSet)
    removeItemsFromDistribution(Distributions[1], itemSet)
    removeItemsFromDistribution(SuburbsDistributions, itemSet)
    removeItemsFromDistribution(VehicleDistributions, itemSet)
end


---===========================================---
--     INITIALIZE ON PRE DISTRIBUTION MERGE    --
---===========================================---

Events.OnInitGlobalModData.Add(function()
    -- Nuke vanilla junk first
    HFO.LootDistro:removeVanillaItems()

    -- Reset state
    HFO.LootDistro.AddedItems = {}
    HFO.LootDistro.RemovedItems = {}

    -- Add HFO loot
    local enabledTables = HFO.Loot.getEnabledItems()
    
    for categoryName, applyFunc in pairs(HFO.LootDistro.CategoryConfig) do
        if type(applyFunc) == "function" then
            applyFunc(enabledTables) 
        end
    end
end)


---===========================================---
--      CLEANUP ON POST DISTRIBUTION MERGE     --
---===========================================---

Events.OnPostDistributionMerge.Add(function()
    if HFO.LootDistro and HFO.LootDistro.cleanup then
        HFO.LootDistro:cleanup()
    end
end)