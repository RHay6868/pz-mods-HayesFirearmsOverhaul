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
    Pistol = {"CompensatorHandgun", "MuzzleBrakeHandgun", "GunLight"},
    Pistol2 = {"CompensatorHandgun", "MuzzleBrakeHandgun", "RedDot"},
    Pistol3 = {"CompensatorHandgun", "MuzzleBrakeHandgun", "PistolScope"},
    Revolver_Short = {"TacticalGrip", "RedDot", "IronSight"},
    Revolver = {"TacticalGrip", "RedDot", "IronSight"},
    Revolver_Long = {"TacticalGrip", "RedDot", "PistolScope"},
    VarmintRifle = {"x2Scope", "x4Scope", "ProOpticScope", "PEMScope", "RecoilPad", "ButtStockWrap"},
    HuntingRifle = {"x2Scope", "x4Scope", "x8Scope", "ACOG", "PEMScope",  "RecoilPad", "ButtStockWrap"},
    AssaultRifle = {"AngleGrip", "x2Scope", "ACOG", "HoloSight", "ReflexSight", "CarryHandle", "MuzzleBrake", "Compensator"},
    AssaultRifle2 = {"x4Scope", "x8Scope", "ProOpticScope", "PEMScope", "Bayonnet", "BayonetImprovised", "ButtStockWrap"},
    Shotgun = {"VertGrip", "ChokeTubeFull", "ChokeTubeImproved", "ShellHolder"},
    DoubleBarrelShotgun = {"VertGrip", "ShellHolder", "RecoilPad"},
}

if getActivatedMods():contains("HayesFirearmsExtensionDEVTEST") then
    WeaponUpgrades["Glock"] = {"CompensatorHandgun", "MuzzleBrakeHandgun", "PistolScope", "WeaponLightMedium"}
    WeaponUpgrades["FiveSeven"] = {"CompensatorHandgun", "MuzzleBrakeHandgun", "PistolScope", "WeaponLightMedium"}
    WeaponUpgrades["Luger"] = {"CompensatorHandgun", "MuzzleBrakeHandgun", "TacticalGrip"}
    WeaponUpgrades["WaltherPPK"] = {"CompensatorHandgun", "MuzzleBrakeHandgun", "TacticalGrip"}
    WeaponUpgrades["Makarov"] = {"CompensatorHandgun", "MuzzleBrakeHandgun", "TacticalGrip"}
    WeaponUpgrades["SIGSauer"] = {"CompensatorHandgun", "MuzzleBrakeHandgun", "PistolScope", "WeaponLightMedium"}
    WeaponUpgrades["JenningsJ22"] = {"CompensatorHandgun", "MuzzleBrakeHandgun", "TacticalGrip"}
    WeaponUpgrades["Derringer"] = {"TacticalGrip"}
    WeaponUpgrades["PLR16"] = {"CompensatorHandgun", "MuzzleBrakeHandgun", "ACOG", "x2Scope"}
    WeaponUpgrades["MosinNagantObrez"] = {"x2Scope", "PEMScope", "WeaponLightMedium"}
    WeaponUpgrades["OA93"] = {"Compensator", "MuzzleBrake", "ACOG", "ReflexSight"}
    WeaponUpgrades["TheNailGun"] = {"GunLight", "Laser"}   
    WeaponUpgrades["ColtCavalryRevolver"] = {"TacticalGrip", "RedDot", "IronSight"}
    WeaponUpgrades["RugerGP100"] = {"TacticalGrip", "RedDot", "PistolScope"}
    WeaponUpgrades["HighStandardSentinel"] = {"TacticalGrip", "RedDot"}
    WeaponUpgrades["CrossbowCompound"] = {"x2Scope", "ProOpticScope", "HoloSight", "WeaponLight", "LaserNoLight"}
    WeaponUpgrades["CrossbowReverseDraw"] = {"x2Scope", "ACOG", "ReflexSight", "RecoilPad"}
    WeaponUpgrades["CrossbowPistol"] = {"LaserNoLight", "WeaponLight"}
    WeaponUpgrades["AK74U"] = {"x2Scope", "ProOpticScope", "HoloSight", "Compensator", "WeaponLightMedium"}
    WeaponUpgrades["FranchiLF57"] = {"PistolScope", "ReflexSight", "Laser"}
    WeaponUpgrades["MiniUzi"] = {"HoloSight", "ReflexSight", "Laser"}
    WeaponUpgrades["P90"] = {"ACOG", "ReflexSight", "Laser"}
    WeaponUpgrades["PM63RAK"] = {"HoloSight", "ReflexSight", "RedDot"}
    WeaponUpgrades["MP28"] = {"HoloSight", "LaserNoLight"}
    WeaponUpgrades["ThompsonM1921"] = {"WeaponLight", "LaserNoLight"}
    WeaponUpgrades["AK103"] = {"x2Scope", "BayonetImprovised", "ACOG", "PEMScope", "UniversalOpticalSight", "Compensator"}
    WeaponUpgrades["AK74"] = {"BayonetImprovised", "x4Scope", "ProOpticScope", "PEMScope", "UniversalOpticalSight", "MuzzleBrake"}
    WeaponUpgrades["HenryRepeatingBigBoy"] = {"x2Scope", "x4Scope", "PEMScope", "RecoilPad", "ButtStockWrap"}
    WeaponUpgrades["BrowningBLR"] = {"x4Scope", "ACOG", "WeaponLightMedium", "RecoilPad", "ButtStockWrap"}
    WeaponUpgrades["Marlin39A"] = {"x8Scope", "x4Scope", "RecoilPad", "UniversalOpticalSight", "Compensator", "ButtStockWrap"}
    WeaponUpgrades["GrozaOTs14"] = {"x2Scope", "x4Scope", "ACOG", "ReflexSight", "WeaponLightMedium", "LaserNoLight"}
    WeaponUpgrades["M1918BAR"] = {"HoloSight", "ReflexSight", "RecoilPad"}
    WeaponUpgrades["M1Garand"] = {"x4Scope", "ProOpticScope", "BayonetImprovised", "RecoilPad", "ButtStockWrap"}
    WeaponUpgrades["SIG550"] = {"AngleGrip", "x2Scope", "x4Scope", "ACOG", "PSO1Scope", "Compensator", "WeaponLight"}
    WeaponUpgrades["StG44"] = {"x4Scope", "ProOpticScope", "PEMScope", "MuzzleBrake"}
    WeaponUpgrades["MosinNagant"] = {"x4Scope", "x8Scope", "PSO1Scope", "UniversalOpticalSight", "Bayonnet", "BayonetImprovised"}
    WeaponUpgrades["L2A1"] = {"ACOG", "HoloSight", "MuzzleBrake", "WeaponLightMedium"}    
    WeaponUpgrades["EM2"] = {"UniversalOpticalSight", "WeaponLightMedium", "BayonetImprovised"}
    WeaponUpgrades["L85A1"] = {"AngleGrip", "UniversalOpticalSight",  "CarryHandle", "WeaponLightMedium", "LaserNoLight"}
    WeaponUpgrades["ASVal"] = {"ProOpticScope", "PSO1Scope", "ACOG", "WeaponLight"}
    WeaponUpgrades["M4A1"] = {"AngleGrip", "x2Scope", "ACOG",  "ProOpticScope", "PEMScope",  "CarryHandle"}
    WeaponUpgrades["FG42"] = {"ScopeFG42", "IronSightsFG42"}
    WeaponUpgrades["Ruger1022"] = {"ACOG", "WeaponLight", "x4Scope", "PSO1Scope"}
    WeaponUpgrades["BarrettM82A1"] = {"x4Scope", "x8Scope", "ProOpticScope", "PEMScope", "WeaponLight"}
    WeaponUpgrades["PGMHecate"] = {"x4Scope", "x8Scope", "PEMScope", "RecoilPad", "ButtStockWrap"}
    WeaponUpgrades["SVDDragunov"] = {"x4Scope", "x8Scope", "ACOG", "PEMScope", "MuzzleBrake", "ButtStockWrap" }
    WeaponUpgrades["Galil"] = {"x4Scope", "PSO1Scope", "WeaponLight",  "RecoilPad"}
    WeaponUpgrades["VSSVintorez"] = {"x4Scope", "PSO1Scope", "WeaponLight", "LaserNoLight"}
    WeaponUpgrades["Remington1100"] = {"VertGrip", "HoloSight", "ShellHolder"}
    WeaponUpgrades["Mossberg500"] = {"VertGrip", "ReflexSight", "ShellHolder", "RecoilPad"}
    WeaponUpgrades["Chiappa1887"] = {"HoloSight", "ReflexSight", "ShellHolder"}
    WeaponUpgrades["TrenchGun"] = {"VertGrip", "BayonetImprovised", "ShellHolder", "RecoilPad"}
    WeaponUpgrades["BeckerRevolver"] = {"VertGrip", "ShellHolder", "RecoilPad"}
    WeaponUpgrades["FlintlockPistol"] = {"WeaponLightMedium"}
    WeaponUpgrades["Springfield1861"] = {"x4Scope","Bayonnet", "BayonetImprovised", "UniversalOpticalSight", "RecoilPad"}
    WeaponUpgrades["Blunderbuss"] = {"VertGrip", "WeaponLight"}
    WeaponUpgrades["PneumaticBlowgun"] = {"LaserNoLight", "WeaponLight"}
end 