require "TimedActions/ISBaseTimedAction"

ISAttachGunPlating = ISBaseTimedAction:derive("ISAttachGunPlating");

local function predicateNotBroken(item)
    return not item:isBroken()
end

function ISAttachGunPlating:isValid()
    if not self.character:getInventory():containsTagEval("Screwdriver", predicateNotBroken) then return false end
    if not self.character:getInventory():contains(self.weapon) then return false end
    if not self.character:getInventory():contains(self.gunPlatingItem) then return false end
    -- Check if a gun plating is already attached
    if self.weapon:getModData().GunPlating then return false end
    -- Verify this weapon can accept this plating
    local validGunPlating = self.weapon:getModData().GunPlatingOptions
    if not validGunPlating or not string.find(validGunPlating, self.gunPlatingItem:getType()) then return false end
    return true
end

function ISAttachGunPlating:update()
    self.weapon:setJobDelta(self:getJobDelta());
    self.gunPlatingItem:setJobDelta(self:getJobDelta());

    self.character:setMetabolicTarget(Metabolics.LightDomestic);
end

function ISAttachGunPlating:start()
    self.weapon:setJobType(getText("ContextMenu_Apply_Weapon_GunPlating"))
    self.weapon:setJobDelta(0.0)
    self.gunPlatingItem:setJobType(getText("ContextMenu_Apply_Weapon_GunPlating"))
    self.gunPlatingItem:setJobDelta(0.0)

    self:setActionAnim("Craft") -- or "AttachItem" if Craft looks wrong
    self:setOverrideHandModelsString("Base.Screwdriver", self.weapon:getFullType())
end

function ISAttachGunPlating:stop()
    ISBaseTimedAction.stop(self);
    self.weapon:setJobDelta(0.0);
    self.gunPlatingItem:setJobDelta(0.0);
end

function ISAttachGunPlating:perform()
    self.weapon:setJobDelta(0.0);
    self.gunPlatingItem:setJobDelta(0.0);
    
    -- Store the plating type in the weapon's mod data
    if not self.weapon:getModData().GunPlating then
        -- Print debug info to see what's being stored
        print("HFO: Attaching gun plating to " .. self.weapon:getFullType())
        print("HFO: Gun Plating item type: " .. self.gunPlatingItem:getType())
        print("HFO: Gun Plating item full type: " .. self.gunPlatingItem:getFullType())
        
        self.weapon:getModData().GunPlating = self.gunPlatingItem:getType()
        print("HFO: Stored plating as: " .. self.weapon:getModData().GunPlating)
        
        -- Remove the plating item from inventory
        self.character:getInventory():Remove(self.gunPlatingItem);
        
        -- Force model change based on new criteria
        BWTweaks:checkForModelChange(self.weapon)
    end
    
    -- Needed to remove from queue / start next
    ISBaseTimedAction.perform(self);
end

function ISAttachGunPlating:new(character, weapon, gunPlatingItem, time)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character;
    o.weapon = weapon;
    o.gunPlatingItem = gunPlatingItem;
    o.stopOnWalk = true;
    o.stopOnRun = true;
    o.maxTime = time;
    if character:isTimedActionInstant() then
        o.maxTime = 1;
    end
    return o;
end