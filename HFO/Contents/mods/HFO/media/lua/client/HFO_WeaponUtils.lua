--============================================================--
--                     HFO_WeaponUtils.lua                    --
--============================================================--
-- Purpose:
--   Contains advanced weapon behavior logic for weapon light toggling,
--   firemode control, suppressor effects, burst fire management,
--   melee-mode swapping, and context-based gun plating mechanics.
--
-- Overview:
--   - Handles hotkey and event-based weapon utilities.
--   - Supports stat and attachment transfer during weapon conversion.
--   - Applies suppressor modifiers with condition-based break logic.
--   - Tracks burst firing and dynamically adjusts recoil delay.
--   - Provides context menu-driven plating options with timed actions.
--
-- Core Features:
--   - Weapon light toggle and aiming-based strength adjustments.
--   - Suppressor wear and randomized break mechanics.
--   - Burst fire animation + recoil syncing (with cleanup).
--   - Firemode cycling with support for recoil delay mapping.
--   - Melee/ranged weapon state swaps retaining key data.
--   - Gun plating system using screwdriver, context menu, and suffix updates.
--
-- Dependencies:
--   - HFO_Utils, HFO_Constants, HFO_SandboxUtils, HFO_InnerVoice
--   - Vanilla Project Zomboid Events and Timed Actions
--
-- Notes:
--   - Designed to remain modular, multiplayer-safe, and easily extended
--============================================================--

require "HFO_Utils"
require "HFO_SandboxUtils"
require "HFO_Constants"
require "BGunTweaker"
require "BGunModelChange"
require "Reloading/ISReloadableWeapon"
require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISReloadWeaponAction"
require "TimedActions/ISAttachGunPlating"
require "TimedActions/ISRemoveGunPlating"

HFO = HFO or {}
HFO.WeaponUtils = HFO.WeaponUtils or {}


---===========================================---
--            WEAPON LIGHT FUNCTIONS           --
---===========================================---

function HFO.WeaponUtils.getLightSettings(stockType)  -- attach light level to item type for stock attachments
    local level = HFO.Constants.LightSettingsByStock[stockType or ""] or "none"
    return HFO.Constants.LightLevels[level] or HFO.Constants.LightLevels.none
end

-- Function to handle toggling the light on/off with hotkey
function HFO.WeaponUtils.WeaponLightHotkey()
	local player, weapon = HFO.Utils.getPlayerAndWeapon()
	if not player or not weapon or not HFO.Utils.isAimedFirearm(weapon) then return end

	local stock = weapon:getStock()
	if not stock then return end

	local stockType = stock:getType()
	if HFO.Constants.LightSettingsByStock[stockType] then
        local lightState = HFO.Utils.toggleModDataBool(weapon, "HFO_LightOn")
		HFO.Utils.debugLog("Toggled weapon light: " .. tostring(lightState))
    end
end

-- Function for continuous updates to handle dynamic light behavior
function HFO.WeaponUtils.WeaponLight()
    local player, weapon = HFO.Utils.getPlayerAndWeapon()
    if not player or not weapon then return end
	if not HFO.Utils.isAimedFirearm(weapon) then
		weapon:setTorchCone(false)
		weapon:setLightDistance(0)
		weapon:setLightStrength(0)
		return
	end

    local stock = weapon:getStock()
    if not stock then return end

    local stockType = stock:getType()
    if HFO.Constants.LightSettingsByStock[stockType] and weapon:getModData().HFO_LightOn == true then
        local settings = HFO.WeaponUtils.getLightSettings(stockType)

        if player:isAiming() then
            weapon:setTorchCone(true)
            weapon:setLightDistance(settings.distance)
            weapon:setLightStrength(settings.strength)
        else
            weapon:setTorchCone(false)
            weapon:setLightDistance(2.5)
            weapon:setLightStrength(0.5)
        end
    else
        weapon:setTorchCone(false)
        weapon:setLightDistance(0)
        weapon:setLightStrength(0)
    end
end

Events.OnPlayerUpdate.Add(HFO.WeaponUtils.WeaponLight)


---===========================================---
--           SELECT FIREMODE FUNCTION          --
---===========================================---

HFO.WeaponUtils.RecoilDelays = HFO.WeaponUtils.RecoilDelays or {} -- Table to store default recoil delays for weapons

function HFO.WeaponUtils.getNextPrevFireModes(weapon)
	if not weapon or not weapon:getFireModePossibilities() then return nil end

	local firemodes = weapon:getFireModePossibilities()
	if firemodes:size() <= 1 then return nil end

	local indexFiremodes = {}
	for i = 0, firemodes:size() - 1 do
		table.insert(indexFiremodes, firemodes:get(i))
	end

	return HFO.Utils.getNextPrevFromList(indexFiremodes, weapon:getFireMode())
end

function HFO.WeaponUtils.cycleFiremode(reverse)
	local player, weapon = HFO.Utils.getPlayerAndWeapon()
	HFO.WeaponUtils.clearBurstTracker(player, weapon)
	if not HFO.Utils.isAimedFirearm(weapon) then return end -- Exit if not a firearm
	if HFO.Utils.isInMeleeMode(weapon) then
		HFO.Utils.debugLog("Blocked firemode swap: Weapon is in melee mode.")
		return
	end

	local firemodeInfo = HFO.WeaponUtils.getNextPrevFireModes(weapon)
	if not firemodeInfo then return end

	local nextFireMode = reverse and firemodeInfo.prev or firemodeInfo.next
	weapon:setFireMode(nextFireMode)
	player:playSound("LightSwitch")
	HFO.Utils.debugLog("Switched to fire mode: " .. tostring(nextFireMode))

	local mappedCategory = HFO.InnerVoice.map[nextFireMode]
	if mappedCategory then
		HFO.InnerVoice.say(mappedCategory)
	end

	local weaponID = weapon:getType() -- Store the weapon's ID or a unique reference for recoil storage
	if not HFO.WeaponUtils.RecoilDelays[weaponID] then
		HFO.WeaponUtils.RecoilDelays[weaponID] = weapon:getRecoilDelay()
		HFO.Utils.debugLog("Stored default recoil delay: " .. weapon:getRecoilDelay())
	end

	local defaultDelay = HFO.WeaponUtils.RecoilDelays[weaponID]
	local modeAdjust   = HFO.Constants.FiremodeAdjustments[nextFireMode]

	if modeAdjust then -- Apply adjustment for specific fire modes based on table outside function
        local rawDelay = defaultDelay + modeAdjust.adjust
        local clampedDelay = math.max(modeAdjust.min, math.max(1, rawDelay))
		if weapon:getRecoilDelay() ~= clampedDelay  then
			weapon:setRecoilDelay(clampedDelay )
		end
		HFO.Utils.debugLog("Set recoil delay for " .. nextFireMode .. ": " .. clampedDelay )
	else
		-- No special config: restore default recoil delay
		weapon:setRecoilDelay(defaultDelay)
		HFO.Utils.debugLog("Restored default recoil delay for fire mode: " .. nextFireMode)

		local hasAdjustedMode = false
		for _, mode in ipairs(firemodeInfo.list) do
			if HFO.Constants.FiremodeAdjustments[mode] then
				hasAdjustedMode = true
				break
			end
		end

		if not hasAdjustedMode then
			HFO.WeaponUtils.RecoilDelays[weaponID] = nil
			HFO.Utils.debugLog("Cleaned up stored recoil delay")
		end
	end
end


---===========================================---
--           BURST FIREMODE FUNCTION           --
---===========================================---

function HFO.WeaponUtils.getBurstInfo(weapon)
    if not weapon or type(weapon.getFireMode) ~= "function" then 
        return false, 0, 20, {} 
    end

    local mode = weapon:getFireMode()
    if not mode then return false, 0, 20, {} end

    local md = weapon:getModData() -- always a table in PZ

    local burstModes       = HFO.Constants.BurstModes       or {}
    local burstDelays      = HFO.Constants.BurstDelays      or {}
    local burstSpeedStages = HFO.Constants.BurstSpeedStages or {}

    local isBurst     = burstModes[mode] ~= nil or md.HFO_burstSize ~= nil
    local burstCount  = md.HFO_burstSize   or burstModes[mode]      or 0
    local burstDelay  = md.HFO_burstDelay  or burstDelays[mode]     or 20
    local burstSpeeds = md.HFO_burstSpeeds or burstSpeedStages[mode] or {}

    return isBurst, burstCount, burstDelay, burstSpeeds
end

function HFO.WeaponUtils.onBurstWeaponSwing()
    local player, weapon = HFO.Utils.getPlayerAndWeapon()
    if not player or not weapon or not player:isAiming() then return end
    if not HFO.Utils.isAimedFirearm(weapon) then return end
    if HFO.Utils.isInMeleeMode(weapon) then return end

    -- Early ammo exit
    local currentAmmo = weapon:getCurrentAmmoCount()
    if not currentAmmo or currentAmmo <= 0 then return end

    local isBurst, burstSize, burstDelay, burstSpeeds = HFO.WeaponUtils.getBurstInfo(weapon)
    if not isBurst or burstSize <= 0 then return end

    local md = weapon:getModData()
    
    if not md.HFO_burstTracker then
        md.HFO_burstTracker = {
            startingAmmo = currentAmmo,
            shotsInBurst = 1,
            burstSize    = burstSize,
            burstDelay   = burstDelay,
            burstSpeeds  = burstSpeeds,
        }

        local rawSpeed = burstSpeeds[1] or burstSpeeds[burstSize] or 5.0
        local scaledSpeed = rawSpeed * (GameTime.getAnimSpeedFix() or 1.0)
        player:setVariable("autoShootSpeed", scaledSpeed)

        HFO.Utils.debugLog("Burst started: shot 1/" .. burstSize .. " | Speed: " .. rawSpeed .. " (Scaled: " .. scaledSpeed .. ")")
        weapon:setRecoilDelay(1)
        return
    end

	local tracker  		  = md.HFO_burstTracker -- Already mid-burst, track + fire next shot
    tracker.shotsInBurst  = tracker.shotsInBurst + 1 -- Increment shots in burst counter
    local shotNum         = tracker.shotsInBurst

    local rawSpeed = tracker.burstSpeeds[shotNum] or tracker.burstSpeeds[tracker.burstSize] or 5.0
    local scaledSpeed = rawSpeed * (GameTime.getAnimSpeedFix() or 1.0)
    player:setVariable("autoShootSpeed", scaledSpeed)

    currentAmmo = weapon:getCurrentAmmoCount() or 0
    if shotNum >= tracker.burstSize or currentAmmo <= 1 then
        player:setRecoilDelay(tracker.burstDelay)
        HFO.Utils.debugLog("Burst complete: shot " .. shotNum .. "/" .. tracker.burstSize .. " | Delay: " .. tracker.burstDelay)
        md.HFO_burstTracker = nil
    else
        weapon:setRecoilDelay(1)
        HFO.Utils.debugLog("Burst: shot " .. shotNum .. "/" .. tracker.burstSize .. " | Speed: " .. rawSpeed .. " (Scaled: " .. scaledSpeed .. ")")
    end
end

function HFO.WeaponUtils.onBurstAttackFinished()
    local player, weapon = HFO.Utils.getPlayerAndWeapon()
    if not player or not weapon then return end
    if not HFO.Utils.isAimedFirearm(weapon) then return end
    if HFO.Utils.isInMeleeMode(weapon) then return end

    local md = weapon:getModData()
    local tracker = md.HFO_burstTracker
    if not tracker then return end

    local isBurst, _, burstDelay = HFO.WeaponUtils.getBurstInfo(weapon)
    if not isBurst then return end

    local currentAmmo = weapon:getCurrentAmmoCount() or 0
    if currentAmmo <= 0 or tracker.shotsInBurst >= tracker.burstSize then
        -- Prefer tracker’s delay, fall back to the info we already retrieved.
        local finalDelay = math.max(1, tracker.burstDelay or burstDelay or 20)
        HFO.Utils.debugLog("Burst cleanup (attack finished): Delay " .. tostring(finalDelay))
        md.HFO_burstTracker = nil
    end
end

-- Simple function to reset burst tracking
function HFO.WeaponUtils.clearBurstTracker(player, weapon)
    if not player or not weapon then
        player, weapon = HFO.Utils.getPlayerAndWeapon()
    end

    if player and weapon then
        local md = weapon:getModData()
        if md and md.HFO_burstTracker then
            md.HFO_burstTracker = nil
            HFO.Utils.debugLog("Burst tracking reset")
        end
    end
end

Events.OnPressReloadButton.Add(function()
    local player, weapon = HFO.Utils.getPlayerAndWeapon()
    HFO.WeaponUtils.clearBurstTracker(player, weapon)
end)

Events.OnEquipPrimary.Add(function(player, weapon)
    HFO.WeaponUtils.clearBurstTracker(player, weapon)
end)

Events.OnWeaponSwing.Add(HFO.WeaponUtils.onBurstWeaponSwing)
Events.OnPlayerAttackFinished.Add(HFO.WeaponUtils.onBurstAttackFinished)


---===========================================---
--             MELEE MODE FUNCTION             --
---===========================================---

function HFO.WeaponUtils.MeleeModeHotkey()
	local player, weapon = HFO.Utils.getPlayerAndWeapon()
	if not HFO.Utils.isAimedFirearm(weapon) then return end

    -- Block outgoing swap (firearm -> melee) if disabled, but always allow return swap
    local sv = HFO.SandboxUtils.get()
    if not sv.MeleeModeEnabled and weapon:isRanged() then
        HFO.InnerVoice.say("MeleeModeDisabled")
        return
    end

	HFO.Utils.debugLog("Weapon: " .. tostring(weapon:getFullType()))
	HFO.Utils.debugLog("MeleeSwap: " .. tostring(weapon:getModData().HFO_MeleeSwap))

	local meleeSwap = weapon:getModData().HFO_MeleeSwap
	if not meleeSwap then return end

	local result = InventoryItemFactory.CreateItem(meleeSwap)
	if not result then return end

	local isMelee = not result:isRanged()

	HFO.Utils.applySuffixToWeaponName(result)
	HFO.Utils.setWeaponParts(weapon, result)
	HFO.Utils.applyWeaponStats(weapon, result, isMelee)
    local wasChambered = HFO.Utils.handleWeaponChamber(weapon, result, isMelee)
    HFO.Utils.handleWeaponJam(weapon, result, true)
    
	HFO.Utils.finalizeWeaponSwap(player, weapon, result)

	-- Handle suppressor sound changes after weapon swap
	HFO.WeaponUtils.handleSuppressor()

	if isMelee then
		HFO.InnerVoice.say("SwappedToMelee")
	else
		HFO.InnerVoice.say("SwappedToRanged")
	end
end


---===========================================---
--             SUPPRESSOR FUNCTION             --
---===========================================---


function HFO.WeaponUtils.handleSuppressor()
	local player, weapon = HFO.Utils.getPlayerAndWeapon()
	if not HFO.Utils.isAimedFirearm(weapon) then return end

    if not weapon:isRanged() then return end

	local scriptItem = weapon:getScriptItem()
	local soundVolume = scriptItem:getSoundVolume()
	local soundRadius = scriptItem:getSoundRadius()
	local swingSound = scriptItem:getSwingSound()

	local canon = weapon:getCanon()
	local suppressorApplied = false

	if canon and canon:hasTag("Suppressor") then
		if canon:getCondition() > 0 then
			local suppressorType = canon:getType()
			local volumeReduction, radiusReduction, newSwingSound
			
			-- Direct sandbox variable calls based on suppressor type
			if string.find(suppressorType, "SuppressorPistol") then
				volumeReduction = SandboxVars.HFO.PistolSuppressionLevels or 30
				radiusReduction = SandboxVars.HFO.PistolSuppressionLevels or 30
				newSwingSound = "SuppressorPistol"
			elseif string.find(suppressorType, "SuppressorRifle") then
				volumeReduction = SandboxVars.HFO.RifleSuppressionLevels or 40
				radiusReduction = SandboxVars.HFO.RifleSuppressionLevels or 40
				newSwingSound = "SuppressorRifle"
			elseif string.find(suppressorType, "SuppressorSniper") then
				volumeReduction = SandboxVars.HFO.SniperSuppressionLevels or 50
				radiusReduction = SandboxVars.HFO.SniperSuppressionLevels or 50
				newSwingSound = "SuppressorSniper"
			end
			
			if volumeReduction then
				soundVolume = math.floor(soundVolume * (1 - volumeReduction / 100))
				soundRadius = math.floor(soundRadius * (1 - radiusReduction / 100))
				swingSound = newSwingSound
				suppressorApplied = true
			end
		else
            HFO.Utils.detachBrokenPart(player, weapon, canon, swingSound)
		end
	end

	weapon:setSoundVolume(soundVolume)
	weapon:setSoundRadius(soundRadius)
	weapon:setSwingSound(swingSound)
end

Events.OnEquipPrimary.Add(function(player, weapon)
    if not weapon or not HFO.Utils.isAimedFirearm(weapon) then return end
    local sv = HFO.SandboxUtils.get()
    if not sv.MeleeModeEnabled and HFO.Utils.isInMeleeMode(weapon) then
        -- Defer by one update tick so equip animation settles first
        local function doSwap()
            Events.OnPlayerUpdate.Remove(doSwap)
            HFO.WeaponUtils.MeleeModeHotkey()
        end
        Events.OnPlayerUpdate.Add(doSwap)
    end
end)

Events.OnGameStart.Add(function()
    local player, weapon = HFO.Utils.getPlayerAndWeapon()
    if not weapon or not HFO.Utils.isAimedFirearm(weapon) then return end
    local sv = HFO.SandboxUtils.get()
    if not sv.MeleeModeEnabled and HFO.Utils.isInMeleeMode(weapon) then
        local function doSwap()
            Events.OnPlayerUpdate.Remove(doSwap)
            HFO.WeaponUtils.MeleeModeHotkey()
        end
        Events.OnPlayerUpdate.Add(doSwap)
    end
end)

Events.OnEquipPrimary.Add(HFO.WeaponUtils.handleSuppressor)

Events.OnGameStart.Add(function()
	HFO.WeaponUtils.handleSuppressor()
end)


---===========================================---
--         SUPPRESSOR BREAKAGE FUNCTION        --
---===========================================---

function HFO.WeaponUtils.checkForSuppressorBreak()
	if (SandboxVars.HFO.SuppressorBreak or 20) >= 20 then return end

	local player, weapon = HFO.Utils.getPlayerAndWeapon()
	if not HFO.Utils.isAimedFirearm(weapon) then return end

	local canon = weapon:getCanon()
	if not (canon and canon:hasTag("Suppressor")) then return end

	local breakChance = 400 * SandboxVars.HFO.SuppressorBreak
	local maxCondition = canon:getConditionMax()
	local currentCondition = canon:getCondition()
	local rollChance = 10 * ((maxCondition - currentCondition) + 1)

	if ZombRand(breakChance) <= rollChance then
		canon:setCondition(currentCondition - 1)
		HFO.InnerVoice.say("SuppressorWearing")

		-- Adjust volume/radius to reflect wear
        local suppressBoost = SandboxVars.HFO.SuppressorLevels or 0
        weapon:setSoundVolume(math.floor(weapon:getSoundVolume() * (1 + suppressBoost * 0.01)))
        weapon:setSoundRadius(math.floor(weapon:getSoundRadius() * (1 + suppressBoost * 0.01)))

		if canon:getCondition() <= 0 then
			local scriptItem = weapon:getScriptItem()
			HFO.Utils.detachBrokenPart(player, weapon, canon, scriptItem:getSwingSound())
			player:playSound("PZ_MetalSnap")
			HFO.InnerVoice.say("SuppressorBroken")
		
			player:setPrimaryHandItem(weapon)
			if weapon:isRequiresEquippedBothHands() or weapon:isTwoHandWeapon() then
				player:setSecondaryHandItem(weapon)
			else
				player:setSecondaryHandItem(nil)
			end
		else
			HFO.InnerVoice.say("SuppressorWearing")
		end
	end

	BWTweaks:checkForModelChange(weapon)
end

Events.OnPlayerAttackFinished.Add(function()
	HFO.WeaponUtils.checkForSuppressorBreak()
end)

---===========================================---
--         WEAPON PLATING SWAP FUNCTION        --
---===========================================---

HFO.WeaponUtils.gunPlatingContextMenu = {}

-- Use the same predicate function as in your timed actions
local function predicateNotBroken(item)
    -- Safer version with nil check
    if not item then return false end
    return not item:isBroken()
end

-- Add context menu options for gun plating
HFO.WeaponUtils.gunPlatingContextMenu.doWeaponMenu = function(player, context, weapon)
    local playerObj = getSpecificPlayer(player)
    local inventory = playerObj:getInventory()
    local md = weapon:getModData()
    
    -- Check if the weapon supports gun plating
    if not md.HFO_GunPlatingOptions then return end
    
    -- Get the current attached gun plating (if any)
    local currentGunPlating = md.HFO_GunPlating
    
    -- Check for screwdriver - using the SAME method as the timed action
    local hasScrewdriver = inventory:containsTagEval("Screwdriver", predicateNotBroken)
    
    -- If we have a plating attached, offer to remove it
    if currentGunPlating then
        local removeOption = context:addOption(getText("ContextMenu_Remove_Weapon_GunPlating"), weapon, HFO.WeaponUtils.gunPlatingContextMenu.onRemoveGunPlating, playerObj)
        
        -- Check if we have a screwdriver
        if not hasScrewdriver then
            removeOption.notAvailable = true
            removeOption.toolTip = ISToolTip:new()
            removeOption.toolTip:setVisible(true)
            removeOption.toolTip:setName(getText("ContextMenu_Remove_Weapon_GunPlating"))
            removeOption.toolTip:setTexture("Item_Screwdriver")
        end
    else
        -- If no gun plating is attached, offer to attach available plating options
        local validGunPlatingTypes = {}
        for gunPlatingType in string.gmatch(md.HFO_GunPlatingOptions, "([^;]+)") do
            validGunPlatingTypes[gunPlatingType:trim()] = true
        end
        
        -- Find all gun plating items in the inventory
        local gunPlatingItems = ArrayList.new()
        local items = inventory:getItems()
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if item:hasTag("GunPlating") then
                gunPlatingItems:add(item)
            end
        end

        if gunPlatingItems and gunPlatingItems:size() > 0 then
            -- Check if we have at least one valid plating item before creating the menu
            local validGunPlatingItems = {}
            local seenTypes = {}

            for i = 0, gunPlatingItems:size() - 1 do
                local gunPlatingItem = gunPlatingItems:get(i)
                local itemType = gunPlatingItem:getType()
                if validGunPlatingTypes[itemType] and not seenTypes[itemType] then
                    table.insert(validGunPlatingItems, gunPlatingItem)
                    seenTypes[itemType] = true
                end
            end

            if #validGunPlatingItems > 0 then
                -- Create submenu
                local gunPlatingMenu = context:addOption(getText("ContextMenu_Apply_Weapon_GunPlating"), nil, nil)
                local gunPlatingSubMenu = ISContextMenu:getNew(context)
                context:addSubMenu(gunPlatingMenu, gunPlatingSubMenu)

                for _, gunPlatingItem in ipairs(validGunPlatingItems) do
                    local option = gunPlatingSubMenu:addOption(gunPlatingItem:getDisplayName(), weapon, HFO.WeaponUtils.gunPlatingContextMenu.onAttachGunPlating, playerObj, gunPlatingItem)

                    if not hasScrewdriver then
                        option.notAvailable = true
                        option.toolTip = ISToolTip:new()
                        option.toolTip:setVisible(true)
                        option.toolTip:setName(gunPlatingItem:getDisplayName())
                        option.toolTip:setTexture("Item_Screwdriver")
                    end
                end
            end
        end
    end
end

-- Function to handle attaching gun plating
HFO.WeaponUtils.gunPlatingContextMenu.onAttachGunPlating = function(weapon, player, gunPlatingItem)
    -- Queue the timed action to attach the gun plating
    ISTimedActionQueue.add(ISAttachGunPlating:new(player, weapon, gunPlatingItem, 100))
end

-- Function to handle removing gun plating
HFO.WeaponUtils.gunPlatingContextMenu.onRemoveGunPlating = function(weapon, player)
    -- Queue the timed action to remove the gun plating
    ISTimedActionQueue.add(ISRemoveGunPlating:new(player, weapon, 100))
end

-- Hook into the ISInventoryPaneContextMenu
Events.OnFillInventoryObjectContextMenu.Add(function(playerID, context, items)
    -- Check if we're dealing with a single item
    if items and #items == 1 then
        local item = nil
    
        if type(items[1]) == "table" and items[1].items then
            item = items[1].items[1]
        else
            item = items[1]
        end
    
        if item and item:IsWeapon() then
            local md = item:getModData()
            if md and md.HFO_GunPlatingOptions then
                HFO.WeaponUtils.gunPlatingContextMenu.doWeaponMenu(playerID, context, item)
            end
        end
    end
end)


Events.OnFillInventoryObjectContextMenu.Add(function(playerID, context, items)
    if items and #items == 1 then
        local item = nil
    
        if type(items[1]) == "table" and items[1].items then
            item = items[1].items[1]
        else
            item = items[1]
        end
    
        if item and HFO.Utils.isAimedFirearm(item) then
            local playerObj = getSpecificPlayer(playerID)
            if not playerObj then return end
            
            local inventory = playerObj:getInventory()
            local hasKit = inventory:getItemCount("FirearmCleaningKit") > 0
            local hasLubeWithUses = inventory:getFirstTypeEval("FirearmLubricant", 
                function(item) return item:getUsedDelta() >= 0.1 end) ~= nil
            local hasAnyLube = inventory:getItemCount("FirearmLubricant") > 0
            local hasRags = inventory:getItemCount("RippedSheets") > 0
            local hasSkill = playerObj:getPerkLevel(Perks.Aiming) >= 3
            local isCleanable = item:getCondition() < item:getConditionMax() or item:getHaveBeenRepaired() > 1

            -- Show option if they have either cleaning kit OR any firearm lubricant
            if hasKit or hasAnyLube then
                local option = context:addOption("Clean Firearm", item, function()
                    -- Give voice feedback for missing requirements
                if not hasKit then
                    HFO.InnerVoice.say("CleanNeedKit")
                    return
                end
                if not hasLubeWithUses then
                    HFO.InnerVoice.say("CleanNeedLube") 
                    return
                end
                if not hasRags then
                    HFO.InnerVoice.say("CleanNeedRags")
                    return
                end
                if not hasSkill then
                    HFO.InnerVoice.say("CleanNeedSkill")
                    return
                end
                if not isCleanable then
                    HFO.InnerVoice.say("CleanNoNeed")
                    return
                end
                    
                    ISTimedActionQueue.add(ISCleanFirearm:new(playerObj, item, 400))
                end)
                
                -- Show tooltip for missing requirements
                if not (hasKit and hasLubeWithUses and hasRags and hasSkill and isCleanable) then
                    option.notAvailable = true
                    local tooltip = ISWorldObjectContextMenu.addToolTip()
                    local missing = {}
                    if not hasSkill then table.insert(missing, getText("ContextMenu_Cleaning_Missing_Skill")) end
                    if not hasKit then table.insert(missing, getText("ContextMenu_Cleaning_Missing_Kit")) end
                    if not hasLubeWithUses then table.insert(missing, getText("ContextMenu_Cleaning_Missing_Lube")) end
                    if not hasRags then table.insert(missing, getText("ContextMenu_Cleaning_Missing_Rags")) end
                    if not isCleanable then table.insert(missing, getText("ContextMenu_Cleaning_Missing_Cleanable")) end

                    local header = getText("ContextMenu_Cleaning_Missing_Header")
                    tooltip.description = header .. "<LINE>- " .. table.concat(missing, "<LINE>- ")
                    option.toolTip = tooltip
                end
            end
        end
    end
end)