require "ISUI/ISInventoryPaneContextMenu"

local original_doMagazineMenu = ISInventoryPaneContextMenu.doMagazineMenu
ISInventoryPaneContextMenu.doMagazineMenu = function(playerObj, magazine, context)

    original_doMagazineMenu(playerObj, magazine, context)
    
    context:addOption("Load All Similar Magazines", playerObj, OnLoadAllMagazines, magazine)
    context:addOption("Unload All Similar Magazines", playerObj, OnUnloadAllMagazines, magazine)
  
    -- Admin option for instant loading
    if isAdmin() or isCoopHost() then
        context:addOption("Admin: Instant Load All", playerObj, OnAdminLoadAllMagazines, magazine)
    end
end

function OnLoadAllMagazines(playerObj, magazine)
    local ammoType = magazine:getAmmoType()
    local allAmmoCount = playerObj:getInventory():getItemCountRecurse(ammoType)
    
    if allAmmoCount <= 0 then 
        playerObj:Say("No ammunition found")
        return 
    end
    
    local allAmmoItems = playerObj:getInventory():getSomeTypeRecurse(ammoType, allAmmoCount)
    local similarMagazines = FindAllSimilarMagazines(playerObj, magazine:getType())
    local ammoIndex = 0
    local anyLoaded = false

    for _, mag in ipairs(similarMagazines) do
        local neededAmmo = mag:getMaxAmmo() - mag:getCurrentAmmoCount()
        
        if neededAmmo > 0 and ammoIndex < allAmmoCount then
            local ammoToLoad = math.min(neededAmmo, allAmmoCount - ammoIndex)
            
            if ammoToLoad > 0 then
                ISInventoryPaneContextMenu.transferIfNeeded(playerObj, mag)
                
                local bulletsToLoad = GetAmmoSubset(allAmmoItems, ammoIndex, ammoToLoad)
                
                ISInventoryPaneContextMenu.transferIfNeeded(playerObj, bulletsToLoad)

                ISTimedActionQueue.add(ISLoadBulletsInMagazine:new(playerObj, mag, ammoToLoad))
                
                ammoIndex = ammoIndex + ammoToLoad
                anyLoaded = true
            end
        end
    end

    if anyLoaded then
        HFO.InnerVoice.say("MagsLoaded")
    end
end

-- Unload all magazines of the same type
function OnUnloadAllMagazines(playerObj, magazine)
    local similarMagazines = FindAllSimilarMagazines(playerObj, magazine:getType())
    local anyUnloaded = false

    for _, mag in ipairs(similarMagazines) do
        if mag:getCurrentAmmoCount() > 0 then
            ISInventoryPaneContextMenu.transferIfNeeded(playerObj, mag)
            ISTimedActionQueue.add(ISUnloadBulletsFromMagazine:new(playerObj, mag))
            anyUnloaded = true
        end
    end

    if anyUnloaded then
        HFO.InnerVoice.say("MagsUnloaded")
    end
end

function OnAdminLoadAllMagazines(playerObj, magazine)
    if not (isAdmin() or isCoopHost()) then
        -- playerObj:Say("Admin privileges required")
        return
    end
    
    local loaded = 0
    local magazinesLoaded = 0
    
    local similarMagazines = FindAllSimilarMagazines(playerObj, magazine:getType())
    
    for _, mag in ipairs(similarMagazines) do
        if mag:getCurrentAmmoCount() < mag:getMaxAmmo() then
            local before = mag:getCurrentAmmoCount()
            mag:setCurrentAmmoCount(mag:getMaxAmmo())
            
            if mag.transmitModData then
                mag:transmitModData()
            end
            
            loaded = loaded + (mag:getMaxAmmo() - before)
            magazinesLoaded = magazinesLoaded + 1
        end
    end
    
    if loaded > 0 then
        HFO.InnerVoice.say("AdminMagLoad")
    end
end

function FindAllSimilarMagazines(playerObj, magazineType)
    local result = {}
    local MAX_DEPTH = 1
    
    local function scanContainer(container, currentDepth)
        local items = container:getItems()
        for i = 0, items:size()-1 do
            local item = items:get(i)
            
            if item:getType() == magazineType then
                table.insert(result, item)
            end
            
            if instanceof(item, "InventoryContainer") then
               -- print("Container: " .. tostring(item:getName()) .. " at depth " .. currentDepth)
                if currentDepth < MAX_DEPTH then
                    scanContainer(item:getInventory(), currentDepth + 1)
                else
                    --print("Skipping deeper container: " .. tostring(item:getName()))
                end
            end
        end
    end
    
    scanContainer(playerObj:getInventory(), 0)
    
    return result
end

function GetAmmoSubset(allAmmo, startIndex, count)
    local result = ArrayList.new()
    local endIndex = math.min(startIndex + count - 1, allAmmo:size() - 1)
    
    for i = startIndex, endIndex do
        result:add(allAmmo:get(i))
    end
    
    return result
end
