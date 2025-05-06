--============================================================--
--                      HFO_Constants.lua                     --
--============================================================--
-- Purpose:
--   Defines centralized constants, mappings, and fallback logic used
--   across all major HFO systems: weapons, sandbox tuning, UI, loot,
--   recoil, lighting, attachments, suffix naming, and modData tracking.
--
-- Overview:
--   This file serves as the backbone of shared configuration 
--   It ensures that all systems access consistent values,
--   including tracked fields during swaps, sandbox-scoped
--   suppression or recoil settings, suffix renaming formats,
--   and tiered item categorization for distribution logic.
--
-- Core Features:
--   - Tracked modData fields for safe firearm state preservation
--   - Suffix renaming maps for dynamic UI weapon names
--   - Tooltip stat ordering and color/icon delta indicators
--   - Suppressor, recoil, light, and firing mode behavior tables
--   - Tiered loot tables with full category structure
--
-- Responsibilities:
--   - Prevent duplication of logic across weapon, loot, and sandbox systems
--   - Offer stable definitions used across UI, gameplay, and distribution
--
-- Dependencies:
--   - HFO_SandboxUtils is required to resolve suppression values at runtime
--
-- Usage:
--   - Access via HFO.Constants.<Category> (e.g., SuffixMappings, Items)
--   - Safe to read globally; avoid mutation outside Constants.lua
--
-- Notes:
--   - Mod-breaking if edited without caution. Update systems accordingly.
--   - Changes here affect spawning, attachments, stat views, and swap logic.
--============================================================--


HFO = HFO or {}
HFO.Constants = HFO.Constants or {}
local sv = HFO.SandboxUtils.get()


---===========================================---
--      MOD DATA SPECIFIC CONSTANTS     --
---===========================================---
-- NEED to plan out the swap process of modData to HFO_ prefix and create 
-- function to swap old moddata to new moddata as a lot of things have changed

HFO.Constants.TrackedModData = {
    "MeleeSwap", "FoldSwap",  "IntegratedSwap",  "currentName",  
    "MagBase",  "MagNone", "MagExtSm",  "MagExtLg",  "MagDrum", "currentMagType",
    "AdditionalAmmoTypes",  "currentAmmoType", "OriginalAmmoType",
}

-- Default fallback logic for missing modData fields (used during first-time captures)
HFO.Constants.ModDataFallbacks = {
    currentAmmoType     = function(weapon) return weapon:getAmmoType() end,
    currentMagType      = function(weapon) return weapon:getMagazineType() end,
    currentName         = function(weapon) return weapon:getName() end,
    MagBase             = function(weapon) return weapon:getMagazineType() end,
    MagNone             = function(_)      return "NoMag" end,
}


---===========================================---
--             UTILITY FOR CUSTOM UI           --
---===========================================---

-- Stat Display Priority Map for tooltips and ui
HFO.Constants.StatDisplayOrder = {
    ["Damage (Min)"]     = 1,
    ["Damage (Max)"]     = 2,
    ["Range"]            = 3,
    ["Hit Chance"]       = 4,
    ["Critical Chance"]  = 5,
    ["Recoil Delay"]     = 6,
    ["Firing Cone"]      = 7,
    ["Aiming Speed"]     = 8,
    ["Reload Speed"]     = 9,
    ["Sound Radius"]     = 10,
    ["Weight"]           = 11,
    ["Flashlight"]       = 12,
    ["Melee Damage"]     = 13,
}

function HFO.Constants.getPositiveColor()
    local c = getCore():getGoodHighlitedColor()
    return { c:getR(), c:getG(), c:getB() } 
end

function HFO.Constants.getNegativeColor()
    local c = getCore():getBadHighlitedColor()
    return { c:getR(), c:getG(), c:getB() }
end

function HFO.Constants.getNeutralColor()
    return { r = 1.0, g = 1.0, b = 1.0 }
end

local positiveColor = HFO.Constants.getPositiveColor()
local negativeColor = HFO.Constants.getNegativeColor()
local neutralColor = HFO.Constants.getNeutralColor()

-- 4-state delta system for color + icon pairing
HFO.Constants.StatChangeIndicators = {
    ["posIncrease"] = { color = positiveColor, icon = "media/ui/Moodle_internal_plus_green.png" },
    ["negIncrease"] = { color = negativeColor, icon = "media/ui/Moodle_internal_plus_red.png" },
    ["posDecrease"] = { color = positiveColor, icon = "media/ui/Moodle_internal_minus_green.png" },
    ["negDecrease"] = { color = negativeColor, icon = "media/ui/Moodle_internal_minus_red.png" },
    ["neutral"]     = { color = neutralColor, icon = nil }
}


---===========================================---
--        MULTIPURPOSE CONSTANTS FOR HFO       --
---===========================================---

-- Suffixes used to dynamically rename weapons based on variant type
HFO.Constants.SuffixMappings = {
    { swaptype = "_Extended_Melee", suffix = " [Melee Extended]" },
    { swaptype = "_Folded_Melee",   suffix = " [Melee Folded]"   },
    { swaptype = "_GripExtended",   suffix = " [Grip & Extended]"},
    { swaptype = "_Melee",          suffix = " [Melee]"          },
    { swaptype = "_Bipod",          suffix = " [Bipod]"          },
    { swaptype = "_Grip",           suffix = " [Grip]"           },
    { swaptype = "_Extended",       suffix = " [Extended]"       },
    { swaptype = "_Folded",         suffix = " [Folded]"         },
}

-- Weapon part check used to transfer attachments during weapon swaps
HFO.Constants.WeaponAttachmentParts = {
    { get = "getScope",     attach = "attachWeaponPart", partType = "scope" },
    { get = "getSling",     attach = "attachWeaponPart", partType = "sling" },
    { get = "getCanon",     attach = "attachWeaponPart", partType = "canon" },
    { get = "getStock",     attach = "attachWeaponPart", partType = "stock" },
    { get = "getRecoilpad", attach = "attachWeaponPart", partType = "recoilpad" },
    { get = "getClip",      attach = "attachWeaponPart", partType = "clip" },
}

-- Light settings by power level
HFO.Constants.LightLevels = {
    none   = { distance = 0,  strength = 0.0 },
    low    = { distance = 8,  strength = 1.5 },
    medium = { distance = 10, strength = 1.2 },
    high   = { distance = 15, strength = 1.0 }
}

-- Stock-based mapping for attached light behavior base on specific items
HFO.Constants.LightSettingsByStock = {
    LaserRed        = "medium",
    LaserGreen      = "medium",
    LaserNoLight    = "medium",
    WeaponLight     = "high",
    WeaponLightMedium = "low",
    GunLight        = "low",
}

-- Recoil delay adjustments and aim penalties per firemode type
HFO.Constants.FiremodeAdjustments = {
    Single     = { adjust = 0,  min = 9 },
    FullAuto   = { adjust = -4, min = 8 },
    SMGFullAuto = { adjust = -3, min = 7 },
    CustomBurst = { adjust = -6, min = 0 },
    SMGBurst    = { adjust = -6, min = 0 }
}

-- Burst-specific firing logic
HFO.Constants.BurstModes = {
    CustomBurst = 3,
    SMGBurst    = 3
}

-- Delay between bursts (in ticks/frames)
HFO.Constants.BurstDelays = {
    CustomBurst = 20,
    SMGBurst    = 18
}

-- Recoil recovery stages during burst fire
HFO.Constants.BurstSpeedStages = {
    CustomBurst = { 2.0, 5.0, 8.0 },
    SMGBurst    = { 5.0, 7.0, 8.0 }
}

HFO.Constants.SuppressorLevels = {
    SuppressorPistol = {
        volume = sv.PistolSuppressionLevels or 30,
        radius = sv.PistolSuppressionLevels or 30,
        swing  = "SuppressorPistol"
    },
    SuppressorRifle = {
        volume = sv.RifleSuppressionLevels or 40,
        radius = sv.RifleSuppressionLevels or 40,
        swing  = "SuppressorRifle"
    },
    SuppressorSniper = {
        volume = sv.SniperSuppressionLevels or 50,
        radius = sv.SniperSuppressionLevels or 50,
        swing  = "SuppressorSniper"
    }
}

-- Ammo-specific stat overrides still being configured
HFO.Constants.AmmoProperties = {
    ["Base.223Bullets"]            = { damage = 0.2, recoil = -10, penetration = 0, range = 0.6, weight = 0.005, stoppingPower = 0 },
    ["Base.556Bullets"]            = { weight = 0.005 },
    ["Base.308Bullets"]            = { weight = 0.015 },
    ["Base.762x51Bullets"]         = { weight = 0.01 },
    ["Base.ShotgunShells"]         = { weight = 0.04 },
    ["Base.ShotgunShellsBirdShot"] = { weight = 0.04 },
    ["Base.ShotgunShellsSlugs"]    = { weight = 0.04 },
    ["Base.CrossbowBolt"]          = { weight = 0.01 },
    ["Base.WoodCrossbowBolt"]      = { weight = 0.01 }
}

---===========================================---
--    ALL HFO SPECIFIC LOOT SPOTS FOR DISTRO   --
---===========================================---

HFO.Constants.LootLocations = {
    FirearmsAccessoriesExtended = {
        "FirearmWeapons", "GarageFirearms", "GunStoreCounter",
        "GunStoreDisplayCase","PoliceStorageGuns", "PoliceEvidence", 
        "ArmyStorageGuns", "PawnShopGuns", "PawnShopGunsSpecial",
    },
    AmmoandMags = {
        "ArmyStorageAmmunition", "ArmyStorageGuns", "DrugLabGuns",
        "FirearmWeapons", "GunStoreAmmunition", "GunStoreCounter", 
        "GunStoreDisplayCase", "GunStoreShelf", "PawnShopGunsSpecial",
        "PoliceStorageAmmunition", "PoliceStorageGuns",
    },
    FirearmSkins = {
        "PawnShopGunsSpecial", "PawnShopCases", "ArmyHangarTools",
        "GunStoreDisplayCase", "GarageFirearms", "PlankStashMisc",
    },
    Mechanics = {
        "GunStoreCounter", "GunStoreDisplayCase", "GunStoreShelf",
        "PoliceStorageGuns", "ArmyStorageGuns", "ArmySurplusTools",
        "PlankStashMisc", "PoliceEvidence", "GarageFirearms",
        "Hunter", "PawnShopGunsSpecial", "SurvivalGear", "Trapper",
    },
    CacheandCases = {
        "ArmyHangarTools", "ArmyStorageGuns", "GarageFirearms",
        "GunStoreDisplayCase", "GunStoreShelf", "PawnShopGunsSpecial", 
        "PawnShopCases", "PlankStashMisc", "PoliceEvidence",
    },
    Magazines = {
        "BookstoreBooks", "BookstoreMisc", "CrateMagazines", "CrateBooks", 
        "GunStoreMagazineRack", "LibraryBooks", "MagazineRackMixed", "PostOfficeMagazines", 
    },
}


---===========================================---
--   ONE SINGLE SOURCE OF TRUTH FOR ALL ITEMS  --
---===========================================---

HFO.Constants.Items = {
    Firearms = {
        Handguns = {
            Base = { "Pistol", "Pistol2", "Pistol3", "Revolver_Short", "Revolver_Long", "Revolver" },
            HFE = {"Glock", "FiveSeven", "Luger", "WaltherPPK", "Makarov", "Derringer", "PLR16", "MosinNagantObrez", 
                "SIGSauer", "JenningsJ22",  "RugerGP100", "HighStandardSentinel" },
            ColtCavalry = { "ColtCavalryRevolver" }, 
        },
        SMGs = {
            Base = {},
            HFE = { "AK74U", "FranchiLF57", "MiniUzi", "P90", "PM63RAK", "MP28", "ThompsonM1921" },
        },
        Rifles = {
            Base = { "VarmintRifle", "HuntingRifle", "AssaultRifle", "AssaultRifle2" },
            HFE = { "AK103", "AK74", "HenryRepeatingBigBoy", "BrowningBLR", "Marlin39A", "GrozaOTs14",
                "M1918BAR", "M1Garand", "SIG550", "StG44", "M4A1", "L2A1", "EM2", "L85A1", "ASVal", "Ruger1022" }, 
            FGMG = { "FG42", "MG42" },
        },
        Snipers = {
            Base = {},
            HFE = { "MosinNagant", "BarrettM82A1", "McMillanTAC50", "SVDDragunov", "Galil", "VSSVintorez" },
        },
        Shotguns = {
            Base = {"Shotgun", "DoubleBarrelShotgun" },
            HFE = { "Remington1100", "Mossberg500", "Chiappa1887", "TrenchGun", "BeckerRevolver" },
        },
        Other = {
            Base = {},
            HFE = { "CrossbowCompound", "CrossbowReverseDraw", "CrossbowPistol", "TheNailGun", "FlintlockPistol",
             "Springfield1861", "Blunderbuss", "PneumaticBlowgun" },
            TShirt = { "TShirtLauncher" },
        },
    },

    Ammo = {
        Handguns = {
            Base = { "Bullets9mm", "Bullets45", "Bullets44", "Bullets38" },
            HFE = {"22Bullets", "380Bullets", "57Bullets" },
        },
        Rifles = {
            Base = { "223Bullets", "308Bullets", "556Bullets" },
            HFE = { "3006Bullets", "545Bullets", "762Bullets", "762x51Bullets", "762x54rBullets", "792x33Bullets", "50BMGBullets", "9x39Bullets" },
            FGMG = { "792Bullets" },
        },
        Shotguns = {
            Base = { "ShotgunShells" },
            HFE = { "ShotgunShellsBirdshot", "ShotgunShellsSlug" },
        },
        Other = { 
            Base = { },
            HFE = { "CrossbowBolt", "WoodCrossbowBolt", "MinieBall", "BlunderbussBullets", "BlowgunDart" },
        },
    },

    AmmoBox = {
        Handguns = {
            Base = { "Bullets9mmBox", "Bullets45Box", "Bullets44Box", "Bullets38Box" },
            HFE = { "22Box", "380Box", "57Box" },
        },
        Rifles = {
            Base = { "223Box", "308Box", "556Box" },
            HFE = { "3006Box", "545Box", "762Box", "762x51Box", "762x54rBox", "792x33Box", "50BMGBox", "9x39Box" },
            FGMG = { "792Box" },
        },
        Shotguns = {
            Base = { "ShotgunShellsBox" },
            HFE = { "ShotgunShellsBirdshotBox", "ShotgunShellsSlugBox" },
        },
        Other = { 
            Base = { },
            HFE = { "CrossbowBoltBox", "WoodCrossbowBoltBox", "MinieBallBox", "BlunderbussBulletsBox", "BlowgunDartBox" },
        },
    },

    AmmoMags = {
        Handguns = {
            Base = { "9mmClip", "45Clip", "44Clip" },
            HFE = { "22Clip", "380Clip", "57Clip", "9mmBoxClip", "9mmClip8", "9mmClip32", "45Clip13", "223Clip10" },
        },
        Rifles = {
            Base = { "223Clip", "308Clip", "M14Clip", "556Clip" },
            HFE = { "22Clip10","3006BlocClip", "3006Clip", "545Clip", "P90Clip", "762Clip", "762x51Clip", "762x54rClip",
                 "762x54rStripperClip", "792x33Clip", "50BMGClip", "9x39Clip" , "45Clip20", "9x39Clip20", "762x51Clip20", "762x51Clip30" },
            FGMG = { "792Clip", "792Drum" },
        },
        Other = { 
            Base = { },
            HFE = { "TheNailGunClip", "AmmoCanUnopened" },
        },
    },

    Accessories = {
        Suppressors = {
            Base = {},
            HFE = {"SuppressorPistol", "SuppressorRifle", "SuppressorSniper", "SuppressorSniperWinter", 
                    "SuppressorSniperDesert", "SuppressorSniperWoodland" },
        },
        Scopes = {
            Base = { "IronSight", "x2Scope", "x4Scope", "x8Scope", "RedDot" },
            HFE = { "PEMScope", "PSO1Scope", "UniversalOpticalSight", "HoloSight", "ReflexSight", "ProOpticScope", "CarryHandle" },
            FGMG = {"IronSightsFG42", "ScopeFG42"},    
        },
        Other = {
            Base = { "ChokeTubeFull", "ChokeTubeImproved", "Bayonnet", "BayonetImprovised", "GunLight", "Laser", "AmmoStraps", 
                "Sling", "FiberglassStock", "RecoilPad" },
            HFE = { "Compensator", "MuzzleBrake", "CompensatorHandgun", "MuzzleBrakeHandgun", "VertGrip", "AngleGrip", 
                "TacticalGrip", "SkeletonizedStock", "LaserNoLight", "WeaponLight", "WeaponLightMedium", "ShellHolder", "ButtStockWrap" },
        },
    },

    FirearmSkins = {
        Base = {},
        HFE = { "GunPlatingTan", "GunPlatingBlue", "GunPlatingRed", "GunPlatingGold", "GunPlatingPatriot", "GunPlatingRainbow", "GunPlatingDZ", "GunPlatingDarkCherry", "GunPlatingWinterCamo",
                "GunPlatingMatteBlack", "GunPlatingWoodStyle", "GunPlatingPink", "GunPlatingRedWhite", "GunPlatingGreenGold", "GunPlatingAztec", "GunPlatingYellow", "GunPlatingPearl" },
        Exclusive = { "GunPlatingGoldDE", "GunPlatingGoldShotgun", "GunPlatingRainbowAnodized", "GunPlatingGreen", "GunPlatingSteelDamascus", 
                "GunPlatingSalvagedRage", "GunPlatingZoidbergSpecial", "GunPlatingShenron", "GunPlatingNerf", "GunPlatingBespokeEngraved", "GunPlatingSurvivalist", 
                "GunPlatingMysteryMachine", "GunPlatingSalvagedBlack", "GunPlatingPlank", "GunPlatingBlackIce", "GunPlatingBlackDeath",
                "GunPlatingOrnateIvory", "GunPlatingGildedAge", "GunPlatingTBD", "GunPlatingCannabis" },
    },

    Extended = {
        Base = {},
        HFE = {},
        ExtendedSmall = { "Mag22ExtSm", "Mag9ExtSm", "MagLugerExtSm", "Mag380ExtSm", "Mag44ExtSm", "Mag45ExtSm", "MagMosinNagantExtSm",
                        "MagM1GarandExtSm", "Mag308ExtSm", "MagSVDExtSm", "Mag50BMGExtSm", "Mag762x51ExtSm", "Mag9x39ExtSm" },
        ExtendedLarge = { "Mag22ExtLg", "Mag9ExtLg", "Mag57ExtLg", "MagLugerExtLg", "Mag380ExtLg", "Mag44ExtLg", "Mag45ExtLg", 
                        "Mag223ExtLg", "MagPM63RAKExtLg", "Mag3006ExtLg", "MagMP28ExtLg", "Mag9x39ExtLg", "Mag762x51ExtLg" },
        ExtendedDrum = {  "Mag9Drum", "Mag57Drum", "MagLugerDrum", "Mag380Drum", "Mag45Drum",  },
        SpeedLoaders = { "22SpeedLoader", "38SpeedLoader5", "38SpeedLoader7", "44SpeedLoader", "45SpeedLoader" },
    },

    Mechanics = {
        RepairKits = {
            Base = { "FirearmRepairKit" },
            HFE = {},
        },
        Cleaning = {
            Base = { "FirearmLubricant", "FirearmCleaningKit" },
            HFE = {},
        },
    },

    SpecialItems = {
        FirearmCache = {
            Base = {},
            HFE = { "FirearmCache" },
        },
        Magazines = {
            Base = {},
            HFE = {},
            FGMG = { "FG42RifleItemsMagazine" },
            Crossbow = { "CompoundCrossbowMagazine" },
        },
        RifleCases = {
            Base = { "RifleCase1", "RifleCase2", "RifleCase3" },
            HFE = {},
        },
        ShotgunCases = {
            Base = { "ShotgunCase1", "ShotgunCase2" },
            HFE = {},
        },
        PistolCases = {
            Base = { "PistolCase1", "PistolCase2", "PistolCase3" },
            HFE = {},
        },
        RevolverCases = {
            Base = { "RevolverCase1", "RevolverCase2", "RevolverCase3" },
            HFE = {},
        }
    }
}