--============================================================--
--                 HFO_WeaponPreAttachList.lua                --
--============================================================--
-- Purpose:
--   Defines valid attachments that may be pre-equipped on weapons
--   when they spawn in the world. Supports HFO-specific and HFE sub mod
--
-- Overview:
--   - Used primarily to seed attachments at spawn or loot time.
--   - Categorized by weapon ID with corresponding upgrade options.
--
-- Notes:
--   - Simple config table, no logic beyond conditional extension check.
--============================================================--

WeaponUpgrades = {
    Pistol = {"CompensatorHandgun", "MuzzleBrakeHandgun", "TacticalGrip", "GunLight", "RedDot", "IronSight", "Laser"},
    Pistol2 = {"CompensatorHandgun", "MuzzleBrakeHandgun", "TacticalGrip", "GunLight", "RedDot", "IronSight", "Laser"},
    Pistol3 = {"CompensatorHandgun", "MuzzleBrakeHandgun", "TacticalGrip", "GunLight", "RedDot", "IronSight", "Laser"},
    Revolver_Short = {"TacticalGrip", "RedDot", "IronSight"},
    Revolver = {"TacticalGrip", "RedDot", "IronSight"},
    Revolver_Long = {"TacticalGrip", "RedDot", "IronSight"},
    VarmintRifle = {"x2Scope", "x4Scope", "x8Scope", "ProOpticScope", "PEMScope", "HoloSight", "ReflexSight", "RecoilPad", "ButtStockWrap", "RemingtonRiflesDarkCherryStock"},
    HuntingRifle = {"x2Scope", "x4Scope", "x8Scope", "ProOpticScope", "PEMScope", "HoloSight", "ReflexSight", "RecoilPad", "ButtStockWrap", "RemingtonRiflesDarkCherryStock"},
    AssaultRifle = {"VertGrip", "AngleGrip", "x2Scope", "x4Scope", "ProOpticScope", "PEMScope", "HoloSight", "ReflexSight", "CarryHandle", "MuzzleBrake", "Compensator"},
    AssaultRifle2 = {"x2Scope", "x4Scope", "x8Scope", "ProOpticScope", "PEMScope", "HoloSight", "ReflexSight", "Bayonnet", "BayonetImprovised", "ButtStockWrap"},
    Shotgun = {"VertGrip", "ChokeTubeFull", "ChokeTubeImproved"},
    ShotgunSawnoff = {"VertGrip", "ChokeTubeFull", "ChokeTubeImproved"}
}

if getActivatedMods():contains("HayesFirearmsExtensionDEVTEST") then
    WeaponUpgrades["Glock"] = {"CompensatorHandgun", "MuzzleBrakeHandgun", "TacticalGrip", "GunLight", "RedDot", "IronSight", "Laser", "WeaponLightMedium"}
    WeaponUpgrades["FiveSeven"] = {"CompensatorHandgun", "MuzzleBrakeHandgun", "TacticalGrip", "GunLight", "RedDot", "IronSight", "Laser", "WeaponLightMedium"}
    WeaponUpgrades["Luger"] = {"CompensatorHandgun", "MuzzleBrakeHandgun", "TacticalGrip"}
    WeaponUpgrades["WaltherPPK"] = {"CompensatorHandgun", "MuzzleBrakeHandgun", "TacticalGrip"}
    WeaponUpgrades["Makarov"] = {"CompensatorHandgun", "MuzzleBrakeHandgun", "TacticalGrip"}
    WeaponUpgrades["Derringer"] = {"TacticalGrip"}
    WeaponUpgrades["PLR16"] = {"CompensatorHandgun", "MuzzleBrakeHandgun", "TacticalGrip", "x2Scope", "HoloSight", "ReflexSight", "WeaponLightMedium", "LaserNoLight"}
    WeaponUpgrades["MosinNagantObrez"] = {"x2Scope", "PEMScope", "HoloSight", "ReflexSight", "WeaponLightMedium", "LaserNoLight"}
    WeaponUpgrades["OA93"] = {"Compensator", "MuzzleBrake", "HoloSight", "ReflexSight"}
    WeaponUpgrades["TheNailGun"] = {"GunLight", "Laser"}   
    WeaponUpgrades["AK74U"] = {"x2Scope", "x4Scope", "ProOpticScope", "HoloSight", "ReflexSight", "MuzzleBrake", "Compensator", "WeaponLightMedium", "LaserNoLight"}
    WeaponUpgrades["FranchiLF57"] = {"HoloSight", "ReflexSight", "GunLight", "RedDot", "IronSight", "Laser"}
    WeaponUpgrades["MiniUzi"] = {"HoloSight", "ReflexSight", "GunLight", "RedDot", "IronSight", "Laser"}
    WeaponUpgrades["P90"] = {"ReflexSight", "GunLight", "Laser"}
    WeaponUpgrades["PM63RAK"] = {"HoloSight", "ReflexSight", "RedDot"}
    WeaponUpgrades["MP28"] = {"HoloSight", "WeaponLight", "LaserNoLight"}
    WeaponUpgrades["AK103"] = {"x2Scope", "x4Scope", "ProOpticScope", "PEMScope", "PSO1Scope", "UniversalOpticalSight", "HoloSight", "ReflexSight", "MuzzleBrake", "Compensator"}
    WeaponUpgrades["AK74"] = {"x2Scope", "x4Scope", "ProOpticScope", "PEMScope", "PSO1Scope", "UniversalOpticalSight", "HoloSight", "ReflexSight", "MuzzleBrake", "Compensator"}
    WeaponUpgrades["HenryRepeatingBigBoy"] = {"x2Scope", "x4Scope", "ProOpticScope", "PEMScope", "HoloSight", "ReflexSight", "MuzzleBrake", "Compensator", "WeaponLight", "LaserNoLight"}
    WeaponUpgrades["GrozaOTs14"] = {"x2Scope", "x4Scope", "HoloSight", "ReflexSight", "WeaponLightMedium", "LaserNoLight"}
    WeaponUpgrades["M1918BAR"] = {"HoloSight", "ReflexSight", "RecoilPad"}
    WeaponUpgrades["M1Garand"] = {"x2Scope", "x4Scope", "ProOpticScope", "HoloSight", "ReflexSight", "BayonetImprovised", "RecoilPad"}
    WeaponUpgrades["SIG550"] = {"VertGrip", "AngleGrip", "x2Scope", "x4Scope", "ProOpticScope", "PEMScope", "PSO1Scope", "HoloSight", "ReflexSight", "MuzzleBrake", "Compensator", "WeaponLight", "LaserNoLight"}
    WeaponUpgrades["StG44"] = {"x2Scope", "x4Scope", "ProOpticScope", "PEMScope", "HoloSight", "ReflexSight", "MuzzleBrake", "Compensator"}
    WeaponUpgrades["MosinNagant"] = {"x2Scope", "x4Scope", "x8Scope", "ProOpticScope", "PEMScope", "PSO1Scope", "UniversalOpticalSight", "HoloSight", "ReflexSight", "Bayonnet", "BayonetImprovised"}
    WeaponUpgrades["L2A1"] = {"ProOpticScope", "HoloSight", "ReflexSight", "WeaponLightMedium"}    
    WeaponUpgrades["EM2"] = {"UniversalOpticalSight", "HoloSight", "ReflexSight", "WeaponLightMedium", "BayonetImprovised"}
    WeaponUpgrades["L85A1"] = {"VertGrip", "AngleGrip", "UniversalOpticalSight", "HoloSight", "ReflexSight", "CarryHandle", "WeaponLightMedium", "LaserNoLight"}
    WeaponUpgrades["ASVal"] = {"ProOpticScope", "PSO1Scope", "PEMScope", "WeaponLight", "LaserNoLight"}
    WeaponUpgrades["BarrettM82A1"] = {"x4Scope", "x8Scope", "ProOpticScope", "PEMScope"}
    WeaponUpgrades["SVDDragunov"] = {"x2Scope", "x4Scope", "x8Scope", "ProOpticScope", "PEMScope", "MuzzleBrake", "Compensator", "ButtStockWrap" }
    WeaponUpgrades["Galil"] = {"x4Scope", "x8Scope", "PSO1Scope", "PEMScope", "MuzzleBrake", "Compensator", "WeaponLight", "LaserNoLight", "RecoilPad"}
    WeaponUpgrades["VSSVintorez"] = {"x4Scope", "PSO1Scope", "PEMScope", "WeaponLight", "LaserNoLight"}
    WeaponUpgrades["Remington1100"] = {"VertGrip", "HoloSight", "ReflexSight"}
    WeaponUpgrades["TrenchGun"] = {"VertGrip", "BayonetImprovised"}
    WeaponUpgrades["FG42"] = {"ScopeFG42", "IronSightsFG42"}
    WeaponUpgrades["M4A1"] = {"VertGrip", "AngleGrip", "x2Scope", "x4Scope", "ProOpticScope", "PEMScope", "HoloSight", "ReflexSight", "CarryHandle", "MuzzleBrake", "Compensator"}
    WeaponUpgrades["ColtCavalryRevolver"] = {"TacticalGrip", "RedDot", "IronSight"}
    WeaponUpgrades["CrossbowCompound"] = {"x2Scope", "ProOpticScope", "HoloSight", "ReflexSight", "WeaponLight", "LaserNoLight"}
end 