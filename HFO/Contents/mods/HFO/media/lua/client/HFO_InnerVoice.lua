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
	HFO_MagBase   = "MagSwapDefault",
	HFO_MagExtSm  = "MagSwapSmall",
	HFO_MagExtLg  = "MagSwapLarge",
	HFO_MagDrum   = "MagSwapDrum",
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
            "Standard rounds back in action.",
            "Factory specs — reliable as always.",
            "Nothing beats the original.",
            "Back to what it was designed for.",
        },
    },
    AmmoSwapBirdshot = {
        simple = "Loading birdshot",
        verbose = {
            "Smaller pellets, wider spread",
            "Feathers beware",
            "Loaded up with birdshot",
            "Great for crowd control, not so much for armor",
            "Pattern over power.",
            "Wide spread, less penetration.",
            "Perfect for close encounters.",
        },
    },
    AmmoSwapSlug = {
        simple = "Loading slugs",
        verbose = {
            "One shot, one slug",
            "These'll punch clean through",
            "Swapped to slugs — aim matters now",
            "Forget spread, we’re going solid",
            "Single projectile, maximum impact.",
            "Time to make every shot count.",
            "No scatter — just raw power.",
            "Precision over spread.",
        },
    },
    AmmoSwap556 = {
        simple = "Swapped to 5.56",
        verbose = {
            "Loaded NATO rounds",
            "Standard 5.56 in the pipe",
            "Same punch, faster burn",
            "Nothing wrong with a little military surplus",
            "NATO standard loaded and ready.",
            "High velocity, low recoil.",
            "Military surplus has its perks.",
        },
    },
    AmmoSwapWoodBolt = {
        simple = "Wooden bolts loaded",
        verbose = {
            "Primitive, but it’ll fly",
            "Swapped to wood bolts — quiet and simple",
            "Not fancy, but it will do the job",
            "Back to basics with wood bolts",
            "Old school approach.",
            "Quiet and easy to make.",
            "Simple materials, same result.",
            "Wood works when metal is scarce.",
        },
    },
    AmmoSwapGeneric = {
        simple = "Swapped ammo type",
        verbose = {
            "New caliber loaded",
            "Different round, same gun",
            "Let’s see how this feeds",
            "Hope this one hits harder",
            "Different round, same purpose.",
            "Let's test this combination.",
            "Mixing things up a bit.",
            "Variety keeps things interesting.",
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
            "Like turning back the clock.",
            "Better than factory condition now.",
            "That's how you maintain equipment.",
            "Professional cleaning pays off.",
		},
	},
	CleanSuccess = {
		simple = "Weapon cleaned",
		verbose = {
			"Grime’s gone — should shoot smoother",
			"Looks better already",
			"All cleaned up and ready to go",
            "That's more like it",
            "Smooth operation restored.",
            "Clean gun, clear conscience.",
            "Maintenance matters.",
            "Back to fighting condition.",
		},
	},
	CleanFail = {
		simple = "Cleaning had no effect",
		verbose = {
			"Huh... still not right",
			"Didn’t make much difference",
			"Guess that didn’t help",
            "Some problems run deeper.",
            "Not every issue's surface-level.",
            "Might need professional help.",
            "Well, that was a waste of time.",
		},
	},
    SwappedToMelee = {
        simple = "Switched to melee mode",
        verbose = {
            "Going hands-on...",
            "Let’s keep it quiet",
            "Switched to close quarters",
            "Time for close-quarters work.",
            "Up close and personal now.",
            "Old school conflict resolution.",
            "Let's get personal.",
        },
    },
    SwappedToRanged = {
        simple = "Switched to ranged mode",
        verbose = {
            "Back to firing distance",
            "Let's put some space between us",
            "Reloaded and ranged again",
            "Distance is our friend again.",
            "Back to proper firearm mode.",
            "Need to keep my distance now",
            "Ranged advantage restored.",
        },
    },
    SuppressorWearing = {
        simple = "Suppressor wearing down",
        verbose = {
            "Feels louder... suppressor might be going",
            "That didn’t sound right. Suppressor’s struggling",
            "Noise control’s slipping — might need a replacement",
            "That's not supposed to sound like that.",
            "Suppressor's losing its grip.",
            "Definitely getting louder each shot.",
            "Time to start shopping for a replacement.",
        },
    },
    SuppressorBroken = {
        simple = "Suppressor broke",
        verbose = {
            "Suppressor just gave out",
            "That was the last shot it could take",
            "Broke clean off — back to loud",
            "Well, there goes the quiet approach.",
            "Suppressor's done its last job.",
            "Back to making noise.",
        },
    },
    FiremodeSingle = {
        simple = "Switched to semi-auto",
        verbose = {
            "One shot at a time.",
            "Precise and steady.",
            "No room for error now.",
            "Controlled fire mode.",
            "Make every shot deliberate.",
            "Quality over quantity.",
            "Precision shooting enabled.",
        },
    },
    FiremodeAuto = {
        simple = "Full auto selected",
        verbose = {
            "Time to spray",
            "Let’s make some noise",
            "Hold and pray",
            "Maximum firepower unleashed.",
            "When subtlety isn't an option.",
            "Bullet hose engaged.",
        },
    },
    FiremodeBurst = {
        simple = "Burst fire enabled",
        verbose = {
            "Triple tap. Controlled chaos",
            "One pull, three down",
            "Three’s enough — if you hit",
            "Controlled burst mode.",
            "Three-round discipline.",
            "Burst fire — best of both worlds.",
            "Short bursts, long effectiveness.",
        },
    },
    SpeedloaderUsed = {
        simple = "Used Speedloader",
        verbose = {
            "Quick reload with the speedloader",
            "Snapped the rounds in fast",
            "Speedloader did the trick",
            "That was faster — back in action",
            "Cylinder topped off in record time.",
            "Speed reload complete.",
            "Back in business, fast.",
            "That's why they call it a speedloader.",
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
            "This is all the magazine I've got.",
            "Need to find more mag options.",
            "Stuck with current capacity.",
            "Time to go shopping for magazines.",
        },
	},
	MagSwapDefault = {
		simple = "Standard mag equipped.",
		verbose = {
			"Back to basics.",
			"Standard magazine loaded in.",
			"Nothing fancy, just reliable.",
            "Back to factory standard.",
            "Reliable capacity restored.",
            "Our main magazine back in place.",
            "Original specs, original reliability.",
		},
	},
	MagSwapSmall = {
		simple = "Small extended mag.",
		verbose = {
			"Not much more, but it helps.",
			"Extended mag (small) loaded.",
			"A few extra shots never hurt.",
            "A little extra never hurts.",
            "Modest upgrade in capacity.",
            "Small extension, big difference.",
            "Every extra round counts.",
		},
	},
	MagSwapLarge = {
		simple = "Large extended mag.",
		verbose = {
			"More firepower, less reloads.",
			"Large mag secured.",
			"Loaded for longer fights.",
            "Now we're talking capacity.",
            "Extended firepower ready.",
            "More ammo, fewer interruptions.",
            "Large mag means longer engagements.",
		},
	},
	MagSwapDrum = {
		simple = "Drum mag loaded.",
		verbose = {
			"Drum in place. Let it rip.",
			"This one’s for when things get ugly.",
			"Maximum capacity ready.",
            "High capacity, high expectations.",
            "Drum loaded — time to party.",
            "Maximum rounds for maximum chaos.",
            "This should keep them busy.",
		},
	},
    MeleeBlockUpgrade = {
        simple = "Cannot remove parts in melee mode.",
        verbose = {
            "Not happening — you’ll need to switch out of melee mode first.",
            "Nope. Can't change attachments while this thing’s a blunt object.",
            "Better not mess with parts while swinging it like a bat.",
            "Can't modify while it's a club.",
            "Need to switch back to firearm mode first.",
        },
	},
    BlockMagazineUpgrade = {
        simple = "Magazine cannot be removed this way.",
        verbose = {
            "Can't remove this through weapon modifications I should just reload normally.",
            "This magazine isn't removable as a weapon part.",
            "I should try reloading normally instead of removing it as a modification.",
            "Of course I need to use the eject function instead.",
            "This magazine only works through normal reloading, not part removal.",
            "Wrong approach I just reload normally to swap magazines.",
        },
	},
    ReloadBoost = {
        simple = "Reload boost applied.",
        verbose = {
            "Installed a fast-reload mod.",
            "Should shave some time off reloads.",
            "Reloads might feel smoother after this.",
            "Speed reload modification installed.",
            "Reload times just got better.",
            "Faster reloads, more action.",
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
            "Feed malfunction — great timing.",
            "Jammed up at the worst moment.",
            "Mechanical failure, naturally gun gets jammed.",
            "Of course it jams now.",
        },
    },
    WeaponInspect = {
        simple = "Inspecting firearm.",
        verbose = {
            "Let’s see what condition this thing’s in...",
            "Gotta make sure everything’s in place.",
            "Looking over the firearm — better safe than sorry.",
            "Time for a condition check.",
            "Let's see what we're working with.",
            "Examining the hardware.",
            "Better know what shape this is in.",
        },
    },
    WeaponInspectFailed = {
        simple = "Need a firearm to inspect.",
        verbose = {
            "Hard to inspect something I’m not even holding.",
            "Well... no gun, no inspection.",
            "Might want to grab a firearm first.",
            "Can't inspect what I don't have.",
            "Empty hands, empty inspection.",
            "Need to be holding a weapon first.",
            "Nothing in my hands to examine here.",
        },
    },
    WeaponSawedOff = {
        simple = "Firearm Sawn Off.",
        verbose = {
            "Sawed off the barrel — compact and risky.",
            "It won’t win any beauty contests now.",
            "Cut it down to size. Just hope it still works.",
            "Compact and dangerous now.",
            "Barrel shortened, handling improved.",
            "Less accuracy, more portability.",
            "Chopped it down to size.",
        },
    },
    OpenedcommonCache = {
        simple = "Opened common firearm cache.",
        verbose = {
            "Not bad, some basic gear.",
            "Standard military supplies.",
            "Could be worse.",
            "All Basic equipment.",
            "Basic supplies, but supplies nonetheless.",
            "Standard issue gear.",
            "Nothing fancy, but it'll do the job.",
            "Typical military cache contents.",
        },
    },
    OpeneduncommonCache = {
        simple = "Opened uncommon firearm cache.",
        verbose = {
            "Nice find, decent gear here.",
            "This has some ok stuff.",
            "Better than I expected.",
            "Solid equipment stash.",
            "Above average haul here.",
            "Some quality pieces in this lot.",
            "This cache has some merit.",
            "Respectable gear selection.",
        },
    },
    OpenedrareCache = {
        simple = "Opened rare firearm cache.",
        verbose = {
            "Definitely a rare bit of gear",
            "Now we're talking!",
            "Outstanding find",
            "Jackpot on this one.",
            "Rare finds like this don't come often.",
            "Someone stashed the good stuff here.",
            "This is some serious equipment!",
        },
    },
    OpenedpremiumCache = {
        simple = "Opened premium firearm cache.",
        verbose = {
            "This is premium equipment.",
            "This is top-tier gear.",
            "Elite cache contents.",
            "Military-grade equipment cache",
            "This is professional-level gear.",
            "Premium firearm stash all around.",
            "Whoever hid this knew their weapons.",
        },
    },
    OpenedlegendaryCache = {
        simple = "Opened legendary firearm cache.",
        verbose = {
            "Incredible! This is a legendary haul",
            "This cache is a goldmine!",
            "A ton of great stuff in here",
            "I've struck the jackpot here!",
            "This is one hell of a find!",
            "Legendary equipment cache this is unbelievable!",
        },
    },
    OpenedAmmoCan = {
        simple = "Ammo can opened.",
        verbose = {
            "Ammo secured. Feels like Christmas.",
            "Let’s fill some mags.",
            "Loaded up. This’ll come in handy.",
            "Rounds for days.",
            "Locked and loaded supply.",
            "That's the good stuff right there.",
            "Ammunition secured — let's get to work.",
            "Perfect timing on this find.",
            "Can never have too much ammo.",
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
            "Bolt's in pieces now.",
            "Impact was too much for it.",
            "That's what cheap bolts get you.",
            "Another one bites the dust.",
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
            "Bolt survived the impact.",
            "Bolt is still in one piece — jackpot.",
            "Good shot, reusable bolt.",
            "That one's coming home with me.",
            "Clean hit, clean recovery.",
            "Bolt's intact — I'll take it.",
        },
    },
    DartBroke = {
        simple = "Dart shattered",
        verbose = {
            "Broke on impact. No saving it.",
            "That one’s toast.",
            "Too brittle for a second shot.",
            "Well, that one's done for.",
            "Definitely not reusing that.",
            "Dart's in pieces now.",
            "Impact was too much for it.",
            "That's what cheap darts get you.",
            "Another one bites the dust.",
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
            "Dart survived the impact.",
            "Still in one piece — jackpot.",
            "Good shot, reusable dart.",
            "That one's coming home with me.",
            "Clean hit, clean recovery.",
            "Dart's intact — I'll take it.",
        },
    },
    TShirtHit = {
        simple = "Shirt delivery successful",
        verbose = {
            "Right in the fashion zone.",
            "Well-placed cotton cannonball.",
            "Who knew soft could hit hard?",
            "Bullseye. Laundry inbound.",
            "That one left a stain.",
            "Tag, you're it.",
            "Direct cotton impact.",
            "Fashion statement delivered.",
            "Clothing deployed successfully.",
            "That's one way to dress someone.",
            "Fabric-based projectile on target.",
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
            "All magazines topped off.",
            "Ready for engagements.",
            "Magazines fully stocked.",
            "Ammunition distribution complete.",
        },
    },
    MagsUnloaded = {
        simple = "Magazines unloaded.",
        verbose = {
            "Cleared the mags out.",
            "Unloading complete.",
            "No rounds left loaded.",
            "All magazines emptied.",
            "Rounds extracted and sorted.",
            "Magazines cleared for storage.",
            "Ammunition redistribution complete.",
        },
    },
    AdminMagLoad = {
        simple = "Admin override: magazines filled.",
        verbose = {
            "All mags topped off. Perks of the badge.",
            "Instant reload? Must be nice.",
            "Magazines loaded — admin style.",
            "Unlimited ammo privileges activated.",
            "Administrative reload complete.",
            "Magic magazine refill engaged.",
        },
    },
    WrapAppliedWoodland = {
        simple = "Woodland wrap on.",
        verbose = {
            "Wrapped and ready for the deep woods.",
            "Nature camo engaged.",
            "Green and mean.",
            "Forest camouflage applied.",
            "Ready for woodland operations.",
            "Tree-hugger mode engaged.",
        },
    },
    WrapAppliedWinter = {
        simple = "Winter wrap on.",
        verbose = {
            "Snow patrol mode activated.",
            "Time to blend with the frost.",
            "Whiteout ready.",
            "Arctic camouflage deployed.",
            "Cold weather operations ready.",
            "Invisible in the snow.",
            "Winter warfare mode.",
        },
    },
    WrapAppliedDesert = {
        simple = "Desert wrap on.",
        verbose = {
            "Desert ops ready.",
            "Blend in with the dunes.",
            "Heat camo, applied.",
            "Sand camouflage engaged.",
            "Ready for arid operations.",
            "Dust and heat ready.",
            "Desert storm mode activated.",
        },
    },
    WrapRemoved = {
        simple = "Wrap removed.",
        verbose = {
            "Back to classic black.",
            "Shedding some camo.",
            "Gone minimalist.",
            "Camouflage stripped off.",
            "Back to basic black finish.",
            "Clean and simple again.",
            "Naked gun, full power."
        }
    }
}