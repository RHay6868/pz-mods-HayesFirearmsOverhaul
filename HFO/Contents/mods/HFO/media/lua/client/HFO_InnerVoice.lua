---===========================================================---
--                      HFO_InnerVoice.lua                     --
---===========================================================---
-- Description:
--   This module handles the "Inner Voice" system used across the
--   It provides in-game contextual feedback based on weapon
--   state changes, actions (e.g., cleaning, reloading, mode
--   switches), and various upgrades or malfunctions.
--
--   The system supports three verbosity levels:
--     0 = Off (no inner voice output)
--     1 = Simple (short feedback lines)
--     2 = Verbose (flavorful randomized lines)
--
--   Messages are triggered from various modules including reload
--   logic, utility tools, UI events, and player interaction scripts.
--
-- Key Features:
--   - Dynamic commentary system tied to mod actions and outcomes.
--   - Toggleable setting, stored in player modData.
--   - Extensive mapping table for standardized response keys.
--   - Localization-ready design by centralizing output text here.
--
-- Dependencies:
--   - HFO.Utils.PlayerSay()
--   - Sandbox variable access through modData
--
-- Notes:
--   - Designed to be immersive but unobtrusive.
--   - Modular design allows other HFO systems to extend easily.
---===========================================================---

HFO = HFO or {}
HFO.Utils = HFO.Utils or {}
HFO.InnerVoice = HFO.InnerVoice or {}


---===========================================---
--     INTEGRATED CONTEXTUAL HALO MESSAGES     --
---===========================================---

-- 0 = OFF, 1 = SIMPLE, 2 = VERBOSE
function HFO.InnerVoice.getLevel()
	local player = getSpecificPlayer(0)
	if not player then return 0 end -- default OFF if no player

	local level = player:getModData().HFO_InnerVoiceLevel
	if level == nil then return 1 end -- default to SIMPLE
	return tonumber(level)
end

function HFO.InnerVoice.setLevel(newLevel)
	local player = getSpecificPlayer(0)
	if player then
		player:getModData().HFO_InnerVoiceLevel = newLevel
	end
end


---===========================================---
--   TOGGLE BETWEEN OFF, SIMPLE, AND VERBOSE   --
---===========================================---

function HFO.InnerVoice.InnerVoiceToggle(keyNum)
	local player = getSpecificPlayer(0)
	if not player then return end

	local md = player:getModData()
	local current = tonumber(md.HFO_InnerVoiceLevel) or 1
	local new = (current + 1) % 3 -- 0 > 1 > 2 > 0 loop

	md.HFO_InnerVoiceLevel = new

	local msg = ({ "Inner Voice: Off", "Inner Voice: Simple", "Inner Voice: Verbose" })[new + 1]
	HFO.Utils.PlayerSay(msg)
end

function HFO.InnerVoice.say(category)
	local level = HFO.InnerVoice.getLevel()
	if level == 0 then return end -- Silent

	local lines = HFO.InnerVoice.LINES[category]
	if not lines then return end

	if level == 1 and lines.simple then
		HFO.Utils.PlayerSay(lines.simple)
	elseif level == 2 and lines.verbose then
		local line = lines.verbose[ZombRand(#lines.verbose) + 1]
		HFO.Utils.PlayerSay(line)
	end
end


---===========================================---
--      MAPPING TO SPECIFIC FUNCTION CALLS     --
---===========================================---

HFO.InnerVoice.map = {
    -- Firemode Mapping
	Single        = "FiremodeSingle",
	FullAuto      = "FiremodeAuto",
	SMGFullAuto   = "FiremodeAuto",
	CustomBurst   = "FiremodeBurst",
	SMGBurst      = "FiremodeBurst",

    -- Magazine Type Mapping
	MagBase       = "MagSwapDefault",
	MagExtSm      = "MagSwapSmall",
	MagExtLg      = "MagSwapLarge",
	MagDrum       = "MagSwapDrum",
}


---===========================================---
--         VARIOUS INNER VOICE DIALOGUE        --
---===========================================---

HFO.InnerVoice.LINES = HFO.InnerVoice.LINES or {
    AmmoSwapDefault = {
        simple = "Swapped ammo type",
        verbose = {
            "Standard rounds loaded",
            "Back to the basics",
            "Default caliber in place",
            "Running what it's made for",
        },
    },
    AmmoSwapBirdshot = {
        simple = "Loading birdshot",
        verbose = {
            "Smaller pellets, wider spread",
            "Feathers beware",
            "Loaded up with birdshot",
            "Great for crowd control, not so much for armor",
        },
    },
    AmmoSwapSlug = {
        simple = "Loading slugs",
        verbose = {
            "One shot, one slug",
            "These'll punch clean through",
            "Swapped to slugs — aim matters now",
            "Forget spread, we’re going solid",
        },
    },
    AmmoSwap556 = {
        simple = "Swapped to 5.56",
        verbose = {
            "Loaded NATO rounds",
            "Standard 5.56 in the pipe",
            "Same punch, faster burn",
            "Nothing wrong with a little military surplus",
        },
    },
    AmmoSwapWoodBolt = {
        simple = "Wooden bolts loaded",
        verbose = {
            "Primitive, but it’ll fly",
            "Swapped to wood bolts — quiet and simple",
            "Not fancy, but it’ll do the job",
            "Back to basics with wood bolts",
        },
    },
    AmmoSwapGeneric = {
        simple = "Swapped ammo type",
        verbose = {
            "New caliber loaded",
            "Different round, same gun",
            "Let’s see how this feeds",
            "Hope this one hits harder",
        },
    },
    NoAmmoSwapAvailable = {
        simple = "No alternate ammo found",
        verbose = {
            "You're stuck with what’s loaded",
            "No spare ammo types in reach",
            "Nothing else fits this chamber",
            "Looks like that’s the only type on hand",
        },
    },
    CleanBonusSuccess = {
		simple = "Weapon cleaned and improved",
		verbose = {
            "Looks like it's almost brand new",
            "That cleaned up nicely",
            "That should buy us some time",
            "Nice. Reduced some wear too",
            "Not perfect, but a hell of a lot better",
            "Condition’s back and repair count’s down. Win-win",
		},
	},
	CleanSuccess = {
		simple = "Weapon cleaned",
		verbose = {
			"Grime’s gone — should shoot smoother",
			"Looks better already",
			"All cleaned up and ready to go",
            "That's more like it",
		},
	},
	CleanFail = {
		simple = "Cleaning had no effect",
		verbose = {
			"Huh... still not right",
			"Didn’t make much difference",
			"Guess that didn’t help",
		},
	},
    SwappedToMelee = {
        simple = "Switched to melee mode",
        verbose = {
            "Going hands-on...",
            "Let’s keep it quiet",
            "Switched to close quarters",
        },
    },
    SwappedToRanged = {
        simple = "Switched to ranged mode",
        verbose = {
            "Back to firing distance",
            "Let's put some space between us",
            "Reloaded and ranged again",
        },
    },
    SuppressorWearing = {
        simple = "Suppressor wearing down",
        verbose = {
            "Feels louder... suppressor might be going",
            "That didn’t sound right. Suppressor’s struggling",
            "Noise control’s slipping — might need a replacement",
        },
    },
    SuppressorBroken = {
        simple = "Suppressor broke",
        verbose = {
            "Suppressor just gave out",
            "That was the last shot it could take",
            "Broke clean off — back to loud",
        },
    },
    FiremodeSingle = {
        simple = "Switched to semi-auto",
        verbose = {
            "One shot at a time.",
            "Precise and steady.",
            "No room for error now.",
        },
    },
    FiremodeAuto = {
        simple = "Full auto selected",
        verbose = {
            "Time to spray",
            "Let’s make some noise",
            "Hold and pray",
        },
    },
    FiremodeBurst = {
        simple = "Burst fire enabled",
        verbose = {
            "Triple tap. Controlled chaos",
            "One pull, three down",
            "Three’s enough — if you hit",
        },
    },
    SpeedloaderUsed = {
        simple = "Used Speedloader",
        verbose = {
            "Quick reload with the speedloader",
            "Snapped the rounds in fast",
            "Speedloader did the trick",
            "That was faster — back in action",
        },
    },
	NoMagSwapAvailable = {
        simple = "No other magazines available.",
        verbose = {
            "You're stuck with this mag for now.",
            "No alternative magazines in sight.",
            "That’s the only mag you’ve got.",
            "Try looting for more magazines.",
            "This one’s your only option right now.",
        },
	},
	MagSwapDefault = {
		simple = "Standard mag equipped.",
		verbose = {
			"Back to basics.",
			"Standard magazine loaded in.",
			"Nothing fancy, just reliable.",
		},
	},
	MagSwapSmall = {
		simple = "Small extended mag.",
		verbose = {
			"Not much more, but it helps.",
			"Extended mag (small) loaded.",
			"A few extra shots never hurt.",
		},
	},
	MagSwapLarge = {
		simple = "Large extended mag.",
		verbose = {
			"More firepower, less reloads.",
			"Large mag secured.",
			"Loaded for longer fights.",
		},
	},
	MagSwapDrum = {
		simple = "Drum mag loaded.",
		verbose = {
			"Drum in place. Let it rip.",
			"This one’s for when things get ugly.",
			"Maximum capacity ready.",
		},
	},
    MeleeBlockUpgrade = {
        simple = "Cannot remove parts in melee mode.",
        verbose = {
            "Not happening — you’ll need to switch out of melee mode first.",
            "Nope. Can't change attachments while this thing’s a blunt object.",
            "Better not mess with parts while swinging it like a bat.",
        },
	},
    MeleeBlockMagazine = {
        simple = "Magazine removal blocked.",
        verbose = {
            "Magazine’s locked in tight. Try again in ranged mode.",
            "Can’t eject mags while in melee mode.",
            "Not with the current setup. You’ll need to switch back to fire mode first.",
        },
	},
    ReloadBoost = {
        simple = "Reload boost applied.",
        verbose = {
            "Installed a fast-reload mod.",
            "Should shave some time off reloads.",
            "Reloads might feel smoother after this.",
        },
    },
    AmmoSwap223To556 = {
        simple = "Loaded 5.56mm rounds.",
        verbose = {
            "Switching to NATO standard — 5.56 it is.",
            "Lightweight, versatile. Time to move fast.",
            "Let’s see what the 5.56 can do.",
        },
    },
    AmmoSwap556To223 = {
        simple = "Loaded .223 rounds.",
        verbose = {
            "Back to civilian-grade .223 — should still do the job.",
            "Lighter recoil. Better control.",
            "Let’s keep things precise.",
        },
    },
    AmmoSwap308To762 = {
        simple = "Switched to 7.62x51.",
        verbose = {
            "Going full power — 7.62 locked in.",
            "Military-grade firepower now chambered.",
            "Not subtle, but it gets the job done.",
        },
    },
    AmmoSwap762To308 = {
        simple = "Loaded .308 rounds.",
        verbose = {
            "Back to .308. Still packs a punch.",
            "Reliable and accurate — I’ll take it.",
            "Smoother recoil, same intent.",
        },
    },
    AmmoSwapBuckToBird = {
        simple = "Loaded birdshot.",
        verbose = {
            "Swapping out buckshot for something lighter.",
            "Birdshot chambered — won’t punch through, but it’ll sting.",
            "Spread’s wider now. Gotta be close.",
        },
    },
    AmmoSwapBirdToBuck = {
        simple = "Loaded buckshot.",
        verbose = {
            "Back to buckshot — heavier hit incoming.",
            "Loaded up to do real damage.",
            "More lead, less mercy.",
        },
    },
    AmmoSwapBirdToSlug = {
        simple = "Loaded slug rounds.",
        verbose = {
            "No more scatter — time to punch holes.",
            "Slugs in. Going straight and hard.",
            "One big hit. Let’s make it count.",
        },
    },
    AmmoSwapSlugToBird = {
        simple = "Loaded birdshot.",
        verbose = {
            "Switched from slugs to a lighter spread.",
            "Going soft. Birdshot chambered.",
            "Back to light work. More spray, less punch.",
        },
    },
    AmmoSwapBuckToSlug = {
        simple = "Switched to slugs.",
        verbose = {
            "Upgraded from spread to precision.",
            "Swapped out buck for slugs — fewer shots, more punch.",
            "This time, one shot needs to matter.",
        },
    },
    AmmoSwapSlugToBuck = {
        simple = "Back to buckshot.",
        verbose = {
            "Let’s spread the love again — buckshot loaded.",
            "More pellets, more chances.",
            "Back to crowd control mode.",
        },
    },
    AmmoSwapToWoodBolt = {
        simple = "Using wooden bolts.",
        verbose = {
            "Swapped to wooden bolts. Not ideal, but it’ll do.",
            "Quiet... but a little more fragile.",
            "Better save the steel for something tougher.",
        },
    },
    AmmoSwapToSteelBolt = {
        simple = "Switched to steel bolts.",
        verbose = {
            "Steel bolts ready — time to pierce clean through.",
            "Precision reload. These won’t bend easy.",
            "Now that’s more like it.",
        },
    },
    WeaponJammed = {
        simple = "Firearm jammed.",
        verbose = {
            "Click. Damn, it jammed.",
            "Not now… gun’s stuck.",
            "Jam. Figures.",
            "Weapon’s not cooperating — jammed up tight.",
        },
    },
    WeaponInspect = {
        simple = "Inspecting firearm.",
        verbose = {
            "Let’s see what condition this thing’s in...",
            "Gotta make sure everything’s in place.",
            "Looking over the firearm — better safe than sorry.",
        },
    },
    WeaponInspectFailed = {
        simple = "Need a firearm to inspect.",
        verbose = {
            "Hard to inspect something I’m not even holding.",
            "Well... no gun, no inspection.",
            "Might want to grab a firearm first.",
        },
    },
    WeaponSawedOff = {
        simple = "Firearm Sawn Off.",
        verbose = {
            "Sawed off the barrel — compact and risky.",
            "It won’t win any beauty contests now.",
            "Cut it down to size. Just hope it still works.",
        },
    },
    OpenedCache = {
        simple = "Opened firearm cache.",
        verbose = {
            "Jackpot — let’s see what’s inside.",
            "Cracked the cache. Hope it’s not junk.",
            "Opening it up... fingers crossed.",
        },
    },
    OpenedAmmoCan = {
        simple = "Ammo can opened.",
        verbose = {
            "Ammo secured. Feels like Christmas.",
            "Let’s fill some mags.",
            "Loaded up. This’ll come in handy.",
        },
    },
    BoltBroke = {
        simple = "Bolt shattered",
        verbose = {
            "Snapped on impact. No saving it.",
            "That one’s toast.",
            "Too brittle for a second shot.",
            "Damn — snapped clean.",
            "Well, that one's done for.",
            "Definitely not reusing that.",
        },
    },
    BoltRecovered = {
        simple = "Bolt looks recoverable",
        verbose = {
            "Lucky — got the bolt back.",
            "Intact and reusable.",
            "Still good. I’ll take it.",
            "I see it still sticking out — might get it back.",
            "Could probably recover that after the kill.",
            "Nice shot — should be reusable.",
        },
    },
    DartBroke = {
        simple = "Dart shattered",
        verbose = {
            "Snapped on impact. No saving it.",
            "That one’s toast.",
            "Too brittle for a second shot.",
            "Damn — snapped clean.",
            "Well, that one's done for.",
            "Definitely not reusing that.",
        },
    },
    DartRecovered = {
        simple = "Dart looks recoverable",
        verbose = {
            "Lucky — got the dart back.",
            "Intact and reusable.",
            "Still good. I’ll take it.",
            "I see it still sticking out — might get it back.",
            "Could probably recover that after the kill.",
            "Nice shot — should be reusable.",
        },
    },
    TShirtHit = {
        simple = "Shirt delivery successful",
        verbose = {
            "Right in the fashion zone.",
            "Well-placed cotton cannonball.",
            "Who knew soft could hit hard?",
            "Bullseye. Laundry inbound.",
            "That one left a mark.",
            "Tag, you're it — in cotton.",
        },
    },
    TShirtMissed = {
        simple = "Shirt missed",
        verbose = {
            "That shirt’s gone forever.",
            "Overshot — hope someone finds it.",
            "Fashionably lost.",
            "Not every shot's a fashion statement.",
            "Hope someone picks that up.",
            "Wrong size. Try again.",
        },
    },
    MagsLoaded = {
        simple = "Magazines loaded.",
        verbose = {
            "Bulk reload complete.",
            "Stacked and ready.",
            "Full mags across the board.",
        },
    },
    MagsUnloaded = {
        simple = "Magazines unloaded.",
        verbose = {
            "Cleared the mags out.",
            "Unloading complete.",
            "No rounds left loaded.",
        },
    },
    AdminMagLoad = {
        simple = "Admin override: magazines filled.",
        verbose = {
            "All mags topped off. Perks of the badge.",
            "Instant reload? Must be nice.",
            "Magazines loaded — admin style.",
        },
    },
    WrapAppliedWoodland = {
        simple = "Woodland wrap on.",
        verbose = {
            "Wrapped and ready for the deep woods.",
            "Nature camo engaged.",
            "Green and mean.",
        },
    },
    WrapAppliedWinter = {
        simple = "Winter wrap on.",
        verbose = {
            "Snow patrol mode activated.",
            "Time to blend with the frost.",
            "Whiteout ready.",
        },
    },
    WrapAppliedDesert = {
        simple = "Desert wrap on.",
        verbose = {
            "Desert ops ready.",
            "Blend in with the dunes.",
            "Heat camo, applied.",
        },
    },
    WrapRemoved = {
        simple = "Wrap removed.",
        verbose = {
            "Back to classic black.",
            "Shedding some camo.",
            "Gone minimalist."
        }
    }
}