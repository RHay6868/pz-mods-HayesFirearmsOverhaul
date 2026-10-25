-- HFO_WeaponViewerContextMenu.lua
-- Adds "Inspect Weapon" to context menu for firearms (equipped or in inventory)

require "TimedActions/ISInventoryPaneContextMenu"

HFO = HFO or {}

-- Helper function to open the weapon viewer
local function openWeaponViewer(weapon)
    if not weapon then return end
    
    -- Close any existing viewer
    if HFO_WeaponViewer_Instance then
        HFO_WeaponViewer_Instance:removeFromUIManager()
        HFO_WeaponViewer_Instance = nil
    end
    
    -- Open new viewer
    local viewer = HFO_WeaponViewer:new(100, 100, 0, 0, weapon)
    viewer:initialise()
    viewer:addToUIManager()
    HFO_WeaponViewer_Instance = viewer
    
    if HFO.InnerVoice and HFO.InnerVoice.say then
        HFO.InnerVoice.say("WeaponInspect")
    end
end

-- Add context menu for inventory items (right-click in inventory)
local function addInventoryInspectOption(player, context, items)
    local item = nil
    
    if items and #items > 0 then
        if type(items[1]) == "table" and items[1].items then
            -- Multiple items selected
            item = items[1].items[1]
        else
            -- Single item
            item = items[1]
        end
    end
    
    -- Check if it's a valid firearm
    if item and instanceof(item, "HandWeapon") and item:isAimedFirearm() then
        local option = context:addOption(
            "Inspect Weapon", 
            item, 
            openWeaponViewer
        )
        
        local icon = item:getTex()
        if icon then
            option.iconTexture = icon
        end

        local tooltip = ISInventoryPaneContextMenu.addToolTip()
        tooltip:setName("Inspect Weapon")
        tooltip.description = "Open the 3D weapon viewer\n" ..
                            "View weapon stats\n" ..
                            "Examine attachments\n" ..
                            "Preview gun plating options\n" ..
                            "Rotate and zoom the model"
        option.toolTip = tooltip
        
        table.remove(context.options)
        table.insert(context.options, option)
    end
end

-- Add context menu for world/equipped items (right-click in world or on character)
local function addWorldInspectOption(playerIndex, context, worldobjects, test)
    local player = getSpecificPlayer(playerIndex)
    if not player then return end
    
    local weapon = player:getPrimaryHandItem()
    
    if weapon and instanceof(weapon, "HandWeapon") and weapon:isAimedFirearm() then
        local option = context:addOption(
            "Inspect Equipped Weapon",
            weapon,
            openWeaponViewer
        )
        
        local icon = weapon:getTex()
        if icon then
            option.iconTexture = icon
        end
        
        local tooltip = ISInventoryPaneContextMenu.addToolTip()
        tooltip:setName("Inspect Equipped Weapon")
        tooltip.description = "Open the 3D weapon viewer for your equipped weapon\n" ..
                            "View weapon stats\n" ..
                            "Examine attachments\n" ..
                            "Preview gun plating options\n" ..
                            "Rotate and zoom the model"
        option.toolTip = tooltip
        
        table.remove(context.options)
        table.insert(context.options, option)
    end
end

-- Hook into both context menus
Events.OnFillInventoryObjectContextMenu.Add(addInventoryInspectOption)
Events.OnFillWorldObjectContextMenu.Add(addWorldInspectOption)