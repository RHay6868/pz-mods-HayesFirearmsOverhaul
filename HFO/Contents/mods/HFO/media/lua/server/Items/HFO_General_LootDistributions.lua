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
    minMultiplier = 0.1, 
    maxMultiplier = 20.0,
    
    -- Curve profiles with predefined modifiers
    curveProfiles = {
        common = 0.9,    -- Flatter curve
        standard = 1.0,  -- Standard curve
        rare = 1.15,      -- Steeper curve
        veryRare = 1.25,   -- Steepest curve
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
    local sv = config.sv
    local itemList = config.itemList
    if not itemList or #itemList == 0 then return end

    local mappedLocationType = HFO.LootDistro.CategoryLocations[config.locationType] or config.locationType
    local locs = HFO.Constants.LootLocations[mappedLocationType]
    
    -- Calculate baseRate using the new system
    local baseRate = HFO.LootDistro.spawnRateEngine:calculateRate({
        baseRate = config.baseRate,                     
        categorySetting = config.categorySetting or 4,  
        globalLoot = sv.Loot,                           
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
    Magazines = "Magazines",
    Cases = "CacheandCases"
}


---===========================================---
--                   FIREARMS                  --
---===========================================---
function HFO.LootDistro.CategoryConfig.FirearmsHandguns(sv, enabledTables)
    HFO.LootDistro:processCategory({
        sv = sv,                                        -- Connect to sandbox settings
        itemList = enabledTables.FirearmsHandguns,      -- Grab from enabled Loot Table Firearms Handguns
        locationType = "Firearms",                      -- Connect to mapped location for Firearms
        baseRate = 2.5,                                 -- Establish base rate for spawns for this category
        categorySetting = sv.Firearms,                  -- Grab overall category sandbox loot setting
        spawnRateSlider  = sv.FirearmsHandgunsRates,    -- Grab Handgun specific sandbox loot setting
        rarity = "standard",                            -- Curve used for impact of global and category multipliers from defaults
    })
end

function HFO.LootDistro.CategoryConfig.FirearmsSMGs(sv, enabledTables)
    HFO.LootDistro:processCategory({
        sv = sv,
        itemList = enabledTables.FirearmsSMGs,
        locationType = "Firearms",
        baseRate = 1.4,
        categorySetting = sv.Firearms,
        spawnRateSlider  = sv.FirearmsSMGsRates,
        rarity = "rare",
    })
end

function HFO.LootDistro.CategoryConfig.FirearmsRifles(sv, enabledTables)
    HFO.LootDistro:processCategory({
        sv = sv,
        itemList = enabledTables.FirearmsRifles,
        locationType = "Firearms",
        baseRate = 2.0,
        categorySetting = sv.Firearms,
        spawnRateSlider  = sv.FirearmsRiflesRates,
        rarity = "standard",
    })
end

function HFO.LootDistro.CategoryConfig.FirearmsSnipers(sv, enabledTables)
    HFO.LootDistro:processCategory({
        sv = sv,
        itemList = enabledTables.FirearmsSnipers,
        locationType = "Firearms",
        baseRate = 1.2,
        categorySetting = sv.Firearms,
        spawnRateSlider  = sv.FirearmsSnipersRates,
        rarity = "rare",
    })
end

function HFO.LootDistro.CategoryConfig.FirearmsShotguns(sv, enabledTables)
    HFO.LootDistro:processCategory({
        sv = sv,
        itemList = enabledTables.FirearmsShotguns,
        locationType = "Firearms",
        baseRate = 1.6,
        categorySetting = sv.Firearms,
        spawnRateSlider  = sv.FirearmsShotgunsRates,
        rarity = "rare",
    })
end

function HFO.LootDistro.CategoryConfig.FirearmsOther(sv, enabledTables)
    HFO.LootDistro:processCategory({
        sv = sv,
        itemList = enabledTables.FirearmsOther,
        locationType = "Firearms",
        baseRate = 0.5,
        categorySetting = sv.Firearms,
        spawnRateSlider  = sv.FirearmsOtherRates,
        rarity = "veryRare",
    })
end

---===========================================---
--        AMMO BOXES AND AMMO MAGAZINES        --
---===========================================---
function HFO.LootDistro.CategoryConfig.AmmoBoxHandguns(sv, enabledTables)
    HFO.LootDistro:processCategory({
        sv = sv,
        itemList = enabledTables.AmmoBoxHandguns,
        locationType = "Ammo",
        baseRate = 2.0,
        categorySetting = sv.Ammo,
        spawnRateSlider  = sv.AmmoHandgunsRates,
        rarity = "standard",
    })
end

function HFO.LootDistro.CategoryConfig.AmmoMagsHandguns(sv, enabledTables)
    HFO.LootDistro:processCategory({
        sv = sv,
        itemList = enabledTables.AmmoMagsHandguns,
        locationType = "Ammo",
        baseRate = 2.0,
        categorySetting = sv.Ammo,
        spawnRateSlider  = sv.AmmoHandgunsRates,
        rarity = "standard",
    })
end

function HFO.LootDistro.CategoryConfig.AmmoBoxRifles(sv, enabledTables)
    HFO.LootDistro:processCategory({
        sv = sv,
        itemList = enabledTables.AmmoBoxRifles,
        locationType = "Ammo",
        baseRate = 1.6,
        categorySetting = sv.Ammo,
        spawnRateSlider  = sv.AmmoRiflesRates,
        rarity = "standard",
    })
end

function HFO.LootDistro.CategoryConfig.AmmoMagsRifles(sv, enabledTables)
    HFO.LootDistro:processCategory({
        sv = sv,
        itemList = enabledTables.AmmoMagsRifles,
        locationType = "Ammo",
        baseRate = 1.6,
        categorySetting = sv.Ammo,
        spawnRateSlider  = sv.AmmoRiflesRates,
        rarity = "standard",
    })
end

function HFO.LootDistro.CategoryConfig.AmmoBoxShotguns(sv, enabledTables)
    HFO.LootDistro:processCategory({
        sv = sv,
        itemList = enabledTables.AmmoBoxShotguns,
        locationType = "Ammo",
        baseRate = 1.2,
        categorySetting = sv.Ammo,
        spawnRateSlider  = sv.AmmoShotgunsRates,
        rarity = "standard",
    })
end

function HFO.LootDistro.CategoryConfig.AmmoBoxOther(sv, enabledTables)
    HFO.LootDistro:processCategory({
        sv = sv,
        itemList = enabledTables.AmmoBoxOther,
        locationType = "Ammo",
        baseRate = 0.3,
        categorySetting = sv.Ammo,
        spawnRateSlider  = sv.AmmoOtherRates,
        rarity = "veryRare",
    })
end

function HFO.LootDistro.CategoryConfig.AmmoMagsOther(sv, enabledTables)
    HFO.LootDistro:processCategory({
        sv = sv,
        itemList = enabledTables.AmmoMagsOther,
        locationType = "Ammo",
        baseRate = 0.3,
        categorySetting = sv.Ammo,
        spawnRateSlider  = sv.AmmoOtherRates,
        rarity = "veryRare",
    })
end

---===========================================---
--    ACCESSORIES / WEAPON PART ATTACHMENTS    --
---===========================================---
function HFO.LootDistro.CategoryConfig.AccessoriesSuppressors(sv, enabledTables)
    HFO.LootDistro:processCategory({
        sv = sv,
        itemList = enabledTables.AccessoriesSuppressors,
        locationType = "Accessories",
        baseRate = 0.6,
        categorySetting = sv.Accessories,
        spawnRateSlider  = sv.AccessoriesSuppressorsRates,
        rarity = "veryRare",
    })
end

function HFO.LootDistro.CategoryConfig.AccessoriesScopes(sv, enabledTables)
    HFO.LootDistro:processCategory({
        sv = sv,
        itemList = enabledTables.AccessoriesScopes,
        locationType = "Accessories",
        baseRate = 0.8,
        categorySetting = sv.Accessories,
        spawnRateSlider  = sv.AccessoriesScopesRates,
        rarity = "rare",
    })
end

function HFO.LootDistro.CategoryConfig.AccessoriesOther(sv, enabledTables)
    HFO.LootDistro:processCategory({
        sv = sv,
        itemList = enabledTables.AccessoriesOther,
        locationType = "Accessories",
        baseRate = 0.9,
        categorySetting = sv.Accessories,
        spawnRateSlider  = sv.AccessoriesOtherRates,
        rarity = "rare",
    })
end

---===========================================---
--        EXTENDED MAGS AND SPEEDLOADERS       --
---===========================================---
function HFO.LootDistro.CategoryConfig.ExtendedSmall(sv, enabledTables)
    HFO.LootDistro:processCategory({
        sv = sv,
        itemList = enabledTables.ExtendedSmall,
        locationType = "Extended",
        baseRate = 0.2,
        categorySetting = sv.Extended,
        rarity = "rare",
    })
end

function HFO.LootDistro.CategoryConfig.ExtendedLarge(sv, enabledTables)
    HFO.LootDistro:processCategory({
        sv = sv,
        itemList = enabledTables.ExtendedLarge,
        locationType = "Extended",
        baseRate = 0.1,
        categorySetting = sv.Extended,
        rarity = "veryRare",
    })
end

function HFO.LootDistro.CategoryConfig.ExtendedDrum(sv, enabledTables)
    HFO.LootDistro:processCategory({
        sv = sv,
        itemList = enabledTables.ExtendedDrum,
        locationType = "Extended",
        baseRate = 0.05,
        categorySetting = sv.Extended,
        rarity = "veryRare",
    })
end

function HFO.LootDistro.CategoryConfig.SpeedLoaders(sv, enabledTables)
    HFO.LootDistro:processCategory({
        sv = sv,
        itemList = enabledTables.SpeedLoaders,
        locationType = "Extended",
        baseRate = 0.3,
        categorySetting = sv.Loot,
        rarity = "rare",
    })
end

---===========================================---
--                FIREARM SKINS                --
---===========================================---
function HFO.LootDistro.CategoryConfig.FirearmSkins(sv, enabledTables)
    HFO.LootDistro:processCategory({
        sv = sv,
        itemList = enabledTables.FirearmSkins,
        locationType = "FirearmSkins",
        baseRate = 0.5,
        categorySetting = sv.FirearmSkins,
        rarity = "rare",
    })
end

---===========================================---
--               CLEANING ITEMS                --
---===========================================---
function HFO.LootDistro.CategoryConfig.Cleaning(sv, enabledTables)
    HFO.LootDistro:processCategory({
        sv = sv,
        itemList = enabledTables.Cleaning,
        locationType = "Cleaning",
        baseRate = 2.5,
        categorySetting = sv.CleanRepairSpawns,
        rarity = "standard",
    })
end

---===========================================---
--                 REPAIR KITS                 --
---===========================================---
function HFO.LootDistro.CategoryConfig.RepairKits(sv, enabledTables)
    HFO.LootDistro:processCategory({
        sv = sv,
        itemList = enabledTables.RepairKits,
        locationType = "RepairKits",
        baseRate = 1.0,
        categorySetting = sv.CleanRepairSpawns,
        rarity = "standard",
    })
end

---===========================================---
--               FIREARM CACHES                --
---===========================================---
function HFO.LootDistro.CategoryConfig.FirearmCache(sv, enabledTables)
    HFO.LootDistro:processCategory({
        sv = sv,
        itemList = enabledTables.FirearmCache,
        locationType = "FirearmCache",
        baseRate = 0.4,
        categorySetting = sv.FirearmCache,
        rarity = "rare",
    })
end

---===========================================---
--                  MAGAZINES                  --
---===========================================---
function HFO.LootDistro.CategoryConfig.Magazines(sv, enabledTables)
    HFO.LootDistro:processCategory({
        sv = sv,
        itemList = enabledTables.Magazines,
        locationType = "Magazines",
        baseRate = 0.2,
        categorySetting = sv.Loot,
        rarity = "veryRare",
    })
end

---===========================================---
--                    CASES                    --
---===========================================---
function HFO.LootDistro.CategoryConfig.Cases(sv, enabledTables)
    HFO.LootDistro:processCategory({
        sv = sv,
        itemList = enabledTables.Cases,
        locationType = "Cases",
        baseRate = 0.5,
        categorySetting = sv.Loot,
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

Events.OnPreDistributionMerge.Add(function()
    -- Nuke vanilla junk first
    HFO.LootDistro:removeVanillaItems()

    -- Reset state
    HFO.LootDistro.AddedItems = {}
    HFO.LootDistro.RemovedItems = {}

    -- Add HFO loot
    local sv = HFO.SandboxUtils.get()
    local enabledTables = HFO.Loot.getEnabledItems()
    
    for categoryName, applyFunc in pairs(HFO.LootDistro.CategoryConfig) do
        if type(applyFunc) == "function" then
            applyFunc(sv, enabledTables) 
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


---===========================================---
--        DEBUG LOOT CHECK WITH HOTKEY         --
---===========================================---

local function debugHFOLootTables()
    -- Get and print sandbox variables
    local sv = HFO.SandboxUtils.get()
    print("=== HFO DEBUG - SANDBOX VARS ===")
    for k, v in pairs(sv) do
        print(k .. " = " .. tostring(v))
    end
    
    -- Get and print enabled items
    local enabledItems = HFO.Loot.getEnabledItems()
    print("=== HFO DEBUG - ENABLED ITEMS ===")
    for category, items in pairs(enabledItems) do
        print(category .. ": " .. #items .. " items")
        -- Print first few items as samples
        for i=1, math.min(3, #items) do
            print("  - " .. items[i])
        end
        if #items > 3 then print("  (and " .. (#items - 3) .. " more)") end
    end
    
    -- Check specific problem toggles
    print("=== HFO DEBUG - SPECIAL TOGGLES ===")
    local specialToggles = {"FGMG42", "CrossbowAmmoMag", "TShirtLauncher", "ColtCavalry", "ExclusiveFirearmSkins"}
    for _, toggle in ipairs(specialToggles) do
        print(toggle .. " enabled: " .. tostring(sv[toggle] == true))
    end

    print("=== DEBUG CRITICAL SETTINGS TYPES ===")
print("FGMG42 type: " .. type(sv.FGMG42) .. ", value: " .. tostring(sv.FGMG42))
print("TShirtLauncher type: " .. type(sv.TShirtLauncher) .. ", value: " .. tostring(sv.TShirtLauncher))
print("ColtCavalry type: " .. type(sv.ColtCavalry) .. ", value: " .. tostring(sv.ColtCavalry))
print("ExclusiveFirearmSkins type: " .. type(sv.ExclusiveFirearmSkins) .. ", value: " .. tostring(sv.ExclusiveFirearmSkins))
end

-- Register hotkey (use any key you want)
local function registerHFODebugHotkey()
    local function onKeyPressed(key)
        -- Debug hotkey: press CTRL + D
        if key == 67 then  -- 32 is 'D', 29 is 'CTRL'
            debugHFOLootTables()
        end
    end
    
    Events.OnKeyPressed.Add(onKeyPressed)
    print("HFO Debug Hotkey registered. Press CTRL+D to print loot table info.")
end

-- Call the registration function on game start
Events.OnGameStart.Add(registerHFODebugHotkey)