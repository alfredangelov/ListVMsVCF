<#
.SYNOPSIS
    VirtToolkit shared logging utilities for standardized logging across all modules.

.DESCRIPTION
    This module provides unified logging functionality for all VirtToolkit modules.
    It consolidates logging patterns from RVToolsDump, PermissionToolkit, MigrationToolkit, and ListVMs
    to provide consistent log formatting, file output, and console display.

    Key Features:
    - Standardized log levels with configurable filtering
    - Consistent timestamp formatting for exports and logs
    - File and console output with formatting options
    - Color-coded console output based on log levels
    - Integration with existing VirtToolkit patterns

.NOTES
    Part of VirtToolkit: Enterprise Virtualization Management Platform
    Integrates with shared modules and unified configuration system
#>

function Write-VirtToolkitLog {
    <#
    .SYNOPSIS
        Writes log messages with standardized timestamp and level formatting for VirtToolkit operations.

    .DESCRIPTION
        Write-VirtToolkitLog provides a unified logging interface across all VirtToolkit modules.
        It supports different log levels, configurable filtering, and can write to both console
        and log files with consistent formatting.

    .PARAMETER Message
        The message to log. Supports multi-line messages.

    .PARAMETER Level
        The log level. Valid values are 'DEBUG', 'INFO', 'WARN', 'ERROR', 'SUCCESS'.
        Default: 'INFO'

    .PARAMETER LogFile
        Optional path to a log file. If specified, messages will be written to both console and file.
        Directory will be created automatically if it doesn't exist.

    .PARAMETER ConfigLogLevel
        The minimum log level to display based on configuration. Messages below this level will be filtered.
        Default: 'INFO'

    .PARAMETER ModuleName
        Name of the calling VirtToolkit module for context in log messages.
        If provided, will be included in the log format.

    .PARAMETER NoConsole
        Suppress console output and write only to log file (if specified).

    .PARAMETER NoTimestamp
        Suppress timestamp in log output for cleaner display.

    .OUTPUTS
        None. Writes to console and/or file based on parameters.

    .EXAMPLE
        Write-VirtToolkitLog -Message "Starting VM export process" -Level 'INFO' -ModuleName 'ListVMs'

        Description
        -----------
        Writes informational message with module context

    .EXAMPLE
        Write-VirtToolkitLog -Message "Export completed successfully" -Level 'SUCCESS' -LogFile "C:\logs\virtoolkit.log"

        Description
        -----------
        Writes success message to both console and file

    .EXAMPLE
        Write-VirtToolkitLog -Message "Connection failed" -Level 'ERROR' -ModuleName 'PermissionToolkit' -LogFile "C:\logs\errors.log"

        Description
        -----------
        Writes error message with module context to console and file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO',
        
        [Parameter(Mandatory = $false)]
        [string]$LogFile,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR', 'SUCCESS')]
        [string]$ConfigLogLevel = 'INFO',

        [Parameter(Mandatory = $false)]
        [string]$ModuleName,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Application", "Security", "Performance", "Error", "Audit")]
        [string]$Category = "Application",

        [Parameter(Mandatory = $false)]
        [string]$OperationType,

        [Parameter(Mandatory = $false)]
        [switch]$NoConsole,

        [Parameter(Mandatory = $false)]
        [switch]$NoTimestamp
    )
    
    # Define log level hierarchy for filtering
    $logLevels = @{
        'DEBUG'   = 0
        'INFO'    = 1
        'WARN'    = 2
        'ERROR'   = 3
        'SUCCESS' = 1  # Same level as INFO but always displayed
    }
    
    # Check if we should log this level
    $shouldLog = $logLevels[$Level] -ge $logLevels[$ConfigLogLevel] -or $Level -eq 'SUCCESS'
    
    if (-not $shouldLog) {
        return
    }
    
    # Build log message components
    $timestamp = if (-not $NoTimestamp) { Get-Date -Format 'yyyy-MM-dd HH:mm:ss' } else { $null }
    $module = if ($ModuleName) { "[$ModuleName]" } else { "" }
    $levelTag = "[$Level]"
    
    # Construct full log line
    $logComponents = @()
    if ($timestamp) { $logComponents += $timestamp }
    if ($module) { $logComponents += $module }
    $logComponents += $levelTag
    $logComponents += $Message
    
    $logLine = $logComponents -join " "
    
    # Write to console with color coding (if not suppressed)
    if (-not $NoConsole) {
        $color = switch ($Level) {
            'DEBUG' { 'Gray' }
            'INFO' { 'White' }
            'WARN' { 'Yellow' }
            'ERROR' { 'Red' }
            'SUCCESS' { 'Green' }
            default { 'White' }
        }
        
        Write-Host $logLine -ForegroundColor $color
    }
    
    # Write to log file if specified
    if ($LogFile) {
        try {
            # Ensure log directory exists
            $logDir = Split-Path $LogFile -Parent
            if ($logDir -and -not (Test-Path $logDir)) {
                New-Item -Path $logDir -ItemType Directory -Force | Out-Null
            }
            
            # Append to log file
            $logLine | Out-File -FilePath $LogFile -Append -Encoding UTF8
        }
        catch {
            Write-Warning "VirtToolkit.Logging: Failed to write to log file '$LogFile': $($_.Exception.Message)"
        }
    }
}

function Get-VirtToolkitTimestamp {
    <#
    .SYNOPSIS
        Generates standardized timestamps used across VirtToolkit modules.

    .DESCRIPTION
        Get-VirtToolkitTimestamp provides consistent timestamp formatting for file names,
        exports, and logging across all VirtToolkit modules. It supports different formats
        for different use cases.

    .PARAMETER Format
        The timestamp format to generate. Valid values:
        - 'FileExport': Format suitable for file names (yyyyMMdd_HHmmss)
        - 'Display': Format for display in logs and UI (yyyy-MM-dd HH:mm:ss)
        - 'ISO': ISO 8601 format (yyyy-MM-ddTHH:mm:ss)
        - 'Sortable': Sortable format (yyyy-MM-dd_HH-mm-ss)
        Default: 'Display'

    .PARAMETER UTC
        Use UTC time instead of local time.

    .OUTPUTS
        System.String
        Returns formatted timestamp string

    .EXAMPLE
        $timestamp = Get-VirtToolkitTimestamp -Format 'FileExport'
        # Returns: "20250130_143022"

    .EXAMPLE
        $timestamp = Get-VirtToolkitTimestamp -Format 'Display'
        # Returns: "2025-01-30 14:30:22"

    .EXAMPLE
        $timestamp = Get-VirtToolkitTimestamp -Format 'ISO' -UTC
        # Returns: "2025-01-30T19:30:22" (UTC time)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('FileExport', 'Display', 'ISO', 'Sortable')]
        [string]$Format = 'Display',

        [Parameter(Mandatory = $false)]
        [switch]$UTC
    )

    $dateTime = if ($UTC) { Get-Date -AsUTC } else { Get-Date }

    switch ($Format) {
        'FileExport' {
            return $dateTime.ToString('yyyyMMdd_HHmmss')
        }
        'Display' {
            return $dateTime.ToString('yyyy-MM-dd HH:mm:ss')
        }
        'ISO' {
            return $dateTime.ToString('yyyy-MM-ddTHH:mm:ss')
        }
        'Sortable' {
            return $dateTime.ToString('yyyy-MM-dd_HH-mm-ss')
        }
        default {
            return $dateTime.ToString('yyyy-MM-dd HH:mm:ss')
        }
    }
}

function Start-VirtToolkitOperation {
    <#
    .SYNOPSIS
        Starts a VirtToolkit operation with standardized logging and timing.

    .DESCRIPTION
        Start-VirtToolkitOperation initializes operation tracking with consistent
        logging format and provides a mechanism for timing operations across modules.

    .PARAMETER OperationName
        Name of the operation being started (e.g., "VM Export", "Permission Analysis").

    .PARAMETER ModuleName
        Name of the VirtToolkit module performing the operation.

    .PARAMETER LogFile
        Optional log file for operation tracking.

    .PARAMETER Parameters
        Optional hashtable of operation parameters for logging.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Returns operation tracking object with StartTime and OperationId

    .EXAMPLE
        $operation = Start-VirtToolkitOperation -OperationName "VM Export" -ModuleName "ListVMs"

        Description
        -----------
        Starts operation tracking for VM export process

    .EXAMPLE
        $operation = Start-VirtToolkitOperation -OperationName "Permission Analysis" -ModuleName "PermissionToolkit" -LogFile "C:\logs\operations.log"

        Description
        -----------
        Starts operation with file logging
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OperationName,

        [Parameter(Mandatory = $false)]
        [string]$ModuleName,

        [Parameter(Mandatory = $false)]
        [string]$LogFile,

        [Parameter(Mandatory = $false)]
        [hashtable]$Parameters
    )

    $operationId = [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
    $startTime = Get-Date

    $message = "INFO: Starting operation: $OperationName"
    if ($Parameters -and $Parameters.Count -gt 0) {
        $paramStrings = $Parameters.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }
        $message += " [Parameters: $($paramStrings -join ', ')]"
    }

    Write-VirtToolkitLog -Message $message -Level 'INFO' -ModuleName $ModuleName -LogFile $LogFile

    return [PSCustomObject]@{
        OperationId   = $operationId
        OperationName = $OperationName
        ModuleName    = $ModuleName
        StartTime     = $startTime
        LogFile       = $LogFile
    }
}

function Stop-VirtToolkitOperation {
    <#
    .SYNOPSIS
        Completes a VirtToolkit operation with standardized logging and timing.

    .DESCRIPTION
        Stop-VirtToolkitOperation completes operation tracking with duration calculation
        and standardized completion logging.

    .PARAMETER Operation
        Operation object returned from Start-VirtToolkitOperation.

    .PARAMETER Success
        Whether the operation completed successfully. Default: $true

    .PARAMETER Message
        Optional custom completion message.

    .PARAMETER Results
        Optional results data to include in logging.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Returns operation summary with timing and results

    .EXAMPLE
        Stop-VirtToolkitOperation -Operation $operation -Success $true -Message "Exported 150 VMs"

        Description
        -----------
        Completes operation tracking with success status and custom message

    .EXAMPLE
        Stop-VirtToolkitOperation -Operation $operation -Success $false -Message "Connection failed"

        Description
        -----------
        Completes operation tracking with failure status
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Operation,

        [Parameter(Mandatory = $false)]
        [bool]$Success = $true,

        [Parameter(Mandatory = $false)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [object]$Results
    )

    $endTime = Get-Date
    $duration = $endTime - $Operation.StartTime

    $statusIcon = if ($Success) { "SUCCESS:" } else { "ERROR:" }
    $level = if ($Success) { "SUCCESS" } else { "ERROR" }
    
    $completionMessage = "$statusIcon Operation completed: $($Operation.OperationName)"
    
    if ($Message) {
        $completionMessage += " - $Message"
    }
    
    $completionMessage += " [Duration: $($duration.ToString('hh\:mm\:ss\.fff'))]"

    Write-VirtToolkitLog -Message $completionMessage -Level $level -ModuleName $Operation.ModuleName -LogFile $Operation.LogFile

    return [PSCustomObject]@{
        OperationId   = $Operation.OperationId
        OperationName = $Operation.OperationName
        ModuleName    = $Operation.ModuleName
        StartTime     = $Operation.StartTime
        EndTime       = $endTime
        Duration      = $duration
        Success       = $Success
        Message       = $Message
        Results       = $Results
    }
}

# Export module functions
Export-ModuleMember -Function Write-VirtToolkitLog, Get-VirtToolkitTimestamp, Start-VirtToolkitOperation, Stop-VirtToolkitOperation
