require "ISUI/ISToolTipInv"
require "ISUI/ISUIElement"
require "HFO_Utils"

HFO = HFO or {}
HFO.Utils = HFO.Utils or {}
HFO.Tooltips = HFO.Tooltips or {}


---===========================================---
--        EXPANDED STATS WEAPON TOOLTIP        --
---===========================================---

-- Create a simple options table
HFO_Tooltip = {
    Options = {
        Color = {
            r = 0.2,
            g = 0.7,
            b = 0.7
        },
        ShowGunPlating = true
    },
    StatPairs = {},
    Expanded = false
}

-- Fix for the initStats function in HFO_Tooltip to use display values
function HFO_Tooltip:initStats(item)
    -- Only process firearms
    if not item or not instanceof(item, "HandWeapon") or item:getSubCategory() ~= "Firearm" then
        return false
    end

    -- Clear previous data
    self.StatPairs = {}

    local options = {
        skipAmmo = not self.Expanded,
        includeDebug = false,
        includePlating = true,
    }

    local stats = HFO.Utils.getWeaponStats(item, options)

    -- Always show plating if attached and valid
    for _, stat in ipairs(stats) do
        if stat.label == "Gun Plating" then
            local displayValue = stat.formatted or stat.value
            if displayValue and type(displayValue) == "string" and displayValue ~= "Invalid" then
                table.insert(self.StatPairs, {
                    label = stat.label .. ":",
                    value = displayValue
                })
            end
            break
        end
    end

    -- Add toggle instruction
    if self.Expanded then
        -- Define stats order with numeric values for sorting priority
        local statsOrder = {
            ["Damage"] = 1,
            ["Range"] = 2,
            ["Max Hits"] = 3,
            ["Projectile Count"] = 4,
            ["Jam Chance"] = 5,
            ["Hit Chance"] = 6,
            ["Critical Chance"] = 7,
            ["Recoil Delay"] = 8,
            ["Firing Cone"] = 9,
            ["Aiming Speed"] = 10,
            ["Reload Speed"] = 11,
            ["Sound Radius"] = 12,
            ["Suppressor"] = 13,
        }
        
        -- Create a temporary array to hold stats for sorting
        local orderedStats = {}
        
        -- Collect all allowed stats
        for _, stat in ipairs(stats) do
            local label = stat.label
            if statsOrder[label] then
                table.insert(orderedStats, {
                    order = statsOrder[label],
                    label = label,
                    value = stat.formatted or stat.value
                })
            end
        end
        
        -- Sort by our predefined order
        table.sort(orderedStats, function(a, b) 
            return a.order < b.order 
        end)
        
        -- Add the sorted stats to StatPairs
        for _, orderedStat in ipairs(orderedStats) do
            table.insert(self.StatPairs, {
                label = orderedStat.label .. ":",
                value = orderedStat.value
            })
        end

        -- Separator
        table.insert(self.StatPairs, {label = " ", value = " "})
        table.insert(self.StatPairs, {
            label = "Press [Shift+E]",
            value = "to collapse"
        })
        table.insert(self.StatPairs, {label = " ", value = " "})
    else
        table.insert(self.StatPairs, {
            label = "Press [Shift+E]",
            value = "to expand"
        })
    end

    return true
end


---===========================================---
--      RENDERING OF EXPANDED WEAPON STATS     --
---===========================================---

-- Store the original render function
local orig_render = ISToolTipInv.render

-- Override the render function with better value checking
function ISToolTipInv:render()
    -- Check if we have a valid item and initialize stats
    if not self.item or not HFO_Tooltip:initStats(self.item) then
        return orig_render(self)
    end

    local font = UIFont[getCore():getOptionTooltipFont()]
    local colors = HFO_Tooltip.Options.Color
    local lineSpacing = self.tooltip:getLineSpacing()
    local height = self.tooltip:getHeight()
    local minExtraHeight = 8

    -- Calculate max label width for alignment
    local maxLabelWidth = 0

    -- Get stack weight (if present)
    local weightOfStack = self.tooltip:getWeightOfStack() or 0
    local hasStackWeight = weightOfStack > 0

    if hasStackWeight then
        local stackLabel = getText("Tooltip_item_StackWeight")
        local stackWidth = getTextManager():MeasureStringX(font, stackLabel)
        maxLabelWidth = math.max(maxLabelWidth, stackWidth)
    end

    -- First check all our custom labels
    for _, pair in ipairs(HFO_Tooltip.StatPairs) do
        local label = pair.label or ""
        local width = getTextManager():MeasureStringX(font, label)
        if width > maxLabelWidth then maxLabelWidth = width end
    end

    -- Get the vanilla label width using the actual magazine/ammo type
    local fallbackLabel = ""
    local hasMagType = self.item:getMagazineType() and self.item:getMagazineType() ~= ""
    if hasMagType then
        fallbackLabel = HFO.Utils.getDisplayNameFromFullType(self.item:getMagazineType())
    else
        fallbackLabel = HFO.Utils.getDisplayNameFromFullType(self.item:getAmmoType())
    end

    -- Add some padding to match vanilla tooltip formatting
    local fallbackWidth = getTextManager():MeasureStringX(font, fallbackLabel or "")

    -- Use the larger of our own max label width or vanilla's
    maxLabelWidth = math.max(maxLabelWidth, fallbackWidth)

    -- Now calculate total number of lines needed and track if any wrapping occurs
    local totalLines = 0
    
    for _, pair in ipairs(HFO_Tooltip.StatPairs) do
        -- Convert value to string and handle nil case
        local valueText = pair.value ~= nil and tostring(pair.value) or ""
        local padding = 5
        local valueX = 10 + maxLabelWidth + padding
        local maxValueWidth = self.tooltip:getWidth() - valueX - 10
        
        -- Safety checks for valid value
        local valueWidth = 0
        if valueText ~= "" then
            valueWidth = getTextManager():MeasureStringX(font, valueText)
        end

        if valueWidth > maxValueWidth then
            totalLines = totalLines + 2 -- one extra wrap
        else
            totalLines = totalLines + 1
        end
    end

    -- Calculate new height based on content needs
    local newHeight = height + totalLines * lineSpacing
    
    if not HFO_Tooltip.Expanded then
        newHeight = newHeight + minExtraHeight
    end

    -- Store original methods
    local orig_setHeight = ISToolTipInv.setHeight
    local orig_drawRectBorder = ISToolTipInv.drawRectBorder

    -- Override height with correct line wrapping support
    self.setHeight = function(self, h, ...)
        h = newHeight
        self.keepOnScreen = false
        return orig_setHeight(self, h, ...)
    end

    -- Override border drawing to add our text
    self.drawRectBorder = function(self, ...)
        orig_drawRectBorder(self, ...)

        -- Draw stat pairs with aligned values
        local currentY = height
        for _, pair in ipairs(HFO_Tooltip.StatPairs) do
            local label = pair.label or ""
            
            -- Draw label in cyan
            self.tooltip:DrawText(
                font, label, 5, currentY,
                colors.r, colors.g, colors.b, 1
            )
            
            -- Handle value text wrapping if needed
            local valueText = pair.value ~= nil and tostring(pair.value) or ""
            local padding = 5  -- tweak this number based on font rendering
            local valueX = 10 + maxLabelWidth + padding
            local maxValueWidth = self.tooltip:getWidth() - valueX - 10 -- 10px right margin
            
            local valueWidth = 0
            if valueText ~= "" then
                valueWidth = getTextManager():MeasureStringX(font, valueText)
            end
            
            if valueWidth > maxValueWidth and valueText:len() > 0 then
                -- Find a good split point (space character)
                local splitPos = math.floor(valueText:len() * (maxValueWidth / valueWidth))
                -- Make sure splitPos is at least 1 and at most the length of the text
                splitPos = math.max(1, math.min(splitPos, valueText:len()))
                
                local breakPos = valueText:find(" ", math.floor(splitPos/2))
                -- If no space found, just split at calculated position
                if not breakPos or breakPos <= 0 or breakPos > valueText:len() then
                    breakPos = splitPos
                end
                
                -- Safety check to make sure we don't go out of bounds
                breakPos = math.max(1, math.min(breakPos, valueText:len()))
                
                -- First line of the value
                self.tooltip:DrawText(
                    font, valueText:sub(1, breakPos-1), valueX, currentY,
                    1, 1, 1, 1
                )
                
                -- Second line of the value (indented)
                currentY = currentY + lineSpacing
                -- Check if we have something to display in the second line
                if breakPos < valueText:len() then
                    self.tooltip:DrawText(
                        font, valueText:sub(breakPos+1), valueX, currentY,
                        1, 1, 1, 1
                    )
                end
            else
                -- Normal single-line display
                self.tooltip:DrawText(
                    font, valueText, valueX, currentY,
                    1, 1, 1, 1
                )
            end
            
            currentY = currentY + lineSpacing
        end
    end

    -- Call original render
    orig_render(self)

    -- Restore original methods
    self.setHeight = orig_setHeight
    self.drawRectBorder = orig_drawRectBorder
end

-- Add keyboard toggle
Events.OnKeyPressed.Add(function(key)
    if key == Keyboard.KEY_E and isKeyDown(Keyboard.KEY_LSHIFT) then
        HFO_Tooltip.Expanded = not HFO_Tooltip.Expanded
    end
end)