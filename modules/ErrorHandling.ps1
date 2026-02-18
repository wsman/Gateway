# ErrorHandling.ps1 - Centralized Error Handling Module
#
# This module provides comprehensive error handling for the Gateway Launcher application.
# Features:
# - Centralized error logging to file
# - User-friendly error messages
# - Error recovery suggestions
# - Global exception handling setup

# ============================================================
# Error Log Configuration
# ============================================================

$script:ErrorLogPath = Join-Path $env:TEMP "GatewayLauncher_errors.log"
$script:MaxLogFileSize = 5MB  # 5MB max log file size

# ============================================================
# Error Logging Functions
# ============================================================

<#
.SYNOPSIS
    Logs an error to the central error log file

.DESCRIPTION
    Writes error information to the log file with timestamp, error message, and stack trace

.PARAMETER ErrorRecord
    The error record from a try-catch block

.PARAMETER Context
    Additional context about where the error occurred

.PARAMETER Severity
    Error severity: Critical, Error, Warning, Info
#>
function Write-ErrorLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $ErrorRecord,

        [Parameter(Mandatory = $false)]
        [string]$Context = "Unknown",

        [Parameter(Mandatory = $false)]
        [ValidateSet('Critical', 'Error', 'Warning', 'Info')]
        [string]$Severity = 'Error'
    )

    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $errorMessage = $ErrorRecord.Exception.Message
        $stackTrace = $ErrorRecord.ScriptStackTrace

        # Build log entry
        $logEntry = @"
================================================================================
[$timestamp] [$Severity] $Context
Error: $errorMessage
Stack Trace:
$stackTrace
================================================================================

"@

        # Ensure log directory exists
        $logDir = Split-Path -Parent $script:ErrorLogPath
        if (-not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }

        # Check and rotate log file if too large
        if (Test-Path $script:ErrorLogPath) {
            $logSize = (Get-Item $script:ErrorLogPath).Length
            if ($logSize -gt $script:MaxLogFileSize) {
                # Archive old log
                $archivePath = $script:ErrorLogPath -replace '\.log$', '_archived.log'
                Move-Item -Path $script:ErrorLogPath -Destination $archivePath -Force
            }
        }

        # Write to log file
        Add-Content -Path $script:ErrorLogPath -Value $logEntry -Encoding UTF8
    }
    catch {
        # Silently fail if logging fails - don't create infinite loop
    }
}

<#
.SYNOPSIS
    Generates user-friendly error messages

.DESCRIPTION
    Creates human-readable error messages with context and recovery suggestions

.PARAMETER ErrorRecord
    The error record from a try-catch block

.PARAMETER Operation
    The operation that failed

.PARAMETER SuggestRecovery
    Whether to generate recovery suggestions
#>
function Get-FriendlyErrorMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $ErrorRecord,

        [Parameter(Mandatory = $false)]
        [string]$Operation = "Unknown operation",

        [Parameter(Mandatory = $false)]
        [switch]$SuggestRecovery
    )

    $errorMsg = $ErrorRecord.Exception.Message

    # Map common errors to user-friendly messages
    $friendlyMessages = @{
        "Cannot find path" = "The required file or folder could not be found."
        "Access is denied" = "Permission denied. Please check your access rights."
        "The process cannot access the file" = "The file is in use by another program."
        "The operation has timed out" = "The operation took too long and was cancelled."
        "Network path not found" = "The network location is not accessible."
        "Object reference not set" = "A required component is missing or not initialized."
        "Invalid operation" = "This action cannot be performed at this time."
    }

    $userMessage = "Error during $Operation"
    $recoverySuggestion = ""

    # Check for known error patterns
    foreach ($pattern in $friendlyMessages.Keys) {
        if ($errorMsg -like "*$pattern*") {
            $userMessage = $friendlyMessages[$pattern]
            break
        }
    }

    # Generate recovery suggestions if requested
    if ($SuggestRecovery) {
        $recoverySuggestion = Get-RecoverySuggestion -ErrorRecord $ErrorRecord -Operation $Operation
    }

    # Build result
    $result = @{
        UserMessage = $userMessage
        TechnicalDetails = $errorMsg
        RecoverySuggestion = $recoverySuggestion
    }

    return $result
}

<#
.SYNOPSIS
    Generates recovery suggestions based on error type

.DESCRIPTION
    Analyzes the error and provides actionable recovery steps

.PARAMETER ErrorRecord
    The error record from a try-catch block

.PARAMETER Operation
    The operation that failed
#>
function Get-RecoverySuggestion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $ErrorRecord,

        [Parameter(Mandatory = $false)]
        [string]$Operation = "Unknown operation"
    )

    $errorMsg = $ErrorRecord.Exception.Message
    $suggestions = @()

    # File/Path related errors
    if ($errorMsg -like "*Cannot find path*") {
        $suggestions += "Verify the file or folder path is correct"
        $suggestions += "Check if the required files exist"
        $suggestions += "Try creating the missing file or folder manually"
    }

    # Permission errors
    if ($errorMsg -like "*Access is denied*") {
        $suggestions += "Run the application as Administrator"
        $suggestions += "Check file/folder permissions"
        $suggestions += "Verify the file is not locked by another process"
    }

    # Port/Network errors
    if ($errorMsg -like "*port*" -or $errorMsg -like "*connection*") {
        $suggestions += "Use 'Clean Ports' button to free the port"
        $suggestions += "Check if another application is using the port"
        $suggestions += "Try restarting the application"
    }

    # Configuration errors
    if ($errorMsg -like "*configuration*" -or $errorMsg -like "*config*") {
        $suggestions += "Check the configuration file for errors"
        $suggestions += "Reset to default settings if needed"
        $suggestions += "Verify all required settings are present"
    }

    # Process errors
    if ($errorMsg -like "*process*" -or $errorMsg -like "*PID*") {
        $suggestions += "The gateway process may have crashed"
        $suggestions += "Try stopping the gateway and starting again"
        $suggestions += "Check the gateway logs for more details"
    }

    # Module import errors
    if ($errorMsg -like "*module*" -or $errorMsg -like "*import*") {
        $suggestions += "Verify all required modules are present"
        $suggestions += "Try restarting the application"
        $suggestions += "Check for syntax errors in module files"
    }

    # Default suggestions if none matched
    if ($suggestions.Count -eq 0) {
        $suggestions += "Try restarting the application"
        $suggestions += "Check the error log for more details"
        $suggestions += "If the problem persists, check for updates"
    }

    return $suggestions -join ". "
}

<#
.SYNOPSIS
    Displays a user-friendly error message dialog

.DESCRIPTION
    Shows an error dialog with the message and optional recovery suggestions

.PARAMETER ErrorRecord
    The error record from a try-catch block

.PARAMETER Operation
    The operation that failed

.PARAMETER ShowDetails
    Whether to show technical details to the user
#>
function Show-ErrorDialog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $ErrorRecord,

        [Parameter(Mandatory = $false)]
        [string]$Operation = "Unknown operation",

        [Parameter(Mandatory = $false)]
        [switch]$ShowDetails
    )

    # Get friendly error message
    $errorInfo = Get-FriendlyErrorMessage -ErrorRecord $ErrorRecord -Operation $Operation -SuggestRecovery

    # Log the error
    Write-ErrorLog -ErrorRecord $ErrorRecord -Context $Operation -Severity 'Error'

    # Build message text
    $messageText = $errorInfo.UserMessage
    if ($errorInfo.RecoverySuggestion) {
        $messageText += "`n`nRecovery suggestion: $($errorInfo.RecoverySuggestion)"
    }

    if ($ShowDetails) {
        $messageText += "`n`nTechnical details: $($errorInfo.TechnicalDetails)"
    }

    # Write to output log instead of showing popup
    try {
        if ($script:OutputTextBox) {
            $time = Get-Date -Format "HH:mm:ss"
            $script:OutputTextBox.AppendText("[$time] ERROR: $messageText`r`n")
            $script:OutputTextBox.ScrollToCaret()
        }
    }
    catch {
        # Silently fail if output textbox not available
    }
}

<#
.SYNOPSIS
    Shows a warning dialog with recovery options

.DESCRIPTION
    Displays a warning message with actionable recovery options

.PARAMETER Message
    The warning message to display

.PARAMETER Title
    Dialog title

.PARAMETER Suggestions
    Array of recovery suggestions
#>
function Show-WarningDialog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$Title = "Warning",

        [Parameter(Mandatory = $false)]
        [string[]]$Suggestions = @()
    )

    $fullMessage = $Message
    if ($Suggestions.Count -gt 0) {
        $fullMessage += "`n`nSuggestions:"
        foreach ($suggestion in $Suggestions) {
            $fullMessage += "`n- $suggestion"
        }
    }

    # Write to output log instead of showing popup
    try {
        if ($script:OutputTextBox) {
            $time = Get-Date -Format "HH:mm:ss"
            $script:OutputTextBox.AppendText("[$time] WARNING: $fullMessage`r`n")
            $script:OutputTextBox.ScrollToCaret()
        }
    }
    catch {
        # Silently fail if output textbox not available
    }
}

<#
.SYNOPSIS
    Shows an info dialog to the user

.DESCRIPTION
    Displays an informational message dialog

.PARAMETER Message
    The message to display

.PARAMETER Title
    Dialog title
#>
function Show-InfoDialog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$Title = "Information"
    )

    # Write to output log instead of showing popup
    try {
        if ($script:OutputTextBox) {
            $time = Get-Date -Format "HH:mm:ss"
            $script:OutputTextBox.AppendText("[$time] INFO: $Message`r`n")
            $script:OutputTextBox.ScrollToCaret()
        }
    }
    catch {
        # Silently fail if output textbox not available
    }
}

<#
.SYNOPSIS
    Sets up global exception handling

.DESCRIPTION
    Registers global exception handlers to catch unhandled errors
#>
function Initialize-GlobalErrorHandler {
    # Set global error action preference
    $global:ErrorActionPreference = 'Stop'

    # Register script block for unhandled exceptions
    $global:ErrorHandler_Initialized = $true

    Write-SilentLog "Global error handler initialized. Log file: $script:ErrorLogPath" 'DEBUG'
}

<#
.SYNOPSIS
    Safely executes a script block with error handling

.DESCRIPTION
    Wraps a script block in try-catch and handles errors appropriately

.PARAMETER ScriptBlock
    The script block to execute

.PARAMETER Operation
    Description of the operation for error messages

.PARAMETER OnError
    Script block to execute on error

.PARAMETER ContinueOnError
    Whether to continue (return $false) on error instead of throwing
#>
function Invoke-Safely {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory = $false)]
        [string]$Operation = "Operation",

        [Parameter(Mandatory = $false)]
        [scriptblock]$OnError = $null,

        [Parameter(Mandatory = $false)]
        [switch]$ContinueOnError
    )

    try {
        & $ScriptBlock
        return $true
    }
    catch {
        # Log the error
        Write-ErrorLog -ErrorRecord $_ -Context $Operation -Severity 'Error'

        # Get friendly message
        $errorInfo = Get-FriendlyErrorMessage -ErrorRecord $_ -Operation $Operation -SuggestRecovery

        # Call error handler if provided
        if ($null -ne $OnError) {
            & $OnError $errorInfo
        }

        if ($ContinueOnError) {
            return $false
        }
        else {
            throw
        }
    }
}

<#
.SYNOPSIS
    Gets the path to the error log file

.DESCRIPTION
    Returns the current error log file path
#>
function Get-ErrorLogPath {
    return $script:ErrorLogPath
}

<#
.SYNOPSIS
    Opens the error log file in the default text editor

.DESCRIPTION
    Launches the default application to view the error log
#>
function Open-ErrorLog {
    if (Test-Path $script:ErrorLogPath) {
        Start-Process notepad.exe -ArgumentList $script:ErrorLogPath
    }
    else {
        Show-InfoDialog -Message "No error log file exists yet." -Title "Error Log"
    }
}

<#
.SYNOPSIS
    Clears the error log file

.DESCRIPTION
    Deletes the contents of the error log file
#>
function Clear-ErrorLog {
    if (Test-Path $script:ErrorLogPath) {
        Remove-Item -Path $script:ErrorLogPath -Force
        Write-SilentLog "Error log cleared" 'DEBUG'
    }
}

# ============================================================
# Initialize on Module Load
# ============================================================

# Ensure error log directory exists
$logDir = Split-Path -Parent $script:ErrorLogPath
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

# Export module functions - simply list them (sourced scripts)
$functionList = @(
    'Write-ErrorLog',
    'Get-FriendlyErrorMessage',
    'Get-RecoverySuggestion',
    'Show-ErrorDialog',
    'Show-WarningDialog',
    'Show-InfoDialog',
    'Initialize-GlobalErrorHandler',
    'Invoke-Safely',
    'Get-ErrorLogPath',
    'Open-ErrorLog',
    'Clear-ErrorLog'
)

Write-SilentLog "ErrorHandling Module v1.0.0 loaded successfully" 'DEBUG'
