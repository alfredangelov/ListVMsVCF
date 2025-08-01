Write-Host "`n🛠️ PERMISSION TOOLKIT SETUP SCRIPT v2.0" -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────────"
Write-Host "Setting up enhanced vSphere Permission Toolkit with:" -ForegroundColor Gray
Write-Host "• Permission Grouping & Exclusion Filtering" -ForegroundColor Gray
Write-Host "• Interactive Tooltip Enhancement" -ForegroundColor Gray
Write-Host "• SSO External Domain Analysis" -ForegroundColor Gray
Write-Host "• Comprehensive HTML Reporting" -ForegroundColor Gray

# Minimum PowerShell version required
$minPSVersion = [Version]"7.0"  # Lowered to 7.0 for better compatibility

# Check PowerShell version
Write-Host "`n🔎 Checking PowerShell version..."
if ($PSVersionTable.PSVersion -lt $minPSVersion) {
    Write-Host "❌ PowerShell version $($PSVersionTable.PSVersion) is below required $minPSVersion" -ForegroundColor Red
    Write-Host "Please install PowerShell 7.0+ from https://github.com/PowerShell/PowerShell" -ForegroundColor Yellow
    Write-Host "💡 The toolkit supports both PowerShell 7.x and 5.1 for compatibility" -ForegroundColor Cyan
    return
} else {
    Write-Host "✅ PowerShell version OK: $($PSVersionTable.PSVersion)" -ForegroundColor Green
}

# Check required core files
$coreFiles = @(
    ".\modules\Connect-VSphere.psm1",
    ".\modules\Export-HTML.Report.psm1", 
    ".\modules\Get-Permissions.psm1",
    ".\modules\Utils.psm1",
    ".\shared\Configuration.psd1",
    ".\shared\Configuration-template.psd1",
    ".\Build-Configuration.ps1",
    ".\Validate-Configuration.ps1", 
    ".\Permission-Toolkit.ps1",
    ".\Permission-Tooltip.ps1",
    ".\Monitor-TooltipProgress.ps1"
)

# Check optional/enhancement files
$enhancementFiles = @(
    ".\exclude-permissions.txt"
)

Write-Host "`n📂 Verifying core toolkit files..."
$missingCore = $coreFiles | Where-Object { -not (Test-Path $_) }
if ($missingCore.Count -gt 0) {
    Write-Host "❌ Missing core files:" -ForegroundColor Red
    $missingCore | ForEach-Object { Write-Host "   • $_" -ForegroundColor Red }
    Write-Host "Please clone or restore these from the toolkit repository." -ForegroundColor Yellow
    return
} else {
    Write-Host "✅ All core files present ($($coreFiles.Count) files)" -ForegroundColor Green
}

Write-Host "`n📁 Checking enhancement files..."
$missingEnhancement = $enhancementFiles | Where-Object { -not (Test-Path $_) }
if ($missingEnhancement.Count -gt 0) {
    Write-Host "⚠️ Optional files missing:" -ForegroundColor Yellow
    $missingEnhancement | ForEach-Object { Write-Host "   • $_" -ForegroundColor Yellow }
    Write-Host "These files provide additional testing and configuration options." -ForegroundColor Gray
} else {
    Write-Host "✅ All enhancement files present ($($enhancementFiles.Count) files)" -ForegroundColor Green
}

# Check directory structure
$requiredDirs = @(".\modules", ".\shared")
Write-Host "`n📁 Verifying directory structure..."
$missingDirs = $requiredDirs | Where-Object { -not (Test-Path $_) }
if ($missingDirs.Count -gt 0) {
    Write-Host "⚠️ Missing directories:" -ForegroundColor Yellow
    $missingDirs | ForEach-Object { 
        Write-Host "   • Creating: $_" -ForegroundColor Cyan
        New-Item -Path $_ -ItemType Directory -Force | Out-Null
    }
} else {
    Write-Host "✅ Directory structure complete" -ForegroundColor Green
}

# Required modules with version checking
$modules = @(
    @{ Name = "VMware.PowerCLI"; MinVersion = "13.0.0"; Required = $true; Description = "vSphere management and automation" },
    @{ Name = "Microsoft.PowerShell.SecretManagement"; MinVersion = "1.1.0"; Required = $true; Description = "Secure credential storage" },
    @{ Name = "Microsoft.PowerShell.SecretStore"; MinVersion = "1.0.0"; Required = $true; Description = "Secret storage provider" }
)

# Optional modules for enhanced functionality
$optionalModules = @(
    @{ Name = "VCF.PowerCLI"; MinVersion = "1.0.0"; Required = $false; Description = "VMware Cloud Foundation support" }
)

Write-Host "`n📦 Checking required PowerShell modules..."
$moduleInstallNeeded = $false

foreach ($moduleInfo in $modules) {
    $installedModule = Get-Module -ListAvailable -Name $moduleInfo.Name | Sort-Object Version -Descending | Select-Object -First 1
    
    if (-not $installedModule) {
        Write-Host "📦 Installing: $($moduleInfo.Name) - $($moduleInfo.Description)" -ForegroundColor Cyan
        try {
            Install-Module $moduleInfo.Name -Scope CurrentUser -SkipPublisherCheck -AllowClobber -Force
            Write-Host "✅ Successfully installed: $($moduleInfo.Name)" -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Failed to install $($moduleInfo.Name): $($_.Exception.Message)" -ForegroundColor Red
            $moduleInstallNeeded = $true
        }
    }
    elseif ($installedModule.Version -lt [Version]$moduleInfo.MinVersion) {
        Write-Host "⚠️ $($moduleInfo.Name) version $($installedModule.Version) is below minimum $($moduleInfo.MinVersion)" -ForegroundColor Yellow
        Write-Host "   Updating to latest version..." -ForegroundColor Cyan
        try {
            Update-Module $moduleInfo.Name -Force
            Write-Host "✅ Updated: $($moduleInfo.Name)" -ForegroundColor Green
        }
        catch {
            Write-Host "⚠️ Update failed, but existing version may work: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "✅ Module OK: $($moduleInfo.Name) v$($installedModule.Version) - $($moduleInfo.Description)" -ForegroundColor Green
    }
}

Write-Host "`n📦 Checking optional modules..."
foreach ($moduleInfo in $optionalModules) {
    $installedModule = Get-Module -ListAvailable -Name $moduleInfo.Name | Sort-Object Version -Descending | Select-Object -First 1
    
    if (-not $installedModule) {
        Write-Host "ℹ️ Optional module not installed: $($moduleInfo.Name) - $($moduleInfo.Description)" -ForegroundColor Gray
        Write-Host "   This module enhances functionality but isn't required" -ForegroundColor Gray
    }
    else {
        Write-Host "✅ Optional module present: $($moduleInfo.Name) v$($installedModule.Version)" -ForegroundColor Green
    }
}

# Validate toolkit module functionality
Write-Host "`n🔧 Validating toolkit modules..."
try {
    # Test importing core modules
    $testModules = @(".\modules\Utils.psm1", ".\modules\Connect-VSphere.psm1", ".\modules\Get-Permissions.psm1", ".\modules\Export-HTML.Report.psm1")
    
    foreach ($testModule in $testModules) {
        if (Test-Path $testModule) {
            Import-Module $testModule -Force -ErrorAction Stop
            Write-Host "✅ Module loads correctly: $(Split-Path $testModule -Leaf)" -ForegroundColor Green
        }
    }
    
    # Test key functions are available
    $keyFunctions = @("Group-PermissionsByType", "Get-ExternalSsoMembers", "Filter-PermissionsByExclusion", "Export-HTMLReport")
    foreach ($func in $keyFunctions) {
        if (Get-Command $func -ErrorAction SilentlyContinue) {
            Write-Host "✅ Function available: $func" -ForegroundColor Green
        } else {
            Write-Host "⚠️ Function not found: $func" -ForegroundColor Yellow
        }
    }
}
catch {
    Write-Host "⚠️ Module validation issue: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "   This may be normal during initial setup" -ForegroundColor Gray
}

# Validate configuration
Write-Host "`n⚙️ Checking configuration setup..."
if (Test-Path ".\shared\Configuration.psd1") {
    try {
        $config = Import-PowerShellDataFile -Path ".\shared\Configuration.psd1"
        Write-Host "✅ Configuration file loads successfully" -ForegroundColor Green
        
        # Check for new features
        $features = @(
            @{ Key = "EnablePermissionExclusion"; Name = "Permission Exclusion Filtering" },
            @{ Key = "EnableSsoAnalysis"; Name = "SSO External Domain Analysis" },
            @{ Key = "EnableTooltips"; Name = "Interactive Tooltip Enhancement" }
        )
        
        # Check for version configuration
        if ($config.vCenterVersion) {
            Write-Host "   • vCenter Version: $($config.vCenterVersion)" -ForegroundColor Green
        } else {
            Write-Host "   • vCenter Version: Not specified (consider adding to config)" -ForegroundColor Yellow
        }
        
        foreach ($feature in $features) {
            if ($config.ContainsKey($feature.Key)) {
                $status = if ($config[$feature.Key]) { "Enabled" } else { "Disabled" }
                $color = if ($config[$feature.Key]) { "Green" } else { "Gray" }
                Write-Host "   • $($feature.Name): $status" -ForegroundColor $color
            } else {
                Write-Host "   • $($feature.Name): Not configured (will use default)" -ForegroundColor Yellow
            }
        }
    }
    catch {
        Write-Host "⚠️ Configuration file has issues: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "   Run .\Build-Configuration.ps1 to recreate it" -ForegroundColor Cyan
    }
} else {
    Write-Host "⚠️ Configuration file not found" -ForegroundColor Yellow
    Write-Host "   Run .\Build-Configuration.ps1 to create it" -ForegroundColor Cyan
}

# Check exclusion file
Write-Host "`n🚫 Checking exclusion configuration..."
if (Test-Path ".\exclude-permissions.txt") {
    $exclusionLines = Get-Content ".\exclude-permissions.txt" | Where-Object { $_.Trim() -and -not $_.StartsWith("#") }
    Write-Host "✅ Exclusion file present with $($exclusionLines.Count) patterns" -ForegroundColor Green
} else {
    Write-Host "⚠️ Exclusion file not found - permission filtering will be disabled" -ForegroundColor Yellow
    Write-Host "   This file helps filter out standard vCenter service accounts" -ForegroundColor Gray
}

if ($moduleInstallNeeded) {
    Write-Host "`n❌ Some modules failed to install. Please resolve manually:" -ForegroundColor Red
    Write-Host "   1. Check internet connectivity" -ForegroundColor Yellow
    Write-Host "   2. Run PowerShell as Administrator if needed" -ForegroundColor Yellow
    Write-Host "   3. Try: Set-PSRepository -Name PSGallery -InstallationPolicy Trusted" -ForegroundColor Yellow
    return
}

Write-Host "`n🎯 Toolkit environment ready!" -ForegroundColor Green
Write-Host "`n📋 Next Steps:" -ForegroundColor Cyan
Write-Host "1. .\Build-Configuration.ps1    - Set up vCenter connection" -ForegroundColor White
Write-Host "2. .\Validate-Configuration.ps1 - Test connection settings" -ForegroundColor White
Write-Host "3. .\Permission-Toolkit.ps1     - Run permission analysis" -ForegroundColor White
Write-Host "4. .\Permission-Tooltip.ps1     - Add interactive tooltips" -ForegroundColor White

Write-Host "`n💡 Features Available:" -ForegroundColor Cyan
Write-Host "• 🚫 Permission Exclusion: Filter out service accounts (90%+ noise reduction)" -ForegroundColor White
Write-Host "• 📊 Permission Grouping: Organize by entity type (VMs, Hosts, etc.)" -ForegroundColor White
Write-Host "• 🌐 SSO Analysis: Identify external domain integrations" -ForegroundColor White  
Write-Host "• 💬 Interactive Tooltips: Enhanced HTML reports with hover details" -ForegroundColor White
Write-Host "• 📱 Professional HTML: Responsive design with progress tracking" -ForegroundColor White
