--============================================================--
--                        HFO_Utils.lua                       --
--============================================================--
-- Purpose:
--   Core gameplay utility functions for Hayes Firearms Overhaul (HFO).
--   Provides standardized helpers for player actions, weapon management,
--   transformations, stat manipulation, player interactions, and UI logic.
--
-- Features:
--   - Custom chat message handling 
--   - Safe access to player and equipped weapon references
--   - Hotbar management for equipped weapons
--   - Weapon transformation utilities (swapping, suffixes, ammo updates)
--   - Magazine/ammo compatibility and transformation maps
--   - Custom suffix naming, jam/chamber state retention, and part reattachment
--   - Weapon stat capture and formatted UI output
--   - Dynamic ammo stat conversion and scaled property logic
--
-- Responsibilities:
--   - Handle all core runtime interactions between player, inventory, weapons, and mod data
--   - Provide reusable, lightweight utility functions safe for both client and server use
--   - Enable consistent stat comparison and transformation logic
--
-- Usage:
--   - Must be required by weapon scripts, tooltip renderers, or event hooks
--   - Avoid placing constants, loot distribution, or sandbox config here
--   - Designed to work both client-side and server-safe where possible
--
-- Notes:
--   - This file assumes the presence of HFO.Constants 
--   - All public functions are exposed under `HFO.Utils`
--============================================================--

HFO = HFO or {}
HFO.Utils = HFO.Utils or {}

HFO.Utils.DATA_VERSION = 1

---===========================================---
--          DEBUG TESTING LOG PRINTS           --
---===========================================---

local isDebugEnabled = false

function HFO.Utils.debugLog(msg)
	if isDebugEnabled then -- define this global switch at the top of your script
		print("[HFO] " .. msg)
	end
end


---===========================================---
--        TOGGLE BOOLEAN STATE FUNCTIONS       --
---===========================================---

function HFO.Utils.toggleModDataBool(item, key)
    local md = item and item:getModData()
    if md then
        md[key] = not md[key]
        return md[key]
    end
end


---===========================================---
<<<<<<< Updated upstream
=======
--         OLD MODDATA MIGRATION PROCESS       --
---===========================================---

function HFO.Utils.migrateModData(item)
    if not item or not item.getModData then return false end
    
    local md = item:getModData()
    if not md or md.HFO_Migrated then return false end
    
    -- Migrate the 11 legacy keys
    local oldKeys = {
        "currentName", "LightOn", "currentAmmoType", "currentMagType",
        "MeleeSwap", "FoldSwap", "IntegratedSwap", 
        "MagBase", "MagExtSm", "MagExtLg", "MagDrum"
    }
    
    for _, key in ipairs(oldKeys) do
        if md[key] ~= nil then
            md["HFO_" .. key] = md[key]
            md[key] = nil -- Clear old key
        end
    end
    
    md.HFO_Migrated = true
    return true
end

---===========================================---
--   UPDATE NEW MISSING MODDATA ON OLD ITEMS   --
---===========================================---

function HFO.Utils.initializeNewModData(item)
    if not item or not item.getModData then 
        return false 
    end
    
    local md = item:getModData()
    if md.HFO_DataVersion == HFO.Utils.DATA_VERSION then 
        return false 
    end
    
    local freshItem = InventoryItemFactory.CreateItem(item:getFullType())
    if not freshItem then 
        return false 
    end
    
    local freshMd = freshItem:getModData()
    local fieldsToCheck = {
        "HFO_AmmoTypeBase",
        "HFO_AmmoTypeAdditional", 
        "HFO_GunPlatingOptions"
    }
    
    local updated = false
    for _, field in ipairs(fieldsToCheck) do
        if freshMd[field] and not md[field] then
            HFO.Utils.debugLog("DEBUG: Adding " .. field .. ": " .. tostring(freshMd[field]))
            md[field] = freshMd[field]
            updated = true
        end
    end
    
    if updated then
        md.HFO_DataVersion = HFO.Utils.DATA_VERSION
        HFO.Utils.debugLog("DEBUG: Updated to version " .. tostring(HFO.Utils.DATA_VERSION))
    end
    
    return updated
end

---===========================================---
--           UPDATE MODDATA FOR WEAPON         --
---===========================================---

function HFO.Utils.storePreSwapStats(weapon)
    if not weapon or not instanceof(weapon, "HandWeapon") or not weapon:isAimedFirearm() then return end
    local md = weapon:getModData()
    if md.HFO_PreSwapStats then 
        --HFO.Utils.debugLog("Baseline already exists, skipping")
        return 
    end

    local weaponType = weapon:getFullType()
    
    -- Get the base weapon type (strip variant suffixes)
    local baseWeaponType = weaponType
    for _, suffixInfo in ipairs(HFO.Constants.SuffixMappings) do
        if weaponType:find(suffixInfo.swaptype) then
            baseWeaponType = weaponType:gsub(suffixInfo.swaptype, "")
            break
        end
    end
    
    HFO.Utils.debugLog("Creating clean weapon for: " .. baseWeaponType)
    
    -- Create a fresh weapon instance to get clean script stats
    local cleanWeapon = InventoryItemFactory.CreateItem(baseWeaponType)
    if cleanWeapon then
        -- Create the baseline table
        local baseline = {
            maxDamage = cleanWeapon:getMaxDamage(),
            minDamage = cleanWeapon:getMinDamage(),
            aimingTime = cleanWeapon:getAimingTime(),
            reloadTime = cleanWeapon:getReloadTime(),
            recoilDelay = cleanWeapon:getRecoilDelay(),
            hitChance = cleanWeapon:getHitChance(),
            maxRange = cleanWeapon:getMaxRange(),
            minAngle = cleanWeapon:getMinAngle(),
            ammoType = cleanWeapon:getAmmoType(),
            magazineType = cleanWeapon:getMagazineType(),
            maxHitCount = cleanWeapon:getMaxHitCount(),        
            projectileCount = cleanWeapon:getProjectileCount(), 
        }

        md.HFO_PreSwapStats = baseline
    end
end


---===========================================---
>>>>>>> Stashed changes
--       CYCLE THROUGH INDEX OF OPTIONS        --
---===========================================---

-- helper for extended mag swaps, firemode changes, and ammo caliber swaps
function HFO.Utils.getNextPrevFromList(list, currentValue) 
    if not list or #list <= 1 then return nil end

    local currentIndex = 1 
    for i, val in ipairs(list) do
        if val == currentValue then
            currentIndex = i
            break
        end
    end

    local nextIndex = (currentIndex % #list) + 1
    local prevIndex = (currentIndex - 2 + #list) % #list + 1

    return {
        list         = list,
        current      = currentValue,
        currentIndex = currentIndex,
        next         = list[nextIndex],
        prev         = list[prevIndex],
    }
end


---===========================================---
--         PATH FIX FOR TEXTURE ICONS          --
---===========================================---

function HFO.Utils.getItemTexture(iconName)
	if not iconName or iconName == "" then
		return getTexture("media/ui/CarKey.png")
	end

	local candidates = {
		"media/textures/" .. iconName .. ".png",
		"media/textures/Item_" .. iconName .. ".png",
		"media/ui/" .. iconName .. ".png",
		"media/ui/Item_" .. iconName .. ".png"
	}

	for _, path in ipairs(candidates) do
		local tex = getTexture(path)
		if tex then return tex end
	end

	return getTexture("media/ui/CarKey.png")
end


---===========================================---
--           IN GAME TEXT FOR ACTIONS          --
---===========================================---

-- To provide contextual feedback during gameplay will add future optioon to customize color
function HFO.Utils.PlayerSay(text)
	local player = getSpecificPlayer(0)
	if not player then
		print("[HFO] No valid player for PlayerSay: " .. tostring(text))
		return
	end
    
	-- If PARP exists and has a halo message method, use it
	if getActivatedMods():contains("BTSE_Base") and PARP then
		if not PARP.sayCustomMessage then
			function PARP:sayCustomMessage(message)
				local r, g, b = 0.2, 0.7, 0.7
				PARP:sayHaloMessage(message, PARP:getPlayer(), r, g, b)
			end
		end
		PARP:sayCustomMessage(text)
		return
	end

	-- Fallback: manually mimic halo message
	if player.setHaloNote then
		player:setHaloNote(text, 51, 178, 178, 300) -- cyan-ish
	else
		player:addLineChatElement(text)
	end
end


---===========================================---
--         CHECK FOR PLAYER AND WEAPON         --
---===========================================---

-- Helper used often to check for player and if player is equipped with a weapon 
function HFO.Utils.safeGetPlayer(index)
    if not getSpecificPlayer then return nil end
    return getSpecificPlayer(index or 0)
end

function HFO.Utils.getPlayerAndWeapon(index) 
    local player = HFO.Utils.safeGetPlayer(index)
    if not player then
        return nil, nil
    end

    local weapon = player:getPrimaryHandItem()
    if not weapon then
        return nil, nil
    end

    return player, weapon
end


---===========================================---
--              CHECK FOR FIREARM              --
---===========================================---

function HFO.Utils.isAimedFirearm(weapon)
    return weapon and instanceof(weapon, "HandWeapon") and weapon:isAimedFirearm()
end


---===========================================---
--              CHECK HOTBAR ITEMS             --
---===========================================---

function HFO.Utils.checkHotbar(weapon, result)  
	local hotbar = getPlayerHotbar(0)  
	if hotbar == nil then -- make sure there is a hotbar to check
		return
	end

	local weaponSlot = weapon:getAttachedSlot() -- check for weapon on hotbar and take it off before it is transformed and put back on afterwards
	local slot = hotbar.availableSlot[weaponSlot]
	if slot and result and not hotbar:isInHotbar(result) and hotbar:canBeAttached(slot, result) then 
		hotbar:removeItem(weapon, false)
		local attachmentType = result:getAttachmentType()
		local attachment = slot.def.attachments[attachmentType]
		hotbar:attachItem(result, attachment, weaponSlot, slot.def, false)
	end
end


---===========================================---
--          CHECK FOR EQUIPPED RESULT          --
---===========================================---

function HFO.Utils.handleEquippedWeapon(player, weapon, result)
	local player, weapon = HFO.Utils.getPlayerAndWeapon()
	if not player or not weapon then return end

	if instanceof(result, "HandWeapon") then -- Making sure to keep things equipped correctly between swaps
		player:setPrimaryHandItem(result)
		if result:isRequiresEquippedBothHands() or result:isTwoHandWeapon() then
			player:setSecondaryHandItem(result)
		else
			player:setSecondaryHandItem(nil)
		end
	end
end


---===========================================---
--             CHECK FOR MELEE MODE            --
---===========================================---

function HFO.Utils.isInMeleeMode(weapon) -- At times need to handle situations when firearms are in melee mode
    if not weapon then return false end
    local md = weapon:getModData()
    local result = not weapon:isRanged() and md and md.MeleeSwap ~= nil
    HFO.Utils.debugLog("isInMeleeMode for " .. tostring(weapon:getFullType()) .. ": " .. tostring(result))
    return result
end


---===========================================---
--    APPLY CUSTOM NAME + SUFFIX TO WEAPON     --
---===========================================---

-- Grab and apply correct suffix if applicable [Melee], [Bipod], [Folded], etc.
function HFO.Utils.getSuffix(weaponType)
    for _, suffixInfo in ipairs(HFO.Constants.SuffixMappings) do
        if string.find(weaponType, suffixInfo.swaptype) then
            return suffixInfo.suffix
        end
    end
    return ""
end

function HFO.Utils.sanitizeWeaponName(name)
    if not name then return "" end
    return string.gsub(name, "%s*%[.*%]$", "")
end

function HFO.Utils.applySuffixToWeaponName(weapon, suffixType)
    if not weapon or not HFO.Utils.isAimedFirearm(weapon) then return end

    local md  = weapon:getModData()

    -- Preserve original name if not already set
    if not md.currentName then
        md.currentName = HFO.Utils.sanitizeWeaponName(weapon:getName())
    end

    local baseName = HFO.Utils.sanitizeWeaponName(md.currentName)
    local suffix   = HFO.Utils.getSuffix(suffixType or weapon:getType())
    local newName  = baseName .. suffix

    weapon:setName(newName)
end


---===========================================---
--       WEAPON STAT RETENTION FUNCTION        --
---===========================================---

-- Swaps need to maintain consistency as not to lose stats of the previous version
function HFO.Utils.applyWeaponStats(weapon, result, isMelee)
    local md              = result:getModData()
    local weaponModData   = weapon:getModData()

    result:setHaveBeenRepaired(weapon:getHaveBeenRepaired())
    result:setFireMode(weapon:getFireMode())

    if weapon:isContainsClip() ~= nil then
        result:setContainsClip(weapon:isContainsClip())
    end

    if weapon:getMaxAmmo() and weapon:getMaxAmmo() > 0 then
        result:setMaxAmmo(weapon:getMaxAmmo())
        result:setCurrentAmmoCount(weapon:getCurrentAmmoCount())
    end

    result:setCondition(weapon:getCondition())

    md.LightOn = weaponModData.LightOn == true

    -- Only apply melee logic if EXPLICITLY told it's a melee variant
    if isMelee then
        local scriptItem  = result:getScriptItem()
        local meleeRange  = scriptItem and scriptItem:getMaxRange() or result:getMaxRange()
        local maxDamage   = result:getMaxDamage()
        local minDamage   = result:getMinDamage()
        local critChance  = result:getCriticalChance()
        local impactSound = result:getImpactSound()

        local canon = result:getCanon()
        if canon and (string.find(canon:getType(), "Bayonnet") or string.find(canon:getType(), "Bayonet")) then
            maxDamage     = 1
            minDamage     = 0.6
            critChance    = 10
            meleeRange    = meleeRange + 0.4
            impactSound   = "HuntingKnifeHit"
        end

        result:setMaxRange(meleeRange)
        result:setMaxDamage(maxDamage)
        result:setMinDamage(minDamage)
        result:setCriticalChance(critChance)
        result:setImpactSound(impactSound)
    end
end


---===========================================---
--       GET ALL WEAPON PARTS AVAILABLE        --
---===========================================---

-- Mostly used to make sure we snag all attachments for swaps
function HFO.Utils.getAllWeaponPartsInInventory(player)
    local inv = player:getInventory()
    local all = {}

    for i = 0, inv:getItems():size() - 1 do
        local item = inv:getItems():get(i)
        if item and item.getPartType and item:getPartType() then
            table.insert(all, item)
        end
    end

    return all
end


---===========================================---
--          RESET WEAPON PARTS ON SWAP         --
---===========================================---

function HFO.Utils.setWeaponParts(weapon, result)
    if not HFO.Utils.isAimedFirearm(weapon) or not HFO.Utils.isAimedFirearm(result) then return end

    -- Attach all parts from defined constants
    for _, part in ipairs(HFO.Constants.WeaponAttachmentParts) do
        local weaponPart = weapon[part.get](weapon)
        if weaponPart ~= nil then
            result[part.attach](result, weaponPart)
        end
    end
end


---===========================================---
--       DETACH BROKEN PART FROM WEAPON        --
---===========================================---

-- For when suppressors break or we need to reset a weaponpart in mid swaps
function HFO.Utils.detachBrokenPart(player, weapon, part, fallbackSwingSound)
    weapon:detachWeaponPart(part)
    player:getInventory():AddItem(part)
    player:resetEquippedHandsModels()

    if fallbackSwingSound then
        weapon:setSwingSound(fallbackSwingSound)
    end
end


---===========================================---
--          JAMMED AND CHAMBER STATUS          --
---===========================================---

function HFO.Utils.handleWeaponJam(weapon, result, shouldPreserveJam)
    if shouldPreserveJam and weapon:isJammed() then
        result:setJammed(true)
    elseif weapon:isJammed() and not shouldPreserveJam then
        result:setJammed(false)
    end
end

function HFO.Utils.handleWeaponChamber(weapon, result, isToMelee)
    local wasChambered = weapon:haveChamber() and weapon:isRoundChambered()
    weapon:getModData().HFO_WasChambered = wasChambered
    
    if result:haveChamber() then
        if not isToMelee and result:isAimedHandWeapon() then
            result:setRoundChambered(wasChambered)
        else
            result:setRoundChambered(false) -- Melee mode or fallback case
        end
    end
    
    return wasChambered -- Return this in case the caller needs it
end


---===========================================---
--      CACHE AND RESTORE CUSTOM MOD DATA      --
---===========================================---

<<<<<<< Updated upstream
-- Will be updated more thoroughly but currently makes sure we dont miss HFO data on swaps
function HFO.Utils.cachedHFOModData(obj)
	local md = obj:getModData()
	local cache = {}
=======
-- instead of hardcoding stat changes in item script adding in chages here for _Bipod, _Folded, _Grip, _Extended, and _GripExtended
function HFO.Utils.applyVariantModifications(weapon)
    if not weapon or not HFO.Utils.isAimedFirearm(weapon) then return end
    local md = weapon:getModData()
    if md.HFO_VariantApplied then return end -- Already applied
    
    local weaponType = weapon:getFullType()
    
    local variantSuffix = nil
    for suffix, mods in pairs(HFO.Constants.VariantModifications) do
        if weaponType:find(suffix) then
            variantSuffix = suffix
            break
        end
    end
>>>>>>> Stashed changes

	for _, key in ipairs(HFO.Constants.TrackedModData) do
		cache[key] = md[key]
	end

	return cache
end

function HFO.Utils.restoreHFOModData(result, cache)
	if not cache then return end
	local md = result:getModData()

	for _, key in ipairs(HFO.Constants.TrackedModData) do
		if cache[key] ~= nil then
			md[key] = cache[key]
		end
	end
end


---===========================================---
--          FINALIZE WEAPON SWAP LOGIC         --
---===========================================---

-- Where we grab our HFO data, copy all other moddata, reapply our HFO data and finishing our updated weapon 
function HFO.Utils.finalizeWeaponSwap(player, weapon, result) 

	local cached = HFO.Utils.cachedHFOModData(result)
	HFO.Utils.debugLog("Cached MeleeSwap: " .. tostring(cached and cached.MeleeSwap or "nil"))

    -- Preserve all existing modData
    result:copyModData(weapon:getModData()) 

    HFO.Utils.debugLog("restoreHFOModData")
	HFO.Utils.restoreHFOModData(result, cached)  -- restore the cached modData for HFO mechanics
    HFO.Utils.debugLog(">>> Running finalizeWeaponSwap")

    BWTweaks:checkForModelChange(result)
    HFO.Utils.handleEquippedWeapon(player, weapon, result)
    HFO.Utils.checkHotbar(weapon, result)
    player:getInventory():AddItem(result)
    player:getInventory():DoRemoveItem(weapon)
end


---===========================================---
--           GENERIC SWAP ENTRYPOINT           --
---===========================================---

-- For simple swaps like Bipod, Fold, Grips that don't need addiitonal configurations
function HFO.Utils.runGenericSwap(modDataField)
    local player, weapon = HFO.Utils.getPlayerAndWeapon()
    if not HFO.Utils.isAimedFirearm(weapon) then return end

    local swapType = weapon:getModData()[modDataField]
    if not swapType then return end

    local result = InventoryItemFactory.CreateItem(swapType)
    if not result then return end

	HFO.Utils.applySuffixToWeaponName(result)
	HFO.Utils.applyWeaponStats(weapon, result)
	HFO.Utils.setWeaponParts(weapon, result)
    HFO.Utils.handleWeaponChamber(weapon, result, false)
    HFO.Utils.handleWeaponJam(weapon, result, true)
	HFO.Utils.finalizeWeaponSwap(player, weapon, result)
end


---===========================================---
--              MAGAZINE INFO MAPS             --
---===========================================---

-- Main place for all truths to extended mags used in radial menus, hotkeys, and inner voice
function HFO.Utils.getMagazineInfoMaps(md)
    local nameMap = {}
    local iconMap = {}
    local typeMap = {} 

    if md.MagBase then
        nameMap[md.MagBase] = getText("IGUI_HFO_DefaultMag")
        iconMap[md.MagBase] = "HFO_swap_base"
        typeMap[md.MagBase] = md.MagBase
    end

    if md.MagExtSm then
        nameMap[md.MagExtSm] = getText("IGUI_HFO_ExtSm")
        iconMap[md.MagExtSm] = "HFO_swap_sm"
        typeMap[md.MagExtSm] = md.MagExtSm
    end

    if md.MagExtLg then
        nameMap[md.MagExtLg] = getText("IGUI_HFO_ExtLg")
        iconMap[md.MagExtLg] = "HFO_swap_lg"
        typeMap[md.MagExtLg] = md.MagExtLg
    end

    if md.MagDrum then
        nameMap[md.MagDrum] = getText("IGUI_HFO_Drum")
        iconMap[md.MagDrum] = "HFO_swap_drum"
        typeMap[md.MagDrum] = md.MagDrum
    end

    return {
        nameMap = nameMap,
        iconMap = iconMap,
        typeMap = typeMap 
    }
end


---===========================================---
--     UI AND WEAPON STAT HELPER FUNCTIONS     --
---===========================================---
-- Our sources of truth gathered and formatted for custom tooltips and weapon viewer UI

-- Get minangle accuracy cone description 
function HFO.Utils.getAccuracyConeDescription(angle)
    if angle >= 0.990 then return "Pinpoint"
    elseif angle >= 0.980 then return "Narrow"
    elseif angle >= 0.970 then return "Focused"
    elseif angle >= 0.955 then return "Standard"
    elseif angle >= 0.940 then return "Broad"
    elseif angle >= 0.925 then return "Wide"
    elseif angle >= 0.910 then return "Very Wide"
    else return "Scattershot"
    end
end

-- Get custom reload speed description
function HFO.Utils.getReloadSpeedDescription(multiplier)
    if multiplier >= 2.4 then return "Fastest"
    elseif multiplier >= 2.0 then return "Extemely Fast"
    elseif multiplier >= 1.6 then return "Very Fast"
    elseif multiplier >= 1.2 then return "Fast"
    elseif multiplier >= 0.9 then return "Average"
    elseif multiplier >= 0.7 then return "Slow"
    elseif multiplier >= 0.5 then return "Very Slow"
    else return "Slowest"
    end
end

-- Easier to understand depiction of aiming speed recovery
function HFO.Utils.getAimingSpeedDescription(value)
    if value >= 85 then return "Fastest"
    elseif value >= 70 then return "Very Fast"
    elseif value >= 60 then return "Fast"
    elseif value >= 50 then return "Quick"
    elseif value >= 40 then return "Average"
    elseif value >= 30 then return "Steady"
    elseif value >= 20 then return "Slow"
    elseif value >= 10  then return "Very Slow"
    else return "Sluggish"
    end
end

-- Gets us the proper way to show names in tooltips and UI
function HFO.Utils.getDisplayNameFromFullType(fullType)
    if not fullType or fullType == "" then return "None" end
    if fullType:find("^Base%.") then
        local item = InventoryItemFactory.CreateItem(fullType)
        if item then return item:getDisplayName() end
        return fullType:gsub("^Base%.", "")
    end
    return fullType
end

-- Skip suffix on [Melee] [Bipod] [Folded] and other variants for streamlined mount on list
function HFO.Utils.shouldSkipSuffix(fullType)
    if not fullType then return false end
    
    -- Check against our suffix mappings list
    for _, entry in ipairs(HFO.Constants.SuffixMappings or {}) do
        if fullType:ends(entry.swaptype) then
            return true
        end
    end
    return false
end

-- Get valid magazine types for a weapon this is to properly populate Clip attachment tooltip 
function HFO.Utils.getValidMagazineTypes(weapon)
    if not weapon then return {} end

    local md = weapon:getModData() or {}
    return {
        weapon:getMagazineType(),
        md.MagExtSm or "",
        md.MagExtLg or "",
        md.MagDrum or "",
        md.MagBase or ""
    }
end

-- Get accurate adjusted weapon stats based on player skills
function HFO.Utils.getAdjustedWeaponStats(player, weapon)
    if not weapon then return {} end

    local aimingLevel = player and player:getPerkLevel(Perks.Aiming) or 0
    local halfLevel = aimingLevel / 2
    local adjustedStats = {}

    local baseHit    = weapon:getHitChance()
    local hitMod     = weapon:getAimingPerkHitChanceModifier()
    adjustedStats.hitChance  = math.floor(math.min(baseHit + (hitMod * aimingLevel), 95))

    local baseAngle  = weapon:getMinAngle()
    local angleMod   = weapon:getAimingPerkMinAngleModifier()
    adjustedStats.minAngle   = baseAngle - (angleMod * halfLevel)

    local baseRange  = weapon:getMaxRange()
    local rangeMod   = weapon:getAimingPerkRangeModifier()
    adjustedStats.maxRange   = baseRange + (rangeMod * halfLevel)

    local critMod    = weapon:getAimingPerkCritModifier()
    local baseCrit   = 0
    if weapon.getFullType then
        local scriptItem = InventoryItemFactory.CreateItem(weapon:getFullType())
        baseCrit = scriptItem and scriptItem.getCriticalChance and scriptItem:getCriticalChance() or 0
    end

    -- Calculate crit chance and clamp between 10 and 90 as to mirror the core game
    local critChance = baseCrit + (critMod * halfLevel) + (aimingLevel * 3)
    adjustedStats.critChance = math.floor(math.max(10, math.min(critChance, 90)))

    if weapon:isRanged() == true then
        local baseRecoil = weapon:getRecoilDelay()
        local modified = baseRecoil * (1.0 - (aimingLevel / 30.0))
        adjustedStats.recoilDelay = math.max(0, math.floor(modified + 0.5))
    else
        adjustedStats.recoilDelay = 0
    end

    return adjustedStats
end


---===========================================---
--        WEAPON STAT CORE TOOLS FOR UI        --
---===========================================---

-- Core stat definitions - SINGLE SOURCE OF TRUTH
HFO.Stats = {
    definitions = {
        { key = "minDamage", label = "Min Damage", priority = 10, format = "%.1f" },
        { key = "maxDamage", label = "Max Damage", priority = 11, format = "%.1f" },
        { key = "range", label = "Range", priority = 20, format = "%.0f" },
        { key = "hitChance", label = "Hit Chance", priority = 30, format = "%.0f%%", isPercent = true },
        { key = "critChance", label = "Critical Chance", priority = 40, format = "%.0f%%", isPercent = true },
        { key = "recoilDelay", label = "Recoil Delay", priority = 50, format = "%.0f" },
        { key = "minAngle", label = "Firing Cone", priority = 60, format = "%.3f", lowerIsBetter = true, 
          formatFunc = function(val) return HFO.Utils.getAccuracyConeDescription(val) end },
        { key = "aimingTime", label = "Aiming Speed", priority = 70, format = "%.2f", 
          formatFunc = function(val) return HFO.Utils.getAimingSpeedDescription(val) end },
        { key = "reloadSpeed", label = "Reload Speed", priority = 80, format = "%.2f", 
          formatFunc = function(val) return HFO.Utils.getReloadSpeedDescription(val) end },
        { key = "soundRadius", label = "Sound Radius", priority = 90, format = "%.0f", lowerIsBetter = true },
        { key = "weight", label = "Weight", priority = 100, format = "%.2f kg", lowerIsBetter = true },
    },
    
    -- Lookup a stat definition by key
    getDefinition = function(key)
        for _, def in ipairs(HFO.Stats.definitions) do
            if def.key == key then return def end
        end
        return nil
    end,
    
    formatValue = function(key, value, useChange)
        local def = HFO.Stats.getDefinition(key)
        if not def then return tostring(value) end
        
        -- Use custom formatter if available
        if def.formatFunc then
            return def.formatFunc(value)
        end
        
        local prefix = useChange and value ~= 0 and (value > 0 and "+" or "") or ""
        return prefix .. string.format(def.format, value)
    end,
    
    -- Determine if a stat change is positive or negative this fed into the game settings Green and Red
    isPositiveChange = function(key, change)
        local def = HFO.Stats.getDefinition(key)
        if not def then return change > 0 end
        
        local isIncrease = change > 0
        return (isIncrease and not def.lowerIsBetter) or (not isIncrease and def.lowerIsBetter)
    end,
    
    -- Get indicators (icon, color) for a stat change where we call vanilla Green and Red colors
    getChangeIndicators = function(key, from, to)
        if not from or not to or type(from) ~= "number" or type(to) ~= "number" then
            return HFO.Constants.StatChangeIndicators["neutral"], false
        end
        
        local change = to - from
        if math.abs(change) < 0.0001 then 
            return HFO.Constants.StatChangeIndicators["neutral"], false 
        end
        
        local def = HFO.Stats.getDefinition(key)
        local lowerIsBetter = def and def.lowerIsBetter or false
        local isIncrease = change > 0
        local isPositive = (isIncrease and not lowerIsBetter) or (not isIncrease and lowerIsBetter)
        local indicatorKey = (isPositive and "pos" or "neg") .. (isIncrease and "Increase" or "Decrease")
        
        return HFO.Constants.StatChangeIndicators[indicatorKey] or HFO.Constants.StatChangeIndicators["neutral"], isPositive
    end
}


---===========================================---
--    WEAPON STAT COLLECTION AND FORMATTING    --
---===========================================---

-- Gathers raw weapon stats for tooltip and UI purposes
function HFO.Utils.getRawWeaponStats(weapon, player, options)
    if not weapon or not instanceof(weapon, "HandWeapon") then return {} end

    local md = weapon:getModData() or {}
    player = player or getPlayer()
    options = options or {}

    local adjustedStats = HFO.Utils.getAdjustedWeaponStats(player, weapon)

    local stats = {
        damage = string.format("%.1f - %.1f", weapon:getMinDamage(), weapon:getMaxDamage()),
        minDamage = weapon:getMinDamage(),
        maxDamage = weapon:getMaxDamage(),
        range = adjustedStats.maxRange or weapon:getMaxRange(),
        hitChance = adjustedStats.hitChance or weapon:getHitChance(),
        critChance = adjustedStats.critChance,
        recoilDelay = adjustedStats.recoilDelay or weapon:getRecoilDelay(),
        minAngle = adjustedStats.minAngle or weapon:getMinAngle(),
        aimingTime = weapon:getAimingTime(),

        condition = weapon:getCondition(),
        conditionMax = weapon:getConditionMax(),

        ammoType = weapon:getAmmoType(),
        magazineType = weapon:getMagazineType(),

        jamChance = HFO.ReloadUtils.calculateJamChance(player, weapon),

        reloadSpeed = HFO.ReloadUtils.getReloadSpeedModifier(player, weapon),

        soundRadius = weapon:getSoundRadius(),
        timesRepaired = weapon.getHaveBeenRepaired and (weapon:getHaveBeenRepaired() - 1) or 0,

        weight = weapon:getWeight(),
    }

    -- Ammo
    if not options.skipAmmo and weapon.getCurrentAmmoCount then
        stats.currentAmmo = weapon:getCurrentAmmoCount()
        stats.maxAmmo = weapon.getMaxAmmo and weapon:getMaxAmmo() or 0
    end

    -- Gun Plating
    if md.GunPlating and options.includePlating ~= false then
        if type(md.GunPlating) == "string" and md.GunPlating ~= "" then
            stats.gunPlating = md.GunPlating
        end
    end

    -- Suppressor
    local canonPart = (options.previewPart and options.previewPart:getPartType() == "Canon")
        and options.previewPart
        or (weapon.getCanon and weapon:getCanon())

    if canonPart and canonPart:hasTag("Suppressor") then
        for key, info in pairs(HFO.Constants.SuppressorLevels) do
            if canonPart:getType():find(key) then
                stats.suppressor = {
                    type = key,
                    name = key:gsub("Suppressor", "") .. " Suppressor",
                    reductionPercent = info.radius or 0,
                }
                stats.soundRadius = weapon:getSoundRadius()
                stats.soundRadiusDescription = info.radius and string.format("(reduced by %d%%)", info.radius) or nil
                break
            end
        end
    else
        stats.soundRadius = stats.baseSoundRadius
    end

    return stats
end

-- Format weapon stats for tooltips and UI
function HFO.Utils.formatWeaponStats(rawStats)
    if not rawStats then return {} end

    local formattedStats = {}

    local function add(label, value, section, opts)
        opts = opts or {}
        local rawValue = opts.raw or tonumber(value) or value
        local formattedValue = opts.formatted or value

        table.insert(formattedStats, {
            label = label,
            value = value,
            formatted = formattedValue,
            raw = rawValue,
            section = section or "core",
            
        })
    end

    -- Core numeric stats
    for _, def in ipairs(HFO.Stats.definitions) do
        local value = rawStats[def.key]
        if value and def.key ~= "soundRadius" then
            add(def.label, value, "core", {
                formatted = HFO.Stats.formatValue(def.key, value),
                raw = value
            })
        end
    end

    -- Other stats (non-numeric or special display)
    if rawStats.damage then
        add("Damage", rawStats.damage, "core", {formatted = rawStats.damage, raw = rawStats.damage})
    end

    -- Now handle Sound Radius with the description in one place only
    if rawStats.soundRadius then
        local soundText = string.format("%.0f", rawStats.soundRadius)
        if rawStats.soundRadiusDescription and rawStats.soundRadiusDescription ~= "" then
            soundText = soundText .. " " .. rawStats.soundRadiusDescription
        end
        add("Sound Radius", soundText, "core", {formatted = soundText, raw = rawStats.soundRadius})
    end

    -- Condition
    if rawStats.condition and rawStats.conditionMax then
        add("Condition", string.format("%d / %d", rawStats.condition, rawStats.conditionMax))
    end

    -- Ammo
    if rawStats.ammoType then
        add("Ammo Type", HFO.Utils.getDisplayNameFromFullType(rawStats.ammoType))
    end

    if rawStats.magazineType then
        add("Magazine Type", HFO.Utils.getDisplayNameFromFullType(rawStats.magazineType))
    end

    if rawStats.currentAmmo ~= nil then
        local ammoText = rawStats.maxAmmo > 0
            and string.format("%d / %d", rawStats.currentAmmo, rawStats.maxAmmo)
            or tostring(rawStats.currentAmmo)
        add("Ammo", ammoText)
    end

    -- Repairs
    if rawStats.timesRepaired then
        add("Times Repaired", tostring(rawStats.timesRepaired))
    end

    -- Cosmetic especially now that we moved into our own context menu we need to show it in tooltip
    if rawStats.gunPlating then
        local platingName = rawStats.gunPlating:gsub("GunPlating", ""):gsub("([A-Z])", " %1"):trim()
        add("Gun Plating", platingName == "" and "Standard" or platingName, "cosmetic")
    end

    -- Suppressor
    if rawStats.suppressor then
        add("Suppressor", rawStats.suppressor.name, "suppressor")
    end

    return formattedStats
end

-- Backward compatibility wrapper
function HFO.Utils.getWeaponStats(weapon, options)
    if not weapon or not instanceof(weapon, "HandWeapon") then return {} end

    local player = getPlayer()
    local rawStats = HFO.Utils.getRawWeaponStats(weapon, player, options)
    return HFO.Utils.formatWeaponStats(rawStats)
end


---===========================================---
--     COMPARE WEAPON STATS BASED ON PARTS     --
---===========================================---

-- Simulated weapon stat comparison from a snapshot of held gun and compared parts
function HFO.Utils.compareWeaponStats(weapon, part, options)
    if not weapon or not part or not HFO.Utils.isAimedFirearm(weapon) then return {} end
    if not (part.getPartType and part:getPartType()) then return {} end
    
    options = options or {}
    
    -- Find matching slot for this slotted part
    local matchedSlot
    for _, def in ipairs(HFO.Constants.WeaponAttachmentParts) do
        local current = weapon[def.get] and weapon[def.get](weapon)
    
        if current and current:getType() == part:getType() then
            matchedSlot = def
            break
        elseif part:getPartType() and part:getPartType():lower() == def.partType then
            local mountList = part:getMountOn()
            if mountList then
                for i = 0, mountList:size() - 1 do
                    if mountList:get(i) == weapon:getFullType() then
                        matchedSlot = def
                        break
                    end
                end
            else
                matchedSlot = def
            end
    
            if matchedSlot then break end
        end
    end
    
    if not matchedSlot then return {} end

    -- Create simulated weapons for before/after comparison
    local function createSim(original)
        local sim = InventoryItemFactory.CreateItem(original:getFullType())
        if not sim then return nil end
        sim:setCondition(original:getCondition())
        local md = sim:getModData()
        for k, v in pairs(original:getModData()) do md[k] = v end
        return sim
    end
    

    local weaponBefore = createSim(weapon)
    local weaponAfter = createSim(weapon)
    if not weaponBefore or not weaponAfter then return {} end

    -- Apply all existing parts to both simulation
    for _, def in ipairs(HFO.Constants.WeaponAttachmentParts) do
        if weapon[def.get] and def ~= matchedSlot then
            local existingPart = weapon[def.get](weapon)
            if existingPart then
                weaponBefore[def.attach](weaponBefore, existingPart)
                weaponAfter[def.attach](weaponAfter, existingPart)
            end
        end
    end

    -- Apply the part being tested
    if not options.reverse then
        weaponAfter[matchedSlot.attach](weaponAfter, part)
    end
    
    local baseStats = HFO.Utils.getRawWeaponStats(weaponBefore, getPlayer(), { skipAmmo = true })
    local modStats = HFO.Utils.getRawWeaponStats(weaponAfter, getPlayer(), { skipAmmo = true })
    
    local statChanges = {}
    
    -- Configure the raw stats in a format for ui and for tooltips to call to correctly
    for _, def in ipairs(HFO.Stats.definitions) do
        local from, to = baseStats[def.key], modStats[def.key]
        
        if from and to and type(from) == "number" and type(to) == "number" then
            local change = to - from
            if math.abs(change) > 0.0001 then
                local indicators, isPositive = HFO.Stats.getChangeIndicators(def.key, from, to)
                
                table.insert(statChanges, {
                    label = def.label,
                    formatted = def.formatFunc 
                    and HFO.Stats.formatValue(def.key, to, false) 
                    or HFO.Stats.formatValue(def.key, change, true),
                    from = from,
                    to = to,
                    rawChange = change,
                    isPositive = isPositive,
                    icon = indicators.icon,
                    color = indicators.color,
                    priority = def.priority
                })
            end
        end
    end
    
    -- For a few instances of customized weapon parts needing a few extra steps
    if options.includeExtraEffects then
        addExtraStatEffects(statChanges, part)
    end
    
    -- Sort results if needed
    if options.sort ~= false then
        table.sort(statChanges, function(a, b) return a.priority < b.priority end)
    end

    return statChanges
end


---===========================================---
--   FORMAT STAT COMPARISON AND EXTRA EFFECTS  --
---===========================================---

-- Format stat changes for various custom UI
function HFO.Utils.formatStatComparison(statChanges)
    local formatted = {}
    
    for _, entry in ipairs(statChanges) do
        local def = HFO.Stats.getDefinition(entry.label)
        local key = def and def.key or entry.label:lower():gsub(" ", "")
        
        -- For text descriptors, use the 'to' value instead of the delta
        local formattedValue
        if def and def.formatFunc then
            -- Use the resulting value for special formatters
            formattedValue = HFO.Stats.formatValue(key, entry.to, false)
        else
            -- Use the delta (change) for numeric values
            formattedValue = entry.formatted or HFO.Stats.formatValue(key, entry.rawChange, true)
        end
        
        -- the  matchy matchy way of getting the right format
        table.insert(formatted, {
            label = entry.label,
            formatted = formattedValue,
            tooltip = string.format("%s: %s → %s", entry.label,
                HFO.Stats.formatValue(key, entry.from, false),
                HFO.Stats.formatValue(key, entry.to, false)),
            color = entry.color or HFO.Constants.getNeutralColor(),
            from = entry.from,
            to = entry.to,
            rawChange = entry.rawChange,
            icon = entry.icon  
        })
    end
    
    return formatted
end

-- the "extra" checks needed for custom modifiers like lights and melee attachments
function addExtraStatEffects(statChanges, newPart)
    -- Flashlight bonus
    for k, intensity in pairs(HFO.Constants.LightSettingsByStock) do
        if newPart:getType():contains(k) then
            local indicator = HFO.Constants.StatChangeIndicators["posIncrease"] -- consistent UI signal
            local displayIntensity = intensity:gsub("^%l", string.upper) .. " Intensity"
            table.insert(statChanges, {
                label = "Flashlight",
                from = "None",
                to = intensity,
                formatted = displayIntensity,
                rawChange = 0,
                isPositive = true,
                color = indicator.color,
                icon = indicator.icon,
                priority = HFO.Constants.StatDisplayOrder["Flashlight"] or 120,
                special = "light"
            })
            break
        end
    end

    -- Bayonet melee damage
    if string.find(newPart:getType(), "Bayonet") then
        local indicator = HFO.Constants.StatChangeIndicators["posIncrease"]
        table.insert(statChanges, {
            label = "Melee Damage",
            from = 0,
            to = 0.8,
            rawChange = 0.8,
            formatted = "+0.8",
            isPositive = true,
            color = indicator.color,
            icon = indicator.icon,
            priority = HFO.Constants.StatDisplayOrder["Melee Damage"] or 130,
            special = "bayonet"
        })
    end
end


---===========================================---
--       AMMO INFO MAPS AND STAT UPDATES       --
---===========================================---

-- Currently the next thing in development is configuring ammo caliber swapping

HFO.Utils.AmmoTierIndex = {
    -- Rifle rounds
    ["Base.223Bullets"] = 1,
    ["Base.556Bullets"] = 2,
    ["Base.308Bullets"] = 3,
    ["Base.762x51Bullets"] = 4,

    -- Shotgun rounds
    ["Base.ShotgunShellsBirdShot"] = 1,
    ["Base.ShotgunShells"] = 2,
    ["Base.ShotgunShellsSlugs"] = 3,

    -- Crossbow bolts
    ["Base.WoodCrossbowBolt"] = 1,
    ["Base.CrossbowBolt"] = 2,
}

local function AmmoStats(stats)
    return {
        maxDamage = stats.maxDamage or 0,
        minDamage = stats.minDamage or 0,
        recoil = stats.recoil or 0,
        penetration = stats.penetration or 0,
        maxRange = stats.maxRange or 0,
        stoppingPower = stats.stoppingPower or 0,
        projectileCount = stats.projectileCount or 0,
        criticalChance = stats.criticalChance or 0,
        minAngle = stats.minAngle or 0,
        maxHitCount = stats.maxHitCount or 0,
        hitChance = stats.hitChance or 0
    }
end

HFO.Utils.AmmoProperties = {
    -- Base modifiers for common ammo types that will be swappable
    ["Base.223Bullets"] = AmmoStats{}, --Baseline 0 stats across the board
    ["Base.556Bullets"] = AmmoStats{
        minDamage = 0.1, maxDamage = 0.2, maxRange = 2, recoilDelay = 4, hitChance = 5,
        criticalChance = 10, minAngle = -0.005
    },
    ["Base.308Bullets"] = AmmoStats{
        minDamage = 0.2, maxDamage = 0.3, maxRange = 3, recoilDelay = 5, hitChance = 8,
        criticalChance = 15, minAngle = -0.01
    },
    ["Base.762x51Bullets"] = AmmoStats{
        minDamage = 0.3, maxDamage = 0.4, maxRange = 4, recoilDelay = 6, hitChance = 10,
        criticalChance = 20, minAngle = -0.01
    },
    ["Base.ShotgunShells"] = AmmoStats{}, -- baseline for shotgun shells so whatever the gun stats are
    ["Base.ShotgunShellsBirdShot"] = AmmoStats{
        minDamage = -0.3, maxDamage = -0.3, maxRange = -3, recoilDelay = 10, hitChance = 10,
        criticalChance = -10, minAngle = -0.02, projectileCount = 3, maxHitCount = 2
    },
    ["Base.ShotgunShellsSlugs"] = AmmoStats{
        minDamage = 0.3, maxDamage = 0.3, maxRange = 5, recoilDelay = 5, hitChance = 30,
        criticalChance = 20, minAngle = 0.04, projectileCount = 1, maxHitCount = 1
    },
    ["Base.CrossbowBolt"] = AmmoStats{}, -- baseline for crossbow bolts since this was the first made
    ["Base.WoodCrossbowBolt"] = AmmoStats{
        minDamage = -0.2, maxDamage = -0.2, maxRange = -1, recoilDelay = -3, hitChance = 5,
        criticalChance = -10, minAngle = -0.005
    }
}


function HFO.Utils.applyAmmoPropertiesToWeapon(weapon, newAmmoType)
    local md = weapon:getModData()
    local originalStats = md.OriginalStats
    local originalAmmoType = originalStats.OriginalAmmoType or weapon:getAmmoType()

    local indexMap = HFO.Utils.AmmoTierIndex
    local origIndex = indexMap[originalAmmoType] or 1
    local newIndex = indexMap[newAmmoType] or 1
    local indexRatio = newIndex / origIndex

    local newProps = HFO.Utils.AmmoProperties[newAmmoType] or {}
    local origProps = HFO.Utils.AmmoProperties[originalAmmoType] or {}

    -- Defensive fill for all expected keys
    for _, key in ipairs({
        "maxDamage", "minDamage", "recoil", "penetration", "maxRange",
        "stoppingPower", "criticalChance", "minAngle", "maxHitCount",
        "hitChance", "projectileCount"
    }) do
        newProps[key] = newProps[key] or 0
        origProps[key] = origProps[key] or 0
    end

    -- Utility: float scaling with clamping (damage, range)
    local function scaleFloat(base, delta, ratio, exp, clampMin, clampMax)
        local scaled = base * (1 + delta) * (ratio ^ (exp or 1))
        return math.min(math.max(scaled, clampMin or 0), clampMax or scaled)
    end

    -- Utility: int scaling with clamping (hit chance, stopping power)
    local function scaleClampedInt(base, delta, ratio, exp, clampMin, clampMax)
        local val = math.floor(base * (1 + delta) * (ratio ^ (exp or 1)))
        return math.min(math.max(val, clampMin or 0), clampMax or val)
    end

    weapon:setMaxDamage(scaleFloat(originalStats.maxDamage, newProps.maxDamage - origProps.maxDamage, indexRatio, 1.2, 0, 4))
    weapon:setMinDamage(scaleFloat(originalStats.minDamage, newProps.minDamage - origProps.minDamage, indexRatio, 1.2, 0, 4))
    weapon:setRecoilDelay(math.max(7, math.floor(originalStats.recoilDelay * (1 + newProps.recoil - origProps.recoil) * (1 / indexRatio) ^ 1.1)))
    weapon:setMaxRange(scaleFloat(originalStats.maxRange, newProps.maxRange - origProps.maxRange, indexRatio, 0.9))
    weapon:setStopPower(scaleClampedInt(originalStats.stoppingPower, newProps.stoppingPower - origProps.stoppingPower, indexRatio, 1.1, 0, 100))
    weapon:setCriticalChance(scaleClampedInt(originalStats.criticalChance, newProps.criticalChance - origProps.criticalChance, indexRatio, 0.8, 0, 100))
    weapon:setHitChance(scaleClampedInt(originalStats.hitChance, newProps.hitChance - origProps.hitChance, indexRatio, 0.9, 0, 100))
    weapon:setMaxHitCount(math.max(1, math.floor(originalStats.maxHitCount * (1 + newProps.maxHitCount - origProps.maxHitCount) * (indexRatio))))

    if newProps.projectileCount and newProps.projectileCount > 0 then
        weapon:setProjectileCount(math.max(1, math.floor(newProps.projectileCount)))
    else
        weapon:setProjectileCount(originalStats.projectileCount)
    end

    local angle = originalStats.minAngle * (1 + newProps.minAngle - origProps.minAngle) * (indexRatio ^ 0.8)
    weapon:setMinAngle(math.max(0.8, math.min(1.0, angle)))

    weapon:setPiercingBullets(newProps.penetration == 1)

    md.currentAmmoType = newAmmoType
end


-- Also an idea was floated about adding posion dipped arrows or drugged darts
-- This was some notes about poison but also thought about exploring DoTs on zombies
-- Drunk darts, tranquilizers, stress inducers, basically can build some interesting
-- Player vs Player mechanics that dont have to be death related but can be too



--[[ Enable poison projectiles separately from vanilla food poisoning
HFO.Config.EnablePoisonAmmo = true -- can be turned off independently

Create the Poison Check Function
function HFO.Utils.poisonAllowed()
    return HFO.Config.EnablePoisonAmmo == true and (SandboxVars.EnablePoisoning or 1) ~= 2
end


Use It in Projectile Logic (Crossbows / Dart Guns / etc.)

if HFO.Utils.poisonAllowed() and item:getPoisonPower() > 0 then
    local poison = item:getPoisonPower()
    target:getBodyDamage():setPoisonLevel(
        math.min(target:getBodyDamage():getPoisonLevel() + poison, 100)
    )
end


Use It in Crafting Recipes (Optional)
If you're letting players craft poison darts/bolts:

function setPoisonDart(items, result, player)
    if not HFO.Utils.poisonAllowed() then return end

    result:setPoisonPower(10)
    result:setPoison(true)
    result:setUseForPoison(1)
    result:setPoisonDetectionLevel(0)
end

if not HFO.Utils.poisonAllowed() then
    if isClient() == false then
        print("[HFO] Poison effect skipped due to sandbox/mod settings.")
    end
    return
end]]