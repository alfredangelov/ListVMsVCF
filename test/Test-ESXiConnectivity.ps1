#Requires -Version 5.1

<#
.SYNOPSIS
    Tests ESXi host connectivity using VirtToolkit modules.

.DESCRIPTION
    This test script validates direct ESXi host connectivity by:
    - Loading configuration from Configuration.psd1
    - Prompting for ESXi hostname
    - Retrieving credentials using the new server-centric pattern
    - Connecting to ESXi host
    - Retrieving basic host information
    - Disconnecting cleanly

.PARAMETER ESXiHost
    Optional ESXi hostname or IP address. If not provided, will prompt.

.NOTES
    Part of VirtToolkit: Enterprise Virtualization Management Platform
    Test script for validating ESXi connectivity and credential management
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ESXiHost
)

# Script setup
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ToolkitRoot = Split-Path -Parent $ScriptRoot

# Initialize log file
$LogsDir = Join-Path $ToolkitRoot 'logs'
if (-not (Test-Path $LogsDir)) {
    New-Item -Path $LogsDir -ItemType Directory -Force | Out-Null
}
$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$LogFile = Join-Path $LogsDir "Test-ESXi_$Timestamp.log"

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                    VirtToolkit ESXi Connectivity Test                         " -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Import modules
try {
    Write-Host "Loading VirtToolkit modules..." -ForegroundColor Yellow
    Import-Module (Join-Path $ToolkitRoot 'modules\VirtToolkit.Logging.psm1') -Force -ErrorAction Stop
    Import-Module (Join-Path $ToolkitRoot 'modules\VirtToolkit.Credentials.psm1') -Force -ErrorAction Stop
    Write-Host "Modules loaded successfully" -ForegroundColor Green
    Write-VirtToolkitLog -Message "VirtToolkit modules loaded successfully" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "Test-ESXi"
    Write-Host ""
}
catch {
    Write-Host "Failed to load modules: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Load configuration
$ConfigPath = Join-Path $ToolkitRoot 'shared\config\Configuration.psd1'
Write-Host "Loading configuration from: $ConfigPath" -ForegroundColor Yellow
Write-VirtToolkitLog -Message "Loading configuration from: $ConfigPath" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-ESXi"
try {
    $Config = Import-PowerShellDataFile -Path $ConfigPath -ErrorAction Stop
    Write-Host "Configuration loaded" -ForegroundColor Green
    Write-VirtToolkitLog -Message "Configuration loaded successfully" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "Test-ESXi"
    Write-Host ""
}
catch {
    Write-Host "Failed to load configuration: $($_.Exception.Message)" -ForegroundColor Red
    Write-VirtToolkitLog -Message "Failed to load configuration: $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile -ModuleName "Test-ESXi"
    exit 1
}

# Get ESXi hostname
if (-not $ESXiHost) {
    Write-Host "Enter ESXi hostname or IP address:" -ForegroundColor Yellow
    $ESXiHost = Read-Host "ESXi Host"
    Write-Host ""
}

# Extract vault settings
$VaultName = $Config.preferredVault
$PreferredUsername = $Config.PreferredUsername

Write-Host "Configuration Details:" -ForegroundColor Cyan
Write-Host "  ESXi Host: $ESXiHost" -ForegroundColor White
Write-Host "  Vault: $VaultName" -ForegroundColor White
Write-Host "  Preferred Username: $PreferredUsername" -ForegroundColor White
Write-Host ""

# Import VMware PowerCLI
try {
    Write-Host "Loading VMware PowerCLI..." -ForegroundColor Yellow
    Import-Module VMware.VimAutomation.Core -ErrorAction Stop
    Write-Host "PowerCLI loaded" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "Failed to load PowerCLI: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Run Initialize-Environment.ps1 to install required modules" -ForegroundColor Yellow
    exit 1
}

# Configure PowerCLI settings
if ($Config.IgnoreSSLCertificates) {
    Write-Host "Configuring PowerCLI to ignore SSL certificates..." -ForegroundColor Yellow
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
    Write-Host "SSL certificate validation disabled" -ForegroundColor Green
    Write-Host ""
}

# Retrieve credentials
Write-Host "───────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "Retrieving credentials for $ESXiHost..." -ForegroundColor Yellow
try {
    # For ESXi, credentials might be different than vCenter
    # First try to get ESXi-specific credential, fall back to vSphere pattern
    $Credential = Get-VirtToolkitCredential -Server $ESXiHost -PreferredUsername $PreferredUsername -VaultName $VaultName
    
    if ($Credential) {
        Write-Host "Credential retrieved: $($Credential.UserName)" -ForegroundColor Green
    }
    else {
        Write-Host "Failed to retrieve credential" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "Credential retrieval failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Connect to ESXi
Write-Host "───────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "Connecting to ESXi host: $ESXiHost" -ForegroundColor Yellow
try {
    $Connection = Connect-VIServer -Server $ESXiHost -Credential $Credential -ErrorAction Stop
    Write-Host "Successfully connected to ESXi host" -ForegroundColor Green
    Write-Host "  Server: $($Connection.Name)" -ForegroundColor White
    Write-Host "  Version: $($Connection.Version)" -ForegroundColor White
    Write-Host "  Build: $($Connection.Build)" -ForegroundColor White
    Write-Host "  User: $($Connection.User)" -ForegroundColor White
    Write-Host "  Session ID: $($Connection.SessionId)" -ForegroundColor White
}
catch {
    Write-Host "Connection failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Test basic operations
Write-Host "───────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "Testing ESXi operations..." -ForegroundColor Yellow
try {
    # Get host information
    $VMHost = Get-VMHost -ErrorAction Stop
    Write-Host "Retrieved host information" -ForegroundColor Green
    Write-Host "  Hostname: $($VMHost.Name)" -ForegroundColor White
    Write-Host "  Version: $($VMHost.Version)" -ForegroundColor White
    Write-Host "  Build: $($VMHost.Build)" -ForegroundColor White
    Write-Host "  Manufacturer: $($VMHost.Manufacturer)" -ForegroundColor White
    Write-Host "  Model: $($VMHost.Model)" -ForegroundColor White
    Write-Host "  CPU: $($VMHost.ProcessorType)" -ForegroundColor White
    Write-Host "  CPU Cores: $($VMHost.NumCpu)" -ForegroundColor White
    Write-Host "  Memory (GB): $([math]::Round($VMHost.MemoryTotalGB, 2))" -ForegroundColor White
    Write-Host "  Power State: $($VMHost.PowerState)" -ForegroundColor White
    Write-Host "  Connection State: $($VMHost.ConnectionState)" -ForegroundColor White
    Write-Host ""
    
    # Get VM count on this host
    $VMs = Get-VM -ErrorAction Stop
    Write-Host "Retrieved VM information" -ForegroundColor Green
    Write-Host "  VMs on this host: $($VMs.Count)" -ForegroundColor White
    
    if ($VMs.Count -gt 0) {
        Write-Host "  Sample VMs:" -ForegroundColor White
        $VMs | Select-Object -First 5 | ForEach-Object {
            Write-Host "    - $($_.Name) - $($_.PowerState)" -ForegroundColor Cyan
        }
    }
    Write-Host ""
    
    # Get datastore information
    $Datastores = Get-Datastore -ErrorAction Stop
    Write-Host "Retrieved datastore information" -ForegroundColor Green
    Write-Host "  Datastores: $($Datastores.Count)" -ForegroundColor White
    
    foreach ($ds in $Datastores) {
        $freeSpaceGB = [math]::Round($ds.FreeSpaceGB, 2)
        $capacityGB = [math]::Round($ds.CapacityGB, 2)
        $percentFree = [math]::Round(($ds.FreeSpaceGB / $ds.CapacityGB) * 100, 1)
        Write-Host "    - $($ds.Name): ${freeSpaceGB}GB free / ${capacityGB}GB total (${percentFree}% free)" -ForegroundColor Cyan
    }
}
catch {
    Write-Host "Operation failed: $($_.Exception.Message)" -ForegroundColor Red
    Disconnect-VIServer -Server $Connection -Confirm:$false -ErrorAction SilentlyContinue
    exit 1
}
Write-Host ""

# Disconnect
Write-Host "───────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "Disconnecting from ESXi host..." -ForegroundColor Yellow
try {
    Disconnect-VIServer -Server $Connection -Confirm:$false -ErrorAction Stop
    Write-Host "Disconnected successfully" -ForegroundColor Green
}
catch {
    Write-Host "Disconnect warning: $($_.Exception.Message)" -ForegroundColor Yellow
}
Write-Host ""

# Summary
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                          Test Completed Successfully                          " -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-VirtToolkitLog -Message "ESXi connectivity test completed successfully" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "Test-ESXi"
Write-VirtToolkitLog -Message "Log file: $LogFile" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-ESXi"

exit 0
