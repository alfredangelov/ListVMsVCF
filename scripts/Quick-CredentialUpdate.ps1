#Requires -Version 5.1
<#
.SYNOPSIS
    Quick vCenter credential setup/update utility

.DESCRIPTION
    Ensures the preferred SecretManagement vault from Configuration.psd1 exists
    (creates it if missing) and then prompts to set/update the configured
    credential inside that vault.

.EXAMPLE
    .\scripts\Quick-CredentialUpdate.ps1
    Creates the vault if needed and updates the credential.

.NOTES
    Author: VM Listing Toolkit
    Version: 1.1
    Dependencies: Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath
)

# Resolve paths
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ConfigPath) {
    $ConfigPath = Join-Path -Path $ScriptRoot -ChildPath "..\shared\Configuration.psd1"
}

Write-Host "🔑 Quick Credential Update" -ForegroundColor Cyan

# Load configuration
if (-not (Test-Path -Path $ConfigPath)) {
    Write-Host "❌ Configuration not found: $ConfigPath" -ForegroundColor Red
    exit 1
}

$config = Import-PowerShellDataFile -Path $ConfigPath
$server = $config.SourceServerHost
$credentialName = $config.CredentialName
$requestedVault = $config.preferredVault

Write-Host "Target Server: $server" -ForegroundColor Yellow
Write-Host "Credential Name: $credentialName" -ForegroundColor Yellow
Write-Host "Requested Vault: $requestedVault" -ForegroundColor Yellow

# Import helper module for vault/credential helpers if present
$modulePath = Join-Path -Path $ScriptRoot -ChildPath "..\modules\EnvironmentValidator.psm1"
if (Test-Path -Path $modulePath) {
    Import-Module -Name $modulePath -Force -ErrorAction SilentlyContinue
}

# Ensure required modules are available
try {
    Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction Stop
    Import-Module Microsoft.PowerShell.SecretStore -ErrorAction Stop
} catch {
    Write-Host "❌ Required modules missing: Microsoft.PowerShell.SecretManagement/SecretStore" -ForegroundColor Red
    Write-Host "Install them and retry: Install-Module Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore" -ForegroundColor Yellow
    exit 1
}

# Determine preferred vault (favor existing VCenterVault if available)
$preferredVault = if (Get-Command Get-PreferredVaultName -ErrorAction SilentlyContinue) {
    Get-PreferredVaultName -RequestedVaultName $requestedVault
} else {
    # Fallback: if VCenterVault exists, use it; else use requested name
    $existingVaults = Get-SecretVault -ErrorAction SilentlyContinue
    if ($existingVaults | Where-Object Name -eq 'VCenterVault') { 'VCenterVault' } else { $requestedVault }
}

Write-Host "Using Vault: $preferredVault" -ForegroundColor Cyan

# Ensure the vault exists (create if missing)
$vaultExists = $true
try {
    Get-SecretVault -Name $preferredVault -ErrorAction Stop | Out-Null
} catch {
    $vaultExists = $false
}

if (-not $vaultExists) {
    Write-Host "🔧 Vault '$preferredVault' not found. Creating..." -ForegroundColor Yellow
    # Try leveraging Initialize-CredentialManagement if available
    if (Get-Command Initialize-CredentialManagement -ErrorAction SilentlyContinue) {
        if (-not (Initialize-CredentialManagement -VaultName $preferredVault)) {
            Write-Host "❌ Failed to create or access vault '$preferredVault'" -ForegroundColor Red
            exit 1
        }
    } else {
        # Manual registration using SecretStore
        try {
            # Attempt register directly
            Register-SecretVault -Name $preferredVault -ModuleName Microsoft.PowerShell.SecretStore -ErrorAction Stop
        } catch {
            # If it fails, attempt SecretStore configuration once
            try {
                Set-SecretStoreConfiguration -Authentication Password -PasswordTimeout 900 -Interaction Prompt -Scope CurrentUser -Force
                Register-SecretVault -Name $preferredVault -ModuleName Microsoft.PowerShell.SecretStore -ErrorAction Stop
            } catch {
                Write-Host "❌ Vault registration failed: $($_.Exception.Message)" -ForegroundColor Red
                exit 1
            }
        }
        Write-Host "✅ Vault '$preferredVault' ready" -ForegroundColor Green
    }
}

# If an existing credential is present, show the username
try {
    $existing = Get-Secret -Name $credentialName -Vault $preferredVault -ErrorAction SilentlyContinue
    if ($existing -is [System.Management.Automation.PSCredential]) {
        Write-Host "Current User: $($existing.UserName)" -ForegroundColor White
    }
} catch { }

# Prompt for new credentials and store
$prompt = "Enter credentials for $server"
$newCred = Get-Credential -Message $prompt
if ($newCred) {
    try {
        Set-Secret -Name $credentialName -Secret $newCred -Vault $preferredVault -ErrorAction Stop
        Write-Host "✅ Credentials stored in vault '$preferredVault' as '$credentialName'" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to store credentials: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "❌ Cancelled by user" -ForegroundColor Yellow
    exit 1
}

Write-Host "Done." -ForegroundColor Green
