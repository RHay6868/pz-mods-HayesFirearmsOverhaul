require "TimedActions/ISBaseTimedAction"

ISAmmoSwapAction = ISBaseTimedAction:derive("ISAmmoSwapAction")

function ISAmmoSwapAction:isValid()
    return self.character
        and self.weapon
        and self.nextAmmoType
        and self.character:getPrimaryHandItem() == self.weapon
end

function ISAmmoSwapAction:start()
    local currentPart = self.weapon:getWeaponPart("Clip")
    if currentPart then
        self.weapon:detachWeaponPart(currentPart)
    end

    self:setOverrideHandModels(self.weapon, nil)
    self:setAnimVariable("WeaponReloadType", self.weapon:getWeaponReloadType())
    self:setAnimVariable("isLoading", true)
    self:setActionAnim(CharacterActionAnims.Reload)
    self.weapon:setJobType("Swap Ammo")
    self.weapon:setJobDelta(0.0)

    self.character:reportEvent("EventReloading")
    ISReloadWeaponAction.setReloadSpeed(self.character, false)
    
    -- Eject spent rounds first
    self:ejectSpentRounds()
end

function ISAmmoSwapAction:update()
    self.weapon:setJobDelta(self:getJobDelta())
end

function ISAmmoSwapAction:stop()
    self.weapon:setJobDelta(0.0)
    self.character:clearVariable("isLoading")
    self.character:clearVariable("WeaponReloadType")
    ISBaseTimedAction.stop(self)
end

function ISAmmoSwapAction:perform()
    local md = self.weapon:getModData()
    local nextAmmoType = self.nextAmmoType
    local swapSuccess = false

    -- Store original stats if not already stored (only what we modify)
    if not md.OriginalStats then
        md.OriginalStats = {
            AmmoType = self.weapon:getAmmoType(),
            maxDamage = self.weapon:getMaxDamage(),
            minDamage = self.weapon:getMinDamage(),
            recoilDelay = self.weapon:getRecoilDelay(),
            maxRange = self.weapon:getMaxRange(),
            hitChance = self.weapon:getHitChance(),
            projectileCount = self.weapon:getProjectileCount(),
            minAngle = self.weapon:getMinAngle()
        }
    end

    -- Eject spent rounds
    self:ejectSpentRounds()

    -- Remove any remaining ammo of the old type (return individual rounds)
    local currentAmmo = self.weapon:getCurrentAmmoCount()
    if currentAmmo > 0 then
        local oldAmmoType = self.weapon:getAmmoType()
        
        for i = 1, currentAmmo do
            local round = InventoryItemFactory.CreateItem(oldAmmoType)
            if round then
                self.character:getInventory():AddItem(round)
            end
        end
        
        self.weapon:setCurrentAmmoCount(0)
    end

    -- Ammo box mapping - maps ammo types to their corresponding ammo boxes
    local ammoBoxes = {
        ["Base.ShotgunShells"] = "ShotgunShellsBox",
        ["Base.ShotgunShellsBirdshot"] = "ShotgunShellsBirdshotBox", 
        ["Base.ShotgunShellsSlug"] = "ShotgunShellsSlugBox",
        ["Base.223Bullets"] = "223Box",
        ["Base.556Bullets"] = "556Box",
        ["Base.CrossbowBolt"] = "CrossbowBoltBox",
        ["Base.WoodCrossbowBolt"] = "WoodCrossbowBoltBox"
    }

    local result = InventoryItemFactory.CreateItem(self.weapon:getType())
    if result then
        self.weapon:setAmmoType(nextAmmoType)
        result:setAmmoType(nextAmmoType)

        local newAmmoBox = ammoBoxes[nextAmmoType]
        if newAmmoBox then
            self.weapon:setAmmoBox(newAmmoBox)
            result:setAmmoBox(newAmmoBox)
        end

        md.currentAmmoType = nextAmmoType
        
        HFO.Utils.runGenericSwap(result)

        swapSuccess = true
    end

    -- STEP 5: Apply ammo stat modifiers
    if swapSuccess and HFO and HFO.Utils and HFO.Utils.applyAmmoPropertiesToWeapon then
        HFO.Utils.applyAmmoPropertiesToWeapon(self.weapon, nextAmmoType)
    end

    -- Begin automatic reload with new ammo type
    if swapSuccess then
        ISReloadWeaponAction.BeginAutomaticReload(self.character, self.weapon)

        -- Voice feedback based on ammo type
        local baseAmmo = md.AmmoTypeBase
        if nextAmmoType == baseAmmo then
            HFO.InnerVoice.say("AmmoSwapDefault")
        elseif nextAmmoType == "Base.ShotgunShellsBirdshot" then
            HFO.InnerVoice.say("AmmoSwapBirdshot")
        elseif nextAmmoType == "Base.ShotgunShellsSlug" then
            HFO.InnerVoice.say("AmmoSwapSlug")
        elseif nextAmmoType == "Base.556Bullets" then
            HFO.InnerVoice.say("AmmoSwap556")
        elseif nextAmmoType == "Base.WoodCrossbowBolt" then
            HFO.InnerVoice.say("AmmoSwapWoodBolt")
        else
            HFO.InnerVoice.say("AmmoSwapGeneric")
        end
    end

    -- Cleanup animation state
    self.weapon:setJobDelta(0.0)
    self.character:clearVariable("isLoading")
    self.character:clearVariable("WeaponReloadType")

    ISBaseTimedAction.perform(self)
end

function ISAmmoSwapAction:ejectSpentRounds()
    if self.weapon:getSpentRoundCount() > 0 then
        self.weapon:setSpentRoundCount(0)
    elseif self.weapon:isSpentRoundChambered() then
        self.weapon:setSpentRoundChambered(false)
    else
        return
    end
    if self.weapon:getShellFallSound() then
        self.character:getEmitter():playSound(self.weapon:getShellFallSound())
    end
end

function ISAmmoSwapAction:new(character, weapon, nextAmmoType)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.weapon = weapon
    o.nextAmmoType = nextAmmoType
    o.stopOnRun = true
    o.stopOnWalk = false
    o.stopOnAim = false
    o.maxTime = 80 -- Slightly longer than mag swap since we're changing calibers
    o.useProgressBar = false
    return o
end