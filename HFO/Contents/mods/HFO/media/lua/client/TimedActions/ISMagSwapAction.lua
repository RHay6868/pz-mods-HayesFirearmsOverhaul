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
    local nextMagType = self.nextMagType
    local swapSuccess = false

    if nextMagType then
        local result = InventoryItemFactory.CreateItem(self.weapon:getType())

        if nextMagType ~= md.HFO_MagBase then
            local newPart = InventoryItemFactory.CreateItem(nextMagType)
            if newPart then
                self.weapon:attachWeaponPart(newPart)
                self.weapon:setMaxAmmo(newPart:getMaxAmmo())
                self.weapon:setMagazineType(nextMagType)
                md.HFO_currentMagType = nextMagType

                result:setMaxAmmo(self.weapon:getMaxAmmo())
                result:setMagazineType(self.weapon:getMagazineType())

                HFO.Utils.applySuffixToWeaponName(result)
                HFO.Utils.applyWeaponStats(self.weapon, result)
                HFO.Utils.setWeaponParts(self.weapon, result)
                HFO.Utils.handleWeaponChamber(self.weapon, result, false)
                HFO.Utils.handleWeaponJam(self.weapon, result, true)
                HFO.Utils.finalizeWeaponSwap(self.character, self.weapon, result)

                swapSuccess = true
            end
        else
            local baseMagItem = InventoryItemFactory.CreateItem(md.HFO_MagBase)
            if baseMagItem then
                self.weapon:setMaxAmmo(baseMagItem:getMaxAmmo())
                self.weapon:setMagazineType(nextMagType)
                md.HFO_currentMagType = nextMagType

                result:setMaxAmmo(self.weapon:getMaxAmmo())
                result:setMagazineType(self.weapon:getMagazineType())
                self.character:getInventory():DoRemoveItem(baseMagItem)

                HFO.Utils.applySuffixToWeaponName(result)
                HFO.Utils.applyWeaponStats(self.weapon, result)
                HFO.Utils.setWeaponParts(self.weapon, result)
                HFO.Utils.handleWeaponChamber(self.weapon, result, false)
                HFO.Utils.handleWeaponJam(self.weapon, result, true)
                HFO.Utils.finalizeWeaponSwap(self.character, self.weapon, result)
    
                swapSuccess = true
            end
        end
    end

    -- Begin automatic reload if swap succeeded
    if swapSuccess then
        local newWeapon = self.character:getPrimaryHandItem()
        if newWeapon then
            ISReloadWeaponAction.BeginAutomaticReload(self.character, newWeapon)
        end

        if nextMagType == md.HFO_MagBase then
            HFO.InnerVoice.say("MagSwapDefault")
        elseif nextMagType == md.HFO_MagExtSm then
            HFO.InnerVoice.say("MagSwapSmall")
        elseif nextMagType == md.HFO_MagExtLg then
            HFO.InnerVoice.say("MagSwapLarge")
        elseif nextMagType == md.HFO_MagDrum then
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
    o.maxTime = 60 -- You can tweak this; could vary per mag type
    o.useProgressBar = false
    return o
end