#Requires -Version 5.1

<#
.SYNOPSIS
    Utility script for VM Listing Toolkit
.DESCRIPTION
    This script provides various utility functions for the VM Listing Toolkit
.AUTHOR
    VM Listing Toolkit
.VERSION
    1.0.0
.PARAMETER Action
    Action to perform: Status, TestConnection, ListFolders, or Help
.PARAMETER ConfigPath
    Path to the configuration file (default: ..\shared\Configuration.psd1)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Status", "TestConnection", "ListFolders", "SetupCredentials", "Help")]
    [string]$Action,
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath
)

# Get script directory and set up paths
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulePath = Join-Path -Path $ScriptRoot -ChildPath "..\modules"

if (-not $ConfigPath) {
    $ConfigPath = Join-Path -Path $ScriptRoot -ChildPath "..\shared\Configuration.psd1"
}

# Function to import modules safely
function Import-ToolkitModule {
    param([string]$ModuleName)
    
    $modulePath = Join-Path -Path $ModulePath -ChildPath "$ModuleName.psm1"
    if (-not (Test-Path -Path $modulePath)) {
        throw "Cannot find module '$ModuleName' at: $modulePath"
    }
    
    Import-Module -Name $modulePath -Force
}

# Display banner
Write-Host @"
╔════════════════════════════════════════════════════════════════════════════════╗
║                           VM Listing Toolkit                                  ║
║                             Utility Script                                    ║
╚════════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Host ""

try {
    switch ($Action) {
        "Help" {
            Write-Host "Available actions:" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Status         - Show environment and module status" -ForegroundColor White
            Write-Host "TestConnection - Test connection to vCenter server" -ForegroundColor White
            Write-Host "ListFolders    - Validate configured VM folder and check for VMs" -ForegroundColor White
            Write-Host "SetupCredentials- Create vault if needed and (re)store credentials" -ForegroundColor White
            Write-Host "Help           - Show this help message" -ForegroundColor White
            Write-Host ""
            Write-Host "Examples:" -ForegroundColor Yellow
            Write-Host "  .\scripts\Toolkit-Utilities.ps1 -Action Status" -ForegroundColor Cyan
            Write-Host "  .\scripts\Toolkit-Utilities.ps1 -Action TestConnection" -ForegroundColor Cyan
            Write-Host "  .\scripts\Toolkit-Utilities.ps1 -Action ListFolders" -ForegroundColor Cyan
            Write-Host "  .\scripts\Toolkit-Utilities.ps1 -Action SetupCredentials" -ForegroundColor Cyan
        }
        
        "Status" {
            Write-Host "Checking environment status..." -ForegroundColor Blue
            Write-Host ""
            
            # Import environment validator
            Import-ToolkitModule -ModuleName "EnvironmentValidator"
            
            $status = Get-EnvironmentStatus
            
            Write-Host "PowerShell Environment:" -ForegroundColor Cyan
            Write-Host "  Version: $($status.PowerShellVersion)" -ForegroundColor White
            Write-Host "  Status: $(if ($status.PowerShellVersionOK) { '✓ OK' } else { '✗ Needs Update' })" -ForegroundColor $(if ($status.PowerShellVersionOK) { 'Green' } else { 'Red' })
            Write-Host ""
            
            Write-Host "Required Modules:" -ForegroundColor Cyan
            foreach ($module in $status.Modules.GetEnumerator()) {
                $moduleName = $module.Key
                $moduleInfo = $module.Value
                $statusText = if ($moduleInfo.OK) { '✓ OK' } else { '✗ Missing/Outdated' }
                $statusColor = if ($moduleInfo.OK) { 'Green' } else { 'Red' }
                
                Write-Host "  $moduleName" -ForegroundColor White
                Write-Host "    Required: $($moduleInfo.Required)" -ForegroundColor Gray
                Write-Host "    Installed: $($moduleInfo.Installed)" -ForegroundColor Gray
                Write-Host "    Status: $statusText" -ForegroundColor $statusColor
                Write-Host ""
            }
            
            # Display optional modules if any exist
            if ($status.OptionalModules -and $status.OptionalModules.Count -gt 0) {
                Write-Host "Optional Modules:" -ForegroundColor Cyan
                foreach ($module in $status.OptionalModules.GetEnumerator()) {
                    $moduleName = $module.Key
                    $moduleInfo = $module.Value
                    $statusText = if ($moduleInfo.Available) { 
                        if ($moduleInfo.UpToDate) { '✓ Available (Up to Date)' } else { '⚠ Available (Update Recommended)' } 
                    } else { 
                        'ℹ Not Installed' 
                    }
                    $statusColor = if ($moduleInfo.Available) { 
                        if ($moduleInfo.UpToDate) { 'Green' } else { 'Yellow' } 
                    } else { 
                        'Gray' 
                    }
                    
                    Write-Host "  $moduleName" -ForegroundColor White
                    Write-Host "    Purpose: $($moduleInfo.Description)" -ForegroundColor Gray
                    Write-Host "    Recommended: $($moduleInfo.Recommended)" -ForegroundColor Gray
                    Write-Host "    Installed: $($moduleInfo.Installed)" -ForegroundColor Gray
                    Write-Host "    Status: $statusText" -ForegroundColor $statusColor
                    Write-Host ""
                }
            }
            
            $overallStatus = $status.PowerShellVersionOK -and $status.AllModulesOK
            Write-Host "Overall Status: $(if ($overallStatus) { '✓ Ready' } else { '✗ Needs Attention' })" -ForegroundColor $(if ($overallStatus) { 'Green' } else { 'Red' })
            
            # Check credential status if modules are available
            if ($status.AllModulesOK) {
                Write-Host ""
                Write-Host "Credential Management:" -ForegroundColor Cyan
                
                # Load configuration to check for stored credentials
                if (Test-Path -Path $ConfigPath) {
                    try {
                        $config = Import-PowerShellDataFile -Path $ConfigPath
                        
                        # Use the preferred vault (prioritizes existing VCenterVault)
                        $preferredVault = Get-PreferredVaultName -RequestedVaultName $config.preferredVault
                        $credentialStatus = Test-StoredCredential -CredentialName $config.CredentialName -ServerHost $config.SourceServerHost -VaultName $preferredVault
                        
                        if ($credentialStatus) {
                            Write-Host "  vCenter Credentials: ✓ Stored and accessible (vault: $preferredVault)" -ForegroundColor Green
                        } else {
                            Write-Host "  vCenter Credentials: ⚠️ Not stored - will prompt when needed" -ForegroundColor Yellow
                        }
                    } catch {
                        Write-Host "  vCenter Credentials: ❓ Could not check (configuration issue)" -ForegroundColor Gray
                    }
                } else {
                    Write-Host "  vCenter Credentials: ❓ Could not check (no configuration)" -ForegroundColor Gray
                }
            }
            
            if (-not $overallStatus) {
                Write-Host ""
                Write-Host "Run .\scripts\Initialize-Environment.ps1 to fix any issues" -ForegroundColor Yellow
            }
        }
        
        "TestConnection" {
            Write-Host "Testing connection to vCenter..." -ForegroundColor Blue
            Write-Host ""
            
            # Load configuration
            if (-not (Test-Path -Path $ConfigPath)) {
                throw "Configuration file not found: $ConfigPath"
            }
            
            $config = Import-PowerShellDataFile -Path $ConfigPath
            Write-Host "Configuration loaded from: $ConfigPath" -ForegroundColor Gray
            Write-Host "Target server: $($config.SourceServerHost)" -ForegroundColor White
            Write-Host ""
            
            # Import vSphere connector
            Import-ToolkitModule -ModuleName "vSphereConnector"
            
            # Test connection
            if (Connect-vSphereServer -ServerHost $config.SourceServerHost -CredentialName $config.CredentialName -VaultName $config.preferredVault) {
                Write-Host ""
                Write-Host "✓ Connection test successful!" -ForegroundColor Green
                
                # Try to get datacenter info
                try {
                    $dc = Get-Datacenter -Name $config.dataCenter -ErrorAction Stop
                    Write-Host "✓ Found datacenter: $($dc.Name)" -ForegroundColor Green
                } catch {
                    Write-Warning "Could not find datacenter '$($config.dataCenter)': $($_.Exception.Message)"
                }
                
                Disconnect-vSphereServer
            } else {
                Write-Host "✗ Connection test failed!" -ForegroundColor Red
            }
        }
        
        "ListFolders" {
            Write-Host "Validating configured VM folder..." -ForegroundColor Blue
            Write-Host ""
            
            # Load configuration
            if (-not (Test-Path -Path $ConfigPath)) {
                throw "Configuration file not found: $ConfigPath"
            }
            
            $config = Import-PowerShellDataFile -Path $ConfigPath
            Write-Host "Configuration loaded from: $ConfigPath" -ForegroundColor Gray
            Write-Host "Target server: $($config.SourceServerHost)" -ForegroundColor White
            Write-Host "Datacenter: $($config.dataCenter)" -ForegroundColor White
            Write-Host "VM Folder: $($config.VMFolder)" -ForegroundColor White
            Write-Host ""
            
            # Import vSphere connector
            Import-ToolkitModule -ModuleName "vSphereConnector"
            
            # Connect to vSphere
            if (Connect-vSphereServer -ServerHost $config.SourceServerHost -CredentialName $config.CredentialName -VaultName $config.preferredVault) {
                try {
                    $dc = Get-Datacenter -Name $config.dataCenter -ErrorAction Stop
                    Write-Host "✓ Connected to datacenter: $($dc.Name)" -ForegroundColor Green
                    Write-Host ""
                    
                    # Try to find the specific configured folder
                    Write-Host "Validating folder: '$($config.VMFolder)'" -ForegroundColor Cyan
                    
                    try {
                        $folder = Get-Folder -Name $config.VMFolder -Location $dc -Type VM -ErrorAction Stop
                        Write-Host "✓ Folder found successfully!" -ForegroundColor Green
                        Write-Host "  Full path: $($folder.Name)" -ForegroundColor Gray
                        Write-Host "  Folder ID: $($folder.Id)" -ForegroundColor Gray
                        Write-Host ""
                        
                        # Try to get VMs from the folder
                        Write-Host "Checking for VMs in folder..." -ForegroundColor Blue
                        try {
                            $vms = Get-VM -Location $folder -ErrorAction Stop
                            
                            if ($vms -and $vms.Count -gt 0) {
                                Write-Host "✓ Found $($vms.Count) VM(s) in folder" -ForegroundColor Green
                                Write-Host ""
                                Write-Host "Sample VMs (first 5):" -ForegroundColor Cyan
                                $sampleVMs = $vms | Select-Object -First 5
                                foreach ($vm in $sampleVMs) {
                                    $powerState = $vm.PowerState
                                    $powerColor = switch ($powerState) {
                                        'PoweredOn' { 'Green' }
                                        'PoweredOff' { 'Yellow' }
                                        'Suspended' { 'Cyan' }
                                        default { 'Gray' }
                                    }
                                    Write-Host "  • $($vm.Name) - " -NoNewline -ForegroundColor White
                                    Write-Host $powerState -ForegroundColor $powerColor
                                }
                                if ($vms.Count -gt 5) {
                                    Write-Host "  ... and $($vms.Count - 5) more VMs" -ForegroundColor Gray
                                }
                                Write-Host ""
                                Write-Host "✅ Folder validation successful - Ready to run VM listing!" -ForegroundColor Green
                            } else {
                                Write-Host "⚠ Folder exists but contains no VMs" -ForegroundColor Yellow
                                Write-Host ""
                                Write-Host "This could mean:" -ForegroundColor Yellow
                                Write-Host "  • The folder is empty" -ForegroundColor Gray
                                Write-Host "  • You don't have permissions to see VMs in this folder" -ForegroundColor Gray
                                Write-Host "  • VMs are in a sub-folder that needs to be specified" -ForegroundColor Gray
                                Write-Host ""
                                Write-Host "❌ No point in using this folder for VM listing" -ForegroundColor Red
                            }
                        } catch {
                            Write-Host "❌ Error accessing VMs in folder: $($_.Exception.Message)" -ForegroundColor Red
                            Write-Host ""
                            Write-Host "This could indicate:" -ForegroundColor Yellow
                            Write-Host "  • Insufficient permissions to read VMs in this folder" -ForegroundColor Gray
                            Write-Host "  • Network/connection issues" -ForegroundColor Gray
                            Write-Host "  • Folder path is correct but inaccessible" -ForegroundColor Gray
                        }
                        
                    } catch {
                        Write-Host "❌ Folder '$($config.VMFolder)' not found!" -ForegroundColor Red
                        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
                        Write-Host ""
                        Write-Host "Possible solutions:" -ForegroundColor Yellow
                        Write-Host "  • Check the folder name spelling in Configuration.psd1" -ForegroundColor Gray
                        Write-Host "  • Verify you have permissions to access this folder" -ForegroundColor Gray
                        Write-Host "  • Confirm the folder exists in the specified datacenter" -ForegroundColor Gray
                        Write-Host "  • Try using a different folder path" -ForegroundColor Gray
                        Write-Host ""
                        Write-Host "To explore available folders, you can manually browse vCenter or" -ForegroundColor Gray
                        Write-Host "contact your vSphere administrator for the correct folder path." -ForegroundColor Gray
                    }
                    
                } catch {
                    Write-Error "Error accessing datacenter '$($config.dataCenter)': $($_.Exception.Message)"
                } finally {
                    Disconnect-vSphereServer
                }
            } else {
                Write-Host "✗ Could not connect to vCenter server!" -ForegroundColor Red
            }
        }

        "SetupCredentials" {
            Write-Host "Setting up credentials and vault..." -ForegroundColor Blue
            Write-Host ""

            # Load configuration
            if (-not (Test-Path -Path $ConfigPath)) {
                throw "Configuration file not found: $ConfigPath"
            }
            $config = Import-PowerShellDataFile -Path $ConfigPath
            Write-Host "Configuration loaded from: $ConfigPath" -ForegroundColor Gray
            Write-Host "Target server: $($config.SourceServerHost)" -ForegroundColor White
            Write-Host "Credential name: $($config.CredentialName)" -ForegroundColor White
            Write-Host "Requested vault: $($config.preferredVault)" -ForegroundColor White
            Write-Host ""

            # Import environment validator for credential helpers
            Import-ToolkitModule -ModuleName "EnvironmentValidator"

            # Determine preferred vault and initialize
            $preferredVault = Get-PreferredVaultName -RequestedVaultName $config.preferredVault
            $initOk = Initialize-CredentialManagement -VaultName $preferredVault
            if (-not $initOk) {
                throw "Failed to initialize credential management for vault '$preferredVault'"
            }

            # If credential exists, inform user; else prompt to set
            $exists = Test-StoredCredential -CredentialName $config.CredentialName -ServerHost $config.SourceServerHost -VaultName $preferredVault
            if ($exists) {
                Write-Host "✅ Credential already exists in vault '$preferredVault'" -ForegroundColor Green
                $update = Read-Host "Do you want to update it now? (y/N)"
                if ($update -match '^[Yy]') {
                    if (Set-VCenterCredential -CredentialName $config.CredentialName -ServerHost $config.SourceServerHost -VaultName $preferredVault -Force) {
                        Write-Host "✅ Credential updated" -ForegroundColor Green
                    } else {
                        throw "Failed to update credential"
                    }
                } else {
                    Write-Host "Skipping update" -ForegroundColor Yellow
                }
            } else {
                if (Set-VCenterCredential -CredentialName $config.CredentialName -ServerHost $config.SourceServerHost -VaultName $preferredVault) {
                    Write-Host "✅ Credential stored" -ForegroundColor Green
                } else {
                    throw "Failed to store credential"
                }
            }

            Write-Host "Done." -ForegroundColor Green
        }
    }
    
} catch {
    Write-Host ""
    Write-Host "❌ Error occurred:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
