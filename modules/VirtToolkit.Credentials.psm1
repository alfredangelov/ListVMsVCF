<#
.SYNOPSIS
    VirtToolkit shared credential management utilities for standardized SecretVault operations.

.DESCRIPTION
    This module provides unified credential management functionality for all VirtToolkit modules.
    It uses a server-centric credential naming pattern to enable credential reuse across
    different modules and workflows.

    Key Features:
    - Server-centric credential storage: vSphere-{hostname}-{username}
    - Automatic credential discovery by server hostname
    - Support for multiple usernames per server
    - Smart credential selection with PreferredUsername
    - Fallback to interactive credential prompts
    - Consistent error handling and logging

    Credential Naming Pattern:
    vSphere-{hostname}-{username}
    Example: vSphere-vcenter01.contoso.com-administrator@vsphere.local

.NOTES
    Part of VirtToolkit: Enterprise Virtualization Management Platform
    Integrates with shared modules and unified configuration system
#>

function Get-VirtToolkitCredential {
    <#
    .SYNOPSIS
        Retrieves credentials from SecretVault using server-centric naming with smart discovery.

    .DESCRIPTION
        Get-VirtToolkitCredential provides intelligent credential retrieval for vSphere servers.
        It searches for credentials using the pattern: vSphere-{hostname}-{username}
        
        Smart Discovery Process:
        1. If PreferredUsername specified: Look for vSphere-{Server}-{PreferredUsername}
        2. If no PreferredUsername: Find all credentials for server (vSphere-{Server}-*)
           - If only one found: Use it automatically
           - If multiple found: Prompt user to select
        3. If no credentials found: Prompt for new credentials (if AllowPrompt = $true)

    .PARAMETER Server
        The target vSphere server hostname or FQDN (required).
        Used to search for stored credentials.

    .PARAMETER PreferredUsername
        Optional preferred username. If specified, will look for credentials with this exact username.
        If not specified, will search for any credentials associated with the server.

    .PARAMETER VaultName
        Name of the SecretVault to query. Default: 'SecretVault'

    .PARAMETER AllowPrompt
        If credential retrieval from SecretVault fails, prompt user for credentials.
        Default: $true

    .OUTPUTS
        System.Management.Automation.PSCredential
        Returns PSCredential object or $null if retrieval fails

    .EXAMPLE
        $cred = Get-VirtToolkitCredential -Server "vcenter01.contoso.com" -PreferredUsername "administrator@vsphere.local"

        Description
        -----------
        Retrieves specific credential: vSphere-vcenter01.contoso.com-administrator@vsphere.local

    .EXAMPLE
        $cred = Get-VirtToolkitCredential -Server "vcenter01.contoso.com"

        Description
        -----------
        Searches for any credential for vcenter01.contoso.com, auto-selects if only one exists

    .EXAMPLE
        $cred = Get-VirtToolkitCredential -Server "192.168.1.100" -AllowPrompt:$false

        Description
        -----------
        Retrieves credential without prompting if not found
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Server,

        [Parameter(Mandatory = $false)]
        [string]$PreferredUsername,

        [Parameter(Mandatory = $false)]
        [string]$VaultName = 'SecretVault',

        [Parameter(Mandatory = $false)]
        [bool]$AllowPrompt = $true
    )

    # Import required modules
    $requiredModules = @('Microsoft.PowerShell.SecretManagement')
    foreach ($module in $requiredModules) {
        if (-not (Get-Module -Name $module -ListAvailable)) {
            throw "Required module '$module' not found. Please install SecretManagement module."
        }
        Import-Module $module -ErrorAction Stop
    }

    # Clean server name for credential lookup
    $cleanServer = $Server -replace '[^a-zA-Z0-9.-]', ''
    
    # Strategy 1: Look for specific credential if PreferredUsername is provided
    if ($PreferredUsername) {
        $credentialName = "vSphere-$cleanServer-$PreferredUsername"
        Write-Verbose "VirtToolkit.Credentials: Looking for specific credential '$credentialName'"
        
        try {
            $credential = Get-Secret -Name $credentialName -Vault $VaultName -ErrorAction Stop
            Write-Verbose "VirtToolkit.Credentials: Successfully retrieved credential from SecretVault"
            return $credential
        }
        catch {
            Write-Verbose "VirtToolkit.Credentials: Specific credential not found: $($_.Exception.Message)"
        }
    }
    
    # Strategy 2: Search for any credentials matching this server
    Write-Verbose "VirtToolkit.Credentials: Searching for credentials matching server '$cleanServer'"
    
    try {
        $searchPattern = "vSphere-$cleanServer-*"
        $allSecrets = Get-SecretInfo -Vault $VaultName -ErrorAction Stop
        $matchingSecrets = $allSecrets | Where-Object { $_.Name -like $searchPattern }
        
        if ($matchingSecrets) {
            if ($matchingSecrets.Count -eq 1) {
                # Only one credential found - use it automatically
                Write-Verbose "VirtToolkit.Credentials: Found single credential '$($matchingSecrets[0].Name)', using automatically"
                $credential = Get-Secret -Name $matchingSecrets[0].Name -Vault $VaultName -ErrorAction Stop
                return $credential
            }
            elseif ($matchingSecrets.Count -gt 1) {
                # Multiple credentials found - prompt user to select
                Write-Host "VirtToolkit.Credentials: Multiple credentials found for server '$Server':" -ForegroundColor Yellow
                Write-Host ""
                
                for ($i = 0; $i -lt $matchingSecrets.Count; $i++) {
                    # Extract username from credential name pattern: vSphere-server-username
                    $parts = $matchingSecrets[$i].Name -split '-', 3
                    $username = if ($parts.Count -eq 3) { $parts[2] } else { "Unknown" }
                    Write-Host "  [$($i + 1)] $username" -ForegroundColor Cyan
                }
                Write-Host ""
                
                $selection = Read-Host "Select credential number (1-$($matchingSecrets.Count)) or press Enter to create new"
                
                if ($selection -match '^\d+$') {
                    $index = [int]$selection - 1
                    if ($index -ge 0 -and $index -lt $matchingSecrets.Count) {
                        $selectedCred = $matchingSecrets[$index].Name
                        Write-Verbose "VirtToolkit.Credentials: User selected credential '$selectedCred'"
                        $credential = Get-Secret -Name $selectedCred -Vault $VaultName -ErrorAction Stop
                        return $credential
                    }
                }
                
                Write-Verbose "VirtToolkit.Credentials: Invalid selection or user chose to create new credential"
            }
        }
        else {
            Write-Verbose "VirtToolkit.Credentials: No existing credentials found for server '$Server'"
        }
    }
    catch {
        Write-Verbose "VirtToolkit.Credentials: Error searching for credentials: $($_.Exception.Message)"
    }
    
    # Strategy 3: Prompt for new credentials if allowed
    if ($AllowPrompt) {
        Write-Host "VirtToolkit.Credentials: No suitable credential found - prompting for new credentials" -ForegroundColor Yellow
        
        $promptMessage = "Enter credentials for vSphere server: $Server"
        $credential = Get-Credential -Message $promptMessage -UserName $PreferredUsername
        
        if ($credential) {
            Write-Verbose "VirtToolkit.Credentials: Interactive credential prompt successful"
            
            # Ask if user wants to save the credential
            $save = Read-Host "Save this credential to vault for future use? (Y/n)"
            if ($save -ne 'n' -and $save -ne 'N') {
                $newCredName = "vSphere-$cleanServer-$($credential.UserName)"
                try {
                    Set-Secret -Name $newCredName -Secret $credential -Vault $VaultName -ErrorAction Stop
                    Write-Host "VirtToolkit.Credentials: Credential saved as '$newCredName'" -ForegroundColor Green
                }
                catch {
                    Write-Warning "VirtToolkit.Credentials: Failed to save credential: $($_.Exception.Message)"
                }
            }
            
            return $credential
        }
        else {
            Write-Warning "VirtToolkit.Credentials: Interactive credential prompt was cancelled"
            return $null
        }
    }
    else {
        Write-Warning "VirtToolkit.Credentials: No credential found and prompting disabled"
        return $null
    }
}

function Set-VirtToolkitCredential {
    <#
    .SYNOPSIS
        Stores credentials in SecretVault using server-centric naming pattern.

    .DESCRIPTION
        Set-VirtToolkitCredential stores credentials with the naming pattern:
        vSphere-{hostname}-{username}
        
        The username is extracted from the PSCredential object automatically.

    .PARAMETER Server
        The target vSphere server hostname or FQDN (required).

    .PARAMETER Credential
        PSCredential object to store in SecretVault (required).

    .PARAMETER VaultName
        Name of the SecretVault to use for storage. Default: 'SecretVault'

    .PARAMETER Force
        Overwrite existing credential without confirmation.

    .OUTPUTS
        System.Boolean
        Returns $true if credential was stored successfully, $false otherwise

    .EXAMPLE
        $cred = Get-Credential -UserName "administrator@vsphere.local"
        Set-VirtToolkitCredential -Server "vcenter01.contoso.com" -Credential $cred

        Description
        -----------
        Stores credential as: vSphere-vcenter01.contoso.com-administrator@vsphere.local

    .EXAMPLE
        Set-VirtToolkitCredential -Server "vcenter01.contoso.com" -Credential $cred -Force

        Description
        -----------
        Stores credential, overwriting if it exists
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Server,

        [Parameter(Mandatory = $true)]
        [PSCredential]$Credential,

        [Parameter(Mandatory = $false)]
        [string]$VaultName = 'SecretVault',

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    # Import required modules
    if (-not (Get-Module -Name 'Microsoft.PowerShell.SecretManagement' -ListAvailable)) {
        throw "Required module 'Microsoft.PowerShell.SecretManagement' not found. Please install SecretManagement module."
    }
    Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction Stop

    # Clean server name and get username from credential
    $cleanServer = $Server -replace '[^a-zA-Z0-9.-]', ''
    $username = $Credential.UserName
    
    # Build credential name using server-centric pattern
    $CredentialName = "vSphere-$cleanServer-$username"

    Write-Verbose "VirtToolkit.Credentials: Storing credential '$CredentialName' in vault '$VaultName'"
    Write-Verbose "VirtToolkit.Credentials: Storing credential '$CredentialName' in vault '$VaultName'"

    # Check for existing credential
    if (-not $Force) {
        try {
            $existingCredential = Get-Secret -Name $CredentialName -Vault $VaultName -ErrorAction Stop
            if ($existingCredential) {
                $confirmation = Read-Host "Credential '$CredentialName' already exists. Overwrite? (y/N)"
                if ($confirmation -notmatch '^[Yy]') {
                    Write-Warning "VirtToolkit.Credentials: Credential storage cancelled by user"
                    return $false
                }
            }
        }
        catch {
            # Credential doesn't exist, proceed with storage
        }
    }

    # Store credential
    try {
        Set-Secret -Name $CredentialName -Secret $Credential -Vault $VaultName -ErrorAction Stop
        Write-Host "SUCCESS: VirtToolkit.Credentials: Successfully stored credential '$CredentialName'" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "VirtToolkit.Credentials: Failed to store credential '$CredentialName': $($_.Exception.Message)"
        return $false
    }
}

function Remove-VirtToolkitCredential {
    <#
    .SYNOPSIS
        Removes credentials from SecretVault by name.

    .DESCRIPTION
        Remove-VirtToolkitCredential removes a credential from SecretVault.
        Used primarily by management scripts.

    .PARAMETER CredentialName
        Exact name of the credential to remove from SecretVault (required).

    .PARAMETER VaultName
        Name of the SecretVault to remove from. Default: 'SecretVault'

    .PARAMETER Force
        Remove credential without confirmation prompt.

    .OUTPUTS
        System.Boolean
        Returns $true if credential was removed successfully, $false otherwise

    .EXAMPLE
        Remove-VirtToolkitCredential -CredentialName "vSphere-vcenter01.contoso.com-admin@vsphere.local"

        Description
        -----------
        Removes specific credential with confirmation prompt

    .EXAMPLE
        Remove-VirtToolkitCredential -CredentialName "vSphere-vcenter01.contoso.com-admin@vsphere.local" -Force

        Description
        -----------
        Removes credential without confirmation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CredentialName,

        [Parameter(Mandatory = $false)]
        [string]$VaultName = 'SecretVault',

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    # Import required modules
    if (-not (Get-Module -Name 'Microsoft.PowerShell.SecretManagement' -ListAvailable)) {
        throw "Required module 'Microsoft.PowerShell.SecretManagement' not found. Please install SecretManagement module."
    }
    Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction Stop

    Write-Verbose "VirtToolkit.Credentials: Removing credential '$CredentialName' from vault '$VaultName'"

    # Verify credential exists
    try {
        $existingCredential = Get-Secret -Name $CredentialName -Vault $VaultName -ErrorAction Stop
        if (-not $existingCredential) {
            Write-Warning "VirtToolkit.Credentials: Credential '$CredentialName' not found in vault '$VaultName'"
            return $false
        }
    }
    catch {
        Write-Warning "VirtToolkit.Credentials: Credential '$CredentialName' not found in vault '$VaultName'"
        return $false
    }

    # Confirm removal
    if (-not $Force) {
        $confirmation = Read-Host "Remove credential '$CredentialName' from vault '$VaultName'? (y/N)"
        if ($confirmation -notmatch '^[Yy]') {
            Write-Warning "VirtToolkit.Credentials: Credential removal cancelled by user"
            return $false
        }
    }

    # Remove credential
    try {
        Remove-Secret -Name $CredentialName -Vault $VaultName -ErrorAction Stop
        Write-Host "SUCCESS: VirtToolkit.Credentials: Successfully removed credential '$CredentialName'" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "VirtToolkit.Credentials: Failed to remove credential '$CredentialName': $($_.Exception.Message)"
        return $false
    }
}

function Test-VirtToolkitCredential {
    <#
    .SYNOPSIS
        Tests credential existence in SecretVault.

    .DESCRIPTION
        Test-VirtToolkitCredential verifies that a credential exists in SecretVault
        and returns its properties.

    .PARAMETER CredentialName
        Exact name of the credential to test (required).

    .PARAMETER VaultName
        Name of the SecretVault to query. Default: 'SecretVault'

    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Returns test result with properties:
        - CredentialName: Name of the tested credential
        - Exists: Boolean indicating if credential exists in vault
        - Username: Username from the credential (if exists)
        - Message: Status or error message

    .EXAMPLE
        $test = Test-VirtToolkitCredential -CredentialName "vSphere-vcenter01.contoso.com-admin@vsphere.local"

        Description
        -----------
        Tests existence of specific credential
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CredentialName,

        [Parameter(Mandatory = $false)]
        [string]$VaultName = 'SecretVault'
    )

    $result = [PSCustomObject]@{
        CredentialName = $CredentialName
        Exists         = $false
        Username       = $null
        Message        = ""
    }

    # Test credential existence
    try {
        $credential = Get-Secret -Name $CredentialName -Vault $VaultName -ErrorAction Stop
        $result.Exists = $true
        $result.Username = $credential.UserName
        $result.Message = "Credential exists in vault"
    }
    catch {
        $result.Message = "Credential not found in vault"
    }

    return $result
}

# Export module functions
Export-ModuleMember -Function Get-VirtToolkitCredential, Set-VirtToolkitCredential, Remove-VirtToolkitCredential, Test-VirtToolkitCredential
