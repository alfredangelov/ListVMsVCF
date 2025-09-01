#Requires -Version 5.1

<#
.SYNOPSIS
    Initialize Environment for VM Listing Toolkit
.DESCRIPTION
    This script initializes the environment by checking PowerShell version and installing required modules
.AUTHOR
    VM Listing Toolkit
.VERSION
    1.0.0
#>

[CmdletBinding()]
param()

# Get script directory and set up module path
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulePath = Join-Path -Path $ScriptRoot -ChildPath "..\modules"

# Import the environment validator module
$EnvironmentValidatorPath = Join-Path -Path $ModulePath -ChildPath "EnvironmentValidator.psm1"
if (-not (Test-Path -Path $EnvironmentValidatorPath)) {
    Write-Error "Cannot find EnvironmentValidator module at: $EnvironmentValidatorPath"
    exit 1
}

Import-Module -Name $EnvironmentValidatorPath -Force

# Display banner
Write-Host @"
╔════════════════════════════════════════════════════════════════════════════════╗
║                           VM Listing Toolkit                                  ║
║                        Environment Initialization                             ║
╚════════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Host ""
Write-Host "This script will check and prepare your PowerShell environment for the VM Listing Toolkit." -ForegroundColor White
Write-Host ""

# Check if running as administrator (helpful for some module installations)
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
    Write-Host "✓ Running with administrator privileges" -ForegroundColor Green
} else {
    Write-Host "ℹ Running without administrator privileges (modules will be installed for current user only)" -ForegroundColor Yellow
}
Write-Host ""

# Initialize the environment
$success = Initialize-Environment

# Load configuration for credential setup
$ConfigPath = Join-Path -Path $ScriptRoot -ChildPath "..\shared\Configuration.psd1"
if (Test-Path -Path $ConfigPath) {
    try {
        $config = Import-PowerShellDataFile -Path $ConfigPath
        Write-Host ""
        Write-Host "Credential configuration" -ForegroundColor Blue
        Write-Host "  Server: $($config.SourceServerHost)" -ForegroundColor Gray
        Write-Host "  Requested vault: $($config.preferredVault)" -ForegroundColor Gray
        Write-Host "  Credential name: $($config.CredentialName)" -ForegroundColor Gray

        # Determine preferred vault and check for existing credential; seed only if missing
        $preferredVault = Get-PreferredVaultName -RequestedVaultName $config.preferredVault
        $hasCred = Test-StoredCredential -CredentialName $config.CredentialName -ServerHost $config.SourceServerHost -VaultName $preferredVault

        if ($hasCred) {
            Write-Host "✅ Credential already present in vault '$preferredVault' — skipping setup" -ForegroundColor Green
        } else {
            Write-Host "🔧 Credential not found — initializing vault and storing credentials" -ForegroundColor Yellow
            $credentialSuccess = Initialize-VCenterCredentials -ServerHost $config.SourceServerHost -CredentialName $config.CredentialName -VaultName $preferredVault
            if (-not $credentialSuccess) {
                Write-Host "⚠️ Credential setup incomplete - you'll be prompted when connecting to vCenter" -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Host "⚠️ Could not load configuration for credential setup: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "   Credentials will be prompted when needed" -ForegroundColor Gray
    }
} else {
    Write-Host "⚠️ Configuration file not found - credentials will be prompted when needed" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan

if ($success) {
    Write-Host "🎉 Environment initialization completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "You can now run the VM listing script using:" -ForegroundColor White
    Write-Host "  .\scripts\List-VMs.ps1" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Or get environment status using:" -ForegroundColor White
    Write-Host "  Get-EnvironmentStatus" -ForegroundColor Cyan
} else {
    Write-Host "❌ Environment initialization completed with errors!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please resolve the issues above before running the VM listing script." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Common solutions:" -ForegroundColor White
    Write-Host "• Ensure you have internet connectivity for module downloads" -ForegroundColor Gray
    Write-Host "• Run PowerShell as Administrator if module installation fails" -ForegroundColor Gray
    Write-Host "• Update PowerShell to the latest version if version check fails" -ForegroundColor Gray
    exit 1
}

Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
