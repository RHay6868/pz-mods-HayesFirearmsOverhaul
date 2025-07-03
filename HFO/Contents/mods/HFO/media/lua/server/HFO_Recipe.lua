--============================================================--
--                  HFO_Recipes.lua                           --
--============================================================--
-- Purpose:
--   Implements custom crafting, conversion, cleaning, ammo can loot,
--   weapons cache, and stripper clip logic.
--
-- Overview:
--   This module registers custom recipe behavior, item tag lookups,
--   and scripted effects on create. It integrates with sandbox logic,
--   InnerVoice feedback, and dynamic loot source mapping for recipe-driven
--   item generation.
--
-- Core Features:
--   - Sawn-off weapon stat/part transfer (preserves condition and jam state)
--   - Firearm cleaning with skill + RNG-based repair and flavor responses
--   - Ammo Can and Weapon Cache opening with tiered loot pool logic
--   - Stripper Clip packing and unpacking via context menu options
--   - Dynamic registration of valid loot items per sandbox settings
--   - Suppressor Wrap transfer logic with condition + modData carryover
--
-- Responsibilities:
--   - Provide immersive and gameplay-balanced item transformation logic
--   - Integrate closely with HFO.Loot, HFO.Utils, and HFO.SandboxUtils
--   - Enhance gameplay through robust utility and crafting interaction
--
-- Dependencies:
--   - Requires HFO_Loot, HFO_Utils, HFO_Constants, and HFO_SandboxUtils
--   - Optional HFO.InnerVoice support for immersive feedback
--
-- Notes:
--   - This file is still actively being developed and extended
--   - MANY of these still need THOROUGH TESTING
--============================================================--

require "recipecode"
require "HFO_Utils"
require "HFO_SandboxUtils"
require "HFO_Constants"
require "HFO_Loot"

HFO = HFO or {};
HFO.Recipe = HFO.Recipe or {}

local sv = HFO.SandboxUtils.get() -- still testing some things with sandbox settings


---===========================================---
--          ADD CUSTOM TAGS FOR ITEMS          --
---===========================================---

function Recipe.GetItemTypes.Suppressor(scriptItems)
	scriptItems:addAll(getScriptManager():getItemsTag("Suppressor"))
end


---===========================================---
--            SAWN OFF SWAP FUNCTION           --
---===========================================---

function GeneralSawnWeapon_OnCreate(items, result, player)
	for i = 0, items:size() - 1 do
		local weapon = items:get(i)
		if HFO.Utils.isAimedFirearm(weapon) then

			HFO.Utils.applyWeaponStats(weapon, result)
			HFO.Utils.setWeaponParts(weapon, result)
			HFO.Utils.handleWeaponChamber(weapon, result, false)
			HFO.Utils.handleWeaponJam(weapon, result, true) -- preserve jam state

			-- Special: Remove recoil pad when sawing
			local recoilPad = weapon:getRecoilpad()
			if recoilPad and recoilPad:getFullType() == "Base.RecoilPad" then
				result:detachWeaponPart(recoilPad)
				player:getInventory():AddItem(recoilPad)
			end

			HFO.Utils.finalizeWeaponSwap(player, weapon, result)
			HFO.InnerVoice.say("WeaponSawedOff")
			return
		end
	end
end


---===========================================---
--         CLEANING FIREARMS MECHANICS         --
---===========================================---

function Recipe.OnCreate.FirearmCleaning(items, result, player)
	for i = 0, items:size() - 1 do
		local weapon = items:get(i)
		if not HFO.Utils.isAimedFirearm(weapon) then
			HFO.Utils.debugLog("Item is not a firearm")
			return
		end

		player:getInventory():AddItem("Base.RippedSheetsDirty") -- Always added

		local currentCondition = weapon:getCondition()
		local maxCondition = weapon:getConditionMax()

		local roll = ZombRand(1, 100)
		local didRepair = false -- repair flag
		local repairCountReduced = false -- repair count flag

		-- Step 2: Chance-based condition repair
		if currentCondition < maxCondition and roll > sv.CleaningFail then
			local newCondition = math.min(currentCondition + (1 + sv.CleaningStats), maxCondition)
			result:setCondition(newCondition)
			didRepair = true
		else
			result:setCondition(currentCondition)
		end

		-- Step 3: Repair count reduction
		if weapon:getHaveBeenRepaired() > 1 then
			local aiming = player:getPerkLevel(Perks.Aiming)
			local successRate = 0.05 + aiming * (0.01 * sv.CleaningRepairRate)
			if ZombRandFloat(0.0, 1.0) <= successRate then
				result:setHaveBeenRepaired(weapon:getHaveBeenRepaired() - 1)
				repairCountReduced = true
			else
                result:setHaveBeenRepaired(weapon:getHaveBeenRepaired())
            end
		end

		-- Step 4: Apply proper stat retention and utility functions
		HFO.Utils.applyWeaponStats(weapon, result)
		HFO.Utils.setWeaponParts(weapon, result)
        HFO.Utils.handleWeaponChamber(weapon, result, false)
        HFO.Utils.handleWeaponJam(weapon, result, false) 
		HFO.Utils.finalizeWeaponSwap(player, weapon, result)

		if didRepair and repairCountReduced then
			HFO.InnerVoice.say("CleanBonusSuccess")
		elseif didRepair then
			HFO.InnerVoice.say("CleanSuccess")
		else
			HFO.InnerVoice.say("CleanFail")
		end
		return
	end
end


---===========================================---
--           AMMO CAN LOOT RANDOMIZER          --
---===========================================---

function Recipe.OnCreate.OpenAmmoCan(items, result, player)
	local inv = player:getInventory()
	local spawns = {}

	-- Step 1: Pull valid ammo pools based on category
	local ammoPools = {
		Handguns = HFO.Loot.getEnabledItems("AmmoBox", "Handguns"),
		Rifles   = HFO.Loot.getEnabledItems("AmmoBox", "Rifles"),
		Shotguns = HFO.Loot.getEnabledItems("AmmoBox", "Shotguns"),
		Other    = HFO.Loot.getEnabledItems("AmmoBox", "Other"),
	}

	-- Step 2: Helper to add random ammo
	local function addRandomAmmo(category, count)
		local pool = ammoPools[category]
		if not pool or #pool == 0 then return end

		for _ = 1, count do
			local item = pool[ZombRand(#pool) + 1]
			table.insert(spawns, item) -- Already full ID now!
		end
	end

	-- Step 3: Determine drop mix
	local roll = ZombRand(100)

	if roll <= 20 then
		addRandomAmmo("Handguns", 8)
	elseif roll <= 40 then
		addRandomAmmo("Rifles", 6)
	elseif roll <= 60 then
		addRandomAmmo("Shotguns", 5)
	elseif roll <= 80 then
		addRandomAmmo("Handguns", 6)
		addRandomAmmo("Rifles", 6)
	elseif roll <= 94 then
		addRandomAmmo("Handguns", 5)
		addRandomAmmo("Rifles", 5)
		addRandomAmmo("Shotguns", 4)
	else -- r 95–99 (5% chance)
		addRandomAmmo("Other", 3)
	end

	-- Step 4: Add items to inventory
	for _, fullId in ipairs(spawns) do
		inv:AddItem(fullId)
		HFO.InnerVoice.say("OpenedAmmoCan")
	end
end


---===========================================---
--    WEAPON CACHE WEIGHTED LOOT RANDOMIZER    --
---===========================================---

local baseSources = { Base = {} }

local function addFromCategory(section, subtype, lootKey)
    local items = HFO.Loot.getEnabledItems(section, subtype)
    if not items or #items == 0 then return end

    baseSources.Base[lootKey] = baseSources.Base[lootKey] or {}
    for _, item in ipairs(items) do
        table.insert(baseSources.Base[lootKey], item)
    end
end 

-- AmmoBox categories
addFromCategory("AmmoBox", "Handguns",  "Ammo")
addFromCategory("AmmoBox", "Rifles",    "Ammo")
addFromCategory("AmmoBox", "Shotguns",  "Ammo")
addFromCategory("AmmoBox", "Other",     "Ammo")

-- Ammo mags
addFromCategory("AmmoMags", "Handguns", "AmmoMags")
addFromCategory("AmmoMags", "Rifles",   "AmmoMags")
addFromCategory("AmmoMags", "Other",    "AmmoMags")

-- Firearms by broad tier categories
addFromCategory("Firearms", "Handguns", "Firearms")
addFromCategory("Firearms", "SMGs",     "ExtensionFirearms")
addFromCategory("Firearms", "Rifles",   "Firearms")
addFromCategory("Firearms", "Snipers",  "RareExtensionFirearms")
addFromCategory("Firearms", "Shotguns", "Firearms")
addFromCategory("Firearms", "Other",    "ExtensionFirearms")

-- Skins
addFromCategory("FirearmSkins", "Base",      "Skins")
addFromCategory("FirearmSkins", "Exclusive", "Skins")

-- Repair kits
if HFO.SandboxUtils.get().RepairKits then
    addFromCategory("Mechanics", "RepairKits", "RepairItems")
end

-- Register loot
HFO.Recipe.cacheOptions = {}

function HFO.Recipe.registerLootSources(sourceTable)
    local seen = {}
    for moduleName, categories in pairs(sourceTable) do
        for lootType, items in pairs(categories) do
            HFO.Recipe.cacheOptions[lootType] = HFO.Recipe.cacheOptions[lootType] or {}
            for _, itemId in ipairs(items) do
                local fullId = moduleName .. "." .. itemId
                if not seen[fullId] then
                    table.insert(HFO.Recipe.cacheOptions[lootType], fullId)
                    seen[fullId] = true
                end
            end
        end
    end
end

HFO.Recipe.registerLootSources(baseSources)


HFO.Recipe.cacheLootTables = {
    {
        name = "commonCache",
        weight = 30,
        contents = {
            { type = "TieredDrop", tier = "common", count = 3, allowDuplicates = false  }
        }
    },
    {
        name = "uncommonCache",
        weight = 25,
        contents = {
            { type = "TieredDrop", tier = "uncommon", count = 2, allowDuplicates = false  }
        }
    },
    {
        name = "rareCache",
        weight = 20,
        contents = {
			{ type = "TieredDrop", tier = "rare", count = 2, allowDuplicates = false },
			{ type = "Ammo", count = 1 }
        }
    },
    {
        name = "premiumCache",
        weight = 15,
        contents = {
			{ type = "TieredDrop", tier = "uncommon", count = 1, allowDuplicates = false },
			{ type = "TieredDrop", tier = "premium", count = 1, allowDuplicates = false },
			{ type = "AmmoMags", count = 1 },
			{ type = "Ammo", count = 1 }
        }
    },
    {
        name = "legendaryCache",
        weight = 10,
        contents = {
			{ type = "TieredDrop", tier = "rare", count = 1 },
			{ type = "TieredDrop", tier = "legendary", count = 1, allowDuplicates = false },
			{ type = "Ammo", count = 1 },
			{ type = "AmmoMags", count = 1 }
        }
    }
}

function Recipe.OnCreate.OpenFirearmCache(items, result, player)
    local inv = player:getInventory()
    local lootRandom = HFO.Utils.getWeightedRandom(HFO.Recipe.cacheLootTables)

	for _, entry in ipairs(lootRandom.contents) do
        local itemType = entry.type
        local count = entry.count or 1
        local rolls = entry.rolls or count 
        local allowDuplicates = entry.allowDuplicates
	
		-- Handle tiered weapons
		if itemType == "TieredDrop" then
			itemType = HFO.Utils.getItemsFromTier(entry.tier or "common")
		end
	
        local options = HFO.Recipe.cacheOptions[itemType]
        if options and #options > 0 then
            local selectedItems = {}
            local maxUnique = #options

            -- Guardrails BEFORE the loop
            if not allowDuplicates and rolls > maxUnique then
                rolls = maxUnique
            end

            local attemptsMax = 10

            for _ = 1, rolls do
                local selected = options[ZombRand(#options) + 1]

                -- Retry until unique (if needed)
                if not allowDuplicates and rolls > 1 then
                    local attempts = 0
                    while selectedItems[selected] and attempts < attemptsMax do
                        selected = options[ZombRand(#options) + 1]
                        attempts = attempts + 1
                    end
                end

                selectedItems[selected] = true

                -- Add multiple copies if allowed
                for _ = 1, count do
                    inv:AddItem(selected)
					HFO.InnerVoice.say("OpenedCache")
                end
            end
        end
    end
end


---===========================================---
--                STRIPPER CLIPS               --
---===========================================---

-- Make clip from bullets
local function makeClip(player)
    local inv = player:getInventory()
    local bulletCount = inv:getItemCount("Base.762x54rBullets")
    if bulletCount < 1 then return end
    
    local roundsToUse = math.min(bulletCount, 5)
    
    -- Remove bullets
    for i = 1, roundsToUse do
        local bullet = inv:FindAndReturn("Base.762x54rBullets")
        if bullet then inv:Remove(bullet) end
    end
    
    -- Add clip
    local clip = InventoryItemFactory.CreateItem("Base.762x54rStripperClip")
    clip:setCurrentAmmoCount(roundsToUse)
    clip:setMaxAmmo(5)
    inv:AddItem(clip)
end

-- Break clip into bullets
local function breakClip(player, clip)
    local inv = player:getInventory()
    local rounds = clip:getCurrentAmmoCount() or 0
    
    -- Add bullets back
    for i = 1, rounds do
        inv:AddItem("Base.762x54rBullets")
    end
    
    -- Remove clip
    inv:Remove(clip)
end

-- Remove all empty clips
local function cleanupEmptyClips(player)
    local inv = player:getInventory()
    local items = inv:getItems()
    
    for i = items:size() - 1, 0, -1 do
        local item = items:get(i)
        if item and item:getFullType() == "Base.762x54rStripperClip" and item:getCurrentAmmoCount() == 0 then
            inv:DoRemoveItem(item)
        end
    end
end

-- Context menu
local function onStripperClipContextMenu(player, context, items)
    -- Only show if we actually clicked on an item
    if not items or #items == 0 then return end
    
    -- Extract the actual item
    local item = items[1]
    if item.items then item = item.items[1] end
    if not item or not item.getFullType then return end
    
    -- Right-clicked on bullets
    if item:getFullType() == "Base.762x54rBullets" then
        local inv = getSpecificPlayer(player):getInventory()
        local bulletCount = inv:getItemCount("Base.762x54rBullets")
        if bulletCount > 0 then
            local roundsToUse = math.min(bulletCount, 5)
            context:addOption("Make Mosin Stripper Clip (" .. roundsToUse .. " rounds)", nil, function()
                makeClip(getSpecificPlayer(player))
            end)
        end
        return
    end
    
    -- Right-clicked on clip
    if item:getFullType() == "Base.762x54rStripperClip" then
        if item:getCurrentAmmoCount() > 0 then
            context:addOption("Break Down Mosin Stripper Clip (" .. item:getCurrentAmmoCount() .. " rounds)", nil, function()
                breakClip(getSpecificPlayer(player), item)
            end)
        else
            -- Right-clicked on empty clip, offer cleanup
            context:addOption("Remove Empty Mosin Stripper Clips", nil, function()
                cleanupEmptyClips(getSpecificPlayer(player))
            end)
        end
        return
    end
end

Events.OnFillInventoryObjectContextMenu.Add(onStripperClipContextMenu)


---===========================================---
--   SNIPER SUPPRESSOR WRAPS CONDITION KEEPER  --
---===========================================---
       
function Recipe.OnCreate.SuppressorWrap(items, result, player)
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item:hasTag("Suppressor") then
            result:setCondition(item:getCondition())
            result:copyModData(item:getModData())
            -- Flavor text based on result type
            local resultType = result:getType()
            if string.find(resultType, "Woodland") then -- Some inner voice dialogue
                HFO.InnerVoice.say("WrapAppliedWoodland")
            elseif string.find(resultType, "Winter") then
                HFO.InnerVoice.say("WrapAppliedWinter")
            elseif string.find(resultType, "Desert") then
                HFO.InnerVoice.say("WrapAppliedDesert")
            else
                HFO.InnerVoice.say("WrapRemoved")
            end

            break
        end
    end
end