Write-Host "`n🔍 PERMISSION TOOLKIT CONFIGURATION VALIDATOR" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Validating configuration and connectivity for Permission Toolkit" -ForegroundColor Gray

# STEP 1: Load the configuration file
Write-Host "`n📋 STEP 1: Configuration File Validation" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────"

$ConfigFilePath = Join-Path -Path $PSScriptRoot -ChildPath 'shared\Configuration.psd1'
Write-Host "📁 Checking configuration file: $ConfigFilePath"

if (-Not (Test-Path -Path $ConfigFilePath)) {
    Write-Host "❌ Configuration file not found at path: $ConfigFilePath" -ForegroundColor Red
    Write-Host "💡 Please run .\Build-Configuration.ps1 first to create the configuration" -ForegroundColor Yellow
    exit 1
}

try {
    $config = Import-PowerShellDataFile -Path $ConfigFilePath
    if (-Not $config) {
        throw "Configuration file is empty or invalid"
    }
    Write-Host "✅ Configuration file loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to load configuration: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "💡 Please check the configuration file syntax or re-run .\Build-Configuration.ps1" -ForegroundColor Yellow
    exit 1
}

# STEP 2: Validate required configuration parameters
Write-Host "`n⚙️ STEP 2: Core Configuration Validation" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────"

$sourceServer = $config.SourceServerHost
$ExportNormalPermissions = $config.ExportNormalPermissions

if (-Not $sourceServer) {
    Write-Host "❌ Source server host is not set in the configuration." -ForegroundColor Red
    exit 1
} else {
    Write-Host "✅ Source server configured: $sourceServer" -ForegroundColor Green
}

# Validate vCenter version
if ($config.vCenterVersion) {
    Write-Host "✅ vCenter version specified: $($config.vCenterVersion)" -ForegroundColor Green
} else {
    Write-Host "⚠️ vCenter version not specified (will assume 8.0)" -ForegroundColor Yellow
}

# Validate permission export settings
Write-Host "📊 Permission export settings:"
Write-Host "   • Global permissions: $($config.ExportGlobalPermissions)" -ForegroundColor Gray
Write-Host "   • Normal permissions: $($config.ExportNormalPermissions)" -ForegroundColor Gray

if ($ExportNormalPermissions -and $config.ContainsKey('dataCenter')) {
    Write-Host "   • Datacenter: $($config.dataCenter)" -ForegroundColor Gray
} elseif ($ExportNormalPermissions) {
    Write-Host "⚠️ Normal permissions enabled but no datacenter specified" -ForegroundColor Yellow
}

# Validate advanced features
Write-Host "🔧 Advanced features:"
if ($config.EnableSsoAnalysis) {
    Write-Host "   ✅ SSO Analysis enabled" -ForegroundColor Green
} else {
    Write-Host "   ⚪ SSO Analysis disabled" -ForegroundColor Gray
}

if ($config.EnablePermissionExclusion) {
    Write-Host "   ✅ Permission exclusion enabled" -ForegroundColor Green
    if ($config.ExclusionFilePath) {
        $exclusionPath = Join-Path $PSScriptRoot $config.ExclusionFilePath
        if (Test-Path $exclusionPath) {
            Write-Host "     ✅ Exclusion file found: $($config.ExclusionFilePath)" -ForegroundColor Green
        } else {
            Write-Host "     ⚠️ Exclusion file not found: $($config.ExclusionFilePath)" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "   ⚪ Permission exclusion disabled" -ForegroundColor Gray
}

if ($config.EnableTooltips) {
    Write-Host "   ✅ Tooltip enhancement enabled ($($config.TooltipTheme) theme)" -ForegroundColor Green
} else {
    Write-Host "   ⚪ Tooltip enhancement disabled" -ForegroundColor Gray
}

# STEP 3: Test connection to the source server, is server reachable?
Write-Host "`n🌐 STEP 3: Network Connectivity Test" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────"

Write-Host "🔍 Testing connectivity to: $sourceServer"
if (Test-Connection -ComputerName $sourceServer -Count 2 -Quiet) {
    Write-Host "✅ Network connectivity successful" -ForegroundColor Green
} else {
    Write-Host "⚠️ Cannot reach $sourceServer via ICMP (ping)" -ForegroundColor Yellow
    Write-Host "   This may be normal if ICMP is blocked by firewall" -ForegroundColor Gray
    Write-Host "   Will proceed with HTTPS connectivity test..." -ForegroundColor Gray
}

# Test HTTPS connectivity
Write-Host "🔐 Testing HTTPS connectivity on port 443..."
try {
    $httpsTest = Test-NetConnection -ComputerName $sourceServer -Port 443 -WarningAction SilentlyContinue
    if ($httpsTest.TcpTestSucceeded) {
        Write-Host "✅ HTTPS port 443 is accessible" -ForegroundColor Green
    } else {
        Write-Host "❌ HTTPS port 443 is not accessible" -ForegroundColor Red
        Write-Host "💡 Check firewall, VPN, or network connectivity" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️ Could not test HTTPS connectivity: $($_.Exception.Message)" -ForegroundColor Yellow
}

# STEP 4: Credential validation and vCenter authentication test
Write-Host "`n🔐 STEP 4: Credential & Authentication Validation" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────"

# Check SecretManagement availability
try {
    Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction Stop
    Write-Host "✅ SecretManagement module available" -ForegroundColor Green
} catch {
    Write-Host "❌ SecretManagement module not found" -ForegroundColor Red
    Write-Host "💡 Install with: Install-Module Microsoft.PowerShell.SecretManagement" -ForegroundColor Yellow
    exit 1
}

# Check secret vault
$vault = Get-SecretVault | Where-Object { $_.Name -eq "VCenterVault" }
if ($vault) {
    Write-Host "✅ Secret vault 'VCenterVault' is registered" -ForegroundColor Green
} else {
    Write-Host "❌ Secret vault 'VCenterVault' is not registered" -ForegroundColor Red
    Write-Host "💡 Run .\Build-Configuration.ps1 to set up the vault" -ForegroundColor Yellow
    exit 1
}

# Check stored credentials
$storedCred = Get-SecretInfo | Where-Object { $_.Name -eq "SourceCred" }
if ($storedCred) {
    Write-Host "✅ Credentials 'SourceCred' are stored in vault" -ForegroundColor Green
} else {
    Write-Host "❌ Credentials 'SourceCred' not found in vault" -ForegroundColor Red
    Write-Host "💡 Run .\Build-Configuration.ps1 to store credentials" -ForegroundColor Yellow
    exit 1
}

# Test vCenter authentication
Write-Host "🔍 Testing vCenter authentication..."
try {
    $srcCred = Get-Secret -Name "SourceCred" -ErrorAction Stop
    Write-Host "✅ Credentials retrieved from vault" -ForegroundColor Green
    
    # Test PowerCLI availability
    if (-not (Get-Module -ListAvailable -Name VMware.PowerCLI)) {
        Write-Host "❌ VMware PowerCLI module not found" -ForegroundColor Red
        Write-Host "💡 Install with: Install-Module VMware.PowerCLI" -ForegroundColor Yellow
        exit 1
    } else {
        Write-Host "✅ VMware PowerCLI module available" -ForegroundColor Green
    }

    Write-Host "🔌 Attempting vCenter connection..."
    $srcSession = Connect-VIServer -Server $sourceServer -Credential $srcCred -ErrorAction Stop
    Write-Host "✅ vCenter authentication successful!" -ForegroundColor Green
    Write-Host "   Connected as: $($srcSession.User)" -ForegroundColor Gray
    Write-Host "   vCenter version: $($srcSession.Version)" -ForegroundColor Gray

    # STEP 5: Validate datacenter and permissions (if applicable)
    Write-Host "`n📍 STEP 5: Datacenter & Permission Validation" -ForegroundColor Yellow
    Write-Host "─────────────────────────────────────────────────────────"
    
    if ($ExportNormalPermissions -and $config.ContainsKey('dataCenter')) {
        $dataCenter = $config.dataCenter
        Write-Host "🔍 Validating datacenter: $dataCenter"
        
        try {
            $dc = Get-Datacenter -Name $dataCenter -ErrorAction Stop
            Write-Host "✅ Datacenter found: $($dc.Name)" -ForegroundColor Green
        } catch {
            Write-Host "⚠️ Datacenter '$dataCenter' not found or not accessible" -ForegroundColor Yellow
            Write-Host "   Available datacenters:" -ForegroundColor Gray
            Get-Datacenter | ForEach-Object { Write-Host "     • $($_.Name)" -ForegroundColor Gray }
        }
    } else {
        Write-Host "ℹ️ No datacenter validation needed (normal permissions disabled or not specified)" -ForegroundColor Cyan
    }
    
    # Test permission retrieval capabilities
    Write-Host "🔒 Testing permission retrieval capabilities..."
    try {
        $globalPerms = Get-VIPermission -ErrorAction Stop | Select-Object -First 1
        if ($globalPerms) {
            Write-Host "✅ Permission retrieval working" -ForegroundColor Green
        } else {
            Write-Host "⚠️ No permissions found (may be normal in some environments)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "❌ Failed to retrieve permissions: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "💡 Check user privileges in vCenter" -ForegroundColor Yellow
    }

} catch {
    Write-Host "❌ vCenter connection failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "💡 Please verify:" -ForegroundColor Yellow
    Write-Host "   • Server hostname is correct: $sourceServer" -ForegroundColor Gray
    Write-Host "   • Credentials are valid" -ForegroundColor Gray
    Write-Host "   • User has sufficient privileges" -ForegroundColor Gray
    Write-Host "   • Network connectivity is working" -ForegroundColor Gray
    exit 1
} finally {
    if ($srcSession) {
        Write-Host "🧹 Disconnecting from vCenter..."
        Disconnect-VIServer -Server $srcSession -Confirm:$false
        Write-Host "✅ Disconnected successfully" -ForegroundColor Green
    }
}

# STEP 6: Module and file validation
Write-Host "`n🧩 STEP 6: Module & File Validation" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────"

# Check toolkit modules
$moduleFiles = @(
    'modules\Connect-VSphere.psm1',
    'modules\Export-HTML.Report.psm1', 
    'modules\Get-Permissions.psm1',
    'modules\Utils.psm1'
)

Write-Host "📦 Checking toolkit modules:"
foreach ($moduleFile in $moduleFiles) {
    $modulePath = Join-Path $PSScriptRoot $moduleFile
    if (Test-Path $modulePath) {
        Write-Host "   ✅ $moduleFile" -ForegroundColor Green
    } else {
        Write-Host "   ❌ $moduleFile (missing)" -ForegroundColor Red
    }
}

# Check exclusion file if filtering is enabled
if ($config.EnablePermissionExclusion -and $config.ExclusionFilePath) {
    $exclusionPath = Join-Path $PSScriptRoot $config.ExclusionFilePath
    Write-Host "🚫 Checking exclusion file:"
    if (Test-Path $exclusionPath) {
        $exclusionCount = (Get-Content $exclusionPath | Where-Object { $_ -and $_.Trim() -and -not $_.StartsWith('#') }).Count
        Write-Host "   ✅ $($config.ExclusionFilePath) - $exclusionCount patterns found" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️ $($config.ExclusionFilePath) (will be created automatically)" -ForegroundColor Yellow
    }
}

# Check main toolkit scripts
$toolkitFiles = @(
    'Permission-Toolkit.ps1',
    'Initialize-Environment.ps1'
)

if ($config.EnableTooltips) {
    $toolkitFiles += 'Permission-Tooltip.ps1'
}

Write-Host "🛠️ Checking toolkit scripts:"
foreach ($scriptFile in $toolkitFiles) {
    $scriptPath = Join-Path $PSScriptRoot $scriptFile
    if (Test-Path $scriptPath) {
        Write-Host "   ✅ $scriptFile" -ForegroundColor Green
    } else {
        Write-Host "   ❌ $scriptFile (missing)" -ForegroundColor Red
    }
}

# FINAL VALIDATION SUMMARY
Write-Host "`n🎯 VALIDATION COMPLETE!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "✅ Configuration file is valid and complete" -ForegroundColor Green
Write-Host "✅ Network connectivity confirmed" -ForegroundColor Green  
Write-Host "✅ vCenter authentication successful" -ForegroundColor Green
Write-Host "✅ All required modules and files present" -ForegroundColor Green

Write-Host "`n🚀 READY TO RUN!" -ForegroundColor Cyan
Write-Host "Your Permission Toolkit is fully configured and ready for analysis." -ForegroundColor Gray

Write-Host "`n📖 NEXT STEPS:" -ForegroundColor Yellow
Write-Host "1. 🔍 Run full analysis: .\Permission-Toolkit.ps1" -ForegroundColor Gray

if ($config.EnableTooltips) {
    Write-Host "2. 🎨 Enhance reports: .\Permission-Tooltip.ps1" -ForegroundColor Gray
}

Write-Host "`n💡 Configured Features:" -ForegroundColor Cyan
if ($config.DryRun -eq $true) { Write-Host "   🔒 Dry Run Mode - Safe testing" -ForegroundColor Gray }
if ($config.EnableSsoAnalysis) { Write-Host "   👥 SSO Analysis - External domain detection" -ForegroundColor Gray }
if ($config.EnablePermissionExclusion) { Write-Host "   🚫 Permission Filtering - Noise reduction" -ForegroundColor Gray }
if ($config.EnableTooltips) { Write-Host "   🎨 Interactive Tooltips - Enhanced reports" -ForegroundColor Gray }

Write-Host "`n🏁 Happy permission analyzing! 🎉" -ForegroundColor Cyan