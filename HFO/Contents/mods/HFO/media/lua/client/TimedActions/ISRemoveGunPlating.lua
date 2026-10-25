require "TimedActions/ISBaseTimedAction"

ISRemoveGunPlating = ISBaseTimedAction:derive("ISRemoveGunPlating");

local function predicateNotBroken(item)
    return not item:isBroken()
end

function ISRemoveGunPlating:isValid()
    if not self.character:getInventory():containsTagEval("Screwdriver", predicateNotBroken) then return false end
    if not self.character:getInventory():contains(self.weapon) then return false end
    -- Check if a plating is actually attached
    if not self.weapon:getModData().HFO_GunPlating then return false end
    return true
end

function ISRemoveGunPlating:update()
    self.character:setMetabolicTarget(Metabolics.LightDomestic);
end

function ISRemoveGunPlating:start()
    self.weapon:setJobType(getText("ContextMenu_Remove_Weapon_GunPlating"))
    self.weapon:setJobDelta(0.0)

    self:setActionAnim("Craft") -- or "AttachItem" if Craft looks wrong
    self:setOverrideHandModelsString("Base.Screwdriver", self.weapon:getFullType())
end

function ISRemoveGunPlating:stop()
    ISBaseTimedAction.stop(self);
    self.weapon:setJobDelta(0.0);
end

function ISRemoveGunPlating:perform()
    self.weapon:setJobDelta(0.0);
    
    -- Get the plating type before removing it
    local gunPlatingType = self.weapon:getModData().HFO_GunPlating
    
    if gunPlatingType then
        -- Clear the plating data
        self.weapon:getModData().HFO_GunPlating = nil
        
        -- Add the plating item back to the inventory
        self.character:getInventory():AddItem(gunPlatingType);
        
        -- Force model update
        self.character:resetEquippedHandsModels();

        -- 🔄 Force model change based on new criteria
        BWTweaks:checkForModelChange(self.weapon)
    end
    
    -- Needed to remove from queue / start next
    ISBaseTimedAction.perform(self);
end

function ISRemoveGunPlating:new(character, weapon, time)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character;
    o.weapon = weapon;
    o.stopOnWalk = true;
    o.stopOnRun = true;
    o.maxTime = time;
    return o;
end