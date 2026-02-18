<#
.SYNOPSIS
    System Tray Icon Module for PowerShell WinForms Application

.DESCRIPTION
    This module provides system tray icon functionality with Nordic theme styling.
    Uses the Nordic color palette for menu items and balloon notifications.

.VERSION
    1.0.1
.CREATED
    2026-02-15
.LAST_UPDATED
    2026-02-16
#>

# Error logging function for TrayIcon module
function Write-TrayIconErrorLog {
    param(
        [string]$Message,
        [string]$Operation = "TrayIcon"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logPath = Join-Path $env:TEMP "GatewayLauncher_errors.log"
    $logEntry = "[$timestamp] [TrayIcon] $Operation - $Message`n"
    try {
        Add-Content -Path $logPath -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    catch {
        # Silently fail if logging fails
    }
}

# Load required assemblies
try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
}
catch {
    Write-SilentLog "Failed to load required assemblies: $_" 'DEBUG'
}

# ============================================================
# Color Cache and Helper Functions
# ============================================================

# Initialize color cache for performance optimization
$script:ColorCache = @{}

<#
.SYNOPSIS
    Converts hex color or Color object to Color object with caching for performance

.PARAMETER Color
    Hex color string (e.g., "#3D7A5F", "3D7A5F", "#3D7A5FCC" for ARGB) or System.Drawing.Color object
#>
function ConvertFrom-HexColor {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Color
    )
    
    try {
        # Check cache first for string inputs
        if ($Color -is [string]) {
            if ($script:ColorCache.ContainsKey($Color)) {
                return $script:ColorCache[$Color]
            }
        }
        
        # Handle System.Drawing.Color object directly
        if ($Color -is [System.Drawing.Color]) {
            return $Color
        }
        
        # Handle string input (hex color)
        if ($Color -is [string]) {
            $HexColor = $Color
            
            # Clean the hex string: remove #, spaces, and any non-hex characters
            $hex = $HexColor -replace '#', ''
            $hex = $hex -replace '\s', ''
            $hex = $hex -replace '[^0-9A-Fa-f]', ''
            
            # Validate hex string
            if ([string]::IsNullOrEmpty($hex)) {
                return [System.Drawing.Color]::FromArgb(61, 122, 95)  # Default Nordic Pine color
            }
            
            # Handle different hex formats
            if ($hex.Length -eq 3) {
                # Short format (e.g., "F00") - expand to 6 digits
                $hex = $hex[0] + $hex[0] + $hex[1] + $hex[1] + $hex[2] + $hex[2]
            }
            elseif ($hex.Length -eq 6) {
                # Standard RGB format
                # Continue with normal processing
            }
            elseif ($hex.Length -eq 8) {
                # ARGB format (8 digits) - we'll only use RGB (skip alpha)
                $hex = $hex.Substring(2, 6)
            }
            else {
                return [System.Drawing.Color]::FromArgb(61, 122, 95)  # Default Nordic Pine color
            }
            
            # Ensure we have exactly 6 characters for RGB
            if ($hex.Length -ne 6) {
                return [System.Drawing.Color]::FromArgb(61, 122, 95)  # Default Nordic Pine color
            }
            
            # Verify each character is valid hex digit
            $validHexPattern = '^[0-9A-Fa-f]{6}$'
            if ($hex -notmatch $validHexPattern) {
                return [System.Drawing.Color]::FromArgb(61, 122, 95)  # Default Nordic Pine color
            }
            
            # Convert hex to integers with proper base-16 parsing
            try {
                $r = [Convert]::ToInt32($hex.Substring(0, 2), 16)
                $g = [Convert]::ToInt32($hex.Substring(2, 2), 16)
                $b = [Convert]::ToInt32($hex.Substring(4, 2), 16)
                
                $colorObj = [System.Drawing.Color]::FromArgb($r, $g, $b)
                
                # Cache the result for future use
                $script:ColorCache[$HexColor] = $colorObj
                
                return $colorObj
            }
            catch {
                return [System.Drawing.Color]::FromArgb(61, 122, 95)
            }
        }
        
        # If input is not a string or Color object, use fallback
        return [System.Drawing.Color]::FromArgb(61, 122, 95)  # Default Nordic Pine color
    }
    catch {
        # Return a safe default color (Nordic Pine)
        return [System.Drawing.Color]::FromArgb(61, 122, 95)
    }
}

<#
.SYNOPSIS
    Creates a default tray icon bitmap

.PARAMETER Size
    Icon size (default: 16x16)
#>
function New-DefaultTrayIconBitmap {
    param(
        [int]$Size = 16
    )
    $bitmap = New-Object System.Drawing.Bitmap($Size, $Size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

    # Use Nordic accent color for default icon
    $accentColor = ConvertFrom-HexColor -Color $global:NordicTheme.AccentNormal
    $brush = New-Object System.Drawing.SolidBrush($accentColor)

    # Draw a simple circle (notification indicator style)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $margin = 2
    $graphics.FillEllipse($brush, $margin, $margin, $Size - (2 * $margin), $Size - (2 * $margin))

    $brush.Dispose()
    $graphics.Dispose()

    return $bitmap
}

# ============================================================
# Public Tray Icon Functions
# ============================================================

<#
.SYNOPSIS
    Initializes a system tray icon

.DESCRIPTION
    Creates and displays a system tray icon with optional context menu

.PARAMETER Name
    Unique name for the tray icon (used as identifier)

.PARAMETER ToolTip
    Tooltip text displayed on hover

.PARAMETER Icon
    Custom icon (System.Drawing.Icon or System.Drawing.Bitmap). If not provided, creates a default icon

.PARAMETER OnClick
    Script block to execute when icon is clicked

.PARAMETER OnDoubleClick
    Script block to execute when icon is double-clicked

.EXAMPLE
    Initialize-TrayIcon -Name "MyApp" -ToolTip "My Application" -OnClick { Show-MyForm }
#>
function Initialize-TrayIcon {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$ToolTip = "Application",

        [Parameter(Mandatory = $false)]
        [System.Drawing.Image]$Icon = $null,

        [Parameter(Mandatory = $false)]
        [scriptblock]$OnClick = $null,

        [Parameter(Mandatory = $false)]
        [scriptblock]$OnDoubleClick = $null
    )
    try {
        # Initialize global tray icons collection if needed
        if ($null -eq $global:TrayIcons) {
            $global:TrayIcons = @{}
        }

        # Check if tray icon already exists
        $existingIcon = $global:TrayIcons[$Name]
        if ($null -ne $existingIcon) {
            Write-SilentLog "Tray icon '$Name' already exists. Use Remove-TrayIcon first or call Set-TrayIconStatus to update." 'DEBUG'
            return $existingIcon
        }

        # Create context menu with error handling
        try {
            $contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
            $contextMenu.BackColor = ConvertFrom-HexColor -Color $global:NordicTheme.BackgroundSecondary
            $contextMenu.ForeColor = ConvertFrom-HexColor -Color $global:NordicTheme.TextPrimary
            $contextMenu.Font = New-Object System.Drawing.Font($global:NordicTheme.FontDefault, 9)
        }
        catch {
            Write-TrayIconErrorLog -Message "Failed to create context menu: $_" -Operation "Initialize-TrayIcon"
            $contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
        }

        # Create tray icon
        $notifyIcon = New-Object System.Windows.Forms.NotifyIcon
        $notifyIcon.Text = $ToolTip

        # Set icon
        try {
            if ($null -ne $Icon) {
                $notifyIcon.Icon = $Icon
            } else {
                $defaultBitmap = New-DefaultTrayIconBitmap
                $notifyIcon.Icon = [System.Drawing.Icon]::FromHandle($defaultBitmap.GetHicon())
                $defaultBitmap.Dispose()
            }
        }
        catch {
            Write-TrayIconErrorLog -Message "Failed to set tray icon: $_" -Operation "Initialize-TrayIcon"
            # Try to create a default icon
            try {
                $defaultBitmap = New-DefaultTrayIconBitmap
                $notifyIcon.Icon = [System.Drawing.Icon]::FromHandle($defaultBitmap.GetHicon())
                $defaultBitmap.Dispose()
            }
            catch {
                Write-SilentLog "Could not create default tray icon: $_" 'DEBUG'
            }
        }

        # Attach context menu
        $notifyIcon.ContextMenuStrip = $contextMenu

        # Set click handlers with error handling
        if ($null -ne $OnClick) {
            try {
                # Capture variable for closure
                $clickHandler = $OnClick
                $notifyIcon.Add_Click({
                    try {
                        & $clickHandler
                    }
                    catch {
                        Write-TrayIconErrorLog -Message "Error in OnClick handler: $_" -Operation "TrayIcon_Click"
                    }
                })
            }
            catch {
                Write-TrayIconErrorLog -Message "Failed to add click handler: $_" -Operation "Initialize-TrayIcon"
            }
        }

        if ($null -ne $OnDoubleClick) {
            try {
                # Capture variable for closure
                $doubleClickHandler = $OnDoubleClick
                $notifyIcon.Add_DoubleClick({
                    try {
                        & $doubleClickHandler
                    }
                    catch {
                        Write-TrayIconErrorLog -Message "Error in OnDoubleClick handler: $_" -Operation "TrayIcon_DoubleClick"
                    }
                })
            }
            catch {
                Write-TrayIconErrorLog -Message "Failed to add double-click handler: $_" -Operation "Initialize-TrayIcon"
            }
        }

        # Show the tray icon
        try {
            $notifyIcon.Visible = $true
        }
        catch {
            Write-TrayIconErrorLog -Message "Failed to show tray icon: $_" -Operation "Initialize-TrayIcon"
            Write-SilentLog "Failed to make tray icon visible: $_" 'DEBUG'
        }

        # Store in global collection
        $global:TrayIcons[$Name] = $notifyIcon

        Write-SilentLog "Tray icon '$Name' initialized successfully" 'DEBUG'
        return $notifyIcon
    }
    catch {
        Write-TrayIconErrorLog -Message "Failed to initialize tray icon '$Name': $_" -Operation "Initialize-TrayIcon"
        Write-SilentLog "Failed to initialize tray icon: $_" 'DEBUG'
        throw
    }
}

<#
.SYNOPSIS
    Adds a menu item to a tray icon's context menu

.DESCRIPTION
    Adds a new menu item to the specified tray icon's context menu

.PARAMETER TrayIconName
    Name of the tray icon to add the menu item to

.PARAMETER Text
    Display text for the menu item

.PARAMETER Action
    Script block to execute when the menu item is clicked

.PARAMETER Icon
    Optional icon to display next to the menu item

.PARAMETER Separator
    If specified, adds a separator line instead of a menu item

.PARAMETER Enabled
    Whether the menu item is enabled (default: true)

.PARAMETER Position
    Position to insert the item (Beginning, End, or index number)

.EXAMPLE
    Add-TrayMenuItem -TrayIconName "MyApp" -Text "Show Window" -Action { Show-Window }
#>
function Add-TrayMenuItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TrayIconName,

        [Parameter(Mandatory = $false)]
        [string]$Text = "",

        [Parameter(Mandatory = $false)]
        [scriptblock]$Action = $null,

        [Parameter(Mandatory = $false)]
        [System.Drawing.Image]$Icon = $null,

        [Parameter(Mandatory = $false)]
        [switch]$Separator,

        [Parameter(Mandatory = $false)]
        [bool]$Enabled = $true,

        [Parameter(Mandatory = $false)]
        [object]$Position = "End"
    )
    # Get the tray icon
    $trayIcon = $global:TrayIcons[$TrayIconName]
    if ($null -eq $trayIcon) {
        throw "Tray icon '$TrayIconName' not found. Use Initialize-TrayIcon first."
    }

    $contextMenu = $trayIcon.ContextMenuStrip

    if ($Separator.IsPresent) {
        # Add separator - create a new ToolStripSeparator object
        try {
            $separatorItem = New-Object System.Windows.Forms.ToolStripSeparator
            if ($Position -eq "Beginning") {
                $contextMenu.Items.Insert(0, $separatorItem)
            } elseif ($Position -is [int]) {
                $contextMenu.Items.Insert($Position, $separatorItem)
            } else {
                $contextMenu.Items.Add($separatorItem)
            }
            Write-SilentLog "Separator added to tray icon '$TrayIconName'" 'DEBUG'
            return $separatorItem
        }
        catch {
            Write-TrayIconErrorLog -Message "Failed to add separator: $_" -Operation "Add-TrayMenuItem"
            return $null
        }
    }

    # Create menu item
    $menuItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $menuItem.Text = $Text
    $menuItem.Enabled = $Enabled
    $menuItem.Font = New-Object System.Drawing.Font($global:NordicTheme.FontDefault, 9)

    # Apply Nordic theme colors (with cached color conversion)
    $menuItem.BackColor = ConvertFrom-HexColor -Color $global:NordicTheme.BackgroundSecondary
    $menuItem.ForeColor = ConvertFrom-HexColor -Color $global:NordicTheme.TextPrimary

    # Add icon if provided
    if ($null -ne $Icon) {
        $menuItem.Image = $Icon
    }

    # Set action handler
    if ($null -ne $Action) {
        # Capture the variable for closure scope
        $actionHandler = $Action
        $menuItem.Add_Click({
            try {
                & $actionHandler
            }
            catch {
                Write-SilentLog "Error in Add-TrayMenuItem click handler: $_" 'DEBUG'
            }
        })
    }

    # Add hover effect using events (with cached color conversion)
    $menuItem.Add_MouseEnter({
        $this.BackColor = ConvertFrom-HexColor -Color $global:NordicTheme.BackgroundTertiary
        $this.ForeColor = ConvertFrom-HexColor -Color $global:NordicTheme.TextPrimary
    })

    $menuItem.Add_MouseLeave({
        $this.BackColor = ConvertFrom-HexColor -Color $global:NordicTheme.BackgroundSecondary
        $this.ForeColor = ConvertFrom-HexColor -Color $global:NordicTheme.TextPrimary
    })

    # Insert at specified position
    if ($Position -eq "Beginning") {
        $contextMenu.Items.Insert(0, $menuItem)
    } elseif ($Position -is [int]) {
        $contextMenu.Items.Insert($Position, $menuItem)
    } else {
        $contextMenu.Items.Add($menuItem)
    }

    Write-SilentLog "Menu item '$Text' added to tray icon '$TrayIconName'" 'DEBUG'
    return $menuItem
}

<#
.SYNOPSIS
    Removes a tray icon from the system tray

.DESCRIPTION
    Removes and disposes the specified tray icon

.PARAMETER Name
    Name of the tray icon to remove

.EXAMPLE
    Remove-TrayIcon -Name "MyApp"
#>
function Remove-TrayIcon {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )
    $trayIcon = $global:TrayIcons[$Name]
    if ($null -eq $trayIcon) {
        Write-SilentLog "Tray icon '$Name' not found. No action taken." 'DEBUG'
        return
    }

    # Hide and dispose
    $trayIcon.Visible = $false

    # Dispose context menu
    if ($null -ne $trayIcon.ContextMenuStrip) {
        $trayIcon.ContextMenuStrip.Dispose()
    }

    # Dispose icon
    if ($null -ne $trayIcon.Icon) {
        $trayIcon.Icon.Dispose()
    }

    # Remove from global collection
    $global:TrayIcons.Remove($Name)

    Write-SilentLog "Tray icon '$Name' removed successfully" 'DEBUG'
}

<#
.SYNOPSIS
    Sets the status of a tray icon by changing its icon image

.DESCRIPTION
    Updates the tray icon's appearance based on status (Normal, Success, Warning, Error, Info)

.PARAMETER Name
    Name of the tray icon to update

.PARAMETER Status
    Status type: Normal, Success, Warning, Error, or Info

.PARAMETER Icon
    Custom icon to use instead of status-based icon

.PARAMETER ToolTip
    Optional new tooltip text

.EXAMPLE
    Set-TrayIconStatus -Name "MyApp" -Status Success
#>
function Set-TrayIconStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Normal', 'Success', 'Warning', 'Error', 'Info')]
        [string]$Status = 'Normal',

        [Parameter(Mandatory = $false)]
        [System.Drawing.Image]$Icon = $null,

        [Parameter(Mandatory = $false)]
        [string]$ToolTip = $null
    )
    $trayIcon = $global:TrayIcons[$Name]
    if ($null -eq $trayIcon) {
        throw "Tray icon '$Name' not found. Use Initialize-TrayIcon first."
    }

    # Set icon based on status or custom icon
    if ($null -ne $Icon) {
        if ($trayIcon.Icon -ne $null) {
            $trayIcon.Icon.Dispose()
        }
        $trayIcon.Icon = [System.Drawing.Icon]::FromHandle($Icon.GetHicon())
    } else {
        # Create status-colored icon
        $statusColors = @{
            'Normal' = $global:NordicTheme.AccentNormal
            'Success' = $global:NordicTheme.StatusSuccess
            'Warning' = $global:NordicTheme.StatusWarning
            'Error' = $global:NordicTheme.StatusError
            'Info' = $global:NordicTheme.StatusInfo
        }

        $colorHex = $statusColors[$Status]
        $color = ConvertFrom-HexColor -Color $colorHex

        # Create new bitmap with status color
        $bitmap = New-DefaultTrayIconBitmap
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

        $brush = New-Object System.Drawing.SolidBrush($color)
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

        # Redraw with status color
        $margin = 2
        $size = 16
        $graphics.FillEllipse($brush, $margin, $margin, $size - (2 * $margin), $size - (2 * $margin))

        $brush.Dispose()
        $graphics.Dispose()

        # Apply new icon
        if ($trayIcon.Icon -ne $null) {
            $trayIcon.Icon.Dispose()
        }
        $trayIcon.Icon = [System.Drawing.Icon]::FromHandle($bitmap.GetHicon())
        $bitmap.Dispose()
    }

    # Update tooltip if provided
    if ($null -ne $ToolTip) {
        $trayIcon.Text = $ToolTip
    }

    Write-SilentLog "Tray icon '$Name' status set to '$Status'" 'DEBUG'
}

<#
.SYNOPSIS
    Shows a balloon notification from a tray icon

.DESCRIPTION
    Displays a balloon tip notification from the specified tray icon

.PARAMETER Name
    Name of the tray icon to show the balloon from

.PARAMETER Title
    Title of the balloon notification

.PARAMETER Message
    Message content of the balloon notification

.PARAMETER Type
    Type of notification: None, Info, Warning, Error

.PARAMETER Duration
    Duration in milliseconds (default: 3000)

.PARAMETER Icon
    Custom icon to display in the balloon

.EXAMPLE
    Show-TrayBalloon -Name "MyApp" -Title "Update Available" -Message "A new version is ready" -Type Info
#>
function Show-TrayBalloon {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('None', 'Info', 'Warning', 'Error')]
        [string]$Type = 'Info',

        [Parameter(Mandatory = $false)]
        [int]$Duration = 3000,

        [Parameter(Mandatory = $false)]
        [System.Drawing.Image]$Icon = $null
    )
    try {
        $trayIcon = $global:TrayIcons[$Name]
        if ($null -eq $trayIcon) {
            Write-SilentLog "Tray icon '$Name' not found. Cannot show balloon notification." 'DEBUG'
            return
        }

        # Map type to ToolTipIcon
        $toolTipIcon = switch ($Type) {
            'Info'    { [System.Windows.Forms.ToolTipIcon]::Info }
            'Warning' { [System.Windows.Forms.ToolTipIcon]::Warning }
            'Error'   { [System.Windows.Forms.ToolTipIcon]::Error }
            'None'    { [System.Windows.Forms.ToolTipIcon]::None }
        }

        # Set balloon properties
        try {
            $trayIcon.BalloonTipTitle = $Title
            $trayIcon.BalloonTipText = $Message
            $trayIcon.BalloonTipIcon = $toolTipIcon
            # Note: BalloonTipDuration is not a settable property in NotifyIcon
            # The duration is controlled by ShowBalloonTip parameter

            # Show the balloon
            $trayIcon.ShowBalloonTip($Duration)

            Write-SilentLog "Balloon notification shown for tray icon '$Name': $Title" 'DEBUG'
        }
        catch {
            Write-TrayIconErrorLog -Message "Failed to show balloon: $_" -Operation "Show-TrayBalloon"
            # Balloon notifications may fail on some systems - don't throw
            Write-SilentLog "Balloon notification may not be supported on this system" 'DEBUG'
        }
    }
    catch {
        Write-TrayIconErrorLog -Message "Error showing balloon: $_" -Operation "Show-TrayBalloon"
    }
}

<#
.SYNOPSIS
    清理颜色缓存，释放内存

.DESCRIPTION
    清理颜色缓存以释放内存，在应用程序关闭时调用
#>
function Clear-ColorCache {
    try {
        $script:ColorCache.Clear()
        Write-SilentLog "颜色缓存已清理" 'DEBUG'
    }
    catch {
        Write-TrayIconErrorLog -Message "清理颜色缓存失败: $_" -Operation "Clear-ColorCache"
    }
}

# ============================================================
# Module Initialization
# ============================================================

# Initialize global tray icons collection
if ($null -eq $global:TrayIcons) {
    $global:TrayIcons = @{}
}

# Initialize color cache
$script:ColorCache = @{}

# Register application exit handler to clean cache
try {
    Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
        try {
            Clear-ColorCache
        }
        catch {
            # Silently fail on exit
        }
    }
}
catch {
    Write-SilentLog "无法注册应用程序退出事件: $_" 'DEBUG'
}

Write-SilentLog "托盘图标模块 v1.0.1 已加载 (颜色缓存已启用)" 'DEBUG'