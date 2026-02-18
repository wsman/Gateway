# Config.ps1 - PowerShell Configuration Management Module
# ============================================================

# Error logging function for Config module
function Write-ConfigErrorLog {
    param(
        [string]$Message,
        [string]$Operation = "Configuration"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logPath = Join-Path $env:TEMP "GatewayLauncher_errors.log"
    $logEntry = "[$timestamp] [Config] $Operation - $Message`n"
    try {
        Add-Content -Path $logPath -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    catch {
        # Silently fail if logging fails
    }
}

# Default configuration values
# All paths are dynamic - no hardcoded absolute paths
$script:DefaultConfig = @{
    # Dynamic path using user's Documents folder
    ProjectPath     = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "OpenClaw"
    GatewayPort     = 18789
    # Centralized log file path
    LogFilePath     = Join-Path $env:TEMP "openclaw-gateway.log"
    ThemePreference = 'Nordic'
    AutoStart       = $false
    LogLevel        = 'Info'
    # Gateway command template - {PORT} will be replaced with actual port
    GatewayCommand  = "pnpm openclaw gateway run --port {PORT}"
}

# Global configuration hashtable
$script:Config = @{}

# Track if config is loaded
$script:ConfigLoaded = $false

# Get-Config - Retrieve configuration value by key
function Get-Config {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Name
    )
    try {
        if ([string]::IsNullOrEmpty($Name)) {
            # Return entire config hashtable
            return $script:Config
        }

        # Check if key exists in config AND value is not null/empty
        if ($script:Config.ContainsKey($Name) -and $null -ne $script:Config[$Name]) {
            $value = $script:Config[$Name]
            # For string values, also check if empty
            if ($value -is [string] -and [string]::IsNullOrEmpty($value)) {
                # Value is empty string, use default
                if ($script:DefaultConfig.ContainsKey($Name)) {
                    Write-SilentLog "Configuration key '$Name' is empty, using default value." 'DEBUG'
                    return $script:DefaultConfig[$Name]
                }
            }
            return $value
        }

        # Fallback to default if key doesn't exist or value is null
        if ($script:DefaultConfig.ContainsKey($Name)) {
            Write-SilentLog "Configuration key '$Name' not found or null, using default value." 'DEBUG'
            return $script:DefaultConfig[$Name]
        }

        Write-SilentLog "Configuration key '$Name' not found." 'DEBUG'
        return $null
    }
    catch {
        Write-ConfigErrorLog -Message "Error getting config '$Name': $_" -Operation "Get-Config"
        Write-SilentLog "Error retrieving configuration: $_" 'DEBUG'
        # Return default value if available
        if ($script:DefaultConfig.ContainsKey($Name)) {
            return $script:DefaultConfig[$Name]
        }
        return $null
    }
}

# Set-Config - Set configuration value
function Set-Config {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $Value
    )
    try {
        if (-not $script:DefaultConfig.ContainsKey($Name)) {
            Write-SilentLog "Configuration key '$Name' is not a recognized default key. Adding anyway." 'DEBUG'
        }

        $script:Config[$Name] = $Value
        Write-SilentLog "Configuration '$Name' set to '$Value'" 'DEBUG'
    }
    catch {
        Write-ConfigErrorLog -Message "Error setting config '$Name': $_" -Operation "Set-Config"
        Write-SilentLog "Error setting configuration '$Name': $_" 'DEBUG'
        throw
    }
}

# LoadConfig - Load configuration from JSON file
function LoadConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$ConfigPath = $null
    )
    try {
        # Validate and resolve ConfigPath if null or empty
        if ([string]::IsNullOrEmpty($ConfigPath)) {
            # Try to resolve from script root, fallback to relative path
            $scriptRoot = $null
            if (-not [string]::IsNullOrEmpty($PSScriptRoot)) {
                $scriptRoot = $PSScriptRoot
            }
            elseif (-not [string]::IsNullOrEmpty($MyInvocation.MyCommand.Path)) {
                $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
            }

            if (-not [string]::IsNullOrEmpty($scriptRoot)) {
                $ConfigPath = Join-Path $scriptRoot 'config\settings.json'
            }
            else {
                $ConfigPath = 'config\settings.json'
            }
        }

        # Double-check ConfigPath is not null after resolution
        if ([string]::IsNullOrEmpty($ConfigPath)) {
            Write-ConfigErrorLog -Message "ConfigPath is null or empty. Cannot load configuration." -Operation "LoadConfig"
            Write-SilentLog "Cannot load configuration: ConfigPath is null or empty. Using default values." 'DEBUG'
            $script:Config = $script:DefaultConfig.Clone()
            $script:ConfigLoaded = $true
            return $script:Config
        }

        # Start with defaults
        $script:Config = $script:DefaultConfig.Clone()

        # Check if config file exists
        if (-not (Test-Path -Path $ConfigPath -PathType Leaf)) {
            Write-SilentLog "Configuration file not found at '$ConfigPath'. Using default values." 'DEBUG'
            # Save default config to create the file
            try {
                SaveConfig -ConfigPath $ConfigPath
            }
            catch {
                Write-ConfigErrorLog -Message "Could not create default config file: $_" -Operation "LoadConfig"
            }
            $script:ConfigLoaded = $true
            return $script:Config
        }

        try {
            $jsonContent = Get-Content -Path $ConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json

            # Convert JSON object to hashtable and merge with defaults
            $jsonHashtable = @{}
            $jsonContent.PSObject.Properties | ForEach-Object {
                $jsonHashtable[$_.Name] = $_.Value
            }

            # Merge loaded config with defaults (loaded values override defaults)
            foreach ($key in $script:DefaultConfig.Keys) {
                if ($jsonHashtable.ContainsKey($key)) {
                    $script:Config[$key] = $jsonHashtable[$key]
                }
            }

            Write-SilentLog "Configuration loaded successfully from '$ConfigPath'" 'DEBUG'
            $script:ConfigLoaded = $true
        }
        catch {
            Write-ConfigErrorLog -Message "Failed to parse config file: $_" -Operation "LoadConfig"
            Write-SilentLog "Failed to load configuration from '$ConfigPath': $_" 'DEBUG'
            Write-SilentLog "Using default configuration values." 'DEBUG'
            $script:Config = $script:DefaultConfig.Clone()
        }
    }
    catch {
        Write-ConfigErrorLog -Message "Critical error loading config: $_" -Operation "LoadConfig"
        Write-SilentLog "Critical error loading configuration: $_" 'DEBUG'
        $script:Config = $script:DefaultConfig.Clone()
    }

    return $script:Config
}

# SaveConfig - Save configuration to JSON file
function SaveConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$ConfigPath = $null,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
    try {
        # Validate and resolve ConfigPath if null or empty
        if ([string]::IsNullOrEmpty($ConfigPath)) {
            # Try to resolve from script root, fallback to relative path
            $scriptRoot = $null
            if (-not [string]::IsNullOrEmpty($PSScriptRoot)) {
                $scriptRoot = $PSScriptRoot
            }
            elseif (-not [string]::IsNullOrEmpty($MyInvocation.MyCommand.Path)) {
                $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
            }

            if (-not [string]::IsNullOrEmpty($scriptRoot)) {
                $ConfigPath = Join-Path $scriptRoot 'config\settings.json'
            }
            else {
                $ConfigPath = 'config\settings.json'
            }
        }

        # Ensure ConfigPath is not null after resolution
        if ([string]::IsNullOrEmpty($ConfigPath)) {
            Write-ConfigErrorLog -Message "ConfigPath is null or empty. Cannot save configuration." -Operation "SaveConfig"
            Write-SilentLog "Cannot save configuration: ConfigPath is null or empty." 'DEBUG'
            return
        }

        # Ensure directory exists
        $configDir = Split-Path -Path $ConfigPath -Parent
        if (-not [string]::IsNullOrEmpty($configDir) -and -not (Test-Path -Path $configDir -PathType Container)) {
            try {
                New-Item -Path $configDir -ItemType Directory -Force | Out-Null
                Write-SilentLog "Created configuration directory: $configDir" 'DEBUG'
            }
            catch {
                Write-ConfigErrorLog -Message "Failed to create config directory '$configDir': $_" -Operation "SaveConfig"
                Write-SilentLog "Failed to create configuration directory '$configDir': $_" 'DEBUG'
            }
        }

        try {
            # Convert hashtable to JSON (preserving order for readability)
            $jsonOutput = $script:Config | ConvertTo-Json -Depth 10

            Set-Content -Path $ConfigPath -Value $jsonOutput -Force:$Force -ErrorAction Stop
            Write-SilentLog "Configuration saved successfully to '$ConfigPath'" 'DEBUG'
        }
        catch {
            Write-ConfigErrorLog -Message "Failed to save config to '$ConfigPath': $_" -Operation "SaveConfig"
            Write-Error "Failed to save configuration to '$ConfigPath': $_"
            throw
        }
    }
    catch {
        Write-ConfigErrorLog -Message "Critical error saving config: $_" -Operation "SaveConfig"
        Write-Error "Critical error saving configuration: $_"
        throw
    }
}

# Function to check if config is loaded
function Test-ConfigLoaded {
    return $script:ConfigLoaded
}

# Function to get default config value
function Get-DefaultConfigValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    if ($script:DefaultConfig.ContainsKey($Name)) {
        return $script:DefaultConfig[$Name]
    }
    return $null
}

# Export module functions

