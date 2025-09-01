#Requires -Version 5.1

<#
.SYNOPSIS
    Environment validation module for the VM listing toolkit
.DESCRIPTION
    This module provides functions to validate PowerShell version and required modules
.AUTHOR
    VM Listing Toolkit
.VERSION
    1.0.0
#>

# Define required modules and their minimum versions
$Script:RequiredModules = @{
    'VMware.PowerCLI' = [version]'13.0.0'
    'Microsoft.PowerShell.SecretManagement' = [version]'1.1.0'
    'Microsoft.PowerShell.SecretStore' = [version]'1.0.0'
    'ImportExcel' = [version]'7.0.0'  # For Excel export functionality
}

# Define optional modules for enhanced functionality
$Script:OptionalModules = @{
    'VCF.PowerCLI' = @{
        MinVersion = [version]'1.0.0'
        Description = 'VMware Cloud Foundation support'
        Required = $false
    }
}

# Define minimum PowerShell version
$Script:MinimumPowerShellVersion = [version]'5.1'

function Test-PowerShellVersion {
    <#
    .SYNOPSIS
        Tests if the current PowerShell version meets minimum requirements
    .DESCRIPTION
        Validates that the PowerShell version is at least the minimum required version
    .OUTPUTS
        [bool] True if version is sufficient, False otherwise
    #>
    [CmdletBinding()]
    param()
    
    $currentVersion = $PSVersionTable.PSVersion
    Write-Verbose "Current PowerShell version: $currentVersion"
    Write-Verbose "Minimum required version: $Script:MinimumPowerShellVersion"
    
    if ($currentVersion -ge $Script:MinimumPowerShellVersion) {
        Write-Host "✓ PowerShell version $currentVersion meets minimum requirement ($Script:MinimumPowerShellVersion)" -ForegroundColor Green
        return $true
    } else {
        Write-Warning "✗ PowerShell version $currentVersion is below minimum requirement ($Script:MinimumPowerShellVersion)"
        Write-Host "Please upgrade PowerShell to version $Script:MinimumPowerShellVersion or higher" -ForegroundColor Yellow
        Write-Host "Download from: https://github.com/PowerShell/PowerShell/releases" -ForegroundColor Cyan
        return $false
    }
}

function Test-RequiredModule {
    <#
    .SYNOPSIS
        Tests if a specific module is installed with the required minimum version
    .PARAMETER ModuleName
        Name of the module to test
    .PARAMETER MinimumVersion
        Minimum version required
    .OUTPUTS
        [bool] True if module meets requirements, False otherwise
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,
        
        [Parameter(Mandatory = $true)]
        [version]$MinimumVersion
    )
    
    try {
        $installedModule = Get-Module -Name $ModuleName -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
        
        if ($null -eq $installedModule) {
            Write-Warning "✗ Module '$ModuleName' is not installed"
            return $false
        }
        
        if ($installedModule.Version -ge $MinimumVersion) {
            Write-Host "✓ Module '$ModuleName' version $($installedModule.Version) meets requirement ($MinimumVersion)" -ForegroundColor Green
            return $true
        } else {
            Write-Warning "✗ Module '$ModuleName' version $($installedModule.Version) is below minimum requirement ($MinimumVersion)"
            return $false
        }
    }
    catch {
        Write-Error "Error checking module '$ModuleName': $($_.Exception.Message)"
        return $false
    }
}

function Install-RequiredModule {
    <#
    .SYNOPSIS
        Installs a required module with error handling
    .PARAMETER ModuleName
        Name of the module to install
    .PARAMETER MinimumVersion
        Minimum version to install
    .OUTPUTS
        [bool] True if installation succeeded, False otherwise
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,
        
        [Parameter(Mandatory = $true)]
        [version]$MinimumVersion
    )
    
    try {
        Write-Host "Installing module '$ModuleName' (minimum version $MinimumVersion)..." -ForegroundColor Yellow
        
        # Install module for current user to avoid elevation requirements
        Install-Module -Name $ModuleName -MinimumVersion $MinimumVersion -Scope CurrentUser -Force -AllowClobber
        
        # Verify installation
        if (Test-RequiredModule -ModuleName $ModuleName -MinimumVersion $MinimumVersion) {
            Write-Host "✓ Successfully installed module '$ModuleName'" -ForegroundColor Green
            return $true
        } else {
            Write-Error "✗ Failed to verify installation of module '$ModuleName'"
            return $false
        }
    }
    catch {
        Write-Error "Error installing module '$ModuleName': $($_.Exception.Message)"
        return $false
    }
}

function Test-OptionalModule {
    <#
    .SYNOPSIS
        Tests if an optional module is installed and offers to install it
    .PARAMETER ModuleName
        Name of the module to test
    .PARAMETER ModuleInfo
        Module information hashtable containing MinVersion, Description, Required
    .OUTPUTS
        [bool] True if module is available or user chooses not to install, False if installation fails
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$ModuleInfo
    )
    
    try {
        $installedModule = Get-Module -Name $ModuleName -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
        
        if ($null -eq $installedModule) {
            Write-Host "ℹ Optional module '$ModuleName' is not installed" -ForegroundColor Yellow
            Write-Host "  Description: $($ModuleInfo.Description)" -ForegroundColor Gray
            
            $choice = Read-Host "Would you like to install '$ModuleName'? (y/N)"
            if ($choice -match '^[Yy]') {
                return Install-OptionalModule -ModuleName $ModuleName -MinimumVersion $ModuleInfo.MinVersion
            } else {
                Write-Host "  Skipping installation of '$ModuleName'" -ForegroundColor Gray
                return $true  # Not an error, user chose not to install
            }
        }
        
        if ($installedModule.Version -ge $ModuleInfo.MinVersion) {
            Write-Host "✓ Optional module '$ModuleName' version $($installedModule.Version) is available" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠ Optional module '$ModuleName' version $($installedModule.Version) is below recommended version ($($ModuleInfo.MinVersion))" -ForegroundColor Yellow
            
            $choice = Read-Host "Would you like to update '$ModuleName'? (y/N)"
            if ($choice -match '^[Yy]') {
                return Install-OptionalModule -ModuleName $ModuleName -MinimumVersion $ModuleInfo.MinVersion
            } else {
                Write-Host "  Continuing with current version of '$ModuleName'" -ForegroundColor Gray
                return $true  # Not an error, user chose not to update
            }
        }
    }
    catch {
        Write-Warning "Error checking optional module '$ModuleName': $($_.Exception.Message)"
        return $true  # Don't fail the entire process for optional modules
    }
}

function Install-OptionalModule {
    <#
    .SYNOPSIS
        Installs an optional module with error handling
    .PARAMETER ModuleName
        Name of the module to install
    .PARAMETER MinimumVersion
        Minimum version to install
    .OUTPUTS
        [bool] True if installation succeeded, False otherwise
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,
        
        [Parameter(Mandatory = $true)]
        [version]$MinimumVersion
    )
    
    try {
        Write-Host "Installing optional module '$ModuleName' (minimum version $MinimumVersion)..." -ForegroundColor Yellow
        
        # Install module for current user to avoid elevation requirements
        Install-Module -Name $ModuleName -MinimumVersion $MinimumVersion -Scope CurrentUser -Force -AllowClobber
        
        # Verify installation
        $installedModule = Get-Module -Name $ModuleName -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
        if ($null -ne $installedModule -and $installedModule.Version -ge $MinimumVersion) {
            Write-Host "✓ Successfully installed optional module '$ModuleName'" -ForegroundColor Green
            return $true
        } else {
            Write-Warning "✗ Failed to verify installation of optional module '$ModuleName'"
            return $false
        }
    }
    catch {
        Write-Warning "Error installing optional module '$ModuleName': $($_.Exception.Message)"
        Write-Host "  This is an optional module - continuing without it" -ForegroundColor Gray
        return $false
    }
}

function Initialize-Environment {
    <#
    .SYNOPSIS
        Initializes the environment by validating and installing required components
    .DESCRIPTION
        Checks PowerShell version and installs missing or outdated modules
    .OUTPUTS
        [bool] True if environment is ready, False if critical issues exist
    #>
    [CmdletBinding()]
    param()
    
    Write-Host "=== VM Listing Toolkit - Environment Initialization ===" -ForegroundColor Cyan
    Write-Host ""
    
    $allGood = $true
    
    # Check PowerShell version
    Write-Host "Checking PowerShell version..." -ForegroundColor Blue
    if (-not (Test-PowerShellVersion)) {
        $allGood = $false
    }
    Write-Host ""
    
    # Check and install required modules
    Write-Host "Checking required modules..." -ForegroundColor Blue
    
    foreach ($module in $Script:RequiredModules.GetEnumerator()) {
        $moduleName = $module.Key
        $minVersion = $module.Value
        
        if (-not (Test-RequiredModule -ModuleName $moduleName -MinimumVersion $minVersion)) {
            Write-Host "Attempting to install $moduleName..." -ForegroundColor Yellow
            
            if (-not (Install-RequiredModule -ModuleName $moduleName -MinimumVersion $minVersion)) {
                Write-Error "Critical: Failed to install required module '$moduleName'"
                $allGood = $false
            }
        }
    }
    
    Write-Host ""
    
    # Check and offer to install optional modules
    if ($Script:OptionalModules.Count -gt 0) {
        Write-Host "Checking optional modules for enhanced functionality..." -ForegroundColor Blue
        
        foreach ($module in $Script:OptionalModules.GetEnumerator()) {
            $moduleName = $module.Key
            $moduleInfo = $module.Value
            
            Test-OptionalModule -ModuleName $moduleName -ModuleInfo $moduleInfo | Out-Null
        }
        
        Write-Host ""
    }
    
    if ($allGood) {
        Write-Host "✓ Environment initialization completed successfully!" -ForegroundColor Green
        Write-Host "All required components are available and ready for use." -ForegroundColor Green
    } else {
        Write-Host "✗ Environment initialization completed with errors!" -ForegroundColor Red
        Write-Host "Please resolve the issues above before proceeding." -ForegroundColor Red
    }
    
    return $allGood
}

function Get-EnvironmentStatus {
    <#
    .SYNOPSIS
        Gets the current status of the environment
    .DESCRIPTION
        Returns a summary of PowerShell version and module status
    .OUTPUTS
        [hashtable] Environment status information
    #>
    [CmdletBinding()]
    param()
    
    $status = @{
        PowerShellVersion = $PSVersionTable.PSVersion
        PowerShellVersionOK = (Test-PowerShellVersion)
        Modules = @{}
        OptionalModules = @{}
        AllModulesOK = $true
    }
    
    foreach ($module in $Script:RequiredModules.GetEnumerator()) {
        $moduleName = $module.Key
        $minVersion = $module.Value
        $moduleOK = Test-RequiredModule -ModuleName $moduleName -MinimumVersion $minVersion
        
        $status.Modules[$moduleName] = @{
            Required = $minVersion
            Installed = if ($moduleOK) { 
                (Get-Module -Name $moduleName -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Version 
            } else { 
                "Not installed or insufficient version" 
            }
            OK = $moduleOK
        }
        
        if (-not $moduleOK) {
            $status.AllModulesOK = $false
        }
    }
    
    # Check optional modules
    foreach ($module in $Script:OptionalModules.GetEnumerator()) {
        $moduleName = $module.Key
        $moduleInfo = $module.Value
        $installedModule = Get-Module -Name $moduleName -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
        
        $status.OptionalModules[$moduleName] = @{
            Recommended = $moduleInfo.MinVersion
            Description = $moduleInfo.Description
            Installed = if ($null -ne $installedModule) { $installedModule.Version } else { "Not installed" }
            Available = ($null -ne $installedModule)
            UpToDate = if ($null -ne $installedModule) { $installedModule.Version -ge $moduleInfo.MinVersion } else { $false }
        }
    }
    
    return $status
}

function Initialize-CredentialManagement {
    <#
    .SYNOPSIS
        Initializes credential management using PowerShell SecretManagement
    .DESCRIPTION
        Sets up the secret vault and validates credential storage capabilities.
        Prioritizes using existing "VCenterVault" if available.
    .PARAMETER VaultName
        Name of the secret vault to use (default: 'VCenterVault')
    .OUTPUTS
        [bool] True if credential management is ready, False otherwise
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$VaultName = 'VCenterVault'
    )
    
    Write-Host ""
    Write-Host "🔐 CREDENTIAL MANAGEMENT" -ForegroundColor Yellow
    Write-Host "─────────────────────────────────────────────────────────"
    
    $allGood = $true
    
    # Check if SecretManagement module is available
    try {
        Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction Stop
        Write-Host "✅ SecretManagement module available" -ForegroundColor Green
    } catch {
        Write-Host "❌ SecretManagement module not found" -ForegroundColor Red
        Write-Host "💡 Install with: Install-Module Microsoft.PowerShell.SecretManagement" -ForegroundColor Yellow
        $allGood = $false
    }
    
    # Check if SecretStore module is available
    try {
        Import-Module Microsoft.PowerShell.SecretStore -ErrorAction Stop
        Write-Host "✅ SecretStore module available" -ForegroundColor Green
    } catch {
        Write-Host "❌ SecretStore module not found" -ForegroundColor Red
        Write-Host "💡 Install with: Install-Module Microsoft.PowerShell.SecretStore" -ForegroundColor Yellow
        $allGood = $false
    }
    
    if (-not $allGood) {
        return $false
    }
    
    # Check for existing secret vaults
    Write-Host "🔍 Checking for existing secret vaults..."
    $existingVaults = Get-SecretVault -ErrorAction SilentlyContinue
    
    if ($existingVaults) {
        Write-Host "📋 Found existing secret vault(s):" -ForegroundColor Cyan
        foreach ($vault in $existingVaults) {
            $status = if ($vault.IsDefault) { " (Default)" } else { "" }
            Write-Host "  • $($vault.Name) - $($vault.ModuleName)$status" -ForegroundColor Gray
        }
        Write-Host ""
        
        # Check if the specified vault exists
        $targetVault = $existingVaults | Where-Object { $_.Name -eq $VaultName }
        if ($targetVault) {
            Write-Host "✅ Using existing vault: $VaultName" -ForegroundColor Green
            return $true
        } else {
            # Check if there's a VCenterVault specifically (in case user passed different name)
            $vcenterVault = $existingVaults | Where-Object { $_.Name -eq 'VCenterVault' }
            if ($vcenterVault -and $VaultName -ne 'VCenterVault') {
                Write-Host "📌 Found existing 'VCenterVault' - using that instead of '$VaultName'" -ForegroundColor Cyan
                return $true
            }
        }
    }
    
    # Only create vault if it doesn't exist and no VCenterVault is available
    if (-not $existingVaults -or (-not ($existingVaults | Where-Object { $_.Name -eq $VaultName }) -and -not ($existingVaults | Where-Object { $_.Name -eq 'VCenterVault' }))) {
        Write-Host "🔧 Creating new secret vault: $VaultName" -ForegroundColor Cyan
        try {
            # Check if SecretStore needs to be configured first
            try {
                # Try to register the vault
                Register-SecretVault -Name $VaultName -ModuleName Microsoft.PowerShell.SecretStore -ErrorAction Stop
                Write-Host "✅ Secret vault created successfully: $VaultName" -ForegroundColor Green
                
                # Test vault functionality by attempting to set/get a test secret
                try {
                    $testSecretName = "test-connectivity-$(Get-Random)"
                    Set-Secret -Name $testSecretName -Secret "test-value" -Vault $VaultName -ErrorAction Stop
                    $retrievedValue = Get-Secret -Name $testSecretName -Vault $VaultName -AsPlainText -ErrorAction Stop
                    Remove-Secret -Name $testSecretName -Vault $VaultName -ErrorAction SilentlyContinue
                    
                    if ($retrievedValue -eq "test-value") {
                        Write-Host "✅ Vault functionality verified" -ForegroundColor Green
                        return $true
                    } else {
                        Write-Host "⚠️ Vault created but functionality test failed" -ForegroundColor Yellow
                        return $true  # Still return true as vault exists
                    }
                } catch {
                    Write-Host "⚠️ Vault created but functionality test failed: $($_.Exception.Message)" -ForegroundColor Yellow
                    Write-Host "💡 You may need to configure the SecretStore vault password when first used" -ForegroundColor Cyan
                    return $true  # Still return true as vault exists
                }
            } catch {
                # If registration fails, it might be because SecretStore needs initial configuration
                Write-Host "⚠️ Initial vault registration failed. Attempting SecretStore configuration..." -ForegroundColor Yellow
                
                try {
                    # Try to configure SecretStore with reasonable defaults
                    $storeConfig = @{
                        Authentication = 'Password'
                        PasswordTimeout = 900  # 15 minutes
                        Interaction = 'Prompt'
                        Scope = 'CurrentUser'
                    }
                    
                    Write-Host "🔧 Configuring SecretStore with default settings..." -ForegroundColor Cyan
                    Set-SecretStoreConfiguration @storeConfig -Force -ErrorAction Stop
                    
                    # Now try to register the vault again
                    Register-SecretVault -Name $VaultName -ModuleName Microsoft.PowerShell.SecretStore -ErrorAction Stop
                    Write-Host "✅ Secret vault created successfully: $VaultName (after configuration)" -ForegroundColor Green
                    return $true
                } catch {
                    Write-Host "❌ Failed to create vault even after configuration: $($_.Exception.Message)" -ForegroundColor Red
                    Write-Host "💡 Manual steps required:" -ForegroundColor Yellow
                    Write-Host "   1. Run: Set-SecretStoreConfiguration -Authentication Password -Interaction Prompt" -ForegroundColor Gray
                    Write-Host "   2. Run: Register-SecretVault -Name '$VaultName' -ModuleName Microsoft.PowerShell.SecretStore" -ForegroundColor Gray
                    return $false
                }
            }
        } catch {
            Write-Host "❌ Failed to create vault: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "💡 This may require the SecretStore module or additional permissions" -ForegroundColor Yellow
            return $false
        }
    } else {
        Write-Host "✅ Credential management ready using existing vault" -ForegroundColor Green
        return $true
    }
}

function Get-PreferredVaultName {
    <#
    .SYNOPSIS
        Determines the preferred vault name to use for credential storage
    .DESCRIPTION
        Checks for existing VCenterVault first, then falls back to provided name
    .PARAMETER RequestedVaultName
        The vault name that was requested (default: 'VCenterVault')
    .OUTPUTS
        [string] The name of the vault to use
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$RequestedVaultName = 'VCenterVault'
    )
    
    try {
        $existingVaults = Get-SecretVault -ErrorAction SilentlyContinue
        
        if ($existingVaults) {
            # Always prefer VCenterVault if it exists
            $vcenterVault = $existingVaults | Where-Object { $_.Name -eq 'VCenterVault' }
            if ($vcenterVault) {
                Write-Verbose "Using existing VCenterVault"
                return 'VCenterVault'
            }
            
            # If requested vault exists, use it
            $requestedVault = $existingVaults | Where-Object { $_.Name -eq $RequestedVaultName }
            if ($requestedVault) {
                Write-Verbose "Using existing vault: $RequestedVaultName"
                return $RequestedVaultName
            }
        }
        
        # Default to VCenterVault
        Write-Verbose "Defaulting to VCenterVault"
        return 'VCenterVault'
    } catch {
        Write-Verbose "Error checking vaults, defaulting to VCenterVault: $($_.Exception.Message)"
        return 'VCenterVault'
    }
}

function Test-StoredCredential {
    <#
    .SYNOPSIS
        Checks if a credential is stored in the secret vault and validates it
    .PARAMETER CredentialName
        Name of the stored credential
    .PARAMETER ServerHost
        Server hostname for credential validation (optional)
    .PARAMETER VaultName
        Name of the secret vault to check (optional)
    .OUTPUTS
        [bool] True if credential exists and is accessible, False otherwise
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CredentialName,
        
        [Parameter(Mandatory = $false)]
        [string]$ServerHost,
        
        [Parameter(Mandatory = $false)]
        [string]$VaultName
    )
    
    Write-Host "🔑 Checking stored credential: $CredentialName" -ForegroundColor Cyan
    
    # Determine which vault to use
    $vaultToUse = if ($VaultName) { $VaultName } else { Get-PreferredVaultName }
    Write-Verbose "Using vault: $vaultToUse"
    
    try {
        # Try to get the credential from the vault
        $getSecretParams = @{
            Name = $CredentialName
            ErrorAction = 'Stop'
        }
        
        # Only specify vault if we have a preference and it exists
        try {
            $existingVaults = Get-SecretVault -ErrorAction SilentlyContinue
            if ($existingVaults -and ($existingVaults | Where-Object { $_.Name -eq $vaultToUse })) {
                $getSecretParams.Vault = $vaultToUse
            }
        } catch {
            Write-Verbose "Could not check vault existence, will try without specifying vault"
        }
        
        $storedSecret = Get-Secret @getSecretParams
        
        if ($storedSecret) {
            if ($storedSecret -is [System.Management.Automation.PSCredential]) {
                Write-Host "✅ Credential found and accessible: $CredentialName" -ForegroundColor Green
                Write-Host "   Username: $($storedSecret.UserName)" -ForegroundColor Gray
                return $true
            } else {
                Write-Host "⚠️ Credential found but not in PSCredential format: $CredentialName" -ForegroundColor Yellow
                return $false
            }
        } else {
            Write-Host "❌ Credential not found: $CredentialName" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "❌ Error accessing credential '$CredentialName': $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Set-VCenterCredential {
    <#
    .SYNOPSIS
        Stores or updates vCenter credentials in the secret vault
    .PARAMETER CredentialName
        Name to store the credential under
    .PARAMETER ServerHost
        vCenter server hostname for context
    .PARAMETER VaultName
        Name of the secret vault to use (optional)
    .PARAMETER Force
        Force credential update even if it already exists
    .OUTPUTS
        [bool] True if credential was stored successfully, False otherwise
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CredentialName,
        
        [Parameter(Mandatory = $true)]
        [string]$ServerHost,
        
        [Parameter(Mandatory = $false)]
        [string]$VaultName,
        
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
    
    Write-Host "🔐 Setting up credential: $CredentialName" -ForegroundColor Cyan
    
    # Determine which vault to use
    $vaultToUse = if ($VaultName) { $VaultName } else { Get-PreferredVaultName }
    Write-Verbose "Using vault: $vaultToUse"
    
    # Check if credential already exists (unless forced)
    if (-not $Force -and (Test-StoredCredential -CredentialName $CredentialName -VaultName $vaultToUse)) {
        Write-Host "✅ Credential already exists: $CredentialName (use -Force to update)" -ForegroundColor Green
        return $true
    }
    
    # Prompt for credentials
    $promptMessage = "Enter vCenter credentials for $ServerHost"
    Write-Host "📝 $promptMessage" -ForegroundColor Yellow
    
    $credential = Get-Credential -Message $promptMessage
    if (-not $credential) {
        Write-Host "❌ Credential entry cancelled" -ForegroundColor Red
        return $false
    }
    
    # Store the credential
    try {
        $setSecretParams = @{
            Name = $CredentialName
            Secret = $credential
            ErrorAction = 'Stop'
        }
        
        # Only specify vault if it exists
        try {
            $existingVaults = Get-SecretVault -ErrorAction SilentlyContinue
            if ($existingVaults -and ($existingVaults | Where-Object { $_.Name -eq $vaultToUse })) {
                $setSecretParams.Vault = $vaultToUse
            }
        } catch {
            Write-Verbose "Could not check vault existence, will try without specifying vault"
        }
        
        Set-Secret @setSecretParams
        Write-Host "✅ Credential stored successfully: $CredentialName" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "❌ Failed to store credential: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Get-VCenterCredential {
    <#
    .SYNOPSIS
        Retrieves vCenter credentials from the secret vault
    .PARAMETER CredentialName
        Name of the stored credential
    .PARAMETER VaultName
        Name of the secret vault to check (optional)
    .OUTPUTS
        [PSCredential] The stored credential, or $null if not found
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CredentialName,
        
        [Parameter(Mandatory = $false)]
        [string]$VaultName
    )
    
    # Determine which vault to use
    $vaultToUse = if ($VaultName) { $VaultName } else { Get-PreferredVaultName }
    Write-Verbose "Using vault: $vaultToUse"
    
    try {
        $getSecretParams = @{
            Name = $CredentialName
            ErrorAction = 'Stop'
        }
        
        # Only specify vault if it exists
        try {
            $existingVaults = Get-SecretVault -ErrorAction SilentlyContinue
            if ($existingVaults -and ($existingVaults | Where-Object { $_.Name -eq $vaultToUse })) {
                $getSecretParams.Vault = $vaultToUse
            }
        } catch {
            Write-Verbose "Could not check vault existence, will try without specifying vault"
        }
        
        $credential = Get-Secret @getSecretParams
        
        if ($credential -is [System.Management.Automation.PSCredential]) {
            return $credential
        } else {
            Write-Warning "Stored secret '$CredentialName' is not a PSCredential object"
            return $null
        }
    } catch {
        Write-Verbose "Could not retrieve credential '$CredentialName': $($_.Exception.Message)"
        return $null
    }
}

function Initialize-VCenterCredentials {
    <#
    .SYNOPSIS
        Initializes vCenter credentials for the toolkit
    .PARAMETER ServerHost
        vCenter server hostname
    .PARAMETER CredentialName
        Name to store the credential under (default: 'VCenterCred')
    .PARAMETER VaultName
        Name of the secret vault to use (default: 'VCenterVault')
    .OUTPUTS
        [bool] True if credentials are ready, False otherwise
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServerHost,
        
        [Parameter(Mandatory = $false)]
        [string]$CredentialName = 'SourceCred',
        
        [Parameter(Mandatory = $false)]
        [string]$VaultName = 'VCenterVault'
    )
    
    # Determine which vault to use
    $vaultToUse = Get-PreferredVaultName -RequestedVaultName $VaultName
    Write-Verbose "Using vault: $vaultToUse"
    
    # Initialize credential management
    if (-not (Initialize-CredentialManagement -VaultName $vaultToUse)) {
        Write-Host "❌ Credential management initialization failed" -ForegroundColor Red
        return $false
    }
    
    # Check for existing credentials
    if (Test-StoredCredential -CredentialName $CredentialName -ServerHost $ServerHost -VaultName $vaultToUse) {
        Write-Host "✅ vCenter credentials are already configured and ready for use" -ForegroundColor Green
        Write-Host "   Credential: '$CredentialName' in vault '$vaultToUse'" -ForegroundColor Gray
        return $true
    }
    
    # Set up new credentials
    Write-Host ""
    Write-Host "🔧 Setting up vCenter credentials..." -ForegroundColor Blue
    Write-Host "   Server: $ServerHost" -ForegroundColor Gray
    Write-Host "   Credential Name: $CredentialName" -ForegroundColor Gray
    Write-Host "   Vault: $vaultToUse" -ForegroundColor Gray
    $credentialSuccess = Set-VCenterCredential -CredentialName $CredentialName -ServerHost $ServerHost -VaultName $vaultToUse
    
    if ($credentialSuccess) {
        Write-Host "✅ vCenter credential setup completed" -ForegroundColor Green
        return $true
    } else {
        Write-Host "❌ vCenter credential setup failed" -ForegroundColor Red
        return $false
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Test-PowerShellVersion',
    'Test-RequiredModule', 
    'Install-RequiredModule',
    'Initialize-Environment',
    'Get-EnvironmentStatus',
    'Initialize-CredentialManagement',
    'Get-PreferredVaultName',
    'Test-StoredCredential',
    'Set-VCenterCredential',
    'Get-VCenterCredential',
    'Initialize-VCenterCredentials'
)
