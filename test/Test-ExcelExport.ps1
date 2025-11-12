#Requires -Version 5.1

<#
.SYNOPSIS
    Tests Excel export functionality using VirtToolkit modules.

.DESCRIPTION
    This test script validates Excel export with four test cases:
    
    TEST 1: Basic Excel Export (3 properties)
    - Tests basic Excel export functionality
    - Exports 10 VMs with Name, UUID, PowerState
    - Validates Excel file creation and formatting
    
    TEST 2: All Properties Export
    - Tests retrieval of ALL properties defined in Configuration.psd1
    - Exports 10 VMs with all configured VMProperties
    - Validates that all property retrievals work correctly
    
    TEST 3: Filtering Validation
    - Tests all filter configurations from Configuration.psd1
    - Applies PowerState filters and ExcludeNames patterns
    - Exports filtered VMs with Name, UUID, PowerState
    - Validates filter logic works as expected
    
    TEST 4: Full Production Workflow (Mini Scale)
    - Retrieves VMs from specified folder in Configuration.psd1
    - Applies ALL filters (PowerState, ExcludeNames)
    - Retrieves ALL properties from VMProperties
    - Simulates complete production workflow at smaller scale

.PARAMETER BasicExcelExport
    Run only Test Case 1: Basic Excel Export

.PARAMETER AllProperties
    Run only Test Case 2: All Properties Export

.PARAMETER FilteringValidation
    Run only Test Case 3: Filtering Validation

.PARAMETER FullWorkflow
    Run only Test Case 4: Full Production Workflow

.PARAMETER FilteringValidation
    Run only Test Case 3: Filtering Validation

.PARAMETER All
    Run all test cases (default if no switches specified)

.EXAMPLE
    .\Test-ExcelExport.ps1
    Runs all three test cases

.EXAMPLE
    .\Test-ExcelExport.ps1 -BasicExcelExport
    Runs only Test Case 1 (Basic Excel Export)

.EXAMPLE
    .\Test-ExcelExport.ps1 -FilteringValidation
    Runs only Test Case 3 (Filtering Validation)

.EXAMPLE
    .\Test-ExcelExport.ps1 -AllProperties -FilteringValidation
    Runs Test Case 2 and Test Case 3

.EXAMPLE
    .\Test-ExcelExport.ps1 -FullWorkflow
    Runs only Test Case 4 (Full Production Workflow)

.NOTES
    Part of VirtToolkit: Enterprise Virtualization Management Platform
    Comprehensive test script for Excel export and VM data retrieval
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$BasicExcelExport,
    
    [Parameter(Mandatory = $false)]
    [switch]$AllProperties,
    
    [Parameter(Mandatory = $false)]
    [switch]$FilteringValidation,
    
    [Parameter(Mandatory = $false)]
    [switch]$FullWorkflow,
    
    [Parameter(Mandatory = $false)]
    [switch]$All
)

# Script setup
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ToolkitRoot = Split-Path -Parent $ScriptRoot

# Determine which tests to run
if (-not $BasicExcelExport -and -not $AllProperties -and -not $FilteringValidation -and -not $FullWorkflow -and -not $All) {
    # No switches specified, run all tests
    $RunTest1 = $true
    $RunTest2 = $true
    $RunTest3 = $true
    $RunTest4 = $true
}
elseif ($All) {
    # -All switch specified
    $RunTest1 = $true
    $RunTest2 = $true
    $RunTest3 = $true
    $RunTest4 = $true
}
else {
    # Specific tests selected
    $RunTest1 = $BasicExcelExport.IsPresent
    $RunTest2 = $AllProperties.IsPresent
    $RunTest3 = $FilteringValidation.IsPresent
    $RunTest4 = $FullWorkflow.IsPresent
}

# Initialize log file
$LogsDir = Join-Path $ToolkitRoot 'logs'
if (-not (Test-Path $LogsDir)) {
    New-Item -Path $LogsDir -ItemType Directory -Force | Out-Null
}
$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$LogFile = Join-Path $LogsDir "Test-ExcelExport_$Timestamp.log"

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                      VirtToolkit Excel Export Test                            " -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Display test selection
Write-Host "Test Selection:" -ForegroundColor Yellow
$status1 = if ($RunTest1) { "ENABLED" } else { "SKIPPED" }
$color1 = if ($RunTest1) { "Green" } else { "Gray" }
Write-Host "  Test 1 (Basic Export): " -NoNewline -ForegroundColor White
Write-Host $status1 -ForegroundColor $color1

$status2 = if ($RunTest2) { "ENABLED" } else { "SKIPPED" }
$color2 = if ($RunTest2) { "Green" } else { "Gray" }
Write-Host "  Test 2 (All Properties): " -NoNewline -ForegroundColor White
Write-Host $status2 -ForegroundColor $color2

$status3 = if ($RunTest3) { "ENABLED" } else { "SKIPPED" }
$color3 = if ($RunTest3) { "Green" } else { "Gray" }
Write-Host "  Test 3 (Filtering): " -NoNewline -ForegroundColor White
Write-Host $status3 -ForegroundColor $color3

$status4 = if ($RunTest4) { "ENABLED" } else { "SKIPPED" }
$color4 = if ($RunTest4) { "Green" } else { "Gray" }
Write-Host "  Test 4 (Full Workflow): " -NoNewline -ForegroundColor White
Write-Host $status4 -ForegroundColor $color4
Write-Host ""

Write-VirtToolkitLog -Message "Test execution started - Test1: $RunTest1, Test2: $RunTest2, Test3: $RunTest3, Test4: $RunTest4" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-ExcelExport"

# Import modules
try {
    Write-Host "Loading VirtToolkit modules..." -ForegroundColor Yellow
    Import-Module (Join-Path $ToolkitRoot 'modules\VirtToolkit.Logging.psm1') -Force -ErrorAction Stop
    Import-Module (Join-Path $ToolkitRoot 'modules\VirtToolkit.Credentials.psm1') -Force -ErrorAction Stop
    Import-Module (Join-Path $ToolkitRoot 'modules\VirtToolkit.Excel.psm1') -Force -ErrorAction Stop
    Write-Host "Modules loaded successfully" -ForegroundColor Green
    Write-VirtToolkitLog -Message "VirtToolkit modules loaded successfully" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "Test-ExcelExport"
    Write-Host ""
}
catch {
    Write-Host "Failed to load modules: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Load configuration
$ConfigPath = Join-Path $ToolkitRoot 'shared\config\Configuration.psd1'
Write-Host "Loading configuration from: $ConfigPath" -ForegroundColor Yellow
Write-VirtToolkitLog -Message "Loading configuration from: $ConfigPath" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-ExcelExport"
try {
    $Config = Import-PowerShellDataFile -Path $ConfigPath -ErrorAction Stop
    Write-Host "Configuration loaded" -ForegroundColor Green
    Write-VirtToolkitLog -Message "Configuration loaded successfully" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "Test-ExcelExport"
    Write-Host ""
}
catch {
    Write-Host "Failed to load configuration: $($_.Exception.Message)" -ForegroundColor Red
    Write-VirtToolkitLog -Message "Failed to load configuration: $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile -ModuleName "Test-ExcelExport"
    exit 1
}

# Extract settings
$vCenterServer = $Config.SourceServerHost
$VaultName = $Config.preferredVault
$PreferredUsername = $Config.PreferredUsername
$OutputPath = if ($Config.OutputPath) { Join-Path $ToolkitRoot $Config.OutputPath } else { Join-Path $ToolkitRoot 'output' }

# Ensure output directory exists
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
}

Write-Host "Configuration Details:" -ForegroundColor Cyan
Write-Host "  vCenter Server: $vCenterServer" -ForegroundColor White
Write-Host "  Vault: $VaultName" -ForegroundColor White
Write-Host "  Preferred Username: $PreferredUsername" -ForegroundColor White
Write-Host "  Output Path: $OutputPath" -ForegroundColor White
Write-Host ""

# Import VMware PowerCLI
try {
    Write-Host "Loading VMware PowerCLI..." -ForegroundColor Yellow
    Import-Module VMware.VimAutomation.Core -ErrorAction Stop
    Write-Host "PowerCLI loaded" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "Failed to load PowerCLI: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Run Initialize-Environment.ps1 to install required modules" -ForegroundColor Yellow
    exit 1
}

# Configure PowerCLI settings
if ($Config.IgnoreSSLCertificates) {
    Write-Host "Configuring PowerCLI to ignore SSL certificates..." -ForegroundColor Yellow
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
    Write-Host "SSL certificate validation disabled" -ForegroundColor Green
    Write-Host ""
}

# Retrieve credentials
Write-Host "───────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "Retrieving credentials for $vCenterServer..." -ForegroundColor Yellow
try {
    $Credential = Get-VirtToolkitCredential -Server $vCenterServer -PreferredUsername $PreferredUsername -VaultName $VaultName
    
    if ($Credential) {
        Write-Host "Credential retrieved: $($Credential.UserName)" -ForegroundColor Green
    }
    else {
        Write-Host "Failed to retrieve credential" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "Credential retrieval failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Connect to vCenter
Write-Host "───────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "Connecting to vCenter: $vCenterServer" -ForegroundColor Yellow
try {
    $Connection = Connect-VIServer -Server $vCenterServer -Credential $Credential -ErrorAction Stop
    Write-Host "Successfully connected to vCenter" -ForegroundColor Green
    Write-Host "  Server: $($Connection.Name)" -ForegroundColor White
    Write-Host "  User: $($Connection.User)" -ForegroundColor White
}
catch {
    Write-Host "Connection failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Retrieve VM data
Write-Host "───────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "Retrieving VM data for testing..." -ForegroundColor Yellow
Write-VirtToolkitLog -Message "Retrieving VM data for test cases" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-ExcelExport"
try {
    # Get base VM list (limited to 50 VMs for testing)
    $AllVMs = Get-VM -ErrorAction Stop | Select-Object -First 50
    
    Write-Host "Retrieved base VM data" -ForegroundColor Green
    Write-Host "  Total VMs available for testing: $($AllVMs.Count)" -ForegroundColor White
    Write-VirtToolkitLog -Message "Retrieved $($AllVMs.Count) VMs for testing" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "Test-ExcelExport"
}
catch {
    Write-Host "Failed to retrieve VM data: $($_.Exception.Message)" -ForegroundColor Red
    Write-VirtToolkitLog -Message "Failed to retrieve VM data: $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile -ModuleName "Test-ExcelExport"
    Disconnect-VIServer -Server $Connection -Confirm:$false -ErrorAction SilentlyContinue
    exit 1
}
Write-Host ""

# Note: Connection remains open for all test cases
Write-VirtToolkitLog -Message "Connection remains active for test execution" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-ExcelExport"

#region Test Case 1: Basic Excel Export (3 Properties)
if ($RunTest1) {
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "                    TEST CASE 1: Basic Excel Export                            " -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Test Description:" -ForegroundColor Yellow
    Write-Host "  - Export 10 VMs with basic properties (Name, UUID, PowerState)" -ForegroundColor White
    Write-Host "  - Validate Excel module functionality" -ForegroundColor White
    Write-Host "  - Test metadata sheet generation" -ForegroundColor White
    Write-Host ""

    Write-VirtToolkitLog -Message "TEST 1: Starting basic Excel export test" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-ExcelExport"

    $Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $ExcelFile1 = Join-Path $OutputPath "Test1-Basic-Export_$Timestamp.xlsx"

    try {
        # Prepare test data - basic 3 properties
        $TestData1 = $AllVMs | Select-Object -First 10 | Select-Object Name,
        @{N = 'UUID'; E = { $_.ExtensionData.Config.Uuid } },
        PowerState
    
        Write-Host "Exporting to Excel..." -ForegroundColor Yellow
        Write-Host "  VMs to export: $($TestData1.Count)" -ForegroundColor White
        Write-Host "  Properties: Name, UUID, PowerState" -ForegroundColor White
        Write-Host "  File: $(Split-Path $ExcelFile1 -Leaf)" -ForegroundColor White
        Write-Host ""
    
        $ExportParams = @{
            Data                  = $TestData1
            FilePath              = $ExcelFile1
            WorksheetName         = "Basic VM Data"
            Title                 = "Test 1: Basic Excel Export"
            Properties            = @('Name', 'UUID', 'PowerState')
            ModuleName            = "Test-ExcelExport"
            Server                = $vCenterServer
            IncludeMetadataSheet  = $true
            AutoSize              = $true
            FreezeHeaders         = $true
            UseAdvancedFormatting = $true
        }
    
        $Result1 = Export-VirtToolkitExcel @ExportParams
    
        if ($Result1 -and $Result1.Success) {
            Write-Host "TEST 1: PASSED" -ForegroundColor Green
            Write-VirtToolkitLog -Message "TEST 1: Basic export completed successfully" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "Test-ExcelExport"
            Write-Host "  File: $($Result1.FilePath)" -ForegroundColor White
            Write-Host "  Rows: $($Result1.RecordCount)" -ForegroundColor White
        
            if (Test-Path $ExcelFile1) {
                $FileInfo = Get-Item $ExcelFile1
                Write-Host "  Size: $([math]::Round($FileInfo.Length / 1KB, 2)) KB" -ForegroundColor White
            }
        }
        else {
            $ErrorMsg = if ($Result1 -and $Result1.Message) { $Result1.Message } else { "Unknown error" }
            Write-Host "TEST 1: FAILED - $ErrorMsg" -ForegroundColor Red
            Write-VirtToolkitLog -Message "TEST 1: Failed - $ErrorMsg" -Level 'ERROR' -LogFile $LogFile -ModuleName "Test-ExcelExport"
        }
    }
    catch {
        Write-Host "TEST 1: EXCEPTION - $($_.Exception.Message)" -ForegroundColor Red
        Write-VirtToolkitLog -Message "TEST 1: Exception - $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile -ModuleName "Test-ExcelExport"
    }
    Write-Host ""
}
else {
    Write-VirtToolkitLog -Message "TEST 1: Skipped (not selected)" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-ExcelExport"
}
#endregion

#region Test Case 2: All Properties Export
if ($RunTest2) {
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "                 TEST CASE 2: All Properties Export                            " -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Test Description:" -ForegroundColor Yellow
    Write-Host "  - Export 10 VMs with ALL properties from Configuration.psd1" -ForegroundColor White
    Write-Host "  - Validate property retrieval logic" -ForegroundColor White
    Write-Host "  - Test complex property calculations" -ForegroundColor White
    Write-Host ""

    Write-VirtToolkitLog -Message "TEST 2: Starting all properties export test" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-ExcelExport"

    $Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $ExcelFile2 = Join-Path $OutputPath "Test2-AllProperties-Export_$Timestamp.xlsx"

    try {
        # Get VM properties from configuration
        $VMProperties = $Config.VMProperties
    
        Write-Host "Configured properties ($($VMProperties.Count)):" -ForegroundColor Cyan
        $VMProperties.Keys | ForEach-Object { Write-Host "  - $_ ($($VMProperties[$_]))" -ForegroundColor Gray }
        Write-Host ""
    
        Write-Host "Retrieving VMs with all properties..." -ForegroundColor Yellow
    
        # Build Select-Object with all properties from configuration
        $SelectProperties = @(
            'Name'
            @{N = 'UUID'; E = { $_.ExtensionData.Config.Uuid } }
            @{N = 'DNSName'; E = { $_.Guest.HostName } }
            'PowerState'
            @{N = 'GuestOS'; E = { $_.Guest.OSFullName } }
            @{N = 'NumCPU'; E = { $_.NumCpu } }
            @{N = 'MemoryMB'; E = { $_.MemoryMB } }
            @{N = 'ProvisionedSpaceGB'; E = { [math]::Round($_.ProvisionedSpaceGB, 2) } }
            @{N = 'UsedSpaceGB'; E = { [math]::Round($_.UsedSpaceGB, 2) } }
            @{N = 'Datastore'; E = { ($_.DatastoreIdList | ForEach-Object { (Get-Datastore -Id $_).Name }) -join ', ' } }
            @{N = 'NetworkAdapters'; E = { ($_.NetworkAdapters | ForEach-Object { $_.NetworkName }) -join ', ' } }
            @{N = 'IPAddresses'; E = { ($_.Guest.IPAddress | Where-Object { $_ -notmatch ':' }) -join ', ' } }
            @{N = 'Annotation'; E = { $_.Notes } }
            @{N = 'HostSystem'; E = { $_.VMHost.Name } }
            @{N = 'VMToolsVersion'; E = { $_.Guest.ToolsVersion } }
            @{N = 'VMToolsStatus'; E = { $_.Guest.ToolsStatus } }
            @{N = 'Folder'; E = { $_.Folder.Name } }
        )
    
        $TestData2 = $AllVMs | Select-Object -First 10 | Select-Object $SelectProperties
    
        Write-Host "VMs processed: $($TestData2.Count)" -ForegroundColor Green
        Write-Host ""
    
        # Display sample record
        Write-Host "Sample VM data:" -ForegroundColor Cyan
        $SampleVM = $TestData2 | Select-Object -First 1
        Write-Host "  Name: $($SampleVM.Name)" -ForegroundColor White
        Write-Host "  UUID: $($SampleVM.UUID)" -ForegroundColor White
        Write-Host "  DNS Name: $($SampleVM.DNSName)" -ForegroundColor White
        Write-Host "  Guest OS: $($SampleVM.GuestOS)" -ForegroundColor White
        Write-Host "  CPU: $($SampleVM.NumCPU)" -ForegroundColor White
        Write-Host "  Memory MB: $($SampleVM.MemoryMB)" -ForegroundColor White
        Write-Host "  Datastore: $($SampleVM.Datastore)" -ForegroundColor White
        Write-Host "  Network: $($SampleVM.NetworkAdapters)" -ForegroundColor White
        Write-Host ""
    
        Write-Host "Exporting to Excel..." -ForegroundColor Yellow
    
        $ExportParams = @{
            Data                  = $TestData2
            FilePath              = $ExcelFile2
            WorksheetName         = "All Properties"
            Title                 = "Test 2: All VM Properties Export"
            ModuleName            = "Test-ExcelExport"
            Server                = $vCenterServer
            IncludeMetadataSheet  = $true
            AutoSize              = $true
            FreezeHeaders         = $true
            UseAdvancedFormatting = $true
        }
    
        $Result2 = Export-VirtToolkitExcel @ExportParams
    
        if ($Result2 -and $Result2.Success) {
            Write-Host "TEST 2: PASSED" -ForegroundColor Green
            Write-VirtToolkitLog -Message "TEST 2: All properties export completed successfully" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "Test-ExcelExport"
            Write-Host "  File: $($Result2.FilePath)" -ForegroundColor White
            Write-Host "  Rows: $($Result2.RecordCount)" -ForegroundColor White
            Write-Host "  Properties: $($VMProperties.Count)" -ForegroundColor White
        
            if (Test-Path $ExcelFile2) {
                $FileInfo = Get-Item $ExcelFile2
                Write-Host "  Size: $([math]::Round($FileInfo.Length / 1KB, 2)) KB" -ForegroundColor White
            }
        }
        else {
            $ErrorMsg = if ($Result2 -and $Result2.Message) { $Result2.Message } else { "Unknown error" }
            Write-Host "TEST 2: FAILED - $ErrorMsg" -ForegroundColor Red
            Write-VirtToolkitLog -Message "TEST 2: Failed - $ErrorMsg" -Level 'ERROR' -LogFile $LogFile -ModuleName "Test-ExcelExport"
        }
    }
    catch {
        Write-Host "TEST 2: EXCEPTION - $($_.Exception.Message)" -ForegroundColor Red
        Write-VirtToolkitLog -Message "TEST 2: Exception - $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile -ModuleName "Test-ExcelExport"
    }
    Write-Host ""
}
else {
    Write-VirtToolkitLog -Message "TEST 2: Skipped (not selected)" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-ExcelExport"
}
#endregion

#region Test Case 3: Filtering Validation
if ($RunTest3) {
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "                  TEST CASE 3: Filtering Validation                            " -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Test Description:" -ForegroundColor Yellow
    Write-Host "  - Apply all filters from Configuration.psd1" -ForegroundColor White
    Write-Host "  - Validate PowerState filtering" -ForegroundColor White
    Write-Host "  - Validate ExcludeNames pattern matching" -ForegroundColor White
    Write-Host ""

    Write-VirtToolkitLog -Message "TEST 3: Starting filter validation test" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-ExcelExport"

    $Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $ExcelFile3 = Join-Path $OutputPath "Test3-Filtered-Export_$Timestamp.xlsx"

    try {
        # Get filter configuration
        $PowerStateFilters = $Config.Filters.PowerStates
        $ExcludeNamePatterns = $Config.Filters.ExcludeNames
    
        Write-Host "Filter Configuration:" -ForegroundColor Cyan
        Write-Host "  PowerStates: $($PowerStateFilters -join ', ')" -ForegroundColor White
        Write-Host "  ExcludeNames: $($ExcludeNamePatterns -join ', ')" -ForegroundColor White
        Write-Host ""
    
        Write-Host "Applying filters..." -ForegroundColor Yellow
    
        # Start with all VMs
        $FilteredVMs = $AllVMs
    
        # Apply PowerState filter
        if ($PowerStateFilters -and $PowerStateFilters.Count -gt 0) {
            $BeforeCount = $FilteredVMs.Count
            $FilteredVMs = $FilteredVMs | Where-Object { $_.PowerState -in $PowerStateFilters }
            Write-Host "  PowerState filter applied: $BeforeCount → $($FilteredVMs.Count) VMs" -ForegroundColor Gray
        }
    
        # Apply ExcludeNames filter
        if ($ExcludeNamePatterns -and $ExcludeNamePatterns.Count -gt 0) {
            $BeforeCount = $FilteredVMs.Count
            foreach ($pattern in $ExcludeNamePatterns) {
                $cleanPattern = $pattern.TrimStart('!')
                $FilteredVMs = $FilteredVMs | Where-Object { $_.Name -notlike $cleanPattern }
            }
            Write-Host "  ExcludeNames filter applied: $BeforeCount → $($FilteredVMs.Count) VMs" -ForegroundColor Gray
        }
    
        Write-Host ""
        Write-Host "Filter Results:" -ForegroundColor Green
        Write-Host "  VMs before filtering: $($AllVMs.Count)" -ForegroundColor White
        Write-Host "  VMs after filtering: $($FilteredVMs.Count)" -ForegroundColor White
        Write-Host "  VMs filtered out: $($AllVMs.Count - $FilteredVMs.Count)" -ForegroundColor White
        Write-Host ""
    
        # Take first 10 for export
        $TestData3 = $FilteredVMs | Select-Object -First 10 | Select-Object Name,
        @{N = 'UUID'; E = { $_.ExtensionData.Config.Uuid } },
        PowerState
    
        # Show sample of filtered data
        Write-Host "Sample filtered VMs:" -ForegroundColor Cyan
        $TestData3 | Select-Object -First 5 | ForEach-Object {
            Write-Host "  - $($_.Name) | State: $($_.PowerState)" -ForegroundColor White
        }
        Write-Host ""
    
        Write-Host "Exporting filtered data to Excel..." -ForegroundColor Yellow
    
        $ExportParams = @{
            Data                  = $TestData3
            FilePath              = $ExcelFile3
            WorksheetName         = "Filtered VMs"
            Title                 = "Test 3: Filtered VM Export"
            Properties            = @('Name', 'UUID', 'PowerState')
            ModuleName            = "Test-ExcelExport"
            Server                = $vCenterServer
            AdditionalMetadata    = @{
                'PowerState Filters'    = ($PowerStateFilters -join ', ')
                'Exclude Name Patterns' = ($ExcludeNamePatterns -join ', ')
                'VMs Before Filtering'  = $AllVMs.Count
                'VMs After Filtering'   = $FilteredVMs.Count
                'VMs Filtered Out'      = ($AllVMs.Count - $FilteredVMs.Count)
            }
            IncludeMetadataSheet  = $true
            AutoSize              = $true
            FreezeHeaders         = $true
            UseAdvancedFormatting = $true
        }
    
        $Result3 = Export-VirtToolkitExcel @ExportParams
    
        if ($Result3 -and $Result3.Success) {
            Write-Host "TEST 3: PASSED" -ForegroundColor Green
            Write-VirtToolkitLog -Message "TEST 3: Filter validation completed successfully" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "Test-ExcelExport"
            Write-Host "  File: $($Result3.FilePath)" -ForegroundColor White
            Write-Host "  Rows: $($Result3.RecordCount)" -ForegroundColor White
            Write-Host "  Filters Applied: PowerState, ExcludeNames" -ForegroundColor White
        
            if (Test-Path $ExcelFile3) {
                $FileInfo = Get-Item $ExcelFile3
                Write-Host "  Size: $([math]::Round($FileInfo.Length / 1KB, 2)) KB" -ForegroundColor White
            }
        }
        else {
            $ErrorMsg = if ($Result3 -and $Result3.Message) { $Result3.Message } else { "Unknown error" }
            Write-Host "TEST 3: FAILED - $ErrorMsg" -ForegroundColor Red
            Write-VirtToolkitLog -Message "TEST 3: Failed - $ErrorMsg" -Level 'ERROR' -LogFile $LogFile -ModuleName "Test-ExcelExport"
        }
    }
    catch {
        Write-Host "TEST 3: EXCEPTION - $($_.Exception.Message)" -ForegroundColor Red
        Write-VirtToolkitLog -Message "TEST 3: Exception - $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile -ModuleName "Test-ExcelExport"
    }
    Write-Host ""
}
else {
    Write-VirtToolkitLog -Message "TEST 3: Skipped (not selected)" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-ExcelExport"
}
#endregion

#region Test Case 4: Full Production Workflow
if ($RunTest4) {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "                  TEST CASE 4: Full Production Workflow                        " -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-VirtToolkitLog -Message "TEST 4: Starting Full Production Workflow test" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-ExcelExport"
    
    try {
        # Get VMFolder from configuration
        $VMFolder = $Config.VMFolder
        Write-Host "VM Folder: $VMFolder" -ForegroundColor Yellow
        Write-VirtToolkitLog -Message "TEST 4: Using VM Folder '$VMFolder' from configuration" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-ExcelExport"
        
        # Get VMs from specified folder
        Write-Host "Retrieving VMs from folder..." -ForegroundColor Yellow
        $VMs = Get-VM -Location $VMFolder -ErrorAction Stop
        $TotalVMs = $VMs.Count
        Write-Host "Total VMs in folder: $TotalVMs" -ForegroundColor Green
        Write-VirtToolkitLog -Message "TEST 4: Retrieved $TotalVMs VMs from folder '$VMFolder'" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-ExcelExport"
        
        # Apply PowerState filter
        if ($Config.Filters.PowerStates -and $Config.Filters.PowerStates.Count -gt 0) {
            $FilteredVMs = $VMs | Where-Object { $Config.Filters.PowerStates -contains $_.PowerState }
            $PowerStateFiltered = $TotalVMs - $FilteredVMs.Count
            Write-Host "After PowerState filter ($($Config.Filters.PowerStates -join ', ')): $($FilteredVMs.Count) VMs" -ForegroundColor Green
            Write-VirtToolkitLog -Message "TEST 4: PowerState filter applied - $PowerStateFiltered VMs filtered out" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-ExcelExport"
            $VMs = $FilteredVMs
        }
        
        # Apply ExcludeNames filter
        if ($Config.Filters.ExcludeNames -and $Config.Filters.ExcludeNames.Count -gt 0) {
            $BeforeExclude = $VMs.Count
            foreach ($pattern in $Config.Filters.ExcludeNames) {
                $VMs = $VMs | Where-Object { $_.Name -notlike $pattern }
            }
            $ExcludeFiltered = $BeforeExclude - $VMs.Count
            Write-Host "After ExcludeNames filter ($($Config.Filters.ExcludeNames -join ', ')): $($VMs.Count) VMs" -ForegroundColor Green
            Write-VirtToolkitLog -Message "TEST 4: ExcludeNames filter applied - $ExcludeFiltered VMs filtered out" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-ExcelExport"
        }
        
        # Limit to 10 VMs for testing
        $VMs = $VMs | Select-Object -First 10
        Write-Host "Limited to 10 VMs for testing" -ForegroundColor Green
        Write-VirtToolkitLog -Message "TEST 4: Limited to 10 VMs for testing" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-ExcelExport"
        
        # Retrieve ALL properties from configuration
        Write-Host "Retrieving all properties from configuration..." -ForegroundColor Yellow
        $VMData = $VMs | Select-Object @{Name = 'Name'; Expression = { $_.Name } },
        @{Name = 'UUID'; Expression = { $_.ExtensionData.Config.Uuid } },
        @{Name = 'DNSName'; Expression = { $_.Guest.HostName } },
        @{Name = 'PowerState'; Expression = { $_.PowerState } },
        @{Name = 'GuestOS'; Expression = { $_.Guest.OSFullName } },
        @{Name = 'NumCPU'; Expression = { $_.NumCpu } },
        @{Name = 'MemoryMB'; Expression = { $_.MemoryMB } },
        @{Name = 'ProvisionedSpaceGB'; Expression = { [math]::Round($_.ProvisionedSpaceGB, 2) } },
        @{Name = 'UsedSpaceGB'; Expression = { [math]::Round($_.UsedSpaceGB, 2) } },
        @{Name = 'Datastore'; Expression = { ($_.DatastoreIdList | ForEach-Object { (Get-Datastore -Id $_).Name }) -join ', ' } },
        @{Name = 'NetworkAdapters'; Expression = { ($_ | Get-NetworkAdapter).Name -join ', ' } },
        @{Name = 'IPAddresses'; Expression = { ($_.Guest.IPAddress | Where-Object { $_ -notmatch ':' }) -join ', ' } },
        @{Name = 'Annotation'; Expression = { $_.Notes } },
        @{Name = 'HostSystem'; Expression = { $_.VMHost.Name } },
        @{Name = 'VMToolsVersion'; Expression = { $_.Guest.ToolsVersion } },
        @{Name = 'VMToolsStatus'; Expression = { $_.Guest.ToolsStatus } },
        @{Name = 'Folder'; Expression = { $_.Folder.Name } }
        
        Write-Host "Retrieved all 17 properties from $($VMData.Count) VMs" -ForegroundColor Green
        Write-VirtToolkitLog -Message "TEST 4: Retrieved all 17 properties from $($VMData.Count) VMs" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-ExcelExport"
        
        # Export to Excel
        $Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $ExcelFile4 = Join-Path $OutputPath "Test4-FullWorkflow-Export_$Timestamp.xlsx"
        Write-Host "Exporting to Excel: $ExcelFile4" -ForegroundColor Yellow
        
        $AdditionalMetadata = @{
            "Test Case"                     = "Test 4: Full Production Workflow"
            "Timestamp"                     = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            "VM Folder"                     = $VMFolder
            "Total VMs in Folder"           = $TotalVMs
            "VMs After PowerState Filter"   = if ($Config.Filters.PowerStates) { $FilteredVMs.Count } else { $TotalVMs }
            "VMs After ExcludeNames Filter" = if ($Config.Filters.ExcludeNames) { $VMs.Count + 10 - 10 } else { "N/A" }
            "VMs Exported"                  = $VMData.Count
            "Properties Retrieved"          = ($Config.VMProperties.Keys -join ', ')
            "Property Count"                = $Config.VMProperties.Count
            "PowerState Filters"            = if ($Config.Filters.PowerStates) { ($Config.Filters.PowerStates -join ', ') } else { "None" }
            "ExcludeNames Patterns"         = if ($Config.Filters.ExcludeNames) { ($Config.Filters.ExcludeNames -join ', ') } else { "None" }
        }
        
        $Result4 = Export-VirtToolkitExcel -Data $VMData -FilePath $ExcelFile4 -WorksheetName "VMs" -AdditionalMetadata $AdditionalMetadata -AutoSize $true -FreezeHeaders $true -UseAdvancedFormatting $true
        
        if ($Result4 -and $Result4.Success) {
            Write-Host "Excel export successful!" -ForegroundColor Green
            Write-Host "File location: $ExcelFile4" -ForegroundColor Cyan
            $FileSize = [math]::Round((Get-Item $ExcelFile4).Length / 1KB, 2)
            Write-Host "File size: $FileSize KB" -ForegroundColor Cyan
            Write-VirtToolkitLog -Message "TEST 4: Excel export successful - $ExcelFile4 ($FileSize KB)" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "Test-ExcelExport"
        }
        else {
            Write-Host "Excel export failed!" -ForegroundColor Red
            Write-VirtToolkitLog -Message "TEST 4: Excel export failed" -Level 'ERROR' -LogFile $LogFile -ModuleName "Test-ExcelExport"
        }
    }
    catch {
        Write-Host "TEST 4 Failed: $_" -ForegroundColor Red
        Write-VirtToolkitLog -Message "TEST 4: Exception - $_" -Level 'ERROR' -LogFile $LogFile -ModuleName "Test-ExcelExport"
        $Result4 = @{ Success = $false; Message = $_.Exception.Message }
    }
}
else {
    Write-VirtToolkitLog -Message "TEST 4: Skipped (not selected)" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-ExcelExport"
}
#endregion

# Disconnect from vCenter
Write-Host ""
Write-Host "───────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "Disconnecting from vCenter..." -ForegroundColor Yellow
try {
    Disconnect-VIServer -Server $Connection -Confirm:$false -ErrorAction Stop
    Write-Host "Disconnected successfully" -ForegroundColor Green
    Write-VirtToolkitLog -Message "Disconnected from vCenter" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "Test-ExcelExport"
}
catch {
    Write-Host "Disconnect warning: $($_.Exception.Message)" -ForegroundColor Yellow
}
Write-Host ""

# Summary
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                          Test Summary                                         " -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Determine overall status
$TestResults = @()
if ($RunTest1) {
    $TestResults += @{ Name = "TEST 1: Basic Excel Export"; Success = ($Result1 -and $Result1.Success); File = $ExcelFile1; Run = $true }
}
if ($RunTest2) {
    $TestResults += @{ Name = "TEST 2: All Properties Export"; Success = ($Result2 -and $Result2.Success); File = $ExcelFile2; Run = $true }
}
if ($RunTest3) {
    $TestResults += @{ Name = "TEST 3: Filtering Validation"; Success = ($Result3 -and $Result3.Success); File = $ExcelFile3; Run = $true }
}
if ($RunTest4) {
    $TestResults += @{ Name = "TEST 4: Full Production Workflow"; Success = ($Result4 -and $Result4.Success); File = $ExcelFile4; Run = $true }
}

if ($TestResults.Count -eq 0) {
    Write-Host "No tests were selected to run." -ForegroundColor Yellow
    Write-VirtToolkitLog -Message "No tests selected - exiting" -Level 'WARN' -LogFile $LogFile -ModuleName "Test-ExcelExport"
    exit 0
}

$TotalTests = $TestResults.Count
$PassedTests = 0
foreach ($test in $TestResults) {
    if ($test.Success) {
        $PassedTests++
    }
}

Write-Host "Test Results:" -ForegroundColor Yellow
foreach ($test in $TestResults) {
    $status = if ($test.Success) { "PASSED" } else { "FAILED" }
    $color = if ($test.Success) { "Green" } else { "Red" }
    Write-Host "  $($test.Name): " -NoNewline -ForegroundColor White
    Write-Host $status -ForegroundColor $color
}
Write-Host ""

Write-Host "Overall Results:" -ForegroundColor Yellow
Write-Host "  Tests Run: $TotalTests" -ForegroundColor White
Write-Host "  Tests Passed: $PassedTests / $TotalTests" -ForegroundColor White
Write-Host "  Success Rate: $([math]::Round(($PassedTests / $TotalTests) * 100, 1))%" -ForegroundColor White
Write-Host ""

Write-VirtToolkitLog -Message "Test suite completed: $PassedTests/$TotalTests tests passed" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-ExcelExport"
Write-VirtToolkitLog -Message "Log file: $LogFile" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-ExcelExport"

if ($PassedTests -eq $TotalTests) {
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "                     ALL TESTS PASSED SUCCESSFULLY                             " -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-VirtToolkitLog -Message "All tests passed successfully" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "Test-ExcelExport"
    
    Write-Host "Generated Files:" -ForegroundColor Yellow
    foreach ($test in $TestResults) {
        if (Test-Path $test.File) {
            $fileInfo = Get-Item $test.File
            Write-Host "  - $(Split-Path $test.File -Leaf) ($([math]::Round($fileInfo.Length / 1KB, 2)) KB)" -ForegroundColor White
        }
    }
    Write-Host ""
    
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Review Test 1 Excel file for basic export validation" -ForegroundColor White
    Write-Host "  2. Review Test 2 Excel file to verify all properties are retrieved correctly" -ForegroundColor White
    Write-Host "  3. Review Test 3 Excel file and metadata to verify filter logic" -ForegroundColor White
    Write-Host "  4. Check log file for detailed execution information: $LogFile" -ForegroundColor White
    Write-Host ""
    
    exit 0
}
else {
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "                        SOME TESTS FAILED                                      " -ForegroundColor Red
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host ""
    Write-VirtToolkitLog -Message "Test suite completed with failures: $PassedTests/$TotalTests passed" -Level 'ERROR' -LogFile $LogFile -ModuleName "Test-ExcelExport"
    
    Write-Host "Review the log file for error details: $LogFile" -ForegroundColor Yellow
    Write-Host ""
    
    exit 1
}
