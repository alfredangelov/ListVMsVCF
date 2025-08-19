#Requires -Version 5.1
<#
.SYNOPSIS
    Quick vCenter credential update utility

.DESCRIPTION
    A simplified script to quickly update vCenter credentials in the SecretManagement vault.
    Reads the server from Configuration.psd1 and prompts for new credentials.

.EXAMPLE
    .\Quick-CredentialUpdate.ps1
    Quick credential update with minimal prompts

.NOTES
    Author: Permission Toolkit
    Version: 1.0
    Dependencies: Microsoft.PowerShell.SecretManagement
#>

# Quick credential update banner
Write-Host "🔑 Quick Credential Update" -ForegroundColor Cyan

# Load configuration for server info
$configPath = Join-Path $PSScriptRoot "shared\Configuration.psd1"
if (Test-Path $configPath) {
    $config = Import-PowerShellDataFile -Path $configPath
    $server = $config.SourceServerHost
    Write-Host "Target Server: $server" -ForegroundColor Yellow
} else {
    Write-Host "❌ Configuration not found" -ForegroundColor Red
    exit 1
}

# Check SecretManagement
if (-not (Get-Module -Name Microsoft.PowerShell.SecretManagement -ListAvailable)) {
    Write-Host "❌ SecretManagement module required" -ForegroundColor Red
    exit 1
}

Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction SilentlyContinue

# Get current credential info
$existing = Get-SecretInfo | Where-Object { $_.Name -eq "SourceCred" }
if ($existing) {
    $current = Get-Secret -Name "SourceCred" -ErrorAction SilentlyContinue
    Write-Host "Current User: $($current.UserName)" -ForegroundColor White
}

# Prompt for new credentials
$newCred = Get-Credential -Message "New credentials for $server"
if ($newCred) {
    Set-Secret -Name "SourceCred" -Secret $newCred
    Write-Host "✅ Credentials updated!" -ForegroundColor Green
} else {
    Write-Host "❌ Cancelled" -ForegroundColor Yellow
}
