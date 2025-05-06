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

-- Fixed layout for Mount-On display
local function renderMountOnFixedColumns(item, font, tooltip, startX, startY)
    if not item or not tooltip then return startY end

    local mountList = item:getMountOn()
    if not mountList or mountList:isEmpty() then return startY end

    local names = {}
    for i = 0, mountList:size() - 1 do
        local fullType = mountList:get(i)
        if not HFO.Utils.shouldSkipSuffix or not HFO.Utils.shouldSkipSuffix(fullType) then
            local name = HFO.Utils.getDisplayNameFromFullType(fullType)
            table.insert(names, name)
        end
    end

    if #names == 0 then return startY end

    -- Sort alphabetically (case-insensitive)
    table.sort(names, function(a, b)
        return tostring(a):lower() < tostring(b):lower()
    end)

    -- Draw header
    tooltip:DrawText(font, getText("Tooltip_weapon_CanBeMountOn") .. ":", startX, startY, 1.0, 1.0, 0.8, 1.0)
    local spacing = tooltip:getLineSpacing()
    local y = startY + spacing

    local textManager = getTextManager()
    local padding = 8
    local currentX = startX
    local currentY = y
    local maxWidth = tooltip:getWidth() - startX - 10

    for i, name in ipairs(names) do
        local text = name .. (i < #names and "," or "")
        local width = textManager:MeasureStringX(font, text)

        -- Wrap if exceeding width
        if currentX + width > startX + maxWidth then
            currentX = startX
            currentY = currentY + spacing
        end

        tooltip:DrawText(font, text, currentX, currentY, 1, 1, 1, 1)
        currentX = currentX + width + padding
    end

    return currentY + spacing
end

---===========================================---
--    PULLING IN THE NECESSARY TOOLTIP INFO    --
---===========================================---

-- Custom tooltip function for weapon parts with improved error handling
function HFO_WeaponPart_DoTooltip(weaponPart, tooltip)
    if not weaponPart or not tooltip then return end
    
    local font = UIFont.Small
    local x = 5
    local y = 5
    local spacing = tooltip:getLineSpacing()
    local textManager = getTextManager()
    
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
        y = renderMountOnFixedColumns(weaponPart, font, tooltip, x, y)
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

        if formattedChanges  and #formattedChanges  > 0 then
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
        tooltip:setHeight(y + 10)
    end
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

        -- First pass: calculate dynamic width
        local font = UIFont.Small
        local textManager = getTextManager()
        local initialWidth = 300  -- Starting width
        
        -- Get all weapon names to check lengths
        local fullTypes = self.item:getMountOn()
        local longestName = 0
        
        if fullTypes and not fullTypes:isEmpty() then
            for i = 0, fullTypes:size() - 1 do
                local fullType = fullTypes:get(i)
                if fullType and (not HFO.Utils.shouldSkipSuffix or not HFO.Utils.shouldSkipSuffix(fullType)) then
                    local name = HFO.Utils.getDisplayNameFromFullType(fullType)
                    local width = textManager:MeasureStringX(font, tostring(name))
                    if width > longestName then
                        longestName = width
                    end
                end
            end
        end
        
        -- Calculate ideal width to fit 3 average weapon names per row
        local padding = 8
        local targetWidth = math.max(initialWidth, (longestName + padding) * 3)
        
        -- Set width and measure tooltip
        self.tooltip:setWidth(targetWidth)
        self.tooltip:setMeasureOnly(true)
        HFO_WeaponPart_DoTooltip(self.item, self.tooltip)
        self.tooltip:setMeasureOnly(false)

        -- Position the tooltip on screen
        local myCore = getCore()
        local maxX = myCore:getScreenWidth()
        local maxY = myCore:getScreenHeight()

        local tw = self.tooltip:getWidth()
        local th = self.tooltip:getHeight()
        
        -- If tooltip would go off screen, limit width and re-measure
        if mx + 11 + tw > maxX then
            local newWidth = maxX - mx - 11 - 10  -- 10px margin
            if newWidth < initialWidth then newWidth = initialWidth end
            
            self.tooltip:setWidth(newWidth)
            self.tooltip:setMeasureOnly(true)
            HFO_WeaponPart_DoTooltip(self.item, self.tooltip)
            self.tooltip:setMeasureOnly(false)
            
            tw = self.tooltip:getWidth()
            th = self.tooltip:getHeight()
        end
        
        self.tooltip:setX(math.max(0, math.min(mx + 11, maxX - tw - 1)))
        if not self.followMouse and self.anchorBottomLeft then
            self.tooltip:setY(math.max(0, math.min(my - th, maxY - th - 1)))
        else
            self.tooltip:setY(math.max(0, math.min(my, maxY - th - 1)))
        end

        -- Position the panel containing the tooltip
        self:setX(self.tooltip:getX() - 11)
        self:setY(self.tooltip:getY())
        self:setWidth(tw + 11)
        self:setHeight(th)

        -- Avoid overlap with cursor
        if self.followMouse then
            self:adjustPositionToAvoidOverlap({ x = mx - 24 * 2, y = my - 24 * 2, width = 24 * 2, height = 24 * 2 })
        end

        -- Draw background and border (using vanilla colors)
        self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
        self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
        
        -- Draw the tooltip content mostly copying how vanilla builds their tooltips
        HFO_WeaponPart_DoTooltip(self.item, self.tooltip)
    end
end