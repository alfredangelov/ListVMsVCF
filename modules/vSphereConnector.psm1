#Requires -Version 5.1

<#
.SYNOPSIS
    vSphere connectivity module for the VM listing toolkit
.DESCRIPTION
    This module provides functions to connect to vSphere and retrieve VM information
.AUTHOR
    VM Listing Toolkit
.VERSION
    1.0.0
#>

function Connect-vSphereServer {
    <#
    .SYNOPSIS
        Connects to a vSphere server using stored or provided credentials
    .PARAMETER ServerHost
        The vSphere server hostname or IP address
    .PARAMETER Credential
        PSCredential object for authentication (optional - will try stored credentials first)
    .PARAMETER CredentialName
        Name of stored credential to use (default: 'SourceCred')
    .PARAMETER VaultName
        Name of secret vault to check (default: 'VCenterVault')
    .PARAMETER IgnoreSSLCertificates
        Whether to ignore SSL certificate warnings (useful for ESXi hosts with self-signed certificates)
    .OUTPUTS
        [bool] True if connection succeeded, False otherwise
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServerHost,
        
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential,
        
        [Parameter(Mandatory = $false)]
        [string]$CredentialName = 'SourceCred',
        
        [Parameter(Mandatory = $false)]
        [string]$VaultName = 'VCenterVault',
        
        [Parameter(Mandatory = $false)]
        [bool]$IgnoreSSLCertificates = $true
    )
    
    try {
        Write-Host "Connecting to vSphere server: $ServerHost" -ForegroundColor Blue
        
        # Disconnect any existing connections first
        if ($global:DefaultVIServers) {
            Write-Verbose "Disconnecting existing vSphere connections..."
            Disconnect-VIServer -Server * -Force -Confirm:$false -ErrorAction SilentlyContinue
        }
        
        # Try to get credentials in order of preference:
        # 1. Provided credential parameter
        # 2. Stored credentials from secret vault
        # 3. Prompt user
        
        $credentialToUse = $null
        
        if ($Credential) {
            Write-Verbose "Using provided credential"
            $credentialToUse = $Credential
        } else {
            # Try to get stored credentials
            Write-Host "Checking for stored credentials..." -ForegroundColor Gray
            try {
                # Import the EnvironmentValidator module to access credential functions
                $moduleDir = Split-Path -Path $PSScriptRoot -Parent
                $envValidatorPath = Join-Path -Path $moduleDir -ChildPath "modules\EnvironmentValidator.psm1"
                if (Test-Path -Path $envValidatorPath) {
                    Import-Module -Name $envValidatorPath -Force -ErrorAction SilentlyContinue
                    
                    # Use the preferred vault (prioritizes existing VCenterVault)
                    Write-Verbose "Requesting vault: $VaultName, credential: $CredentialName"
                    $preferredVault = Get-PreferredVaultName -RequestedVaultName $VaultName
                    Write-Verbose "Preferred vault determined: $preferredVault"
                    $credentialToUse = Get-VCenterCredential -CredentialName $CredentialName -VaultName $preferredVault -Verbose
                    Write-Verbose "Credential retrieval result: $($credentialToUse -ne $null)"
                } else {
                    Write-Verbose "EnvironmentValidator module not found at: $envValidatorPath"
                }
                
                if ($credentialToUse) {
                    Write-Host "✅ Using stored credentials for $($credentialToUse.UserName)" -ForegroundColor Green
                } else {
                    Write-Host "ℹ️ No stored credentials found - will prompt for authentication" -ForegroundColor Yellow
                }
            } catch {
                Write-Verbose "Could not access stored credentials: $($_.Exception.Message)"
                Write-Host "ℹ️ No stored credentials found - will prompt for authentication" -ForegroundColor Yellow
            }
        }
        
        # Configure PowerCLI SSL certificate handling
        if ($IgnoreSSLCertificates) {
            Write-Host "Configuring SSL to ignore certificate warnings (ESXi self-signed certificates)..." -ForegroundColor Gray
            try {
                # Set to ignore invalid certificates (common for ESXi hosts with self-signed certs)
                Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Scope Session -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
                
                # Configure .NET security protocols to support older TLS versions (ESXi compatibility)
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls
                
                # Configure certificate validation callback to accept all certificates
                [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
                
                Write-Verbose "SSL/TLS configuration updated for ESXi compatibility"
            } catch {
                Write-Verbose "Could not configure certificate policy: $($_.Exception.Message)"
            }
        } else {
            Write-Host "Using strict SSL certificate validation..." -ForegroundColor Gray
        }
        
        # Connect to vSphere
        $connectParams = @{
            Server = $ServerHost
            ErrorAction = 'Stop'
            Force = $true
        }
        
        if ($credentialToUse) {
            $connectParams.Credential = $credentialToUse
        }
        
        $connection = Connect-VIServer @connectParams
        
        if ($connection) {
            Write-Host "✓ Successfully connected to vSphere server: $($connection.Name)" -ForegroundColor Green
            Write-Host "  Version: $($connection.Version)" -ForegroundColor Gray
            Write-Host "  Build: $($connection.Build)" -ForegroundColor Gray
            return $true
        } else {
            Write-Error "✗ Failed to connect to vSphere server: $ServerHost"
            return $false
        }
    }
    catch {
        Write-Error "Error connecting to vSphere server '$ServerHost': $($_.Exception.Message)"
        return $false
    }
}

function Disconnect-vSphereServer {
    <#
    .SYNOPSIS
        Disconnects from all vSphere servers
    .OUTPUTS
        [bool] True if disconnection succeeded, False otherwise
    #>
    [CmdletBinding()]
    param()
    
    try {
        if ($global:DefaultVIServers) {
            Write-Host "Disconnecting from vSphere servers..." -ForegroundColor Blue
            Disconnect-VIServer -Server * -Force -Confirm:$false
            Write-Host "✓ Disconnected from vSphere servers" -ForegroundColor Green
        } else {
            Write-Host "No active vSphere connections to disconnect" -ForegroundColor Gray
        }
        return $true
    }
    catch {
        Write-Error "Error disconnecting from vSphere servers: $($_.Exception.Message)"
        return $false
    }
}

function Get-VMsFromFolder {
    <#
    .SYNOPSIS
        Retrieves VMs from a specific folder within a datacenter
    .PARAMETER DataCenter
        Name of the datacenter
    .PARAMETER VMFolder
        Path to the VM folder
    .PARAMETER Properties
        Array of VM properties to retrieve
    .OUTPUTS
        [array] Array of VM objects with requested properties
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DataCenter,
        
        [Parameter(Mandatory = $true)]
        [string]$VMFolder,
        
        [Parameter(Mandatory = $true)]
        [string[]]$Properties
    )
    
    try {
        Write-Host "Retrieving VMs from datacenter '$DataCenter', folder '$VMFolder'..." -ForegroundColor Blue
        
        # Get the datacenter
        $dc = Get-Datacenter -Name $DataCenter -ErrorAction Stop
        if (-not $dc) {
            throw "Datacenter '$DataCenter' not found"
        }
        
        # Get the folder
        $folder = Get-Folder -Name $VMFolder -Location $dc -Type VM -ErrorAction Stop
        if (-not $folder) {
            throw "VM folder '$VMFolder' not found in datacenter '$DataCenter'"
        }
        
        Write-Host "Found folder: $($folder.Name)" -ForegroundColor Gray
        
        # Get VMs from the folder
        $vms = Get-VM -Location $folder -ErrorAction Stop
        
        if (-not $vms) {
            Write-Warning "No VMs found in folder '$VMFolder'"
            return @()
        }
        
        Write-Host "Found $($vms.Count) VM(s) in folder" -ForegroundColor Green
        
        # Collect VM information
        $vmData = @()
        $counter = 0
        
        foreach ($vm in $vms) {
            $counter++
            Write-Progress -Activity "Processing VMs" -Status "Processing VM $counter of $($vms.Count): $($vm.Name)" -PercentComplete (($counter / $vms.Count) * 100)
            
            $vmInfo = Get-VMProperties -VM $vm -Properties $Properties
            $vmData += $vmInfo
        }
        
        Write-Progress -Activity "Processing VMs" -Completed
        Write-Host "✓ Successfully processed $($vmData.Count) VMs" -ForegroundColor Green
        
        return $vmData
    }
    catch {
        Write-Error "Error retrieving VMs from folder '$VMFolder' in datacenter '$DataCenter': $($_.Exception.Message)"
        return @()
    }
}

function Get-VMProperties {
    <#
    .SYNOPSIS
        Extracts specific properties from a VM object
    .PARAMETER VM
        The VM object to process
    .PARAMETER Properties
        Array of property names to extract
    .OUTPUTS
        [hashtable] Hashtable containing the requested VM properties
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine]$VM,
        
        [Parameter(Mandatory = $true)]
        [string[]]$Properties
    )
    
    $vmData = @{}
    
    foreach ($property in $Properties) {
        try {
            switch ($property) {
                'Name' { 
                    $vmData[$property] = if ($VM.Name) { $VM.Name } else { "NULL" }
                }
                'UUID' { 
                    $vmData[$property] = if ($VM.ExtensionData.Config.Uuid) { $VM.ExtensionData.Config.Uuid } else { "NULL" }
                }
                'DNSName' { 
                    $vmData[$property] = if ($VM.Guest.HostName) { $VM.Guest.HostName } else { "NULL" }
                }
                'PowerState' { 
                    $vmData[$property] = if ($VM.PowerState) { $VM.PowerState.ToString() } else { "NULL" }
                }
                'GuestOS' { 
                    $vmData[$property] = if ($VM.Guest.OSFullName) { $VM.Guest.OSFullName } else { "NULL" }
                }
                'NumCPU' { 
                    $vmData[$property] = if ($VM.NumCpu) { $VM.NumCpu } else { "NULL" }
                }
                'MemoryMB' { 
                    $vmData[$property] = if ($VM.MemoryMB) { $VM.MemoryMB } else { "NULL" }
                }
                'ProvisionedSpaceGB' { 
                    $vmData[$property] = if ($VM.ProvisionedSpaceGB) { [math]::Round($VM.ProvisionedSpaceGB, 2) } else { "NULL" }
                }
                'UsedSpaceGB' { 
                    $vmData[$property] = if ($VM.UsedSpaceGB) { [math]::Round($VM.UsedSpaceGB, 2) } else { "NULL" }
                }
                'Datastore' { 
                    $datastores = $VM | Get-Datastore
                    $vmData[$property] = if ($datastores) { ($datastores.Name -join "; ") } else { "NULL" }
                }
                'NetworkAdapters' { 
                    $networks = $VM | Get-NetworkAdapter
                    $vmData[$property] = if ($networks) { ($networks.NetworkName -join "; ") } else { "NULL" }
                }
                'IPAddresses' { 
                    $ips = $VM.Guest.IPAddress | Where-Object { $_ -and $_ -ne "" }
                    $vmData[$property] = if ($ips) { ($ips -join "; ") } else { "NULL" }
                }
                'Annotation' { 
                    $vmData[$property] = if ($VM.Notes) { $VM.Notes } else { "NULL" }
                }
                'HostSystem' { 
                    $vmData[$property] = if ($VM.VMHost.Name) { $VM.VMHost.Name } else { "NULL" }
                }
                'VMToolsVersion' { 
                    $vmData[$property] = if ($VM.ExtensionData.Guest.ToolsVersion) { $VM.ExtensionData.Guest.ToolsVersion } else { "NULL" }
                }
                'VMToolsStatus' { 
                    $vmData[$property] = if ($VM.ExtensionData.Guest.ToolsStatus) { $VM.ExtensionData.Guest.ToolsStatus.ToString() } else { "NULL" }
                }
                'Folder' { 
                    $vmData[$property] = if ($VM.Folder.Name) { $VM.Folder.Name } else { "NULL" }
                }
                default { 
                    # For any other property, try to get it directly from the VM object
                    $value = $VM | Select-Object -ExpandProperty $property -ErrorAction SilentlyContinue
                    $vmData[$property] = if ($value) { $value.ToString() } else { "NULL" }
                }
            }
        }
        catch {
            Write-Warning "Could not retrieve property '$property' for VM '$($VM.Name)': $($_.Exception.Message)"
            $vmData[$property] = "NULL"
        }
    }
    
    return $vmData
}

function Test-vSphereConnection {
    <#
    .SYNOPSIS
        Tests if there is an active vSphere connection
    .OUTPUTS
        [bool] True if connected, False otherwise
    #>
    [CmdletBinding()]
    param()
    
    try {
        if ($global:DefaultVIServers -and $global:DefaultVIServers.Count -gt 0) {
            $connectedServers = $global:DefaultVIServers | Where-Object { $_.IsConnected }
            if ($connectedServers) {
                return $true
            }
        }
        return $false
    }
    catch {
        return $false
    }
}

function Get-VMsFromESXiHost {
    <#
    .SYNOPSIS
        Retrieves all VMs directly from an ESXi host
    .DESCRIPTION
        Connects directly to an ESXi host and retrieves all VMs with specified properties.
        This function is designed for direct ESXi host connections without vCenter.
    .PARAMETER Properties
        Array of VM properties to retrieve
    .OUTPUTS
        [array] Array of VM objects with requested properties
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Properties
    )
    
    try {
        Write-Host "Retrieving VMs from ESXi host..." -ForegroundColor Blue
        
        # Get all VMs directly from the ESXi host
        $vms = Get-VM -ErrorAction Stop
        
        if (-not $vms) {
            Write-Warning "No VMs found on ESXi host"
            return @()
        }
        
        Write-Host "Found $($vms.Count) VM(s) on ESXi host" -ForegroundColor Green
        Write-Host ""
        
        # Process VMs and extract properties
        $vmDataList = @()
        $counter = 0
        
        foreach ($vm in $vms) {
            $counter++
            $progressPercent = [math]::Round(($counter / $vms.Count) * 100, 0)
            Write-Progress -Activity "Processing VMs" -Status "Processing VM $counter of $($vms.Count): $($vm.Name)" -PercentComplete $progressPercent
            
            # Get VM properties
            $vmInfo = Get-VMProperties -VM $vm -Properties $Properties
            $vmDataList += $vmInfo
        }
        
        Write-Progress -Activity "Processing VMs" -Completed
        Write-Host "✓ Successfully processed $($vmDataList.Count) VMs" -ForegroundColor Green
        
        return $vmDataList
    }
    catch {
        Write-Error "Error retrieving VMs from ESXi host: $($_.Exception.Message)"
        throw
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Connect-vSphereServer',
    'Disconnect-vSphereServer',
    'Get-VMsFromFolder',
    'Get-VMsFromESXiHost',
    'Get-VMProperties',
    'Test-vSphereConnection'
)
