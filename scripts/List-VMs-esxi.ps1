#Requires -Version 5.1

<#
.SYNOPSIS
    List VMs from ESXi host and export to Excel
.DESCRIPTION
    This script connects directly to an ESXi host, retrieves all VMs, and exports the data to Excel
.AUTHOR
    VM Listing Toolkit
.VERSION
    1.0.0
.PARAMETER ConfigPath
    Path to the configuration file (default: ..\shared\Configuration.psd1)
.PARAMETER OutputPath
    Directory where the Excel file will be saved (default: .\output)
.PARAMETER DryRun
    If specified, overrides the DryRun setting in configuration to true
.PARAMETER Force
    If specified, skips environment validation
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Get script directory and set up paths
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulePath = Join-Path -Path $ScriptRoot -ChildPath "..\modules"

if (-not $ConfigPath) {
    $ConfigPath = Join-Path -Path $ScriptRoot -ChildPath "..\shared\Configuration.psd1"
}

if (-not $OutputPath) {
    $OutputPath = Join-Path -Path $ScriptRoot -ChildPath "..\output"
}

# Function to import modules safely
function Import-ToolkitModule {
    param([string]$ModuleName)

    $ModuleFile = Join-Path -Path $ModulePath -ChildPath "$ModuleName.psm1"
    if (-not (Test-Path -Path $ModuleFile)) {
        throw "Cannot find module file: $ModuleFile"
    }

    try {
        Import-Module -Name $ModuleFile -Force -Global
        return $true
    }
    catch {
        Write-Error "Failed to import module '$ModuleName': $($_.Exception.Message)"
        return $false
    }
}

# Display banner
Write-Host @"
╔════════════════════════════════════════════════════════════════════════════════╗
║                           VM Listing Toolkit                                  ║
║                        ESXi Host VM Listing Script                            ║
╚════════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Host ""

try {
    # Load toolkit modules
    Write-Host "Loading toolkit modules..." -ForegroundColor Blue
    $moduleLoadResults = @{
        EnvironmentValidator = Import-ToolkitModule -ModuleName "EnvironmentValidator"
        vSphereConnector = Import-ToolkitModule -ModuleName "vSphereConnector"
        ExcelExporter = Import-ToolkitModule -ModuleName "ExcelExporter"
    }

    $failedModules = $moduleLoadResults.GetEnumerator() | Where-Object { -not $_.Value } | Select-Object -ExpandProperty Key
    if ($failedModules.Count -gt 0) {
        throw "Failed to load required modules: $($failedModules -join ', ')"
    }

    Write-Host "✓ All modules loaded successfully" -ForegroundColor Green
    Write-Host ""

    # Validate environment (unless forced to skip)
    if (-not $Force) {
        Write-Host "Validating environment..." -ForegroundColor Blue
        $envStatus = Get-EnvironmentStatus

        if (-not $envStatus.PowerShellVersionOK) {
            throw "PowerShell version $($envStatus.PowerShellVersion) is below minimum requirement"
        }

        if (-not $envStatus.AllModulesOK) {
            $missingModules = $envStatus.Modules.GetEnumerator() | Where-Object { -not $_.Value.OK } | Select-Object -ExpandProperty Key
            throw "Required modules missing or outdated: $($missingModules -join ', ')"
        }

        Write-Host "✓ Environment validation passed" -ForegroundColor Green
        Write-Host ""
    }

    # Load configuration
    Write-Host "Loading configuration..." -ForegroundColor Blue
    if (-not (Test-Path -Path $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }

    try {
        $config = Import-PowerShellDataFile -Path $ConfigPath
    }
    catch {
        throw "Failed to load configuration file: $($_.Exception.Message)"
    }

    # Override DryRun if specified in parameters
    if ($DryRun) {
        $config.DryRun = $true
    }

    Write-Host "✓ Configuration loaded from: $ConfigPath" -ForegroundColor Green
    Write-Host ""

    Write-Host "Configuration Summary:" -ForegroundColor Cyan
    Write-Host "  ESXi Host: $($config.SourceServerHost)" -ForegroundColor White
    Write-Host "  DryRun Mode: $($config.DryRun)" -ForegroundColor White
    Write-Host "  Properties to Export: $($config.VMProperties.Count)" -ForegroundColor White
    Write-Host ""

    # Create output directory if it doesn't exist
    if (-not (Test-Path -Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        Write-Host "✓ Created output directory: $OutputPath" -ForegroundColor Green
    }

    # Generate Excel filename with server hostname for ESXi
    # Extract hostname from FQDN and clean it for filename use
    $serverHostname = $config.SourceServerHost -split '\.' | Select-Object -First 1
    # Remove any characters that aren't safe for filenames
    $cleanHostname = $serverHostname -replace '[^\w\-]', '-'
    $filePrefix = "VMList_ESXi_$cleanHostname"

    $excelFilePath = New-ExcelFileName -BasePath $OutputPath -Prefix $filePrefix
    Write-Host "Excel file will be saved as: $excelFilePath" -ForegroundColor Gray
    Write-Host ""

    # Connect to ESXi host
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "Connecting to ESXi host..." -ForegroundColor Blue

    if (-not (Connect-vSphereServer -ServerHost $config.SourceServerHost -CredentialName $config.CredentialName -VaultName $config.preferredVault -IgnoreSSLCertificates $config.IgnoreSSLCertificates)) {
        throw "Failed to connect to ESXi host: $($config.SourceServerHost)"
    }

    Write-Host ""

    # Get VMs directly from ESXi host
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    $vmData = Get-VMsFromESXiHost -Properties $config.VMProperties

    if ($vmData.Count -eq 0) {
        Write-Warning "No VMs found on the ESXi host. Nothing to export."
        Disconnect-vSphereServer
        exit 0
    }

    Write-Host ""

    # Export to Excel
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan

    if ($config.DryRun) {
        Write-Host "🔍 DRY RUN MODE - No files will be created" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Would export $($vmData.Count) VMs with the following properties:" -ForegroundColor Yellow
        foreach ($property in $config.VMProperties) {
            Write-Host "  • $property" -ForegroundColor Gray
        }
        Write-Host ""
        Write-Host "Excel file would be saved as: $excelFilePath" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Sample VM data (first 3 VMs):" -ForegroundColor Yellow

        $sampleVMs = $vmData | Select-Object -First 3
        foreach ($vm in $sampleVMs) {
            Write-Host "  VM: $($vm.Name)" -ForegroundColor White
            foreach ($property in $config.VMProperties) {
                $value = if ($null -ne $vm.$property) { $vm.$property } else { "NULL" }
                Write-Host "    ${property}: $value" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "📊 Exporting $($vmData.Count) VMs to Excel..." -ForegroundColor Blue

        # Export using simplified Excel export for ESXi (no datacenter/folder context)
        $exportSuccess = Export-VMsToExcelSimple -VMData $vmData -FilePath $excelFilePath -SourceServerHost $config.SourceServerHost -DataCenter "ESXi Host" -VMFolder "All VMs" -Properties $config.VMProperties

        if ($exportSuccess) {
            Write-Host "✓ Successfully exported VM data to: $excelFilePath" -ForegroundColor Green
            Write-Host ""
            Write-Host "Export Summary:" -ForegroundColor Cyan
            Write-Host "  VMs Exported: $($vmData.Count)" -ForegroundColor White
            Write-Host "  Properties: $($config.VMProperties.Count)" -ForegroundColor White
            Write-Host "  File: $excelFilePath" -ForegroundColor White
        } else {
            throw "Failed to export VM data to Excel"
        }
    }

    Write-Host ""

    # Disconnect from ESXi host
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "Disconnecting from ESXi host..." -ForegroundColor Blue
    Disconnect-vSphereServer
    Write-Host "✓ Disconnected from ESXi host" -ForegroundColor Green

    Write-Host ""
    Write-Host "🎉 ESXi VM listing completed successfully!" -ForegroundColor Green

    return $true
}
catch {
    Write-Host ""
    Write-Host "❌ Error occurred during ESXi VM listing:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""

    # Ensure we disconnect from any servers
    try {
        Disconnect-vSphereServer
    }
    catch {
        # Ignore disconnection errors during cleanup
        Write-Verbose "Disconnection cleanup error (ignored): $($_.Exception.Message)"
    }

    exit 1
}

