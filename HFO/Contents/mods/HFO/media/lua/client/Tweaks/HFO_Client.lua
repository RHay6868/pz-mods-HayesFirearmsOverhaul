--============================================================--
--                      HFO_Client.lua                        --
--============================================================--
-- Purpose:
--   Client-side logic to dynamically swap firearm models based on weapon 
--   configuration. Drives visual representation of plating, attachments, 
--   and magazine states without affecting gameplay stats.
--
-- Overview:
--   Uses bikinihorst's BGunTweaker (BWTweaks) framework to register and update
--   visual model variants. Ensures firearms reflect correct visuals for:
--   - Equipped attachments (stocks, suppressors, chokes, etc.)
--   - Plating/cosmetic finishes (gold, polymer, painted, camo, etc.)
--   - Presence or absence of magazines or extended mags
--
-- Features:
--   - Supports visual model swap based on combined weapon states
--   - Tracks magazine presence and type for accurate display
--   - Applies special model overrides for plating and stock states
--   - Integrates cleanly with all HFO modular weapons
--
-- Responsibilities:
--   - Register weapon configurations with BWTweaks
--   - Apply correct model variant during OnEquip / OnUpdate cycles
--   - Fallback to default model if conflicts or undefined states arise
--
-- Dependencies:
--   - HFO_Utils (for weapon data and helper functions)
--   - HFO_Constants (for consistent model paths and definitions)
--   - BGunTweaker mod (external mod dependency)
--
-- Notes:
--   - Runs only on client (visual only, no stat impact)
--   - Avoids processing on non-player characters
--
-- WARNING:
--   Extremely verbose logic and large data tables live here. Avoid editing unless 
--   you are confident about the implications across all supported firearm variations.
--============================================================--


require "BGunTweaker";

-- Code allows for model swapping based on a bunch of parameters, 
-- all made possible by bikinihorst, thank you as always for the fantastic code

Events.OnGameStart.Add(function()

    ---===========================================---
    --          MAGAZINE ONLY MODEL SWAPS          --
    ---===========================================---

    local magChange = {
        { fullType = "Base.Pistol", modelWithMag = "Handgun03", modelWithoutMag = "Handgun03NoMag" },
        { fullType = "Base.Pistol2", modelWithMag = "Handgun02", modelWithoutMag = "Handgun02NoMag" },
        { fullType = "Base.Pistol3", modelWithMag = "Handgun", modelWithoutMag = "HandgunNoMag" },
        { fullType = "Base.VarmintRifle", modelWithMag = "VarmintRifleExtMag", modelWithoutMag = "VarmintRifle" },
        { fullType = "Base.VarmintRifle_Melee", modelWithMag = "VarmintRifleExtMag", modelWithoutMag = "VarmintRifle" },
        { fullType = "Base.HuntingRifle", modelWithMag = "HuntingRifle", modelWithoutMag = "HuntingRifleNoMag" },
        { fullType = "Base.HuntingRifle_Melee", modelWithMag = "HuntingRifle", modelWithoutMag = "HuntingRifleNoMag" },
        { fullType = "Base.AssaultRifle", modelWithMag = "AssaultRifle", modelWithoutMag = "AssaultRifleNoMag" },
        { fullType = "Base.AssaultRifle_Melee", modelWithMag = "AssaultRifle", modelWithoutMag = "AssaultRifleNoMag" },
        { fullType = "Base.AssaultRifle2", modelWithMag = "AssaultRifle02", modelWithoutMag = "AssaultRifle02NoMag" },
        { fullType = "Base.AssaultRifle2_Melee", modelWithMag = "AssaultRifle02", modelWithoutMag = "AssaultRifle02NoMag" },
        { fullType = "Base.Glock", modelWithMag = "Glock", modelWithoutMag = "GlockNoMag" },
        { fullType = "Base.FiveSeven", modelWithMag = "FiveSeven", modelWithoutMag = "FiveSevenNoMag" },
        { fullType = "Base.Luger", modelWithMag = "Luger", modelWithoutMag = "LugerNoMag" },
        { fullType = "Base.WaltherPPK", modelWithMag = "WaltherPPK", modelWithoutMag = "WaltherPPKNoMag" },
        { fullType = "Base.Makarov", modelWithMag = "Makarov", modelWithoutMag = "MakarovNoMag" },
        { fullType = "Base.SIGSauer", modelWithMag = "SIGSauer", modelWithoutMag = "SIGSauerNoMag" },
        { fullType = "Base.JenningsJ22", modelWithMag = "JenningsJ22", modelWithoutMag = "JenningsJ22NoMag" },
        { fullType = "Base.PLR16", modelWithMag = "PLR16", modelWithoutMag = "PLR16NoMag" },
        { fullType = "Base.OA93", modelWithMag = "OA93", modelWithoutMag = "OA93NoMag" },
        { fullType = "Base.TheNailGun", modelWithMag = "TheNailGun", modelWithoutMag = "TheNailGunNoMag" },
        { fullType = "Base.TheNailGun_Melee", modelWithMag = "TheNailGunMelee", modelWithoutMag = "TheNailGunNoMagMelee" },
        { fullType = "Base.AK74U", modelWithMag = "AK74U", modelWithoutMag = "AK74UNoMag" },
        { fullType = "Base.AK74U_Melee", modelWithMag = "AK74U", modelWithoutMag = "AK74UNoMag" },
        { fullType = "Base.AK74U_Folded", modelWithMag = "AK74U_Folded", modelWithoutMag = "AK74UNoMag_Folded" },
        { fullType = "Base.AK74U_Folded_Melee", modelWithMag = "AK74U_Folded", modelWithoutMag = "AK74UNoMag_Folded" },
        { fullType = "Base.FranchiLF57", modelWithMag = "FranchiLF57", modelWithoutMag = "FranchiLF57NoMag" },
        { fullType = "Base.FranchiLF57_Melee", modelWithMag = "FranchiLF57", modelWithoutMag = "FranchiLF57NoMag" },
        { fullType = "Base.FranchiLF57_Folded", modelWithMag = "FranchiLF57_Folded", modelWithoutMag = "FranchiLF57NoMag_Folded" },
        { fullType = "Base.FranchiLF57_Folded_Melee", modelWithMag = "FranchiLF57_Folded", modelWithoutMag = "FranchiLF57NoMag_Folded" },
        { fullType = "Base.MiniUzi", modelWithMag = "MiniUzi", modelWithoutMag = "MiniUziNoMag" },
        { fullType = "Base.MiniUzi_Melee", modelWithMag = "MiniUzi", modelWithoutMag = "MiniUziNoMag" },
        { fullType = "Base.MiniUzi_Folded", modelWithMag = "MiniUzi_Folded", modelWithoutMag = "MiniUziNoMag_Folded" },
        { fullType = "Base.MiniUzi_Folded_Melee", modelWithMag = "MiniUzi_Folded", modelWithoutMag = "MiniUziNoMag_Folded" },
        { fullType = "Base.P90", modelWithMag = "P90", modelWithoutMag = "P90NoMag" },
        { fullType = "Base.P90_Melee", modelWithMag = "P90", modelWithoutMag = "P90NoMag" },
        { fullType = "Base.MP28", modelWithMag = "MP28", modelWithoutMag = "MP28NoMag" },
        { fullType = "Base.MP28_Melee", modelWithMag = "MP28", modelWithoutMag = "MP28NoMag" },
        { fullType = "Base.ThompsonM1921", modelWithMag = "ThompsonM1921", modelWithoutMag = "ThompsonM1921NoMag" },
        { fullType = "Base.ThompsonM1921_Melee", modelWithMag = "ThompsonM1921", modelWithoutMag = "ThompsonM1921NoMag" },
        { fullType = "Base.AK103", modelWithMag = "AK103", modelWithoutMag = "AK103NoMag" },
        { fullType = "Base.AK103_Melee", modelWithMag = "AK103", modelWithoutMag = "AK103NoMag" },
        { fullType = "Base.AK74", modelWithMag = "AK74", modelWithoutMag = "AK74NoMag" },
        { fullType = "Base.AK74_Melee", modelWithMag = "AK74", modelWithoutMag = "AK74NoMag" },
        { fullType = "Base.BrowningBLR", modelWithMag = "BrowningBLR", modelWithoutMag = "BrowningBLRNoMag" },
        { fullType = "Base.BrowningBLR_Melee", modelWithMag = "BrowningBLR", modelWithoutMag = "BrowningBLRNoMag" },
        { fullType = "Base.GrozaOTs14", modelWithMag = "GrozaOTs14", modelWithoutMag = "GrozaOTs14NoMag" },
        { fullType = "Base.GrozaOTs14_Melee", modelWithMag = "GrozaOTs14", modelWithoutMag = "GrozaOTs14NoMag" },
        { fullType = "Base.M1918BAR", modelWithMag = "M1918BAR", modelWithoutMag = "M1918BARNoMag" },
        { fullType = "Base.M1918BAR_Bipod", modelWithMag = "M1918BARBipod", modelWithoutMag = "M1918BARBipodNoMag" },
        { fullType = "Base.M1918BAR_Melee", modelWithMag = "M1918BAR", modelWithoutMag = "M1918BARNoMag" },
        { fullType = "Base.SIG550", modelWithMag = "SIG550", modelWithoutMag = "SIG550NoMag" },
        { fullType = "Base.SIG550_Melee", modelWithMag = "SIG550", modelWithoutMag = "SIG550NoMag" },
        { fullType = "Base.StG44", modelWithMag = "StG44", modelWithoutMag = "StG44NoMag" },
        { fullType = "Base.StG44_Melee", modelWithMag = "StG44", modelWithoutMag = "StG44NoMag" },
        { fullType = "Base.SVDDragunov", modelWithMag = "SVDDragunov", modelWithoutMag = "SVDDragunovNoMag" },
        { fullType = "Base.SVDDragunov_Melee", modelWithMag = "SVDDragunov", modelWithoutMag = "SVDDragunovNoMag" },
        { fullType = "Base.BarrettM82A1", modelWithMag = "BarrettM82A1", modelWithoutMag = "BarrettM82A1NoMag" },
        { fullType = "Base.BarrettM82A1_Bipod", modelWithMag = "BarrettM82A1Bipod", modelWithoutMag = "BarrettM82A1BipodNoMag" },
        { fullType = "Base.BarrettM82A1_Melee", modelWithMag = "BarrettM82A1", modelWithoutMag = "BarrettM82A1NoMag" },
        { fullType = "Base.PGMHecate", modelWithMag = "PGMHecate", modelWithoutMag = "PGMHecateNoMag" },
        { fullType = "Base.PGMHecate_Bipod", modelWithMag = "PGMHecateBipod", modelWithoutMag = "PGMHecateBipodNoMag" },
        { fullType = "Base.PGMHecate_Melee", modelWithMag = "PGMHecate", modelWithoutMag = "PGMHecateNoMag" },
        { fullType = "Base.L2A1", modelWithMag = "L2A1", modelWithoutMag = "L2A1NoMag" },
        { fullType = "Base.L2A1_Bipod", modelWithMag = "L2A1Bipod", modelWithoutMag = "L2A1BipodNoMag" },
        { fullType = "Base.L2A1_Melee", modelWithMag = "L2A1", modelWithoutMag = "L2A1NoMag" },
        { fullType = "Base.EM2", modelWithMag = "EM2", modelWithoutMag = "EM2NoMag" },
        { fullType = "Base.EM2_Melee", modelWithMag = "EM2", modelWithoutMag = "EM2NoMag" },
        { fullType = "Base.L85A1", modelWithMag = "L85A1", modelWithoutMag = "L85A1NoMag" },
        { fullType = "Base.L85A1_Melee", modelWithMag = "L85A1", modelWithoutMag = "L85A1NoMag" },
        { fullType = "Base.ASVal", modelWithMag = "ASVal", modelWithoutMag = "ASValNoMag" },
        { fullType = "Base.ASVal_Melee", modelWithMag = "ASVal", modelWithoutMag = "ASValNoMag" },
        { fullType = "Base.ASVal_Folded", modelWithMag = "ASVal_Folded", modelWithoutMag = "ASValNoMag_Folded" },
        { fullType = "Base.ASVal_Folded_Melee", modelWithMag = "ASVal_Folded", modelWithoutMag = "ASValNoMag_Folded" },
        { fullType = "Base.Galil", modelWithMag = "Galil", modelWithoutMag = "GalilNoMag" },
        { fullType = "Base.Galil_Bipod", modelWithMag = "GalilBipod", modelWithoutMag = "GalilBipodNoMag" },
        { fullType = "Base.Galil_Melee", modelWithMag = "Galil", modelWithoutMag = "GalilNoMag" },
        { fullType = "Base.VSSVintorez", modelWithMag = "VSSVintorez", modelWithoutMag = "VSSVintorezNoMag" },
        { fullType = "Base.VSSVintorez_Melee", modelWithMag = "VSSVintorez", modelWithoutMag = "VSSVintorezNoMag" },
        { fullType = "Base.FG42", modelWithMag = "FG42", modelWithoutMag = "FG42NoMag" },
        { fullType = "Base.FG42_Bipod", modelWithMag = "FG42Bipod", modelWithoutMag = "FG42BipodNoMag" },
        { fullType = "Base.FG42_Melee", modelWithMag = "FG42", modelWithoutMag = "FG42NoMag" },
        { fullType = "Base.MG42", modelWithMag = "MG42", modelWithoutMag = "MG42NoMag" },
        { fullType = "Base.MG42_Bipod", modelWithMag = "MG42Bipod", modelWithoutMag = "MG42BipodNoMag" },
        { fullType = "Base.MG42_Melee", modelWithMag = "MG42", modelWithoutMag = "MG42NoMag" },
        { fullType = "Base.Ruger1022", modelWithMag = "Ruger1022", modelWithoutMag = "Ruger1022NoMag" },
        { fullType = "Base.Ruger1022_Melee", modelWithMag = "Ruger1022", modelWithoutMag = "Ruger1022NoMag" },
        { fullType = "Base.M4A1", modelWithMag = "M4A1", modelWithoutMag = "M4A1NoMag" },
        { fullType = "Base.M4A1_Melee", modelWithMag = "M4A1", modelWithoutMag = "M4A1NoMag" },
    }
    
    for _, change in ipairs(magChange) do
        BWTweaks:changeModelByMagPresent(change.fullType, true, change.modelWithMag)
        BWTweaks:changeModelByMagPresent(change.fullType, false, change.modelWithoutMag)
    end


    ---===========================================---
    --        EXTENDED MAGAZINE MODEL SWAPS        --
    ---===========================================---

    local extendedMagChange = {
        { fullType = "Base.ThompsonM1921", attachment = "Base.Mag45TommyDrum", model = "ThompsonM1921NoMag" },
        { fullType = "Base.M1918BAR", attachment = "Base.Mag3006ExtLg", model = "M1918BARNoMag" },
        { fullType = "Base.M1918BAR_Bipod", attachment = "Base.Mag3006ExtLg", model = "M1918BARBipodNoMag" },
        { fullType = "Base.M1918BAR_Melee", attachment = "Base.Mag3006ExtLg", model = "M1918BARNoMag" },
        { fullType = "Base.SVDDragunov", attachment = "Base.MagSVDExtSm", model = "SVDDragunovNoMag" },
        { fullType = "Base.SVDDragunov_Melee", attachment = "Base.MagSVDExtSm", model = "SVDDragunovNoMag" },
        { fullType = "Base.VSSVintorez", attachment = "Base.Mag9x39ExtSm", model = "VSSVintorezNoMag" },
        { fullType = "Base.VSSVintorez_Melee", attachment = "Base.Mag9x39ExtSm", model = "VSSVintorezNoMag" },
        { fullType = "Base.VSSVintorez", attachment = "Base.Mag9x39ExtLg", model = "VSSVintorezNoMag" },
        { fullType = "Base.VSSVintorez_Melee", attachment = "Base.Mag9x39ExtLg", model = "VSSVintorezNoMag" },
        { fullType = "Base.ASVal", attachment = "Base.Mag9x39ExtLg", model = "ASValNoMag" },
        { fullType = "Base.ASVal_Melee", attachment = "Base.Mag9x39ExtLg", model = "ASValNoMag" },
        { fullType = "Base.ASVal_Folded", attachment = "Base.Mag9x39ExtLg", model = "ASValFoldedNoMag" },
        { fullType = "Base.ASVal_Folded_Melee", attachment = "Base.Mag9x39ExtLg", model = "ASValFoldedNoMag" },
        { fullType = "Base.EM2", attachment = "Base.Mag762x51ExtLg", model = "EM2NoMag" },
        { fullType = "Base.EM2_Melee", attachment = "Base.Mag762x51ExtLg", model = "EM2NoMag" },
        { fullType = "Base.PGMHecate", attachment = "Base.Mag50BMGExtSm", model = "PGMHecateNoMag" },
        { fullType = "Base.PGMHecate_Melee", attachment = "Base.Mag50BMGExtSm", model = "PGMHecateNoMag" },
        { fullType = "Base.PGMHecate_Bipod", attachment = "Base.Mag50BMGExtSm", model = "PGMHecateBipodNoMag" },
        { fullType = "Base.Galil", attachment = "Base.Mag762x51ExtSm", model = "GalilNoMag" },
        { fullType = "Base.Galil_Melee", attachment = "Base.Mag762x51ExtSm", model = "GalilNoMag" },
        { fullType = "Base.Galil_Bipod", attachment = "Base.Mag762x51ExtSm", model = "GalilBipodNoMag" },
    }
    
    for _, change in ipairs(extendedMagChange) do
        BWTweaks:changeModelByAttachment(change.fullType, change.attachment, change.model)
    end
    

    ---===========================================---
    --         ATTACHMENT ONLY MODEL SWAPS         --
    ---===========================================---

    --Remington Model 870 Shotgun Choke
    BWTweaks:changeModelByAttachment("Base.Shotgun", "Base.ChokeTubeFull", "ShotgunChoke");
    BWTweaks:changeModelByAttachment("Base.Shotgun_Melee", "Base.ChokeTubeFull", "ShotgunChoke");
    BWTweaks:changeModelByAttachment("Base.Shotgun", "Base.ChokeTubeImproved", "ShotgunChoke");
    BWTweaks:changeModelByAttachment("Base.Shotgun_Melee", "Base.ChokeTubeImproved", "ShotgunChoke");
    --Remington Model 870 Sawnoff Choke
    BWTweaks:changeModelByAttachment("Base.ShotgunSawnoff", "Base.ChokeTubeFull", "ShotgunSawnoffChoke");
    BWTweaks:changeModelByAttachment("Base.ShotgunSawnoff_Melee", "Base.ChokeTubeFull", "ShotgunSawnoffChoke");
    BWTweaks:changeModelByAttachment("Base.ShotgunSawnoff", "Base.ChokeTubeImproved", "ShotgunSawnoffChoke");
    BWTweaks:changeModelByAttachment("Base.ShotgunSawnoff_Melee", "Base.ChokeTubeImproved", "ShotgunSawnoffChoke");
    ----Skeletonized Stock AK103
    BWTweaks:changeModelByAttachmentAndMagPresent("Base.AK103", "Base.SkeletonizedStock", true, "AK103Skele");
    BWTweaks:changeModelByAttachmentAndMagPresent("Base.AK103", "Base.SkeletonizedStock", false, "AK103SkeleNoMag");
    BWTweaks:changeModelByAttachmentAndMagPresent("Base.AK103_Melee", "Base.SkeletonizedStock", true, "AK103Skele");
    BWTweaks:changeModelByAttachmentAndMagPresent("Base.AK103_Melee", "Base.SkeletonizedStock", false, "AK103SkeleNoMag");

    
    ---===========================================---
    --           PLATING ONLY MODEL SWAPS          --
    ---===========================================---
    local function GP(name)
        return "GunPlating" .. name
    end

    ---Beretta M9 DZ Melee
    BWTweaks:changeModelByGunPlating("Base.Pistol_Melee", GP("DZ"), "Handgun03MeleeDZ");
    ---Beretta M9 Pink Melee
    BWTweaks:changeModelByGunPlating("Base.Pistol_Melee", GP("Pink"), "Handgun03MeleePink");
    ---Beretta M9 pearl Melee
    BWTweaks:changeModelByGunPlating("Base.Pistol_Melee", GP("Pearl"), "Handgun03MeleePearl");
    --Colt 1911 Patriot Melee
    BWTweaks:changeModelByGunPlating("Base.Pistol2_Melee", GP("Patriot"), "Handgun02MeleePatriot");
    --Colt 1911 Aztec Melee
    BWTweaks:changeModelByGunPlating("Base.Pistol2_Melee", GP("Aztec"), "Handgun02MeleeAztec");
    --Desert Eagle Gold Melee
    BWTweaks:changeModelByGunPlating("Base.Pistol3_Melee", GP("Gold"), "HandgunMeleeGold");
    --Desert Eagle Salvaged Black Melee
    BWTweaks:changeModelByGunPlating("Base.Pistol3_Melee", GP("MatteBlack"), "HandgunMeleeSalvagedBlack");
    --Desert Eagle Mystery Machine Melee
    BWTweaks:changeModelByGunPlating("Base.Pistol3_Melee", GP("MysteryMachine"), "HandgunMeleeMysteryMachine");
    --Smith and Wesson Pink
    BWTweaks:changeModelByGunPlating("Base.Revolver", GP("Pink"), "RevolverPink");
    BWTweaks:changeModelByGunPlating("Base.Revolver_Melee", GP("Pink"), "RevolverMeleePink");
    --Magnum Anaconda Gold
    BWTweaks:changeModelByGunPlating("Base.Revolver_Long", GP("Gold"), "Revolver_LongGold");
    BWTweaks:changeModelByGunPlating("Base.Revolver_Long_Melee", GP("Gold"), "Revolver_LongMeleeGold");
    --Magnum Anaconda Nerf
    BWTweaks:changeModelByGunPlating("Base.Revolver_Long", GP("Nerf"), "Revolver_LongNerf");
    BWTweaks:changeModelByGunPlating("Base.Revolver_Long_Melee", GP("Nerf"), "Revolver_LongMeleeNerf");
    --Remington Model 700 DZ
    BWTweaks:changeModelByGunPlating("Base.VarmintRifle", GP("DZ"), "VarmintRifleDZ")
    BWTweaks:changeModelByGunPlating("Base.VarmintRifle_Melee", GP("DZ"), "VarmintRifleDZ")
    --Remington Model 700 Dark Cherry
    BWTweaks:changeModelByGunPlating("Base.VarmintRifle", GP("DarkCherry"), "VarmintRifleDarkCherry");
    BWTweaks:changeModelByGunPlating("Base.VarmintRifle_Melee", GP("DarkCherry"), "VarmintRifleDarkCherry");
    --Remington Model 870 ALL Purple
    BWTweaks:changeModelByGunPlating("Base.Shotgun", GP("Purple"), "ShotgunPurple");
    BWTweaks:changeModelByGunPlating("Base.Shotgun_Melee", GP("Purple"), "ShotgunPurple");
    BWTweaks:changeModelByGunPlating("Base.ShotgunSawnoff", GP("Purple"), "ShotgunSawnOffPurple");
    BWTweaks:changeModelByGunPlating("Base.ShotgunSawnoff_Melee", GP("Purple"), "ShotgunSawnOffPurple");
    --Remington SPR 220 Shotgun
    BWTweaks:changeModelByGunPlating("Base.DoubleBarrelShotgun", GP("Purple"), "DoubleBarrelShotgunBespoke");
    BWTweaks:changeModelByGunPlating("Base.DoubleBarrelShotgun_Melee", GP("Purple"), "DoubleBarrelShotgunBespoke");
    BWTweaks:changeModelByGunPlating("Base.DoubleBarrelShotgun_OPEN", GP("Purple"), "DoubleBarrelShotgunBespoke_OPEN");
    --Remington SPR 220 Sawnoff Shotgun
    BWTweaks:changeModelByGunPlating("Base.DoubleBarrelShotgunSawnoff", GP("BespokeEngraved"), "DoubleBarrelShotgunSawnoffBespoke");
    BWTweaks:changeModelByGunPlating("Base.DoubleBarrelShotgunSawnoff_Melee", GP("BespokeEngraved"), "DoubleBarrelShotgunSawnoffBespoke");
    BWTweaks:changeModelByGunPlating("Base.DoubleBarrelShotgunSawnoff_OPEN", GP("BespokeEngraved"), "DoubleBarrelShotgunSawnoffBespoke_OPEN");
    --Glock Wood
    BWTweaks:changeModelByGunPlating("Base.Glock_Melee", GP("Wood"), "GlockWoodMelee");
    --Glock PARP
    BWTweaks:changeModelByGunPlating("Base.Glock_Melee", GP("PARP"), "GlockPARPMelee");    
    --Glock SD
    BWTweaks:changeModelByGunPlating("Base.Glock_Melee", GP("SD"), "GlockSDMelee");
    --Glock DOTD
    BWTweaks:changeModelByGunPlating("Base.Glock_Melee", GP("DOTD"), "GlockDOTDMelee");
    --SIG Sauer Melee Tan
    BWTweaks:changeModelByGunPlating("Base.SIGSauer_Melee", GP("Tan"), "SIGSauerTanMelee");
    --SIG Sauer Melee Purple
    BWTweaks:changeModelByGunPlating("Base.SIGSauer_Melee", GP("Purple"), "SIGSauerPurpleMelee");
    --Jennings Melee Blue
    BWTweaks:changeModelByGunPlating("Base.JenningsJ22_Melee", GP("Blue"), "JenningsJ22BlueMelee");
    --Luger Melee CrabShell
    BWTweaks:changeModelByGunPlating("Base.Luger_Melee", GP("CrabShell"), "LugerCrabShellMelee");
    --Derringer UWU
    BWTweaks:changeModelByGunPlating("Base.Derringer", GP("Pink"), "DerringerUWU");
    BWTweaks:changeModelByGunPlating("Base.Derringer_OPEN", GP("Pink"), "DerringerUWU_OPEN");
    BWTweaks:changeModelByGunPlating("Base.Derringer_Melee", GP("Pink"), "DerringerUWU_Melee");
    ---Henry Repeating Big Boy Fancy
    BWTweaks:changeModelByGunPlating("Base.HenryRepeatingBigBoy", GP("Gold"), "HenryRepeatingBigBoyDeluxe");
    BWTweaks:changeModelByGunPlating("Base.HenryRepeatingBigBoy_Melee", GP("Gold"), "HenryRepeatingBigBoyDeluxe");
    BWTweaks:changeModelByGunPlating("Base.HenryRepeatingBigBoy", GP("Pink"), "HenryRepeatingBigBoyPink");
    BWTweaks:changeModelByGunPlating("Base.HenryRepeatingBigBoy_Melee", GP("Pink"), "HenryRepeatingBigBoyPink");
    --Remington1100 Wood Styling
    BWTweaks:changeModelByGunPlating("Base.Remington1100", GP("Wood"), "Remington1100Wood");
    BWTweaks:changeModelByGunPlating("Base.Remington1100_Melee", GP("Wood"), "Remington1100Wood");
    --Remington1100 Gold 
    BWTweaks:changeModelByGunPlating("Base.Remington1100", GP("Gold"), "Remington1100Gold");
    BWTweaks:changeModelByGunPlating("Base.Remington1100_Melee", GP("Gold"), "Remington1100Gold");
    --Remington1100 Rainbow
    BWTweaks:changeModelByGunPlating("Base.Remington1100", GP("Rainbow"), "Remington1100Rainbow");
    BWTweaks:changeModelByGunPlating("Base.Remington1100_Melee", GP("Rainbow"), "Remington1100Rainbow");
    --Remington1100 Red White
    BWTweaks:changeModelByGunPlating("Base.Remington1100", GP("RedWhite"), "Remington1100RedWhite");
    BWTweaks:changeModelByGunPlating("Base.Remington1100_Melee", GP("RedWhite"), "Remington1100RedWhite");
    --Trench Gun Pink
    BWTweaks:changeModelByGunPlating("Base.TrenchGun", GP("Pink"), "TrenchGunPink");
    BWTweaks:changeModelByGunPlating("Base.TrenchGun_Melee", GP("Pink"), "TrenchGunPink");
    --Trench Gun Yellow
    BWTweaks:changeModelByGunPlating("Base.TrenchGun", GP("Yellow"), "TrenchGunYellow");
    BWTweaks:changeModelByGunPlating("Base.TrenchGun_Melee", GP("Yellow"), "TrenchGunYellow");
    --PM63Rack Green Animal Print
    BWTweaks:changeModelByGunPlating("Base.PM63RAK", GP("Green"), "PM63RAKGreenAnimal");
    BWTweaks:changeModelByGunPlating("Base.PM63RAK_Melee", GP("Green"), "PM63RAKGreenAnimal");
    BWTweaks:changeModelByGunPlating("Base.PM63RAK_Grip", GP("Green"), "PM63RAKGrGreenAnimal");
    BWTweaks:changeModelByGunPlating("Base.PM63RAK_Extended", GP("Green"), "PM63RAKExtGreenAnimal");
    BWTweaks:changeModelByGunPlating("Base.PM63RAK_Extended_Melee", GP("Green"), "PM63RAKExtGreenAnimal");
    BWTweaks:changeModelByGunPlating("Base.PM63RAK_GripExtended", GP("Green"), "PM63RAKExtGrGreenAnimal");
    -- Colt Cavalry Revolver Gilded Age
    BWTweaks:changeModelByGunPlating("Base.ColtCavalryRevolver", GP("GildedAge"), "ColtCavalryRevolverGold");
    BWTweaks:changeModelByGunPlating("Base.ColtCavalryRevolver_Melee", GP("GildedAge"), "ColtCavalryRevolverMeleeGold");
    -- Colt Cavalry Revolver Black Death
    BWTweaks:changeModelByGunPlating("Base.ColtCavalryRevolver", GP("BlackDeath"), "ColtCavalryRevolverBlackDeath");
    BWTweaks:changeModelByGunPlating("Base.ColtCavalryRevolver_Melee", GP("BlackDeath"), "ColtCavalryRevolverMeleeBlackDeath");
    -- Colt Cavalry Revolver Ornate Ivory
    BWTweaks:changeModelByGunPlating("Base.ColtCavalryRevolver", GP("OrnateIvory"), "ColtCavalryRevolverOrnateIvory");
    BWTweaks:changeModelByGunPlating("Base.ColtCavalryRevolver_Melee", GP("OrnateIvory"), "ColtCavalryRevolverMeleeOrnateIvory");
    --Mossberg 500 Cannon Tan
    BWTweaks:changeModelByGunPlating("Base.Mossberg500", GP("Tan"), "Mossberg500Tan");
    BWTweaks:changeModelByGunPlating("Base.Mossberg500_Melee", GP("Tan"), "Mossberg500Tan");
    BWTweaks:changeModelByGunPlating("Base.Mossberg500Super", GP("Tan"), "Mossberg500SuperTan");
    BWTweaks:changeModelByGunPlating("Base.Mossberg500Super_Melee", GP("Tan"), "Mossberg500SuperTan");
    BWTweaks:changeModelByGunPlating("Base.Mossberg500Super_Grip", GP("Tan"), "Mossberg500SuperGrTan");
    --Mossberg 500 Cannon PARP
    BWTweaks:changeModelByGunPlating("Base.Mossberg500", GP("PARP"), "Mossberg500PARP");
    BWTweaks:changeModelByGunPlating("Base.Mossberg500_Melee", GP("PARP"), "Mossberg500PARP");
    BWTweaks:changeModelByGunPlating("Base.Mossberg500Super", GP("PARP"), "Mossberg500SuperPARP");
    BWTweaks:changeModelByGunPlating("Base.Mossberg500Super_Melee", GP("PARP"), "Mossberg500SuperPARP");
    BWTweaks:changeModelByGunPlating("Base.Mossberg500Super_Grip", GP("PARP"), "Mossberg500SuperGrPARP");
    --Mossberg 500 Cannon SD
    BWTweaks:changeModelByGunPlating("Base.Mossberg500", GP("SD"), "Mossberg500SD");
    BWTweaks:changeModelByGunPlating("Base.Mossberg500_Melee", GP("SD"), "Mossberg500SD");
    BWTweaks:changeModelByGunPlating("Base.Mossberg500Super", GP("SD"), "Mossberg500SuperSD");
    BWTweaks:changeModelByGunPlating("Base.Mossberg500Super_Melee", GP("SD"), "Mossberg500SuperSD");
    BWTweaks:changeModelByGunPlating("Base.Mossberg500Super_Grip", GP("SD"), "Mossberg500SuperGrSD");
    --Mossberg 500 Cannon DOTD
    BWTweaks:changeModelByGunPlating("Base.Mossberg500", GP("DOTD"), "Mossberg500DOTD");
    BWTweaks:changeModelByGunPlating("Base.Mossberg500_Melee", GP("DOTD"), "Mossberg500DOTD");
    BWTweaks:changeModelByGunPlating("Base.Mossberg500Super", GP("DOTD"), "Mossberg500SuperDOTD");
    BWTweaks:changeModelByGunPlating("Base.Mossberg500Super_Melee", GP("DOTD"), "Mossberg500SuperDOTD");
    BWTweaks:changeModelByGunPlating("Base.Mossberg500Super_Grip", GP("DOTD"), "Mossberg500SuperGrDOTD");
    --Becker Revolver Shotgun Green
    BWTweaks:changeModelByGunPlating("Base.BeckerRevolver", GP("Green"), "BeckerRevolverGreen");
    BWTweaks:changeModelByGunPlating("Base.BeckerRevolver_Melee", GP("Green"), "BeckerRevolverGreen");
    -- TShirt Cannon PARP
    BWTweaks:changeModelByGunPlating("Base.TShirtLauncher", GP("PARP"), "TShirtCannonPARP");
    -- TShirt Cannon SD
    BWTweaks:changeModelByGunPlating("Base.TShirtLauncher", GP("SD"), "TShirtCannonSD");
    -- TShirt Cannon DOTD
    BWTweaks:changeModelByGunPlating("Base.TShirtLauncher", GP("DOTD"), "TShirtCannonDOTD");

    ---===========================================---
    --       PLATING + ATTACHMENT MODEL SWAPS      --
    ---===========================================---

    --Remington Model 870 Shotgun Choke
    BWTweaks:changeModelByGunPlatingAndAttachment("Base.Shotgun", GP("Purple"), "Base.ChokeTubeFull", "ShotgunChokePurple");
    BWTweaks:changeModelByGunPlatingAndAttachment("Base.Shotgun_Melee", GP("Purple"), "Base.ChokeTubeFull", "ShotgunChokePurple");
    BWTweaks:changeModelByGunPlatingAndAttachment("Base.Shotgun", GP("Purple"), "Base.ChokeTubeImproved", "ShotgunChokePurple");
    BWTweaks:changeModelByGunPlatingAndAttachment("Base.Shotgun_Melee", GP("Purple"), "Base.ChokeTubeImproved", "ShotgunChokePurple");
    --Remington Model 870 Sawnoff Shotgun Choke
    BWTweaks:changeModelByGunPlatingAndAttachment("Base.ShotgunSawnoff", GP("Purple"), "Base.ChokeTubeFull", "ShotgunSawnoffChokePurple");
    BWTweaks:changeModelByGunPlatingAndAttachment("Base.ShotgunSawnoff_Melee", GP("Purple"), "Base.ChokeTubeFull", "ShotgunSawnoffChokePurple");
    BWTweaks:changeModelByGunPlatingAndAttachment("Base.ShotgunSawnoff", GP("Purple"), "Base.ChokeTubeImproved", "ShotgunSawnoffChokePurple");
    BWTweaks:changeModelByGunPlatingAndAttachment("Base.ShotgunSawnoff_Melee", GP("Purple"), "Base.ChokeTubeImproved", "ShotgunSawnoffChokePurple");

    ---===========================================---
    --        PLATING + MAGAZINE MODEL SWAPS       --
    ---===========================================---

    local gunPlatingAndMags = {
        --Beretta M9 DZ
        { fullType = "Base.Pistol", gunPlating = GP("DZ"), modelWithMag = "Handgun03DZ", modelWithoutMag = "Handgun03DZNoMag" },
        --Beretta M9 Pink
        { fullType = "Base.Pistol", gunPlating = GP("Pink"), modelWithMag = "Handgun03Pink", modelWithoutMag = "Handgun03PinkNoMag" },
        --Beretta M9 Pearl
        { fullType = "Base.Pistol", gunPlating = GP("Pearl"), modelWithMag = "Handgun03Pearl", modelWithoutMag = "Handgun03PearlNoMag" },
        --Colt 1911 Patriot
        { fullType = "Base.Pistol2", gunPlating = GP("Patriot"), modelWithMag = "Handgun02Patriot", modelWithoutMag = "Handgun02PatriotNoMag" },
        --Colt 1911 Aztec
        { fullType = "Base.Pistol2", gunPlating = GP("Aztec"), modelWithMag = "Handgun02Aztec", modelWithoutMag = "Handgun02AztecNoMag" },
        --Desert Eagle Gold
         { fullType = "Base.Pistol3", gunPlating = GP("Gold"), modelWithMag = "HandgunGold", modelWithoutMag = "HandgunGoldNoMag" },
        --Desert Eagle Salvaged Black
        { fullType = "Base.Pistol3", gunPlating = GP("MatteBlack"), modelWithMag = "HandgunSalvagedBlack", modelWithoutMag = "HandgunSalvagedBlackNoMag" },
        --Desert Eagle Mystery Machine
        { fullType = "Base.Pistol3", gunPlating = GP("MysteryMachine"), modelWithMag = "HandgunMysteryMachine", modelWithoutMag = "HandgunMysteryMachineNoMag" },
        --Remington Model 788 DZ
        { fullType = "Base.HuntingRifle", gunPlating = GP("DZ"), modelWithMag = "HuntingRifleDZ", modelWithoutMag = "HuntingRifleDZNoMag" },
        { fullType = "Base.HuntingRifle_Melee", gunPlating = GP("DZ"), modelWithMag = "HuntingRifleDZ", modelWithoutMag = "HuntingRifleDZNoMag" },
        --Remington Model 788 Dark Cherry
        { fullType = "Base.HuntingRifle", gunPlating = GP("DarkCherry"), modelWithMag = "HuntingRifleDarkCherry", modelWithoutMag = "HuntingRifleDarkCherryNoMag" },
        { fullType = "Base.HuntingRifle_Melee", gunPlating = GP("DarkCherry"), modelWithMag = "HuntingRifleDarkCherry", modelWithoutMag = "HuntingRifleDarkCherryNoMag" },
        --Colf M16 Gold 
        { fullType = "Base.AssaultRifle", gunPlating = GP("Gold"), modelWithMag = "AssaultRifleGold", modelWithoutMag = "AssaultRifleGoldNoMag" },
        { fullType = "Base.AssaultRifle_Melee", gunPlating = GP("Gold"), modelWithMag = "AssaultRifleGold", modelWithoutMag = "AssaultRifleGoldNoMag" },
        --Colf M16 PARP 
        { fullType = "Base.AssaultRifle", gunPlating = GP("PARP"), modelWithMag = "AssaultRiflePARP", modelWithoutMag = "AssaultRiflePARPNoMag" },
        { fullType = "Base.AssaultRifle_Melee", gunPlating = GP("PARP"), modelWithMag = "AssaultRiflePARP", modelWithoutMag = "AssaultRiflePARPNoMag" },
        --Colf M16 SD 
        { fullType = "Base.AssaultRifle", gunPlating = GP("SD"), modelWithMag = "AssaultRifleSD", modelWithoutMag = "AssaultRifleSDNoMag" },
        { fullType = "Base.AssaultRifle_Melee", gunPlating = GP("SD"), modelWithMag = "AssaultRifleSD", modelWithoutMag = "AssaultRifleSDNoMag" },
        --Colf M16 DOTD 
        { fullType = "Base.AssaultRifle", gunPlating = GP("DOTD"), modelWithMag = "AssaultRifleDOTD", modelWithoutMag = "AssaultRifleDOTDNoMag" },
        { fullType = "Base.AssaultRifle_Melee", gunPlating = GP("DOTD"), modelWithMag = "AssaultRifleDOTD", modelWithoutMag = "AssaultRifleDOTDNoMag" },
        ---Glock Wood
        { fullType = "Base.Glock", gunPlating = GP("Wood"), modelWithMag = "GlockWood", modelWithoutMag = "GlockWoodNoMag" },
        ---Glock PARP
        { fullType = "Base.Glock", gunPlating = GP("PARP"), modelWithMag = "GlockPARP", modelWithoutMag = "GlockPARPNoMag" },
        ---Glock SD
        { fullType = "Base.Glock", gunPlating = GP("SD"), modelWithMag = "GlockSD", modelWithoutMag = "GlockSDNoMag" },
        ---Glock DOTD
        { fullType = "Base.Glock", gunPlating = GP("DOTD"), modelWithMag = "GlockDOTD", modelWithoutMag = "GlockDOTDNoMag" },
        ---SIG Sauer Tan
        { fullType = "Base.SIGSauer", gunPlating = GP("Tan"), modelWithMag = "SIGSauerTan", modelWithoutMag = "SIGSauerTanNoMag" },
        ---SIG Sauer Purple
        { fullType = "Base.SIGSauer", gunPlating = GP("Purple"), modelWithMag = "SIGSauerPurple", modelWithoutMag = "SIGSauerPurpleNoMag" },
        ---SIG Sauer Purple
        { fullType = "Base.JenningsJ22", gunPlating = GP("Blue"), modelWithMag = "JenningsJ22Blue", modelWithoutMag = "JenningsJ22BlueNoMag" },
        ----Crab Shell Luger
        { fullType = "Base.Luger", gunPlating = GP("CrabShell"), modelWithMag = "LugerCrabShell", modelWithoutMag = "LugerCrabShellNoMag"},
        ---The Nailgun PARP
        { fullType = "Base.TheNailGun", gunPlating = GP("PARP"), modelWithMag = "TheNailGunPARP", modelWithoutMag = "TheNailGunPARPNoMag" },
        { fullType = "Base.TheNailGun_Melee", gunPlating = GP("PARP"), modelWithMag = "TheNailGunPARP", modelWithoutMag = "TheNailGunPARPNoMag" },
        ---The Nailgun SD
        { fullType = "Base.TheNailGun", gunPlating = GP("SD"), modelWithMag = "TheNailGunSD", modelWithoutMag = "TheNailGunSDNoMag" },
        { fullType = "Base.TheNailGun_Melee", gunPlating = GP("SD"), modelWithMag = "TheNailGunSD", modelWithoutMag = "TheNailGunSDNoMag" },
        ---The Nailgun DOTD
        { fullType = "Base.TheNailGun", gunPlating = GP("DOTD"), modelWithMag = "TheNailGunDOTD", modelWithoutMag = "TheNailGunDOTDNoMag" },
        { fullType = "Base.TheNailGun_Melee", gunPlating = GP("DOTD"), modelWithMag = "TheNailGunDOTD", modelWithoutMag = "TheNailGunDOTDNoMag"  },
        ----CrabShell STG
        { fullType = "Base.StG44", gunPlating = GP("CrabShell"), modelWithMag = "StG44CrabShell", modelWithoutMag = "StG44CrabShellNoMag" },
        { fullType = "Base.StG44_Melee", gunPlating = GP("CrabShell"), modelWithMag = "StG44CrabShell", modelWithoutMag = "StG44CrabShellNoMag" },
        ----Winter Camo AK74U
        { fullType = "Base.AK74U", gunPlating = GP("WinterCamo"), modelWithMag = "AK74UWinter", modelWithoutMag = "AK74UWinterNoMag" },
        { fullType = "Base.AK74U_Melee", gunPlating = GP("WinterCamo"), modelWithMag = "AK74UWinter", modelWithoutMag = "AK74UWinterNoMag" },
        { fullType = "Base.AK74U_Folded", gunPlating = GP("WinterCamo"), modelWithMag = "AK74UWinter_Folded", modelWithoutMag = "AK74UWinterNoMag_Folded" },
        { fullType = "Base.AK74U_Folded_Melee", gunPlating = GP("WinterCamo"), modelWithMag = "AK74UWinter_Folded", modelWithoutMag = "AK74UWinterNoMag_Folded" },
        ----Gold AK74U
        { fullType = "Base.AK74U", gunPlating = GP("Gold"), modelWithMag = "AK74UGold", modelWithoutMag = "AK74UGoldNoMag" },
        { fullType = "Base.AK74U_Melee", gunPlating = GP("Gold"), modelWithMag = "AK74UGold", modelWithoutMag = "AK74UGoldNoMag" },
        { fullType = "Base.AK74U_Folded", gunPlating = GP("Gold"), modelWithMag = "AK74UGold_Folded", modelWithoutMag = "AK74UGoldNoMag_Folded" },
        { fullType = "Base.AK74U_Folded_Melee", gunPlating = GP("Gold"), modelWithMag = "AK74UGold_Folded", modelWithoutMag = "AK74UGoldNoMag_Folded" },
        ----Rainbow AK74U
        { fullType = "Base.AK74U", gunPlating = GP("Rainbow"), modelWithMag = "AK74URainbow", modelWithoutMag = "AK74URainbowNoMag" },
        { fullType = "Base.AK74U_Melee", gunPlating = GP("Rainbow"), modelWithMag = "AK74URainbow", modelWithoutMag = "AK74URainbowNoMag" },
        { fullType = "Base.AK74U_Folded", gunPlating = GP("Rainbow"), modelWithMag = "AK74URainbow_Folded", modelWithoutMag = "AK74URainbowNoMag_Folded" },
        { fullType = "Base.AK74U_Folded_Melee", gunPlating = GP("Rainbow"), modelWithMag = "AK74URainbow_Folded", modelWithoutMag = "AK74URainbowNoMag_Folded" },
        ----Blue and Yellow DZ styled FranchiLF57
        { fullType = "Base.FranchiLF57", gunPlating = GP("DZ"), modelWithMag = "FranchiLF57DZ", modelWithoutMag = "FranchiLF57DZNoMag" },
        { fullType = "Base.FranchiLF57_Melee", gunPlating = GP("DZ"), modelWithMag = "FranchiLF57DZ", modelWithoutMag = "FranchiLF57DZNoMag" },
        { fullType = "Base.FranchiLF57_Folded", gunPlating = GP("DZ"), modelWithMag = "FranchiLF57DZ_Folded", modelWithoutMag = "FranchiLF57DZNoMag_Folded" },
        { fullType = "Base.FranchiLF57_Folded_Melee", gunPlating = GP("DZ"), modelWithMag = "FranchiLF57DZ_Folded", modelWithoutMag = "FranchiLF57DZNoMag_Folded" },
        ----Rainbow Anondized AK103
        { fullType = "Base.AK103", gunPlating = GP("Rainbow"), modelWithMag = "AK103Rainbow", modelWithoutMag = "AK103RainbowNoMag" },
        { fullType = "Base.AK103_Melee", gunPlating = GP("Rainbow"), modelWithMag = "AK103Rainbow", modelWithoutMag = "AK103RainbowNoMag" },
        ----Gold Plating AK103
        { fullType = "Base.AK103", gunPlating = GP("Gold"), modelWithMag = "AK103Gold", modelWithoutMag = "AK103GoldNoMag" },
        { fullType = "Base.AK103_Melee", gunPlating = GP("Gold"), modelWithMag = "AK103Gold", modelWithoutMag = "AK103GoldNoMag" },
        ----Winter Camo AK103
        { fullType = "Base.AK103", gunPlating = GP("WinterCamo"), modelWithMag = "AK103Winter", modelWithoutMag = "AK103WinterNoMag" },
        { fullType = "Base.AK103_Melee", gunPlating = GP("WinterCamo"), modelWithMag = "AK103Winter", modelWithoutMag = "AK103WinterNoMag" },
        ----Winter Camo AK74
        { fullType = "Base.AK74", gunPlating = GP("WinterCamo"), modelWithMag = "AK74Winter", modelWithoutMag = "AK74WinterNoMag" },
        { fullType = "Base.AK74_Melee", gunPlating = GP("WinterCamo"), modelWithMag = "AK74Winter", modelWithoutMag = "AK74WinterNoMag" },
        ----Gold AK74
        { fullType = "Base.AK74", gunPlating = GP("Gold"), modelWithMag = "AK74Gold", modelWithoutMag = "AK74GoldNoMag" },
        { fullType = "Base.AK74_Melee", gunPlating = GP("Gold"), modelWithMag = "AK74Gold", modelWithoutMag = "AK74GoldNoMag" },
        ----Rainbow AK74
        { fullType = "Base.AK74", gunPlating = GP("Rainbow"), modelWithMag = "AK74Rainbow", modelWithoutMag = "AK74RainbowNoMag" },
        { fullType = "Base.AK74_Melee", gunPlating = GP("Rainbow"), modelWithMag = "AK74Rainbow", modelWithoutMag = "AK74RainbowNoMag" },
        ----Yellow Golden Barb Browning BLR
        { fullType = "Base.BrowningBLR", gunPlating = GP("Yellow"), modelWithMag = "BrowningBLRYellow", modelWithoutMag = "BrowningBLRYellowNoMag" },
        { fullType = "Base.BrowningBLR_Melee", gunPlating = GP("Yellow"), modelWithMag = "BrowningBLRYellow", modelWithoutMag = "BrowningBLRYellowNoMag" },
        ----Red White Camo Browning BLR
        { fullType = "Base.BrowningBLR", gunPlating = GP("RedWhite"), modelWithMag = "BrowningBLRRedWhite", modelWithoutMag = "BrowningBLRRedWhiteNoMag" },
        { fullType = "Base.BrowningBLR_Melee", gunPlating = GP("RedWhite"), modelWithMag = "BrowningBLRRedWhite", modelWithoutMag = "BrowningBLRRedWhiteNoMag" },
        ----Pink Plating and P90
        { fullType = "Base.P90", gunPlating = GP("Pink"), modelWithMag = "P90Pink", modelWithoutMag = "P90PinkNoMag" },
        { fullType = "Base.P90_Melee", gunPlating = GP("Pink"), modelWithMag = "P90Pink", modelWithoutMag = "P90PinkNoMag" },
        ----Salvaged Black Plating to do Black Ice style and P90
        { fullType = "Base.P90", gunPlating = GP("Blue"), modelWithMag = "P90BlackIce", modelWithoutMag = "P90BlackIceNoMag" },
        { fullType = "Base.P90_Melee", gunPlating = GP("Blue"), modelWithMag = "P90BlackIce", modelWithoutMag = "P90BlackIceNoMag" },
        ----Plank Plating and P90
        { fullType = "Base.P90", gunPlating = GP("Wood"), modelWithMag = "P90Plank", modelWithoutMag = "P90PlankNoMag" },
        { fullType = "Base.P90_Melee", gunPlating = GP("Wood"), modelWithMag = "P90Plank", modelWithoutMag = "P90PlankNoMag" },
        ----Green/Gold and M1918
        { fullType = "Base.M1918BAR", gunPlating = GP("GreenGold"), modelWithMag = "M1918BARGreenGold", modelWithoutMag = "M1918BARGreenGoldNoMag" },
        { fullType = "Base.M1918BAR_Bipod", gunPlating = GP("GreenGold"), modelWithMag = "M1918BARGreenGoldBipod", modelWithoutMag = "M1918BARGreenGoldBipodNoMag" },
        { fullType = "Base.M1918BAR_Melee", gunPlating = GP("GreenGold"), modelWithMag = "M1918BARGreenGold", modelWithoutMag = "M1918BARGreenGoldNoMag" },
        ----White SIG550
        { fullType = "Base.SIG550", gunPlating = GP("WinterCamo"), modelWithMag = "SIG550White", modelWithoutMag = "SIG550WhiteNoMag" },
        { fullType = "Base.SIG550_Melee", gunPlating = GP("WinterCamo"), modelWithMag = "SIG550White", modelWithoutMag = "SIG550WhiteNoMag" },
        ----Pink SIG550
        { fullType = "Base.SIG550", gunPlating = GP("Pink"), modelWithMag = "SIG550Pink", modelWithoutMag = "SIG550PinkNoMag" },
        { fullType = "Base.SIG550_Melee", gunPlating = GP("Pink"), modelWithMag = "SIG550Pink", modelWithoutMag = "SIG550PinkNoMag" }, 
        ----Green SIG550
        { fullType = "Base.SIG550", gunPlating = GP("GreenGold"), modelWithMag = "SIG550Green", modelWithoutMag = "SIG550GreenNoMag" },
        { fullType = "Base.SIG550_Melee", gunPlating = GP("GreenGold"), modelWithMag = "SIG550Green", modelWithoutMag = "SIG550GreenNoMag" }, 
        --- DragonBall Shenron SIG550
        { fullType = "Base.SIG550", gunPlating = GP("DragonBall"), modelWithMag = "SIG550Shenron", modelWithoutMag = "SIG550ShenronNoMag" },
        { fullType = "Base.SIG550_Melee", gunPlating = GP("DragonBall"), modelWithMag = "SIG550Shenron", modelWithoutMag = "SIG550ShenronNoMag" }, 
        ---Steel Damascus Barrett
        { fullType = "Base.BarrettM82A1", gunPlating = GP("SteelDamascus"), modelWithMag = "BarrettM82A1SteelDamascus", modelWithoutMag = "BarrettM82A1SteelDamascusNoMag" },
        { fullType = "Base.BarrettM82A1_Bipod", gunPlating = GP("SteelDamascus"), modelWithMag = "BarrettM82A1SteelDamascusBipod", modelWithoutMag = "BarrettM82A1SteelDamascusBipodNoMag" },
        { fullType = "Base.BarrettM82A1_Melee", gunPlating = GP("SteelDamascus"), modelWithMag = "BarrettM82A1SteelDamascus", modelWithoutMag = "BarrettM82A1SteelDamascusNoMag" },
        ---Salvaged Rage Barrett 
        { fullType = "Base.BarrettM82A1", gunPlating = GP("SalvagedRage"), modelWithMag = "BarrettM82A1SalvagedRage", modelWithoutMag = "BarrettM82A1SalvagedRageNoMag" },
        { fullType = "Base.BarrettM82A1_Bipod", gunPlating = GP("SalvagedRage"), modelWithMag = "BarrettM82A1SalvagedRageBipod", modelWithoutMag = "BarrettM82A1SalvagedRageBipodNoMag" },
        { fullType = "Base.BarrettM82A1_Melee", gunPlating = GP("SalvagedRage"), modelWithMag = "BarrettM82A1SalvagedRage", modelWithoutMag = "BarrettM82A1SalvagedRageNoMag" },
        ---Zoidberg Special Barrett
        { fullType = "Base.BarrettM82A1", gunPlating = GP("ZoidbergSpecial"), modelWithMag = "BarrettM82A1ZoidbergSpecial", modelWithoutMag = "BarrettM82A1ZoidbergSpecialNoMag" },
        { fullType = "Base.BarrettM82A1_Bipod", gunPlating = GP("ZoidbergSpecial"), modelWithMag = "BarrettM82A1ZoidbergSpecialBipod", modelWithoutMag = "BarrettM82A1ZoidbergSpecialBipodNoMag" },
        { fullType = "Base.BarrettM82A1_Melee", gunPlating = GP("ZoidbergSpecial"), modelWithMag = "BarrettM82A1ZoidbergSpecial", modelWithoutMag = "BarrettM82A1ZoidbergSpecialNoMag" },
        ---Tan PGM Hecate
        { fullType = "Base.PGMHecate", gunPlating = GP("Tan"), modelWithMag = "PGMHecateTan", modelWithoutMag = "PGMHecateTanNoMag" },
        { fullType = "Base.PGMHecate_Bipod", gunPlating = GP("Tan"), modelWithMag = "PGMHecateTanBipod", modelWithoutMag = "PGMHecateTanBipodNoMag" },
        { fullType = "Base.PGMHecate_Melee", gunPlating = GP("Tan"), modelWithMag = "PGMHecateTan", modelWithoutMag = "PGMHecateTanNoMag" },
        ---Stitches Blue Stitches PGM Hecate
        { fullType = "Base.PGMHecate", gunPlating = GP("Blue"), modelWithMag = "PGMHecateBlue", modelWithoutMag = "PGMHecateBlueNoMag" },
        { fullType = "Base.PGMHecate_Bipod", gunPlating = GP("Blue"), modelWithMag = "PGMHecateBlueBipod", modelWithoutMag = "PGMHecateBlueBipodNoMag" },
        { fullType = "Base.PGMHecate_Melee", gunPlating = GP("Blue"), modelWithMag = "PGMHecateBlue", modelWithoutMag = "PGMHecateBlueNoMag" },
        ---Frieza DragonBall PGM Hecate
        { fullType = "Base.PGMHecate", gunPlating = GP("DragonBall"), modelWithMag = "PGMHecateDragonBall", modelWithoutMag = "PGMHecateDragonBallNoMag" },
        { fullType = "Base.PGMHecate_Bipod", gunPlating = GP("DragonBall"), modelWithMag = "PGMHecateDragonBallBipod", modelWithoutMag = "PGMHecateDragonBallBipodNoMag" },
        { fullType = "Base.PGMHecate_Melee", gunPlating = GP("DragonBall"), modelWithMag = "PGMHecateDragonBall", modelWithoutMag = "PGMHecateDragonBallNoMag" },
        ---DZ PGM Hecate
        { fullType = "Base.PGMHecate", gunPlating = GP("DZ"), modelWithMag = "PGMHecateDZ", modelWithoutMag = "PGMHecateDZNoMag" },
        { fullType = "Base.PGMHecate_Bipod", gunPlating = GP("DZ"), modelWithMag = "PGMHecateDZBipod", modelWithoutMag = "PGMHecateDZBipodNoMag" },
        { fullType = "Base.PGMHecate_Melee", gunPlating = GP("DZ"), modelWithMag = "PGMHecateDZ", modelWithoutMag = "PGMHecateDZNoMag" },
        ----Survivalist SVD Dragunov
        { fullType = "Base.SVDDragunov", gunPlating = GP("Survivalist"), modelWithMag = "SVDDragunovSurvivalist", modelWithoutMag = "SVDDragunovSurvivalistNoMag" },
        { fullType = "Base.SVDDragunov_Melee", gunPlating = GP("Survivalist"), modelWithMag = "SVDDragunovSurvivalist", modelWithoutMag = "SVDDragunovSurvivalistNoMag" }, 
        ----Snowstorm SVD Dragunov
        { fullType = "Base.SVDDragunov", gunPlating = GP("WinterCamo"), modelWithMag = "SVDDragunovSnowstorm", modelWithoutMag = "SVDDragunovSnowstormNoMag" },
        { fullType = "Base.SVDDragunov_Melee", gunPlating = GP("WinterCamo"), modelWithMag = "SVDDragunovSnowstorm", modelWithoutMag = "SVDDragunovSnowstormNoMag" }, 
        ----Gold Mini Uzi
        { fullType = "Base.MiniUzi", gunPlating = GP("Gold"), modelWithMag = "MiniUziGold", modelWithoutMag = "MiniUziGoldNoMag" },
        { fullType = "Base.MiniUzi_Melee", gunPlating = GP("Gold"), modelWithMag = "MiniUziGold", modelWithoutMag = "MiniUziGoldNoMag" },
        { fullType = "Base.MiniUzi_Folded", gunPlating = GP("Gold"), modelWithMag = "MiniUziGold_Folded", modelWithoutMag = "MiniUziGoldNoMag_Folded" },
        { fullType = "Base.MiniUzi_Folded_Melee", gunPlating = GP("Gold"), modelWithMag = "MiniUziGold_Folded", modelWithoutMag = "MiniUziGoldNoMag_Folded" },
         ----Rainbow Mini Uzi
        { fullType = "Base.MiniUzi", gunPlating = GP("Rainbow"), modelWithMag = "MiniUziRainbow", modelWithoutMag = "MiniUziRainbowNoMag" },
        { fullType = "Base.MiniUzi_Melee", gunPlating = GP("Rainbow"), modelWithMag = "MiniUziRainbow", modelWithoutMag = "MiniUziRainbowNoMag" },
        { fullType = "Base.MiniUzi_Folded", gunPlating = GP("Rainbow"), modelWithMag = "MiniUziRainbow_Folded", modelWithoutMag = "MiniUziRainbowNoMag_Folded" },
        { fullType = "Base.MiniUzi_Folded_Melee", gunPlating = GP("Rainbow"), modelWithMag = "MiniUziRainbow_Folded", modelWithoutMag = "MiniUziRainbowNoMag_Folded" },       
        ---M4A1 Tan
        { fullType = "Base.M4A1", gunPlating = GP("Tan"), modelWithMag = "M4A1Tan", modelWithoutMag = "M4A1TanNoMag" },
        { fullType = "Base.M4A1_Melee", gunPlating = GP("Tan"), modelWithMag = "M4A1Tan", modelWithoutMag = "M4A1TanNoMag" },
        ---M4A1 White
        { fullType = "Base.M4A1", gunPlating = GP("WinterCamo"), modelWithMag = "M4A1White", modelWithoutMag = "M4A1WhiteNoMag" },
        { fullType = "Base.M4A1_Melee", gunPlating = GP("WinterCamo"), modelWithMag = "M4A1White", modelWithoutMag = "M4A1WhiteNoMag" },
        ---M4A1 Blue      
        { fullType = "Base.M4A1", gunPlating = GP("Blue"), modelWithMag = "M4A1Blue", modelWithoutMag = "M4A1BlueNoMag" },
        { fullType = "Base.M4A1_Melee", gunPlating = GP("Blue"), modelWithMag = "M4A1Blue", modelWithoutMag = "M4A1BlueNoMag" },
        ---M4A1 Red
        { fullType = "Base.M4A1", gunPlating = GP("Red"), modelWithMag = "M4A1Red", modelWithoutMag = "M4A1RedNoMag" },
        { fullType = "Base.M4A1_Melee", gunPlating = GP("Red"), modelWithMag = "M4A1Red", modelWithoutMag = "M4A1RedNoMag" },
        ---M4A1 Pink
        { fullType = "Base.M4A1", gunPlating = GP("Pink"), modelWithMag = "M4A1Pink", modelWithoutMag = "M4A1PinkNoMag" },
        { fullType = "Base.M4A1_Melee", gunPlating = GP("Pink"), modelWithMag = "M4A1Pink", modelWithoutMag = "M4A1PinkNoMag" },
        ---M4A1 Cannabis
        { fullType = "Base.M4A1", gunPlating = GP("Cannabis"), modelWithMag = "M4A1Cannabis", modelWithoutMag = "M4A1CannabisNoMag" },
        { fullType = "Base.M4A1_Melee", gunPlating = GP("Cannabis"), modelWithMag = "M4A1Cannabis", modelWithoutMag = "M4A1CannabisNoMag" },
    }

    for _, change in ipairs(gunPlatingAndMags) do
        BWTweaks:changeModelByGunPlatingAndMagPresent(change.fullType, change.gunPlating, true, change.modelWithMag)
        BWTweaks:changeModelByGunPlatingAndMagPresent(change.fullType, change.gunPlating, false, change.modelWithoutMag)
    end


    ---===========================================---
    --   PLATING ATTACHMENTS MAGAZINE MODEL SWAPS  --
    ---===========================================---

    local gunPlatingAndAttachAndMags = {
        { fullType = "Base.AK103", gunPlating = GP("Rainbow"), attachment = "Base.SkeletonizedStock", modelWithMag = "AK103RainbowSkele", modelWithoutMag = "AK103RainbowSkeleNoMag" },
        { fullType = "Base.AK103_Melee", gunPlating = GP("Rainbow"), attachment = "Base.SkeletonizedStock", modelWithMag = "AK103RainbowSkele", modelWithoutMag = "AK103RainbowSkeleNoMag" },
        { fullType = "Base.AK103", gunPlating = GP("Gold"), attachment = "Base.SkeletonizedStock", modelWithMag = "AK103GoldSkele", modelWithoutMag = "AK103GoldSkeleNoMag" },
        { fullType = "Base.AK103_Melee", gunPlating = GP("Gold"), attachment = "Base.SkeletonizedStock", modelWithMag = "AK103GoldSkele", modelWithoutMag = "AK103GoldSkeleNoMag" },
        { fullType = "Base.AK103", gunPlating = GP("WinterCamo"), attachment = "Base.SkeletonizedStock", modelWithMag = "AK103WinterSkele", modelWithoutMag = "AK103WinterSkeleNoMag" },
        { fullType = "Base.AK103_Melee", gunPlating = GP("WinterCamo"), attachment = "Base.SkeletonizedStock", modelWithMag = "AK103WinterSkele", modelWithoutMag = "AK103WinterSkeleNoMag" },
    }


    for _, change in ipairs(gunPlatingAndAttachAndMags) do
        BWTweaks:changeModelByGunPlatingAndAttachmentAndMagPresent(change.fullType, change.gunPlating, change.attachment, true, change.modelWithMag)
        BWTweaks:changeModelByGunPlatingAndAttachmentAndMagPresent(change.fullType, change.gunPlating, change.attachment, false, change.modelWithoutMag)
    end


    ---===========================================---
    --  PLATING ATTACHMENT EXTENDED MAGAZINE SWAPS --
    ---===========================================---
    
    local gunPlatingExtendedMag = {
        { fullType = "Base.M1918BAR", gunPlating = GP("GreenGold"), attachment = "Base.Mag3006ExtLg", model = "M1918BARGreenGoldNoMag" },
        { fullType = "Base.M1918BAR_Bipod", gunPlating = GP("GreenGold"), attachment = "Base.Mag3006ExtLg", model = "M1918BARGreenGoldBipodNoMag" },
        { fullType = "Base.M1918BAR_Melee", gunPlating = GP("GreenGold"), attachment = "Base.Mag3006ExtLg", model = "M1918BARGreenGoldNoMag" },
        { fullType = "Base.SVDDragunov", gunPlating = GP("WinterCamo"), attachment = "Base.MagSVDExtSm", model = "SVDDragunovSnowstormNoMag" },
        { fullType = "Base.SVDDragunov_Melee", gunPlating = GP("WinterCamo"), attachment = "Base.MagSVDExtSm", model = "SVDDragunovSnowstormNoMag" },
        { fullType = "Base.SVDDragunov", gunPlating = GP("Survivalist"), attachment = "Base.MagSVDExtSm", model = "SVDDragunovSurvivalistNoMag" },
        { fullType = "Base.SVDDragunov_Melee", gunPlating = GP("Survivalist"), attachment = "Base.MagSVDExtSm", model = "SVDDragunovSurvivalistNoMag" },
    }

    for _, change in ipairs(gunPlatingExtendedMag) do
        BWTweaks:changeModelByGunPlatingAndAttachment(change.fullType, change.gunPlating, change.attachment, change.model)
    end


    ---===========================================---
    --   FIBERGLASS STOCK ATTACHMENT MODEL SWAPS   --
    ---===========================================---

    --Remington Model 700 Fiberglass
    BWTweaks:changeModelByAttachment("Base.VarmintRifle", "Base.FiberglassStock", "VarmintRifleFGS");
    BWTweaks:changeModelByAttachment("Base.VarmintRifle_Melee", "Base.FiberglassStock", "VarmintRifleFGS");
    --Remington Model 870 Shotgun Fiberglass
    BWTweaks:changeModelByAttachment("Base.Shotgun", "Base.FiberglassStock", "ShotgunFGS");
    BWTweaks:changeModelByAttachment("Base.Shotgun_Melee", "Base.FiberglassStock", "ShotgunFGS");
    --Remington Model 870 Shotgun Fiberglass and Choke
    BWTweaks:changeModelByAttachment("Base.Shotgun", {"Base.FiberglassStock","Base.ChokeTubeFull",}, "ShotgunChokeFGS");
    BWTweaks:changeModelByAttachment("Base.Shotgun_Melee", {"Base.FiberglassStock","Base.ChokeTubeFull",}, "ShotgunChokeFGS");
    BWTweaks:changeModelByAttachment("Base.Shotgun", {"Base.FiberglassStock","Base.ChokeTubeImproved",}, "ShotgunChokeFGS");
    BWTweaks:changeModelByAttachment("Base.Shotgun_Melee", {"Base.FiberglassStock","Base.ChokeTubeImproved",}, "ShotgunChokeFGS");
    --Remington Model 700 DZ WITH fiberglass
    BWTweaks:changeModelByGunPlatingAndAttachment("Base.VarmintRifle", GP("DZ"), "Base.FiberglassStock", "VarmintRifleDZ");
    BWTweaks:changeModelByGunPlatingAndAttachment("Base.VarmintRifle_Melee", GP("DZ"), "Base.FiberglassStock", "VarmintRifleDZ");
    --Remington Model 870 Shotgun Purple WITH Fiberglass
    BWTweaks:changeModelByGunPlatingAndAttachment("Base.Shotgun", GP("Purple"), "Base.FiberglassStock", "ShotgunPurple");
    BWTweaks:changeModelByGunPlatingAndAttachment("Base.Shotgun_Melee", GP("Purple"), "Base.FiberglassStock", "ShotgunPurple");
    --Remington Model 870 Shotgun Purple WITH Fiberglass and Choke
    BWTweaks:changeModelByGunPlatingAndAttachment("Base.Shotgun", GP("Purple"), {"Base.FiberglassStock", "Base.ChokeTubeFull"}, "ShotgunChokePurple");
    BWTweaks:changeModelByGunPlatingAndAttachment("Base.Shotgun_Melee", GP("Purple"), {"Base.FiberglassStock", "Base.ChokeTubeFull"}, "ShotgunChokePurple");
    BWTweaks:changeModelByGunPlatingAndAttachment("Base.Shotgun", GP("Purple"), {"Base.FiberglassStock", "Base.ChokeTubeImproved"}, "ShotgunChokePurple");
    BWTweaks:changeModelByGunPlatingAndAttachment("Base.Shotgun_Melee", GP("Purple"), {"Base.FiberglassStock", "Base.ChokeTubeImproved"}, "ShotgunChokePurple");

    local fiberglassStock = {
        --Remington Model 700  Fiberglassstock
        { fullType = "Base.VarmintRifle", attachment = "Base.FiberglassStock", modelWithMag = "VarmintRifleExtMagFGS", modelWithoutMag = "VarmintRifleFGSNoMag" },
        { fullType = "Base.VarmintRifle_Melee", attachment = "Base.FiberglassStock", modelWithMag = "VarmintRifleExtMagFGS", modelWithoutMag = "VarmintRifleFGSNoMag" },
        --Remington Model 788 Fiberglassstock
        { fullType = "Base.HuntingRifle", attachment = "Base.FiberglassStock", modelWithMag = "HuntingRifleFGS", modelWithoutMag = "HuntingRifleFGSNoMag" },
        { fullType = "Base.HuntingRifle_Melee", attachment = "Base.FiberglassStock", modelWithMag = "HuntingRifleFGS", modelWithoutMag = "HuntingRifleFGSNoMag" },
        --Springfield Armory M14 FiberGlass
        { fullType = "Base.AssaultRifle2", attachment = "Base.FiberglassStock", modelWithMag = "AssaultRifle02FGS", modelWithoutMag = "AssaultRifle02FGSNoMag" },
        { fullType = "Base.AssaultRifle2_Melee", attachment = "Base.FiberglassStock", modelWithMag = "AssaultRifle02FGS", modelWithoutMag = "AssaultRifle02FGSNoMag" },
   }

   for _, change in ipairs(fiberglassStock) do
        BWTweaks:changeModelByAttachmentAndMagPresent(change.fullType, change.attachment, true, change.modelWithMag)
        BWTweaks:changeModelByAttachmentAndMagPresent(change.fullType, change.attachment, false, change.modelWithoutMag)
   end

    local platingAndFiberglassStock = {
        --Remington Model 788 DZ WITH fiberglass
        { fullType = "Base.HuntingRifle", gunPlating = GP("DZ"), attachments = {"Base.FiberglassStock"}, modelWithMag = "HuntingRifleDZ", modelWithoutMag = "HuntingRifleDZNoMag" },
        { fullType = "Base.HuntingRifle_Melee", gunPlating = GP("DZ"), attachments = {"Base.FiberglassStock"}, modelWithMag = "HuntingRifleDZ", modelWithoutMag = "HuntingRifleDZNoMag" }, 
        --Remington Model 788 Dark Cherry WITH fiberglass
        { fullType = "Base.HuntingRifle", gunPlating = GP("DarkCherry"), attachments = {"Base.FiberglassStock"}, modelWithMag = "HuntingRifleDarkCherry", modelWithoutMag = "HuntingRifleDarkCherryNoMag" },
        { fullType = "Base.HuntingRifle_Melee", gunPlating = GP("DarkCherry"), attachments = {"Base.FiberglassStock"}, modelWithMag = "HuntingRifleDarkCherry", modelWithoutMag = "HuntingRifleDarkCherryNoMag" },  
    }

    for _, change in ipairs(platingAndFiberglassStock) do
        BWTweaks:changeModelByGunPlatingAndAttachmentAndMagPresent(change.fullType, change.gunPlating, change.attachments, true, change.modelWithMag)
        BWTweaks:changeModelByGunPlatingAndAttachmentAndMagPresent(change.fullType, change.gunPlating, change.attachments, false, change.modelWithoutMag)
    end


    ---===========================================---
    --         SNIPER SUPPRESSOR MODEL SWAP        --
    ---===========================================---

    local suppressorsSniper = {
        "Base.SuppressorSniper",
        "Base.SuppressorSniperWinter",
        "Base.SuppressorSniperDesert",
        "Base.SuppressorSniperWoodland",
    }

    local typesBarrett = {
        "Base.BarrettM82A1",
        "Base.BarrettM82A1_Melee",
    }

    local gunPlatingBarrett = {
        "GunPlatingSteelDamascus",
        "GunPlatingSalvagedRage",
        "GunPlatingZoidbergSpecial"
    }
    
    -- PGM Hecate Setup
    local typesPGMHecate = {
        "Base.PGMHecate",
        "Base.PGMHecate_Melee",
    }
    local gunPlatingPGMHecate = {
        "GunPlatingTan",
        "GunPlatingBlue",
        "GunPlatingDragonBall",
        "GunPlatingDZ"
    }
    

    -- Suppressor Only
    for _, sup in ipairs(suppressorsSniper) do
        for _, typ in ipairs(typesBarrett) do
            BWTweaks:changeModelByAttachmentAndMagPresent(typ, sup, true, "BarrettM82A1Suppressor")
            BWTweaks:changeModelByAttachmentAndMagPresent(typ, sup, false, "BarrettM82A1NoMagSuppressor")
        end
        for _, typ in ipairs(typesPGMHecate) do
            BWTweaks:changeModelByAttachmentAndMagPresent(typ, sup, true, "PGMHecateSuppressor")
            BWTweaks:changeModelByAttachmentAndMagPresent(typ, sup, false, "PGMHecateNoMagSuppressor")
        end
    end

    -- Suppressor + Bipod
    for _, sup in ipairs(suppressorsSniper) do
        BWTweaks:changeModelByAttachmentAndMagPresent("Base.BarrettM82A1_Bipod", sup, true, "BarrettM82A1BipodSuppressor")
        BWTweaks:changeModelByAttachmentAndMagPresent("Base.BarrettM82A1_Bipod", sup, false, "BarrettM82A1BipodNoMagSuppressor")

        BWTweaks:changeModelByAttachmentAndMagPresent("Base.PGMHecate_Bipod", sup, true, "PGMHecateBipodSuppressor")
        BWTweaks:changeModelByAttachmentAndMagPresent("Base.PGMHecate_Bipod", sup, false, "PGMHecateBipodNoMagSuppressor")
    end

    -- GunPlating + Suppressor combos
    for _, sup in ipairs(suppressorsSniper) do
        for _, typ in ipairs(typesBarrett) do
            for _, plating in ipairs(gunPlatingBarrett) do
                local modelSuffix = plating:gsub("GunPlating", "")
                BWTweaks:changeModelByGunPlatingAndAttachmentAndMagPresent(typ, plating, sup, true, "BarrettM82A1" .. modelSuffix .. "Suppressor")
                BWTweaks:changeModelByGunPlatingAndAttachmentAndMagPresent(typ, plating, sup, false, "BarrettM82A1" .. modelSuffix .. "NoMagSuppressor")
            end
        end

        for _, typ in ipairs(typesPGMHecate) do
            for _, plating in ipairs(gunPlatingPGMHecate) do
                local modelSuffix = plating:gsub("GunPlating", "")
                BWTweaks:changeModelByGunPlatingAndAttachmentAndMagPresent(typ, plating, sup, true, "PGMHecate" .. modelSuffix .. "Suppressor")
                BWTweaks:changeModelByGunPlatingAndAttachmentAndMagPresent(typ, plating, sup, false, "PGMHecate" .. modelSuffix .. "NoMagSuppressor")
            end
        end
    end

    -- GunPlating + Suppressor + Bipod
    for _, sup in ipairs(suppressorsSniper) do
        for _, plating in ipairs(gunPlatingBarrett) do
            local modelSuffix = plating:gsub("GunPlating", "")
            BWTweaks:changeModelByGunPlatingAndAttachmentAndMagPresent("Base.BarrettM82A1_Bipod", plating, sup, true, "BarrettM82A1" .. modelSuffix .. "BipodSuppressor")
            BWTweaks:changeModelByGunPlatingAndAttachmentAndMagPresent("Base.BarrettM82A1_Bipod", plating, sup, false, "BarrettM82A1" .. modelSuffix .. "BipodNoMagSuppressor")
        end

        for _, plating in ipairs(gunPlatingPGMHecate) do
            local modelSuffix = plating:gsub("GunPlating", "")
            BWTweaks:changeModelByGunPlatingAndAttachmentAndMagPresent("Base.PGMHecate_Bipod", plating, sup, true, "PGMHecate" .. modelSuffix .. "BipodSuppressor")
            BWTweaks:changeModelByGunPlatingAndAttachmentAndMagPresent("Base.PGMHecate_Bipod", plating, sup, false, "PGMHecate" .. modelSuffix .. "BipodNoMagSuppressor")
        end
    end

    ---===========================================---
    --         CHAMBERED ROUND MODEL SWAPS         --
    ---===========================================---

    -- Compound Crossbow
    local chamberedChange = {
        { fullType = "Base.CrossbowCompound", loaded  = "CrossbowCompoundLoaded", empty = "CrossbowCompound" },
        { fullType = "Base.CrossbowCompound_Melee", loaded  = "CrossbowCompoundLoaded", empty = "CrossbowCompound" },
        { fullType = "Base.CrossbowReverseDraw", loaded  = "CrossbowReverseDrawLoaded", empty = "CrossbowReverseDraw" },
        { fullType = "Base.CrossbowReverseDraw_Melee", loaded  = "CrossbowReverseDrawLoaded", empty = "CrossbowReverseDraw" },
        { fullType = "Base.CrossbowPistol", loaded  = "CrossbowPistolLoaded", empty = "CrossbowPistol" },
        { fullType = "Base.CrossbowPistol_Melee", loaded  = "CrossbowPistolLoaded", empty = "CrossbowPistol" },
    }
    
    for _, change in ipairs(chamberedChange) do
        BWTweaks:changeModelByRoundChambered(change.fullType, true, change.loaded )
        BWTweaks:changeModelByRoundChambered(change.fullType, false, change.empty)
    end

    -- Compound Crossbow Gunplating Changes
    local chamberedGunPlatingChange  = {
        { fullType = "Base.CrossbowCompound", plating = GP("RedWhite"), loaded = "CrossbowCompoundLoadedRedWhite", empty = "CrossbowCompoundRedWhite" },
        { fullType = "Base.CrossbowCompound_Melee", plating = GP("RedWhite"), loaded = "CrossbowCompoundLoadedRedWhite", empty = "CrossbowCompoundRedWhite" },
        { fullType = "Base.CrossbowReverseDraw", plating = GP("Patriot"), loaded = "CrossbowReverseDrawLoadedPatriot", empty = "CrossbowReverseDrawPatriot" },
        { fullType = "Base.CrossbowReverseDraw_Melee", plating = GP("Patriot"), loaded = "CrossbowReverseDrawLoadedPatriot", empty = "CrossbowReverseDrawPatriot" },
        { fullType = "Base.CrossbowReverseDraw", plating = GP("Green"), loaded = "CrossbowReverseDrawLoadedCamo", empty = "CrossbowReverseDrawCamo" },
        { fullType = "Base.CrossbowReverseDraw_Melee", plating = GP("Green"), loaded = "CrossbowReverseDrawLoadedCamo", empty = "CrossbowReverseDrawCamo" },
        { fullType = "Base.CrossbowReverseDraw", plating = GP("Blue"), loaded = "CrossbowReverseDrawLoadedBlue", empty = "CrossbowReverseDrawBlue" },
        { fullType = "Base.CrossbowReverseDraw_Melee", plating = GP("Blue"), loaded = "CrossbowReverseDrawLoadedBlue", empty = "CrossbowReverseDrawBlue" },
    }
    

    for _, change in ipairs(chamberedGunPlatingChange) do
        BWTweaks:changeModelByGunPlatingAndRoundChambered(change.fullType, change.plating, true, change.loaded)
        BWTweaks:changeModelByGunPlatingAndRoundChambered(change.fullType, change.plating, false, change.empty)
    end

    -- Wood Crossbow Changes
    local chamberedWoodChange = {
        { fullType = "Base.CrossbowCompound", material = "wood", loaded = "WoodCrossbowCompoundLoaded", empty = "CrossbowCompound" },
        { fullType = "Base.CrossbowCompound_Melee", material = "wood", loaded = "WoodCrossbowCompoundLoaded", empty = "CrossbowCompound" },
        { fullType = "Base.CrossbowReverseDraw", material = "wood", loaded = "WoodCrossbowReverseDrawLoaded", empty = "CrossbowReverseDraw" },
        { fullType = "Base.CrossbowReverseDraw_Melee", material = "wood", loaded = "WoodCrossbowReverseDrawLoaded", empty = "CrossbowReverseDraw" },
        { fullType = "Base.CrossbowPistol", material = "wood", loaded = "WoodCrossbowPistolLoaded", empty = "CrossbowPistol" },
        { fullType = "Base.CrossbowPistol_Melee", material = "wood", loaded = "WoodCrossbowPistolLoaded", empty = "CrossbowPistol" },
    }

    for _, change in ipairs(chamberedWoodChange) do
        BWTweaks:changeModelByRoundChamberedAndMaterial(change.fullType, true, change.material, change.loaded)
        BWTweaks:changeModelByRoundChamberedAndMaterial(change.fullType, false, change.material, change.empty)
    end

    -- Wood + Gun Plating Changes
    local chamberedGunPlatingWoodChange = {
        { fullType = "Base.CrossbowCompound", plating = GP("RedWhite"), material = "wood", loaded = "WoodCrossbowCompoundLoadedRedWhite", empty = "CrossbowCompoundRedWhite" },
        { fullType = "Base.CrossbowCompound_Melee", plating = GP("RedWhite"), material = "wood", loaded = "WoodCrossbowCompoundLoadedRedWhite", empty = "CrossbowCompoundRedWhite" },
        { fullType = "Base.CrossbowReverseDraw", plating = GP("Patriot"), material = "wood", loaded = "WoodCrossbowReverseDrawLoadedPatriot", empty = "WoodCrossbowReverseDrawPatriot" },
        { fullType = "Base.CrossbowReverseDraw_Melee", plating = GP("Patriot"), material = "wood", loaded = "WoodCrossbowReverseDrawLoadedPatriot", empty = "WoodCrossbowReverseDrawPatriot" },
        { fullType = "Base.CrossbowReverseDraw", plating = GP("Green"), material = "wood", loaded = "WoodCrossbowReverseDrawLoadedCamo", empty = "WoodCrossbowReverseDrawCamo" },
        { fullType = "Base.CrossbowReverseDraw_Melee", plating = GP("Green"), material = "wood", loaded = "WoodCrossbowReverseDrawLoadedCamo", empty = "WoodCrossbowReverseDrawCamo" },
        { fullType = "Base.CrossbowReverseDraw", plating = GP("Blue"), material = "wood", loaded = "WoodCrossbowReverseDrawLoadedBlue", empty = "WoodCrossbowReverseDrawBlue" },
        { fullType = "Base.CrossbowReverseDraw_Melee", plating = GP("Blue"), material = "wood", loaded = "WoodCrossbowReverseDrawLoadedBlue", empty = "WoodCrossbowReverseDrawBlue" },
    }

    for _, change in ipairs(chamberedGunPlatingWoodChange) do
        BWTweaks:changeModelByGunPlatingAndRoundChamberedAndMaterial(change.fullType, change.plating, true, change.material, change.loaded)
        BWTweaks:changeModelByGunPlatingAndRoundChamberedAndMaterial(change.fullType, change.plating, false, change.material, change.empty)
    end

    ---===========================================---
    --            TACTICAL LASER TOGGLE            --
    ---===========================================---

    local weapons = {
        "Base.AssaultRifle",
        "Base.AssaultRifle_Melee",
        "Base.PLR16",
        "Base.PLR16_Melee",
        "Base.MosinNagantObrez",
        "Base.MosinNagantObrez_Melee",
        "Base.CrossbowCompound",
        "Base.CrossbowCompound_Melee",
        "Base.CrossbowReverseDraw",
        "Base.CrossbowReverseDraw_Melee",
        "Base.CrossbowPistol",
        "Base.CrossbowPistol_Melee",
        "Base.AK74U",
        "Base.AK74U_Folded",
        "Base.AK74U_Melee",
        "Base.AK74U_Folded_Melee",
        "Base.MP28",
        "Base.MP28_Melee",
        "Base.ThompsonM1921",
        "Base.ThompsonM1921_Melee",
        "Base.AK103",
        "Base.AK103_Melee",
        "Base.AK74",
        "Base.AK74_Melee",
        "Base.HenryRepeatingBigBoy",
        "Base.HenryRepeatingBigBoy_Melee",
        "Base.BrowningBLR",
        "Base.BrowningBLR_Melee",
        "Base.Marlin39A",
        "Base.Marlin39A_Melee",
        "Base.GrozaOTs14",
        "Base.GrozaOTs14_Melee",
        "Base.SIG550",
        "Base.SIG550_Melee",
        "Base.StG44",
        "Base.StG44_Melee",
        "Base.MosinNagant",
        "Base.MosinNagant_Melee",
        "Base.L2A1",
        "Base.L2A1_Bipod",
        "Base.L2A1_Melee",
        "Base.EM2",
        "Base.EM2_Melee",
        "Base.L85A1",
        "Base.L85A1_Melee",
        "Base.ASVal",
        "Base.ASVal_Melee",
        "Base.ASVal_Folded",
        "Base.ASVal_Folded_Melee",
        "Base.M4A1",
        "Base.M4A1_Melee",
        "Base.Ruger1022",
        "Base.Ruger1022_Melee",
        "Base.SVDDragunov",
        "Base.SVDDragunov_Melee",
        "Base.Galil",
        "Base.Galil_Bipod",
        "Base.Galil_Melee",
        "Base.VSSVintorez",
        "Base.VSSVintorez_Melee",
        "Base.Springfield1861",
        "Base.Springfield1861_Melee",
        "Base.PneumaticBlowgun",
        "Base.PneumaticBlowgun_Melee",
    }

    local laserColors = {
        { attachment = "Base.LaserGreen", translate = "IGUI_HFA_LaserGreen" },
        { attachment = "Base.LaserRed", translate = "IGUI_HFA_LaserRed" },
    }

    for _, weaponType in ipairs(weapons) do
        for _, colorData in ipairs(laserColors) do
            BWTweaks:addToggleOption(weaponType, "Base.LaserNoLight", colorData.attachment, colorData.translate)
        end
    end

end);