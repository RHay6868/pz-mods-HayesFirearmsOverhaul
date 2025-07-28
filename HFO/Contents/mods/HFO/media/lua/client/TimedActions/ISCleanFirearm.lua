require "TimedActions/ISBaseTimedAction"

ISCleanFirearm = ISBaseTimedAction:derive("ISCleanFirearm");

function ISCleanFirearm:isValid()
    if not self.character:getInventory():contains(self.weapon) then return false end
    if not HFO.Utils.isAimedFirearm(self.weapon) then return false end
    if self.character:getInventory():getItemCount("FirearmCleaningKit") < 1 then return false end
    if self.character:getInventory():getItemCount("FirearmLubricant") < 1 then return false end
    if self.character:getInventory():getItemCount("RippedSheets") < 1 then return false end
    return true
end

function ISCleanFirearm:update()
    self.character:setMetabolicTarget(Metabolics.LightWork);
end

function ISCleanFirearm:start()
    self.weapon:setJobType(getText("ContextMenu_Clean_Firearm"))
    self.weapon:setJobDelta(0.0)

    self:setActionAnim("InsertBullets")
end

function ISCleanFirearm:stop()
    ISBaseTimedAction.stop(self);
    self.weapon:setJobDelta(0.0);
end

function ISCleanFirearm:perform()
    self.weapon:setJobDelta(0.0);
    
    local sv = HFO.SandboxUtils.get()
    
    -- Consume materials
    self.character:getInventory():RemoveOneOf("FirearmLubricant")
    self.character:getInventory():RemoveOneOf("RippedSheets")
    self.character:getInventory():AddItem("Base.RippedSheetsDirty")
    
    -- MODIFY THE ORIGINAL WEAPON DIRECTLY (no new item!)
    local currentCondition = self.weapon:getCondition()
    local maxCondition = self.weapon:getConditionMax()
    
    local roll = ZombRand(1, 100)
    local didRepair = false
    local repairCountReduced = false
    
    -- Chance-based condition repair
    if currentCondition < maxCondition and roll > sv.CleaningFail then
        local newCondition = math.min(currentCondition + (1 + sv.CleaningStats), maxCondition)
        self.weapon:setCondition(newCondition)  -- SAME WEAPON OBJECT
        didRepair = true
    end
    
    -- Repair count reduction
    if self.weapon:getHaveBeenRepaired() > 1 then
        local aiming = self.character:getPerkLevel(Perks.Aiming)
        local successRate = 0.05 + aiming * (0.01 * sv.CleaningRepairRate)
        if ZombRandFloat(0.0, 1.0) <= successRate then
            self.weapon:setHaveBeenRepaired(self.weapon:getHaveBeenRepaired() - 1)  -- SAME WEAPON OBJECT
            repairCountReduced = true
        end
    end
    
    -- Voice feedback
    if didRepair and repairCountReduced then
        HFO.InnerVoice.say("CleanBonusSuccess")
    elseif didRepair then
        HFO.InnerVoice.say("CleanSuccess")
    else
        HFO.InnerVoice.say("CleanFail")
    end
    
    -- Needed to remove from queue / start next
    ISBaseTimedAction.perform(self);
end

function ISCleanFirearm:new(character, weapon, time)
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