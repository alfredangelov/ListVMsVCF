#Requires -Version 5.1

<#
.SYNOPSIS
    Tests vSphere (vCenter) connectivity using VirtToolkit modules.

.DESCRIPTION
    This test script validates vCenter connectivity by:
    - Loading configuration from Configuration.psd1
    - Retrieving credentials using the new server-centric pattern
    - Connecting to vCenter server
    - Retrieving basic datacenter information
    - Disconnecting cleanly

.NOTES
    Part of VirtToolkit: Enterprise Virtualization Management Platform
    Test script for validating vCenter connectivity and credential management
#>

[CmdletBinding()]
param()

# Script setup
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ToolkitRoot = Split-Path -Parent $ScriptRoot

# Initialize log file
$LogsDir = Join-Path $ToolkitRoot 'logs'
if (-not (Test-Path $LogsDir)) {
    New-Item -Path $LogsDir -ItemType Directory -Force | Out-Null
}
$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$LogFile = Join-Path $LogsDir "Test-VSphere_$Timestamp.log"

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                   VirtToolkit vSphere Connectivity Test                       " -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Import modules
try {
    Write-Host "Loading VirtToolkit modules..." -ForegroundColor Yellow
    Import-Module (Join-Path $ToolkitRoot 'modules\VirtToolkit.Logging.psm1') -Force -ErrorAction Stop
    Import-Module (Join-Path $ToolkitRoot 'modules\VirtToolkit.Credentials.psm1') -Force -ErrorAction Stop
    Write-Host "Modules loaded successfully" -ForegroundColor Green
    Write-VirtToolkitLog -Message "VirtToolkit modules loaded successfully" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "Test-VSphere"
    Write-Host ""
}
catch {
    Write-Host "Failed to load modules: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Load configuration
$ConfigPath = Join-Path $ToolkitRoot 'shared\config\Configuration.psd1'
Write-Host "Loading configuration from: $ConfigPath" -ForegroundColor Yellow
Write-VirtToolkitLog -Message "Loading configuration from: $ConfigPath" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-VSphere"
try {
    $Config = Import-PowerShellDataFile -Path $ConfigPath -ErrorAction Stop
    Write-Host "Configuration loaded" -ForegroundColor Green
    Write-VirtToolkitLog -Message "Configuration loaded successfully" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "Test-VSphere"
    Write-Host ""
}
catch {
    Write-Host "Failed to load configuration: $($_.Exception.Message)" -ForegroundColor Red
    Write-VirtToolkitLog -Message "Failed to load configuration: $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile -ModuleName "Test-VSphere"
    exit 1
}

# Extract vCenter server and vault settings
$vCenterServer = $Config.SourceServerHost
$VaultName = $Config.preferredVault
$PreferredUsername = $Config.PreferredUsername

Write-Host "Configuration Details:" -ForegroundColor Cyan
Write-Host "  vCenter Server: $vCenterServer" -ForegroundColor White
Write-Host "  Vault: $VaultName" -ForegroundColor White
Write-Host "  Preferred Username: $PreferredUsername" -ForegroundColor White
Write-Host ""

# Import VMware PowerCLI
try {
    Write-Host "Loading VMware PowerCLI..." -ForegroundColor Yellow
    Write-VirtToolkitLog -Message "Loading VMware PowerCLI module" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-VSphere"
    Import-Module VMware.VimAutomation.Core -ErrorAction Stop
    Write-Host "PowerCLI loaded" -ForegroundColor Green
    Write-VirtToolkitLog -Message "PowerCLI module loaded successfully" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "Test-VSphere"
    Write-Host ""
}
catch {
    Write-Host "Failed to load PowerCLI: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Run Initialize-Environment.ps1 to install required modules" -ForegroundColor Yellow
    Write-VirtToolkitLog -Message "Failed to load PowerCLI: $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile -ModuleName "Test-VSphere"
    exit 1
}

# Configure PowerCLI settings
if ($Config.IgnoreSSLCertificates) {
    Write-Host "Configuring PowerCLI to ignore SSL certificates..." -ForegroundColor Yellow
    Write-VirtToolkitLog -Message "Configuring PowerCLI to ignore SSL certificates" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-VSphere"
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
    Write-Host "SSL certificate validation disabled" -ForegroundColor Green
    Write-Host ""
}

# Retrieve credentials
Write-Host "───────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "Retrieving credentials for $vCenterServer..." -ForegroundColor Yellow
Write-VirtToolkitLog -Message "Retrieving credentials for server: $vCenterServer" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-VSphere"
try {
    $Credential = Get-VirtToolkitCredential -Server $vCenterServer -PreferredUsername $PreferredUsername -VaultName $VaultName
    
    if ($Credential) {
        Write-Host "Credential retrieved: $($Credential.UserName)" -ForegroundColor Green
        Write-VirtToolkitLog -Message "Credential retrieved for user: $($Credential.UserName)" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "Test-VSphere"
    }
    else {
        Write-Host "Failed to retrieve credential" -ForegroundColor Red
        Write-VirtToolkitLog -Message "Failed to retrieve credential" -Level 'ERROR' -LogFile $LogFile -ModuleName "Test-VSphere"
        exit 1
    }
}
catch {
    Write-Host "Credential retrieval failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-VirtToolkitLog -Message "Credential retrieval failed: $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile -ModuleName "Test-VSphere"
    exit 1
}
Write-Host ""

# Connect to vCenter
Write-Host "───────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "Connecting to vCenter: $vCenterServer" -ForegroundColor Yellow
Write-VirtToolkitLog -Message "Attempting connection to vCenter: $vCenterServer" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-VSphere"
try {
    $Connection = Connect-VIServer -Server $vCenterServer -Credential $Credential -ErrorAction Stop
    Write-Host "Successfully connected to vCenter" -ForegroundColor Green
    Write-VirtToolkitLog -Message "Successfully connected to vCenter: $($Connection.Name) (Version: $($Connection.Version))" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "Test-VSphere"
    Write-Host "  Server: $($Connection.Name)" -ForegroundColor White
    Write-Host "  Version: $($Connection.Version)" -ForegroundColor White
    Write-Host "  Build: $($Connection.Build)" -ForegroundColor White
    Write-Host "  User: $($Connection.User)" -ForegroundColor White
    Write-Host "  Session ID: $($Connection.SessionId)" -ForegroundColor White
}
catch {
    Write-Host "Connection failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-VirtToolkitLog -Message "Connection failed: $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile -ModuleName "Test-VSphere"
    exit 1
}
Write-Host ""

# Test basic operations
Write-Host "───────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "Testing vCenter operations..." -ForegroundColor Yellow
Write-VirtToolkitLog -Message "Testing vCenter operations" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-VSphere"
try {
    # Get datacenter information
    $Datacenters = Get-Datacenter -ErrorAction Stop
    Write-Host "Retrieved datacenter information" -ForegroundColor Green
    Write-VirtToolkitLog -Message "Retrieved datacenter information: $($Datacenters.Count) datacenter(s) found" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "Test-VSphere"
    Write-Host "  Datacenters found: $($Datacenters.Count)" -ForegroundColor White
    
    foreach ($dc in $Datacenters) {
        Write-Host "    - $($dc.Name)" -ForegroundColor Cyan
    }
    Write-Host ""
    
    # Get cluster information
    $Clusters = Get-Cluster -ErrorAction Stop
    Write-Host "Retrieved cluster information" -ForegroundColor Green
    Write-VirtToolkitLog -Message "Retrieved cluster information: $($Clusters.Count) cluster(s) found" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "Test-VSphere"
    Write-Host "  Clusters found: $($Clusters.Count)" -ForegroundColor White
    
    foreach ($cluster in $Clusters) {
        Write-Host "    - $($cluster.Name)" -ForegroundColor Cyan
    }
    Write-Host ""
    
    # Get VM count
    $VMCount = (Get-VM -ErrorAction Stop).Count
    Write-Host "Retrieved VM information" -ForegroundColor Green
    Write-VirtToolkitLog -Message "Retrieved VM information: $VMCount total VMs" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "Test-VSphere"
    Write-Host "  Total VMs: $VMCount" -ForegroundColor White
}
catch {
    Write-Host "Operation failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-VirtToolkitLog -Message "vCenter operations failed: $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile -ModuleName "Test-VSphere"
    Disconnect-VIServer -Server $Connection -Confirm:$false -ErrorAction SilentlyContinue
    exit 1
}
Write-Host ""

# Disconnect
Write-Host "───────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "Disconnecting from vCenter..." -ForegroundColor Yellow
Write-VirtToolkitLog -Message "Disconnecting from vCenter: $vCenterServer" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-VSphere"
try {
    Disconnect-VIServer -Server $Connection -Confirm:$false -ErrorAction Stop
    Write-Host "Disconnected successfully" -ForegroundColor Green
    Write-VirtToolkitLog -Message "Disconnected successfully from vCenter" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "Test-VSphere"
}
catch {
    Write-Host "Disconnect warning: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-VirtToolkitLog -Message "Disconnect warning: $($_.Exception.Message)" -Level 'WARN' -LogFile $LogFile -ModuleName "Test-VSphere"
}
Write-Host ""

# Summary
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                          Test Completed Successfully                          " -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-VirtToolkitLog -Message "vSphere connectivity test completed successfully" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "Test-VSphere"
Write-VirtToolkitLog -Message "Log file: $LogFile" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-VSphere"

exit 0
