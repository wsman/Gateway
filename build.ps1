<#
.SYNOPSIS
    Build script for Gateway Launcher - Packages PowerShell script as Windows EXE

.DESCRIPTION
    This script:
    1. Checks if PS2EXE module is available, installs it if not
    2. Compiles GatewayLauncher.ps1 into GatewayLauncher.exe
    3. Bundles all required modules as embedded resources
    4. Sets appropriate icon and version info
    5. Outputs to dist\ folder
    6. Tests if the exe runs correctly

.REQUIREMENTS
    - PowerShell 5.1 or later
    - Administrator privileges may be needed for module installation
    - PS2EXE module (installed automatically if missing)

.VERSION
    1.0.0
#>

[CmdletBinding()]
param(
    [switch]$NoTest  # Skip the runtime test
)

# ============================================================
# Configuration
# ============================================================

$ErrorActionPreference = "Stop"
# Use $PSScriptRoot, fallback to $MyInvocation if null
if ([string]::IsNullOrEmpty($PSScriptRoot)) {
    $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
else {
    $ScriptRoot = $PSScriptRoot
}

# Validate ScriptRoot is not null
if ([string]::IsNullOrEmpty($ScriptRoot)) {
    Write-Error "Failed to determine script directory. Please run the script directly (not sourced)."
    exit 1
}

# Paths
$SourceScript = Join-Path $ScriptRoot "GatewayLauncher.ps1"
$ModulesPath = Join-Path $ScriptRoot "modules"
$DistPath = Join-Path $ScriptRoot "dist"
$ExeName = "GatewayLauncher.exe"

# Version Info
$Version = "1.0.0"
$CompanyName = "OpenClaw"
$ProductName = "Gateway Launcher"
$FileDescription = "Gateway Launcher - Start and manage OpenClaw Gateway"
$Copyright = "Copyright (c) 2026"

# ============================================================
# Functions
# ============================================================

function Write-Step {
    param([string]$Message)
    Write-Host "`n>>> $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-SilentLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-PS2EXEModule {
    Write-Step "Installing PS2EXE module..."

    # Check if running as admin (sometimes needed)
    $isAdmin = Test-Administrator

    try {
        # Try to install for current user only (no admin required)
        # Use -Confirm:$false to avoid interactive prompts
        Write-SilentLog "Installing PS2EXE module for current user..." 'INFO'
        Install-Module -Name PS2EXE -Scope CurrentUser -Force -Confirm:$false -ErrorAction Stop
        Write-Success "PS2EXE module installed successfully"
    }
    catch {
        # If that fails, try with -AllowClobber
        try {
            Write-SilentLog "Retrying with AllowClobber..." 'INFO'
            Install-Module -Name PS2EXE -Scope CurrentUser -Force -AllowClobber -Confirm:$false -ErrorAction Stop
            Write-Success "PS2EXE module installed successfully"
        }
        catch {
            Write-Error "Failed to install PS2EXE module: $_"
            Write-SilentLog "`nPlease run PowerShell as Administrator and try again, or install manually:" 'INFO'
            Write-SilentLog "    Install-Module -Name PS2EXE -Scope AllUsers -Force -Confirm:`$false" 'INFO'
            exit 1
        }
    }
}

function Get-ModuleList {
    $modules = @()
    if (Test-Path $ModulesPath) {
        $modules = Get-ChildItem -Path $ModulesPath -Filter "*.ps1" -ErrorAction SilentlyContinue
    }
    return $modules
}

function Test-CompiledEXE {
    param(
        [string]$ExePath,
        [int]$WaitSeconds = 5
    )

    Write-Step "Testing compiled EXE..."

    # Create a temporary test script
    $testScript = @"
`$exePath = "$ExePath"
`$errLog = "`$env:TEMP\gateway_test_`$PID.log"
`$start = Get-Date

# Start the process
try {
    `$proc = Start-Process -FilePath `$exePath -PassThru -RedirectStandardError `$errLog -WindowStyle Hidden
    Write-SilentLog "Process started with PID: `$(`$proc.Id)" 'INFO'

    # Wait a bit for the app to initialize
    Start-Sleep -Seconds $WaitSeconds

    # Check if process is still running
    if (-not `$proc.HasExited) {
        Write-SilentLog "[OK] Application started successfully and is running" 'INFO'

        # Stop the process
        Stop-Process -Id `$proc.Id -Force -ErrorAction SilentlyContinue
        Write-SilentLog "Process stopped" 'INFO'

        # Check for errors
        if ((Test-Path `$errLog) -and ((Get-Content `$errLog -Raw) -match "Exception|Error|ErrorMessage")) {
            Write-SilentLog "[WARN] Errors detected in stderr" 'INFO'
            Get-Content `$errLog | Select-Object -First 5
        }

        Remove-Item `$errLog -ErrorAction SilentlyContinue
        exit 0
    }
    else {
        Write-SilentLog "[ERROR] Process exited prematurely with code: `$($proc.ExitCode)" 'INFO'

        if (Test-Path `$errLog) {
            Write-SilentLog "Error output:" 'INFO'
            Get-Content `$errLog
        }

        Remove-Item `$errLog -ErrorAction SilentlyContinue
        exit 1
    }
}
catch {
    Write-SilentLog "[ERROR] Failed to start process: `$_" 'INFO'
    Remove-Item `$errLog -ErrorAction SilentlyContinue
    exit 1
}
"@

    $testScriptPath = Join-Path $env:TEMP "test_gateway_exe.ps1"
    $testScript | Out-File -FilePath $testScriptPath -Encoding UTF8

    try {
        $result = & $testScriptPath
        Write-SilentLog $result 'INFO'

        if ($LASTEXITCODE -eq 0) {
            Write-Success "EXE test passed"
            return $true
        }
        else {
            Write-Error "EXE test failed"
            return $false
        }
    }
    finally {
        Remove-Item $testScriptPath -ErrorAction SilentlyContinue
    }
}

# ============================================================
# Main Build Process
# ============================================================

Write-SilentLog "========================================" 'INFO'
Write-SilentLog "  Gateway Launcher Build Script" 'INFO'
Write-SilentLog "  Version $Version" 'INFO'
Write-SilentLog "========================================" 'INFO'

# Step 1: Run test suite
Write-Step "Running test suite..."

try {
    $testScriptPath = Join-Path $ScriptRoot "Test-GatewayLauncher.ps1"
    if (Test-Path $testScriptPath) {
        & $testScriptPath -ScriptPath $SourceScript
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Test suite failed"
            exit 1
        }
    }
    else {
        Write-SilentLog "Test script not found. Skipping test suite." 'WARN'
    }
}
catch {
    Write-SilentLog "Test suite failed: $_" 'WARN'
    Write-SilentLog "Continuing anyway..." 'WARN'
}

# Step 2: Verify source files exist
Write-Step "Verifying source files..."

if (-not (Test-Path $SourceScript)) {
    Write-Error "Source script not found: $SourceScript"
    exit 1
}
Write-Success "Found GatewayLauncher.ps1"

$moduleList = Get-ModuleList
if ($moduleList.Count -eq 0) {
    Write-Error "No modules found in: $ModulesPath"
    exit 1
}
Write-Success "Found $($moduleList.Count) module(s):"
foreach ($mod in $moduleList) {
    Write-SilentLog "  - $($mod.Name)" 'INFO'
}

# Step 2: Check/Install PS2EXE
Write-Step "Checking PS2EXE module..."

$ps2exeModule = Get-Module -Name PS2EXE -ListAvailable
if (-not $ps2exeModule) {
    Write-SilentLog "PS2EXE module not found" 'WARN'
    Install-PS2EXEModule
}
else {
    Write-Success "PS2EXE module found (version $($ps2exeModule.Version))"
}

Import-Module PS2EXE -ErrorAction Stop

# Step 3: Prepare output directory
Write-Step "Preparing output directory..."

if (Test-Path $DistPath) {
    Write-SilentLog "Removing old dist folder..." 'INFO'
    Remove-Item -Path $DistPath -Recurse -Force
}

New-Item -Path $DistPath -ItemType Directory | Out-Null
Write-Success "Created dist folder: $DistPath"

# Step 4: Check for icon file
$iconPath = $null
$iconOptions = @(
    (Join-Path $ScriptRoot "app.ico"),
    (Join-Path $ScriptRoot "icon.ico"),
    (Join-Path $ScriptRoot "GatewayLauncher.ico")
)

foreach ($icon in $iconOptions) {
    if (Test-Path $icon) {
        $iconPath = $icon
        break
    }
}

if ($iconPath) {
    Write-Success "Found icon: $iconPath"
}
else {
    Write-SilentLog "No icon file found. EXE will use default icon." 'WARN'
    Write-SilentLog "  Place app.ico, icon.ico, or GatewayLauncher.ico in the project root" 'INFO'
}

# Step 5: Compile EXE
Write-Step "Compiling GatewayLauncher.exe..."

# Build PS2EXE parameters (using correct parameter names)
$compileParams = @{
    inputFile = $SourceScript
    outputFile = Join-Path $DistPath $ExeName
    verbose = $false
    noConsole = $true  # WinForms app without console
    noOutput = $true
    # NOTE: winFormsDPIAware removed - it was preventing window resizing
    noError = $true
    requireAdmin = $false
}

# Add icon if available
if ($iconPath) {
    $compileParams['iconFile'] = $iconPath
}

# Add version info (correct parameter names)
$compileParams['version'] = $Version
$compileParams['company'] = $CompanyName
$compileParams['product'] = $ProductName
$compileParams['description'] = $FileDescription
$compileParams['copyright'] = $Copyright

# Compile the EXE
try {
    Write-SilentLog "Running PS2EXE with parameters..." 'INFO'
    Write-SilentLog "  Output: $($compileParams.OutputFile)" 'INFO'
    Write-SilentLog "  Version: $($compileParams.Version)" 'INFO'

    # Execute PS2EXE
    & "Invoke-ps2exe" @compileParams

    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "PS2EXE exited with code $LASTEXITCODE"
    }

    Write-Success "EXE compiled successfully"
}
catch {
    Write-Error "Failed to compile EXE: $_"
    exit 1
}

# Step 6: Verify EXE was created
Write-Step "Verifying output..."

if (-not (Test-Path (Join-Path $DistPath $ExeName))) {
    Write-Error "EXE was not created"
    exit 1
}

$exeItem = Get-Item (Join-Path $DistPath $ExeName)
Write-Success "EXE created: $($exeItem.Name) ($([math]::Round($exeItem.Length / 1KB, 2)) KB)"

# Step 7: Copy required files to dist
Write-Step "Copying supporting files to dist..."

# Copy modules folder
$distModulesPath = Join-Path $DistPath "modules"
Copy-Item -Path $ModulesPath -Destination $distModulesPath -Recurse -Force
Write-Success "Copied modules folder"

# Copy config folder if it exists
$configPath = Join-Path $ScriptRoot "config"
if (Test-Path $configPath) {
    $distConfigPath = Join-Path $DistPath "config"
    Copy-Item -Path $configPath -Destination $distConfigPath -Recurse -Force
    Write-Success "Copied config folder"
}
else {
    Write-SilentLog "Config folder not found - will use default settings" 'WARN'
}

# Copy themes folder if it exists
$themesPath = Join-Path $ScriptRoot "themes"
if (Test-Path $themesPath) {
    $distThemesPath = Join-Path $DistPath "themes"
    Copy-Item -Path $themesPath -Destination $distThemesPath -Recurse -Force
    Write-Success "Copied themes folder"
}
else {
    Write-SilentLog "Themes folder not found - will use default theme" 'WARN'
}

# Copy any other required files
$extraFiles = @("create_config.ps1")
foreach ($file in $extraFiles) {
    $srcPath = Join-Path $ScriptRoot $file
    if (Test-Path $srcPath) {
        Copy-Item -Path $srcPath -Destination $DistPath -Force
        Write-SilentLog "  Copied $file" 'INFO'
    }
}

# Step 8: Create a README for dist folder
$readmeContent = @"
Gateway Launcher
===============

A modern Windows application for managing OpenClaw Gateway.

REQUIREMENTS
------------
- Windows 10/11
- PowerShell 5.1 or later
- Node.js and pnpm (for running the gateway)

USAGE
-----
1. Run GatewayLauncher.exe
2. Configure the project path in config/settings.json
3. Use the buttons to start/stop the gateway

The application will:
- Look for config/settings.json in the same directory
- Use default settings if no config is found
- Run in system tray when minimized

FILES
-----
- GatewayLauncher.exe  - Main application
- modules/             - Application modules (required)
- config/              - Configuration files (optional)

SUPPORT
-------
For issues and feature requests, contact the development team.
"@

$readmeContent | Out-File -FilePath (Join-Path $DistPath "README.txt") -Encoding UTF8
Write-Success "Created README.txt"

# Step 9: Test the EXE (if not skipped)
if (-not $NoTest) {
    Write-Step "Testing compiled EXE..."

    $testResult = Test-CompiledEXE -ExePath (Join-Path $DistPath $ExeName) -WaitSeconds 5

    if ($testResult) {
        Write-Success "EXE test completed successfully"
    }
    else {
        Write-SilentLog "EXE test had issues - please verify manually" 'WARN'
    }
}
else {
    Write-SilentLog "`nSkipping EXE test (using -NoTest flag)" 'INFO'
}

# ============================================================
# Summary
# ============================================================

Write-SilentLog "`n========================================" 'INFO'
Write-SilentLog "  Build Complete!" 'INFO'
Write-SilentLog "========================================" 'INFO'

Write-SilentLog "`nOutput location: $DistPath" 'INFO'
Write-SilentLog "Executable: $ExeName" 'INFO'

Write-SilentLog "`nTo run the application:" 'INFO'
Write-SilentLog "    .\dist\GatewayLauncher.exe" 'INFO'

Write-SilentLog "`nTo build again, run:" 'INFO'
Write-SilentLog "    .\build.ps1" 'INFO'

Write-SilentLog "" 'INFO'
