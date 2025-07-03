--============================================================--
--                         HFO_Dart.lua                       --
--============================================================--
-- Purpose:
--   Adds behavior and tracking for blowgun darts, including dart
--   breakage, retrieval, and optional component recovery based on
--   sandbox settings.
--
-- Overview:
--   This module handles dart logic during zombie hits and death:
--   it tracks whether darts break on impact, whether they are
--   recoverable, and optionally replaces broken darts with materials.
--   It also integrates with the InnerVoice system for added flavor.
--
-- Core Features:
--   - Pulls darts break and loss chances from sandbox options
--   - Tracks dart status in zombie modData during life
--   - Returns darts or components to zombie inventory on death
--   - Triggers randomized InnerVoice comments
--
-- Responsibilities:
--   - Provide immersive and configurable dart mechanics
--   - Prevent unintended loss or duplication of dart resources
--   - Add depth to blowgun usage without relying on new item types
--
-- Dependencies:
--   - HFO_Utils and`HFO_SandboxUtils (for core support)
--   - HFO.InnerVoice (optional, for immersive flavor)
--
-- Notes:
--   - This system is zombie-specific it does not apply to players
--   - Expandable for future dart types or new ranged weapons
--============================================================--

require "HFO_Utils"
require "HFO_SandboxUtils"

HFO = HFO or {}
HFO.Darts = HFO.Darts or {}


---===========================================---
--             DART CONFIGURATION              --
---===========================================---

HFO.Darts.InnerVoice = {
    hitsUntilComment = ZombRand(3, 11),
    totalHits = 0
}

-- Cached bolt configuration
HFO.Darts.DartConfig = nil

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

function HFO.Darts.getDartsConfig()
    if HFO.Darts.DartConfig then 
        return HFO.Darts.DartConfig 
    end

    local sv = HFO.SandboxUtils.get()

    HFO.Darts.DartConfig = {
        ["Base.BlowgunDart"] = {
            component = "Base.ScrapMetal",
            breakChance = tonumber(sv.DartBreakChance) or 30  -- Ensure it's a number
        }
    }
    return HFO.Darts.DartConfig
end


---===========================================---
--   ON HIT RETRIEVE OR BREAK DARTS MECHANIC   --
---===========================================---

function HFO.Darts.OnDartHit(attacker, target, weapon, damage)
    if not weapon or not weapon:isRanged() then return end

    local ammo = weapon:getAmmoType()
    if not ammo then return end

    local dartConfig = HFO.Darts.getDartsConfig()
    local dartData = dartConfig[ammo] 
    if not dartData then return end
    if not instanceof(target, "IsoZombie") then return end

    local isBroken = (ZombRand(100) < dartData.breakChance) -- randomize dart break based on sandbox setting
    local md = target:getModData()
    md.dartsHits = md.dartsHits or {}
    md.dartsHits[ammo] = md.dartsHits[ammo] or { broken = {} }
    table.insert(md.dartsHits[ammo].broken, isBroken) 

    -- Handle InnerVoice dialogue
    local voice = HFO.Darts.InnerVoice
    voice.totalHits = voice.totalHits + 1

    if voice.totalHits >= voice.hitsUntilComment then  
        voice.totalHits = 0
        voice.hitsUntilComment = ZombRand(3, 13)  -- randomizing the timing of comments

        if HFO.InnerVoice and HFO.InnerVoice.say then
            if isBroken then
                HFO.InnerVoice.say("DartBroke")
            else
                HFO.InnerVoice.say("DartStickingOut")
            end
        end
    end
end


---===========================================---
--     METHOD TO RETRIEVE DARTS OR MATERIALS   --
---===========================================---

function HFO.Darts.OnZombieDead(zombie)
    local md = zombie:getModData()
    if not md.dartsHits then return end

    local dartConfig = HFO.Darts.getDartsConfig()

    for ammo, dartHits in pairs(md.dartsHits) do  -- check for table of dart outcomes
        local dartData = dartConfig[ammo] --
        if dartData and dartHits.broken then
            for i = 1, #dartHits.broken do
                local isBroken = dartHits.broken[i]
                local sv = HFO.SandboxUtils.get()

                if ZombRand(100) < clamp(tonumber(sv.DartsLostChance) or 0, 0, 100) then -- a chance for complete loss of dart  
                elseif not isBroken then -- if not broken does it return full dart or craftin materials
                    zombie:getInventory():AddItem(ammo)
                elseif sv.DartsComponentInstead and dartData.component then
                    zombie:getInventory():AddItem(dartData.component)
                end
            end
        end
    end

    md.dartsHits = nil
end


---===========================================---
--                 EVENT HOOKS                 --
---===========================================---

Events.OnWeaponHitCharacter.Add(HFO.Darts.OnDartHit)
Events.OnZombieDead.Add(HFO.Darts.OnZombieDead)