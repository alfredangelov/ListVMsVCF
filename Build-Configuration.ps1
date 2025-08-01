Write-Host "`n🛠️ PERMISSION TOOLKIT CONFIGURATION BUILDER" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Building configuration for advanced vSphere permission analysis" -ForegroundColor Gray

# Helper function for boolean prompts
function Read-Bool ($Prompt, $Default) {
    $defaultText = if ($Default) { "[Y/n]" } else { "[y/N]" }
    while ($true) {
        $input = Read-Host "$Prompt $defaultText"
        if ([string]::IsNullOrWhiteSpace($input)) { return $Default }
        switch ($input.ToLower()) {
            'y' { return $true }
            'n' { return $false }
            default { Write-Host "Please enter 'y' or 'n'." -ForegroundColor Yellow }
        }
    }
}

# Helper function for choice prompts
function Read-Choice ($Prompt, $Options, $Default) {
    $optionText = ($Options | ForEach-Object { if ($_ -eq $Default) { "[$_]" } else { $_ } }) -join "/"
    while ($true) {
        $input = Read-Host "$Prompt ($optionText)"
        if ([string]::IsNullOrWhiteSpace($input)) { return $Default }
        if ($input -in $Options) { return $input }
        Write-Host "Please enter one of: $($Options -join ', ')" -ForegroundColor Yellow
    }
}

Write-Host "`n📋 BASIC CONFIGURATION" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────"

# Core settings
$dryRun = Read-Bool "Enable dry run mode (recommended for first run)?" $true
$sourceHost = Read-Host "Enter source vCenter server hostname"
$vCenterVersion = Read-Choice "vCenter version" @('6.7', '7.0', '8.0') '8.0'
Write-Host "`n📊 PERMISSION EXPORT OPTIONS" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────"

$exportGlobal = Read-Bool "Export global permissions?" $true
$exportNormal = Read-Bool "Export normal (object-level) permissions?" $true

# Prompt for datacenter if normal permissions are exported
$dataCenter = $null
if ($exportNormal) {
    $dataCenter = Read-Host "Enter the name of the datacenter in source vCenter"
}

Write-Host "`n🔍 SSO & SECURITY ANALYSIS" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────"

$enableSsoAnalysis = Read-Bool "Enable SSO analysis (detect external domain members)?" $true

Write-Host "`n🚫 PERMISSION FILTERING" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────"

$enablePermissionExclusion = Read-Bool "Enable permission exclusion filtering (reduces noise)?" $true
$exclusionFilePath = "exclude-permissions.txt"
if ($enablePermissionExclusion) {
    Write-Host "ℹ️ Exclusion patterns will be loaded from: $exclusionFilePath" -ForegroundColor Cyan
    Write-Host "   You can customize exclusion patterns by editing this file" -ForegroundColor Gray
}

Write-Host "`n🎨 TOOLTIP ENHANCEMENT" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────"

$enableTooltips = Read-Bool "Enable interactive tooltip enhancement for HTML reports?" $true
$tooltipTheme = 'Dark'
$tooltipMaxWidth = 320
$tooltipChunkSize = 300

if ($enableTooltips) {
    $tooltipTheme = Read-Choice "Tooltip theme" @('Dark', 'Light', 'Blue') 'Dark'
    
    Write-Host "💡 Advanced tooltip settings (press Enter for defaults):" -ForegroundColor Cyan
    $maxWidthInput = Read-Host "Maximum tooltip width in pixels [320]"
    if (![string]::IsNullOrWhiteSpace($maxWidthInput) -and $maxWidthInput -match '^\d+$') {
        $tooltipMaxWidth = [int]$maxWidthInput
    }
    
    $chunkSizeInput = Read-Host "Tooltip processing chunk size [300]"
    if (![string]::IsNullOrWhiteSpace($chunkSizeInput) -and $chunkSizeInput -match '^\d+$') {
        $tooltipChunkSize = [int]$chunkSizeInput
    }
}

Write-Host "`n⚙️ BUILDING CONFIGURATION..." -ForegroundColor Cyan

# Build configuration hashtable
$config = @{
    # Core settings
    DryRun                = $dryRun
    SourceServerHost      = $sourceHost
    vCenterVersion        = $vCenterVersion
    
    # Permission export options
    ExportGlobalPermissions = $exportGlobal
    ExportNormalPermissions = $exportNormal
    
    # SSO Analysis options
    EnableSsoAnalysis = $enableSsoAnalysis
    
    # Permission filtering options
    EnablePermissionExclusion = $enablePermissionExclusion
    
    # Tooltip configuration
    EnableTooltips = $enableTooltips
    TooltipTheme = $tooltipTheme
    TooltipMaxWidth = $tooltipMaxWidth
    TooltipChunkSize = $tooltipChunkSize
}

# Add optional settings conditionally
if ($exportNormal -and ![string]::IsNullOrWhiteSpace($dataCenter)) {
    $config.dataCenter = $dataCenter
}

if ($enablePermissionExclusion) {
    $config.ExclusionFilePath = $exclusionFilePath
}

# Output path
$configPath = Join-Path $PSScriptRoot 'shared\Configuration.psd1'

# Ensure shared directory exists
$sharedDir = Split-Path $configPath -Parent
if (-not (Test-Path $sharedDir)) {
    New-Item -Path $sharedDir -ItemType Directory -Force | Out-Null
}

Write-Host "📁 Saving configuration to: $configPath" -ForegroundColor Cyan

# Open file and write the opening brace with header comments
$header = @"
@{
    # ═══════════════════════════════════════════════════════════
    # Permission Toolkit Configuration
    # ═══════════════════════════════════════════════════════════
    # Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    # vCenter: $sourceHost
    # Version: $vCenterVersion
    # ═══════════════════════════════════════════════════════════

    # Core Settings
    # If `$true, actions will be simulated and no changes will be made
    DryRun                = `$$($config.DryRun.ToString().ToLower())

    # vSphere source server connection details
    SourceServerHost      = '$($config.SourceServerHost)'
    vCenterVersion        = '$($config.vCenterVersion)'  # vCenter version (affects API endpoint availability)

    # Permission Export Options
    ExportGlobalPermissions = `$$($config.ExportGlobalPermissions.ToString().ToLower())  # Export global permissions
    ExportNormalPermissions = `$$($config.ExportNormalPermissions.ToString().ToLower())   # Export normal (object-level) permissions
"@

Set-Content -Path $configPath -Value $header -Encoding utf8

# Add datacenter if specified
if ($config.ContainsKey('dataCenter')) {
    Add-Content -Path $configPath -Value ""
    Add-Content -Path $configPath -Value "    # Optional: Datacenter name for object-level permissions"
    Add-Content -Path $configPath -Value "    dataCenter = '$($config.dataCenter)'"
}

# Add SSO analysis section
Add-Content -Path $configPath -Value ""
Add-Content -Path $configPath -Value "    # SSO Analysis Options"
Add-Content -Path $configPath -Value "    EnableSsoAnalysis = `$$($config.EnableSsoAnalysis.ToString().ToLower())                       # Analyze SSO groups for external domain members"

# Add permission filtering section
Add-Content -Path $configPath -Value ""
Add-Content -Path $configPath -Value "    # Permission Filtering Options"
Add-Content -Path $configPath -Value "    EnablePermissionExclusion = `$$($config.EnablePermissionExclusion.ToString().ToLower())                    # Set to `$true to enable exclusion filtering"

if ($config.ContainsKey('ExclusionFilePath')) {
    Add-Content -Path $configPath -Value "    ExclusionFilePath = '$($config.ExclusionFilePath)'       # Path to exclusion file (relative to script root)"
}

# Add tooltip configuration section
Add-Content -Path $configPath -Value ""
Add-Content -Path $configPath -Value "    # Tooltip Enhancement Options"
Add-Content -Path $configPath -Value "    EnableTooltips = `$$($config.EnableTooltips.ToString().ToLower())        # Set to `$true to auto-enhance reports with tooltips"
Add-Content -Path $configPath -Value "    TooltipTheme = '$($config.TooltipTheme)'          # Options: Dark, Light, Blue"
Add-Content -Path $configPath -Value "    TooltipMaxWidth = $($config.TooltipMaxWidth)          # Maximum tooltip width in pixels"
Add-Content -Path $configPath -Value "    TooltipChunkSize = $($config.TooltipChunkSize)         # Number of tooltips to process per chunk (helps manage memory)"

# Write the closing brace
Add-Content -Path $configPath -Value "}"

if (Test-Path $configPath) {
    Write-Host "✅ Configuration saved successfully!" -ForegroundColor Green
    Write-Host "   📁 Location: $configPath" -ForegroundColor Gray
} else {
    Write-Host "❌ Failed to save configuration to $configPath" -ForegroundColor Red
    exit 1
}

Write-Host "`n🔐 CREDENTIAL MANAGEMENT" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────"

# Check if SecretManagement module is available
try {
    Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction Stop
    Write-Host "✅ SecretManagement module available" -ForegroundColor Green
} catch {
    Write-Host "❌ SecretManagement module not found" -ForegroundColor Red
    Write-Host "💡 Install with: Install-Module Microsoft.PowerShell.SecretManagement" -ForegroundColor Yellow
    exit 1
}

# Register Vault (if missing)
Write-Host "� Checking secret vault registration..."
if (-not (Get-SecretVault | Where-Object { $_.Name -eq "VCenterVault" })) {
    Write-Host "� Registering vault: VCenterVault"
    try {
        Register-SecretVault -Name VCenterVault -ModuleName Microsoft.PowerShell.SecretStore -ErrorAction Stop
        Write-Host "✅ Secret vault registered successfully" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to register vault: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "💡 You may need to install: Install-Module Microsoft.PowerShell.SecretStore" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "✅ Secret vault already registered: VCenterVault" -ForegroundColor Green
}

# Store credentials with enhanced validation
function Test-Credential {
    param (
        [string]$Name,
        [string]$Prompt,
        [string]$Description
    )
    
    Write-Host "🔑 Checking credential: $Name" -ForegroundColor Cyan
    
    if (-not (Get-SecretInfo | Where-Object { $_.Name -eq $Name })) {
        Write-Host "� $Description"
        $cred = Get-Credential -Message $Prompt
        if (-not $cred) {
            Write-Host "❌ Credential entry cancelled" -ForegroundColor Red
            return $false
        }
        
        try {
            Set-Secret -Name $Name -Secret $cred -ErrorAction Stop
            Write-Host "✅ Credential stored successfully: $Name" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "❌ Failed to store credential: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "✅ Credential already stored: $Name" -ForegroundColor Green
        return $true
    }
}

$credentialSuccess = Test-Credential -Name "SourceCred" `
    -Prompt "Enter source vCenter credentials for $sourceHost" `
    -Description "Setting up credentials for vCenter server access"

if (-not $credentialSuccess) {
    Write-Host "❌ Credential setup failed. Please re-run this script." -ForegroundColor Red
    exit 1
}

Write-Host "`n🧾 VERIFICATION" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────"

Write-Host "📋 Stored secrets:"
Get-SecretInfo | Where-Object { $_.Name -in @("SourceCred") } | Format-Table Name, VaultName, @{Name="LastAccessed";Expression={$_.LastAccessTime}} -AutoSize

Write-Host "`n🎯 CONFIGURATION COMPLETE!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "✅ Configuration file created with all advanced features" -ForegroundColor Green
Write-Host "✅ Secret vault registered and credentials stored" -ForegroundColor Green
Write-Host "✅ Ready for permission analysis!" -ForegroundColor Green

Write-Host "`n📖 NEXT STEPS:" -ForegroundColor Cyan
Write-Host "1. 🔍 Validate setup: .\Validate-Configuration.ps1" -ForegroundColor Gray
Write-Host "2. 🚀 Run analysis: .\Permission-Toolkit.ps1" -ForegroundColor Gray

if ($enableTooltips) {
    Write-Host "3. 🎨 Enhance reports: .\Permission-Tooltip.ps1" -ForegroundColor Gray
}

Write-Host "`n💡 Configuration Features Enabled:" -ForegroundColor Yellow
if ($dryRun) { Write-Host "   🔒 Dry Run Mode - Safe testing without changes" -ForegroundColor Gray }
if ($enableSsoAnalysis) { Write-Host "   👥 SSO Analysis - External domain detection" -ForegroundColor Gray }
if ($enablePermissionExclusion) { Write-Host "   🚫 Permission Filtering - Noise reduction" -ForegroundColor Gray }
if ($enableTooltips) { Write-Host "   🎨 Interactive Tooltips - Enhanced HTML reports" -ForegroundColor Gray }

Write-Host "`n🏁 Setup complete! Happy permission analyzing! 🎉" -ForegroundColor Cyan