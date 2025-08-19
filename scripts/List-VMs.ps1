#Requires -Version 5.1

<#
.SYNOPSIS
    List VMs from vSphere and export to Excel
.DESCRIPTION
    This script connects to vSphere, retrieves VMs from a specified folder, and exports the data to Excel
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
    
    $modulePath = Join-Path -Path $ModulePath -ChildPath "$ModuleName.psm1"
    if (-not (Test-Path -Path $modulePath)) {
        throw "Cannot find module '$ModuleName' at: $modulePath"
    }
    
    Import-Module -Name $modulePath -Force
    Write-Verbose "Imported module: $ModuleName"
}

# Display banner
Write-Host @"
╔════════════════════════════════════════════════════════════════════════════════╗
║                           VM Listing Toolkit                                  ║
║                            List VMs Script                                    ║
╚════════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Host ""

try {
    # Import required modules
    Write-Host "Loading toolkit modules..." -ForegroundColor Blue
    Import-ToolkitModule -ModuleName "EnvironmentValidator"
    Import-ToolkitModule -ModuleName "vSphereConnector" 
    Import-ToolkitModule -ModuleName "ExcelExporter"
    Write-Host "✓ All modules loaded successfully" -ForegroundColor Green
    Write-Host ""
    
    # Validate environment unless forced to skip
    if (-not $Force) {
        Write-Host "Validating environment..." -ForegroundColor Blue
        $envStatus = Get-EnvironmentStatus
        
        if (-not ($envStatus.PowerShellVersionOK -and $envStatus.AllModulesOK)) {
            Write-Host "❌ Environment validation failed!" -ForegroundColor Red
            Write-Host "Please run .\scripts\Initialize-Environment.ps1 first, or use -Force to skip validation" -ForegroundColor Yellow
            exit 1
        }
        Write-Host "✓ Environment validation passed" -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host "⚠ Skipping environment validation (Force mode)" -ForegroundColor Yellow
        Write-Host ""
    }
    
    # Load configuration
    Write-Host "Loading configuration..." -ForegroundColor Blue
    if (-not (Test-Path -Path $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }
    
    $config = Import-PowerShellDataFile -Path $ConfigPath
    Write-Host "✓ Configuration loaded from: $ConfigPath" -ForegroundColor Green
    
    # Override DryRun if specified
    if ($DryRun) {
        $config.DryRun = $true
        Write-Host "ℹ DryRun mode enabled via parameter" -ForegroundColor Yellow
    }
    
    # Display configuration summary
    Write-Host ""
    Write-Host "Configuration Summary:" -ForegroundColor Cyan
    Write-Host "  vCenter Server: $($config.SourceServerHost)" -ForegroundColor White
    Write-Host "  Datacenter: $($config.dataCenter)" -ForegroundColor White
    Write-Host "  VM Folder: $($config.VMFolder)" -ForegroundColor White
    Write-Host "  DryRun Mode: $($config.DryRun)" -ForegroundColor White
    Write-Host "  Properties to Export: $($config.VMProperties.Count)" -ForegroundColor White
    Write-Host ""
    
    # Create output directory if it doesn't exist
    if (-not (Test-Path -Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        Write-Host "✓ Created output directory: $OutputPath" -ForegroundColor Green
    }
    
    # Generate Excel filename with server hostname
    # Extract hostname from FQDN and clean it for filename use
    $serverHostname = $config.SourceServerHost -split '\.' | Select-Object -First 1
    # Remove any characters that aren't safe for filenames
    $cleanHostname = $serverHostname -replace '[^\w\-]', '-'
    $filePrefix = "VMList_$cleanHostname"
    
    $excelFilePath = New-ExcelFileName -BasePath $OutputPath -Prefix $filePrefix
    Write-Host "Excel file will be saved as: $excelFilePath" -ForegroundColor Gray
    Write-Host ""
    
    # Connect to vSphere
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "Connecting to vSphere..." -ForegroundColor Blue
    
    if (-not (Connect-vSphereServer -ServerHost $config.SourceServerHost -CredentialName $config.CredentialName -VaultName $config.preferredVault -IgnoreSSLCertificates $config.IgnoreSSLCertificates)) {
        throw "Failed to connect to vSphere server: $($config.SourceServerHost)"
    }
    
    Write-Host ""
    
    # Get VMs from folder
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    $vmData = Get-VMsFromFolder -DataCenter $config.dataCenter -VMFolder $config.VMFolder -Properties $config.VMProperties
    
    if ($vmData.Count -eq 0) {
        Write-Warning "No VMs found in the specified folder. Nothing to export."
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
                $value = if ($vm.ContainsKey($property)) { $vm[$property] } else { "NULL" }
                if ($value.ToString().Length -gt 50) {
                    $value = $value.ToString().Substring(0, 47) + "..."
                }
                Write-Host "    $property`: $value" -ForegroundColor Gray
            }
            Write-Host ""
        }
    } else {
        $exportSuccess = Export-VMsToExcelSimple -VMData $vmData -FilePath $excelFilePath -SourceServerHost $config.SourceServerHost -DataCenter $config.dataCenter -VMFolder $config.VMFolder -Properties $config.VMProperties
        
        if ($exportSuccess) {
            Write-Host ""
            Write-Host "📊 Export Summary:" -ForegroundColor Cyan
            Write-Host "  Total VMs processed: $($vmData.Count)" -ForegroundColor White
            Write-Host "  Excel file location: $excelFilePath" -ForegroundColor White
            Write-Host "  File size: $([math]::Round((Get-Item $excelFilePath).Length / 1KB, 2)) KB" -ForegroundColor White
        } else {
            throw "Failed to export VM data to Excel"
        }
    }
    
    Write-Host ""
    
    # Disconnect from vSphere
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Disconnect-vSphereServer
    
    Write-Host ""
    Write-Host "🎉 VM listing completed successfully!" -ForegroundColor Green
    
    if (-not $config.DryRun) {
        Write-Host ""
        Write-Host "To open the Excel file:" -ForegroundColor White
        Write-Host "  Invoke-Item '$excelFilePath'" -ForegroundColor Cyan
    }
    
} catch {
    Write-Host ""
    Write-Host "❌ Error occurred during VM listing:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    
    # Ensure we disconnect from vSphere even if an error occurs
    if (Test-vSphereConnection) {
        Write-Host ""
        Write-Host "Cleaning up vSphere connection..." -ForegroundColor Yellow
        Disconnect-vSphereServer
    }
    
    exit 1
}
