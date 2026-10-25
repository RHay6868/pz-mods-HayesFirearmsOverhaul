--============================================================--
--                     HFO_ReloadUtils.lua                    --
--============================================================--
-- Purpose:
--   Implements all core reload behavior for including dynamic 
--   magazine management, speedloader logic, reload speed modifiers,
--   jam chance calculations, and manual round cycling.
--
-- Overview:
--   - Manages HFO-specific reload logic across weapon and magazine types
--   - Applies weapon attachment reload speed scaling
--   - Utility layer between ISReloading and weapon state logic
--
-- Core Features:
--   - Supports standard and extended mags, drum mags
--   - Applies reload speed modifiers with custom modData on weapon attachments.
--
-- Dependencies:
--   - HFO_Utils, HFO_Constants, HFO_SandboxUtils
--   - Used by HFO_WeaponUtils, radial menus, and timed reload actions
--
-- Notes:
--   - AMMO SWAP logic is not done at all still in development.
--============================================================--

require "HFO_Utils"
require "HFO_SandboxUtils"
require "HFO_Constants"
require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISReloadWeaponAction"
require "TimedActions/ISAmmoSwapAction"
require "TimedActions/ISMagSwapAction"
require "Reloading/ISReloadableWeapon"

HFO = HFO or {}
HFO.ReloadUtils = HFO.ReloadUtils or {}


---===========================================---
--              SPEEDLOADER LOGIC              --
---===========================================---

-- Find a valid speedloader for the given weapon
function HFO.ReloadUtils.getValidSpeedloader(inventory, weapon)
    if not inventory or not weapon then return nil end

    local weaponType = weapon:getFullType()
    local bestLoader = nil
    local bestAmmoCount = 0

    local items = inventory:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and item:getType():contains("SpeedLoader") then
            local currentAmmo = item:getCurrentAmmoCount()
            if currentAmmo > 0 then
                local md = item:getModData()
                if md and md.HFO_SpeedLoadCompatible and 
                   string.find(md.HFO_SpeedLoadCompatible, weaponType, 1, true) then
                    if currentAmmo > bestAmmoCount then
                        bestAmmoCount = currentAmmo
                        bestLoader = item
                    end
                end
            end
        end
    end

    return bestLoader
end

-- Store the original function
local originalBeginAutoReload = ISReloadWeaponAction.BeginAutomaticReload

ISReloadWeaponAction.BeginAutomaticReload = function(playerObj, gun)
    if gun:isManuallyRemoveSpentRounds() and not gun:getMagazineType() then
        local speedloader = HFO.ReloadUtils.getValidSpeedloader(playerObj:getInventory(), gun)

        if speedloader and speedloader:getCurrentAmmoCount() > 0 then
            local loaderAmmo = speedloader:getCurrentAmmoCount()
            local currentAmmo = gun:getCurrentAmmoCount()
            local maxAmmo = gun:getMaxAmmo()
            
            -- What the gun would have *after* the speedloader
            local resultAfterLoader = math.min(loaderAmmo, maxAmmo)
            
            -- Only use if it's truly an upgrade
            if resultAfterLoader > currentAmmo then
                ISTimedActionQueue.add(ISLoadFromSpeedloaderAction:new(playerObj, gun, speedloader))
                return
            end
        end
    end
    -- Fallback to standard reload
    originalBeginAutoReload(playerObj, gun)
end


---===========================================---
--            SWAP MAGAZINE FUNCTION           --
---===========================================---

--- Returns a list of valid magazine types present in inventory.
function HFO.ReloadUtils.getAvailableMagTypes(player, weapon)
    if not player or not weapon then return {} end

    local md = weapon:getModData()
    local magBase = md.HFO_MagBase
    if not magBase then return {} end

    local allTypes = { magBase }
    for _, field in ipairs({ "HFO_MagExtSm", "HFO_MagExtLg", "HFO_MagDrum" }) do
        if md[field] then
            table.insert(allTypes, md[field])
        end
    end

    local inv = player:getInventory()
    local available = {}

    for _, magType in ipairs(allTypes) do
        local isCurrent = weapon:getMagazineType() == magType
        if inv:containsTypeRecurse(magType) or isCurrent then
            table.insert(available, magType)
        end
    end

    return available
end

function HFO.ReloadUtils.SwapMagHotkey(keyNum, reverse)
    local player, weapon = HFO.Utils.getPlayerAndWeapon() 
    if not player or not weapon then return false end
    if not HFO.Utils.isAimedFirearm(weapon) or HFO.Utils.isInMeleeMode(weapon) then return end 
    
    local md = weapon:getModData()
    if not md.HFO_MagBase then return false end -- if there is no MagBase than there are no Extended options
    
    -- Get all available magazine types
    local magTypes = HFO.ReloadUtils.getAvailableMagTypes(player, weapon)
    if #magTypes <= 1 then 
        HFO.InnerVoice.say("NoMagSwapAvailable")
        return false 
    end
    
    local currentMag = weapon:getMagazineType()
    
    local indexed = HFO.Utils.getNextPrevFromList(magTypes, currentMag)
    local nextMagType = reverse and indexed.prev or indexed.next
    if not nextMagType then return false end
    
    local maps = HFO.Utils.getMagazineInfoMaps(md)
    local name = maps.nameMap[nextMagType] or nextMagType

    if weapon:isContainsClip() then
        ISTimedActionQueue.add(ISEjectMagazine:new(player, weapon))
    end
    
    ISTimedActionQueue.add(ISMagSwapAction:new(player, weapon, nextMagType))

    return true
end


---===========================================---
--     GUARDRAILS FOR WEAPONS IN MELEE MODE    --
---===========================================---

local originalRemoveUpgrade = ISInventoryPaneContextMenu.onRemoveUpgradeWeapon

ISInventoryPaneContextMenu.onRemoveUpgradeWeapon = function(weapon, part, player)
    if not weapon or not part then return end

    -- Block ALL upgrades if in Melee Mode
    if HFO.Utils.isAimedFirearm(weapon) and not weapon:isRanged() then
        HFO.InnerVoice.say("MeleeBlockUpgrade")
        return
    end

    -- Block clip removal globally
    if part:getPartType() == "Clip" then
        HFO.InnerVoice.say("BlockMagazineUpgrade")
        return
    end

    return originalRemoveUpgrade(weapon, part, player)
end


---===========================================---
--      RELOAD SPEED PATCH TO ADD UTILITY      --
---===========================================---

-- Only patch once over the vanilla ISReloadWeaponAction.setReloadSpeed block
if not HFO.ReloadUtils.ReloadSpeedPatched then

    local originalSetReloadSpeed = ISReloadWeaponAction.setReloadSpeed

    ISReloadWeaponAction.setReloadSpeed = function(character, rack)
        local reloadSpeed = 1.0
        local gun = character:getPrimaryHandItem()
        local maxSpeed = tonumber(SandboxVars.HFO.ReloadSpeedMax) or 3.0

        -- Safety clamp: max between 1.0 and 10.0
        maxSpeed = math.max(1.0, math.min(maxSpeed, 10.0))

        local reloadingLevel = character:getPerkLevel(Perks.Reloading)
        local panicLevel = character:getMoodles():getMoodleLevel(MoodleType.Panic)

        if rack then
            reloadSpeed = reloadSpeed + (reloadingLevel * 0.03)
        else
            reloadSpeed = reloadSpeed + (reloadingLevel * 0.07)
            reloadSpeed = reloadSpeed - (panicLevel * 0.05)
        end
        local afterSkillPanic = reloadSpeed

        -- Vanilla Ammo Strap Logic- DISABLED for HFO
        -- We use HFO_ReloadSpeedModifier on attachments instead
        --[[
        local strap = character:getWornItem("AmmoStrap")
        local hasFastTag = character:hasEquippedTag("ReloadFastShells") or character:hasEquippedTag("ReloadFastBullets")
        local isShotgun = gun and gun:getAmmoType() == "Base.ShotgunShells"
        local hasStrapBonus = false

        if gun and (hasFastTag or (strap and strap:getClothingItem())) then
            local strapName = strap and strap:getClothingItemName() or ""

            if isShotgun then
                hasStrapBonus = character:hasEquippedTag("ReloadFastShells") or strapName == "AmmoStrap_Shells"
            else
                hasStrapBonus = character:hasEquippedTag("ReloadFastBullets") or strapName == "AmmoStrap_Bullets"
            end
        end

        if hasStrapBonus then
            reloadSpeed = reloadSpeed * 1.15
        end]]

        -- Track attachment modifier contribution
        local attachmentModifier = 1.0
        if HFO and HFO.ReloadUtils and HFO.ReloadUtils.getReloadSpeedModifier then
            attachmentModifier = HFO.ReloadUtils.getReloadSpeedModifier(character, gun)
            reloadSpeed = reloadSpeed * attachmentModifier
        end
        local afterAttachment = reloadSpeed

        -- Track vehicle penalty
        local inVehicle = false
        local vehicle = character:getVehicle()
        if vehicle and vehicle:getDriver() == character then
            inVehicle = true
            reloadSpeed = reloadSpeed * 0.8
        end
        local afterVehicle = reloadSpeed

        -- Apply sandbox-configured max clamp 
        local beforeClamp = reloadSpeed
        reloadSpeed = math.max(0.1, math.min(reloadSpeed, maxSpeed))
        local afterClamp = reloadSpeed

        local finalValue = reloadSpeed * GameTime.getAnimSpeedFix()
        character:setVariable("ReloadSpeed", finalValue)
    end

    -- Set flag to prevent future re-patching
    HFO.ReloadUtils.ReloadSpeedPatched = true
end


---===========================================---
--        RELOAD SPEED ATTACHMENT REWORK       --
---===========================================---

-- Find weapon parts with the ReloadSpeedModifier to apply speed bonus to reload with diminishing returns
function HFO.ReloadUtils.getReloadSpeedModifier(character, weapon)
    local totalReloadMod = 1.0
    if not weapon then return totalReloadMod end

    local weaponParts = weapon:getAllWeaponParts()
    if not weaponParts then return totalReloadMod end

    for i = 0, weaponParts:size() - 1 do
        local part = weaponParts:get(i)
        if part then
            local rawValue = part:getModData() and part:getModData().HFO_ReloadSpeedModifier
            local baseModifier = nil
    
            if type(rawValue) == "number" then
                baseModifier = rawValue 
            elseif type(rawValue) == "string" then
                baseModifier = tonumber(string.match(rawValue, "[%d%.%-]+"))
            end
    
            if baseModifier then
                totalReloadMod = totalReloadMod + baseModifier 
            end
        end
    end

    local weaponModRaw = weapon:getModData() and weapon:getModData().HFO_ReloadSpeedModifier
    local weaponModFinal = tonumber(weaponModRaw)
    if weaponModFinal then
        totalReloadMod = totalReloadMod + weaponModFinal
    end

    return totalReloadMod 
end

-- context call to indicate reload animation will be faster
local originalUpgradeWeapon = ISInventoryPaneContextMenu.onUpgradeWeapon

ISInventoryPaneContextMenu.onUpgradeWeapon = function(weapon, part, player)
	if not weapon or not part then return end

	local result = originalUpgradeWeapon(weapon, part, player)

	-- If the part has a reload bonus, cue the voice line
	local md = part:getModData()
	local bonus = md and tonumber(md.HFO_ReloadSpeedModifier)
	if bonus and bonus > 0 then
		HFO.InnerVoice.say("ReloadBoost")
	end

	return result
end


---===========================================---
--           AMMO CALIBER SWAP FUNCTION        --
---===========================================---

-- Get compatible ammo types for a weapon from modData
function HFO.ReloadUtils.getCompatibleAmmoTypes(weapon)
    if not weapon then return {} end
    
    local md = weapon:getModData()
    local compatibleAmmoTypes = {}

    -- Add base ammo type (always first)
    local baseAmmoType = md.HFO_AmmoTypeBase or weapon:getAmmoType()
    table.insert(compatibleAmmoTypes, baseAmmoType)

    -- Add additional types from modData (semicolon-separated)
    if md.HFO_AmmoTypeAdditional then
        for ammoType in string.gmatch(md.HFO_AmmoTypeAdditional, "([^;]+)") do
            -- Trim whitespace
            ammoType = ammoType:match("^%s*(.-)%s*$")
            if ammoType and ammoType ~= "" then
                table.insert(compatibleAmmoTypes, ammoType)
            end
        end
    end

    local seenAmmoTypes = {}
    local uniqueAmmoTypes = {}
    for _, ammoType in ipairs(compatibleAmmoTypes) do
        if not seenAmmoTypes[ammoType] then
            table.insert(uniqueAmmoTypes, ammoType)
            seenAmmoTypes[ammoType] = true
        end
    end
    
    return uniqueAmmoTypes
end

-- Get available ammo types that player actually has in inventory
function HFO.ReloadUtils.getAvailableAmmoTypes(player, weapon)
    if not player or not weapon then return {} end
    local md = weapon:getModData()

    local compatibleAmmoTypes = HFO.ReloadUtils.getCompatibleAmmoTypes(weapon)
    if #compatibleAmmoTypes <= 1 then return compatibleAmmoTypes end

    local availableAmmoTypes = {}
    local inventory = player:getInventory()
    local currentAmmoType = md.HFO_currentAmmoType or weapon:getAmmoType()
    
    for _, ammoType in ipairs(compatibleAmmoTypes) do
        -- Include current ammo type or types we have in inventory
        if ammoType == currentAmmoType or inventory:containsTypeRecurse(ammoType) then
            table.insert(availableAmmoTypes, ammoType)
        end
    end
    
    return availableAmmoTypes
end

-- Main ammo swap hotkey function
function HFO.ReloadUtils.SwapAmmoHotkey(keyNum, reverse)
    local player, weapon = HFO.Utils.getPlayerAndWeapon()
    if not player or not weapon then return false end
    if not HFO.Utils.isAimedFirearm(weapon) or HFO.Utils.isInMeleeMode(weapon) then return end
    
    local md = weapon:getModData()

    -- Get available ammo types for this weapon
    local availableAmmoTypes = HFO.ReloadUtils.getAvailableAmmoTypes(player, weapon)
    if #availableAmmoTypes <= 1 then 
        HFO.InnerVoice.say("NoAmmoSwapAvailable")
        return false 
    end
    
    local currentAmmoType = md.HFO_currentAmmoType or weapon:getAmmoType()
    
    -- Find next ammo type
    local indexed = HFO.Utils.getNextPrevFromList(availableAmmoTypes, currentAmmoType)
    local nextAmmoType = reverse and indexed.prev or indexed.next
    
    if not nextAmmoType then return false end
 
    -- Eject magazine if weapon has one
    if weapon:isContainsClip() then
        ISTimedActionQueue.add(ISEjectMagazine:new(player, weapon))
    end
    
    -- Queue the ammo swap action
    ISTimedActionQueue.add(ISAmmoSwapAction:new(player, weapon, nextAmmoType))
    
    return true
end


---===========================================---
--  AMMO & MAG CONTINUITY AND STAT RETENTION   --
---===========================================---

-- Extract the logic into its own function
function HFO.ReloadUtils.handleMagazineRetention(weapon)
    if not weapon or not instanceof(weapon, "HandWeapon") or not weapon:isAimedFirearm() then
        return
    end

    local clipLoaded = weapon:isContainsClip()
    local currentMagType = weapon:getModData().HFO_currentMagType

    -- Early exit if no magazine type stored
    if not currentMagType then return end

    if currentMagType ~= nil then
        weapon:setMagazineType(currentMagType)
        local tempItem = InventoryItemFactory.CreateItem(currentMagType)
        if tempItem then
            weapon:setMaxAmmo(tempItem:getMaxAmmo())
        end
    end

    if clipLoaded then
        local magBase = weapon:getModData().HFO_MagBase
        local magExtSm = weapon:getModData().HFO_MagExtSm
        local magExtLg = weapon:getModData().HFO_MagExtLg
        local magDrum = weapon:getModData().HFO_MagDrum
        local magPart

        if not weapon:getClip() then
            if currentMagType and currentMagType ~= "" then
                if currentMagType == magExtSm then
                    magPart = InventoryItemFactory.CreateItem(magExtSm)
                elseif currentMagType == magExtLg then
                    magPart = InventoryItemFactory.CreateItem(magExtLg)
                elseif currentMagType == magDrum then
                    magPart = InventoryItemFactory.CreateItem(magDrum)
                end
            end
        end

        if magPart and not weapon:getClip() then
            weapon:attachWeaponPart(magPart)
        end

    elseif weapon:getClip() then
        weapon:detachWeaponPart(weapon:getWeaponPart("Clip"))
    end
end

function HFO.ReloadUtils.handleAmmoRetention(weapon)
    if not weapon or not instanceof(weapon, "HandWeapon") or not weapon:isAimedFirearm() then
        return
    end

    local md = weapon:getModData()
    local currentAmmoType = md.HFO_currentAmmoType

    -- Early exit if no ammo type stored or already correct
    if not currentAmmoType or currentAmmoType == weapon:getAmmoType() then return end
    
    if currentAmmoType and currentAmmoType ~= weapon:getAmmoType() then
        -- Restore core ammo properties
        weapon:setAmmoType(currentAmmoType)
        
        -- Restore projectile count and max hits from baseline
        if md.HFO_PreSwapStats then
            local baseProjectiles = md.HFO_PreSwapStats.projectileCount
            local baseMaxHits = md.HFO_PreSwapStats.maxHitCount
            
            if currentAmmoType == "Base.ShotgunShellsBirdshot" then
                weapon:setProjectileCount(baseProjectiles + 3)
                weapon:setMaxHitCount(baseMaxHits + 2)
            elseif currentAmmoType == "Base.ShotgunShellsSlug" then
                weapon:setProjectileCount(1)
                weapon:setMaxHitCount(1)
            else
                weapon:setProjectileCount(baseProjectiles)
                weapon:setMaxHitCount(baseMaxHits)
            end
        end
        
        -- Only apply stat modifiers on the ranged firearm, not on the _Melee item
        if not HFO.Utils.isInMeleeMode(weapon) then
            if HFO.Utils.applyAmmoPropertiesToWeapon then
                HFO.Utils.applyAmmoPropertiesToWeapon(weapon, currentAmmoType)
            end
        end
    end

    -- Mark that we've applied stats for this ammo type
    md.HFO_AmmoStatsApplied = currentAmmoType
end

local originalCheckForModelChange = BWTweaks and BWTweaks.checkForModelChange

function BWTweaks:checkForModelChange(weapon)
    if not HFO.Utils.isAimedFirearm(weapon) then
        if originalCheckForModelChange then
            return originalCheckForModelChange(self, weapon)
        end
        return
    end

    local md = weapon:getModData()

    -- Remove slings from ALL pistols
    if not md.HFO_SlingCleanupDone then
        HFO.Utils.removeHandgunSlings(weapon)
    end
    
    -- Remove ammo straps from only Jennings and Derringer
    if not md.HFO_AmmoStrapCleanupDone then
        HFO.Utils.removeAmmoStrapsFromLightHandguns(weapon)
    end

    HFO.ReloadUtils.handleMagazineRetention(weapon)
    HFO.ReloadUtils.handleAmmoRetention(weapon)

    if not md.HFO_Migrated then
        HFO.Utils.migrateModData(weapon)
    end
    if md.HFO_DataVersion ~= HFO.Utils.DATA_VERSION then
        HFO.Utils.initializeNewModData(weapon)
    end
    if not md.HFO_PreSwapStats then
        HFO.Utils.storePreSwapStats(weapon)
    end

    if originalCheckForModelChange then
        return originalCheckForModelChange(self, weapon)
    end
end

Events.OnGameStart.Add(function()
    local player, weapon = HFO.Utils.getPlayerAndWeapon()
    if not HFO.Utils.isAimedFirearm(weapon) then return end
    
    if weapon and instanceof(weapon, "HandWeapon") then
        BWTweaks:checkForModelChange(weapon)
    end
end)


---===========================================---
--           CUSTOM JAM CHANCE LOGIC           --
---===========================================---

-- Create a dedicated function to calculate jam chance based on condition percentage
function HFO.ReloadUtils.calculateJamChance(player, weapon)
    -- Early exits with zero chance
    if not weapon or not weapon:isRanged() then return 0 end

    -- Get jam setting directly from sandbox vars 
    local jamSetting = tonumber(SandboxVars.HFO.JamChance) or 4
    if jamSetting <= 1 then return 0 end -- early exit for no jam

    if jamSetting < 2 or jamSetting > 7 then jamSetting = 4 end -- clamp for weird edge case of sandbox ini going outside values
    
    local condition = weapon:getCondition()
    local maxCondition = weapon:getConditionMax()

    if condition >= maxCondition then return 0 end
    if weapon:getJamGunChance() <= 0 or weapon:getCurrentAmmoCount() <= 0 then return 0 end
    
    -- Get settings based on difficulty
    local conditionPercent = (condition / maxCondition) * 100
    local settings = HFO.ReloadUtils.getJamSettingsForDifficulty(jamSetting)
    local scalingFactor = settings.scalingFactor
    local thresholdPercent = settings.thresholdPercent
    local extraBaseJam = settings.extraBaseJamChance or 0
    
    -- Calculate jam chance - only apply penalty if below threshold
    local conditionPenalty = 0
    if conditionPercent < thresholdPercent then
        conditionPenalty = (thresholdPercent - conditionPercent) * scalingFactor
    end
    
    local baseChance = weapon:getJamGunChance() + extraBaseJam
    local totalJamChance = baseChance + conditionPenalty
    
    -- Apply aiming skill bonus
    local aiming = player and player:getPerkLevel(Perks.Aiming) or 0
    local aimingBonus = aiming * 0.1
    totalJamChance = totalJamChance - aimingBonus
    
    -- Apply max jam chance cap based on difficulty
    local maxJam = (jamSetting >= 6) and 8 or 5
    totalJamChance = math.max(0, math.min(totalJamChance, maxJam))
    
    return totalJamChance
end

-- Function to check if a weapon should jam based on calculated chance
function HFO.ReloadUtils.shouldWeaponJam(player, weapon)
    local jamChance = HFO.ReloadUtils.calculateJamChance(player, weapon)
    if jamChance <= 0 then return false end
    
    local jamThreshold = jamChance * 10 -- Convert to per-1000 value
    local roll = ZombRand(1000)
    return roll < jamThreshold
end

-- Hook into OnWeaponSwingHitPoint to intercept BEFORE vanilla onShoot
function HFO.ReloadUtils.setupJamSystem()
    if HFO.ReloadUtils.HFO_jamPatched then return end
    
    -- Remove the vanilla onShoot from the event
    Events.OnWeaponSwingHitPoint.Remove(ISReloadWeaponAction.onShoot)
    
    -- Add our interceptor that runs first
    Events.OnWeaponSwingHitPoint.Add(function(player, weapon)
        if not weapon or not weapon:isRanged() then return end
        if getDebug() and getDebugOptions():getBoolean("Cheat.Player.UnlimitedAmmo") then
            return
        end
        
        -- === VANILLA LOGIC (preserved exactly) ===
        if weapon:haveChamber() then
            weapon:setRoundChambered(false);
        end
        if weapon:isRackAfterShoot() then
            if weapon:haveChamber() then
                weapon:setSpentRoundChambered(true);
            end
        else
            if not weapon:isManuallyRemoveSpentRounds() then
                if weapon:getShellFallSound() then
                    player:getEmitter():playSound(weapon:getShellFallSound())
                end
            end
            if weapon:getCurrentAmmoCount() >= weapon:getAmmoPerShoot() then
                if weapon:haveChamber() then
                    weapon:setRoundChambered(true);
                end
                weapon:setCurrentAmmoCount(weapon:getCurrentAmmoCount() - weapon:getAmmoPerShoot())
            end
        end
        if weapon:isManuallyRemoveSpentRounds() then
            weapon:setSpentRoundCount(weapon:getSpentRoundCount() + weapon:getAmmoPerShoot())
        end
        
        -- Apply our custom jam logic
        if weapon:getCondition() < weapon:getConditionMax() and 
           weapon:getJamGunChance() > 0 and 
           weapon:getCurrentAmmoCount() > 0 then
            
            if HFO.ReloadUtils.shouldWeaponJam(player, weapon) then
                weapon:setJammed(true)
                
                -- Trigger inner voice
                if HFO.InnerVoice and HFO.InnerVoice.say then
                    HFO.InnerVoice.say("WeaponJammed")
                end
            end
        end
    end)
    
    HFO.ReloadUtils.HFO_jamPatched = true
    HFO.Utils.debugLog("[HFO] Jam system successfully installed")
end

---===========================================---
--     JAM CHANCE SCALING SANDBOX SETTINGS     --
---===========================================---

-- Difficulty presets
function HFO.ReloadUtils.getJamSettingsForDifficulty(level)
    local presets = {
        [1] = { scalingFactor = 0.000, thresholdPercent = 100 }, -- No jams
        [2] = { scalingFactor = 0.020, thresholdPercent = 80 },  -- Very Easy
        [3] = { scalingFactor = 0.040, thresholdPercent = 84 },  -- Easy
        [4] = { scalingFactor = 0.060, thresholdPercent = 88 },  -- Normal
        [5] = { scalingFactor = 0.080, thresholdPercent = 92 },  -- Hard
        [6] = { scalingFactor = 0.100, thresholdPercent = 94 },  -- Very Hard
        [7] = { scalingFactor = 0.150, thresholdPercent = 96, extraBaseJamChance = 1 }, -- Extreme
    }
    return presets[level] or presets[4]
end

-- Apply patch at game start
Events.OnGameStart.Add(HFO.ReloadUtils.setupJamSystem)