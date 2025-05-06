--============================================================--
--               HFO_SandboxOptions_Tweaker.lua               --
--============================================================--
-- Purpose:
--   Dynamically modifies base weapon stats (firearms + melee) based on
--   HFO sandbox settings, allowing server/client customization of damage,
--   range, and sound levels at game start.
--
-- Overview:
--   This file loads and caches base values for supported firearms
--   (including special _Melee variants), then applies stat scaling
--   using values pulled from HFO_SandboxUtils.
--
-- Core Features:
--   - Reads all HFO-defined firearms from HFO.Constants
--   - Applies stat scaling (damage, range, sound) via DoParam
--   - Supports melee conversion weapons (e.g. bipod-folded)
--   - Loads on OnGameStart` for early application
--   - Skips specific melee exceptions to prevent bad overrides
--
-- Responsibilities:
--   - Centralized application of custom stat tweaks
--   - Preserve and respect original values for fallback logic
--
-- Dependencies:
--   - HFO_SandboxUtils (for safe setting access)
--   - HFO_Constants (for list of mod weapons)
--   - HFO_Utils (for debug logging)
--
-- Notes:
--   - Intended to run only once on load no hot reload behavior
--   - Designed to be compatible with multiplayer/server play
--============================================================--


require "HFO_Utils"
require "HFO_SandboxUtils"
require "HFO_Constants"

HFO = HFO or {}

local firearmsStats = {}
local meleeFirearmStats = {}


---===========================================---
--    GATHER FIREARM INFO AND APPLY SETTINGS   --
---===========================================---

-- Pull all valid firearm names from Constants our single source of truth
local function getAllFirearmNames()
    local sv = HFO.SandboxUtils.get()
    local result = {}

    for subtype, sources in pairs(HFO.Constants.Items.Firearms or {}) do
        for sourceMod, itemList in pairs(sources or {}) do
            if sourceMod == "Base" or sv[sourceMod] == true then
                for _, name in ipairs(itemList) do
                    table.insert(result, "Base." .. name)
                end
            end
        end
    end

    return result
end

-- Cache original firearm stats that can be influenced by sandbox settings
local function initializeFirearmStats()
    for _, fullName in ipairs(getAllFirearmNames()) do
        local weapon = ScriptManager.instance:getItem(fullName)
        if weapon and weapon:isRanged() then
            firearmsStats[fullName] = {
                minDamage = weapon:getMinDamage(),
                maxDamage = weapon:getMaxDamage(),
                maxRange = weapon:getMaxRange(),
                soundRadius = weapon:getSoundRadius(),
                soundVolume = weapon:getSoundVolume(),
            }
        end
    end
end

-- Cache melee stats for _Melee versions with exceptions that dont have melee types
local function initializeMeleeStats()
    local meleeExceptions = {
        ["Base.PM63RAK_Grip_Melee"] = true,
        ["Base.PM63RAK_GripExtended_Melee"] = true,
        ["Base.M1918BAR_Bipod_Melee"] = true,
        ["Base.L2A1_Bipod_Melee"] = true,
        ["Base.FG42_Bipod_Melee"] = true,
        ["Base.MG42_Bipod_Melee"] = true,
        ["Base.BarrettM82A1_Bipod_Melee"] = true,
        ["Base.McMillanTAC50_Bipod_Melee"] = true,
        ["Base.Galil_Bipod_Melee"] = true,
    }

    for fullName, _ in pairs(firearmsStats) do
        local meleeName = fullName .. "_Melee"
        if not meleeExceptions[meleeName] then
            local melee = ScriptManager.instance:getItem(meleeName)
            if melee then
                meleeFirearmStats[meleeName] = {
                    meleeMinDamage = melee:getMinDamage(),
                    meleeMaxDamage = melee:getMaxDamage()
                }
            end
        end
    end
end

-- Apply scaled firearm stats with proper clamping
local function applyFirearmStats(weaponName, stats, sv)
    local weapon = ScriptManager.instance:getItem(weaponName)
    if not weapon then
        HFO.Utils.debugLog("[HFO.Firearms] Missing item: " .. tostring(weaponName))
        return
    end

    local minDamage = stats.minDamage or 0
    local maxDamage = stats.maxDamage or 0
    local maxRange = stats.maxRange or 0
    local soundRadius = stats.soundRadius or 0
    local soundVolume = stats.soundVolume or 0

    weapon:DoParam("MinDamage = " .. math.max(0.1, math.floor(minDamage * sv.DamageStats) / 10))
    weapon:DoParam("MaxDamage = " .. math.max(0.4, math.floor(maxDamage * sv.DamageStats) / 10))
    weapon:DoParam("MaxRange = " .. math.max(1, math.floor(maxRange * sv.RangeStats / 10)))
    weapon:DoParam("SoundRadius = " .. math.max(5, math.floor(soundRadius * sv.SoundStats / 10)))
    weapon:DoParam("SoundVolume = " .. math.max(5, math.floor(soundVolume * sv.SoundStats / 10)))
end

-- Apply scaled melee stats with proper clamping
local function applyMeleeStats(weaponName, stats, sv)
    local weapon = ScriptManager.instance:getItem(weaponName)
    if not weapon then
        HFO.Utils.debugLog("[HFO.Melee] Missing item: " .. tostring(weaponName))
        return
    end

    local meleeMinDamage = stats.meleeMinDamage or 0
    local meleeMaxDamage = stats.meleeMaxDamage or 0

    weapon:DoParam("MinDamage = " .. math.max(0.1, meleeMinDamage + (sv.MeleeDamageStats * 0.1)))
    weapon:DoParam("MaxDamage = " .. math.max(0.2, meleeMaxDamage + (sv.MeleeDamageStats * 0.1)))
end


---===========================================---
--                 EVENT HOOKS                 --
---===========================================---

Events.OnGameStart.Add(function()
    local sv = HFO.SandboxUtils.get()

    initializeFirearmStats()
    initializeMeleeStats()

    for weaponName, stats in pairs(firearmsStats) do
        applyFirearmStats(weaponName, stats, sv)
    end

    for meleeName, stats in pairs(meleeFirearmStats) do
        applyMeleeStats(meleeName, stats, sv)
    end
end)