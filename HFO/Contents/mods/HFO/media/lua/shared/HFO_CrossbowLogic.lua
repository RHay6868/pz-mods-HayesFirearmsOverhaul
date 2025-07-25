--============================================================--
--                    HFO_CrossbowLogic.lua                   --
--============================================================--
-- Purpose:
--   Adds behavior and tracking for crossbow bolts, including bolt
--   breakage, retrieval, and optional component recovery based on
--   sandbox settings.
--
-- Overview:
--   This module handles bolt logic during zombie hits and death:
--   it tracks whether bolts break on impact, whether they are
--   recoverable, and optionally replaces broken bolts with materials.
--   It also integrates with the InnerVoice system for added flavor.
--
-- Core Features:
--   - Differentiates between wood and metal bolt types
--   - Pulls bolt break and loss chances from sandbox options
--   - Tracks bolt status in zombie modData during life
--   - Returns bolts or components to zombie inventory on death
--   - Triggers randomized InnerVoice comments
--
-- Responsibilities:
--   - Provide immersive and configurable bolt mechanics
--   - Prevent unintended loss or duplication of bolt resources
--   - Add depth to crossbow usage without relying on new item types
--
-- Dependencies:
--   - HFO_Utils and`HFO_SandboxUtils (for core support)
--   - HFO.InnerVoice (optional, for immersive flavor)
--
-- Notes:
--   - This system is zombie-specific it does not apply to players
--   - Expandable for future bolt types or new ranged weapons
--============================================================--

require "HFO_Utils"
require "HFO_SandboxUtils"

HFO = HFO or {}
HFO.XBow = HFO.XBow or {}


---===========================================---
--         CROSSBOW BOLT CONFIGURATION         --
---===========================================---

HFO.XBow.InnerVoice = {
    hitsUntilComment = ZombRand(3, 13),
    totalHits = 0
}

-- Cached bolt configuration
HFO.XBow.BoltConfig = nil

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

function HFO.XBow.getBoltConfig()
    if HFO.XBow.BoltConfig then
        return HFO.XBow.BoltConfig
    end

    local sv = HFO.SandboxUtils.get() -- safe sandbox settings needed for bolt config

    HFO.XBow.BoltConfig = {
        ["Base.CrossbowBolt"]     = { type = "metal", component = "Base.ScrapMetal", breakChance = sv.XbowMetalBreakChance },
        ["Base.WoodCrossbowBolt"] = { type = "wood",  component = "Base.WoodenStick", breakChance = sv.XbowWoodBreakChance },
    }
    return HFO.XBow.BoltConfig
end


---===========================================---
--   ON HIT RETRIEVE OR BREAK BOLTS MECHANIC   --
---===========================================---

function HFO.XBow.OnBoltHit(attacker, target, weapon, damage)
    if not weapon or not weapon:isRanged() then return end

    local ammo = weapon:getAmmoType()
    if not ammo then return end

    local boltConfig = HFO.XBow.getBoltConfig()
    local boltData = boltConfig[ammo] -- make sure we are checking metal vs wood bolts
    if not boltData then return end
    if not instanceof(target, "IsoZombie") then return end

    local isBroken = (ZombRand(100) < boltData.breakChance) -- randomize bolt break based on sandbox setting
    local md = target:getModData()
    md.HFO_xbowBolts = md.HFO_xbowBolts or {}
    md.HFO_xbowBolts[ammo] = md.HFO_xbowBolts[ammo] or { broken = {} }
    table.insert(md.HFO_xbowBolts[ammo].broken, isBroken) 

    -- Handle InnerVoice dialogue
    local voice = HFO.XBow.InnerVoice
    voice.totalHits = voice.totalHits + 1

    if voice.totalHits >= voice.hitsUntilComment then  
        voice.totalHits = 0
        voice.hitsUntilComment = ZombRand(3, 13)  -- randomizing the timing of comments

        if HFO.InnerVoice and HFO.InnerVoice.say then
            if isBroken then
                HFO.InnerVoice.say("BoltBroke")
            else
                HFO.InnerVoice.say("BoltStickingOut")
            end
        end
    end
end


---===========================================---
--     METHOD TO RETRIEVE BOLTS OR MATERIALS   --
---===========================================---

function HFO.XBow.OnZombieDead(zombie)
    local md = zombie:getModData()
    if not md.HFO_xbowBolts then return end

    local boltConfig = HFO.XBow.getBoltConfig()

    for ammo, boltHits in pairs(md.HFO_xbowBolts) do  -- check for table of bolt outcomes
        local boltData = boltConfig[ammo] --
        if boltData and boltHits.broken then
            for i = 1, #boltHits.broken do
                local isBroken = boltHits.broken[i]
                local sv = HFO.SandboxUtils.get()

                if ZombRand(100) < clamp(sv.XbowLostChance, 0, 100) then -- a chance for complete loss of bolt  
                elseif not isBroken then -- if not broken does it return full bolt or craftin materials
                    zombie:getInventory():AddItem(ammo)
                elseif sv.XbowComponentInstead and boltData.component then
                    zombie:getInventory():AddItem(boltData.component)
                end
            end
        end
    end

    md.HFO_xbowBolts = nil
end


---===========================================---
--                 EVENT HOOKS                 --
---===========================================---

Events.OnWeaponHitCharacter.Add(HFO.XBow.OnBoltHit)
Events.OnZombieDead.Add(HFO.XBow.OnZombieDead)