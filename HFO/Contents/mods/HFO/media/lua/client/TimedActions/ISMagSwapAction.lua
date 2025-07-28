require "TimedActions/ISBaseTimedAction"

ISMagSwapAction = ISBaseTimedAction:derive("ISMagSwapAction")

function ISMagSwapAction:isValid()
    return self.character
        and self.weapon
        and self.nextMagType
        and self.character:getPrimaryHandItem() == self.weapon
end

function ISMagSwapAction:start()
    local currentPart = self.weapon:getWeaponPart("Clip")
    if currentPart then
        self.weapon:detachWeaponPart(currentPart)
    end

    self:setOverrideHandModels(self.weapon, nil)
    self:setAnimVariable("WeaponReloadType", self.weapon:getWeaponReloadType())
    self:setAnimVariable("isLoading", true)
    self:setActionAnim(CharacterActionAnims.Reload)
    self.weapon:setJobType("Swap Magazine")
    self.weapon:setJobDelta(0.0)

    self.character:reportEvent("EventReloading")
    ISReloadWeaponAction.setReloadSpeed(self.character, false)
end

function ISMagSwapAction:update()
    self.weapon:setJobDelta(self:getJobDelta())
end

function ISMagSwapAction:stop()
    self.weapon:setJobDelta(0.0)
    self.character:clearVariable("isLoading")
    self.character:clearVariable("WeaponReloadType")
    ISBaseTimedAction.stop(self)
end

function ISMagSwapAction:perform()
    local md = self.weapon:getModData()
    local maps = HFO.Utils.getMagazineInfoMaps(md)
    local currentPart = self.weapon:getWeaponPart("Clip")
    local nextMagType = self.nextMagType
    local desiredMag = maps.typeMap[nextMagType]
    local swapSuccess = false

<<<<<<< Updated upstream
<<<<<<< Updated upstream
    if desiredMag then
        local result = InventoryItemFactory.CreateItem(self.weapon:getType())
=======
    if nextMagType then
        self.result = InventoryItemFactory.CreateItem(self.weapon:getType())
        local result = self.result 
>>>>>>> Stashed changes
=======
    if nextMagType then
        self.result = InventoryItemFactory.CreateItem(self.weapon:getType())
        local result = self.result 
>>>>>>> Stashed changes

        if desiredMag ~= md.MagBase then
            local newPart = InventoryItemFactory.CreateItem(desiredMag)
            if newPart then
                self.weapon:attachWeaponPart(newPart)
                self.weapon:setMaxAmmo(newPart:getMaxAmmo())
                self.weapon:setMagazineType(nextMagType)
                md.currentMagType = nextMagType

                result:setMaxAmmo(self.weapon:getMaxAmmo())
                result:setMagazineType(self.weapon:getMagazineType())
<<<<<<< Updated upstream
                HFO.Utils.runGenericSwap(result)

=======

                HFO.Utils.applySuffixToWeaponName(result)
                HFO.Utils.applyWeaponStats(self.weapon, result)
                HFO.Utils.setWeaponParts(self.weapon, result)
                HFO.Utils.handleWeaponChamber(self.weapon, result, false)
                HFO.Utils.handleWeaponJam(self.weapon, result, true)
                HFO.Utils.smartDataTransfer(self.weapon, result) 
                BWTweaks:checkForModelChange(result)
                HFO.Utils.handleEquippedWeapon(self.character, self.weapon, result)
                self.character:getInventory():AddItem(result)
                self.character:getInventory():DoRemoveItem(self.weapon)
<<<<<<< Updated upstream
>>>>>>> Stashed changes
=======
>>>>>>> Stashed changes
                swapSuccess = true
            end
        else
            local baseMagItem = InventoryItemFactory.CreateItem(md.MagBase)
            if baseMagItem then
                self.weapon:setMaxAmmo(baseMagItem:getMaxAmmo())
                self.weapon:setMagazineType(nextMagType)
                md.currentMagType = nextMagType

                result:setMaxAmmo(self.weapon:getMaxAmmo())
                result:setMagazineType(self.weapon:getMagazineType())
                self.character:getInventory():DoRemoveItem(baseMagItem)
<<<<<<< Updated upstream
                HFO.Utils.runGenericSwap(result)
    
=======

                HFO.Utils.applySuffixToWeaponName(result)
                HFO.Utils.applyWeaponStats(self.weapon, result)
                HFO.Utils.setWeaponParts(self.weapon, result)
                HFO.Utils.handleWeaponChamber(self.weapon, result, false)
                HFO.Utils.handleWeaponJam(self.weapon, result, true)
                HFO.Utils.smartDataTransfer(self.weapon, result) 
                BWTweaks:checkForModelChange(result)
                HFO.Utils.handleEquippedWeapon(self.character, self.weapon, result)
                self.character:getInventory():AddItem(result)
                self.character:getInventory():DoRemoveItem(self.weapon)
<<<<<<< Updated upstream
>>>>>>> Stashed changes
=======
>>>>>>> Stashed changes
                swapSuccess = true
            end
        end
    end

    -- Begin automatic reload if swap succeeded
    if swapSuccess then
<<<<<<< Updated upstream
        ISReloadWeaponAction.BeginAutomaticReload(self.character, self.weapon)
=======
        local newWeapon = self.character:getPrimaryHandItem()
        if newWeapon then
            ISReloadWeaponAction.BeginAutomaticReload(self.character, newWeapon)
        end
        HFO.Utils.checkHotbar(self.weapon, newWeapon)
<<<<<<< Updated upstream
>>>>>>> Stashed changes
=======
>>>>>>> Stashed changes

        if nextMagType == md.MagBase then
            HFO.InnerVoice.say("MagSwapDefault")
        elseif nextMagType == md.MagExtSm then
            HFO.InnerVoice.say("MagSwapSmall")
        elseif nextMagType == md.MagExtLg then
            HFO.InnerVoice.say("MagSwapLarge")
        elseif nextMagType == md.MagDrum then
            HFO.InnerVoice.say("MagSwapDrum")
        end
    end

    -- Cleanup animation state
    self.weapon:setJobDelta(0.0)
    self.character:clearVariable("isLoading")
    self.character:clearVariable("WeaponReloadType")

    ISBaseTimedAction.perform(self)
end

function ISMagSwapAction:new(character, weapon, nextMagType)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.weapon = weapon
    o.nextMagType = nextMagType
    o.stopOnRun = true
    o.stopOnWalk = false
	o.stopOnAim = false
    o.maxTime = 60 
    o.useProgressBar = false
    return o
end