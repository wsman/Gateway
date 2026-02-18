<#
.SYNOPSIS
    Enhanced Nordic Theme System for PowerShell WinForms Application

.DESCRIPTION
    Advanced theme system based on OpenDoge technology library with JSON configuration,
    light/dark mode support, and dynamic color system.

.VERSION
    2.0.0
.CREATED
    2026-02-15
.LAST_UPDATED
    2026-02-16
#>

# ============================================================
# Theme Constants and Configuration Paths
# ============================================================

$script:ThemeConfig = @{
    ThemeDir = Join-Path $PSScriptRoot "..\themes"
    DefaultTheme = "nordic-theme.json"
    ThemeMode = "light"  # light, dark, auto
    CurrentTheme = $null
    IsInitialized = $false
}

# ============================================================
# Theme Loading and Management Functions
# ============================================================

<#
.SYNOPSIS
    Loads a theme configuration from JSON file

.DESCRIPTION
    Loads and parses theme configuration from JSON file, applies theme settings

.PARAMETER ThemePath
    Path to the theme JSON file

.PARAMETER Mode
    Theme mode (light, dark, auto)
#>
function Load-ThemeConfiguration {
    param(
        [Parameter(Mandatory = $false)]
        [string]$ThemePath = (Join-Path $script:ThemeConfig.ThemeDir $script:ThemeConfig.DefaultTheme),
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('light', 'dark', 'auto')]
        [string]$Mode = 'light'
    )
    
    try {
        if (-not (Test-Path $ThemePath)) {
            Write-SilentLog "Theme file not found: $ThemePath. Using default theme." 'WARN'
            Initialize-DefaultTheme
            return $true
        }
        
        # Load and parse JSON theme
        $themeContent = Get-Content -Path $ThemePath -Raw -Encoding UTF8
        $themeData = $themeContent | ConvertFrom-Json
        
        # Determine actual mode for auto
        $actualMode = if ($Mode -eq 'auto') {
            # Check system preference (simplified)
            $hour = (Get-Date).Hour
            if ($hour -ge 18 -or $hour -lt 6) { 'dark' } else { 'light' }
        } else {
            $Mode
        }
        
        # Store current theme data
        $script:ThemeConfig.CurrentTheme = @{
            Name = $themeData.name
            Version = $themeData.version
            Mode = $actualMode
            Data = $themeData
        }
        
        # Apply theme colors based on mode
        $modeColors = if ($actualMode -eq 'dark') {
            $themeData.darkMode
        } else {
            $themeData.lightMode
        }
        
        # Initialize global theme hash with loaded colors
        $global:NordicTheme = @{
            # Mode and metadata
            ThemeName = $themeData.name
            ThemeVersion = $themeData.version
            ThemeMode = $actualMode
            IsInitialized = $true
            
            # Background colors
            BackgroundPrimary = ConvertTo-Color ($modeColors.backgrounds.primary)
            BackgroundSecondary = ConvertTo-Color ($modeColors.backgrounds.secondary)
            BackgroundTertiary = ConvertTo-Color ($modeColors.backgrounds.tertiary)
            BackgroundElevated = ConvertTo-Color ($modeColors.backgrounds.elevated)
            BackgroundInset = ConvertTo-Color ($modeColors.backgrounds.inset)
            Background = ConvertTo-Color ($modeColors.backgrounds.primary)  # Backward compatibility
            
            # Text colors
            TextPrimary = ConvertTo-Color ($modeColors.text.primary)
            TextSecondary = ConvertTo-Color ($modeColors.text.secondary)
            TextTertiary = ConvertTo-Color ($modeColors.text.tertiary)
            TextInverse = ConvertTo-Color ($modeColors.text.inverse)
            TextOnAccent = '#FFFFFF'  # Fixed for contrast
            Text = ConvertTo-Color ($modeColors.text.primary)  # Backward compatibility
            
            # Accent colors
            AccentNormal = ConvertTo-Color ($modeColors.accents.primary)
            AccentHover = ConvertTo-Color ($modeColors.accents.hover)
            AccentActive = ConvertTo-Color ($modeColors.accents.primary)  # Same as normal for now
            AccentPurple = ConvertTo-Color ($themeData.colorPalette.auroraColors.auroraPurple)
            AccentAmber = ConvertTo-Color ($themeData.colorPalette.auroraColors.auroraAmber)
            
            # Status colors
            StatusSuccess = ConvertTo-Color ($modeColors.status.success)
            StatusWarning = ConvertTo-Color ($modeColors.status.warning)
            StatusError = ConvertTo-Color ($modeColors.status.error)
            StatusInfo = ConvertTo-Color ($modeColors.status.info)
            Status = @{
                Success = ConvertTo-Color ($modeColors.status.success)
                Warning = ConvertTo-Color ($modeColors.status.warning)
                Error = ConvertTo-Color ($modeColors.status.error)
                Info = ConvertTo-Color ($modeColors.status.info)
            }
            
            # Border colors
            BorderLight = ConvertTo-Color ($modeColors.borders.light)
            BorderNormal = ConvertTo-Color ($modeColors.borders.normal)
            BorderStrong = ConvertTo-Color ($modeColors.borders.strong)
            BorderFocus = ConvertTo-Color ($modeColors.accents.primary)
            
            # Font settings
            FontDefault = $themeData.fonts.primary
            FontCode = $themeData.fonts.code
            FontSizeBase = $themeData.fonts.sizes.base
            FontSizeSm = $themeData.fonts.sizes.sm
            FontSizeLg = $themeData.fonts.sizes.lg
            
            # Spacing
            SpacingGrid = $themeData.spacing.grid
            SpacingScale = $themeData.spacing.scale
            
            # Border radius
            BorderRadiusSm = $themeData.borderRadius.sm
            BorderRadiusMd = $themeData.borderRadius.md
            BorderRadiusLg = $themeData.borderRadius.lg
            
        # Animations
            AnimationFast = $themeData.animations.durations.fast
            AnimationNormal = $themeData.animations.durations.normal
            AnimationSlow = $themeData.animations.durations.slow
            
            # Dashboard Layout Configuration
            Dashboard = @{
                Layout = @{
                    Width = $themeData.dashboard.layout.width
                    HeaderHeight = $themeData.dashboard.layout.headerHeight
                    MetricsGridHeight = $themeData.dashboard.layout.metricsGridHeight
                    StatusPanelHeight = $themeData.dashboard.layout.statusPanelHeight
                    SystemInfoHeight = $themeData.dashboard.layout.systemInfoHeight
                    Spacing = $themeData.dashboard.layout.spacing
                }
                Cards = @{
                    Width = $themeData.dashboard.cards.width
                    Height = $themeData.dashboard.cards.height
                    Padding = $themeData.dashboard.cards.padding
                    BorderWidth = $themeData.dashboard.cards.borderWidth
                }
                Metrics = @{
                    HistoryPanelWidth = $themeData.dashboard.metrics.historyPanelWidth
                    HistoryPanelHeight = $themeData.dashboard.metrics.historyPanelHeight
                    MemoryBarWidth = $themeData.dashboard.metrics.memoryBarWidth
                    MemoryBarHeight = $themeData.dashboard.metrics.memoryBarHeight
                    MaxHistoryPoints = $themeData.dashboard.metrics.maxHistoryPoints
                }
                Performance = @{
                    UpdateIntervalMs = $themeData.dashboard.performance.updateIntervalMs
                    CacheDurationSec = $themeData.dashboard.performance.cacheDurationSec
                    MaxRetries = $themeData.dashboard.performance.maxRetries
                }
                Defaults = @{
                    MemoryTotalMB = $themeData.dashboard.defaults.memoryTotalMB
                    LatencyBaseMs = $themeData.dashboard.defaults.latencyBaseMs
                    LatencyVariationFactor = $themeData.dashboard.defaults.latencyVariationFactor
                }
                Thresholds = @{
                    CpuWarning = $themeData.dashboard.thresholds.cpuWarning
                    CpuCritical = $themeData.dashboard.thresholds.cpuCritical
                    MemoryWarning = $themeData.dashboard.thresholds.memoryWarning
                    MemoryCritical = $themeData.dashboard.thresholds.memoryCritical
                    LatencyWarning = $themeData.dashboard.thresholds.latencyWarning
                    LatencyCritical = $themeData.dashboard.thresholds.latencyCritical
                }
            }
        }
        
        $script:ThemeConfig.IsInitialized = $true
        $script:ThemeConfig.ThemeMode = $actualMode
        
        Write-SilentLog "Loaded theme: $($themeData.name) v$($themeData.version) [$actualMode mode]" 'INFO'
        return $true
    }
    catch {
        Write-SilentLog "Failed to load theme configuration: $_" 'ERROR'
        Initialize-DefaultTheme
        return $false
    }
}

<#
.SYNOPSIS
    Converts hex color string to .NET Color object

.PARAMETER HexColor
    Hex color string (e.g., '#FF0000' or 'FF0000')
#>
function ConvertTo-Color {
    param(
        [Parameter(Mandatory = $true)]
        [string]$HexColor
    )
    
    try {
        # Remove # if present
        $hex = $HexColor.Replace('#', '')
        
        # Handle RGBA format
        if ($hex -match '^rgba?') {
            # Extract RGB values from rgba string
            $matches = [regex]::Matches($hex, '\d+')
            if ($matches.Count -ge 3) {
                $r = [int]$matches[0].Value
                $g = [int]$matches[1].Value
                $b = [int]$matches[2].Value
                $a = if ($matches.Count -eq 4) { [int]$matches[3].Value } else { 255 }
                return [System.Drawing.Color]::FromArgb($a, $r, $g, $b)
            }
        }
        
        # Handle regular hex
        if ($hex.Length -eq 6) {
            $r = [Convert]::ToByte($hex.Substring(0,2), 16)
            $g = [Convert]::ToByte($hex.Substring(2,2), 16)
            $b = [Convert]::ToByte($hex.Substring(4,2), 16)
            return [System.Drawing.Color]::FromArgb(255, $r, $g, $b)
        }
        
        # Fallback to gray
        return [System.Drawing.Color]::FromArgb(255, 128, 128, 128)
    }
    catch {
        Write-SilentLog "Failed to convert color '$HexColor': $_" 'DEBUG'
        return [System.Drawing.Color]::Gray
    }
}

<#
.SYNOPSIS
    Initializes default theme as fallback
#>
function Initialize-DefaultTheme {
    $global:NordicTheme = @{
        # Background colors
        BackgroundPrimary = [System.Drawing.Color]::FromArgb(26, 29, 32)  # #1A1D20
        BackgroundSecondary = [System.Drawing.Color]::FromArgb(37, 42, 48)  # #252A30
        BackgroundTertiary = [System.Drawing.Color]::FromArgb(245, 247, 249)  # #F5F7F9
        BackgroundElevated = [System.Drawing.Color]::White
        BackgroundInset = [System.Drawing.Color]::FromArgb(228, 232, 236)  # #E4E8EC
        Background = [System.Drawing.Color]::FromArgb(26, 29, 32)  # Backward compatibility
        
        # Text colors
        TextPrimary = [System.Drawing.Color]::FromArgb(248, 250, 252)  # #F8FAFC
        TextSecondary = [System.Drawing.Color]::FromArgb(203, 213, 225)  # #CBD5E1
        TextTertiary = [System.Drawing.Color]::FromArgb(148, 163, 184)  # #94A3B8
        TextInverse = [System.Drawing.Color]::FromArgb(26, 29, 32)  # #1A1D20
        TextOnAccent = [System.Drawing.Color]::White
        Text = [System.Drawing.Color]::FromArgb(248, 250, 252)  # Backward compatibility
        
        # Accent colors
        AccentNormal = [System.Drawing.Color]::FromArgb(61, 122, 95)  # #3D7A5F
        AccentHover = [System.Drawing.Color]::FromArgb(45, 90, 71)  # #2D5A47
        AccentActive = [System.Drawing.Color]::FromArgb(61, 122, 95)  # Same as normal
        AccentPurple = [System.Drawing.Color]::FromArgb(157, 143, 212)  # #9D8FD4
        AccentAmber = [System.Drawing.Color]::FromArgb(240, 184, 96)  # #F0B860
        
        # Status colors
        StatusSuccess = [System.Drawing.Color]::FromArgb(74, 222, 128)  # #4ADE80
        StatusWarning = [System.Drawing.Color]::FromArgb(251, 191, 36)  # #FBBF24
        StatusError = [System.Drawing.Color]::FromArgb(248, 113, 113)  # #F87171
        StatusInfo = [System.Drawing.Color]::FromArgb(167, 139, 250)  # #A78BFA
        Status = @{
            Success = [System.Drawing.Color]::FromArgb(74, 222, 128)
            Warning = [System.Drawing.Color]::FromArgb(251, 191, 36)
            Error = [System.Drawing.Color]::FromArgb(248, 113, 113)
            Info = [System.Drawing.Color]::FromArgb(167, 139, 250)
        }
        
        # Border colors
        BorderLight = [System.Drawing.Color]::FromArgb(63, 71, 86)  # #3F4756
        BorderNormal = [System.Drawing.Color]::FromArgb(75, 85, 99)  # #4B5563
        BorderStrong = [System.Drawing.Color]::FromArgb(107, 122, 143)  # #6B7A8F
        BorderFocus = [System.Drawing.Color]::FromArgb(61, 122, 95)  # #3D7A5F
        
        # Font settings
        FontDefault = 'Segoe UI, Tahoma, Geneva, Verdana, sans-serif'
        FontCode = 'Consolas, Monaco, Courier New, monospace'
        FontSizeBase = 10
        FontSizeSm = 9
        FontSizeLg = 11
        
        # Mode and metadata
        ThemeName = "Nordic Default"
        ThemeVersion = "1.0.0"
        ThemeMode = "light"
        IsInitialized = $true
    }
    
    $script:ThemeConfig.IsInitialized = $true
    $script:ThemeConfig.CurrentTheme = @{
        Name = "Nordic Default"
        Version = "1.0.0"
        Mode = "light"
    }
    
    Write-SilentLog "Initialized default theme as fallback" 'INFO'
}

<#
.SYNOPSIS
    Switches between light and dark theme modes

.PARAMETER Mode
    Theme mode to switch to (light, dark)
#>
function Switch-ThemeMode {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('light', 'dark')]
        [string]$Mode
    )
    
    if (-not $script:ThemeConfig.IsInitialized -or -not $script:ThemeConfig.CurrentTheme) {
        Write-SilentLog "Theme not initialized. Cannot switch mode." 'WARN'
        return $false
    }
    
    try {
        # Reload theme with new mode
        $themePath = Join-Path $script:ThemeConfig.ThemeDir $script:ThemeConfig.DefaultTheme
        return Load-ThemeConfiguration -ThemePath $themePath -Mode $Mode
    }
    catch {
        Write-SilentLog "Failed to switch theme mode to $Mode : $_" 'ERROR'
        return $false
    }
}

<#
.SYNOPSIS
    Gets current theme information
#>
function Get-CurrentTheme {
    return @{
        Name = $script:ThemeConfig.CurrentTheme.Name
        Version = $script:ThemeConfig.CurrentTheme.Version
        Mode = $script:ThemeConfig.CurrentTheme.Mode
        IsInitialized = $script:ThemeConfig.IsInitialized
    }
}

<#
.SYNOPSIS
    Lists available theme files in theme directory
#>
function Get-AvailableThemes {
    try {
        $themeFiles = Get-ChildItem -Path $script:ThemeConfig.ThemeDir -Filter "*.json" -File
        return @($themeFiles | ForEach-Object {
            try {
                $content = Get-Content $_.FullName -Raw | ConvertFrom-Json
                @{
                    Name = $content.name
                    Version = $content.version
                    Description = $content.description
                    FileName = $_.Name
                    FullPath = $_.FullName
                }
            }
            catch {
                @{ Name = $_.Name; FileName = $_.Name; FullPath = $_.FullName }
            }
        })
    }
    catch {
        Write-SilentLog "Failed to list available themes: $_" 'DEBUG'
        return @()
    }
}

# ============================================================
# Theme Helper Functions (Enhanced)
# ============================================================

<#
.SYNOPSIS
    Sets the background color of a WinForms object

.PARAMETER Control
    The WinForms control to set the background for
#>
function Set-NordicBackground {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Windows.Forms.Control]$Control
    )
    $Control.BackColor = $global:NordicTheme.BackgroundPrimary
}

<#
.SYNOPSIS
    Sets the text color of a WinForms object

.PARAMETER Control
    The WinForms control to set the text color for
#>
function Set-NordicForeground {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Windows.Forms.Control]$Control
    )
    $Control.ForeColor = $global:NordicTheme.TextPrimary
}

<#
.SYNOPSIS
    Sets the font of a WinForms object

.PARAMETER Control
    The WinForms control to set the font for

.PARAMETER FontSize
    Font size (default: base size from theme)

.PARAMETER IsCodeFont
    Whether to use code font instead of default font
#>
function Set-NordicFont {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Windows.Forms.Control]$Control,

        [ValidateRange(1, 72)]
        [int]$FontSize = $global:NordicTheme.FontSizeBase,

        [switch]$IsCodeFont
    )
    try {
        $fontFamily = if ($IsCodeFont) {
            $global:NordicTheme.FontCode
        } else {
            $global:NordicTheme.FontDefault
        }

        $control.Font = New-Object System.Drawing.Font($fontFamily, $FontSize)
    }
    catch {
        Write-SilentLog "Failed to set font for control: $_" 'DEBUG'
        try {
            $control.Font = New-Object System.Drawing.Font('Segoe UI', $FontSize)
        }
        catch {
            Write-SilentLog "Using system default font as fallback" 'DEBUG'
        }
    }
}

<#
.SYNOPSIS
    Applies the complete Nordic theme to a form

.PARAMETER Form
    The WinForms form to apply the theme to
#>
function Apply-NordicTheme {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Windows.Forms.Form]$Form
    )
    # Apply background
    $Form.BackColor = $global:NordicTheme.BackgroundPrimary

    # Apply text color
    $Form.ForeColor = $global:NordicTheme.TextPrimary

    # Apply font
    Set-NordicFont -Control $Form

    # Set form properties
    $Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
    $Form.MaximizeBox = $true
    $Form.MinimizeBox = $true
    $Form.ShowIcon = $false
    $Form.ShowInTaskbar = $true
}

<#
.SYNOPSIS
    Applies theme styling to a button with enhanced animations and visual effects

.PARAMETER Button
    The WinForms button to style

.PARAMETER Style
    Button style (Primary, Secondary, Ghost, Success, Warning, Error, Info)

.PARAMETER WithAnimation
    Whether to enable hover animation effects

.PARAMETER Elevation
    Shadow elevation level (0-3, default: 1)
#>
function Apply-NordicButton {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Windows.Forms.Button]$Button,

        [ValidateSet('Primary', 'Secondary', 'Ghost', 'Success', 'Warning', 'Error', 'Info')]
        [string]$Style = 'Primary',

        [switch]$WithAnimation,
        
        [ValidateRange(0, 3)]
        [int]$Elevation = 1
    )
    # Set font with improved typography
    Set-NordicFont -Control $Button -FontSize $global:NordicTheme.FontSizeLg
    $Button.Font = New-Object System.Drawing.Font($Button.Font.FontFamily, $Button.Font.Size, [System.Drawing.FontStyle]::Medium)

    # Enhanced color definitions with better contrast
    $bgColor = $global:NordicTheme.BackgroundSecondary
    $fgColor = $global:NordicTheme.TextPrimary
    $borderColor = $global:NordicTheme.BorderNormal
    $borderSize = 1
    
    switch ($Style) {
        'Primary' {
            $bgColor = $global:NordicTheme.AccentNormal
            $fgColor = [System.Drawing.Color]::White  # Higher contrast white
            $borderColor = Adjust-Brightness $global:NordicTheme.AccentNormal -15  # Slightly darker border
            $borderSize = 0
        }
        'Secondary' {
            $bgColor = $global:NordicTheme.BackgroundSecondary
            $fgColor = $global:NordicTheme.TextPrimary
            $borderColor = $global:NordicTheme.BorderNormal
            $borderSize = 1
        }
        'Ghost' {
            $bgColor = [System.Drawing.Color]::Transparent
            $fgColor = $global:NordicTheme.TextSecondary
            $borderColor = $global:NordicTheme.BorderStrong
            $borderSize = 1
        }
        'Success' {
            $bgColor = $global:NordicTheme.StatusSuccess
            $fgColor = [System.Drawing.Color]::White
            $borderColor = Adjust-Brightness $global:NordicTheme.StatusSuccess -15
            $borderSize = 0
        }
        'Warning' {
            $bgColor = $global:NordicTheme.StatusWarning
            $fgColor = $global:NordicTheme.TextInverse
            $borderColor = Adjust-Brightness $global:NordicTheme.StatusWarning -15
            $borderSize = 0
        }
        'Error' {
            $bgColor = $global:NordicTheme.StatusError
            $fgColor = [System.Drawing.Color]::White
            $borderColor = Adjust-Brightness $global:NordicTheme.StatusError -15
            $borderSize = 0
        }
        'Info' {
            $bgColor = $global:NordicTheme.StatusInfo
            $fgColor = [System.Drawing.Color]::White
            $borderColor = Adjust-Brightness $global:NordicTheme.StatusInfo -15
            $borderSize = 0
        }
    }

    # Apply enhanced styling
    $Button.BackColor = $bgColor
    $Button.ForeColor = $fgColor
    $Button.FlatAppearance.BorderSize = $borderSize
    $Button.FlatAppearance.BorderColor = $borderColor
    $Button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $Button.Cursor = [System.Windows.Forms.Cursors]::Hand
    $Button.Padding = New-Object System.Windows.Forms.Padding(12, 8, 12, 8)

    # Enhanced border radius
    if ($Elevation -gt 0 -and $borderSize -eq 0) {
        $Button.FlatAppearance.BorderSize = 1
        $Button.FlatAppearance.BorderColor = $borderColor
    }

    # Add sophisticated animation effects
    $originalBgColor = $bgColor
    $originalBorderColor = $borderColor
    $originalSize = $Button.Size
    
    $Button.Add_MouseEnter({
        try {
            if ($this.Tag -ne "Animating") {
                $this.Tag = "Animating"
                
                # Smooth color transition
                $targetBg = Adjust-Brightness $originalBgColor 12
                $targetBorder = Adjust-Brightness $originalBorderColor 12
                
                # Subtle scale effect
                $targetSize = New-Object System.Drawing.Size(
                    [Math]::Min($originalSize.Width + 2, $originalSize.Width * 1.03),
                    [Math]::Min($originalSize.Height + 1, $originalSize.Height * 1.03)
                )
                
                $steps = 6
                $step = 0
                $timer = New-Object System.Windows.Forms.Timer
                $timer.Interval = 16  # ~60fps
                
                $timer.Add_Tick({
                    if ($step -ge $steps) {
                        $this.Size = $targetSize
                        $this.BackColor = $targetBg
                        $this.FlatAppearance.BorderColor = $targetBorder
                        $timer.Stop()
                        $this.Tag = $null
                        return
                    }
                    
                    $ratio = $step / $steps
                    $currentBg = Lerp-Color $originalBgColor $targetBg $ratio
                    $currentBorder = Lerp-Color $originalBorderColor $targetBorder $ratio
                    $currentWidth = [int](($originalSize.Width * (1 - $ratio)) + ($targetSize.Width * $ratio))
                    $currentHeight = [int](($originalSize.Height * (1 - $ratio)) + ($targetSize.Height * $ratio))
                    
                    $this.BackColor = $currentBg
                    $this.FlatAppearance.BorderColor = $currentBorder
                    $this.Size = New-Object System.Drawing.Size($currentWidth, $currentHeight)
                    
                    $step++
                })
                
                $timer.Start()
            }
        }
        catch { }
    })
    
    $Button.Add_MouseLeave({
        try {
            if ($this.Tag -ne "Animating") {
                $this.Tag = "Animating"
                
                # Return to original state
                $steps = 8
                $step = 0
                $currentSize = $this.Size
                $timer = New-Object System.Windows.Forms.Timer
                $timer.Interval = 16
                
                $timer.Add_Tick({
                    if ($step -ge $steps) {
                        $this.Size = $originalSize
                        $this.BackColor = $originalBgColor
                        $this.FlatAppearance.BorderColor = $originalBorderColor
                        $timer.Stop()
                        $this.Tag = $null
                        return
                    }
                    
                    $ratio = $step / $steps
                    $currentBg = Lerp-Color $this.BackColor $originalBgColor $ratio
                    $currentBorder = Lerp-Color $this.FlatAppearance.BorderColor $originalBorderColor $ratio
                    $currentWidth = [int](($currentSize.Width * (1 - $ratio)) + ($originalSize.Width * $ratio))
                    $currentHeight = [int](($currentSize.Height * (1 - $ratio)) + ($originalSize.Height * $ratio))
                    
                    $this.BackColor = $currentBg
                    $this.FlatAppearance.BorderColor = $currentBorder
                    $this.Size = New-Object System.Drawing.Size($currentWidth, $currentHeight)
                    
                    $step++
                })
                
                $timer.Start()
            }
        }
        catch { }
    })
    
    $Button.Add_MouseDown({
        try {
            $this.BackColor = Adjust-Brightness $originalBgColor -18
            $this.FlatAppearance.BorderColor = Adjust-Brightness $originalBorderColor -18
            
            # Slight scale down on click
            $this.Size = New-Object System.Drawing.Size(
                [Math]::Max($originalSize.Width - 2, $originalSize.Width * 0.97),
                [Math]::Max($originalSize.Height - 1, $originalSize.Height * 0.97)
            )
        }
        catch { }
    })
    
    $Button.Add_MouseUp({
        try {
            $this.BackColor = Adjust-Brightness $originalBgColor 12  # Hover state
            $this.FlatAppearance.BorderColor = Adjust-Brightness $originalBorderColor 12
            $this.Size = $originalSize
        }
        catch { }
    })
}

<#
.SYNOPSIS
    Adjusts brightness of a color

.PARAMETER Color
    Color to adjust

.PARAMETER Percent
    Percentage to adjust (-100 to 100)
#>
function Adjust-Brightness {
    param(
        [System.Drawing.Color]$Color,
        [int]$Percent
    )
    
    $percent = [Math]::Max(-100, [Math]::Min(100, $Percent))
    $factor = 1 + ($percent / 100.0)
    
    $r = [Math]::Min(255, [Math]::Max(0, [int]($Color.R * $factor)))
    $g = [Math]::Min(255, [Math]::Max(0, [int]($Color.G * $factor)))
    $b = [Math]::Min(255, [Math]::Max(0, [int]($Color.B * $factor)))
    
    return [System.Drawing.Color]::FromArgb($Color.A, $r, $g, $b)
}

<#
.SYNOPSIS
    Linear interpolation between two colors

.PARAMETER ColorA
    Starting color

.PARAMETER ColorB
    Ending color

.PARAMETER Ratio
    Interpolation ratio (0.0 to 1.0)
#>
function Lerp-Color {
    param(
        [System.Drawing.Color]$ColorA,
        [System.Drawing.Color]$ColorB,
        [double]$Ratio
    )
    
    $ratio = [Math]::Max(0.0, [Math]::Min(1.0, $Ratio))
    
    $r = [int](($ColorA.R * (1 - $ratio)) + ($ColorB.R * $ratio))
    $g = [int](($ColorA.G * (1 - $ratio)) + ($ColorB.G * $ratio))
    $b = [int](($ColorA.B * (1 - $ratio)) + ($ColorB.B * $ratio))
    $a = [int](($ColorA.A * (1 - $ratio)) + ($ColorB.A * $ratio))
    
    return [System.Drawing.Color]::FromArgb($a, $r, $g, $b)
}

<#
.SYNOPSIS
    Creates a smooth animation timer for visual effects

.PARAMETER DurationMs
    Animation duration in milliseconds

.PARAMETER Callback
    Callback function that receives progress (0.0 to 1.0)

.PARAMETER Easing
    Easing function type (Linear, EaseInOut, EaseOutCubic)
#>
function New-AnimationTimer {
    param(
        [int]$DurationMs = 300,
        [scriptblock]$Callback,
        [ValidateSet('Linear', 'EaseInOut', 'EaseOutCubic')]
        [string]$Easing = 'Linear'
    )
    
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 16  # ~60fps
    $startTime = [DateTime]::Now
    $isRunning = $true
    
    $timer.Add_Tick({
        if (-not $isRunning) {
            $this.Stop()
            return
        }
        
        $elapsed = ([DateTime]::Now - $startTime).TotalMilliseconds
        $progress = [Math]::Min(1.0, $elapsed / $DurationMs)
        
        # Apply easing (simplified to avoid parsing issues)
        $easedProgress = $progress  # Default to linear
        
        if ($Easing -eq 'EaseInOut') {
            $t = $progress * 2
            if ($t -lt 1) { 
                $easedProgress = 0.5 * $t * $t * $t 
            } else { 
                $t = $t - 2
                $easedProgress = 0.5 * ($t * $t * $t + 2) 
            }
        } elseif ($Easing -eq 'EaseOutCubic') {
            $t = $progress - 1
            $easedProgress = $t * $t * $t + 1
        }
        
        # Invoke callback
        try {
            & $Callback $easedProgress
        }
        catch {
            Write-SilentLog "Animation callback error: $_" 'DEBUG'
        }
        
        # Stop when done
        if ($progress -ge 1.0) {
            $isRunning = $false
            $this.Stop()
        }
    })
    
    return $timer
}

<#
.SYNOPSIS
    Applies theme styling to a text box

.PARAMETER TextBox
    The WinForms text box to style
#>
function Apply-NordicTextBox {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Windows.Forms.TextBox]$TextBox
    )
    # Apply font
    Set-NordicFont -Control $TextBox -IsCodeFont:$true

    # Apply background and text color
    $TextBox.BackColor = $global:NordicTheme.BackgroundSecondary
    $TextBox.ForeColor = $global:NordicTheme.TextPrimary
    $TextBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $TextBox.Padding = New-Object System.Windows.Forms.Padding(5)
}

<#
.SYNOPSIS
    Applies theme styling to a label

.PARAMETER Label
    The WinForms label to style
#>
function Apply-NordicLabel {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Windows.Forms.Label]$Label
    )
    # Apply font
    Set-NordicFont -Control $Label

    # Apply text color
    $Label.ForeColor = $global:NordicTheme.TextPrimary
}

<#
.SYNOPSIS
    Applies status styling to a control

.PARAMETER Control
    The WinForms control to apply status styling to

.PARAMETER Status
    Status type (Success, Warning, Error, Info)
#>
function Set-NordicStatus {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Windows.Forms.Control]$Control,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet('Success', 'Warning', 'Error', 'Info')]
        [string]$Status
    )
    switch ($Status) {
        'Success' { $Control.ForeColor = $global:NordicTheme.StatusSuccess }
        'Warning' { $Control.ForeColor = $global:NordicTheme.StatusWarning }
        'Error' { $Control.ForeColor = $global:NordicTheme.StatusError }
        'Info' { $Control.ForeColor = $global:NordicTheme.StatusInfo }
    }
}

<#
.SYNOPSIS
    Gets a color from the theme by name

.PARAMETER Name
    The name of the color to retrieve
#>
function Get-NordicColor {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )
    try {
        if ($null -eq $global:NordicTheme) {
            throw "Theme not initialized. Import Theme module first."
        }

        if ($global:NordicTheme.ContainsKey($Name)) {
            return $global:NordicTheme[$Name]
        }

        # Try color aliases
        $colorMap = @{
            'Primary' = $global:NordicTheme.AccentNormal
            'Success' = $global:NordicTheme.StatusSuccess
            'Warning' = $global:NordicTheme.StatusWarning
            'Error' = $global:NordicTheme.StatusError
            'Info' = $global:NordicTheme.StatusInfo
            'Background' = $global:NordicTheme.BackgroundPrimary
            'Text' = $global:NordicTheme.TextPrimary
        }
        
        if ($colorMap.ContainsKey($Name)) {
            return $colorMap[$Name]
        }

        Write-SilentLog "Theme color '$Name' not found in NordicTheme. Using fallback color." 'DEBUG'
        return [System.Drawing.Color]::Gray
    }
    catch {
        Write-SilentLog "Error getting theme color '$Name': $_" 'DEBUG'
        return [System.Drawing.Color]::Gray
    }
}

<#
.SYNOPSIS
    Gets all theme colors
#>
function Get-NordicColorList {
    return $global:NordicTheme.Keys
}

<#
.SYNOPSIS
    Creates a themed separator line

.PARAMETER Width
    Width of the separator

.PARAMETER Height
    Height of the separator

.PARAMETER Color
    Color of the separator (optional)

.OUTPUTS
    System.Windows.Forms.Panel configured as a separator
#>
function New-NordicSeparator {
    param(
        [int]$Width = 200,
        [int]$Height = 1,
        [System.Drawing.Color]$Color = $global:NordicTheme.BorderStrong
    )
    
    $separator = New-Object System.Windows.Forms.Panel
    $separator.Width = $Width
    $separator.Height = $Height
    $separator.BackColor = $Color
    
    return $separator
}

<#
.SYNOPSIS
    Creates a themed card container

.PARAMETER Width
    Width of the card

.PARAMETER Height
    Height of the card

.OUTPUTS
    System.Windows.Forms.Panel configured as a card
#>
function New-NordicCard {
    param(
        [int]$Width = 200,
        [int]$Height = 100
    )
    
    $card = New-Object System.Windows.Forms.Panel
    $card.Width = $Width
    $card.Height = $Height
    $card.BackColor = $global:NordicTheme.BackgroundSecondary
    $card.Padding = New-Object System.Windows.Forms.Padding(12)
    $card.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    
    return $card
}

# ============================================================
# Module Initialization
# ============================================================

# Load default theme on module import
try {
    # Try to load from JSON first
    $themeLoaded = Load-ThemeConfiguration -Mode 'light'
    
    if (-not $themeLoaded) {
        Initialize-DefaultTheme
    }
    
    Write-SilentLog "Enhanced Nordic Theme Module v2.0.0 loaded successfully" 'INFO'
}
catch {
    Write-SilentLog "Failed to initialize theme module: $_" 'ERROR'
    Initialize-DefaultTheme
}

# Export module functions (removed - not needed for dot-sourced scripts)
# Functions are automatically available when dot-sourced