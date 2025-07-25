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


---===========================================---
--         NORMALIZE SANDBOX SETTINGS          --    
---===========================================---

function HFO.SandboxUtils.getSafeSandboxVars()
    -- Enum values with safe bounds (defaults to 4 if outside a valid range)
    local function clampEnum(val, def, min, max)
        val = tonumber(val)
        if not val or val < min or val > max then return def end
        return val
    end

    local result = {
        Loot             = clampEnum(SandboxVars.HFO.Loot,          4, 1, 7),
        Firearms         = clampEnum(SandboxVars.HFO.Firearms,      4, 1, 7),
        Ammo             = clampEnum(SandboxVars.HFO.Ammo,          4, 1, 7),
        Accessories      = clampEnum(SandboxVars.HFO.Accessories,   4, 1, 7),
        Extended         = clampEnum(SandboxVars.HFO.Extended,      4, 1, 7),
        FirearmCache     = clampEnum(SandboxVars.HFO.FirearmCache,  4, 1, 7),
        FirearmSkins     = clampEnum(SandboxVars.HFO.FirearmSkins,  4, 1, 7),
        JamChance        = clampEnum(SandboxVars.HFO.JamChance,     4, 1, 7),

        -- Boolean toggles General
        ExclusiveFirearmSkins    = SandboxVars.HFO.ExclusiveFirearmSkins == true,
        ServerFirearmSkins       = SandboxVars.HFO.ServerFirearmSkins == true,
        RepairKits               = SandboxVars.HFO.RepairKits ~= false,
        Cleaning                 = SandboxVars.HFO.Cleaning ~= false,
        ColtCavalry              = SandboxVars.HFO.ColtCavalry == true,
        FGMG42                   = SandboxVars.HFO.FGMG42 == true,
        TShirtLauncher           = SandboxVars.HFO.TShirtLauncher == true,
        XbowComponentInstead     = SandboxVars.HFO.XbowComponentInstead ~= false,
        DartsComponentInstead    = SandboxVars.HFO.XbowComponentInstead ~= false,

        -- Boolean toggles Firearms
        FirearmsHandguns         = SandboxVars.HFO.FirearmsHandguns ~= false,
        FirearmsSMGs             = SandboxVars.HFO.FirearmsSMGs ~= false,
        FirearmsRifles           = SandboxVars.HFO.FirearmsRifles ~= false,
        FirearmsSnipers          = SandboxVars.HFO.FirearmsSnipers ~= false,
        FirearmsShotguns         = SandboxVars.HFO.FirearmsShotguns ~= false,
        FirearmsOther            = SandboxVars.HFO.FirearmsOther ~= false,

        -- Boolean toggles Ammo
        AmmoHandguns             = SandboxVars.HFO.AmmoHandguns ~= false,
        AmmoRifles               = SandboxVars.HFO.AmmoRifles ~= false,
        AmmoShotguns             = SandboxVars.HFO.AmmoShotguns ~= false,
        AmmoOther                = SandboxVars.HFO.AmmoOther ~= false,

        -- Boolean toggles Accessories
        AccessoriesSuppressors   = SandboxVars.HFO.AccessoriesSuppressors ~= false,
        AccessoriesScopes        = SandboxVars.HFO.AccessoriesScopes ~= false,
        AccessoriesOther         = SandboxVars.HFO.AccessoriesOther ~= false,

        -- Boolean toggles Extended mags + Speedloaders
        ExtendedSmall            = SandboxVars.HFO.ExtendedSmall == true,
        ExtendedLarge            = SandboxVars.HFO.ExtendedLarge == true,
        ExtendedDrum             = SandboxVars.HFO.ExtendedDrum == true,
        SpeedLoaders             = SandboxVars.HFO.SpeedLoaders == true,

        -- Spawn Rate values firearms
        FirearmsHandgunsRates  = tonumber(SandboxVars.HFO.FirearmsHandgunsRates) or 50,
        FirearmsSMGsRates      = tonumber(SandboxVars.HFO.FirearmsSMGsRates) or 50,
        FirearmsRiflesRates    = tonumber(SandboxVars.HFO.FirearmsRiflesRates) or 50,
        FirearmsSnipersRates   = tonumber(SandboxVars.HFO.FirearmsSnipersRates) or 50,
        FirearmsShotgunsRates  = tonumber(SandboxVars.HFO.FirearmsShotgunsRates) or 50,
        FirearmsOtherRates     = tonumber(SandboxVars.HFO.FirearmsOtherRates) or 50,

        -- Spawn Rate values ammo
        AmmoHandgunsRates = tonumber(SandboxVars.HFO.AmmoHandgunsRates) or 50,
        AmmoRiflesRates   = tonumber(SandboxVars.HFO.AmmoRiflesRates) or 50,
        AmmoShotgunsRates = tonumber(SandboxVars.HFO.AmmoShotgunsRates) or 50,
        AmmoOtherRates    = tonumber(SandboxVars.HFO.AmmoOtherRates) or 50,

        -- Spawn Rate values accessories
        AccessoriesSuppressorsRates  = tonumber(SandboxVars.HFO.AccessoriesSuppressorsRates) or 20,
        AccessoriesScopesRates       = tonumber(SandboxVars.HFO.AccessoriesScopesRates) or 30,
        AccessoriesOtherRates        = tonumber(SandboxVars.HFO.AccessoriesOtherRates) or 40,

        -- Stat Changes on base firearms
        DamageStats        = tonumber(SandboxVars.HFO.DamageStats) or 10,
        RangeStats         = tonumber(SandboxVars.HFO.RangeStats) or 10,
        SoundStats         = tonumber(SandboxVars.HFO.SoundStats) or 10,
        MeleeDamageStats   = tonumber(SandboxVars.HFO.MeleeDamageStats) or 0,

        -- Cleaning / mechanic values
        CleanRepairSpawns  = tonumber(SandboxVars.HFO.CleanRepairSpawns) or 2,
        CleaningFail       = tonumber(SandboxVars.HFO.CleaningFail) or 0,
        CleaningStats      = tonumber(SandboxVars.HFO.CleaningStats) or 0,
        CleaningRepairRate = tonumber(SandboxVars.HFO.CleaningRepairRate) or 4,

        -- Suppression levels (these are integer sliders 0-100)
        SuppressorBreak         = tonumber(SandboxVars.HFO.SuppressorBreak) or 20,
        PistolSuppressionLevels = tonumber(SandboxVars.HFO.PistolSuppressionLevels) or 10,
        RifleSuppressionLevels  = tonumber(SandboxVars.HFO.RifleSuppressionLevels) or 15,
        SniperSuppressionLevels = tonumber(SandboxVars.HFO.SniperSuppressionLevels) or 25,

        -- Crossbow mechanics
        XbowMetalBreakChance  = tonumber(SandboxVars.HFO.XbowMetalBreakChance) or 20,
        XbowWoodBreakChance   = tonumber(SandboxVars.HFO.XbowWoodBreakChance) or 50,
        XbowLostChance        = tonumber(SandboxVars.HFO.XbowLostChance) or 10,
        DartBreakChance       = tonumber(SandboxVars.HFO.DartBreakChance) or 30,
        DartsLostChance       = tonumber(SandboxVars.HFO.DartsLostChance) or 20,
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
    return HFO.SandboxUtils.getSafeSandboxVars()
end

function HFO.SandboxUtils.loadSafeSandbox()
    HFO.sv = HFO.SandboxUtils.getSafeSandboxVars()
end

Events.OnInitGlobalModData.Add(HFO.SandboxUtils.loadSafeSandbox)