# Settings.ps1 - Settings Dialog Module

# Error logging function for Settings module
function Write-SettingsErrorLog {
    param(
        [string]$Message,
        [string]$Operation = "Settings"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logPath = Join-Path $env:TEMP "GatewayLauncher_errors.log"
    $logEntry = "[$timestamp] [Settings] $Operation - $Message`n"
    try {
        Add-Content -Path $logPath -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    catch {
        # Silently fail if logging fails
    }
}

# Import required modules
# Use $PSScriptRoot, fallback to $MyInvocation if null
if ([string]::IsNullOrEmpty($PSScriptRoot)) {
    $script:ModuleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
else {
    $script:ModuleRoot = $PSScriptRoot
}

# Validate ModuleRoot is not null with graceful fallback
if ([string]::IsNullOrEmpty($script:ModuleRoot)) {
    Write-SilentLog "ModuleRoot is null. Attempting to use current directory." 'DEBUG'
    $script:ModuleRoot = Get-Location | Select-Object -ExpandProperty Path
}

# Build module paths with null safety
$configModulePath = $null
$themeModulePath = $null

if (-not [string]::IsNullOrEmpty($script:ModuleRoot)) {
    $configModulePath = Join-Path $script:ModuleRoot 'Config.ps1'
    $themeModulePath = Join-Path $script:ModuleRoot 'Theme.ps1'
}

# Import modules with error handling
if (-not [string]::IsNullOrEmpty($configModulePath) -and (Test-Path $configModulePath)) {
    try {
        Import-Module $configModulePath -Force -ErrorAction Stop
    }
    catch {
        Write-SilentLog "Failed to import Config module for Settings: $_" 'DEBUG'
    }
}

if (-not [string]::IsNullOrEmpty($themeModulePath) -and (Test-Path $themeModulePath)) {
    try {
        Import-Module $themeModulePath -Force -ErrorAction Stop
    }
    catch {
        Write-SilentLog "Failed to import Theme module for Settings: $_" 'DEBUG'
    }
}

# ============================================================
# Show-SettingsDialog - Display settings configuration dialog
# ============================================================

<#
.SYNOPSIS
    Displays a modal settings dialog for configuring gateway settings.

.DESCRIPTION
    Shows a WinForms dialog that allows users to configure:
    - Project path
    - Gateway port
    - Theme preference
    - Auto-start option
    - Log level

    Settings are saved to config/settings.json on confirmation.

.PARAMETER ParentForm
    Optional parent form for modal behavior.

.OUTPUTS
    bool - Returns $true if settings were saved, $false if cancelled.
#>
function Show-SettingsDialog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [System.Windows.Forms.Form]$ParentForm
    )
    try {
        # Load current settings from Config module (single source of truth)
        try {
            $script:currentConfig = LoadConfig
        }
        catch {
            Write-SettingsErrorLog -Message "Failed to load config: $_" -Operation "Show-SettingsDialog"
            # Use Config module's default values instead of duplicating them here
            $script:currentConfig = $script:DefaultConfig.Clone()
        }

        # Create form
        $form = New-Object System.Windows.Forms.Form
        $form.Text = 'Gateway Settings'
        $form.Size = New-Object System.Drawing.Size(500, 420)
        $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
        $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
        $form.MaximizeBox = $false
        $form.MinimizeBox = $false
        $form.BackColor = [System.Drawing.ColorTranslator]::FromHtml($global:NordicTheme.BackgroundPrimary)
        $form.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($global:NordicTheme.TextPrimary)

    # Title Label
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = 'Gateway Settings'
    $titleLabel.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
    $titleLabel.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($global:NordicTheme.TextPrimary)
    $titleLabel.Location = New-Object System.Drawing.Point(20, 15)
    $titleLabel.AutoSize = $true
    $form.Controls.Add($titleLabel)

    # --- Project Path Section ---
    $projectPathLabel = New-Object System.Windows.Forms.Label
    $projectPathLabel.Text = 'Project Path:'
    $projectPathLabel.Location = New-Object System.Drawing.Point(20, 60)
    $projectPathLabel.AutoSize = $true
    $projectPathLabel.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($global:NordicTheme.TextPrimary)
    $form.Controls.Add($projectPathLabel)

    $projectPathTextBox = New-Object System.Windows.Forms.TextBox
    $projectPathTextBox.Location = New-Object System.Drawing.Point(20, 80)
    $projectPathTextBox.Size = New-Object System.Drawing.Size(350, 25)
    $projectPathTextBox.Text = $script:currentConfig.ProjectPath
    $projectPathTextBox.BackColor = [System.Drawing.ColorTranslator]::FromHtml($global:NordicTheme.BackgroundSecondary)
    $projectPathTextBox.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($global:NordicTheme.TextPrimary)
    $projectPathTextBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $form.Controls.Add($projectPathTextBox)

    $browseButton = New-Object System.Windows.Forms.Button
    $browseButton.Text = 'Browse...'
    $browseButton.Location = New-Object System.Drawing.Point(380, 78)
    $browseButton.Size = New-Object System.Drawing.Size(80, 28)
    $browseButton.BackColor = [System.Drawing.ColorTranslator]::FromHtml($global:NordicTheme.BackgroundSecondary)
    $browseButton.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($global:NordicTheme.TextPrimary)
    $browseButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $browseButton.Add_Click({
        $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderDialog.Description = 'Select Project Folder'
        $folderDialog.UseDescriptionForTitle = $true
        if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $projectPathTextBox.Text = $folderDialog.SelectedPath
        }
    })
    $form.Controls.Add($browseButton)

    # --- Gateway Port Section ---
    $portLabel = New-Object System.Windows.Forms.Label
    $portLabel.Text = 'Gateway Port:'
    $portLabel.Location = New-Object System.Drawing.Point(20, 120)
    $portLabel.AutoSize = $true
    $portLabel.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($global:NordicTheme.TextPrimary)
    $form.Controls.Add($portLabel)

    $portTextBox = New-Object System.Windows.Forms.TextBox
    $portTextBox.Location = New-Object System.Drawing.Point(20, 140)
    $portTextBox.Size = New-Object System.Drawing.Size(120, 25)
    $portTextBox.Text = $script:currentConfig.GatewayPort
    $portTextBox.BackColor = [System.Drawing.ColorTranslator]::FromHtml($global:NordicTheme.BackgroundSecondary)
    $portTextBox.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($global:NordicTheme.TextPrimary)
    $portTextBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $form.Controls.Add($portTextBox)

    # --- Theme Preference Section ---
    $themeLabel = New-Object System.Windows.Forms.Label
    $themeLabel.Text = 'Theme:'
    $themeLabel.Location = New-Object System.Drawing.Point(180, 120)
    $themeLabel.AutoSize = $true
    $themeLabel.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($global:NordicTheme.TextPrimary)
    $form.Controls.Add($themeLabel)

    $themeComboBox = New-Object System.Windows.Forms.ComboBox
    $themeComboBox.Location = New-Object System.Drawing.Point(180, 140)
    $themeComboBox.Size = New-Object System.Drawing.Size(150, 25)
    $themeComboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $themeComboBox.BackColor = [System.Drawing.ColorTranslator]::FromHtml($global:NordicTheme.BackgroundSecondary)
    $themeComboBox.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($global:NordicTheme.TextPrimary)

    # Add theme options
    $themes = @('Nordic', 'Dark', 'Light')
    foreach ($theme in $themes) {
        $themeComboBox.Items.Add($theme)
    }
    $themeComboBox.SelectedItem = $script:currentConfig.ThemePreference
    $form.Controls.Add($themeComboBox)

    # --- Log Level Section ---
    $logLevelLabel = New-Object System.Windows.Forms.Label
    $logLevelLabel.Text = 'Log Level:'
    $logLevelLabel.Location = New-Object System.Drawing.Point(350, 120)
    $logLevelLabel.AutoSize = $true
    $logLevelLabel.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($global:NordicTheme.TextPrimary)
    $form.Controls.Add($logLevelLabel)

    $logLevelComboBox = New-Object System.Windows.Forms.ComboBox
    $logLevelComboBox.Location = New-Object System.Drawing.Point(350, 140)
    $logLevelComboBox.Size = New-Object System.Drawing.Size(110, 25)
    $logLevelComboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $logLevelComboBox.BackColor = [System.Drawing.ColorTranslator]::FromHtml($global:NordicTheme.BackgroundSecondary)
    $logLevelComboBox.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($global:NordicTheme.TextPrimary)

    # Add log level options
    $logLevels = @('Debug', 'Info', 'Warning', 'Error')
    foreach ($level in $logLevels) {
        $logLevelComboBox.Items.Add($level)
    }
    $logLevelComboBox.SelectedItem = $script:currentConfig.LogLevel
    $form.Controls.Add($logLevelComboBox)

    # --- Auto-Start Section ---
    $autoStartCheckBox = New-Object System.Windows.Forms.CheckBox
    $autoStartCheckBox.Text = 'Start Gateway automatically on launch'
    $autoStartCheckBox.Location = New-Object System.Drawing.Point(20, 185)
    $autoStartCheckBox.AutoSize = $true
    $autoStartCheckBox.Checked = $script:currentConfig.AutoStart
    $autoStartCheckBox.BackColor = [System.Drawing.ColorTranslator]::FromHtml($global:NordicTheme.BackgroundPrimary)
    $autoStartCheckBox.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($global:NordicTheme.TextPrimary)
    $form.Controls.Add($autoStartCheckBox)

    # --- Separator Line ---
    $separatorLine = New-Object System.Windows.Forms.Panel
    $separatorLine.Location = New-Object System.Drawing.Point(20, 220)
    $separatorLine.Size = New-Object System.Drawing.Size(440, 1)
    $separatorLine.BackColor = [System.Drawing.ColorTranslator]::FromHtml($global:NordicTheme.BorderNormal)
    $form.Controls.Add($separatorLine)

    # --- Buttons ---
    $saveButton = New-Object System.Windows.Forms.Button
    $saveButton.Text = 'Save'
    $saveButton.Location = New-Object System.Drawing.Point(290, 340)
    $saveButton.Size = New-Object System.Drawing.Size(80, 30)
    $saveButton.BackColor = [System.Drawing.ColorTranslator]::FromHtml($global:NordicTheme.AccentNormal)
    $saveButton.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($global:NordicTheme.TextOnAccent)
    $saveButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $saveButton.FlatAppearance.BorderSize = 0
    $saveButton.Add_Click({
        $script:dialogResult = $true
        $form.Close()
    })
    $form.Controls.Add($saveButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = 'Cancel'
    $cancelButton.Location = New-Object System.Drawing.Point(380, 340)
    $cancelButton.Size = New-Object System.Drawing.Size(80, 30)
    $cancelButton.BackColor = [System.Drawing.ColorTranslator]::FromHtml($global:NordicTheme.BackgroundSecondary)
    $cancelButton.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($global:NordicTheme.TextPrimary)
    $cancelButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $cancelButton.FlatAppearance.BorderSize = 1
    $cancelButton.FlatAppearance.BorderColor = [System.Drawing.ColorTranslator]::FromHtml($global:NordicTheme.BorderNormal)
    $cancelButton.Add_Click({
        $script:dialogResult = $false
        $form.Close()
    })
    $form.Controls.Add($cancelButton)

    # Validation function - returns error message or empty string if valid
    $script:isValid = $true

    # Error label for inline validation messages
    $errorLabel = New-Object System.Windows.Forms.Label
    $errorLabel.Location = New-Object System.Drawing.Point(20, 250)
    $errorLabel.Size = New-Object System.Drawing.Size(440, 60)
    $errorLabel.ForeColor = [System.Drawing.Color]::Red
    $errorLabel.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $errorLabel.Text = ""
    $errorLabel.Visible = $false
    $form.Controls.Add($errorLabel)

    function Validate-Settings {
        param($port, $path)

        $valid = $true
        $errorMessages = @()

        # Validate port
        if ([string]::IsNullOrWhiteSpace($port)) {
            $errorMessages += "Port cannot be empty."
            $valid = $false
        }
        elseif ($port -notmatch '^\d+$') {
            $errorMessages += "Port must be a valid number."
            $valid = $false
        }
        elseif ([int]$port -lt 1 -or [int]$port -gt 65535) {
            $errorMessages += "Port must be between 1 and 65535."
            $valid = $false
        }

        # Validate path
        if ([string]::IsNullOrWhiteSpace($path)) {
            $errorMessages += "Project path cannot be empty."
            $valid = $false
        }

        # Show inline error message instead of popup
        if (-not $valid) {
            $errorLabel.Text = $errorMessages -join "`n"
            $errorLabel.Visible = $true
        }
        else {
            $errorLabel.Visible = $false
        }

        return $valid
    }

    # Override Save button click with validation and error handling
    $saveButton.Remove_Click($saveButton.ClickEvents[0])
    $saveButton.Add_Click({
        try {
            if (Validate-Settings -port $portTextBox.Text -path $projectPathTextBox.Text) {
                $script:dialogResult = $true
                $form.Close()
            }
        }
        catch {
            Write-SettingsErrorLog -Message "Error in save button click: $_" -Operation "Show-SettingsDialog"
            $errorLabel.Text = "Error saving settings: $_"
            $errorLabel.Visible = $true
        }
    })

    # Show form as modal
    $script:dialogResult = $false
    try {
        if ($null -ne $ParentForm) {
            $form.ShowDialog($ParentForm)
        }
        else {
            $form.ShowDialog()
        }
    }
    catch {
        Write-SettingsErrorLog -Message "Error showing settings dialog: $_" -Operation "Show-SettingsDialog"
        # Show error inline instead of popup
        $errorLabel.Text = "Error displaying settings: $_"
        $errorLabel.Visible = $true
        return $false
    }

    # Process result
    if ($script:dialogResult) {
        try {
            # Update configuration
            Set-Config -Name 'ProjectPath' -Value $projectPathTextBox.Text
            Set-Config -Name 'GatewayPort' -Value ([int]$portTextBox.Text)
            Set-Config -Name 'ThemePreference' -Value $themeComboBox.SelectedItem
            Set-Config -Name 'AutoStart' -Value $autoStartCheckBox.Checked
            Set-Config -Name 'LogLevel' -Value $logLevelComboBox.SelectedItem

            # Save to file
            SaveConfig

            Write-SilentLog 'Settings saved successfully.' 'DEBUG'
            return $true
        }
        catch {
            Write-SettingsErrorLog -Message "Error saving settings: $_" -Operation "Show-SettingsDialog"
            # Show error inline instead of popup
            $errorLabel.Text = "Error saving settings: $_"
            $errorLabel.Visible = $true
            return $false
        }
    }

    return $false
    }
    catch {
        Write-SettingsErrorLog -Message "Failed to show settings dialog: $_" -Operation "Show-SettingsDialog"
        Write-SilentLog "Failed to show settings dialog: $_" 'DEBUG'
        # Show error inline instead of popup - but form may not be available, so just log
        Write-SettingsErrorLog -Message "Failed to load settings: $_" -Operation "Show-SettingsDialog"
        return $false
    }
}

# ============================================================
# Initialize on module load
# ============================================================

# Export module functions

