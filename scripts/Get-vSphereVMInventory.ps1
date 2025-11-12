<#
.SYNOPSIS
    Retrieves VM inventory from vSphere/vCenter and exports to Excel with optional email delivery.

.DESCRIPTION
    This script connects to a vSphere/vCenter server, retrieves VM information from a specified
    folder with configurable filters, and exports the data to Excel. Optionally sends the report
    via email using Microsoft Graph API.

    Features:
    - Connects to vSphere/vCenter using stored credentials
    - Retrieves VMs from configured folder with filtering support
    - Exports all configured properties to Excel with metadata
    - Optional email delivery with Microsoft Graph
    - Comprehensive logging of all operations
    - DryRun mode for testing without generating files

.PARAMETER ConfigPath
    Path to the Configuration.psd1 file. Defaults to shared\config\Configuration.psd1

.PARAMETER SkipEmail
    Skip email notification even if enabled in configuration

.EXAMPLE
    .\Get-vSphereVMInventory.ps1
    
    Runs with default configuration, generates Excel report and sends email if configured

.EXAMPLE
    .\Get-vSphereVMInventory.ps1 -SkipEmail
    
    Generates Excel report but skips email notification

.EXAMPLE
    .\Get-vSphereVMInventory.ps1 -ConfigPath "C:\Custom\Config.psd1"
    
    Uses custom configuration file

.NOTES
    Author: VirtToolkit
    Version: 1.0.0
    Requires: VMware.PowerCLI, Microsoft.PowerShell.SecretManagement, ImportExcel
    Optional: Microsoft.Graph modules (for email notifications)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipEmail
)

# Script setup
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ToolkitRoot = Split-Path -Parent $ScriptRoot

# Initialize timestamp and log file
$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$LogsDir = Join-Path $ToolkitRoot 'logs'
if (-not (Test-Path $LogsDir)) {
    New-Item -Path $LogsDir -ItemType Directory -Force | Out-Null
}
$LogFile = Join-Path $LogsDir "vSphereVMInventory_$Timestamp.log"

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                    vSphere VM Inventory Report Generator                     " -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Import modules
try {
    Write-Host "Loading VirtToolkit modules..." -ForegroundColor Yellow
    Import-Module (Join-Path $ToolkitRoot 'modules\VirtToolkit.Logging.psm1') -Force -ErrorAction Stop
    Import-Module (Join-Path $ToolkitRoot 'modules\VirtToolkit.Credentials.psm1') -Force -ErrorAction Stop
    Import-Module (Join-Path $ToolkitRoot 'modules\VirtToolkit.Excel.psm1') -Force -ErrorAction Stop
    Write-Host "Modules loaded successfully" -ForegroundColor Green
    Write-VirtToolkitLog -Message "VirtToolkit modules loaded successfully" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "vSphereVMInventory"
    Write-Host ""
}
catch {
    Write-Host "Failed to load modules: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Load configuration
if (-not $ConfigPath) {
    $ConfigPath = Join-Path $ToolkitRoot 'shared\config\Configuration.psd1'
}

Write-Host "Loading configuration from: $ConfigPath" -ForegroundColor Yellow
Write-VirtToolkitLog -Message "Loading configuration from: $ConfigPath" -Level 'INFO' -LogFile $LogFile -ModuleName "vSphereVMInventory"

try {
    $Config = Import-PowerShellDataFile -Path $ConfigPath -ErrorAction Stop
    Write-Host "Configuration loaded" -ForegroundColor Green
    Write-VirtToolkitLog -Message "Configuration loaded successfully" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "vSphereVMInventory"
    Write-Host ""
}
catch {
    Write-Host "Failed to load configuration: $($_.Exception.Message)" -ForegroundColor Red
    Write-VirtToolkitLog -Message "Failed to load configuration: $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile -ModuleName "vSphereVMInventory"
    exit 1
}

# Extract settings
$vCenterServer = $Config.SourceServerHost
$VaultName = $Config.preferredVault
$PreferredUsername = $Config.PreferredUsername
$VMFolder = $Config.VMFolder
$OutputPath = if ($Config.OutputPath) { Join-Path $ToolkitRoot $Config.OutputPath } else { Join-Path $ToolkitRoot 'output' }
$DryRun = $Config.DryRun

# Ensure output directory exists
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
}

Write-Host "Configuration Details:" -ForegroundColor Cyan
Write-Host "  vCenter Server: $vCenterServer" -ForegroundColor White
Write-Host "  VM Folder: $VMFolder" -ForegroundColor White
Write-Host "  Output Path: $OutputPath" -ForegroundColor White
Write-Host "  Dry Run Mode: $DryRun" -ForegroundColor White
Write-Host "  Properties to retrieve: $($Config.VMProperties.Count)" -ForegroundColor White
Write-Host ""

if ($DryRun) {
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host "                           DRY RUN MODE ENABLED                                " -ForegroundColor Yellow
    Write-Host "  No Excel file will be generated. Set DryRun = `$false in Configuration.psd1  " -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host ""
    Write-VirtToolkitLog -Message "DRY RUN MODE - No files will be generated" -Level 'WARN' -LogFile $LogFile -ModuleName "vSphereVMInventory"
}

# Import VMware PowerCLI
try {
    Write-Host "Loading VMware PowerCLI..." -ForegroundColor Yellow
    Import-Module VMware.VimAutomation.Core -ErrorAction Stop
    Write-Host "PowerCLI loaded" -ForegroundColor Green
    Write-VirtToolkitLog -Message "PowerCLI loaded successfully" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "vSphereVMInventory"
    Write-Host ""
}
catch {
    Write-Host "Failed to load PowerCLI: $($_.Exception.Message)" -ForegroundColor Red
    Write-VirtToolkitLog -Message "Failed to load PowerCLI: $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile -ModuleName "vSphereVMInventory"
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
Write-VirtToolkitLog -Message "Retrieving credentials for $vCenterServer" -Level 'INFO' -LogFile $LogFile -ModuleName "vSphereVMInventory"

try {
    $Credential = Get-VirtToolkitCredential -Server $vCenterServer -PreferredUsername $PreferredUsername -VaultName $VaultName
    
    if ($Credential) {
        Write-Host "Credential retrieved: $($Credential.UserName)" -ForegroundColor Green
        Write-VirtToolkitLog -Message "Credential retrieved for user: $($Credential.UserName)" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "vSphereVMInventory"
    }
    else {
        Write-Host "Failed to retrieve credential" -ForegroundColor Red
        Write-VirtToolkitLog -Message "Failed to retrieve credential" -Level 'ERROR' -LogFile $LogFile -ModuleName "vSphereVMInventory"
        exit 1
    }
}
catch {
    Write-Host "Credential retrieval failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-VirtToolkitLog -Message "Credential retrieval failed: $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile -ModuleName "vSphereVMInventory"
    exit 1
}
Write-Host ""

# Connect to vCenter
Write-Host "───────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "Connecting to vCenter: $vCenterServer" -ForegroundColor Yellow
Write-VirtToolkitLog -Message "Connecting to vCenter: $vCenterServer" -Level 'INFO' -LogFile $LogFile -ModuleName "vSphereVMInventory"

try {
    $Connection = Connect-VIServer -Server $vCenterServer -Credential $Credential -ErrorAction Stop
    Write-Host "Successfully connected to vCenter" -ForegroundColor Green
    Write-Host "  Server: $($Connection.Name)" -ForegroundColor White
    Write-Host "  User: $($Connection.User)" -ForegroundColor White
    Write-VirtToolkitLog -Message "Successfully connected to vCenter as $($Connection.User)" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "vSphereVMInventory"
}
catch {
    Write-Host "Connection failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-VirtToolkitLog -Message "Connection failed: $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile -ModuleName "vSphereVMInventory"
    exit 1
}
Write-Host ""

# Retrieve VMs from folder
Write-Host "───────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "Retrieving VMs from folder: $VMFolder" -ForegroundColor Yellow
Write-VirtToolkitLog -Message "Retrieving VMs from folder: $VMFolder" -Level 'INFO' -LogFile $LogFile -ModuleName "vSphereVMInventory"

try {
    $VMs = Get-VM -Location $VMFolder -ErrorAction Stop
    $TotalVMs = $VMs.Count
    Write-Host "Total VMs in folder: $TotalVMs" -ForegroundColor Green
    Write-VirtToolkitLog -Message "Retrieved $TotalVMs VMs from folder '$VMFolder'" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "vSphereVMInventory"
    
    # Apply PowerState filter
    if ($Config.Filters.PowerStates -and $Config.Filters.PowerStates.Count -gt 0) {
        $BeforeFilter = $VMs.Count
        $VMs = $VMs | Where-Object { $Config.Filters.PowerStates -contains $_.PowerState }
        $Filtered = $BeforeFilter - $VMs.Count
        Write-Host "After PowerState filter ($($Config.Filters.PowerStates -join ', ')): $($VMs.Count) VMs" -ForegroundColor Green
        Write-VirtToolkitLog -Message "PowerState filter applied - $Filtered VMs filtered out" -Level 'INFO' -LogFile $LogFile -ModuleName "vSphereVMInventory"
    }
    
    # Apply ExcludeNames filter
    if ($Config.Filters.ExcludeNames -and $Config.Filters.ExcludeNames.Count -gt 0) {
        $BeforeExclude = $VMs.Count
        foreach ($pattern in $Config.Filters.ExcludeNames) {
            $VMs = $VMs | Where-Object { $_.Name -notlike $pattern }
        }
        $Excluded = $BeforeExclude - $VMs.Count
        Write-Host "After ExcludeNames filter ($($Config.Filters.ExcludeNames -join ', ')): $($VMs.Count) VMs" -ForegroundColor Green
        Write-VirtToolkitLog -Message "ExcludeNames filter applied - $Excluded VMs filtered out" -Level 'INFO' -LogFile $LogFile -ModuleName "vSphereVMInventory"
    }
    
    # Apply IncludeNames filter
    if ($Config.Filters.IncludeNames -and $Config.Filters.IncludeNames.Count -gt 0) {
        $BeforeInclude = $VMs.Count
        $IncludedVMs = @()
        foreach ($pattern in $Config.Filters.IncludeNames) {
            $IncludedVMs += $VMs | Where-Object { $_.Name -like $pattern }
        }
        $VMs = $IncludedVMs | Select-Object -Unique
        Write-Host "After IncludeNames filter ($($Config.Filters.IncludeNames -join ', ')): $($VMs.Count) VMs" -ForegroundColor Green
        Write-VirtToolkitLog -Message "IncludeNames filter applied - $($VMs.Count) VMs included" -Level 'INFO' -LogFile $LogFile -ModuleName "vSphereVMInventory"
    }
    
    Write-Host "Final VM count after all filters: $($VMs.Count)" -ForegroundColor Cyan
    Write-VirtToolkitLog -Message "Final VM count after filters: $($VMs.Count)" -Level 'INFO' -LogFile $LogFile -ModuleName "vSphereVMInventory"
}
catch {
    Write-Host "Failed to retrieve VMs: $($_.Exception.Message)" -ForegroundColor Red
    Write-VirtToolkitLog -Message "Failed to retrieve VMs: $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile -ModuleName "vSphereVMInventory"
    Disconnect-VIServer -Server $Connection -Confirm:$false -ErrorAction SilentlyContinue
    exit 1
}
Write-Host ""

# Check if any VMs remain after filtering
if ($VMs.Count -eq 0) {
    Write-Host "No VMs found matching the filter criteria" -ForegroundColor Yellow
    Write-VirtToolkitLog -Message "No VMs found matching filter criteria - exiting" -Level 'WARN' -LogFile $LogFile -ModuleName "vSphereVMInventory"
    Disconnect-VIServer -Server $Connection -Confirm:$false -ErrorAction SilentlyContinue
    exit 0
}

# Retrieve VM properties
Write-Host "Retrieving VM properties..." -ForegroundColor Yellow
Write-VirtToolkitLog -Message "Retrieving properties for $($VMs.Count) VMs" -Level 'INFO' -LogFile $LogFile -ModuleName "vSphereVMInventory"

try {
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
    
    Write-Host "Retrieved all properties from $($VMData.Count) VMs" -ForegroundColor Green
    Write-VirtToolkitLog -Message "Successfully retrieved all properties from $($VMData.Count) VMs" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "vSphereVMInventory"
}
catch {
    Write-Host "Failed to retrieve VM properties: $($_.Exception.Message)" -ForegroundColor Red
    Write-VirtToolkitLog -Message "Failed to retrieve VM properties: $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile -ModuleName "vSphereVMInventory"
    Disconnect-VIServer -Server $Connection -Confirm:$false -ErrorAction SilentlyContinue
    exit 1
}
Write-Host ""

# Disconnect from vCenter
Write-Host "───────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "Disconnecting from vCenter..." -ForegroundColor Yellow
try {
    Disconnect-VIServer -Server $Connection -Confirm:$false -ErrorAction Stop
    Write-Host "Disconnected successfully" -ForegroundColor Green
    Write-VirtToolkitLog -Message "Disconnected from vCenter" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "vSphereVMInventory"
}
catch {
    Write-Host "Disconnect warning: $($_.Exception.Message)" -ForegroundColor Yellow
}
Write-Host ""

# Export to Excel (if not DryRun)
if (-not $DryRun) {
    Write-Host "───────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host "Exporting to Excel..." -ForegroundColor Yellow
    
    $ExcelFileName = "vSphere-VM-Inventory_$Timestamp.xlsx"
    $ExcelFilePath = Join-Path $OutputPath $ExcelFileName
    Write-VirtToolkitLog -Message "Exporting to Excel: $ExcelFilePath" -Level 'INFO' -LogFile $LogFile -ModuleName "vSphereVMInventory"
    
    try {
        $AdditionalMetadata = @{
            "Report Type"           = "vSphere VM Inventory"
            "vCenter Server"        = $vCenterServer
            "VM Folder"             = $VMFolder
            "Total VMs in Folder"   = $TotalVMs
            "VMs After Filters"     = $VMData.Count
            "Properties Retrieved"  = ($Config.VMProperties.Keys -join ', ')
            "Property Count"        = $Config.VMProperties.Count
            "PowerState Filters"    = if ($Config.Filters.PowerStates) { ($Config.Filters.PowerStates -join ', ') } else { "None" }
            "ExcludeNames Patterns" = if ($Config.Filters.ExcludeNames) { ($Config.Filters.ExcludeNames -join ', ') } else { "None" }
            "IncludeNames Patterns" = if ($Config.Filters.IncludeNames) { ($Config.Filters.IncludeNames -join ', ') } else { "None" }
            "Generated Date"        = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        }
        
        $Result = Export-VirtToolkitExcel -Data $VMData -FilePath $ExcelFilePath -WorksheetName "VM Inventory" -AdditionalMetadata $AdditionalMetadata -AutoSize $true -FreezeHeaders $true -UseAdvancedFormatting $true
        
        if ($Result -and $Result.Success) {
            Write-Host "Excel export successful!" -ForegroundColor Green
            Write-Host "  File: $ExcelFilePath" -ForegroundColor Cyan
            $FileSize = [math]::Round((Get-Item $ExcelFilePath).Length / 1KB, 2)
            Write-Host "  Size: $FileSize KB" -ForegroundColor Cyan
            Write-VirtToolkitLog -Message "Excel export successful: $ExcelFilePath ($FileSize KB)" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "vSphereVMInventory"
        }
        else {
            Write-Host "Excel export failed!" -ForegroundColor Red
            Write-VirtToolkitLog -Message "Excel export failed" -Level 'ERROR' -LogFile $LogFile -ModuleName "vSphereVMInventory"
            exit 1
        }
    }
    catch {
        Write-Host "Excel export error: $($_.Exception.Message)" -ForegroundColor Red
        Write-VirtToolkitLog -Message "Excel export error: $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile -ModuleName "vSphereVMInventory"
        exit 1
    }
    Write-Host ""
    
    # Send email notification (if enabled and not skipped)
    if ($Config.EmailNotification.Enabled -and -not $SkipEmail) {
        Write-Host "───────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
        Write-Host "Sending email notification..." -ForegroundColor Yellow
        Write-VirtToolkitLog -Message "Email notification enabled - preparing to send" -Level 'INFO' -LogFile $LogFile -ModuleName "vSphereVMInventory"
        
        try {
            # Import Graph Email module
            Import-Module (Join-Path $ToolkitRoot 'modules\VirtToolkit.GraphEmail.psm1') -Force -ErrorAction Stop
            
            # Prepare email parameters
            $EmailSubject = $Config.EmailNotification.Subject -replace '{{DATE}}', (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            $EmailBody = $Config.EmailNotification.BodyTemplate -replace '{{DATE}}', (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -replace '{{SERVER}}', $vCenterServer -replace '{{COUNT}}', $VMData.Count
            
            $EmailParams = @{
                TenantId         = $Config.EmailNotification.TenantId
                ClientId         = $Config.EmailNotification.ClientId
                From             = $Config.EmailNotification.From
                To               = $Config.EmailNotification.To
                Subject          = $EmailSubject
                Body             = $EmailBody
                VaultName        = $VaultName
                ClientSecretName = $Config.EmailNotification.ClientSecretName
                LogFile          = $LogFile
            }
            
            if ($Config.EmailNotification.IncludeAttachment) {
                $EmailParams.Attachments = @($ExcelFilePath)
            }
            
            $EmailResult = Send-VirtToolkitGraphEmail @EmailParams
            
            if ($EmailResult -and $EmailResult.Success) {
                Write-Host "Email sent successfully!" -ForegroundColor Green
                Write-Host "  Recipients: $($Config.EmailNotification.To -join ', ')" -ForegroundColor Cyan
                Write-VirtToolkitLog -Message "Email sent successfully to $($Config.EmailNotification.To -join ', ')" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "vSphereVMInventory"
            }
            else {
                Write-Host "Email sending failed: $($EmailResult.Message)" -ForegroundColor Red
                Write-VirtToolkitLog -Message "Email sending failed: $($EmailResult.Message)" -Level 'ERROR' -LogFile $LogFile -ModuleName "vSphereVMInventory"
            }
        }
        catch {
            Write-Host "Email error: $($_.Exception.Message)" -ForegroundColor Red
            Write-VirtToolkitLog -Message "Email error: $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile -ModuleName "vSphereVMInventory"
        }
        Write-Host ""
    }
    elseif ($SkipEmail) {
        Write-Host "Email notification skipped (-SkipEmail parameter)" -ForegroundColor Yellow
        Write-VirtToolkitLog -Message "Email notification skipped by user" -Level 'INFO' -LogFile $LogFile -ModuleName "vSphereVMInventory"
        Write-Host ""
    }
}
else {
    Write-Host "DRY RUN MODE - Displaying sample data instead of exporting:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Sample VMs (first 5):" -ForegroundColor Cyan
    $VMData | Select-Object -First 5 | Format-Table -AutoSize
    Write-Host "Total VMs that would be exported: $($VMData.Count)" -ForegroundColor Cyan
    Write-VirtToolkitLog -Message "DRY RUN completed - $($VMData.Count) VMs processed" -Level 'INFO' -LogFile $LogFile -ModuleName "vSphereVMInventory"
    Write-Host ""
}

# Summary
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                              Execution Summary                                " -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  vCenter Server: $vCenterServer" -ForegroundColor White
Write-Host "  VM Folder: $VMFolder" -ForegroundColor White
Write-Host "  Total VMs Found: $TotalVMs" -ForegroundColor White
Write-Host "  VMs After Filters: $($VMData.Count)" -ForegroundColor White
Write-Host "  Properties Retrieved: $($Config.VMProperties.Count)" -ForegroundColor White
if (-not $DryRun) {
    Write-Host "  Excel File: $ExcelFileName" -ForegroundColor White
    Write-Host "  Output Path: $OutputPath" -ForegroundColor White
}
Write-Host "  Log File: $LogFile" -ForegroundColor White
Write-Host ""
Write-VirtToolkitLog -Message "Script execution completed successfully" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "vSphereVMInventory"

Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "                         EXECUTION COMPLETED SUCCESSFULLY                      " -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
