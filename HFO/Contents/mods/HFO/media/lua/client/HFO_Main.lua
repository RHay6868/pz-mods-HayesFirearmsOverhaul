--============================================================--
--                        HFO_Main.lua                        --
--============================================================--
-- Overview:
--   Core client-side initializer and global hotkey manager for
--   Hayes Firearms Overhaul (HFO). This script loads essential
--   modules and binds player-triggered firearm interactions to
--   their configured hotkeys.
--
-- Responsibilities:
--   - Initializes required HFO modules on game load.
--   - Caches and registers custom hotkey mappings.
--   - Routes hotkey presses to relevant handler functions.
--   - Provides centralized logic for key firearm features
--
-- Notes:
--   - Designed for extensibility and clarity.
--============================================================--

require "HFO_Utils"
require "HFO_SandboxUtils"
require "HFO_Loot"
require "HFO_Constants"
require "HFO_WeaponUtils"
require "HFO_ReloadUtils"
require "HFO_WeaponRadial"
require "BGunTweaker"
require "BGunModelChange"
require "ISUI/HFO_TooltipWeaponParts"
require "ISUI/HFO_TooltipWeaponStats"
require "ISUI/HFO_WeaponViewer"

if isClient() then
    require("HFO_InnerVoice")
end


HFO = HFO or {}


---===========================================---
--             HOTKEY VALUES CACHE             --
---===========================================---

HFO.hotkeys = HFO.hotkeys or {}

Events.OnGameStart.Add(function()
	HFO.hotkeys.WeaponLight         = getCore():getKey("WeaponLight")
	HFO.hotkeys.MeleeMode           = getCore():getKey("MeleeMode")
	HFO.hotkeys.FoldUnfold          = getCore():getKey("FoldUnfold")
	HFO.hotkeys.Integrated          = getCore():getKey("Integrated")
	HFO.hotkeys.FireMode            = getCore():getKey("FireMode")
	HFO.hotkeys.FireModeReverse     = getCore():getKey("FireModeReverse")
	HFO.hotkeys.SwapMag             = getCore():getKey("SwapMagazine")
	HFO.hotkeys.SwapMagReverse      = getCore():getKey("SwapMagazineReverse")
	HFO.hotkeys.AmmoChange          = getCore():getKey("AmmoChange")
	HFO.hotkeys.AmmoChangeReverse   = getCore():getKey("AmmoChangeReverse")
	HFO.hotkeys.InspectWeapon       = getCore():getKey("InspectWeapon")
	HFO.hotkeys.InnerVoiceToggle    = getCore():getKey("InnerVoiceToggle")

	Events.OnKeyPressed.Add(HFO.handleKeypress)
end)


function HFO.handleKeypress(keyNum)
	--HFO.Utils.debugLog("Key Pressed: " .. tostring(keyNum))

		if keyNum == HFO.hotkeys.WeaponLight        then HFO.WeaponUtils.WeaponLightHotkey(keyNum)
	elseif keyNum == HFO.hotkeys.MeleeMode          then HFO.WeaponUtils.MeleeModeHotkey(keyNum)
	elseif keyNum == HFO.hotkeys.FoldUnfold         then HFO.FoldUnfoldHotkey(keyNum)
	elseif keyNum == HFO.hotkeys.Integrated         then HFO.IntegratedHotkey(keyNum)
	elseif keyNum == HFO.hotkeys.FireMode           then HFO.WeaponUtils.cycleFiremode(keyNum)
	elseif keyNum == HFO.hotkeys.FireModeReverse    then HFO.WeaponUtils.cycleFiremode(keyNum, true)
	elseif keyNum == HFO.hotkeys.SwapMag            then HFO.ReloadUtils.SwapMagHotkey(keyNum)
	elseif keyNum == HFO.hotkeys.SwapMagReverse     then HFO.ReloadUtils.SwapMagHotkey(keyNum, true)
	elseif keyNum == HFO.hotkeys.AmmoChange         then HFO.ReloadUtils.SwapAmmoHotkey(keyNum)
	elseif keyNum == HFO.hotkeys.AmmoChangeReverse  then HFO.ReloadUtils.SwapAmmoHotkey(keyNum, true)
	elseif keyNum == HFO.hotkeys.InspectWeapon      then HFO.InspectWeapon(keyNum)
	elseif keyNum == HFO.hotkeys.InnerVoiceToggle   then HFO.InnerVoice.InnerVoiceToggle(keyNum)
	end
end


---===========================================---
--          HOTKEY WRAPPERS FOR SWAPS          --
---===========================================---

function HFO.FoldUnfoldHotkey(keyNum)
	HFO.Utils.runGenericSwap("HFO_FoldSwap")
end

function HFO.IntegratedHotkey(keyNum)
	HFO.Utils.runGenericSwap("HFO_IntegratedSwap")
end


---===========================================---
--           WEAPON VIEWER UI HOTKEY           --
---===========================================---

function HFO.InspectWeapon(keyNum)
	local player = getSpecificPlayer(0)
	if not player then return end

	-- Toggle off if already open
	if HFO_WeaponViewer_Instance then
		HFO_WeaponViewer_Instance:removeFromUIManager()
		HFO_WeaponViewer_Instance = nil
		return
	end

	local weapon = player:getPrimaryHandItem()
	if weapon and instanceof(weapon, "HandWeapon") and weapon:isAimedFirearm() then
		local viewer = HFO_WeaponViewer:new(100, 100, 0, 0, weapon)
		viewer:initialise()
		viewer:addToUIManager()
		HFO_WeaponViewer_Instance = viewer
        HFO.InnerVoice.say("WeaponInspect")
	else
		HFO.InnerVoice.say("WeaponInspectFailed")
	end
end