--============================================================--
--                    HFO_TShirtLauncher.lua                  --
--============================================================--
-- Purpose:
--   MEME Firearm with proper mechanics for a T-shirt Launcher
--
-- Overview:
--   This file handles unique reload and ammo logic for the T-Shirt Launcher,
--   which uses shirts from inventory as projectile ammo. It determines shirt
--   eligibility, drop location (on hit or miss), and handles in-world effects
--   like blood decals and knockback.
--
-- Features:
--   - Uses wearable clothing items as ammo (shirts only... probably can be expanded)
--   - Handles reload logic by scanning inventory for valid shirts
--   - Spawns the shirt projectile in-world on hit or miss
--   - Includes cooldown handling to prevent duplicate shirt drops
--
-- Responsibilities:
--   - Register event hooks for reload, hit, and shot completion events
--   - Prevent overlapping triggers through timestamp cooldown logic
--
-- Dependencies:
--   - Requires HFO_Utils for player/weapon access and debug logging
--   - Optionally uses HFO.InnerVoice for randomized flavor text
--============================================================--

require "HFO_Utils"

HFO = HFO or {}
HFO.TShirtLauncher = HFO.TShirtLauncher or {}


---===========================================---
--       TSHIRT LAUNCHER HELPER FUNCTIONS      --
---===========================================---

-- Cooldown timestamp to prevent double-spawns on hit + shoot
HFO.TShirtLauncher.shotsSinceLastComment = 0
HFO.TShirtLauncher.nextCommentAt = ZombRand(3, 11) -- Randomized timer for inner voice dialogue lines

local function isTShirtLauncher(weapon)
    return weapon and string.find(weapon:getType(), "TShirtLauncher")
end

local function isValidShirt(item) -- helper to make sure we have any match no matter the way it is written for a shirt
    return item:IsClothing() and not item:isWorn() and string.match(item:getType(), "[Tt]?[Ss]?hirt")
end

-- Check if weapon has been fired (ammo count went to 0) and needs reload
local function weaponNeedsReload(weapon)
    return weapon:getCurrentAmmoCount() == 0
end

---===========================================---
--       TSHIRT LAUNCHER RELOAD MECHANIC       --
---===========================================---

function HFO.TShirtLauncher.SetLaunchableShirt()
    local player, weapon = HFO.Utils.getPlayerAndWeapon()
    if not player or not isTShirtLauncher(weapon) then return end
    if weapon:getCurrentAmmoCount() >= weapon:getMaxAmmo() then return end

    local items = player:getInventory():getItems()
    local md = weapon:getModData()

    -- Clear any previous shot handling flags when reloading
    md.HFO_shotAlreadyHandled = nil

    for i = 0, items:size() - 1 do -- Will grab the first available shirt and make it ammo for your next shot
        local item = items:get(i)
        if isValidShirt(item) then
            local shirtAmmoType = item:getFullType()
            weapon:setAmmoType(shirtAmmoType)
            md.HFO_tShirtToLaunch = shirtAmmoType
            HFO.Utils.debugLog("Loaded shirt: " .. shirtAmmoType)
            return
        end
    end

    HFO.Utils.debugLog("No valid shirt found to load.")
end


---===========================================---
--             SHIRT DROP HANDLING             --
---===========================================---
-- Honestly wanted it to land in the inventory or replace the shirt of the zombie
-- but all the various ways I approached it I was unable to make it work

function HFO.TShirtLauncher.DropShirtAt(square, shirtAmmoType)
    if not square or not shirtAmmoType then return false end
    local item = InventoryItemFactory.CreateItem(shirtAmmoType)
    if not item then return false end
    
    square:AddWorldInventoryItem(item, 0.5, 0.5, 0)
    getSoundManager():PlayWorldSound("ClothingDrop", square, 0, 8.0, 1.0, true) 
    HFO.Utils.debugLog("Shirt dropped at square (" .. square:getX() .. "," .. square:getY() .. ")")
    return true
end

function HFO.TShirtLauncher.GetShirtAmmoType(weapon) -- making sure the shirt we used is the same shirt
    if not isTShirtLauncher(weapon) then return nil end
    local md = weapon:getModData()
    return md and md.HFO_tShirtToLaunch
end


---===========================================---
--             SHIRT HIT MECHANICS             --
---===========================================---

function HFO.TShirtLauncher.OnHit(attacker, target, weapon, damage)
    if not isTShirtLauncher(weapon) then return end
    
    local shirtAmmoType = HFO.TShirtLauncher.GetShirtAmmoType(weapon)
    if not shirtAmmoType then return end

    -- Mark weapon's mod data to prevent OnShoot from also dropping a shirt
    local md = weapon:getModData()
    md.HFO_shotAlreadyHandled = true

    local square = target:getCurrentSquare()
    if square then
        HFO.TShirtLauncher.DropShirtAt(square, shirtAmmoType)

        if instanceof(target, "IsoZombie") then
            target:addBlood(BloodBodyPartType.Torso, false, true, false) 
            target:setStaggerBack(true) -- of course
        end
    end

    HFO.TShirtLauncher.shotsSinceLastComment = HFO.TShirtLauncher.shotsSinceLastComment + 1 -- inner voice dialogue randomizer
    if HFO.TShirtLauncher.shotsSinceLastComment >= HFO.TShirtLauncher.nextCommentAt then
        if HFO.InnerVoice and HFO.InnerVoice.say then
            HFO.InnerVoice.say("TShirtHit")
        end
        HFO.TShirtLauncher.shotsSinceLastComment = 0
        HFO.TShirtLauncher.nextCommentAt = ZombRand(3, 11)
    end
end


---===========================================---
--         SHIRT MISSED SHOT MECHANICS         --
---===========================================---

function HFO.TShirtLauncher.OnShoot(wielder, weapon)
    if not isTShirtLauncher(weapon) then return end
    
    local shirtAmmoType = HFO.TShirtLauncher.GetShirtAmmoType(weapon)
    if not shirtAmmoType then return end

    -- Check if OnHit already handled this shot
    local md = weapon:getModData()
    if md.HFO_shotAlreadyHandled then
        md.HFO_shotAlreadyHandled = nil -- Clear the flag
        return -- OnHit already dropped the shirt, don't drop another
    end

    -- This is a miss - drop the shirt at max range
    local maxRange = weapon:getMaxRange() or 10
    local facing = wielder:getForwardDirection()
    local cell = wielder:getCell()
    local startX, startY = wielder:getX(), wielder:getY()
    local startSquare = cell:getGridSquare(startX, startY, wielder:getZ())
    local landingSquare = nil
    
    for distance = 1, maxRange do
        local checkX = math.floor(startX + (facing:getX() * distance))
        local checkY = math.floor(startY + (facing:getY() * distance))
        local checkSquare = cell:getGridSquare(checkX, checkY, wielder:getZ())

        if not checkSquare or checkSquare:isBlockedTo(startSquare) then break end
        landingSquare = checkSquare
        if checkSquare:HasTree() or checkSquare:isVehicleIntersecting() then break end -- checks for trees and cars too
    end

    if landingSquare then
        HFO.TShirtLauncher.DropShirtAt(landingSquare, shirtAmmoType)

        HFO.TShirtLauncher.shotsSinceLastComment = HFO.TShirtLauncher.shotsSinceLastComment + 1 
        if HFO.TShirtLauncher.shotsSinceLastComment >= HFO.TShirtLauncher.nextCommentAt then
            if HFO.InnerVoice and HFO.InnerVoice.say then
                HFO.InnerVoice.say("TShirtMiss")
            end
            HFO.TShirtLauncher.shotsSinceLastComment = 0
            HFO.TShirtLauncher.nextCommentAt = ZombRand(3, 11)
        end
    end
end


---===========================================---
--                 EVENT HOOKS                 --
---===========================================---

Events.OnPressReloadButton.Add(HFO.TShirtLauncher.SetLaunchableShirt)
Events.OnWeaponHitCharacter.Add(HFO.TShirtLauncher.OnHit)
Events.OnPlayerAttackFinished.Add(HFO.TShirtLauncher.OnShoot)