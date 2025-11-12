#Requires -Version 5.1

<#
.SYNOPSIS
    Initializes the VirtToolkit environment by validating and installing required PowerShell modules.

.DESCRIPTION
    This script performs first-time setup for the VirtToolkit by:
    - Validating PowerShell version requirements
    - Checking for and installing required PowerShell modules
    - Optionally installing Microsoft Graph modules for email functionality
    - Creating necessary directory structure
    - Generating detailed logs of the initialization process

    This should be the first script executed when setting up the toolkit.

.PARAMETER IncludeGraphModules
    If specified, also installs optional Microsoft Graph modules for email notifications.

.PARAMETER SkipModuleInstall
    If specified, only validates existing modules without attempting installation.

.PARAMETER Force
    If specified, reinstalls modules even if they are already present.

.PARAMETER LogPath
    Custom path for the initialization log file. If not specified, uses the default logs directory.

.EXAMPLE
    .\scripts\Initialize-Environment.ps1

    Description
    -----------
    Performs standard initialization with core modules only

.EXAMPLE
    .\scripts\Initialize-Environment.ps1 -IncludeGraphModules

    Description
    -----------
    Initializes environment including optional Microsoft Graph modules for email notifications

.EXAMPLE
    .\scripts\Initialize-Environment.ps1 -Force

    Description
    -----------
    Forces reinstallation of all modules even if they exist

.NOTES
    Part of VirtToolkit: Enterprise Virtualization Management Platform
    Requires: PowerShell 5.1 or higher
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$IncludeGraphModules,

    [Parameter(Mandatory = $false)]
    [switch]$SkipModuleInstall,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [string]$LogPath
)

# Script metadata
$ScriptVersion = "1.0.0"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ToolkitRoot = Split-Path -Parent $ScriptRoot

# Import VirtToolkit.Logging module if available
$LoggingModulePath = Join-Path $ToolkitRoot 'modules\VirtToolkit.Logging.psm1'
if (Test-Path $LoggingModulePath) {
    Import-Module $LoggingModulePath -Force -ErrorAction Stop
    $UseLoggingModule = $true
}
else {
    Write-Warning "VirtToolkit.Logging module not found at: $LoggingModulePath"
    $UseLoggingModule = $false
}

# Required PowerShell version
$RequiredPSVersion = [version]"5.1"

# Define required modules with minimum versions
$RequiredModules = @{
    'VMware.PowerCLI'                       = [version]'13.0.0'
    'Microsoft.PowerShell.SecretManagement' = [version]'1.1.0'
    'Microsoft.PowerShell.SecretStore'      = [version]'1.0.0'
    'ImportExcel'                           = [version]'7.0.0'
}

# Define optional modules (for email notifications)
$OptionalModules = @{
    'Microsoft.Graph.Authentication' = [version]'2.0.0'
    'Microsoft.Graph.Users.Actions'  = [version]'2.0.0'
}

#region Helper Functions

function Write-InitLog {
    <#
    .SYNOPSIS
        Wrapper for VirtToolkit logging with fallback for basic logging.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'SUCCESS', 'WARN', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO',
        
        [Parameter(Mandatory = $false)]
        [string]$LogFile
    )
    
    if ($UseLoggingModule) {
        # Use VirtToolkit.Logging module
        Write-VirtToolkitLog -Message $Message -Level $Level -LogFile $LogFile -ModuleName "Initialize-Environment"
    }
    else {
        # Fallback to basic logging if module not available during first-time setup
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $logLine = "$timestamp [Initialize-Environment] [$Level] $Message"
        
        $color = switch ($Level) {
            'INFO' { 'White' }
            'SUCCESS' { 'Green' }
            'WARN' { 'Yellow' }
            'ERROR' { 'Red' }
            'DEBUG' { 'Gray' }
            default { 'White' }
        }
        
        Write-Host $logLine -ForegroundColor $color
        
        if ($LogFile) {
            try {
                $logLine | Out-File -FilePath $LogFile -Append -Encoding UTF8 -ErrorAction Stop
            }
            catch {
                Write-Warning "Failed to write to log file: $($_.Exception.Message)"
            }
        }
    }
}

function Test-PowerShellVersion {
    <#
    .SYNOPSIS
        Validates PowerShell version meets minimum requirements.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [version]$RequiredVersion,
        
        [Parameter(Mandatory = $false)]
        [string]$LogFile
    )
    
    $currentVersion = $PSVersionTable.PSVersion
    Write-InitLog -Message "Current PowerShell version: $currentVersion" -Level 'INFO' -LogFile $LogFile
    Write-InitLog -Message "Required PowerShell version: $RequiredVersion" -Level 'INFO' -LogFile $LogFile
    
    if ($currentVersion -ge $RequiredVersion) {
        Write-InitLog -Message "PowerShell version check: PASSED" -Level 'SUCCESS' -LogFile $LogFile
        return $true
    }
    else {
        Write-InitLog -Message "PowerShell version check: FAILED" -Level 'ERROR' -LogFile $LogFile
        Write-InitLog -Message "Please upgrade to PowerShell $RequiredVersion or higher" -Level 'ERROR' -LogFile $LogFile
        Write-InitLog -Message "Download from: https://github.com/PowerShell/PowerShell/releases" -Level 'INFO' -LogFile $LogFile
        return $false
    }
}

function Test-ModuleInstalled {
    <#
    .SYNOPSIS
        Tests if a module is installed with the required minimum version.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,
        
        [Parameter(Mandatory = $true)]
        [version]$MinimumVersion,
        
        [Parameter(Mandatory = $false)]
        [string]$LogFile
    )
    
    try {
        $installedModule = Get-Module -Name $ModuleName -ListAvailable | 
        Sort-Object Version -Descending | 
        Select-Object -First 1
        
        if ($null -eq $installedModule) {
            Write-InitLog -Message "Module '$ModuleName' is NOT installed" -Level 'WARN' -LogFile $LogFile
            return $false
        }
        
        if ($installedModule.Version -ge $MinimumVersion) {
            Write-InitLog -Message "Module '$ModuleName' version $($installedModule.Version) (required: $MinimumVersion) - OK" -Level 'SUCCESS' -LogFile $LogFile
            return $true
        }
        else {
            Write-InitLog -Message "Module '$ModuleName' version $($installedModule.Version) is below minimum $MinimumVersion" -Level 'WARN' -LogFile $LogFile
            return $false
        }
    }
    catch {
        Write-InitLog -Message "Error checking module '$ModuleName': $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile
        return $false
    }
}

function Install-RequiredModule {
    <#
    .SYNOPSIS
        Installs a PowerShell module with error handling.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,
        
        [Parameter(Mandatory = $true)]
        [version]$MinimumVersion,
        
        [Parameter(Mandatory = $false)]
        [string]$LogFile,
        
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
    
    try {
        Write-InitLog -Message "Installing module '$ModuleName' (minimum version: $MinimumVersion)..." -Level 'INFO' -LogFile $LogFile
        
        $installParams = @{
            Name               = $ModuleName
            MinimumVersion     = $MinimumVersion
            Scope              = 'CurrentUser'
            Force              = $Force
            AllowClobber       = $true
            ErrorAction        = 'Stop'
            SkipPublisherCheck = $true
        }
        
        Install-Module @installParams
        
        # Verify installation
        $installed = Test-ModuleInstalled -ModuleName $ModuleName -MinimumVersion $MinimumVersion -LogFile $LogFile
        
        if ($installed) {
            Write-InitLog -Message "Successfully installed module '$ModuleName'" -Level 'SUCCESS' -LogFile $LogFile
            return $true
        }
        else {
            Write-InitLog -Message "Failed to verify installation of module '$ModuleName'" -Level 'ERROR' -LogFile $LogFile
            return $false
        }
    }
    catch {
        Write-InitLog -Message "Error installing module '$ModuleName': $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile
        return $false
    }
}

function Initialize-DirectoryStructure {
    <#
    .SYNOPSIS
        Creates required directory structure for the toolkit.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ToolkitRoot,
        
        [Parameter(Mandatory = $false)]
        [string]$LogFile
    )
    
    $directories = @(
        (Join-Path $ToolkitRoot 'logs')
        (Join-Path $ToolkitRoot 'output')
    )
    
    Write-InitLog -Message "Creating directory structure..." -Level 'INFO' -LogFile $LogFile
    
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            try {
                New-Item -Path $dir -ItemType Directory -Force | Out-Null
                Write-InitLog -Message "Created directory: $dir" -Level 'SUCCESS' -LogFile $LogFile
            }
            catch {
                Write-InitLog -Message "Failed to create directory '$dir': $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile
                return $false
            }
        }
        else {
            Write-InitLog -Message "Directory already exists: $dir" -Level 'INFO' -LogFile $LogFile
        }
    }
    
    return $true
}

#endregion

#region Main Script Execution

# Display banner
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                        VirtToolkit Environment Initialization                 " -ForegroundColor Cyan
Write-Host "                                  Version $ScriptVersion                        " -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Initialize log file
if (-not $LogPath) {
    $logsDir = Join-Path $ToolkitRoot 'logs'
    if (-not (Test-Path $logsDir)) {
        New-Item -Path $logsDir -ItemType Directory -Force | Out-Null
    }
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $LogPath = Join-Path $logsDir "Initialize-Environment_$timestamp.log"
}

Write-InitLog -Message "VirtToolkit Environment Initialization Started" -Level 'INFO' -LogFile $LogPath
Write-InitLog -Message "Toolkit Root: $ToolkitRoot" -Level 'INFO' -LogFile $LogPath
Write-InitLog -Message "Log File: $LogPath" -Level 'INFO' -LogFile $LogPath
Write-Host ""

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Write-InitLog -Message "Running with Administrator privileges" -Level 'INFO' -LogFile $LogPath
}
else {
    Write-InitLog -Message "Running without Administrator privileges (modules will install to CurrentUser scope)" -Level 'WARN' -LogFile $LogPath
}
Write-Host ""

# Step 1: Validate PowerShell Version
Write-Host "─────────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-InitLog -Message "Step 1: Validating PowerShell Version" -Level 'INFO' -LogFile $LogPath
Write-Host ""

$psVersionOK = Test-PowerShellVersion -RequiredVersion $RequiredPSVersion -LogFile $LogPath

if (-not $psVersionOK) {
    Write-Host ""
    Write-InitLog -Message "Environment initialization FAILED - PowerShell version requirements not met" -Level 'ERROR' -LogFile $LogPath
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    exit 1
}
Write-Host ""

# Step 2: Create Directory Structure
Write-Host "─────────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-InitLog -Message "Step 2: Creating Directory Structure" -Level 'INFO' -LogFile $LogPath
Write-Host ""

$dirStructureOK = Initialize-DirectoryStructure -ToolkitRoot $ToolkitRoot -LogFile $LogPath

if (-not $dirStructureOK) {
    Write-Host ""
    Write-InitLog -Message "Environment initialization FAILED - Could not create directory structure" -Level 'ERROR' -LogFile $LogPath
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    exit 1
}
Write-Host ""

# Step 3: Check and Install Required Modules
Write-Host "─────────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-InitLog -Message "Step 3: Validating and Installing Required PowerShell Modules" -Level 'INFO' -LogFile $LogPath
Write-Host ""

$modulesOK = $true
$modulesToInstall = @()

foreach ($module in $RequiredModules.GetEnumerator()) {
    $moduleName = $module.Key
    $minVersion = $module.Value
    
    $isInstalled = Test-ModuleInstalled -ModuleName $moduleName -MinimumVersion $minVersion -LogFile $LogPath
    
    if (-not $isInstalled -or $Force) {
        if ($Force) {
            Write-InitLog -Message "Module '$moduleName' will be reinstalled (Force mode)" -Level 'INFO' -LogFile $LogPath
        }
        $modulesToInstall += @{Name = $moduleName; Version = $minVersion }
    }
}

if ($modulesToInstall.Count -eq 0 -and -not $SkipModuleInstall) {
    Write-InitLog -Message "All required modules are already installed" -Level 'SUCCESS' -LogFile $LogPath
}
elseif ($SkipModuleInstall) {
    Write-InitLog -Message "Skipping module installation (SkipModuleInstall specified)" -Level 'WARN' -LogFile $LogPath
    if ($modulesToInstall.Count -gt 0) {
        Write-InitLog -Message "WARNING: $($modulesToInstall.Count) module(s) missing or need updates" -Level 'WARN' -LogFile $LogPath
        $modulesOK = $false
    }
}
else {
    Write-Host ""
    Write-InitLog -Message "Installing $($modulesToInstall.Count) module(s)..." -Level 'INFO' -LogFile $LogPath
    Write-Host ""
    
    foreach ($moduleInfo in $modulesToInstall) {
        $installSuccess = Install-RequiredModule -ModuleName $moduleInfo.Name -MinimumVersion $moduleInfo.Version -LogFile $LogPath -Force:$Force
        if (-not $installSuccess) {
            $modulesOK = $false
            Write-InitLog -Message "Failed to install required module: $($moduleInfo.Name)" -Level 'ERROR' -LogFile $LogPath
        }
        Write-Host ""
    }
}

Write-Host ""

# Step 4: Optional Microsoft Graph Modules
if ($IncludeGraphModules) {
    Write-Host "─────────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
    Write-InitLog -Message "Step 4: Installing Optional Microsoft Graph Modules" -Level 'INFO' -LogFile $LogPath
    Write-Host ""
    
    $graphModulesToInstall = @()
    
    foreach ($module in $OptionalModules.GetEnumerator()) {
        $moduleName = $module.Key
        $minVersion = $module.Value
        
        $isInstalled = Test-ModuleInstalled -ModuleName $moduleName -MinimumVersion $minVersion -LogFile $LogPath
        
        if (-not $isInstalled -or $Force) {
            $graphModulesToInstall += @{Name = $moduleName; Version = $minVersion }
        }
    }
    
    if ($graphModulesToInstall.Count -eq 0 -and -not $SkipModuleInstall) {
        Write-InitLog -Message "All optional Graph modules are already installed" -Level 'SUCCESS' -LogFile $LogPath
    }
    elseif (-not $SkipModuleInstall) {
        Write-Host ""
        Write-InitLog -Message "Installing $($graphModulesToInstall.Count) optional Graph module(s)..." -Level 'INFO' -LogFile $LogPath
        Write-Host ""
        
        foreach ($moduleInfo in $graphModulesToInstall) {
            $installSuccess = Install-RequiredModule -ModuleName $moduleInfo.Name -MinimumVersion $moduleInfo.Version -LogFile $LogPath -Force:$Force
            if (-not $installSuccess) {
                Write-InitLog -Message "Warning: Failed to install optional module: $($moduleInfo.Name)" -Level 'WARN' -LogFile $LogPath
            }
            Write-Host ""
        }
    }
    
    Write-Host ""
}
else {
    Write-Host "─────────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
    Write-InitLog -Message "Step 4: Skipping Optional Microsoft Graph Modules" -Level 'INFO' -LogFile $LogPath
    Write-InitLog -Message "To install Graph modules for email notifications, run with -IncludeGraphModules" -Level 'INFO' -LogFile $LogPath
    Write-Host ""
}

# Final Summary
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

if ($modulesOK) {
    Write-InitLog -Message "Environment initialization COMPLETED SUCCESSFULLY" -Level 'SUCCESS' -LogFile $LogPath
    Write-Host ""
    Write-InitLog -Message "Next Steps:" -Level 'INFO' -LogFile $LogPath
    Write-InitLog -Message "1. Copy shared/Configuration.example.psd1 to shared/Configuration.psd1" -Level 'INFO' -LogFile $LogPath
    Write-InitLog -Message "2. Edit shared/Configuration.psd1 with your vCenter details" -Level 'INFO' -LogFile $LogPath
    Write-InitLog -Message "3. Run scripts to interact with your vSphere environment" -Level 'INFO' -LogFile $LogPath
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    exit 0
}
else {
    Write-InitLog -Message "Environment initialization COMPLETED WITH ERRORS" -Level 'ERROR' -LogFile $LogPath
    Write-Host ""
    Write-InitLog -Message "Please review the errors above and the log file:" -Level 'ERROR' -LogFile $LogPath
    Write-InitLog -Message "$LogPath" -Level 'INFO' -LogFile $LogPath
    Write-Host ""
    Write-InitLog -Message "Common solutions:" -Level 'INFO' -LogFile $LogPath
    Write-InitLog -Message "- Ensure you have internet connectivity for module downloads" -Level 'INFO' -LogFile $LogPath
    Write-InitLog -Message "- Try running as Administrator if installation fails" -Level 'INFO' -LogFile $LogPath
    Write-InitLog -Message "- Check PowerShell Gallery availability: Test-NetConnection -ComputerName www.powershellgallery.com -Port 443" -Level 'INFO' -LogFile $LogPath
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    exit 1
}

#endregion
