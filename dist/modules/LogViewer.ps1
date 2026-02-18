<#
.SYNOPSIS
    Log Viewer Module for Gateway Manager

.DESCRIPTION
    This module provides log viewer functionality for the Gateway Manager application.
    Displays gateway logs in a scrollable text box with filtering by date and log level,
    and supports auto-refresh functionality.

.VERSION
    1.0.0
.CREATED
    2026-02-15
.LAST_UPDATED
    2026-02-15
#>

# Error logging function for LogViewer module
function Write-LogViewerErrorLog {
    param(
        [string]$Message,
        [string]$Operation = "LogViewer"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logPath = Join-Path $env:TEMP "GatewayLauncher_errors.log"
    $logEntry = "[$timestamp] [LogViewer] $Operation - $Message`n"
    try {
        Add-Content -Path $logPath -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    catch {
        # Silently fail if logging fails
    }
}

# Default auto-refresh interval constant (can be overridden)
$script:DefaultAutoRefreshInterval = 3000  # milliseconds

# Global state for log viewer
try {
    $global:GatewayLogViewer = @{
        # LogFilePath will be set from Config module when Initialize-LogViewer is called
        LogFilePath = $null
        AutoRefreshEnabled = $false
        AutoRefreshInterval = $script:DefaultAutoRefreshInterval
        SelectedLogLevels = @('DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL')
        FilterStartDate = $null
        FilterEndDate = $null
        LastReadPosition = 0
        AutoRefreshTimer = $null
        IsInitialized = $false
    }
}
catch {
    Write-SilentLog "Failed to initialize log viewer state: $_" 'DEBUG'
}

# ============================================================
# Log Viewer Functions
# ============================================================

<#
.SYNOPSIS
    Initializes the log viewer and creates UI elements

.DESCRIPTION
    Creates and initializes all log viewer UI elements including the log display textbox,
    filter controls for date and log level, and auto-refresh toggle

.PARAMETER ParentControl
    The parent control to add log viewer elements to

.OUTPUTS
    Hashtable containing log viewer controls
#>
function Initialize-LogViewer {
    param(
        [Parameter(Mandatory = $false)]
        [System.Windows.Forms.Control]$ParentControl
    )

    try {
        $logViewerControls = @{}

        # Get log file path from Config module (single source of truth)
        if ($null -eq $global:GatewayLogViewer.LogFilePath) {
            try {
                $configLogPath = Get-Config -Name "LogFilePath"
                if (-not [string]::IsNullOrEmpty($configLogPath)) {
                    $global:GatewayLogViewer.LogFilePath = $configLogPath
                } else {
                    # Fallback to default if config not available
                    $global:GatewayLogViewer.LogFilePath = Join-Path $env:TEMP "openclaw-gateway.log"
                }
            }
            catch {
                # Fallback if Config module not available
                $global:GatewayLogViewer.LogFilePath = Join-Path $env:TEMP "openclaw-gateway.log"
            }
        }

        # Create main container panel
        try {
            $logViewerPanel = New-Object System.Windows.Forms.Panel
            $logViewerPanel.Name = 'LogViewerPanel'
            $logViewerPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
            $logViewerPanel.BackColor = $global:NordicTheme.BackgroundPrimary
        }
        catch {
            Write-LogViewerErrorLog -Message "Failed to create log viewer panel: $_" -Operation "Initialize-LogViewer"
            $logViewerPanel = New-Object System.Windows.Forms.Panel
            $logViewerPanel.Name = 'LogViewerPanel'
            $logViewerPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
        }

        if ($ParentControl) {
            try {
                $ParentControl.Controls.Add($logViewerPanel)
            }
            catch {
                Write-LogViewerErrorLog -Message "Failed to add panel to parent: $_" -Operation "Initialize-LogViewer"
            }
        }
    }
    catch {
        Write-LogViewerErrorLog -Message "Failed to initialize log viewer: $_" -Operation "Initialize-LogViewer"
        Write-SilentLog "Failed to initialize log viewer: $_" 'DEBUG'
        return $null
    }

    # ------------------------------------------
    # Filter Panel (Top)
    # ------------------------------------------
    $filterPanel = New-Object System.Windows.Forms.Panel
    $filterPanel.Name = 'FilterPanel'
    $filterPanel.Location = New-Object System.Drawing.Point(10, 10)
    $filterPanel.Size = New-Object System.Drawing.Size(780, 50)
    $filterPanel.BackColor = $global:NordicTheme.BackgroundSecondary
    $logViewerPanel.Controls.Add($filterPanel)

    # Date From Label
    $dateFromLabel = New-Object System.Windows.Forms.Label
    $dateFromLabel.Name = 'DateFromLabel'
    $dateFromLabel.Text = 'From:'
    $dateFromLabel.Location = New-Object System.Drawing.Point(10, 15)
    $dateFromLabel.AutoSize = $true
    $dateFromLabel.Font = New-Object System.Drawing.Font($global:NordicTheme.FontDefault, 9)
    $dateFromLabel.ForeColor = $global:NordicTheme.TextSecondary
    $filterPanel.Controls.Add($dateFromLabel)

    # Date From Picker
    $dateFromPicker = New-Object System.Windows.Forms.DateTimePicker
    $dateFromPicker.Name = 'DateFromPicker'
    $dateFromPicker.Location = New-Object System.Drawing.Point(50, 12)
    $dateFromPicker.Size = New-Object System.Drawing.Size(140, 25)
    $dateFromPicker.Format = [System.Windows.Forms.DateTimePickerFormat]::Short
    $dateFromPicker.BackColor = $global:NordicTheme.BackgroundSecondary
    $dateFromPicker.ForeColor = $global:NordicTheme.TextPrimary
    $dateFromPicker.Add_ValueChanged({
        $global:GatewayLogViewer.FilterStartDate = $this.Value
        $logControls = $script:CurrentLogViewerControls
        if ($logControls -and $logControls.ContainsKey('RefreshButton')) {
            & $logControls['RefreshButton'].Tag
        }
    })
    $filterPanel.Controls.Add($dateFromPicker)
    $logViewerControls['DateFromPicker'] = $dateFromPicker

    # Date To Label
    $dateToLabel = New-Object System.Windows.Forms.Label
    $dateToLabel.Name = 'DateToLabel'
    $dateToLabel.Text = 'To:'
    $dateToLabel.Location = New-Object System.Drawing.Point(200, 15)
    $dateToLabel.AutoSize = $true
    $dateToLabel.Font = New-Object System.Drawing.Font($global:NordicTheme.FontDefault, 9)
    $dateToLabel.ForeColor = $global:NordicTheme.TextSecondary
    $filterPanel.Controls.Add($dateToLabel)

    # Date To Picker
    $dateToPicker = New-Object System.Windows.Forms.DateTimePicker
    $dateToPicker.Name = 'DateToPicker'
    $dateToPicker.Location = New-Object System.Drawing.Point(230, 12)
    $dateToPicker.Size = New-Object System.Drawing.Size(140, 25)
    $dateToPicker.Format = [System.Windows.Forms.DateTimePickerFormat]::Short
    $dateToPicker.BackColor = $global:NordicTheme.BackgroundSecondary
    $dateToPicker.ForeColor = $global:NordicTheme.TextPrimary
    $dateToPicker.Add_ValueChanged({
        $global:GatewayLogViewer.FilterEndDate = $this.Value
        $logControls = $script:CurrentLogViewerControls
        if ($logControls -and $logControls.ContainsKey('RefreshButton')) {
            & $logControls['RefreshButton'].Tag
        }
    })
    $filterPanel.Controls.Add($dateToPicker)
    $logViewerControls['DateToPicker'] = $dateToPicker

    # Log Level Filter Label
    $levelLabel = New-Object System.Windows.Forms.Label
    $levelLabel.Name = 'LevelLabel'
    $levelLabel.Text = 'Levels:'
    $levelLabel.Location = New-Object System.Drawing.Point(380, 15)
    $levelLabel.AutoSize = $true
    $levelLabel.Font = New-Object System.Drawing.Font($global:NordicTheme.FontDefault, 9)
    $levelLabel.ForeColor = $global:NordicTheme.TextSecondary
    $filterPanel.Controls.Add($levelLabel)

    # Log Level Checkboxes
    $levelPanelX = 430
    $levelPanelY = 10
    $levelWidth = 70

    $logLevels = @('DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL')
    $levelCheckboxes = @{}

    foreach ($level in $logLevels) {
        $levelCheckbox = New-Object System.Windows.Forms.CheckBox
        $levelCheckbox.Name = "Level$level"
        $levelCheckbox.Text = $level
        $levelCheckbox.Location = New-Object System.Drawing.Point($levelPanelX, $levelPanelY)
        $levelCheckbox.AutoSize = $true
        $levelCheckbox.Checked = $true
        $levelCheckbox.BackColor = $global:NordicTheme.BackgroundSecondary
        $levelCheckbox.ForeColor = $global:NordicTheme.TextPrimary

        # Set color based on level
        switch ($level) {
            'DEBUG' { $levelCheckbox.ForeColor = $global:NordicTheme.TextTertiary }
            'INFO'  { $levelCheckbox.ForeColor = $global:NordicTheme.StatusInfo }
            'WARN'  { $levelCheckbox.ForeColor = $global:NordicTheme.StatusWarning }
            'ERROR' { $levelCheckbox.ForeColor = $global:NordicTheme.StatusError }
            'FATAL' { $levelCheckbox.ForeColor = $global:NordicTheme.StatusError }
        }

        $levelCheckbox.Add_CheckedChanged({
            $selectedLevels = @()
            foreach ($lvl in $logLevels) {
                $cb = $filterPanel.Controls["Level$lvl"]
                if ($cb.Checked) {
                    $selectedLevels += $lvl
                }
            }
            $global:GatewayLogViewer.SelectedLogLevels = $selectedLevels
            $logControls = $script:CurrentLogViewerControls
            if ($logControls -and $logControls.ContainsKey('RefreshButton')) {
                & $logControls['RefreshButton'].Tag
            }
        })

        $filterPanel.Controls.Add($levelCheckbox)
        $levelCheckboxes[$level] = $levelCheckbox
        $levelPanelX += $levelWidth
    }
    $logViewerControls['LevelCheckboxes'] = $levelCheckboxes

    # Auto-refresh Checkbox
    $autoRefreshCheckbox = New-Object System.Windows.Forms.CheckBox
    $autoRefreshCheckbox.Name = 'AutoRefreshCheckbox'
    $autoRefreshCheckbox.Text = 'Auto-refresh'
    $autoRefreshCheckbox.Location = New-Object System.Drawing.Point(780, 15)
    $autoRefreshCheckbox.AutoSize = $true
    $autoRefreshCheckbox.Checked = $false
    $autoRefreshCheckbox.BackColor = $global:NordicTheme.BackgroundSecondary
    $autoRefreshCheckbox.ForeColor = $global:NordicTheme.TextPrimary
    $autoRefreshCheckbox.Add_CheckedChanged({
        $global:GatewayLogViewer.AutoRefreshEnabled = $this.Checked
        $logControls = $script:CurrentLogViewerControls
        if ($logControls -and $logControls.ContainsKey('LogTextBox')) {
            if ($this.Checked) {
                Start-LogViewerAutoRefresh -LogViewerControls $logControls
            } else {
                Stop-LogViewerAutoRefresh
            }
        }
    })
    $filterPanel.Controls.Add($autoRefreshCheckbox)
    $logViewerControls['AutoRefreshCheckbox'] = $autoRefreshCheckbox

    # Refresh Button
    $refreshButton = New-Object System.Windows.Forms.Button
    $refreshButton.Name = 'RefreshButton'
    $refreshButton.Text = 'Refresh'
    $refreshButton.Location = New-Object System.Drawing.Point(880, 10)
    $refreshButton.Size = New-Object System.Drawing.Size(80, 25)
    $refreshButton.BackColor = $global:NordicTheme.AccentNormal
    $refreshButton.ForeColor = $global:NordicTheme.TextOnAccent
    $refreshButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat

    # Store refresh action in Tag
    $refreshButton.Tag = {
        $logControls = $script:CurrentLogViewerControls
        if ($logControls -and $logControls.ContainsKey('LogTextBox')) {
            Refresh-LogViewer -LogViewerControls $logControls
        }
    }
    $refreshButton.Add_Click($refreshButton.Tag)
    $filterPanel.Controls.Add($refreshButton)
    $logViewerControls['RefreshButton'] = $refreshButton

    # Clear Button
    $clearButton = New-Object System.Windows.Forms.Button
    $clearButton.Name = 'ClearButton'
    $clearButton.Text = 'Clear'
    $clearButton.Location = New-Object System.Drawing.Point(970, 10)
    $clearButton.Size = New-Object System.Drawing.Size(60, 25)
    $clearButton.BackColor = $global:NordicTheme.BackgroundSecondary
    $clearButton.ForeColor = $global:NordicTheme.TextPrimary
    $clearButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $clearButton.Add_Click({
        $logControls = $script:CurrentLogViewerControls
        if ($logControls -and $logControls.ContainsKey('LogTextBox')) {
            $logControls['LogTextBox'].Clear()
        }
    })
    $filterPanel.Controls.Add($clearButton)
    $logViewerControls['ClearButton'] = $clearButton

    # ------------------------------------------
    # Log Display TextBox (Main Area)
    # ------------------------------------------
    $logTextBox = New-Object System.Windows.Forms.TextBox
    $logTextBox.Name = 'LogTextBox'
    $logTextBox.Location = New-Object System.Drawing.Point(10, 70)
    $logTextBox.Size = New-Object System.Drawing.Size(1060, 500)
    $logTextBox.Multiline = $true
    $logTextBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
    $logTextBox.ReadOnly = $true
    $logTextBox.Font = New-Object System.Drawing.Font($global:NordicTheme.FontCode, 9)
    $logTextBox.BackColor = $global:NordicTheme.BackgroundSecondary
    $logTextBox.ForeColor = $global:NordicTheme.TextPrimary
    $logTextBox.WordWrap = $false
    $logViewerPanel.Controls.Add($logTextBox)
    $logViewerControls['LogTextBox'] = $logTextBox

    # Status Bar Panel
    $statusPanel = New-Object System.Windows.Forms.Panel
    $statusPanel.Name = 'StatusPanel'
    $statusPanel.Location = New-Object System.Drawing.Point(10, 575)
    $statusPanel.Size = New-Object System.Drawing.Size(780, 25)
    $statusPanel.BackColor = $global:NordicTheme.BackgroundSecondary
    $logViewerPanel.Controls.Add($statusPanel)

    # Log Count Label
    $logCountLabel = New-Object System.Windows.Forms.Label
    $logCountLabel.Name = 'LogCountLabel'
    $logCountLabel.Text = 'Entries: 0'
    $logCountLabel.Location = New-Object System.Drawing.Point(10, 5)
    $logCountLabel.AutoSize = $true
    $logCountLabel.Font = New-Object System.Drawing.Font($global:NordicTheme.FontDefault, 9)
    $logCountLabel.ForeColor = $global:NordicTheme.TextTertiary
    $statusPanel.Controls.Add($logCountLabel)
    $logViewerControls['LogCountLabel'] = $logCountLabel

    # Last Update Label
    $lastUpdateLabel = New-Object System.Windows.Forms.Label
    $lastUpdateLabel.Name = 'LastUpdateLabel'
    $lastUpdateLabel.Text = 'Last Update: --:--:--'
    $lastUpdateLabel.Location = New-Object System.Drawing.Point(150, 5)
    $lastUpdateLabel.AutoSize = $true
    $lastUpdateLabel.Font = New-Object System.Drawing.Font($global:NordicTheme.FontDefault, 9)
    $lastUpdateLabel.ForeColor = $global:NordicTheme.TextTertiary
    $statusPanel.Controls.Add($lastUpdateLabel)
    $logViewerControls['LastUpdateLabel'] = $lastUpdateLabel

    # Auto-refresh Status Label
    $autoRefreshStatusLabel = New-Object System.Windows.Forms.Label
    $autoRefreshStatusLabel.Name = 'AutoRefreshStatusLabel'
    $autoRefreshStatusLabel.Text = 'Auto-refresh: Off'
    $autoRefreshStatusLabel.Location = New-Object System.Drawing.Point(320, 5)
    $autoRefreshStatusLabel.AutoSize = $true
    $autoRefreshStatusLabel.Font = New-Object System.Drawing.Font($global:NordicTheme.FontDefault, 9)
    $autoRefreshStatusLabel.ForeColor = $global:NordicTheme.TextTertiary
    $statusPanel.Controls.Add($autoRefreshStatusLabel)
    $logViewerControls['AutoRefreshStatusLabel'] = $autoRefreshStatusLabel

    $logViewerControls['Panel'] = $logViewerPanel
    $logViewerControls['FilterPanel'] = $filterPanel
    $logViewerControls['StatusPanel'] = $statusPanel

    # Store controls globally for access
    $script:CurrentLogViewerControls = $logViewerControls

    # Initial load of logs with error handling
    try {
        Refresh-LogViewer -LogViewerControls $logViewerControls
    }
    catch {
        Write-LogViewerErrorLog -Message "Failed to load initial logs: $_" -Operation "Initialize-LogViewer"
    }

    # Mark as initialized
    $global:GatewayLogViewer.IsInitialized = $true

    return $logViewerControls
}
catch {
    Write-LogViewerErrorLog -Message "Failed to initialize log viewer: $_" -Operation "Initialize-LogViewer"
    Write-SilentLog "Failed to initialize log viewer: $_" 'DEBUG'
    return $null
}

<#
.SYNOPSIS
    Refreshes the log viewer display with filtered logs

.DESCRIPTION
    Reads the log file, applies filters (date and log level), and displays the results

.PARAMETER LogViewerControls
    Hashtable containing log viewer UI controls
#>
function Refresh-LogViewer {
    param(
        [Parameter(Mandatory = $false)]
        [hashtable]$LogViewerControls
    )

    if (-not $LogViewerControls) {
        $LogViewerControls = $script:CurrentLogViewerControls
    }

    if (-not $LogViewerControls -or -not $LogViewerControls.ContainsKey('LogTextBox')) {
        return
    }

    $logTextBox = $LogViewerControls['LogTextBox']
    $logCountLabel = $LogViewerControls['LogCountLabel']
    $lastUpdateLabel = $LogViewerControls['LastUpdateLabel']

    $logFilePath = $global:GatewayLogViewer.LogFilePath

    # Check if log file exists
    if (-not (Test-Path $logFilePath)) {
        $logTextBox.Text = "Log file not found: $logFilePath`n`nStart the gateway to generate logs."
        $logCountLabel.Text = 'Entries: 0'
        $lastUpdateLabel.Text = "Last Update: $(Get-Date -Format 'HH:mm:ss')"
        return
    }

    try {
        # Read all log lines
        $logLines = Get-Content -Path $logFilePath -ErrorAction SilentlyContinue

        if ($null -eq $logLines -or $logLines.Count -eq 0) {
            $logTextBox.Text = "Log file is empty."
            $logCountLabel.Text = 'Entries: 0'
            $lastUpdateLabel.Text = "Last Update: $(Get-Date -Format 'HH:mm:ss')"
            return
        }

        # Apply filters
        $filteredLines = @()
        $selectedLevels = $global:GatewayLogViewer.SelectedLogLevels
        $startDate = $global:GatewayLogViewer.FilterStartDate
        $endDate = $global:GatewayLogViewer.FilterEndDate

        foreach ($line in $logLines) {
            $includeLine = $true

            # Parse log level
            $level = Get-LogLevelFromLine -Line $line

            # Filter by log level
            if ($selectedLevels -and $selectedLevels.Count -gt 0) {
                if ($level -and $selectedLevels -notcontains $level) {
                    $includeLine = $false
                }
            }

            # Filter by date
            if ($includeLine -and ($startDate -or $endDate)) {
                $lineDate = Get-LogDateFromLine -Line $line

                if ($lineDate) {
                    if ($startDate -and $lineDate -lt $startDate) {
                        $includeLine = $false
                    }
                    if ($endDate -and $lineDate -gt $endDate.AddDays(1)) {
                        $includeLine = $false
                    }
                }
            }

            if ($includeLine) {
                $filteredLines += $line
            }
        }

        # Apply color formatting and display
        $coloredOutput = @()
        foreach ($line in $filteredLines) {
            $coloredOutput += $line
        }

        # Display with coloring (using RichTextBox would be better, but TextBox doesn't support multi-color)
        # For simplicity, we'll use plain text but could upgrade to RichTextBox for colored output
        $logTextBox.Text = $coloredOutput -join "`n"

        # Scroll to bottom
        $logTextBox.SelectionStart = $logTextBox.Text.Length
        $logTextBox.ScrollToCaret()

        # Update status
        $logCountLabel.Text = "Entries: $($filteredLines.Count)"
        $lastUpdateLabel.Text = "Last Update: $(Get-Date -Format 'HH:mm:ss')"

    } catch {
        $logTextBox.Text = "Error reading log file: $_"
        $logCountLabel.Text = 'Entries: 0'
    }
}

<#
.SYNOPSIS
    Extracts the log level from a log line

.DESCRIPTION
    Parses a log line and extracts the log level (DEBUG, INFO, WARN, ERROR, FATAL)

.PARAMETER Line
    The log line to parse

.OUTPUTS
    String containing the log level, or null if not found
#>
function Get-LogLevelFromLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Line
    )

    # Common log patterns
    # [2026-02-15 10:30:45] [INFO] message
    # 2026-02-15T10:30:45.123Z INFO message
    # INFO 2026-02-15 message

    $patterns = @(
        '\[(DEBUG|INFO|WARN|WARNING|ERROR|FATAL|TRACE)\]',
        '(DEBUG|INFO|WARN|WARNING|ERROR|FATAL|TRACE)\s',
        '^\s*(DEBUG|INFO|WARN|WARNING|ERROR|FATAL|TRACE)\s',
        '\s(DEBUG|INFO|WARN|WARNING|ERROR|FATAL|TRACE):'
    )

    foreach ($pattern in $patterns) {
        if ($Line -match $pattern) {
            $level = $Matches[1]
            # Normalize WARNING to WARN
            if ($level -eq 'WARNING') { $level = 'WARN' }
            if ($level -eq 'TRACE') { $level = 'DEBUG' }
            return $level
        }
    }

    return $null
}

<#
.SYNOPSIS
    Extracts the date from a log line

.DESCRIPTION
    Parses a log line and extracts the timestamp

.PARAMETER Line
    The log line to parse

.OUTPUTS
    DateTime object if found, null otherwise
#>
function Get-LogDateFromLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Line
    )

    # Common date patterns
    # [2026-02-15 10:30:45]
    # 2026-02-15T10:30:45
    # 2026-02-15 10:30:45

    $patterns = @(
        '\[(\d{4}-\d{2}-\d{2})',
        '^(\d{4}-\d{2}-\d{2})',
        '(\d{4}-\d{2}-\d{2})T'
    )

    foreach ($pattern in $patterns) {
        if ($Line -match $pattern) {
            $dateStr = $Matches[1]
            try {
                return [DateTime]::ParseExact($dateStr, 'yyyy-MM-dd', $null)
            } catch {
                try {
                    return [DateTime]::Parse($dateStr)
                } catch {
                    # Ignore parse errors
                }
            }
        }
    }

    return $null
}

<#
.SYNOPSIS
    Starts auto-refresh timer for log viewer

.DESCRIPTION
    Creates and starts a timer that periodically refreshes the log display

.PARAMETER LogViewerControls
    Hashtable containing log viewer UI controls
#>
function Start-LogViewerAutoRefresh {
    param(
        [Parameter(Mandatory = $false)]
        [hashtable]$LogViewerControls
    )

    if (-not $LogViewerControls) {
        $LogViewerControls = $script:CurrentLogViewerControls
    }

    # Stop existing timer if any
    Stop-LogViewerAutoRefresh

    $global:GatewayLogViewer.AutoRefreshEnabled = $true

    # Update status label
    if ($LogViewerControls -and $LogViewerControls.ContainsKey('AutoRefreshStatusLabel')) {
        $LogViewerControls['AutoRefreshStatusLabel'].Text = "Auto-refresh: On ($($global:GatewayLogViewer.AutoRefreshInterval / 1000)s)"
    }

    # Create timer
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = $global:GatewayLogViewer.AutoRefreshInterval
    $timer.Add_Tick({
        $controls = $script:CurrentLogViewerControls
        if ($controls -and $controls.ContainsKey('LogTextBox')) {
            Refresh-LogViewer -LogViewerControls $controls
        }
    })

    $timer.Start()
    $global:GatewayLogViewer.AutoRefreshTimer = $timer
}

<#
.SYNOPSIS
    Stops auto-refresh timer

.DESCRIPTION
    Stops and disposes the auto-refresh timer
#>
function Stop-LogViewerAutoRefresh {
    if ($global:GatewayLogViewer.AutoRefreshTimer) {
        $global:GatewayLogViewer.AutoRefreshTimer.Stop()
        $global:GatewayLogViewer.AutoRefreshTimer.Dispose()
        $global:GatewayLogViewer.AutoRefreshTimer = $null
    }

    $global:GatewayLogViewer.AutoRefreshEnabled = $false

    # Update status label
    $logControls = $script:CurrentLogViewerControls
    if ($logControls -and $logControls.ContainsKey('AutoRefreshStatusLabel')) {
        $logControls['AutoRefreshStatusLabel'].Text = 'Auto-refresh: Off'
    }
}

<#
.SYNOPSIS
    Sets the log file path

.DESCRIPTION
    Updates the log file path used by the log viewer

.PARAMETER Path
    The new log file path
#>
function Set-LogViewerPath {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $global:GatewayLogViewer.LogFilePath = $Path

    # Refresh if controls exist
    $logControls = $script:CurrentLogViewerControls
    if ($logControls -and $logControls.ContainsKey('LogTextBox')) {
        Refresh-LogViewer -LogViewerControls $logControls
    }
}

<#
.SYNOPSIS
    Sets the auto-refresh interval

.DESCRIPTION
    Updates the auto-refresh interval in milliseconds

.PARAMETER IntervalMs
    The refresh interval in milliseconds (default: 3000)
#>
function Set-LogViewerRefreshInterval {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateRange(1000, 60000)]
        [int]$IntervalMs
    )

    $global:GatewayLogViewer.AutoRefreshInterval = $IntervalMs

    # Restart timer if auto-refresh is enabled
    if ($global:GatewayLogViewer.AutoRefreshEnabled) {
        Start-LogViewerAutoRefresh
    }
}

<#
.SYNOPSIS
    Gets the current log viewer state

.DESCRIPTION
    Returns the current state of the log viewer including filters and auto-refresh status

.OUTPUTS
    Hashtable containing current log viewer state
#>
function Get-LogViewerState {
    return @{
        LogFilePath = $global:GatewayLogViewer.LogFilePath
        AutoRefreshEnabled = $global:GatewayLogViewer.AutoRefreshEnabled
        AutoRefreshInterval = $global:GatewayLogViewer.AutoRefreshInterval
        SelectedLogLevels = $global:GatewayLogViewer.SelectedLogLevels
        FilterStartDate = $global:GatewayLogViewer.FilterStartDate
        FilterEndDate = $global:GatewayLogViewer.FilterEndDate
    }
}

<#
.SYNOPSIS
    Exports log entries to a file

.DESCRIPTION
    Exports the currently filtered log entries to a specified file

.PARAMETER OutputPath
    The path to export the logs to

.PARAMETER LogViewerControls
    Hashtable containing log viewer UI controls
#>
function Export-LogViewerContent {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [hashtable]$LogViewerControls
    )

    if (-not $LogViewerControls) {
        $LogViewerControls = $script:CurrentLogViewerControls
    }

    if (-not $LogViewerControls -or -not $LogViewerControls.ContainsKey('LogTextBox')) {
        throw "Log viewer controls not available"
    }

    $logTextBox = $LogViewerControls['LogTextBox']
    $logTextBox.Text | Out-File -FilePath $OutputPath -Encoding UTF8
}

# Export module functions (removed - not needed for dot-sourced scripts)
# Functions are automatically available when dot-sourced

# Initialize module on import
Write-SilentLog "LogViewer Module v1.0.0 loaded successfully" 'DEBUG'
