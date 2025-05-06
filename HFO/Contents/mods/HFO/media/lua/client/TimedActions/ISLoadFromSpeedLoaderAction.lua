require "TimedActions/ISBaseTimedAction"

ISLoadFromSpeedloaderAction = ISBaseTimedAction:derive("ISLoadFromSpeedloaderAction");

function ISLoadFromSpeedloaderAction:isValid()
    local loaderAmmo = self.speedloader:getCurrentAmmoCount()
    local currentAmmo = self.weapon:getCurrentAmmoCount()
    local maxAmmo = self.weapon:getMaxAmmo()
    return self.character:getPrimaryHandItem() == self.weapon
        and self.speedloader ~= nil
        and math.min(loaderAmmo, maxAmmo) > currentAmmo
end

function ISLoadFromSpeedloaderAction:update()
    self.weapon:setJobDelta(self:getJobDelta()) -- this animates the progress bar
end

function ISLoadFromSpeedloaderAction:start()
    -- Setup animation flags
    self:setOverrideHandModels(self.weapon, nil)
    self:setAnimVariable("WeaponReloadType", self.weapon:getWeaponReloadType())
    self:setAnimVariable("isLoading", true)
    
    -- Set job info
    self.weapon:setJobType(getText("IGUI_JobType_LoadSpeedloader"))
    self.weapon:setJobDelta(0.0)
    
    -- Setup animation
    self:setActionAnim(CharacterActionAnims.Reload)
    
    -- Report event for other systems
    self.character:reportEvent("EventReloading")
    
    -- Set reload speed
    ISReloadWeaponAction.setReloadSpeed(self.character, false)
    
    -- Play the start sound if it exists
    if self.weapon:getInsertAmmoStartSound() then
        self.character:playSound(self.weapon:getInsertAmmoStartSound())
    end
    
    -- Eject spent rounds first
    self:ejectSpentRounds()
end

function ISLoadFromSpeedloaderAction:stop()
    if self.weapon:getInsertAmmoStopSound() then
        self.character:playSound(self.weapon:getInsertAmmoStopSound())
    end
    
    -- Clear animation variables
    self.character:clearVariable("isLoading")
    self.character:clearVariable("WeaponReloadType")
    
    -- Clear job
    self.weapon:setJobDelta(0.0)
    
    ISBaseTimedAction.stop(self)
end

function ISLoadFromSpeedloaderAction:perform()
    if self.weapon:getInsertAmmoStopSound() then
        self.character:playSound(self.weapon:getInsertAmmoStopSound())
    end

    -- Clear animation variables
    self.character:clearVariable("isLoading")
    self.character:clearVariable("WeaponReloadType")

    -- Clear job
    self.weapon:setJobDelta(0.0)

    -- Eject spent rounds
    self:ejectSpentRounds()

    -- Determine loading logic
    local loaderAmmo = self.speedloader:getCurrentAmmoCount()
    local currentAmmo = self.weapon:getCurrentAmmoCount()
    local maxAmmo = self.weapon:getMaxAmmo()
    local finalAmmoCount = math.min(loaderAmmo, maxAmmo)

    if finalAmmoCount > currentAmmo then
        -- Return unfired rounds
        if currentAmmo > 0 then
            local ammoType = self.weapon:getAmmoType()
            for i = 1, currentAmmo do
                local round = InventoryItemFactory.CreateItem(ammoType)
                self.character:getInventory():AddItem(round)
            end
        end

        -- Load from speedloader
        self.weapon:setCurrentAmmoCount(finalAmmoCount)
        self.speedloader:setCurrentAmmoCount(loaderAmmo - finalAmmoCount)
        HFO.InnerVoice.say("SpeedloaderUsed")

        -- Optional: rack if chambered
        if self.weapon:haveChamber() and not self.weapon:isRoundChambered() then
            ISTimedActionQueue.addAfter(self, ISRackFirearm:new(self.character, self.weapon))
        end
    end

    ISBaseTimedAction.perform(self)
end

function ISLoadFromSpeedloaderAction:animEvent(event, parameter)
    -- Handle animation events
    if event == 'playReloadSound' then
        if parameter == 'load' then
            if self.weapon:getInsertAmmoSound() and (self.ammoInserted or 0) < 1 then
                self.character:playSound(self.weapon:getInsertAmmoSound())
                self.ammoInserted = (self.ammoInserted or 0) + 1
            end
        elseif parameter == 'insertAmmoStart' then
            if not self.playedInsertAmmoStartSound and self.weapon:getInsertAmmoStartSound() then
                self.playedInsertAmmoStartSound = true
                self.character:playSound(self.weapon:getInsertAmmoStartSound())
            end
        end
    elseif event == 'changeWeaponSprite' then
        if parameter and parameter ~= '' then
            if parameter ~= 'original' then
                self:setOverrideHandModels(parameter, nil)
            else
                self:setOverrideHandModels(self.weapon, nil)
            end
        end
    end
end

function ISLoadFromSpeedloaderAction:ejectSpentRounds()
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

function ISLoadFromSpeedloaderAction:new(character, weapon, speedloader)
    local o = ISBaseTimedAction.new(self, character)
    o.stopOnAim = false
    o.stopOnWalk = false
    o.stopOnRun = true
    o.weapon = weapon
    o.speedloader = speedloader
    o.ammoToLoad = math.min(speedloader:getCurrentAmmoCount(), weapon:getMaxAmmo())
    -- Use a fixed time based on reload speed
    local reloadSpeed = 1.0 + (character:getPerkLevel(Perks.Reloading) * 0.1)
    -- Adjust time - speedloaders should be faster than loading individual rounds
    o.maxTime = 40 / reloadSpeed
    o.useProgressBar = false
    return o
end