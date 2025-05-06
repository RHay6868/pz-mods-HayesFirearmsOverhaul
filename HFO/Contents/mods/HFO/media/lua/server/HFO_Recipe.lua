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
--        STRIPPER CLIP CONFIG AND LOGIC       --
---===========================================---

local stripperClipAmmoConfig = {
    ["762x54rBullets"] = { clipType = "762x54rStripperClip", maxPerClip = 5 },
}

local clipToAmmoType = {}
for ammo, clipConfig in pairs(stripperClipAmmoConfig) do
    clipToAmmoType[clipConfig.clipType] = ammo
end

-- Pack bullets into as many stripper clips as possible
local function createAllStripperClips(player, ammoType, clipType, maxPerClip)
    local inv = player:getInventory()
    local count = inv:getItemCount("Base." .. ammoType)
    if count < 1 then return end

    local fullClips = math.floor(count / maxPerClip)
    local remaining = count % maxPerClip

    -- Pack full clips
    for i = 1, fullClips do
        for j = 1, maxPerClip do
            local bullet = inv:FindAndReturn("Base." .. ammoType)
            if bullet then inv:Remove(bullet) end
        end

        local clip = InventoryItemFactory.CreateItem("Base." .. clipType)
        clip:setCurrentAmmoCount(maxPerClip)
        clip:setMaxAmmo(maxPerClip)
        inv:AddItem(clip)
    end

    -- Pack remaining bullets (if any)
    if remaining > 0 then
        for i = 1, remaining do
            local bullet = inv:FindAndReturn("Base." .. ammoType)
            if bullet then inv:Remove(bullet) end
        end

        local clip = InventoryItemFactory.CreateItem("Base." .. clipType)
        clip:setCurrentAmmoCount(remaining)
        clip:setMaxAmmo(maxPerClip)
        inv:AddItem(clip)
    end
end

-- Unpack all selected stripper clips
local function unpackAllStripperClips(player, items)
    local inv = player:getInventory()
    for i = 1, #items do
        local clip = items[i]
        if clip and instanceof(clip, "HandWeapon") then
            local ammoType = clipToAmmoType[clip:getType()]
            if ammoType then
                local count = clip:getCurrentAmmoCount() or 1
                for j = 1, count do
                    inv:AddItem("Base." .. ammoType)
                end
                inv:Remove(clip)
            end
        end
    end
end

-- Safely extract an InventoryItem from a context menu
local function getInventoryItem(entry)
    if instanceof(entry, "InventoryItem") then
        return entry
    elseif type(entry) == "table" and entry.items and #entry.items > 0 then
        return entry.items[1]
    end
    return nil
end

-- Context Menu fill
local function onFillInventoryContextMenu(player, context, items)
    local inv = getSpecificPlayer(player):getInventory()
    local unpackableClipItems = {}

    -- Check for all ammo types in stripperClipAmmoConfig
    for ammoType, clipConfig in pairs(stripperClipAmmoConfig) do
        if inv:getItemCount("Base." .. ammoType) >= 1 then
            context:addOption("Pack all " .. ammoType .. " into Stripper Clips", nil, function()
                createAllStripperClips(getSpecificPlayer(player), ammoType, clipConfig.clipType, clipConfig.maxPerClip)
            end)
        end
    end

    -- Check selected items for clip types to unpack
    for i = 1, #items do
        local entry = items[i]
        local item = getInventoryItem(entry) 
    
        if item and instanceof(item, "HandWeapon") then
            local t = item:getType()
            for _, clipConfig in pairs(stripperClipAmmoConfig) do
                if t == clipConfig.clipType then
                    table.insert(unpackableClipItems, item)
                end
            end
        end
    end

    if #unpackableClipItems > 0 then
        context:addOption("Unpack all selected Stripper Clips", nil, function()
            unpackAllStripperClips(getSpecificPlayer(player), unpackableClipItems)
        end)
    end
end

-- Register hook (vanilla compatible)
Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryContextMenu)


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