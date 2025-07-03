require "ISUI/ISToolTipInv"
require "ISUI/ISUIElement"
require "HFO_Utils"

HFO = HFO or {}
HFO.Utils = HFO.Utils or {}
HFO.Tooltips = HFO.Tooltips or {}

---===========================================---
--      FULL OVERRIDE: WEAPON PART TOOLTIP     --
---===========================================---

function HFO.drawTooltipTexture(tooltip, texturePath, x, y, scale, a, alignCenter)
    if not texturePath then return false end
    
    local texture = getTexture(texturePath)
    if texture then
        local w = texture:getWidth() * scale
        local h = texture:getHeight() * scale
        
        -- If alignCenter is true, center the icon vertically with the text
        local yOffset = 0
        if alignCenter then
            local fontHeight = getTextManager():getFontHeight(tooltip.defaultFont)
            yOffset = (fontHeight - h) / 2
        end
        
        tooltip:DrawTextureScaled(texture, x, y + yOffset, w, h, a or 1)
        return true, w
    end
    return false, 0
end

-- Helper function to check if a string ends with a specific suffix
if not string.ends then
    function string.ends(str, ending)
        if type(str) ~= "string" or type(ending) ~= "string" then return false end
        return ending == "" or str:sub(-#ending) == ending
    end
end

-- Improved layout for Mount-On display with proper width calculation
local function renderMountOnFixedColumns(item, font, tooltip, startX, startY, maxWidth)
    if not item or not tooltip then return startY, 0 end

    local mountList = item:getMountOn()
    if not mountList or mountList:isEmpty() then return startY, 0 end

    local names = {}
    for i = 0, mountList:size() - 1 do
        local fullType = mountList:get(i)
        if not HFO.Utils.shouldSkipSuffix or not HFO.Utils.shouldSkipSuffix(fullType) then
            local name = HFO.Utils.getDisplayNameFromFullType(fullType)
            table.insert(names, name)
        end
    end

    if #names == 0 then return startY, 0 end

    -- Sort alphabetically (case-insensitive)
    table.sort(names, function(a, b)
        return tostring(a):lower() < tostring(b):lower()
    end)

    -- Draw header
    tooltip:DrawText(font, getText("Tooltip_weapon_CanBeMountOn") .. ":", startX, startY, 1.0, 1.0, 0.8, 1.0)
    local spacing = tooltip:getLineSpacing()
    local y = startY + spacing

    local textManager = getTextManager()
    local padding = math.max(6, getCore():getScreenWidth() / 320) -- Reduced padding for better fit
    local currentX = startX
    local currentY = y
    local rightMargin = math.max(10, getTextManager():getFontHeight(font) * 0.8) -- Scale right margin with font size
    local availableWidth = maxWidth - startX - rightMargin -- Use font-scaled right margin
    local maxUsedWidth = 0

    for i, name in ipairs(names) do
        local isLast = (i == #names)
        local text = name .. (isLast and "" or ", ") -- Use ", " instead of just ","
        local width = textManager:MeasureStringX(font, text)

        -- More generous wrapping - only wrap if it would significantly exceed the line
        if currentX > startX and currentX + width > startX + availableWidth + 20 then
            currentX = startX
            currentY = currentY + spacing
        end

        tooltip:DrawText(font, text, currentX, currentY, 1, 1, 1, 1)
        currentX = currentX + width + (isLast and 0 or padding)
        
        -- Track the maximum width used
        maxUsedWidth = math.max(maxUsedWidth, currentX - startX)
    end

    return currentY + spacing, maxUsedWidth
end

-- Helper function to simulate the actual text layout and find the widest row
local function calculateActualMountOnWidth(weaponPart, font, startX, maxTestWidth)
    local textManager = getTextManager()
    local mountList = weaponPart:getMountOn()
    
    if not mountList or mountList:isEmpty() then return 0 end
    
    local names = {}
    for i = 0, mountList:size() - 1 do
        local fullType = mountList:get(i)
        if not HFO.Utils.shouldSkipSuffix or not HFO.Utils.shouldSkipSuffix(fullType) then
            local name = HFO.Utils.getDisplayNameFromFullType(fullType)
            table.insert(names, name)
        end
    end
    
    if #names == 0 then return 0 end
    
    -- Sort alphabetically (case-insensitive) - same as rendering
    table.sort(names, function(a, b)
        return tostring(a):lower() < tostring(b):lower()
    end)
    
    local padding = math.max(6, getCore():getScreenWidth() / 320)
    local availableWidth = maxTestWidth - startX - 10 -- Same logic as rendering
    local currentX = startX
    local currentRowWidth = 0
    local maxRowWidth = 0
    
    -- Simulate the exact same layout logic as renderMountOnFixedColumns
    for i, name in ipairs(names) do
        local isLast = (i == #names)
        local text = name .. (isLast and "" or ", ")
        local width = textManager:MeasureStringX(font, text)
        
        -- Check if we need to wrap (same logic as rendering)
        if currentX > startX and currentX + width > startX + availableWidth + 20 then
            -- Record this row's width before wrapping
            maxRowWidth = math.max(maxRowWidth, currentRowWidth)
            currentX = startX
            currentRowWidth = 0
        end
        
        currentX = currentX + width + (isLast and 0 or padding)
        currentRowWidth = currentX - startX
    end
    
    -- Don't forget the last row
    maxRowWidth = math.max(maxRowWidth, currentRowWidth)
    
    return maxRowWidth
end

-- Helper function to calculate required width for content
local function calculateRequiredWidth(weaponPart, font)
    local textManager = getTextManager()
    local screenWidth = getCore():getScreenWidth()
    local baseMinWidth = 250
    local maxCalculatedWidth = baseMinWidth
    
    -- Scale padding based on font size
    local fontHeight = textManager:getFontHeight(font)
    local rightPadding = math.max(10, fontHeight * 0.8) -- Scale with font size
    local safetyBuffer = math.max(8, fontHeight * 0.6) -- Scale safety buffer too
    
    -- Check item name width
    if weaponPart.getName then
        local nameWidth = textManager:MeasureStringX(font, weaponPart:getName())
        maxCalculatedWidth = math.max(maxCalculatedWidth, nameWidth + rightPadding)
    end
    
    -- Check mod name width
    if weaponPart.getModName and weaponPart:getModName() then
        local modText = "Mod: " .. weaponPart:getModName()
        local modWidth = textManager:MeasureStringX(font, modText)
        maxCalculatedWidth = math.max(maxCalculatedWidth, modWidth + rightPadding)
    end
    
    -- Check header width
    local headerWidth = textManager:MeasureStringX(font, getText("Tooltip_weapon_CanBeMountOn") .. ":")
    maxCalculatedWidth = math.max(maxCalculatedWidth, headerWidth + rightPadding)
    
    -- Check mount-on names with actual layout simulation
    local mountList = weaponPart:getMountOn()
    if mountList and not mountList:isEmpty() then
        -- Count items first
        local itemCount = 0
        for i = 0, mountList:size() - 1 do
            local fullType = mountList:get(i)
            if not HFO.Utils.shouldSkipSuffix or not HFO.Utils.shouldSkipSuffix(fullType) then
                itemCount = itemCount + 1
            end
        end
        
        -- For large lists, ensure we can fit at least 2 items per line minimum
        local minItemsPerLine = 2
        if itemCount > 6 then -- Only enforce for truly long lists
            -- Calculate what width we'd need for 2 items minimum
            local longestItemWidth = 0
            for i = 0, mountList:size() - 1 do
                local fullType = mountList:get(i)
                if not HFO.Utils.shouldSkipSuffix or not HFO.Utils.shouldSkipSuffix(fullType) then
                    local name = HFO.Utils.getDisplayNameFromFullType(fullType)
                    local width = textManager:MeasureStringX(font, name)
                    longestItemWidth = math.max(longestItemWidth, width)
                end
            end
            
            local padding = math.max(6, screenWidth / 320)
            local commaWidth = textManager:MeasureStringX(font, ", ")
            local minWidthFor2Items = 5 + (longestItemWidth + commaWidth + padding) * minItemsPerLine + rightPadding
            maxCalculatedWidth = math.max(maxCalculatedWidth, minWidthFor2Items)
        end
        
        -- Start with a reasonable test width and iterate
        local testWidth = maxCalculatedWidth
        local actualMountWidth = 0
        local iterations = 0
        
        repeat
            actualMountWidth = calculateActualMountOnWidth(weaponPart, font, 5, testWidth)
            local neededWidth = actualMountWidth + 5 + rightPadding + safetyBuffer
            
            if neededWidth <= testWidth then
                -- We found a width that works
                maxCalculatedWidth = math.max(maxCalculatedWidth, neededWidth)
                break
            else
                -- Need more width, try again
                testWidth = neededWidth + math.max(30, fontHeight) -- Scale iteration buffer with font
                iterations = iterations + 1
            end
        until iterations > 5 -- Prevent infinite loops
        
        -- Fallback if iterations exceeded
        if iterations > 5 then
            maxCalculatedWidth = math.max(maxCalculatedWidth, testWidth)
        end
    end
    
    -- Check stat labels width
    local player = getSpecificPlayer(0)
    local primary = player and player:getPrimaryHandItem()
    if primary and instanceof(primary, "HandWeapon") and primary:getSubCategory() == "Firearm" then
        local statChanges = HFO.Utils.compareWeaponStats(primary, weaponPart, {
            includeExtraEffects = true,
            sort = true
        })
        
        if statChanges then
            local formattedChanges = HFO.Utils.formatStatComparison(statChanges)
            if formattedChanges and #formattedChanges > 0 then
                local maxStatWidth = 0
                for _, entry in ipairs(formattedChanges) do
                    local labelWidth = textManager:MeasureStringX(font, entry.label .. ":")
                    local valueWidth = textManager:MeasureStringX(font, entry.formatted or tostring(entry.rawChange))
                    local totalStatWidth = labelWidth + valueWidth + 20
                    maxStatWidth = math.max(maxStatWidth, totalStatWidth)
                end
                
                maxCalculatedWidth = math.max(maxCalculatedWidth, maxStatWidth + rightPadding)
            end
        end
    end
    
    -- Maximum width limits - be more generous for larger fonts
    local maxAllowedWidth = math.min(screenWidth * 0.7, 1000) -- Increased from 0.6/800
    
    return math.min(maxCalculatedWidth, maxAllowedWidth)
end

---===========================================---
--    PULLING IN THE NECESSARY TOOLTIP INFO    --
---===========================================---

-- Custom tooltip function for weapon parts with improved error handling
function HFO_WeaponPart_DoTooltip(weaponPart, tooltip)
    if not weaponPart or not tooltip then return end
    
    -- Use the user's actual font preference instead of hardcoded small
    local font = UIFont[getCore():getOptionTooltipFont()]
    local x = 5
    local y = 5
    local spacing = tooltip:getLineSpacing()
    local textManager = getTextManager()
    local maxWidth = tooltip:getWidth()
    
    -- Get stack weight (if present)
    local weightOfStack = tooltip:getWeightOfStack() or 0

    -- Item name (title)
    if weaponPart.getName then
        tooltip:DrawText(font, weaponPart:getName(), x, y, 1, 1, 0.8, 1)
    else
        tooltip:DrawText(font, "Unknown Part", x, y, 1, 1, 0.8, 1)
    end
    y = y + spacing * 1.5  -- EXACTLY ONE EMPTY LINE after title
    
    -- Calculate the widest label for proper alignment
    local labels = {
        getText("Tooltip_item_Weight") .. ":",
        getText("Tooltip_weapon_Type") .. ":"
    }

    -- Add stack encumbrance label if needed
    if weightOfStack > 0 then
        table.insert(labels, getText("Tooltip_item_StackWeight") .. ":")
    end
    
    local maxLabelWidth = 0
    for _, label in ipairs(labels) do
        local width = textManager:MeasureStringX(font, label)
        if width > maxLabelWidth then maxLabelWidth = width end
    end
    
    -- Add a small padding between label and value
    local valuePadding = 10
    local valueColumnX = x + maxLabelWidth + valuePadding
     
    -- Encumbrance 
    local weightLabel = getText("Tooltip_item_Weight") .. ":"
    local weightValue = string.format("%.2f", weaponPart:getWeight())
    tooltip:DrawText(font, weightLabel, x, y, 1.0, 1.0, 0.8, 1.0)
    tooltip:DrawText(font, weightValue, valueColumnX, y, 1, 1, 1, 1)
    y = y + spacing

    -- Stack weight (if present)
    if weightOfStack > 0 then
        local weightLabel = getText("Tooltip_item_StackWeight") .. ":"
        local weightValue = string.format("%.2f", weightOfStack)
        tooltip:DrawText(font, weightLabel, x, y, 1.0, 1.0, 0.8, 1.0)
        tooltip:DrawText(font, weightValue, valueColumnX, y, 1, 1, 1, 1)
        y = y + spacing
    end
    
    -- Type (slot/part type) 
    if weaponPart.getPartType then
        local typeLabel = getText("Tooltip_weapon_Type") .. ":"
        local typeValue = getText("Tooltip_weapon_" .. weaponPart:getPartType())
        tooltip:DrawText(font, typeLabel, x, y, 1.0, 1.0, 0.8, 1.0)
        tooltip:DrawText(font, typeValue, valueColumnX, y, 1, 1, 1, 1)
        y = y + spacing
    end
    
    -- Mount-on list with comma separation
    if type(renderMountOnFixedColumns) == "function" then
        local mountOnEndY, mountOnWidth = renderMountOnFixedColumns(weaponPart, font, tooltip, x, y, maxWidth)
        y = mountOnEndY
    else
        -- Fallback if renderMountOnFixedColumns function isn't available
        local fullTypes = weaponPart:getMountOn()
        if fullTypes and not fullTypes:isEmpty() then
            tooltip:DrawText(font, getText("Tooltip_weapon_CanBeMountOn") .. ":", x, y, 1.0, 1.0, 0.8, 1.0)
            y = y + spacing
            
            for i = 0, fullTypes:size() - 1 do
                local fullType = fullTypes:get(i)
                if not HFO.Utils.shouldSkipSuffix or not HFO.Utils.shouldSkipSuffix(fullType) then
                    local name = HFO.Utils.getDisplayNameFromFullType(fullType)
                    tooltip:DrawText(font, "- " .. name, x + 10, y, 1, 1, 1, 1)
                    y = y + spacing
                end
            end
        end
    end
    
    if weaponPart.getModName and weaponPart:getModName() then
        tooltip:DrawText(font, "Mod: " .. weaponPart:getModName(), x, y, 0.4, 0.6, 1, 1)
        y = y + spacing
    end
    
    if weaponPart.getType then
        local desc = getTextOrNull("Tooltip_item_" .. weaponPart:getType())
        if desc then
            tooltip:DrawText(font, desc, x, y, 1, 1, 0.8, 1)
            y = y + spacing
        end
    end

    -- Grab stat changes using the new system
    local player = getSpecificPlayer(0)
    local primary = player and player:getPrimaryHandItem()
    if primary and instanceof(primary, "HandWeapon") and primary:getSubCategory() == "Firearm" then
        local statChanges = HFO.Utils.compareWeaponStats(primary, weaponPart, {
            includeExtraEffects = true,
            sort = true
        })
        
        local formattedChanges = HFO.Utils.formatStatComparison(statChanges)

        if formattedChanges and #formattedChanges > 0 then
            y = y + spacing
            tooltip:DrawText(font, "Stat Changes:", x, y, 1.0, 1.0, 0.8, 1.0)
            y = y + spacing

            -- Alignment prep
            local labelColW = 0
            for _, entry in ipairs(formattedChanges) do
                local w = textManager:MeasureStringX(font, entry.label .. ":")
                if w > labelColW then labelColW = w end
            end
            local valueX = x + labelColW + 10

            -- Render each delta
            for _, entry in ipairs(formattedChanges) do
                local label = entry.label .. ":"
                local value = entry.formatted or tostring(entry.rawChange)
                local r, g, b = unpack(entry.color)

                -- Draw icon before the label if it exists
                local iconOffset = 0
                if entry.icon then
                    local iconDrawn, iconWidth = HFO.drawTooltipTexture(tooltip, entry.icon, x, y, 0.75, 1, true)
                    if iconDrawn then
                        iconOffset = iconWidth + 4
                    end
                end

                -- Draw label with offset for icon
                tooltip:DrawText(font, label, x + iconOffset, y, 1, 1, 0.8, 1)
                tooltip:DrawText(font, value, valueX + iconOffset, y, r, g, b, 1)
            
                y = y + spacing
            end
        end
    end
    
    -- ALWAYS set the height at the end, regardless of stat changes
    tooltip:setHeight(y + 10)
end

---===========================================---
--    RENDERING OF PART COMPARISON TOOLTIP     --
---===========================================---

-- Store original method
local orig_ISToolTipInv_render = ISToolTipInv.render

-- Override the render method to use our custom tooltip for weapon parts
function ISToolTipInv:render()
    if not self.item then 
        return orig_ISToolTipInv_render(self)
    end
    
    local isWeaponPart = instanceof(self.item, "WeaponPart")
    
    if not isWeaponPart then
        return orig_ISToolTipInv_render(self)
    end
    
    if not ISContextMenu.instance or not ISContextMenu.instance.visibleCheck then
        local mx = getMouseX() + 24
        local my = getMouseY() + 24
        if not self.followMouse then
            mx = self:getX()
            my = self:getY()
            if self.anchorBottomLeft then
                mx = self.anchorBottomLeft.x
                my = self.anchorBottomLeft.y
            end
        end

        self.tooltip:setX(mx + 11)
        self.tooltip:setY(my)

        -- Calculate optimal width based on content using user's font preference
        local font = UIFont[getCore():getOptionTooltipFont()]
        local calculatedWidth = calculateRequiredWidth(self.item, font)
        
        -- Set initial width and do a measurement pass
        self.tooltip:setWidth(calculatedWidth)
        self.tooltip:setMeasureOnly(true)
        HFO_WeaponPart_DoTooltip(self.item, self.tooltip)
        self.tooltip:setMeasureOnly(false)

        -- Get screen boundaries
        local myCore = getCore()
        local maxX = myCore:getScreenWidth()
        local maxY = myCore:getScreenHeight()

        local tw = self.tooltip:getWidth()
        local th = self.tooltip:getHeight()
        
        -- If tooltip would go off screen horizontally, adjust width and re-measure
        if mx + 11 + tw > maxX then
            local availableWidth = maxX - mx - 11 - 20 -- 20px margin from edge
            local minWidth = 200 -- Absolute minimum width
            local newWidth = math.max(minWidth, availableWidth)
            
            if newWidth ~= tw then
                self.tooltip:setWidth(newWidth)
                self.tooltip:setMeasureOnly(true)
                HFO_WeaponPart_DoTooltip(self.item, self.tooltip)
                self.tooltip:setMeasureOnly(false)
                
                tw = self.tooltip:getWidth()
                th = self.tooltip:getHeight()
            end
        end
        
        -- Position tooltip within screen bounds with consistent margins
        local leftMargin = 10
        local rightMargin = 10  -- Make right margin explicit and match left
        local tooltipX = math.max(leftMargin, math.min(mx + 11, maxX - tw - rightMargin))
        local tooltipY
        
        if not self.followMouse and self.anchorBottomLeft then
            tooltipY = math.max(10, math.min(my - th, maxY - th - 10))
        else
            tooltipY = math.max(10, math.min(my, maxY - th - 10))
        end
        
        self.tooltip:setX(tooltipX)
        self.tooltip:setY(tooltipY)

        -- Position the panel containing the tooltip
        self:setX(tooltipX - 11)
        self:setY(tooltipY)
        self:setWidth(tw + 11)
        self:setHeight(th)

        -- Avoid overlap with cursor
        if self.followMouse then
            self:adjustPositionToAvoidOverlap({ 
                x = mx - 24 * 2, 
                y = my - 24 * 2, 
                width = 24 * 2, 
                height = 24 * 2 
            })
        end

        -- Draw background and border (using vanilla colors)
        self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
        self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
        
        -- Draw the tooltip content
        HFO_WeaponPart_DoTooltip(self.item, self.tooltip)
    end
end