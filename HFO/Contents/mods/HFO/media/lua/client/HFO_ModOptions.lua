--============================================================--
--                     HFO_ModOptions.lua                     --
--============================================================--

HFO = HFO or {}
HFO.Options = HFO.Options or {}

local SETTINGS = {
    options = {
        AlwaysExpandedTooltips = false,
        ShowDamage = true,
        ShowRange = true,
        ShowMaxHits = true,
        ShowProjectileCount = true,
        ShowJamChance = true,
        ShowHitChance = true,
        ShowCriticalChance = true,
        ShowRecoilDelay = true,
        ShowFiringCone = true,
        ShowAimingSpeed = true,
        ShowReloadSpeed = true,
        ShowSoundRadius = true,
        ShowSuppressor = true,
    },
    names = {
        AlwaysExpandedTooltips = "Always Expand Tooltips",
        ShowDamage = "Show Damage",
        ShowRange = "Show Range",
        ShowMaxHits = "Show Max Hits",
        ShowProjectileCount = "Show Projectile Count",
        ShowJamChance = "Show Jam Chance",
        ShowHitChance = "Show Hit Chance",
        ShowCriticalChance = "Show Critical Chance",
        ShowRecoilDelay = "Show Recoil Delay",
        ShowFiringCone = "Show Firing Cone",
        ShowAimingSpeed = "Show Aiming Speed",
        ShowReloadSpeed = "Show Reload Speed",
        ShowSoundRadius = "Show Sound Radius",
        ShowSuppressor = "Show Suppressor",
    },
    mod_id = "HayesFirearmsOverhaul",
    mod_shortname = "HFO",
    mod_fullname = "Hayes Firearms Overhaul",
}

local function updateTooltipExpansion()
    if HFO_Tooltip then
        HFO_Tooltip.AlwaysExpanded = SETTINGS.options.AlwaysExpandedTooltips
        if HFO_Tooltip.AlwaysExpanded then
            HFO_Tooltip.Expanded = true
        end
    end
end

if ModOptions and ModOptions.getInstance then
    local settings = ModOptions:getInstance(SETTINGS)
    
    local AlwaysExpandedTooltips = settings:getData("AlwaysExpandedTooltips")
    AlwaysExpandedTooltips.tooltip = "Keep weapon stat tooltips always expanded (no Shift+E needed)."
    
    local ShowDamage = settings:getData("ShowDamage")
    ShowDamage.tooltip = "Show Damage stat in weapon tooltip"
    
    local ShowRange = settings:getData("ShowRange")
    ShowRange.tooltip = "Show Range stat in weapon tooltip"
    
    local ShowMaxHits = settings:getData("ShowMaxHits")
    ShowMaxHits.tooltip = "Show Max Hits stat in weapon tooltip"
    
    local ShowProjectileCount = settings:getData("ShowProjectileCount")
    ShowProjectileCount.tooltip = "Show Projectile Count stat in weapon tooltip"
    
    local ShowJamChance = settings:getData("ShowJamChance")
    ShowJamChance.tooltip = "Show Jam Chance stat in weapon tooltip"
    
    local ShowHitChance = settings:getData("ShowHitChance")
    ShowHitChance.tooltip = "Show Hit Chance stat in weapon tooltip"
    
    local ShowCriticalChance = settings:getData("ShowCriticalChance")
    ShowCriticalChance.tooltip = "Show Critical Chance stat in weapon tooltip"
    
    local ShowRecoilDelay = settings:getData("ShowRecoilDelay")
    ShowRecoilDelay.tooltip = "Show Recoil Delay stat in weapon tooltip"
    
    local ShowFiringCone = settings:getData("ShowFiringCone")
    ShowFiringCone.tooltip = "Show Firing Cone stat in weapon tooltip"
    
    local ShowAimingSpeed = settings:getData("ShowAimingSpeed")
    ShowAimingSpeed.tooltip = "Show Aiming Speed stat in weapon tooltip"
    
    local ShowReloadSpeed = settings:getData("ShowReloadSpeed")
    ShowReloadSpeed.tooltip = "Show Reload Speed stat in weapon tooltip"
    
    local ShowSoundRadius = settings:getData("ShowSoundRadius")
    ShowSoundRadius.tooltip = "Show Sound Radius stat in weapon tooltip"
    
    local ShowSuppressor = settings:getData("ShowSuppressor")
    ShowSuppressor.tooltip = "Show Suppressor stat in weapon tooltip"
    
    function settings:OnApplyInGame()
        updateTooltipExpansion()
    end
    
    function settings:OnApplyMainMenu()
        updateTooltipExpansion()
    end
    
    print("HFO: ModOptions loaded")
else
    print("HFO: ModOptions not found")
end

HFO.Options = SETTINGS.options

Events.OnGameStart.Add(function()
    updateTooltipExpansion()
    print("HFO: Options initialized")
end)
