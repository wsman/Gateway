<#
.SYNOPSIS
    Gateway Launcher - Main Application Entry Point

.DESCRIPTION
    Gateway Launcher imports all required modules (Theme, Config, TrayIcon, Dashboard)
    and creates a modern WinForms application with Nordic theme styling.

.VERSION
    1.0.1
.CREATED
    2026-02-15
.LAST_UPDATED
    2026-02-16
#>

# ============================================================
# CRITICAL: Load Assemblies FIRST (required for EXE mode)
# ============================================================

try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
}
catch {
    # If assembly loading fails, write to a crash log and exit
    $crashLog = Join-Path $env:TEMP "GatewayLauncher_crash.log"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$timestamp] FATAL: Failed to load WinForms assemblies: $_" | Out-File -FilePath $crashLog -Encoding UTF8
    exit 1
}

# ============================================================
# Error Handling Setup
# ============================================================

# Error log path
$script:ErrorLogPath = Join-Path $env:TEMP "GatewayLauncher_errors.log"

# Function to log errors
function Write-AppErrorLog {
    param(
        [string]$Message,
        [string]$Operation = "Application"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [GatewayLauncher] $Operation - $Message`n"
    try {
        Add-Content -Path $script:ErrorLogPath -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    catch {
        # Silently fail if logging fails
    }
}

# Function to show error as non-blocking notification (no popup)
function Show-AppErrorDialog {
    param(
        [string]$Message,
        [string]$Title = "Error",
        [string[]]$Suggestions = @()
    )

    # Log to error file
    Write-AppErrorLog -Message $Message -Operation $Title

    # Build full message for display
    $fullMessage = $Message
    if ($Suggestions.Count -gt 0) {
        $fullMessage += "`n`nSuggestions:"
        foreach ($suggestion in $Suggestions) {
            $fullMessage += "`n- $suggestion"
        }
    }

    # Display in output log instead of popup
    try {
        if ($script:OutputTextBox) {
            $time = Get-Date -Format "HH:mm:ss"
            $script:OutputTextBox.AppendText("[$time] ERROR: $fullMessage`r`n")
            $script:OutputTextBox.ScrollToCaret()
        }
    }
    catch {
        # Silently fail if output textbox not available
    }
}

# ============================================================
# Silent Logging Function
# ============================================================

# Debug log file path for EXE mode troubleshooting
$script:DebugLogPath = Join-Path $env:TEMP "GatewayLauncher_debug.log"

function Write-SilentLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Always write to debug log file (for troubleshooting EXE issues)
    try {
        Add-Content -Path $script:DebugLogPath -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    catch {
        # Silently fail
    }
    
    # Try to write to UI if available
    try {
        if ($script:OutputTextBox -and $script:OutputTextBox -is [System.Windows.Forms.TextBox]) {
            $script:OutputTextBox.AppendText("$logEntry`r`n")
            $script:OutputTextBox.ScrollToCaret()
        }
    }
    catch {
        # Silently fail if output textbox not available
    }
}

# ============================================================
# Script Initialization
# ============================================================

# Get script directory for relative path resolution
# ROBUST fallback pattern that works for both PS1 and EXE modes
$ScriptRoot = try {
    if (-not [string]::IsNullOrEmpty($PSScriptRoot)) {
        # Standard PowerShell script mode
        $PSScriptRoot
    }
    elseif (-not [string]::IsNullOrEmpty($MyInvocation.MyCommand.Path)) {
        # Fallback: use the invoked script path
        Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    elseif ($null -ne [System.Diagnostics.Process]::GetCurrentProcess()) {
        # EXE mode: use the executable's directory
        $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        if (-not [string]::IsNullOrEmpty($exePath)) {
            Split-Path -Parent $exePath
        }
        else {
            Get-Location | Select-Object -ExpandProperty Path
        }
    }
    else {
        # Final fallback to current working directory
        Get-Location | Select-Object -ExpandProperty Path
    }
}
catch {
    # If all else fails, use current directory
    Get-Location | Select-Object -ExpandProperty Path
}

# Log which path was used (silent in EXE - no console popups)
$scriptSource = try {
    if (-not [string]::IsNullOrEmpty($PSScriptRoot)) {
        "PSScriptRoot: $PSScriptRoot"
    }
    elseif (-not [string]::IsNullOrEmpty($MyInvocation.MyCommand.Path)) {
        "MyInvocation: $($MyInvocation.MyCommand.Path)"
    }
    elseif ($null -ne [System.Diagnostics.Process]::GetCurrentProcess()) {
        $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        "EXE Path: $exePath"
    }
    else {
        "Current working directory"
    }
}
catch {
    "Unknown source"
}

# Write to debug log for troubleshooting
Write-SilentLog "========================================" 'INFO'
Write-SilentLog "Gateway Launcher Starting..." 'INFO'
Write-SilentLog "========================================" 'INFO'
Write-SilentLog "Script source: $scriptSource" 'DEBUG'
Write-SilentLog "Script root resolved to: $ScriptRoot" 'DEBUG'
Write-SilentLog "PowerShell version: $($PSVersionTable.PSVersion)" 'DEBUG'
Write-SilentLog "OS: $([System.Environment]::OSVersion.VersionString)" 'DEBUG'

$ModulesPath = Join-Path $ScriptRoot "modules"

# Import required modules with error handling
# Silent loading - no console output to avoid popups in EXE

$moduleLoadErrors = @()

# Import Theme Module (required first for Nordic theme)
try {
    . "$ModulesPath\Theme.ps1"
    Write-SilentLog "Theme module loaded" 'DEBUG'
}
catch {
    $moduleLoadErrors += "Theme: $_"
    Write-SilentLog "Failed to load Theme module: $_" 'DEBUG'
}

# Import Config Module
try {
    . "$ModulesPath\Config.ps1"
    Write-SilentLog "Config module loaded" 'DEBUG'
}
catch {
    $moduleLoadErrors += "Config: $_"
    Write-SilentLog "Failed to load Config module: $_" 'DEBUG'
}

# Import TrayIcon Module
try {
    . "$ModulesPath\TrayIcon.ps1"
    Write-SilentLog "TrayIcon module loaded" 'DEBUG'
}
catch {
    $moduleLoadErrors += "TrayIcon: $_"
    Write-SilentLog "Failed to load TrayIcon module: $_" 'DEBUG'
}

# Import Dashboard Module
try {
    . "$ModulesPath\Dashboard.ps1"
    Write-SilentLog "Dashboard module loaded" 'DEBUG'
}
catch {
    $moduleLoadErrors += "Dashboard: $_"
    Write-SilentLog "Failed to load Dashboard module: $_" 'DEBUG'
}

# Import Settings Module
try {
    . "$ModulesPath\Settings.ps1"
    Write-SilentLog "Settings module loaded" 'DEBUG'
}
catch {
    $moduleLoadErrors += "Settings: $_"
    Write-SilentLog "Failed to load Settings module: $_" 'DEBUG'
}

# Import Enhanced Interactions Module (optional - has PowerShell 5.1 compatibility issues)
try {
    . "$ModulesPath\EnhancedInteractions.ps1"
    Write-SilentLog "EnhancedInteractions module loaded" 'DEBUG'
}
catch {
    # Non-critical module - continue without it
    Write-SilentLog "EnhancedInteractions module skipped (optional): $_" 'WARN'
}

# Import MotionButton Module (optional - has PowerShell 5.1 compatibility issues)
try {
    . "$ModulesPath\MotionButton.ps1"
    Write-SilentLog "MotionButton module loaded" 'DEBUG'
}
catch {
    # Non-critical module - continue without it
    Write-SilentLog "MotionButton module skipped (optional): $_" 'WARN'
}

# Import PageSkeleton Module
try {
    . "$ModulesPath\PageSkeleton.ps1"
    Write-SilentLog "PageSkeleton module loaded" 'DEBUG'
}
catch {
    $moduleLoadErrors += "PageSkeleton: $_"
    Write-SilentLog "Failed to load PageSkeleton module: $_" 'DEBUG'
}

# Import RollingNumber Module (optional - has PowerShell 5.1 compatibility issues)
try {
    . "$ModulesPath\RollingNumber.ps1"
    Write-SilentLog "RollingNumber module loaded" 'DEBUG'
}
catch {
    # Non-critical module - continue without it
    Write-SilentLog "RollingNumber module skipped (optional): $_" 'WARN'
}

# Import PortConflictResolver Module
try {
    . "$ModulesPath\PortConflictResolver.ps1"
    Write-SilentLog "PortConflictResolver module loaded" 'DEBUG'
}
catch {
    # Non-critical module - continue without it
    Write-SilentLog "PortConflictResolver module skipped (optional): $_" 'WARN'
}

# Check if CRITICAL modules loaded successfully
# Only Theme, Config, TrayIcon, Dashboard, Settings are critical
$criticalModuleErrors = $moduleLoadErrors | Where-Object { 
    $_ -match "Theme:|Config:|TrayIcon:|Dashboard:|Settings:" 
}

if ($criticalModuleErrors.Count -gt 0) {
    Write-AppErrorLog -Message "Failed to load critical modules: $($criticalModuleErrors -join ', ')" -Operation "ModuleLoad"
    $errorMsg = "Critical modules failed to load:`n" + ($criticalModuleErrors -join "`n")
    $suggestions = @(
        "Check that all module files exist",
        "Verify there are no syntax errors in the modules",
        "Try restarting the application"
    )
    Show-AppErrorDialog -Message $errorMsg -Title "Module Load Error" -Suggestions $suggestions
    exit 1
}

Write-SilentLog "All critical modules loaded successfully." 'DEBUG'

# ============================================================
# Load Application Configuration
# ============================================================

# Load configuration (or use defaults)
$ConfigPath = Join-Path $ScriptRoot "config\settings.json"
LoadConfig -ConfigPath $ConfigPath

# Get configuration values from centralized config
$ProjectPath = Get-Config -Name "ProjectPath"
$GatewayPort = Get-Config -Name "GatewayPort"
$LogFile = Get-Config -Name "LogFilePath"

# ============================================================
# Application Functions
# ============================================================

# Application version
$script:AppVersion = "1.0.0"

# Fallback button function (used when MotionButton module fails to load)
function New-FlatButton {
    param(
        [string]$Text,
        [string]$Variant = "Primary",
        [string]$Size = "md"
    )
    
    $btn = New-Object System.Windows.Forms.Button
    
    # Size mapping
    $sizeMap = @{
        "sm" = @{ W = 70; H = 28 }
        "md" = @{ W = 100; H = 32 }
        "lg" = @{ W = 130; H = 40 }
    }
    
    $s = if ($sizeMap.ContainsKey($Size)) { $sizeMap[$Size] } else { $sizeMap["md"] }
    $btn.Size = New-Object System.Drawing.Size($s.W, $s.H)
    $btn.Text = $Text
    $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    
    # Variant colors
    switch ($Variant) {
        "Primary" {
            $btn.BackColor = $global:NordicTheme.AccentNormal
            $btn.ForeColor = $global:NordicTheme.TextOnAccent
        }
        "Secondary" {
            $btn.BackColor = $global:NordicTheme.BackgroundSecondary
            $btn.ForeColor = $global:NordicTheme.TextPrimary
        }
        "Ghost" {
            $btn.BackColor = [System.Drawing.Color]::Transparent
            $btn.ForeColor = $global:NordicTheme.TextSecondary
        }
        default {
            $btn.BackColor = $global:NordicTheme.AccentNormal
            $btn.ForeColor = $global:NordicTheme.TextOnAccent
        }
    }
    
    $btn.FlatAppearance.BorderSize = 0
    $btn.FlatAppearance.MouseOverBackColor = $global:NordicTheme.AccentHover
    
    return $btn
}

function Update-MainFormTitle {
    param([string]$Status = "Ready")

    try {
        $mainForm.Text = "Gateway Launcher v$script:AppVersion - $Status"
    }
    catch {
        Write-AppErrorLog -Message "Failed to update form title: $_" -Operation "Update-MainFormTitle"
    }
}

function Update-StatusBarConnectionCount {
    param([int]$Count = 0)

    try {
        if ($script:ConnectionStatusLabel) {
            $script:ConnectionStatusLabel.Text = "Connections: $Count"

            # Color based on count
            if ($Count -gt 100) {
                $script:ConnectionStatusLabel.ForeColor = $global:NordicTheme.StatusWarning
            } elseif ($Count -gt 0) {
                $script:ConnectionStatusLabel.ForeColor = $global:NordicTheme.StatusSuccess
            } else {
                $script:ConnectionStatusLabel.ForeColor = $global:NordicTheme.TextSecondary
            }
        }
    }
    catch {
        Write-AppErrorLog -Message "Failed to update connection count: $_" -Operation "Update-StatusBarConnectionCount"
    }
}

function Refresh-ConnectionCount {
    try {
        $connections = netstat -ano 2>$null | Select-String ":$GatewayPort" | Select-String "ESTABLISHED"
        $count = if ($connections) { $connections.Count } else { 0 }
        Update-StatusBarConnectionCount -Count $count

        # Also update dashboard
        if ($script:DashboardControls) {
            Update-ConnectionCount -Count $count -DashboardControls $script:DashboardControls
        }
    }
    catch {
        # Silently fail
    }
}

function Write-LogOutput {
    param([string]$Message)

    try {
        $time = Get-Date -Format "HH:mm:ss.fff"
        $fullMessage = "[$time] $Message"
        
        # Optimized text append with throttling for high-frequency logs
        # Check if we should skip scroll to improve performance
        $shouldScroll = $true
        
        # Skip scroll if we're logging a lot of messages rapidly
        if ($script:LastLogTime) {
            $timeSinceLastLog = ([DateTime]::Now - $script:LastLogTime).TotalMilliseconds
            if ($timeSinceLastLog -lt 100) {  # Less than 100ms since last log
                $shouldScroll = $false
            }
        }
        
        # Append text to output box
        $script:OutputTextBox.AppendText("$fullMessage`r`n")
        
        # Only scroll if needed (improves performance during rapid logging)
        if ($shouldScroll) {
            $script:OutputTextBox.ScrollToCaret()
        }
        
        # Update timestamp for throttling
        $script:LastLogTime = [DateTime]::Now
        
        # Also write to debug output for testing
        if ($env:DEBUG -eq "true") {
            Write-Host $fullMessage -ForegroundColor DarkGray
        }
    }
    catch {
        # Silently fail if logging fails - don't crash the app
        Write-AppErrorLog -Message "Failed to write log output: $_" -Operation "Write-LogOutput"
    }
}

function Stop-Gateway {
    try {
        Write-LogOutput "Stopping Gateway..."

        # Kill by primary port
        try {
            $conns = netstat -ano 2>$null | Select-String ":$GatewayPort" | Select-String "LISTENING"
            foreach ($c in $conns) {
                $id = ($c -split '\s+')[-1]
                if ($id -match '^\d+$' -and $id -ne $PID) {
                    taskkill /PID $id /F 2>$null | Out-Null
                    Write-LogOutput "Killed process $id"
                }
            }
        }
        catch {
            Write-LogOutput "Warning: Error checking port ${GatewayPort}: $_"
        }

        # Kill by secondary port
        try {
            $secondaryPort = $GatewayPort + 1
            $conns2 = netstat -ano 2>$null | Select-String ":$secondaryPort" | Select-String "LISTENING"
            foreach ($c in $conns2) {
                $id = ($c -split '\s+')[-1]
                if ($id -match '^\d+$' -and $id -ne $PID) {
                    taskkill /PID $id /F 2>$null | Out-Null
                }
            }
        }
        catch {
            Write-LogOutput "Warning: Error checking secondary port: $_"
        }

        Write-LogOutput "Gateway stopped"

        try {
            if ($script:DashboardControls) {
                Update-GatewayStatus -Status "Stopped" -DashboardControls $script:DashboardControls
            }
            # Update form title
            Update-MainFormTitle -Status "Stopped"
            # Update status bar
            $script:StatusLabel.Text = "Stopped"
            $script:GatewayStatusLabel.Text = "Stopped"
        }
        catch {
            Write-AppErrorLog -Message "Failed to update dashboard status: $_" -Operation "Stop-Gateway"
        }
    }
    catch {
        Write-AppErrorLog -Message "Error stopping gateway: $_" -Operation "Stop-Gateway"
        Write-LogOutput "Error stopping gateway: $_"
    }
}

function Start-Foreground {
    try {
        Stop-Gateway
        Start-Sleep -Milliseconds 500

        if (-not (Test-Path $ProjectPath)) {
            Write-LogOutput "ERROR: Path not found - $ProjectPath"
            Write-AppErrorLog -Message "Project path not found: $ProjectPath" -Operation "Start-Foreground"
            $suggestions = @(
                "Check the project path in Settings",
                "Verify the OpenClaw project exists at the specified location",
                "Update the project path in Settings if needed"
            )
            Show-AppErrorDialog -Message "Project path not found: $ProjectPath" -Title "Path Error" -Suggestions $suggestions
            return
        }

        Write-LogOutput "Starting Gateway (foreground)..."
        
        # 使用智能端口冲突解决
        $portRef = [ref]$GatewayPort
        $portCheck = Start-GatewaySmart -StartMethod "Foreground" -GatewayPort $portRef -ProjectPath $ProjectPath -ConfigPath $ConfigPath
        
        if (-not $portCheck.Success) {
            Write-LogOutput "ERROR: 端口检查失败，无法启动网关"
            return
        }
        
        if ($portCheck.WasChanged) {
            Write-LogOutput "端口 $($portCheck.OriginalPort) 被占用，已自动切换到端口 $($portCheck.Port)"
            # 更新全局变量中的端口值
            $global:GatewayPort = $portCheck.Port
        }
        
        Write-LogOutput "运行在新窗口中..."

        try {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "cmd.exe"
            $psi.Arguments = "/k cd /d `"$ProjectPath`" && pnpm openclaw gateway run --port $($portCheck.Port) --verbose"
            $psi.WindowStyle = "Normal"

            [System.Diagnostics.Process]::Start($psi) | Out-Null
            Write-LogOutput "网关已启动，端口: $($portCheck.Port)"
        }
        catch {
            Write-LogOutput "ERROR: 启动网关进程失败: $_"
            Write-AppErrorLog -Message "启动网关失败: $_" -Operation "Start-Foreground"
            Show-AppErrorDialog -Message "启动网关失败: $_`n`n请确保 pnpm 已安装并且在 PATH 中。" -Title "启动错误"
            return
        }

        try {
            if ($script:DashboardControls) {
                Update-GatewayStatus -Status "Running" -DashboardControls $script:DashboardControls
            }
            # 更新窗体标题
            Update-MainFormTitle -Status "Running"
            # 更新状态栏
            $script:StatusLabel.Text = "Running"
            $script:GatewayStatusLabel.Text = "Running"
        }
        catch {
            Write-AppErrorLog -Message "更新仪表盘失败: $_" -Operation "Start-Foreground"
        }
    }
    catch {
        Write-AppErrorLog -Message "在前台启动网关时出错: $_" -Operation "Start-Foreground"
        Write-LogOutput "错误: $_"
    }
}

function Start-Background {
    try {
        Stop-Gateway
        Start-Sleep -Milliseconds 500

        if (-not (Test-Path $ProjectPath)) {
            Write-LogOutput "ERROR: 路径未找到 - $ProjectPath"
            Write-AppErrorLog -Message "项目路径未找到: $ProjectPath" -Operation "Start-Background"
            $suggestions = @(
                "检查设置中的项目路径",
                "确认指定的位置存在 OpenClaw 项目",
                "如有需要，在设置中更新项目路径"
            )
            Show-AppErrorDialog -Message "项目路径未找到: $ProjectPath" -Title "路径错误" -Suggestions $suggestions
            return
        }

        Write-LogOutput "启动网关 (后台)..."
        
        # 使用智能端口冲突解决
        $portRef = [ref]$GatewayPort
        $portCheck = Start-GatewaySmart -StartMethod "Background" -GatewayPort $portRef -ProjectPath $ProjectPath -ConfigPath $ConfigPath
        
        if (-not $portCheck.Success) {
            Write-LogOutput "ERROR: 端口检查失败，无法启动网关"
            return
        }
        
        if ($portCheck.WasChanged) {
            Write-LogOutput "端口 $($portCheck.OriginalPort) 被占用，已自动切换到端口 $($portCheck.Port)"
            # 更新全局变量中的端口值
            $global:GatewayPort = $portCheck.Port
        }

        try {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "cmd.exe"
            $psi.Arguments = "/c cd /d `"$ProjectPath`" && pnpm openclaw gateway run --port $($portCheck.Port) --verbose > `"$LogFile`" 2>&1"
            $psi.WindowStyle = "Hidden"
            $psi.CreateNoWindow = $true

            [System.Diagnostics.Process]::Start($psi) | Out-Null
            Start-Sleep -Seconds 2
            Write-LogOutput "网关已启动，端口: $($portCheck.Port)。日志: $LogFile"
        }
        catch {
            Write-LogOutput "ERROR: 启动网关进程失败: $_"
            Write-AppErrorLog -Message "启动网关失败: $_" -Operation "Start-Background"
            Show-AppErrorDialog -Message "启动网关失败: $_`n`n请确保 pnpm 已安装并且在 PATH 中。" -Title "启动错误"
            return
        }

        try {
            if ($script:DashboardControls) {
                Update-GatewayStatus -Status "Running" -DashboardControls $script:DashboardControls
            }
            # 更新窗体标题
            Update-MainFormTitle -Status "Running"
            # 更新状态栏
            $script:StatusLabel.Text = "Running"
            $script:GatewayStatusLabel.Text = "Running"
        }
        catch {
            Write-AppErrorLog -Message "更新仪表盘失败: $_" -Operation "Start-Background"
        }
    }
    catch {
        Write-AppErrorLog -Message "在后台启动网关时出错: $_" -Operation "Start-Background"
        Write-LogOutput "错误: $_"
    }
}

function Check-Status {
    try {
        Write-LogOutput "=== 网关状态 ==="

        try {
            $conns = netstat -ano 2>$null | Select-String ":$GatewayPort" | Select-String "LISTENING"
            if ($conns) {
                Write-LogOutput "端口 ${GatewayPort}: 占用中"
                $conns | ForEach-Object { Write-LogOutput ($_ -replace '^\s+', '') }
            } else {
                Write-LogOutput "端口 ${GatewayPort}: 空闲"
            }
        }
        catch {
            Write-LogOutput "警告: 无法检查端口状态: $_"
        }

        if (Test-Path $LogFile) {
            Write-LogOutput "日志文件存在"
        } else {
            Write-LogOutput "尚无日志文件"
        }
    }
    catch {
        Write-AppErrorLog -Message "检查状态时出错: $_" -Operation "Check-Status"
        Write-LogOutput "检查状态时出错: $_"
    }
}

function View-Logs {
    try {
        if (-not (Test-Path $LogFile)) {
            Write-LogOutput "无日志文件。请先启动网关。"
            return
        }

        Write-LogOutput "=== 最后20行日志 ==="
        try {
            Get-Content $LogFile -Tail 20 -Encoding UTF8 | ForEach-Object { Write-LogOutput $_ }
        }
        catch {
            Write-LogOutput "读取日志文件错误: $_"
            Write-AppErrorLog -Message "读取日志文件失败: $_" -Operation "View-Logs"
        }
    }
    catch {
        Write-AppErrorLog -Message "查看日志时出错: $_" -Operation "View-Logs"
        Write-LogOutput "错误: $_"
    }
}

function Clean-Ports {
    Write-LogOutput "强制清理所有端口..."
    Stop-Gateway
    Write-LogOutput "完成"
}

# ============================================================
# Main Application Form
# ============================================================

# Create main form
$mainForm = New-Object System.Windows.Forms.Form
$mainForm.Text = "Gateway Launcher v1.0.0 - Ready"
$mainForm.Size = New-Object System.Drawing.Size(900, 600)
$mainForm.StartPosition = "CenterScreen"
$mainForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
$mainForm.MaximizeBox = $true
$mainForm.MinimizeBox = $true
$mainForm.MinimumSize = New-Object System.Drawing.Size(800, 500)
$mainForm.AutoSize = $false
$mainForm.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowOnly
$mainForm.AutoScroll = $false
$mainForm.SizeGripStyle = [System.Windows.Forms.SizeGripStyle]::Show

# Debug log for form creation
Write-LogOutput "[FORM] Form created with Sizable border style and SizeGripStyle.Show"

# Enable keyboard event handling
$mainForm.KeyPreview = $true

# Apply Nordic theme to form
Apply-NordicTheme -Form $mainForm

# CRITICAL: Force window style settings (may be overridden by PS2EXE)
# These must be set AFTER theme application to ensure they stick
$mainForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
$mainForm.MaximizeBox = $true
$mainForm.MinimizeBox = $true
$mainForm.SizeGripStyle = [System.Windows.Forms.SizeGripStyle]::Show
Write-LogOutput "[FORM] Force-set window styles: Sizable, MaximizeBox=true, MinimizeBox=true"

# ============================================================
# Create UI Layout
# ============================================================

# Create main container panel
$mainPanel = New-Object System.Windows.Forms.Panel
$mainPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
$mainPanel.BackColor = $global:NordicTheme.BackgroundPrimary
$mainForm.Controls.Add($mainPanel)

# ============================================================
# Header Section
# ============================================================

$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Location = New-Object System.Drawing.Point(0, 0)
$headerPanel.Size = New-Object System.Drawing.Size(880, 50)
$headerPanel.BackColor = $global:NordicTheme.BackgroundSecondary
$headerPanel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$mainPanel.Controls.Add($headerPanel)

# Title Label
$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Gateway Launcher"
$titleLabel.Location = New-Object System.Drawing.Point(15, 12)
$titleLabel.AutoSize = $true
$titleLabel.Font = New-Object System.Drawing.Font($global:NordicTheme.FontDefault, 16, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = $global:NordicTheme.TextPrimary
$headerPanel.Controls.Add($titleLabel)

# Version Label
$versionLabel = New-Object System.Windows.Forms.Label
$versionLabel.Text = "v$script:AppVersion"
$versionLabel.Location = New-Object System.Drawing.Point(180, 18)
$versionLabel.AutoSize = $true
$versionLabel.Font = New-Object System.Drawing.Font($global:NordicTheme.FontDefault, 9)
$versionLabel.ForeColor = $global:NordicTheme.TextTertiary
$headerPanel.Controls.Add($versionLabel)

# ============================================================
# Button Bar
# ============================================================

$buttonBar = New-Object System.Windows.Forms.Panel
$buttonBar.Location = New-Object System.Drawing.Point(15, 60)
$buttonBar.Size = New-Object System.Drawing.Size(860, 45)
$buttonBar.BackColor = $global:NordicTheme.BackgroundPrimary
$buttonBar.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$mainPanel.Controls.Add($buttonBar)

# Start Foreground Button (with fallback)
try {
    $btnStartFg = New-MotionButton -Text "Start (Foreground)" -Variant Primary -Size md -ShowRipple $true -ShowHover $true -ShowTap $true -ErrorAction Stop
} catch {
    $btnStartFg = New-FlatButton -Text "Start (Foreground)" -Variant Primary -Size md
}
$btnStartFg.Location = New-Object System.Drawing.Point(0, 5)
$btnStartFg.Size = New-Object System.Drawing.Size(130, 35)
$btnStartFg.Add_Click({ Start-Foreground })
$buttonBar.Controls.Add($btnStartFg)

# Start Background Button (with fallback)
try {
    $btnStartBg = New-MotionButton -Text "Start (Background)" -Variant Primary -Size md -ShowRipple $true -ShowHover $true -ShowTap $true -ErrorAction Stop
} catch {
    $btnStartBg = New-FlatButton -Text "Start (Background)" -Variant Primary -Size md
}
$btnStartBg.Location = New-Object System.Drawing.Point(140, 5)
$btnStartBg.Size = New-Object System.Drawing.Size(130, 35)
$btnStartBg.Add_Click({ Start-Background })
$buttonBar.Controls.Add($btnStartBg)

# Stop Button (with fallback)
try {
    $btnStop = New-MotionButton -Text "Stop" -Variant Secondary -Size md -ShowRipple $true -ShowHover $true -ShowTap $true -ErrorAction Stop
} catch {
    $btnStop = New-FlatButton -Text "Stop" -Variant Secondary -Size md
}
$btnStop.Location = New-Object System.Drawing.Point(280, 5)
$btnStop.Size = New-Object System.Drawing.Size(100, 35)
$btnStop.Add_Click({ Stop-Gateway })
$buttonBar.Controls.Add($btnStop)

# Separator panels for button grouping
$separator1 = New-Object System.Windows.Forms.Panel
$separator1.Location = New-Object System.Drawing.Point(390, 8)
$separator1.Size = New-Object System.Drawing.Size(1, 30)
$separator1.BackColor = $global:NordicTheme.BorderStrong
$buttonBar.Controls.Add($separator1)

# Status Button (with fallback)
try {
    $btnStatus = New-MotionButton -Text "Status" -Variant Ghost -Size md -ShowRipple $true -ShowHover $true -ShowTap $true -ErrorAction Stop
} catch {
    $btnStatus = New-FlatButton -Text "Status" -Variant Ghost -Size md
}
$btnStatus.Location = New-Object System.Drawing.Point(400, 5)
$btnStatus.Size = New-Object System.Drawing.Size(90, 35)
$btnStatus.Add_Click({ Check-Status })
$buttonBar.Controls.Add($btnStatus)

# Logs Button (with fallback)
try {
    $btnLogs = New-MotionButton -Text "Logs" -Variant Ghost -Size md -ShowRipple $true -ShowHover $true -ShowTap $true -ErrorAction Stop
} catch {
    $btnLogs = New-FlatButton -Text "Logs" -Variant Ghost -Size md
}
$btnLogs.Location = New-Object System.Drawing.Point(500, 5)
$btnLogs.Size = New-Object System.Drawing.Size(90, 35)
$btnLogs.Add_Click({ View-Logs })
$buttonBar.Controls.Add($btnLogs)

# Clean Button (with fallback)
try {
    $btnClean = New-MotionButton -Text "Clean Ports" -Variant Ghost -Size md -ShowRipple $true -ShowHover $true -ShowTap $true -ErrorAction Stop
} catch {
    $btnClean = New-FlatButton -Text "Clean Ports" -Variant Ghost -Size md
}
$btnClean.Location = New-Object System.Drawing.Point(600, 5)
$btnClean.Size = New-Object System.Drawing.Size(100, 35)
$btnClean.Add_Click({ Clean-Ports })
$buttonBar.Controls.Add($btnClean)

# Clear Button (with fallback)
try {
    $btnClear = New-MotionButton -Text "Clear" -Variant Ghost -Size md -ShowRipple $true -ShowHover $true -ShowTap $true -ErrorAction Stop
} catch {
    $btnClear = New-FlatButton -Text "Clear" -Variant Ghost -Size md
}
$btnClear.Location = New-Object System.Drawing.Point(710, 5)
$btnClear.Size = New-Object System.Drawing.Size(80, 35)
$btnClear.Add_Click({ $script:OutputTextBox.Clear() })
$buttonBar.Controls.Add($btnClear)

# ============================================================
# Dashboard and Output Panels (Side by Side)
# ============================================================

$contentPanel = New-Object System.Windows.Forms.Panel
$contentPanel.Location = New-Object System.Drawing.Point(15, 115)
$contentPanel.Size = New-Object System.Drawing.Size(860, 480)
$contentPanel.BackColor = $global:NordicTheme.BackgroundPrimary
$contentPanel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$mainPanel.Controls.Add($contentPanel)

# ============================================================
# Dashboard Section (Left Side)
# ============================================================

$dashboardContainer = New-Object System.Windows.Forms.Panel
$dashboardContainer.Location = New-Object System.Drawing.Point(0, 0)
$dashboardContainer.Size = New-Object System.Drawing.Size(250, 470)
$dashboardContainer.BackColor = $global:NordicTheme.BackgroundSecondary
$contentPanel.Controls.Add($dashboardContainer)

# Dashboard Header
$dashboardHeader = New-Object System.Windows.Forms.Label
$dashboardHeader.Text = "Dashboard"
$dashboardHeader.Location = New-Object System.Drawing.Point(10, 10)
$dashboardHeader.AutoSize = $true
$dashboardHeader.Font = New-Object System.Drawing.Font($global:NordicTheme.FontDefault, 12, [System.Drawing.FontStyle]::Bold)
$dashboardHeader.ForeColor = $global:NordicTheme.TextPrimary
$dashboardContainer.Controls.Add($dashboardHeader)

# Initialize Dashboard
try {
    $script:DashboardControls = Initialize-Dashboard -ParentControl $dashboardContainer
    Write-SilentLog "Dashboard initialized: $($null -ne $script:DashboardControls)" 'DEBUG'
} catch {
    Write-SilentLog "Dashboard initialization failed: $_" 'ERROR'
    $script:DashboardControls = $null
}

# Update dashboard with initial values (only if controls is a valid hashtable)
if ($script:DashboardControls -and $script:DashboardControls -is [hashtable]) {
    try {
        Update-GatewayStatus -Status "Ready" -DashboardControls $script:DashboardControls
        Update-ConnectionCount -Count 0 -DashboardControls $script:DashboardControls
    } catch {
        Write-SilentLog "Failed to update dashboard: $_" 'WARN'
    }
} else {
    Write-SilentLog "Dashboard controls not available or invalid type" 'WARN'
}
# Dashboard will automatically update metrics via timer

# ============================================================
# Output/Log Section (Right Side)
# ============================================================

$outputContainer = New-Object System.Windows.Forms.Panel
$outputContainer.Location = New-Object System.Drawing.Point(260, 0)
$outputContainer.Size = New-Object System.Drawing.Size(600, 470)
$outputContainer.BackColor = $global:NordicTheme.BackgroundPrimary
$contentPanel.Controls.Add($outputContainer)

# Output Header
$outputHeader = New-Object System.Windows.Forms.Label
$outputHeader.Text = "Output"
$outputHeader.Location = New-Object System.Drawing.Point(10, 10)
$outputHeader.AutoSize = $true
$outputHeader.Font = New-Object System.Drawing.Font($global:NordicTheme.FontDefault, 12, [System.Drawing.FontStyle]::Bold)
$outputHeader.ForeColor = $global:NordicTheme.TextPrimary
$outputContainer.Controls.Add($outputHeader)

# Output TextBox
$script:OutputTextBox = New-Object System.Windows.Forms.TextBox
$script:OutputTextBox.Location = New-Object System.Drawing.Point(10, 35)
$script:OutputTextBox.Size = New-Object System.Drawing.Size(580, 395)
$script:OutputTextBox.Multiline = $true
$script:OutputTextBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$script:OutputTextBox.ReadOnly = $true
$script:OutputTextBox.Font = New-Object System.Drawing.Font($global:NordicTheme.FontCode, 9)
$script:OutputTextBox.BackColor = $global:NordicTheme.BackgroundSecondary
$script:OutputTextBox.ForeColor = $global:NordicTheme.TextPrimary
$script:OutputTextBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$script:OutputTextBox.Padding = New-Object System.Windows.Forms.Padding(5)
$outputContainer.Controls.Add($script:OutputTextBox)

# ============================================================
# Status Bar
# ============================================================

$statusBar = New-Object System.Windows.Forms.StatusStrip
$statusBar.BackColor = $global:NordicTheme.BackgroundSecondary
$statusBar.ForeColor = $global:NordicTheme.TextSecondary
$mainForm.Controls.Add($statusBar)

# Gateway Status (Running/Stopped)
$script:GatewayStatusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$script:GatewayStatusLabel.Text = "Ready"
$script:GatewayStatusLabel.ForeColor = $global:NordicTheme.StatusSuccess
$script:GatewayStatusLabel.Font = New-Object System.Drawing.Font($global:NordicTheme.FontDefault, 9, [System.Drawing.FontStyle]::Bold)
$statusBar.Items.Add($script:GatewayStatusLabel)

# Separator
$separator1 = New-Object System.Windows.Forms.ToolStripStatusLabel
$separator1.Text = " | "
$separator1.ForeColor = $global:NordicTheme.TextTertiary
$statusBar.Items.Add($separator1)

# Connection count
$script:ConnectionStatusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$script:ConnectionStatusLabel.Text = "Connections: 0"
$script:ConnectionStatusLabel.ForeColor = $global:NordicTheme.TextSecondary
$statusBar.Items.Add($script:ConnectionStatusLabel)

# Separator
$separator2 = New-Object System.Windows.Forms.ToolStripStatusLabel
$separator2.Text = " | "
$separator2.ForeColor = $global:NordicTheme.TextTertiary
$statusBar.Items.Add($separator2)

# Port info
$script:StatusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$script:StatusLabel.Text = "Port: $GatewayPort"
$script:StatusLabel.ForeColor = $global:NordicTheme.TextTertiary
$statusBar.Items.Add($script:StatusLabel)

# Separator
$separator3 = New-Object System.Windows.Forms.ToolStripStatusLabel
$separator3.Text = " | "
$separator3.ForeColor = $global:NordicTheme.TextTertiary
$statusBar.Items.Add($separator3)

# Project path (truncated)
$projectName = Split-Path $ProjectPath -Leaf
if ([string]::IsNullOrEmpty($projectName)) {
    $projectName = "Not set"
}
$portLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$portLabel.Text = "Project: $projectName"
$portLabel.ForeColor = $global:NordicTheme.TextTertiary
$statusBar.Items.Add($portLabel)

# ============================================================
# System Tray Setup
# ============================================================

# Initialize tray icon
Initialize-TrayIcon -Name "GatewayLauncher" -ToolTip "Gateway Launcher" -OnDoubleClick {
    $mainForm.Show()
    $mainForm.WindowState = [System.Windows.Forms.FormWindowState]::Normal
    $mainForm.Activate()
}

# Add tray menu items
Add-TrayMenuItem -TrayIconName "GatewayLauncher" -Text "Show Window" -Action {
    $mainForm.Show()
    $mainForm.WindowState = [System.Windows.Forms.FormWindowState]::Normal
    $mainForm.Activate()
}

Add-TrayMenuItem -TrayIconName "GatewayLauncher" -Text "Start Gateway" -Action {
    Start-Background
}

Add-TrayMenuItem -TrayIconName "GatewayLauncher" -Text "Stop Gateway" -Action {
    Stop-Gateway
}

Add-TrayMenuItem -TrayIconName "GatewayLauncher" -Separator

Add-TrayMenuItem -TrayIconName "GatewayLauncher" -Text "Exit" -Action {
    Stop-Gateway
    Remove-TrayIcon -Name "GatewayLauncher"
    [System.Windows.Forms.Application]::Exit()
}

# ============================================================
# Connection Count Timer (refresh every 5 seconds)
# ============================================================

$connectionTimer = New-Object System.Windows.Forms.Timer
$connectionTimer.Interval = 5000
$connectionTimer.Add_Tick({
    Refresh-ConnectionCount
})
$connectionTimer.Start()

# ============================================================
# Window Size Monitor Timer (optimized for performance)
# ============================================================

# Initialize last known size for comparison
$script:LastWindowWidth = $mainForm.Width
$script:LastWindowHeight = $mainForm.Height

# Only enable size monitoring if debugging is needed
$sizeMonitorTimer = New-Object System.Windows.Forms.Timer
$sizeMonitorTimer.Interval = 1000  # 1000ms (1 second) for better performance
$sizeMonitorTimer.Add_Tick({
    $currentWidth = $mainForm.Width
    $currentHeight = $mainForm.Height
    
    # Only log if size has changed significantly (more than 5 pixels)
    if ([math]::Abs($currentWidth - $script:LastWindowWidth) -gt 5 -or 
        [math]::Abs($currentHeight - $script:LastWindowHeight) -gt 5) {
        # Only log in debug mode or when needed
        if ($env:DEBUG -eq "true") {
            Write-LogOutput "[DEBUG] Window size changed: ${currentWidth}×${currentHeight}"
        }
        $script:LastWindowWidth = $currentWidth
        $script:LastWindowHeight = $currentHeight
    }
})

# Start timer only if debugging is enabled
if ($env:DEBUG -eq "true") {
    $sizeMonitorTimer.Start()
    Write-LogOutput "[DEBUG] Window size monitoring enabled"
}

# ============================================================
# Optimized UI Resize Handler Function
# ============================================================

# Variables for debouncing and performance optimization
$script:ResizeTimer = $null
$script:LastResizeTime = [DateTime]::MinValue
$script:ResizePending = $false
$script:MinResizeInterval = 50  # Minimum 50ms between resize updates

function Update-UIForResize {
    param()
    
    try {
        # Skip if update is too frequent (debouncing)
        $now = [DateTime]::Now
        $timeSinceLastUpdate = ($now - $script:LastResizeTime).TotalMilliseconds
        
        if ($timeSinceLastUpdate -lt $script:MinResizeInterval) {
            # Mark that a resize is pending
            $script:ResizePending = $true
            
            # Debug logging only when enabled
            if ($env:DEBUG -eq "true") {
                Write-LogOutput "[PERF] Resize throttled: $($timeSinceLastUpdate)ms since last update"
            }
            
            # Schedule another check if not already scheduled
            if (-not $script:ResizeTimer) {
                $script:ResizeTimer = New-Object System.Windows.Forms.Timer
                $script:ResizeTimer.Interval = $script:MinResizeInterval
                $script:ResizeTimer.Add_Tick({
                    if ($script:ResizePending) {
                        $script:ResizeTimer.Stop()
                        $script:ResizePending = $false
                        Update-UIForResize
                    }
                })
                $script:ResizeTimer.Start()
            }
            return
        }
        
        # Update last resize time
        $script:LastResizeTime = $now
        $script:ResizePending = $false
        
        # Debug logging only when enabled
        if ($env:DEBUG -eq "true") {
            Write-LogOutput "[PERF] Updating UI layout"
        }
        
        # Get current form dimensions
        $formWidth = $mainForm.Width
        $formHeight = $mainForm.Height
        
        # Update only essential UI elements
        $headerPanel.Width = $formWidth
        
        # Button bar
        $buttonBar.Location = New-Object System.Drawing.Point(15, 60)
        $buttonBar.Width = $formWidth - 30
        
        # Content panel
        $contentPanel.Location = New-Object System.Drawing.Point(15, 115)
        $contentPanel.Width = $formWidth - 30
        $contentPanel.Height = $formHeight - 165
        
        # Dashboard and output containers
        $dashboardHeight = $contentPanel.Height
        $dashboardContainer.Height = $dashboardHeight
        
        $outputContainer.Location = New-Object System.Drawing.Point(260, 0)
        $outputContainer.Width = $contentPanel.Width - 270
        $outputContainer.Height = $dashboardHeight
        
        # Output textbox
        $script:OutputTextBox.Width = $outputContainer.Width - 20
        $script:OutputTextBox.Height = $outputContainer.Height - 45
        
        # Minimal UI refresh - avoid DoEvents and full Refresh
        $mainForm.SuspendLayout()
        try {
            # Only update controls that actually changed
            $headerPanel.PerformLayout()
            $buttonBar.PerformLayout()
            $contentPanel.PerformLayout()
            $dashboardContainer.PerformLayout()
            $outputContainer.PerformLayout()
        }
        finally {
            $mainForm.ResumeLayout($false)
        }
        
        # Debug logging only when enabled
        if ($env:DEBUG -eq "true") {
            Write-LogOutput "[PERF] UI updated: ${formWidth}×${formHeight}"
        }
    }
    catch {
        # Silent error handling - don't flood logs
        if ($env:DEBUG -eq "true") {
            Write-AppErrorLog -Message "Error in UI resize handler: $_" -Operation "Update-UIForResize"
            Write-LogOutput "[ERROR] UI resize handler error: $_"
        }
    }
}

# Add optimized resize event handlers with debouncing
$mainForm.Add_Resize({
    # Minimal logging
    if ($env:DEBUG -eq "true") {
        Write-LogOutput "[EVENT] Resize event"
    }
    Update-UIForResize
})

$mainForm.Add_SizeChanged({
    # SizeChanged event is redundant with Resize for our needs
    # We'll handle it but with minimal processing
    if ($env:DEBUG -eq "true") {
        Write-LogOutput "[EVENT] SizeChanged event"
    }
})

# ============================================================
# Form Event Handlers
# ============================================================

# Keyboard shortcuts handler
$mainForm.Add_KeyDown({
    param($sender, $e)

    # Check for modifier keys
    $ctrlPressed = $e.Control

    if ($ctrlPressed) {
        switch ($e.KeyCode) {
            # Ctrl+S - Start gateway (background)
            'S' {
                Start-Background
                $e.Handled = $true
            }
            # Ctrl+X - Stop gateway
            'X' {
                Stop-Gateway
                $e.Handled = $true
            }
            # Ctrl+R - Refresh status
            'R' {
                Check-Status
                $e.Handled = $true
            }
            # Ctrl+L - View logs
            'L' {
                View-Logs
                $e.Handled = $true
            }
            # Ctrl+Comma - Settings
            'OemComma' {
                try {
                    Show-SettingsDialog -ParentForm $mainForm
                }
                catch {
                    Write-LogOutput "Error opening settings: $_"
                }
                $e.Handled = $true
            }
        }
    }
    else {
        # Escape - Minimize to tray
        if ($e.KeyCode -eq 'Escape') {
            $mainForm.Hide()
            Show-TrayBalloon -Name "GatewayLauncher" -Title "Gateway Launcher" -Message "Application minimized to system tray" -Type Info
            $e.Handled = $true
        }
    }
})

# Mouse events handler for debugging scaling issues
$mainForm.Add_MouseDown({
    param($sender, $e)
    Write-LogOutput "[MOUSE] Mouse down at position X:$($e.X), Y:$($e.Y) Button:$($e.Button)"
})

$mainForm.Add_MouseMove({
    param($sender, $e)
    # Check if mouse is in bottom-right resize area (within 15 pixels of bottom-right corner)
    $resizeAreaSize = 15
    
    # Get client size values first to avoid parser issues
    $clientW = $mainForm.ClientSize.Width
    $clientH = $mainForm.ClientSize.Height
    $thresholdX = $clientW - $resizeAreaSize
    $thresholdY = $clientH - $resizeAreaSize
    
    # Check if in resize area
    $isInResizeArea = ($e.X -ge $thresholdX) -and ($e.Y -ge $thresholdY)
    
    if ($isInResizeArea) {
        Write-LogOutput "[RESIZE-AREA] Mouse in bottom-right resize area at X:$($e.X), Y:$($e.Y)"
        # Change cursor to resize cursor when in resize area
        $mainForm.Cursor = [System.Windows.Forms.Cursors]::SizeNWSE
    } else {
        # Restore default cursor when not in resize area
        $mainForm.Cursor = [System.Windows.Forms.Cursors]::Default
    }
    
    if ($e.Button -ne [System.Windows.Forms.MouseButtons]::None) {
        Write-LogOutput "[MOUSE] Mouse move while button pressed at X:$($e.X), Y:$($e.Y) Button:$($e.Button)"
    }
})

$mainForm.Add_MouseUp({
    param($sender, $e)
    Write-LogOutput "[MOUSE] Mouse up at position X:$($e.X), Y:$($e.Y) Button:$($e.Button)"
})

# Window state change events
$mainForm.Add_Activated({
    Write-LogOutput "[WINDOW] Form activated"
})

$mainForm.Add_Deactivate({
    Write-LogOutput "[WINDOW] Form deactivated"
})

# Window state change event - commented out due to PowerShell compatibility issues
# $mainForm.add_StateChanged({
#     Write-LogOutput "[WINDOW] Window state changed to: $($mainForm.WindowState)"
# })

# Minimize to tray on close
$mainForm.Add_FormClosing({
    if ($_.CloseReason -eq [System.Windows.Forms.CloseReason]::UserClosing) {
        $_.Cancel = $true
        $mainForm.Hide()
        Show-TrayBalloon -Name "GatewayLauncher" -Title "Gateway Launcher" -Message "Application minimized to system tray" -Type Info
    }
})

# ============================================================
# Global Error Handler Setup
# ============================================================

# Set up global error handler for unhandled exceptions
try {
    $global:ErrorActionPreference = 'Stop'

    # Register unhandled exception handler
    Register-EngineEvent -SourceIdentifier 'PowerShell.UnhandledException' -Action {
        param($sender, $event)
        $errorMsg = $event.ExceptionObject
        Write-AppErrorLog -Message "Unhandled exception: $errorMsg" -Operation "UnhandledException"
    }
}
catch {
    Write-SilentLog "Could not set up global error handler: $_" 'DEBUG'
}

# ============================================================
# Initial Output
# ============================================================

Write-LogOutput "========================================="
Write-LogOutput "Gateway Launcher v1.0.0"
Write-LogOutput "========================================="
Write-LogOutput "Project Path: $ProjectPath"
Write-LogOutput "Gateway Port: $GatewayPort"
Write-LogOutput "Log File: $LogFile"
Write-LogOutput "========================================="

# Check for common issues at startup
try {
    if (-not (Test-Path $ProjectPath)) {
        Write-LogOutput "WARNING: Project path not found: $ProjectPath"
        Write-LogOutput "Please configure the correct path in Settings."
    }

    # Check if port is in use
    $portInUse = netstat -ano 2>$null | Select-String ":$GatewayPort" | Select-String "LISTENING"
    if ($portInUse) {
        Write-LogOutput "WARNING: Port $GatewayPort is already in use"
        Write-LogOutput "智能端口冲突解决功能已启用 - 启动时将自动切换到可用端口"
    }
}
catch {
    # Ignore errors during startup checks
}

Write-LogOutput "Ready to start gateway..."
Write-LogOutput ""
Write-LogOutput "Keyboard Shortcuts:"
Write-LogOutput "  Ctrl+S  - Start Gateway"
Write-LogOutput "  Ctrl+X  - Stop Gateway"
Write-LogOutput "  Ctrl+R  - Refresh Status"
Write-LogOutput "  Ctrl+L  - View Logs"
Write-LogOutput "  Ctrl+,  - Settings"
Write-LogOutput "  Esc     - Minimize to Tray"

# ============================================================
# Run Application
# ============================================================

try {
    [void]$mainForm.ShowDialog()
}
catch {
    Write-AppErrorLog -Message "Application error: $_" -Operation "ApplicationRun"
    Show-AppErrorDialog -Message "An unexpected error occurred: $_`n`nThe error has been logged to the error log file." -Title "Application Error"
}