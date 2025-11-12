<#
.SYNOPSIS
    VirtToolkit shared vSphere connection utilities for standardized VMware vCenter connectivity.

.DESCRIPTION
    This module provides unified vSphere connection functionality for all VirtToolkit modules.
    It consolidates connection patterns from ListVMs, PermissionToolkit, MigrationToolkit, and RVToolsDump
    to eliminate code duplication and provide consistent behavior across the toolkit.

    Key Features:
    - Standardized vCenter connection with credential management
    - Automatic credential retrieval from SecretVault with fallback prompts
    - Connection validation and error handling
    - Support for multiple vCenter environments
    - Consistent logging and status reporting

.NOTES
    Part of VirtToolkit: Enterprise Virtualization Management Platform
    Integrates with shared modules and unified configuration system
    Provides standardized vSphere connectivity across all VirtToolkit components
    Requires VMware PowerCLI and Microsoft.PowerShell.SecretManagement modules
#>

function Connect-VirtToolkitVSphere {
    <#
    .SYNOPSIS
        Establishes a connection to a VMware vCenter server using standardized credential management.

    .DESCRIPTION
        Connect-VirtToolkitVSphere provides a unified interface for connecting to vCenter servers
        across all VirtToolkit modules. It handles credential retrieval from SecretVault,
        connection validation, and provides consistent error handling and logging.

    .PARAMETER Server
        The vCenter server hostname or IP address to connect to.
        Supports FQDN or IP address formats.

    .PARAMETER CredentialName
        Name of the credential stored in SecretVault. If not provided, attempts to use
        dynamic naming pattern based on the server name and toolkit module.

    .PARAMETER ModuleName
        Name of the calling VirtToolkit module (e.g., 'ListVMs', 'PermissionToolkit').
        Used for dynamic credential naming and logging context.

    .PARAMETER AllowPrompt
        If credential retrieval from SecretVault fails, prompt user for credentials.
        Default: $true

    .PARAMETER Force
        Force disconnection of existing vCenter connections before establishing new connection.
        Default: $false

    .PARAMETER Port
        Custom port for vCenter connection. Default: 443

    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Returns connection result with properties:
        - Success: Boolean indicating connection success
        - Server: vCenter server connected to
        - SessionId: vCenter session identifier
        - User: Connected username
        - Message: Status or error message
        - ConnectionTime: Timestamp of connection

    .EXAMPLE
        $connection = Connect-VirtToolkitVSphere -Server "vcenter01.contoso.local" -ModuleName "ListVMs"

        Description
        -----------
        Connects to vCenter using dynamic credential naming pattern "ListVMs-vcenter01.contoso.local-admin"

    .EXAMPLE
        $connection = Connect-VirtToolkitVSphere -Server "192.168.1.100" -CredentialName "MyVCenter-Admin"

        Description
        -----------
        Connects to vCenter using specific credential name from SecretVault

    .EXAMPLE
        Connect-VirtToolkitVSphere -Server "vcenter.lab.local" -Force -AllowPrompt:$false

        Description
        -----------
        Forces disconnection of existing connections and connects without prompting for credentials
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Server,

        [Parameter(Mandatory = $false)]
        [string]$CredentialName,

        [Parameter(Mandatory = $false)]
        [string]$ModuleName,

        [Parameter(Mandatory = $false)]
        [bool]$AllowPrompt = $true,

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [int]$Port = 443
    )

    # Import required modules
    $requiredModules = @('VMware.VimAutomation.Core', 'Microsoft.PowerShell.SecretManagement')
    foreach ($module in $requiredModules) {
        if (-not (Get-Module -Name $module -ListAvailable)) {
            throw "Required module '$module' not found. Please install VMware PowerCLI and SecretManagement modules."
        }
        Import-Module $module -ErrorAction Stop
    }

    Write-Verbose "VirtToolkit.VSphere: Initiating connection to $Server"

    # Handle existing connections
    $existingConnection = $global:DefaultVIServers | Where-Object { $_.Name -eq $Server -and $_.IsConnected }
    if ($existingConnection) {
        if ($Force) {
            Write-Verbose "VirtToolkit.VSphere: Disconnecting existing connection to $Server"
            Disconnect-VIServer -Server $existingConnection -Confirm:$false -Force -ErrorAction SilentlyContinue
        }
        else {
            Write-Verbose "VirtToolkit.VSphere: Using existing connection to $Server"
            return [PSCustomObject]@{
                Success        = $true
                Server         = $Server
                SessionId      = $existingConnection.SessionId
                User           = $existingConnection.User
                Message        = "Using existing connection"
                ConnectionTime = $existingConnection.ConnectedSince
            }
        }
    }

    # Determine credential name
    if (-not $CredentialName) {
        if ($ModuleName) {
            # Use dynamic naming pattern: ModuleName-Server-admin
            $cleanServer = $Server -replace '[^a-zA-Z0-9.-]', ''
            $CredentialName = "$ModuleName-$cleanServer-admin"
        }
        else {
            # Fallback pattern
            $cleanServer = $Server -replace '[^a-zA-Z0-9.-]', ''
            $CredentialName = "VirtToolkit-$cleanServer-admin"
        }
    }

    Write-Verbose "VirtToolkit.VSphere: Using credential name '$CredentialName'"

    # Retrieve credentials
    $credential = $null
    try {
        # First attempt: Get from SecretVault
        $credential = Get-Secret -Name $CredentialName -ErrorAction Stop
        Write-Verbose "VirtToolkit.VSphere: Retrieved credential from SecretVault"
    }
    catch {
        Write-Warning "VirtToolkit.VSphere: Failed to retrieve credential '$CredentialName' from SecretVault: $($_.Exception.Message)"
        
        if ($AllowPrompt) {
            Write-Host "VirtToolkit.VSphere: Prompting for credentials for $Server" -ForegroundColor Yellow
            $credential = Get-Credential -Message "Enter credentials for vCenter server: $Server"
            if (-not $credential) {
                return [PSCustomObject]@{
                    Success        = $false
                    Server         = $Server
                    SessionId      = $null
                    User           = $null
                    Message        = "Credential prompt was cancelled"
                    ConnectionTime = $null
                }
            }
        }
        else {
            return [PSCustomObject]@{
                Success        = $false
                Server         = $Server
                SessionId      = $null
                User           = $null
                Message        = "Credential retrieval failed and prompting disabled"
                ConnectionTime = $null
            }
        }
    }

    # Attempt vCenter connection
    try {
        Write-Verbose "VirtToolkit.VSphere: Connecting to $Server as $($credential.UserName)"
        $connectionStartTime = Get-Date
        
        $viConnection = Connect-VIServer -Server $Server -Credential $credential -Port $Port -ErrorAction Stop
        
        Write-Host "SUCCESS: VirtToolkit.VSphere: Successfully connected to $Server" -ForegroundColor Green
        
        return [PSCustomObject]@{
            Success        = $true
            Server         = $Server
            SessionId      = $viConnection.SessionId
            User           = $viConnection.User
            Message        = "Connection established successfully"
            ConnectionTime = $connectionStartTime
        }
    }
    catch {
        $errorMessage = "Failed to connect to $Server`: $($_.Exception.Message)"
        Write-Error "VirtToolkit.VSphere: $errorMessage"
        
        return [PSCustomObject]@{
            Success        = $false
            Server         = $Server
            SessionId      = $null
            User           = $null
            Message        = $errorMessage
            ConnectionTime = $null
        }
    }
}

function Disconnect-VirtToolkitVSphere {
    <#
    .SYNOPSIS
        Disconnects from VMware vCenter server with standardized cleanup.

    .DESCRIPTION
        Provides a unified interface for disconnecting from vCenter servers
        with proper cleanup and logging.

    .PARAMETER Server
        Specific vCenter server to disconnect from. If not specified, disconnects from all servers.

    .PARAMETER Force
        Force disconnection without confirmation prompts.

    .EXAMPLE
        Disconnect-VirtToolkitVSphere -Server "vcenter01.contoso.local"
        
        Description
        -----------
        Disconnects from specific vCenter server

    .EXAMPLE
        Disconnect-VirtToolkitVSphere -Force
        
        Description
        -----------
        Disconnects from all vCenter servers without confirmation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Server,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    try {
        if ($Server) {
            $connection = $global:DefaultVIServers | Where-Object { $_.Name -eq $Server }
            if ($connection) {
                Disconnect-VIServer -Server $connection -Confirm:(-not $Force) -Force:$Force -ErrorAction Stop
                Write-Verbose "VirtToolkit.VSphere: Disconnected from $Server"
            }
            else {
                Write-Warning "VirtToolkit.VSphere: No active connection found for $Server"
            }
        }
        else {
            if ($global:DefaultVIServers.Count -gt 0) {
                Disconnect-VIServer -Server * -Confirm:(-not $Force) -Force:$Force -ErrorAction Stop
                Write-Verbose "VirtToolkit.VSphere: Disconnected from all vCenter servers"
            }
            else {
                Write-Verbose "VirtToolkit.VSphere: No active vCenter connections found"
            }
        }
    }
    catch {
        Write-Error "VirtToolkit.VSphere: Disconnection error: $($_.Exception.Message)"
    }
}

function Test-VirtToolkitVSphereConnection {
    <#
    .SYNOPSIS
        Tests connectivity to a VMware vCenter server without establishing a persistent connection.

    .DESCRIPTION
        Validates that a vCenter server is reachable and credentials are valid
        without maintaining an active connection.

    .PARAMETER Server
        The vCenter server hostname or IP address to test.

    .PARAMETER CredentialName
        Name of the credential stored in SecretVault for testing.

    .PARAMETER Port
        Custom port for vCenter connection testing. Default: 443

    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Returns test result with properties:
        - Success: Boolean indicating test success
        - Server: vCenter server tested
        - Reachable: Boolean indicating network connectivity
        - Authenticated: Boolean indicating credential validation
        - Message: Status or error message
        - ResponseTime: Time taken for the test

    .EXAMPLE
        $testResult = Test-VirtToolkitVSphereConnection -Server "vcenter01.contoso.local" -CredentialName "ListVMs-vcenter01.contoso.local-admin"
        
        Description
        -----------
        Tests connection to vCenter server using specific credentials
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Server,

        [Parameter(Mandatory = $false)]
        [string]$CredentialName,

        [Parameter(Mandatory = $false)]
        [int]$Port = 443
    )

    $testStartTime = Get-Date
    
    # Test network connectivity first
    try {
        $pingTest = Test-NetConnection -ComputerName $Server -Port $Port -WarningAction SilentlyContinue
        if (-not $pingTest.TcpTestSucceeded) {
            return [PSCustomObject]@{
                Success       = $false
                Server        = $Server
                Reachable     = $false
                Authenticated = $false
                Message       = "Network connectivity test failed on port $Port"
                ResponseTime  = (Get-Date) - $testStartTime
            }
        }
    }
    catch {
        return [PSCustomObject]@{
            Success       = $false
            Server        = $Server
            Reachable     = $false
            Authenticated = $false
            Message       = "Network test error: $($_.Exception.Message)"
            ResponseTime  = (Get-Date) - $testStartTime
        }
    }

    # Test authentication if credentials provided
    $authenticated = $false
    if ($CredentialName) {
        try {
            $testConnection = Connect-VirtToolkitVSphere -Server $Server -CredentialName $CredentialName -AllowPrompt:$false
            if ($testConnection.Success) {
                $authenticated = $true
                # Clean up test connection
                Disconnect-VirtToolkitVSphere -Server $Server -Force
            }
        }
        catch {
            # Connection test failed, but server is reachable
        }
    }

    return [PSCustomObject]@{
        Success       = $true
        Server        = $Server
        Reachable     = $true
        Authenticated = $authenticated
        Message       = if ($authenticated) { "Connection and authentication successful" } else { "Server reachable, authentication not tested" }
        ResponseTime  = (Get-Date) - $testStartTime
    }
}

# Export module functions
Export-ModuleMember -Function Connect-VirtToolkitVSphere, Disconnect-VirtToolkitVSphere, Test-VirtToolkitVSphereConnection
