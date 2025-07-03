require "ISUI/ISUIElement"
require "Vehicles/ISUI/ISUI3DScene"

function classifyWeaponSize(weapon)
    local name = weapon:getFullType() or ""
    local wt = weapon:getWeight() or 1

    -- Check if the gun is folded (either by ModData flag or naming)
    local isFolded = weapon:getModData() and weapon:getModData().FoldSwap
    if isFolded or string.find(name, "_Folded") then
        return "small"
    end

    -- Specific overrides
    local forceSmallWeapons = {
        "P90", "PM63RAK", 
    }
    for _, weaponName in ipairs(forceSmallWeapons) do
        if string.find(name, weaponName) then
            return "small"
        end
    end

    local forceMediumWeapons = {
        "PLR16", "MosinNagantObrez", "CrossbowCompound", "ASVal", 
        "FG42_Bipod", "Ruger1022", "PneumaticBlowgun"
    }
    for _, weaponName in ipairs(forceMediumWeapons) do
        if string.find(name, weaponName) then
            return "medium"
        end
    end

    local forceLargeWeapons = {
        "AK103", "AK74", "HenryRepeatingBigBoy", "BrowningBLR", 
        "Marlin39A", "MosinNagant", "M1Garand", "SVDDragunov", "Springfield1861"
    }
    for _, weaponName in ipairs(forceLargeWeapons) do
        if string.find(name, weaponName) then
            return "large"
        end
    end

    -- Standard classification with more granular sizing
    if wt <= 2.5 then
        return "small"   -- All pistols and light weapons
    elseif wt <= 5.0 then
        return "medium"  -- SMGs, carbines, medium rifles
    elseif wt <= 8.0 then
        return "large"   -- Full-size rifles
    else
        return "xlarge"  -- Heavy weapons (MG42, Barrett, etc.)
    end
end

-- A few guns models are flipped due to item script setup
function flipModelFix(weapon)
    local name = weapon:getFullType() or ""
    
    local weaponNeedingFlip = {
        "P90", "MiniUzi", "CrossbowPistol"
    }
    
    for _, weaponName in ipairs(weaponNeedingFlip) do
        if string.find(name:upper(), weaponName:upper()) then
            return true
        end
    end
    
    return false
end

local function isValidMagazineForGun(part, weapon)
    -- Get the part's full type
    local partFullType = part:getFullType()
    if not partFullType then return false end
    
    -- List of valid magazine types for this weapon
    local validTypes = {
        weapon:getMagazineType(),                  -- Base magazine
        weapon:getModData().MagExtSm or "",        -- Small extended magazine
        weapon:getModData().MagExtLg or "",        -- Large extended magazine
        weapon:getModData().MagDrum or "",         -- Drum magazine
        weapon:getModData().MagBase or ""          -- Explicit base magazine override
    }
    
    -- Check if part matches any valid magazine type
    for _, validType in ipairs(validTypes) do
        if validType and validType ~= "" and partFullType == validType then
            return true
        end
    end
    
    return false
end

local function isFilteredOut(part, att, weapon)
    if not part or not att or not weapon then return true end
    local name = part:getDisplayName() or ""
    local fullName = part:getFullType() or ""

    -- Filter out legacy plating conversions
    if name:find("CONVERT") or fullName:find("CONVERT") then return true end

    -- Filter out LaserRed and LaserGreen accessories
    if fullName:find("LaserRed") or fullName:find("LaserGreen") then return true end

    -- Filter out mags that don't match the base or extended
    if att.id == "Clip" and not isValidMagazineForGun(part, weapon) then return true end

    return false
end

-- Add this function to format ModData values for display
local function getDisplayNameForValue(value)
    if type(value) ~= "string" then return tostring(value) end
    
    if value:find("^Base%.") then
        local itemName = value:gsub("^Base%.", "")
        local item = InventoryItemFactory.CreateItem(value)
        if item then
            return item:getDisplayName() or itemName
        end
        return itemName
    end
    
    return value
end

HFO_WeaponViewer = ISPanel:derive("HFO_WeaponViewer")

-- Parse plating options safely
local function parsePlatingOptions(weapon)
    local base = weapon:getModData().GunBaseModel or (weapon:getWeaponSprite() or weapon:getStaticModel())
    local options = {}

    if base and base ~= "" then
        table.insert(options, base) -- base model first
    end

    local raw = weapon:getModData() and weapon:getModData().GunPlatingOptions
    if raw and raw ~= "" then
        for opt in string.gmatch(raw, "([^;]+)") do
            opt = opt:trim()
            if opt ~= "" and opt ~= base then
                table.insert(options, opt)
            end
        end
    end

    return options
end

local function getScaledFont(baseSize)
    local screenW = getCore():getScreenWidth()
    if screenW >= 2560 then
        if baseSize == UIFont.Small then return UIFont.Medium
        elseif baseSize == UIFont.Medium then return UIFont.Large
        end
    end
    return baseSize
end

function HFO_WeaponViewer:new(x, y, width, height, weapon)
    local o = ISPanel.new(self, x, y, width, height)
    
    o.backgroundColor = {r=0.1, g=0.1, b=0.1, a=0.9}
    o.borderColor = {r=0.6, g=0.6, b=0.6, a=0.95}
    
    o.addedAttachments = {} 
    o.title = weapon:getDisplayName() or "Inspect Weapon"
    o.isHandgun = (weapon:getSwingAnim() == "Handgun")
    o.modelId = "weaponModel"
    o.weapon = weapon
    
    local options = parsePlatingOptions(weapon)
    o.availablePlatings = options
    local currentPlating = weapon:getModData().GunPlating or options[1]
    local foundIndex = 1
    for i = 1, #options do
        if options[i] == currentPlating then
            foundIndex = i
            break
        end
    end
    o.previewPlatingIndex = foundIndex
    o.originalPlating = weapon:getModData().GunPlating
    o.platingLabel = nil
    o.leftBtn = nil
    o.rightBtn = nil
    o.debugDetailsVisible = false
    o.detailsVisible = false
    o.detailsPanel = nil
    o.attachmentsVisible = false
    o.attachmentsPanel = nil
    o.moveWithMouse = true
    o.closable = true
    return o
end

function HFO_WeaponViewer:addWeaponAttachments()
    if not self.weapon then return end
    local weaponModelName =  self.weapon:getStaticModel() or self.weapon:getWeaponSprite() --Get Parent Model of Weapon for attachment points
    if not weaponModelName then return end

    local weaponFullType = "Base." .. weaponModelName
    local modelScript = getScriptManager():getModelScript(weaponFullType) --make sure we can pull from the weapons model script for rotation and offset
    if not modelScript then return end

    local attachmentPoints = {} -- establish table for attachmentPoint index
    for i = 0, modelScript:getAttachmentCount() - 1 do
        local attach = modelScript:getAttachment(i)
        if attach then 
            attachmentPoints[attach:getId()] = {
                offset = attach:getOffset(),
                rotate = attach:getRotate(),
                raw = attach
            }
        end
    end

    local parts = self.weapon:getAllWeaponParts() -- grab weapon part info for matching to attachment points
    if not parts or parts:isEmpty() then return end

    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        local modelName = part and part:getStaticModel()
        local slot = part and part:getModData() and part:getModData().AttachmentSlot -- added moddata in attachment item script since it was the easiest way to do matches
        if modelName and slot and attachmentPoints[slot] then
            local modelId = "attachment_" .. slot:lower()
            local modelFullType = modelName:find("^Base%.") and modelName or ("Base." .. modelName)
            table.insert(self.addedAttachments, modelId)
            self.scene.javaObject:fromLua2("createModel", modelId, modelFullType)
            self.scene.javaObject:fromLua4("setObjectParent", modelId, nil, self.modelId, slot)
        end
    end
end

function HFO_WeaponViewer:removeWeaponAttachments()
    if not self.scene or not self.addedAttachments then return end

    for _, modelId in ipairs(self.addedAttachments) do
        if modelId ~= self.modelId then -- Don't remove the main model
            self.scene.javaObject:fromLua1("removeModel", modelId)
        end
    end

    -- Keep the main model in the attachments list
    local newAttachments = {}
    for _, modelId in ipairs(self.addedAttachments) do
        if modelId == self.modelId then
            table.insert(newAttachments, modelId)
        end
    end
    self.addedAttachments = newAttachments
end



function HFO_WeaponViewer:initialise()
    ISPanel.initialise(self)
    local padding, sceneHeight = 10, 260
    self.sizeClass = classifyWeaponSize(self.weapon)

    local screenW, screenH = getCore():getScreenWidth(), getCore():getScreenHeight()

    local resolutionScale = math.min(screenW / 1280, screenH / 720)
    resolutionScale = math.max(0.7, math.min(resolutionScale, 2.5))
    
    local hasBarrel = self.weapon:getCanon() ~= nil
    local useRifleOrientation = flipModelFix(self.weapon)
    local baseX = 90.0

    local weaponName = self.weapon:getFullType() or ""

    if (self.weapon:getSwingAnim() == "Handgun" or useRifleOrientation) and not string.find(weaponName:lower(), "obrez") then
        baseX = (baseX + 180) % 360
    end

    self.viewRotation = { x = baseX, y = 180.0, z = 90.0 }
    self.resetViewRotation = { x = baseX, y = 180.0, z = 90.0 }
    
    local sizeConfigs = {
        small  = { zoom = 17, origin = { x = -90, y = -10 }, baseWidth = 500, widthFactor = 0.45 },
        medium = { zoom = 15, origin = { x = -110, y = -10 }, baseWidth = 600, widthFactor = 0.5 },
        large  = { zoom = 14, origin = { x = -160, y = 0 }, baseWidth = 750, widthFactor = 0.55 },
        xlarge = { zoom = 14, origin = { x = -200, y = 0 }, baseWidth = 900, widthFactor = 0.6 },
    }
    local cfg = sizeConfigs[self.sizeClass] or sizeConfigs["medium"]
    self.zoomLevel = cfg.zoom
    self.viewOrigin = { 
        x = cfg.origin.x * resolutionScale, 
        y = cfg.origin.y * resolutionScale 
    }
    self:setWidth(math.min(math.floor(cfg.baseWidth * resolutionScale), screenW * cfg.widthFactor))

    -- Apply barrel attachment adjustments
    if hasBarrel then
        self:setWidth(self:getWidth() + math.floor(80 * resolutionScale))
        self.viewOrigin.x = self.viewOrigin.x - 20
    end
    
    -- Scale scene height with resolution but keep reasonable bounds
    sceneHeight = math.floor(sceneHeight * math.max(0.8, resolutionScale))
    sceneHeight = math.max(250, math.min(sceneHeight, 400))
    
    self:setHeight(sceneHeight + 160)
    self:setX(math.floor(screenW * 0.03))
    self:setY(math.floor(screenH * 0.03))

    self.closeBtn = ISButton:new(self.width - 30, 8, 20, 20, "X", self, function()
        self:removeFromUIManager()
        HFO_WeaponViewer_Instance = nil
    end)
    self.closeBtn:initialise()
    self:addChild(self.closeBtn)
    
    local nameLabel = ISLabel:new(10, 10, 20, self.weapon:getDisplayName(), 1, 1, 1, 1, getScaledFont(UIFont.Medium), true)
    self:addChild(nameLabel)

    if isDebugEnabled() or isAdmin() then
        local debugBtn = ISButton:new(nameLabel:getRight() + 10, 10, 60, 20, "DEBUG", self, function()
            if not self.detailsVisible then
                self.detailsVisible = true
                self.detailsPanel:setVisible(true)
            end
            self.debugDetailsVisible = not self.debugDetailsVisible
            self:updateDetailsPanel()
            self:refreshLayout()
        end)
    
        debugBtn:setAnchorLeft(true)
        debugBtn:setAnchorTop(true)
        debugBtn:setAnchorRight(false)
        debugBtn:setAnchorBottom(false)
    
        -- Optional: recolor for admin flavor
        debugBtn.backgroundColor = { r = 0.5, g = 0.2, b = 0.2, a = 1 }
        debugBtn.backgroundColorMouseOver = { r = 0.6, g = 0.2, b = 0.2, a = 1 }
        debugBtn.borderColor = { r = 0.6, g = 0.2, b = 0.2, a = 1 }
        debugBtn:setTooltip("Toggle Debug Details")
    
        debugBtn:initialise()
        self:addChild(debugBtn)
    end

    -- Predefine plating UI row offset
    local platingYOffset = 0

    -- Gun plating UI - add second row below title if options exist
    if #self.availablePlatings > 1 then
        local currentPlatingName = self:getDisplayName(self.availablePlatings[self.previewPlatingIndex])
        local platingY = 38  -- below the title line (y=10 + 20 height + a little padding)
        platingYOffset = 30  -- we will apply this later once scene exists

        -- Static label
        local title = ISLabel:new(10, platingY, 20, "Cycle Gun Plating:", 1, 1, 1, 1, getScaledFont(UIFont.Small), true)
        self:addChild(title)

        -- Left button
        self.leftBtn = ISButton:new(title:getRight() + 10, platingY - 2, 20, 20, "<", self, HFO_WeaponViewer.onPrevPlating)
        self.leftBtn:initialise(); self:addChild(self.leftBtn)

        -- Right button
        self.rightBtn = ISButton:new(self.leftBtn:getRight() + 6, platingY - 2, 20, 20, ">", self, HFO_WeaponViewer.onNextPlating)
        self.rightBtn:initialise(); self:addChild(self.rightBtn)

        -- Dynamic plating name label
        self.platingLabel = ISLabel:new(self.rightBtn:getRight() + 10, platingY, 20, currentPlatingName, 0.2, 0.7, 0.7, 1, getScaledFont(UIFont.Small), true)
        self:addChild(self.platingLabel)
    end

    self.scene = ISUI3DScene:new(padding, 38, self:getWidth() - 2 * padding, sceneHeight)
    self.scene.backgroundColor = { r = 0.05, g = 0.05, b = 0.05, a = 1 } -- background color of 3d scene not parent container
    self.scene.borderColor = { r = 0.3, g = 0.3, b = 0.3, a = 1 }        -- border styling of 3d scene not parent container
    self.scene.background = true -- can go full transparent but thought it didn't work well
    self.scene:initialise()
    self.scene:instantiate()
    self.scene:setView("UserDefined")
    self.scene.javaObject:fromLua1("setDrawGrid", false) -- no grid lines
    self.scene.javaObject:fromLua1("setDrawGridAxes", false)
    self.scene.javaObject:fromLua1("setDrawGridPlane", false)
    self.scene.javaObject:fromLua1("setGridPlane", "XZ")
    self.scene.javaObject:fromLua1("setMaxZoom", 25.0) -- can change for more zoom levels
    self:addChild(self.scene)

    -- Adjust scene Y *and height*, but don't touch self.controlsY yet
    if platingYOffset > 0 then
        self.scene:setY(self.scene:getY() + platingYOffset)
        self:setHeight(self:getHeight() + platingYOffset)
    end

    -- Create the weapon model - IMPORTANT: do this in the right order
    local modelScript = self.weapon:getWeaponSprite() or self.weapon:getStaticModel()
    if modelScript then
        -- Strip "Base." if it's already present to avoid duplication
        local baseName = modelScript:gsub("^Base%.", "")
        local fullType = "Base." .. baseName

        self.scene.javaObject:fromLua2("createModel", self.modelId, fullType)
        table.insert(self.addedAttachments, self.modelId)
        self:addWeaponAttachments()
        self:setView(self.viewRotation.x, self.viewRotation.y, self.viewRotation.z)
        self.scene.javaObject:fromLua1("setZoom", self.zoomLevel)
        self.scene.javaObject:fromLua2("dragView", self.viewOrigin.x, self.viewOrigin.y)
    end

    -- Basic tooltip about wheel zoom and sliders
    local tooltipY = 38 + platingYOffset + sceneHeight
    self:addChild(ISLabel:new(padding, tooltipY, 30,
    "Mouse Wheel to Zoom | Click and Drag to Move Model", 0.8, 0.8, 0.8, 1, getScaledFont(UIFont.Small), true))

    -- Layout calculations for controls section
    self.controlsY = 38 + sceneHeight + 30 + platingYOffset
    local controlsWidth = self:getWidth() - 2 * padding
    local buttonWidth = math.max(100, controlsWidth * 0.15)
    local sliderCol = padding + buttonWidth + 20
    local btnYIndex = 0

    -- Helper: adds styled button with hover + tooltip
    local function addButton(label, tooltip, action)
        local b = ISButton:new(padding, self.controlsY + (btnYIndex * 28), buttonWidth, 24, label, self, action)
        b:initialise()
        b:setTooltip(tooltip)

        -- Optional: hover color effect
        b.backgroundColorMouseOver = { r = 0.1, g = 0.3, b = 0.1, a = 0.9 }  -- muted mossy green
        b.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }

        self:addChild(b)
        btnYIndex = btnYIndex + 1
    end

    -- Buttons
    addButton("RESET",      "Reset the model rotation and zoom", function() self:resetView() end)
    addButton("ATTACHMENTS","Toggle weapon attachment panel",   function() self:toggleAttachments() end)
    addButton("DETAILS",    "Toggle weapon stat breakdown",     function() self:toggleDetails() end)

    -- Add a spacer before sliders
    btnYIndex = btnYIndex + 1

    local props = {"x", "y", "z"}
    for i = 1, 3 do
        local axis = props[i]
        local y = self.controlsY + (i - 1) * 28
    
        self:addChild(ISLabel:new(sliderCol, y + 4, 20, axis:upper() .. ":", 1, 1, 1, 1, getScaledFont(UIFont.Small), true))
    
        local slider = ISSliderPanel:new(sliderCol + 25, y, controlsWidth - buttonWidth - 55, 24, self, function(_, val)
            local v = val
            if axis ~= "z" then
                v = self.resetViewRotation[axis] + val
            end
            self.viewRotation[axis] = v
            self:setRawRotation(self.viewRotation.x, self.viewRotation.y, self.viewRotation.z)
        end)
        
        slider:initialise()
        slider:setValues(-90, 90, 5, 0)
        slider.axis = axis
        self:addChild(slider)
    end

    -- attachment panel for attachment showcase
    self.attachmentsPanel = ISPanel:new(padding, self.height, self:getWidth() - 2 * padding, 100)
    self.attachmentsPanel:initialise()
    self.attachmentsPanel.backgroundColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.9 }
    self.attachmentsPanel.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    self.attachmentsPanel:setVisible(false)
    self:addChild(self.attachmentsPanel)

    -- details panel for weapon info
    self.detailsPanel = ISPanel:new(padding, self.height, self:getWidth() - 2 * padding, 80)
    self.detailsPanel:initialise()
    self.detailsPanel.backgroundColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.9 }
    self.detailsPanel.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    self.detailsPanel:setVisible(false)  -- starts false so can't see until details button makes true
    self:addChild(self.detailsPanel)

    self.baseHeight = self:getHeight()
    self:resetView()
    
    return self
end

function HFO_WeaponViewer:setView(rx, ry, rz)
    self.viewRotation = { x = rx, y = ry, z = rz }
    self:setRawRotation(rx, ry, rz)
    self:updateSliders()
end

function HFO_WeaponViewer:setRawRotation(rx, ry, rz)
    self.scene.javaObject:fromLua3("setViewRotation", rx, ry, rz)
    self.scene.javaObject:fromLua2("dragView", -self.viewOrigin.x, -self.viewOrigin.y)
    self.scene.javaObject:fromLua2("dragView", self.viewOrigin.x, self.viewOrigin.y)
end

function HFO_WeaponViewer:resetView()
    local rot = self.resetViewRotation
    self:setView(rot.x, rot.y, rot.z)
    self.scene.javaObject:fromLua1("setZoom", self.zoomLevel)
    self:updateSliders()
end

function HFO_WeaponViewer:updateSliders()
    if not self.controlsY then return end
    for _, child in ipairs(self:getChildren()) do
        if instanceof(child, "ISSliderPanel") and child.axis then
            local axis = child.axis
            local offset = self.viewRotation[axis] - self.resetViewRotation[axis]
            child:setValue(offset)
        end
    end
end

-- Update the details panel with truncated values and tooltips
function HFO_WeaponViewer:updateDetailsPanel()
    self.detailsPanel:clearChildren()

    local wpn = self.weapon
    if not wpn then return end

    -- Use the unified stats generator to get all weapon stats
    local options = {
        includeDebug = self.debugDetailsVisible,
        skipAmmo = false,
        includePlating = true
    }
    
    local stats = HFO.Utils.formatWeaponStats(HFO.Utils.getRawWeaponStats(wpn, getPlayer(), options))
    
    -- Convert to details format
    local details = {}

    -- Mapping of important stat order
    local statOrder = {
        ["Damage"] = 1,
        ["Aiming Speed"] = 2,
        ["Range"] = 3,
        ["Firing Cone"] = 4,
        ["Hit Chance"] = 5,
        ["Reload Speed"] = 6,
        ["Critical Chance"] = 7,
        ["Ammo"] = 8,
        ["Recoil Delay"] = 9,
        ["Ammo Type"] = 10,
        ["Jam Chance"] = 11,
        ["Magazine Type"] = 12,
        ["Condition"] = 13,
        ["Sound Radius"] = 14,
        ["Gun Plating"] = 15,
        ["Suppressor"] = 16
    }
    
    -- Filter stats to only include those in statOrder
    local filteredStats = {}
    for _, stat in ipairs(stats) do
        -- Only include stats in statOrder
        if statOrder[stat.label] then
            table.insert(filteredStats, stat)
        end
    end

    -- Sort the stats by our preferred order
    table.sort(filteredStats, function(a, b)
        local orderA = statOrder[a.label] or 100
        local orderB = statOrder[b.label] or 100
        return orderA < orderB
    end)
    
    -- Add core stats first
    for _, stat in ipairs(filteredStats) do
        if not stat.debug then
            table.insert(details, {
                label = stat.label,
                value = stat.formatted or stat.value,
                fullValue = stat.formatted and stat.value ~= stat.formatted and stat.value or nil
            })
        end
    end

    -- Only add debug info if requested
    if self.debugDetailsVisible and (isDebugEnabled() or isAdmin()) then
        -- Add stats marked as debug
        for _, stat in ipairs(filteredStats) do
            if stat.debug then
                table.insert(details, {
                    label = stat.label,
                    value = stat.formatted or stat.value,
                    fullValue = stat.formatted and stat.value ~= stat.formatted and stat.value or nil,
                    debug = true
                })
            end
        end
        
        -- Add important ModData entries
        local md = wpn:getModData()
        if md then
            local importantKeys = {
                "GunPlating", "GunPlatingOptions", 
                "GunBaseModel", "FoldSwap",
                "MagBase", "MagExtSm", "MagExtLg", "MagDrum"
            }
            
            -- Process ModData entries directly, without nesting loops
            for _, k in ipairs(importantKeys) do
                if md[k] then
                    local v = md[k]
                    local rawValue = tostring(v)
                    local displayValue = getDisplayNameForValue(rawValue)
                    
                    -- Truncate long values
                    local truncatedValue = displayValue
                    if #displayValue > 20 then
                        truncatedValue = displayValue:sub(1, 17) .. "..."
                    end
                    
                    table.insert(details, {
                        label = k,
                        value = truncatedValue,
                        fullValue = #displayValue > 25 and displayValue or nil,
                        debug = true
                    })
                end
            end
        end
    end

    -- Layout constants
    local padding = 50
    local rowHeight = 20
    local panelWidth = self.detailsPanel:getWidth()
    local colWidth = math.floor((panelWidth - padding * 3) / 2)
    local labelWidth = math.min(80, colWidth * 0.4)
    
    -- Better centering
    local totalContentWidth = colWidth * 2 + padding
    local centerX = math.floor((panelWidth - totalContentWidth) / 2)

    -- Create all the label-value pairs
    for i, d in ipairs(details) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)

        local xColStart = centerX + col * (colWidth + padding)
        local xLabel = xColStart
        local xValue = xColStart + labelWidth + 10
        local y = 10 + row * rowHeight

        -- Colors
        local isDebugRow = d.debug
        local labelColor = isDebugRow and {0.6, 0.8, 1} or {0.7, 0.7, 0.7}
        local valueColor = isDebugRow and {1, 1, 1} or {1, 1, 1}

        -- Format texts
        local labelText = tostring(d.label or "")
        local valueText = tostring(d.value or "")
        if #valueText > 20 then         -- Add this: Control max value length
            valueText = valueText:sub(1, 17) .. "..."  -- Add this: Control truncated length
        end

        -- Truncate label if needed
        local displayLabel = labelText
        if #labelText > 16 then
            displayLabel = labelText:sub(1, 13) .. "..."
        end

        -- Create label (right-aligned)
        local label = ISLabel:new(xLabel + labelWidth, y, rowHeight, displayLabel .. ":", labelColor[1], labelColor[2], labelColor[3], 1, getScaledFont(UIFont.Small), false)
        if displayLabel ~= labelText then
            label:setTooltip(labelText .. ":")
        end
        self.detailsPanel:addChild(label)

        -- Create value (left-aligned)
        local value = ISLabel:new(xValue, y, rowHeight, valueText, valueColor[1], valueColor[2], valueColor[3], 1, getScaledFont(UIFont.Small), true)
        if d.fullValue or #valueText > 20 then
            value:setTooltip(d.fullValue or d.value)
        end
        self.detailsPanel:addChild(value)
    end

    -- Set panel height
    local numRows = math.ceil(#details / 2)
    local contentHeight = 10 + numRows * rowHeight + 10
    local maxHeight = 300
    self.detailsPanel:setHeight(math.min(contentHeight, maxHeight))
    
    -- Adjust overall layout
    self:refreshLayout()
end


function HFO_WeaponViewer:toggleAttachments()
    self.attachmentsVisible = not self.attachmentsVisible
    self.attachmentsPanel:setVisible(self.attachmentsVisible)

    if self.attachmentsVisible then
        self:updateAttachmentsPanel()
    else
        self.attachmentsPanel:clearChildren()
    end

    self:refreshLayout()
end

-- Helper function to get formatted part stats for tooltips
function getPartStatsTooltip(part)
    if not part then return "No part" end
    
    -- Get player for accurate stat comparisons
    local player = getSpecificPlayer(0)
    local weapon = player and player:getPrimaryHandItem()
    
    if not weapon or not instanceof(weapon, "HandWeapon") or weapon:getSubCategory() ~= "Firearm" then
        -- No weapon equipped, show basic part info only
        local tooltipText = part:getDisplayName()
        local desc = getTextOrNull("Tooltip_item_" .. part:getType())
        if desc then
            tooltipText = tooltipText .. "\n\n" .. desc
        end
        return tooltipText
    end
    
    -- Get stat comparison using the new unified system
    local statChanges = HFO.Utils.compareWeaponStats(weapon, part, {
        includeExtraEffects = true,
        sort = true,
        reverse = reverse  -- Use the passed parameter
    })
    
    -- Format the stat changes for display
    local formattedChanges = HFO.Utils.formatStatComparison(statChanges)
    
    if not formattedChanges or #formattedChanges == 0 then
        -- No stat changes, show basic part info
        local tooltipText = part:getDisplayName()
        local desc = getTextOrNull("Tooltip_item_" .. part:getType())
        if desc then
            tooltipText = tooltipText .. "\n\n" .. desc
        end
        return tooltipText
    end
    
    -- Build tooltip with stat changes
    local tooltipText = "<RGB:1,1,0.8> " .. part:getDisplayName() .. " </RGB>\n\n"

    -- Add stat changes
    tooltipText = tooltipText .. "<RGB:1,1,0.8> Stat Changes: </RGB>\n"

    -- Process all stats using our formatted changes
    for _, change in ipairs(formattedChanges) do
        -- Get color directly from the already formatted data
        local r, g, b = unpack(change.color)
        local colorCode = string.format("<RGB:%.1f,%.1f,%.1f> ", r, g, b)

        -- Ensure proper spacing between the label and value
        tooltipText = tooltipText .. "<RGB:1,1,1>  - " .. change.label .. ": </RGB>" 
            .. "<RGB:0.01,0.01,0.01> .. </RGB>" ..  -- Added space between color code and formatted value
            colorCode .. change.formatted .. " <RGB:1,1,1> \n"
    end

    -- Add description if available
    local desc = getTextOrNull("Tooltip_item_" .. part:getType())
    if desc then
        tooltipText = tooltipText .. "\n" .. desc
    end

    return tooltipText
end

-- Update the attachmentsPanel function to use this new tooltip
function HFO_WeaponViewer:updateAttachmentsPanel()
    self.attachmentsPanel:clearChildren()

    local attachments = {
        { id = "Scope", key = "Tooltip_weapon_Scope", item = self.weapon:getScope() },
        { id = "Clip", key = "Tooltip_weapon_Clip", item = self.weapon:isContainsClip() and InventoryItemFactory.CreateItem(self.weapon:getMagazineType()) or nil },
        { id = "RecoilPad", key = "Tooltip_weapon_RecoilPad", item = self.weapon:getRecoilpad() },
        { id = "Sling", key = "Tooltip_weapon_Sling", item = self.weapon:getSling() },
        { id = "Stock", key = "Tooltip_weapon_Stock", item = self.weapon:getStock() },
        { id = "Canon", key = "Tooltip_weapon_Canon", item = self.weapon:getCanon() },
    }

    -- Layout calculations
    local columns = 3
    local spacing = 6  -- Reduced from 12 to 6
    local boxHeight = 64
    local boxWidth = math.floor((self.attachmentsPanel:getWidth() - (columns + 1) * spacing) / columns)
    local rows = math.ceil(#attachments / columns)
    local iconSize = 32  
    local iconBoxSize = 48  
    local headerFont = getScaledFont(UIFont.Medium)
    local contentFont = getScaledFont(UIFont.Small)

    for i, att in ipairs(attachments) do
        local col = (i - 1) % columns
        local row = math.floor((i - 1) / columns)

        local boxX = spacing + col * (boxWidth + spacing)
        local boxY = spacing + row * (boxHeight + spacing)

        -- Panel box
        local box = ISPanel:new(boxX, boxY, boxWidth, boxHeight)
        box:initialise()
        box.backgroundColor = { r = 0.14, g = 0.14, b = 0.14, a = 0.95 }
        box.borderColor = { r = 0.5, g = 0.5, b = 0.5, a = 1 }
        self.attachmentsPanel:addChild(box)

        -- Title (INSIDE box!)
        local translated = getText(att.key) or att.id
        local labelTitle = ISLabel:new(8, 8, 20, translated, 1, 1, 1, 1, headerFont, true)
        box:addChild(labelTitle)

        -- Item name (wrap if too long)
        local partName = att.item and att.item:getDisplayName() or "None"
        local line1, line2 = partName, nil
        if #partName > 24 then
            local splitPos = partName:find(" ", 16) or 25
            line1 = partName:sub(1, splitPos - 1)
            line2 = partName:sub(splitPos + 1)
        end

        local labelItem1 = ISLabel:new(8, 26, 20, line1, 0.85, 0.85, 0.85, 1, contentFont, true)
        box:addChild(labelItem1)

        if line2 then
            local labelItem2 = ISLabel:new(8, 40, 20, line2, 0.85, 0.85, 0.85, 1, contentFont, true)
            box:addChild(labelItem2)
        end

        -- Icon panel (MUST be added before tooltip logic)
        local iconFrameX = box:getWidth() - iconBoxSize - 8
        local iconFrameY = math.floor((boxHeight - iconBoxSize) / 2)

        -- Icon panel: use ISButton to allow tooltip support but style it to look like a panel
        local iconPanel = ISButton:new(iconFrameX, iconFrameY, iconBoxSize, iconBoxSize, "", self, nil)
        iconPanel:initialise()
        iconPanel:setEnable(false) -- disables interaction
        iconPanel.borderColor = { r = 0.35, g = 0.35, b = 0.35, a = 1 }
        iconPanel.backgroundColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.95 }
        iconPanel.backgroundColorMouseOver = iconPanel.backgroundColor
        iconPanel.backgroundColorClicked = iconPanel.backgroundColor
        iconPanel.borderColorMouseOver = iconPanel.borderColor
        iconPanel.borderColorClicked = iconPanel.borderColor
        box:addChild(iconPanel)

        -- Create an enhanced tooltip for the current attachment if it exists
        if att.item then
            -- For attached parts, create a comparison that shows what the stats would be without it
            local statsTooltip = getPartStatsTooltip(att.item, true) -- Pass true to indicate reverse mode
            iconPanel:setTooltip(statsTooltip)
        else
            -- If no attachment, build compatible parts list
            local compatibleInInventory = {}
            local compatibleOther = {}
            local weapon = self.weapon
            local weaponFullType = weapon:getFullType()
            local playerInv = getSpecificPlayer(0):getInventory()
        
            local seenFullTypes = {}

            -- Special case for the default magazine type
            if att.id == "Clip" and weapon:getMagazineType() then
                local defaultMag = InventoryItemFactory.CreateItem(weapon:getMagazineType())
                if defaultMag then
                    table.insert(compatibleOther, defaultMag:getDisplayName() .. " (Default)")
                    seenFullTypes[defaultMag:getFullType()] = true
                end
            end
        
            -- Inventory parts
            local invParts = playerInv:getItemsFromCategory("WeaponPart")
            for i = 0, invParts:size() - 1 do
                local part = invParts:get(i)
                if part:getPartType() == att.id and part:getMountOn() and part:getMountOn():contains(weaponFullType) then
                    if not seenFullTypes[part:getFullType()] then
                        seenFullTypes[part:getFullType()] = true
                        if not isFilteredOut(part, att, weapon) then
                            local name = part:getDisplayName() or part:getName()
                            table.insert(compatibleInInventory, name)
                        end
                    end
                end
            end
        
            -- ScriptManager parts
            local allItems = getScriptManager():getAllItems()
            for i = 0, allItems:size() - 1 do
                local scriptItem = allItems:get(i)
                if scriptItem and scriptItem:getTypeString() == "WeaponPart" then
                    local fullName = scriptItem:getFullName()
                    if not seenFullTypes[fullName] then
                        local part = InventoryItemFactory.CreateItem(fullName)
                        if part and part:getPartType() == att.id then
                            local mountOn = part:getMountOn()
                            local canMount = false
                            if mountOn and mountOn:contains(weaponFullType) then
                                canMount = true
                            elseif not mountOn or mountOn:size() == 0 then
                                canMount = true
                            end
        
                            if canMount and not isFilteredOut(part, att, weapon) then
                                local name = part:getDisplayName() or part:getName()
                                table.insert(compatibleOther, name)
                            end
                        end
                    end
                end
            end
        
            -- Tooltip string build
            local tooltipText = ""
            -- Compatible in Inventory section
            if #compatibleInInventory > 0 then
                tooltipText = tooltipText .. "<RGB:1,1,0.8>Compatible in Inventory: </RGB>\n"  -- Note the double \n for spacing
                tooltipText = tooltipText .. "<RGB:1,1,1>  - " .. table.concat(compatibleInInventory, "\n  - ") .. " </RGB>\n"
            end

            -- Add vertical space between the sections
            if #compatibleInInventory > 0 and #compatibleOther > 0 then
                tooltipText = tooltipText .. "\n"
            end

            -- Other Compatible Parts section
            if #compatibleOther > 0 then
                tooltipText = tooltipText .. "<RGB:1,1,0.8>Other Compatible Parts: </RGB>\n"  -- Note the double \n for spacing
                tooltipText = tooltipText .. "<RGB:1,1,1>  - " .. table.concat(compatibleOther, "\n  - ") .. " </RGB>\n"
            end

            -- No compatible parts found
            if tooltipText == "" then
                tooltipText = "No compatible parts found"
            end
        
            iconPanel:setTooltip(tooltipText)
        end
        
        -- Show icon if item exists
        if att.item then
            local icon = att.item:getTex()
            if icon then
                local iconX = (iconBoxSize - iconSize) / 2
                local iconY = (iconBoxSize - iconSize) / 2
                local iconImg = ISImage:new(iconX, iconY, iconSize, iconSize, icon)
                iconImg:initialise()
                iconImg.scaled = true
                iconPanel:addChild(iconImg)
            end
        end
    end

    local totalHeight = spacing + rows * (boxHeight + spacing)
    self.attachmentsPanel:setHeight(totalHeight)
    
    self:refreshLayout()
end

function HFO_WeaponViewer:toggleDetails()
    self.detailsVisible = not self.detailsVisible
    self.detailsPanel:setVisible(self.detailsVisible)

    if self.detailsVisible then
        self:updateDetailsPanel()
    else
        self.detailsPanel:clearChildren()
    end

    self:refreshLayout()
end

-- Improved refreshLayout function
function HFO_WeaponViewer:refreshLayout()
    local base = self.baseHeight or 0
    local screenH = getCore():getScreenHeight()
    local maxHeight = math.floor(screenH * 0.9)
    
    -- Reset positions based on visibility
    if self.attachmentsVisible then
        self.attachmentsPanel:setY(base)
        base = base + self.attachmentsPanel:getHeight()
    end
    
    if self.detailsVisible then
        -- Use standard Lua if-then-else since ternary isn't available
        if self.attachmentsVisible then
            self.detailsPanel:setY(base)
        else
            self.detailsPanel:setY(self.baseHeight)
        end
        base = base + self.detailsPanel:getHeight()
    end
    
    -- Add padding
    if self.attachmentsVisible or self.detailsVisible then
        base = base + 10
    end
    
    -- Set height but don't exceed maximum
    local newHeight = math.min(base, maxHeight)
    if newHeight ~= self:getHeight() then
        self:setHeight(newHeight)
    end
end

function HFO_WeaponViewer:getDisplayName(platingType)
    if not platingType then return "None" end
    local base = self.weapon:getModData().GunBaseModel or (self.weapon:getWeaponSprite() or self.weapon:getStaticModel())
    if platingType == base then
        return "Original Plating"
    end
    return platingType:gsub("GunPlating", ""):gsub("([A-Z])", " %1"):trim()
end

-- Simple next plating button handler
function HFO_WeaponViewer:onNextPlating()
    self:cyclePlating(1)
end

-- Simple prev plating button handler
function HFO_WeaponViewer:onPrevPlating()
    self:cyclePlating(-1)
end

-- Core plating cycle function
function HFO_WeaponViewer:cyclePlating(direction)
    if not self.availablePlatings or #self.availablePlatings == 0 then return end
    
    -- Update index
    self.previewPlatingIndex = self.previewPlatingIndex + direction
    if self.previewPlatingIndex > #self.availablePlatings then self.previewPlatingIndex = 1 end
    if self.previewPlatingIndex < 1 then self.previewPlatingIndex = #self.availablePlatings end
    
    -- Get plating option
    local platingOption = self.availablePlatings[self.previewPlatingIndex]
    
    -- Update label text
    if self.platingLabel then
        local displayName = self:getDisplayName(platingOption)
        self.platingLabel:setName(displayName)
        self.platingLabel:setX(self.rightBtn:getRight() + 10)
    end

    -- Remove old model and attachments
    self:removeWeaponAttachments()
    self.scene.javaObject:fromLua1("removeModel", self.modelId)
    self.addedAttachments = {} -- Reset attachments list

    -- Get temporary model preview without changing the actual weapon
    local originalPlating = self.weapon:getModData().GunPlating
    self.weapon:getModData().GunPlating = platingOption
    BWTweaks:checkForModelChange(self.weapon)
    local previewModel = self.weapon:getWeaponSprite() or self.weapon:getStaticModel()
    self.weapon:getModData().GunPlating = originalPlating
    BWTweaks:checkForModelChange(self.weapon)
    
    -- Create new model and reset view completely
    if previewModel and self.scene then
        local fullType = "Base." .. previewModel
        -- Create model FIRST
        self.scene.javaObject:fromLua2("createModel", self.modelId, fullType)
        -- THEN add to tracking list
        table.insert(self.addedAttachments, self.modelId)
        -- Configure model

        -- Add attachments
        self:addWeaponAttachments()
        -- Reset view
        self:resetView()
    end
end

-- Also add this to the removeFromUIManager function
function HFO_WeaponViewer:removeFromUIManager()
    ISPanel.removeFromUIManager(self)
end