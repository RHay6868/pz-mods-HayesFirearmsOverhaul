--============================================================--
--                    HFO_SandboxUtils.lua                    --
--============================================================--
-- Purpose:
--   Normalize and safely access HFO-related SandboxVars 
--   Attrempts to ensures consistent settings, even if values are 
--   missing, invalid, or misconfigured by the player or server.
--
-- Overview:
--   This module handles parsing, clamping, and fallback logic for 
--   Hayes Firearms Overhaul mod settings. It centralizes how systems
--   access sandbox options.
--
-- Core Features:
--   - Clamps enums to valid ranges (e.g., 1-7 for rarity settings)
--   - Converts nil/bad inputs to usable booleans or numbers
--   - Returns fully-structured settings tables for use by other systems
--   - Tracks presence of sub mods (e.g., HFE) for conditional logic
--   - Registers an OnGameStart hook to initialize values early
--
-- Responsibilities:
--   - Prevent crashes or erratic behavior due to malformed settings
--   - Keep sandbox value handling centralized and up to date
--   - Minimize burden on dependent systems (firearms, loot, cleaning, etc.)
--
-- Usage:
--   - Use HFO.SandboxUtils.get() anywhere safe settings are needed
--   - Auto-loads via OnGameStart for early availability
--
-- Notes:
--   - This module is expected to grow with future sandbox additions
--   - Avoid hard-coding SandboxVars directly outside this module
--============================================================--

HFO = HFO or {}
HFO.SandboxUtils = HFO.SandboxUtils or {}
HFO.sVars = SandboxVars.HFO or {}


---===========================================---
--         NORMALIZE SANDBOX SETTINGS          --    
---===========================================---

function HFO.SandboxUtils.getSafeSandboxVars()
    local s = HFO.sVars or {}

    -- Enum values with safe bounds (defaults to 4 if outside a valid range)
    local function clampEnum(val, def, min, max)
        val = tonumber(val)
        if not val or val < min or val > max then return def end
        return val
    end

    local result = {
        Loot             = clampEnum(s.Loot,          4, 1, 7),
        Firearms         = clampEnum(s.Firearms,      4, 1, 7),
        Ammo             = clampEnum(s.Ammo,          4, 1, 7),
        Accessories      = clampEnum(s.Accessories,   4, 1, 7),
        Extended         = clampEnum(s.Extended,      4, 1, 7),
        FirearmCache     = clampEnum(s.FirearmCache,  4, 1, 7),
        FirearmSkins     = clampEnum(s.FirearmSkins,  4, 1, 7),
        JamChance        = clampEnum(s.JamChance,     4, 1, 7),

        -- Boolean toggles General
        ExclusiveFirearmSkins    = s.ExclusiveFirearmSkins == true,
        RepairKits               = s.RepairKits ~= false,
        Cleaning                 = s.Cleaning ~= false,
        ColtCavalry              = s.ColtCavalry == true,
        FGMG42                   = s.FGMG42 == true,
        TShirtLauncher           = s.TShirtLauncher == true,
        CrossbowAmmoMag          = s.CrossbowAmmoMag == true,
        XbowComponentInstead     = s.XbowComponentInstead ~= false,
        DartsComponentInstead    = s.XbowComponentInstead ~= false,

        -- Boolean toggles Firearms
        FirearmsHandguns         = s.FirearmsHandguns ~= false,
        FirearmsSMGs             = s.FirearmsSMGs ~= false,
        FirearmsRifles           = s.FirearmsRifles ~= false,
        FirearmsSnipers          = s.FirearmsSnipers ~= false,
        FirearmsShotguns         = s.FirearmsShotguns ~= false,
        FirearmsOther            = s.FirearmsOther ~= false,

        -- Boolean toggles Ammo
        AmmoHandguns             = s.AmmoHandguns ~= false,
        AmmoRifles               = s.AmmoRifles ~= false,
        AmmoShotguns             = s.AmmoShotguns ~= false,
        AmmoOther                = s.AmmoOther ~= false,

        -- Boolean toggles Accessories
        AccessoriesSuppressors   = s.AccessoriesSuppressors ~= false,
        AccessoriesScopes        = s.AccessoriesScopes ~= false,
        AccessoriesOther         = s.AccessoriesOther ~= false,

        -- Boolean toggles Extended mags + Speedloaders
        ExtendedSmall            = s.ExtendedSmall == true,
        ExtendedLarge            = s.ExtendedLarge == true,
        ExtendedDrum             = s.ExtendedDrum == true,
        SpeedLoaders             = s.SpeedLoaders == true,

        -- Spawn Rate values firearms
        FirearmsHandgunsRates  = tonumber(s.FirearmsHandgunsRates) or 50,
        FirearmsSMGsRates      = tonumber(s.FirearmsSMGsRates) or 50,
        FirearmsRiflesRates    = tonumber(s.FirearmsRiflesRates) or 50,
        FirearmsSnipersRates   = tonumber(s.FirearmsSnipersRates) or 50,
        FirearmsShotgunsRates  = tonumber(s.FirearmsShotgunsRates) or 50,
        FirearmsOtherRates     = tonumber(s.FirearmsOtherRates) or 50,

        -- Spawn Rate values ammo
        AmmoHandgunsRates = tonumber(s.AmmoHandgunsRates) or 50,
        AmmoRiflesRates   = tonumber(s.AmmoRiflesRates) or 50,
        AmmoShotgunsRates = tonumber(s.AmmoShotgunsRates) or 50,
        AmmoOtherRates    = tonumber(s.AmmoOtherRates) or 50,

        -- Spawn Rate values accessories
        AccessoriesSuppressorsRates  = tonumber(s.AccessoriesSuppressorsRates) or 20,
        AccessoriesScopesRates       = tonumber(s.AccessoriesScopesRates) or 30,
        AccessoriesOtherRates        = tonumber(s.AccessoriesOtherRates) or 40,

        -- Stat Changes on base firearms
        DamageStats        = tonumber(s.DamageStats) or 10,
        RangeStats         = tonumber(s.RangeStats) or 10,
        SoundStats         = tonumber(s.SoundStats) or 10,
        MeleeDamageStats   = tonumber(s.MeleeDamageStats) or 0,

        -- Cleaning / mechanic values
        CleanRepairSpawns  = tonumber(s.CleanRepairSpawns) or 2,
        CleaningFail       = tonumber(s.CleaningFail) or 0,
        CleaningStats      = tonumber(s.CleaningStats) or 0,
        CleaningRepairRate = tonumber(s.CleaningRepairRate) or 4,

        -- Suppression levels (these are integer sliders 0-100)
        SuppressorBreak         = tonumber(s.SuppressorBreak) or 20,
        PistolSuppressionLevels = tonumber(s.PistolSuppressionLevels) or 10,
        RifleSuppressionLevels  = tonumber(s.RifleSuppressionLevels) or 15,
        SniperSuppressionLevels = tonumber(s.SniperSuppressionLevels) or 25,

        -- Crossbow mechanics
        XbowMetalBreakChance  = tonumber(s.XbowMetalBreakChance) or 20,
        XbowWoodBreakChance   = tonumber(s.XbowWoodBreakChance) or 50,
        XbowLostChance        = tonumber(s.XbowLostChance) or 10,
        DartBreakChance       = tonumber(s.DartBreakChance) or 30,
        DartsLostChance       = tonumber(s.DartsLostChance) or 20,
    }

    -- Inject HFE mod flag if sub mod is active
    result.HFE = getActivatedMods():contains("HayesFirearmsExtensionDEVTEST")

    return result
end

function HFO.SandboxUtils.isEnumEnabled(value)
    return value and value >= 2 -- Not "Never"
end

-- main utility to snag safe sandbox settings
function HFO.SandboxUtils.get()
    if not HFO.sv then
        HFO.sv = HFO.SandboxUtils.getSafeSandboxVars()
    end
    return HFO.sv
end

function HFO.SandboxUtils.loadSafeSandbox()
    HFO.sv = HFO.SandboxUtils.getSafeSandboxVars()
end

Events.OnGameStart.Add(HFO.SandboxUtils.loadSafeSandbox)