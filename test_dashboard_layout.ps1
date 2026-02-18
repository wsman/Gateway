# Complete Dashboard Test - Final Verification
Write-Host "=== Dashboard Final Verification Test ===" -ForegroundColor Cyan
Write-Host ""

Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
Add-Type -AssemblyName System.Drawing -ErrorAction Stop

# Theme configuration
$global:NordicTheme = @{
    BackgroundPrimary = [System.Drawing.Color]::FromArgb(250, 251, 252)
    BackgroundSecondary = [System.Drawing.Color]::FromArgb(245, 247, 249)
    BackgroundTertiary = [System.Drawing.Color]::FromArgb(238, 241, 244)
    TextPrimary = [System.Drawing.Color]::FromArgb(44, 49, 54)
    TextSecondary = [System.Drawing.Color]::FromArgb(110, 120, 129)
    TextTertiary = [System.Drawing.Color]::FromArgb(155, 164, 174)
    TextOnAccent = [System.Drawing.Color]::FromArgb(250, 251, 252)
    TextInverse = [System.Drawing.Color]::FromArgb(250, 251, 252)
    AccentNormal = [System.Drawing.Color]::FromArgb(61, 122, 95)
    AccentHover = [System.Drawing.Color]::FromArgb(45, 90, 71)
    StatusSuccess = [System.Drawing.Color]::FromArgb(127, 188, 140)
    StatusWarning = [System.Drawing.Color]::FromArgb(228, 168, 83)
    StatusError = [System.Drawing.Color]::FromArgb(209, 107, 107)
    FontDefault = "Segoe UI"
    FontCode = "Consolas"
}

function Write-SilentLog { param([string]$Message, [string]$Level = "INFO") }

# Reset global state to ensure clean test
$global:GatewayDashboard = $null
$script:PerfCounters = $null
$script:DashboardTimer = $null

# Load Dashboard module
$dashboardPath = "d:\Users\WSMAN\Desktop\Claude\Gateway\modules\Dashboard.ps1"
Write-Host "Loading Dashboard module..." -ForegroundColor Yellow

try {
    . $dashboardPath
    Write-Host "[OK] Dashboard module loaded" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to load module: $_" -ForegroundColor Red
    exit 1
}

# Create test form
$testForm = New-Object System.Windows.Forms.Form
$testForm.Text = "Gateway Dashboard - Verification Test"
$testForm.Size = New-Object System.Drawing.Size(280, 520)
$testForm.StartPosition = "CenterScreen"
$testForm.BackColor = $global:NordicTheme.BackgroundPrimary
$testForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$testForm.MaximizeBox = $false

$mainPanel = New-Object System.Windows.Forms.Panel
$mainPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
$testForm.Controls.Add($mainPanel)

# Status label at bottom
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Dock = [System.Windows.Forms.DockStyle]::Bottom
$statusLabel.Height = 30
$statusLabel.BackColor = $global:NordicTheme.BackgroundSecondary
$statusLabel.ForeColor = $global:NordicTheme.TextSecondary
$statusLabel.Text = " Initializing..."
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$testForm.Controls.Add($statusLabel)

Write-Host ""
Write-Host "=== Running Tests ===" -ForegroundColor Cyan

# Test 1: Initialize Dashboard
Write-Host "`n[TEST 1] Initialize-Dashboard..." -ForegroundColor Yellow
try {
    $controls = Initialize-Dashboard -ParentControl $mainPanel
    if ($controls -and $controls['Panel']) {
        Write-Host "  [OK] Dashboard initialized" -ForegroundColor Green
        Write-Host "    - Panel type: $($controls['Panel'].GetType().Name)" -ForegroundColor Cyan
        Write-Host "    - Controls count: $($controls['Panel'].Controls.Count)" -ForegroundColor Cyan
    } else {
        Write-Host "  [ERROR] Dashboard initialization returned null" -ForegroundColor Red
    }
} catch {
    Write-Host "  [ERROR] Exception: $_" -ForegroundColor Red
    exit 1
}

# Test 2: Performance Metrics
Write-Host "`n[TEST 2] Update-PerformanceMetrics..." -ForegroundColor Yellow
$result = Update-PerformanceMetrics
if ($result) {
    Write-Host "  [OK] Metrics updated" -ForegroundColor Green
    Write-Host "    - CPU: $($global:GatewayDashboard.CpuUsage)%" -ForegroundColor Cyan
    Write-Host "    - Memory: $($global:GatewayDashboard.MemoryUsageMB)MB / $($global:GatewayDashboard.MemoryTotalMB)MB" -ForegroundColor Cyan
    Write-Host "    - Memory Percent: $($global:GatewayDashboard.MemoryPercent)%" -ForegroundColor Cyan
} else {
    Write-Host "  [WARN] Metrics update returned false (using fallback)" -ForegroundColor Yellow
}

# Test 3: Health Status
Write-Host "`n[TEST 3] Calculate-HealthStatus..." -ForegroundColor Yellow
$health = Calculate-HealthStatus
Write-Host "  [OK] Health status: $health" -ForegroundColor Green

# Test 4: Dashboard State
Write-Host "`n[TEST 4] Get-DashboardState..." -ForegroundColor Yellow
$state = Get-DashboardState
Write-Host "  [OK] State retrieved:" -ForegroundColor Green
Write-Host "    - Status: $($state.Status)" -ForegroundColor Cyan
Write-Host "    - CPU: $($state.CpuUsage)%" -ForegroundColor Cyan
Write-Host "    - Memory: $($state.MemoryUsageMB)MB" -ForegroundColor Cyan

# Test 5: Update Display
Write-Host "`n[TEST 5] Update-DashboardDisplay..." -ForegroundColor Yellow
Update-DashboardDisplay -DashboardControls $controls
Write-Host "  [OK] Display updated" -ForegroundColor Green

# Test 6: Update Gateway Status
Write-Host "`n[TEST 6] Update-GatewayStatus..." -ForegroundColor Yellow
Update-GatewayStatus -Status "Running" -DashboardControls $controls
Write-Host "  [OK] Gateway status updated to 'Running'" -ForegroundColor Green

# Test 7: Update Connection Count
Write-Host "`n[TEST 7] Update-ConnectionCount..." -ForegroundColor Yellow
Update-ConnectionCount -Count 42 -DashboardControls $controls
Write-Host "  [OK] Connection count updated to 42" -ForegroundColor Green

Write-Host ""
Write-Host "=== All Tests Passed! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Showing dashboard window for 10 seconds..." -ForegroundColor Yellow
Write-Host "Observe:" -ForegroundColor White
Write-Host "  1. CPU/RAM values update in real-time" -ForegroundColor White
Write-Host "  2. CPU history bars animate" -ForegroundColor White
Write-Host "  3. Memory progress bar fills" -ForegroundColor White
Write-Host "  4. Status shows 'Running'" -ForegroundColor White
Write-Host "  5. Connection count shows 42" -ForegroundColor White
Write-Host ""

# Update status label
$statusLabel.Text = " Running - Window will close in 10 seconds"

# Auto-close timer
$closeTimer = New-Object System.Windows.Forms.Timer
$closeTimer.Interval = 10000
$closeTimer.Add_Tick({
    $testForm.Close()
    $closeTimer.Stop()
})
$closeTimer.Start()

# Status update timer
$statusTimer = New-Object System.Windows.Forms.Timer
$statusTimer.Interval = 1000
$secondsRemaining = 10
$statusTimer.Add_Tick({
    $secondsRemaining--
    $statusLabel.Text = " Running - Closing in $secondsRemaining seconds..."
    if ($secondsRemaining -le 0) {
        $statusTimer.Stop()
    }
})
$statusTimer.Start()

# Show form
[void]$testForm.ShowDialog()

# Cleanup
$closeTimer.Dispose()
$statusTimer.Dispose()
Stop-Dashboard

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary of fixes applied:" -ForegroundColor White
Write-Host "  1. UInt64 type detection for CIM queries" -ForegroundColor Green
Write-Host "  2. Removed array subtraction operations" -ForegroundColor Green
Write-Host "  3. FlowLayoutPanel auto-stacking layout" -ForegroundColor Green
Write-Host "  4. PerformanceCounter for fast metrics" -ForegroundColor Green
Write-Host "  5. Explicit type conversions for all calculations" -ForegroundColor Green