--============================================================--
--               HFO_WeaponRadial.lua                         --
--============================================================--
-- Purpose:
--   Extends and overrides the vanilla ISFirearmRadialMenu to support
--   Hayes Firearms Overhaul (HFO) mechanics. Dynamically injects mod-
--   specific firearm actions into the radial menu when applicable.
--
-- Overview:
--   - Enhances the radial menu with HFO utility functions.
--   - Adds support for toggling firemodes, weapon lights, melee modes.
--   - Allows folding/unfolding stocks and toggling bipod/grip states.
--   - Supports magazine cycling (next/previous) and context-based options.
--
-- Core Features:
--   - Seamlessly integrates into existing UI flow without conflicts.
--   - Uses part tags and suffix rules to determine available options.
--   - Respects weapon state, player input, and HFO constants.
--   - Designed to remain modular, extendable, and multiplayer-safe.
--
-- Dependencies:
--   - HFO_Utils, HFO_Constants, HFO_WeaponUtils, ISFirearmRadialMenu
--
-- Notes:
--   - This file assumes the player is using a firearm governed by HFO 
--============================================================--


require "HFO_Utils"
require "HFO_SandboxUtils"
require "HFO_Constants"
require "ISUI/ISFirearmRadialMenu"

HFO = HFO or {};


---===========================================---
--    HOOK INTO VANILLA FIREARM RADIAL MENU    --
---===========================================---

function ISFirearmRadialMenu:getWeapon()  -- a call to pull up the firearms radial menu if function criteria is met
    local weapon = self.character:getPrimaryHandItem()
    if weapon and instanceof(weapon, "HandWeapon") then
        -- Check for weapons in melee mode by examining their modData
        if weapon:isRanged() or weapon:isAimedFirearm() or (weapon:getModData().MeleeSwap and not weapon:isRanged()) then
            return weapon
        end
    end
    return nil
end

function HFO.addRadialMenuItem(main, name, icons, func, args)

	table.insert(main, {
		name = name,
		icons = icons,
		functions = func,
		arguments = args
	})
end

local ISFirearmRadialMenu_fillMenu_Vanilla = ISFirearmRadialMenu.fillMenu 

function ISFirearmRadialMenu:fillMenu(submenu)
    HFO.Utils.debugLog("fillMenu called: submenu = " .. tostring(submenu))
    local menu = getPlayerRadialMenu(self.playerNum)
    menu:clear()

    local weapon = self:getWeapon() 
    if not weapon then return end
    
    self.main = {}
    
    -- First, collect all the vanilla menu items WITHOUT adding them to the menu yet
    local vanillaSlices = {}
    
    local originalAddSlice = menu.addSlice 
    menu.addSlice = function(self, name, texture, func, target, arg)
        if name or texture or func then -- Only collect non-blank slices
            table.insert(vanillaSlices, {
                name = name, 
                icons = texture, 
                functions = func, 
                target = target,
                arguments = arg
            })
        end
    end
    
    ISFirearmRadialMenu_fillMenu_Vanilla(self)
    
    -- Restore the original addSlice function
    menu.addSlice = originalAddSlice
    
    -- Load weapon data for custom items
    local md = weapon:getModData()
    local weaponType = weapon:getType()
    local isRanged = weapon:isRanged()
    local meleeSwap = md.MeleeSwap
    local foldSwap = md.FoldSwap
    local integratedSwap = md.IntegratedSwap
    local currentMag = weapon:getMagazineType() or ""
    local weaponStock = weapon:getStock()
    local lightOn = md.LightOn
    
    -- Add custom menu items
    -- Melee Mode
    if meleeSwap then
        local label = getText("IGUI_HFO_MeleeMode")..'\n['..(isRanged and getText("IGUI_HFO_MeleeRanged") or getText("IGUI_HFO_MeleeMelee"))..']'
        local icon = isRanged and HFO.Utils.getItemTexture("HFO_MeleeMelee") or HFO.Utils.getItemTexture("HFO_MeleeRanged")
        HFO.addRadialMenuItem(self.main, label, icon, HFO.WeaponUtils.MeleeModeHotkey)
    end
    
    -- Fold/Unfold
    if foldSwap then
        local isFolded = string.find(weaponType, "_Folded") or not string.find(weaponType, "Extended")
        local label = getText("IGUI_HFO_StockToggle")..'\n['..(isFolded and getText("IGUI_HFO_StockFold") or getText("IGUI_HFO_StockExtended"))..']'
        HFO.addRadialMenuItem(self.main, label, HFO.Utils.getItemTexture("HFO_StockFold"), HFO.FoldUnfoldHotkey)
    end
    
    -- Integrated Mode
    if integratedSwap then
        local state = string.find(weaponType, "_Grip") and "Grip" or string.find(weaponType, "_Bipod") and "Extended" or "Retracted"
        local label = getText("IGUI_HFO_IntegratedToggle")..'\n['..getText("IGUI_HFO_Integrated" .. state)..']'
        HFO.addRadialMenuItem(self.main, label, HFO.Utils.getItemTexture("HFO_BipodFold"), HFO.IntegratedHotkey)
    end
    
    -- Weapon Light
    if weaponStock and HFO.Constants.LightSettingsByStock[weaponStock:getType()] then
        local label = getText("IGUI_HFO_WeaponLight")..'\n['..(lightOn and getText("IGUI_HFO_On") or getText("IGUI_HFO_Off"))..']'
        local icon = lightOn and HFO.Utils.getItemTexture("HFO_WeaponLightOn") or HFO.Utils.getItemTexture("HFO_WeaponLightOff")
        HFO.addRadialMenuItem(self.main, label, icon, HFO.WeaponUtils.WeaponLightHotkey)
    end
    
    -- Firemode Cycling
    if not HFO.Utils.isInMeleeMode(weapon) and weapon:getFireModePossibilities() and weapon:getFireModePossibilities():size() > 1 then
        local modes = HFO.WeaponUtils.getNextPrevFireModes(weapon)
        if modes then
            HFO.addRadialMenuItem(self.main, getText("IGUI_HFO_Firemode")..'\n→ ['..getText("ContextMenu_FireMode_" .. modes.next)..']', HFO.Utils.getItemTexture("HFO_Firemode"), function() HFO.WeaponUtils.cycleFiremode(false) end)
            HFO.addRadialMenuItem(self.main, getText("IGUI_HFO_Firemode")..'\n← ['..getText("ContextMenu_FireMode_" .. modes.prev)..']', HFO.Utils.getItemTexture("HFO_FiremodeReverse"), function() HFO.WeaponUtils.cycleFiremode(true) end)
        end
    end
    
    -- Magazine Swap
    local validMags = HFO.ReloadUtils.getAvailableMagTypes(getSpecificPlayer(self.playerNum), weapon)

    if not HFO.Utils.isInMeleeMode(weapon) and #validMags > 1 then
        local currentMag = weapon:getMagazineType()
        local magCycle = HFO.Utils.getNextPrevFromList(validMags, currentMag)
        local nextMagType = reverse and magCycle.prev or magCycle.next
    
        local forwardMag = magCycle.next
        local reverseMag = magCycle.prev
    
        local md = weapon:getModData()
        local maps = HFO.Utils.getMagazineInfoMaps(md)

    -- Use shared utility to resolve icon/name with fallback
        local function getMagDetails(magType)
        local name = maps.nameMap[magType]
        local iconName = maps.iconMap[magType]

        if not name or not iconName then
            local item = getScriptManager():FindItem(magType)
            name = name or (item and item:getDisplayName()) or tostring(magType)
            iconName = iconName or (item and item:getIcon())
        end

        local icon = HFO.Utils.getItemTexture(iconName or "HFO_swap_base")
        return name, icon
    end

    local fwdName, fwdIcon = getMagDetails(forwardMag)
    local revName, revIcon = getMagDetails(reverseMag)
    
    -- Always show forward
    HFO.addRadialMenuItem(self.main,
        getText("IGUI_HFO_SwapMagazine") .. "\n→ " .. fwdName,
        fwdIcon,
        HFO.ReloadUtils.SwapMagHotkey
    )

    -- Only show reverse if 3+ mags
    if #validMags > 2 then
        HFO.addRadialMenuItem(self.main,
            getText("IGUI_HFO_SwapMagazine") .. "\n← " .. revName,
            revIcon,
            function()
                HFO.ReloadUtils.SwapMagHotkey(getCore():getKey("SwapMagazineReverse"), true)
            end,
            getCore():getKey("SwapMagazineReverse")
        )
        end
    end

    -- Render menu
    if not submenu then
        for i, v in ipairs(self.main) do -- Add custom slices first
            if type(v) == "table" and v.name and v.icons and v.functions then
                menu:addSlice(v.name, v.icons, v.functions, self, v.arguments)
            else
                HFO.Utils.debugLog(string.format(" Skipping invalid slice at index %d: %s", i, tostring(v and v.name or "nil")))
            end
        end
        
        for _, slice in ipairs(vanillaSlices) do -- Then add vanilla slices
            menu:addSlice(slice.name, slice.icons, slice.functions, slice.target, slice.arguments)
        end
    elseif self.main[submenu] and self.main[submenu].subMenu then
        for _, v in pairs(self.main[submenu].subMenu) do
            menu:addSlice(v.name, v.icons, v.functions, self, v.arguments)
        end
        menu:addSlice(getText("IGUI_Emote_Back"), getTexture("media/ui/emotes/back.png"), self.fillMenu, self)
    end
    
    self:display()
end

function ISFirearmRadialMenu.checkWeapon(playerObj)
    local weapon = playerObj:getPrimaryHandItem()
    if not weapon or not instanceof(weapon, "HandWeapon") then
        return false
    end
    
    -- Check for weapons that are: In ranged mode then Aimed Firearms and then Weapons with MeleeSwap capability, even if currently in melee mode
    if weapon:isRanged() or weapon:isAimedFirearm() then
        return true
    end
    
    -- Check for weapons in melee mode that can be toggled back
    if weapon:getModData().MeleeSwap then
        return true
    end
    
    return false
end