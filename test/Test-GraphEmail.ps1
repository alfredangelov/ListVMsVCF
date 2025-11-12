#Requires -Version 5.1

<#
.SYNOPSIS
    Tests Microsoft Graph email functionality using VirtToolkit modules.

.DESCRIPTION
    This test script validates Microsoft Graph email sending by:
    - Loading configuration from Configuration.psd1
    - Retrieving Graph client secret from SecretVault
    - Connecting to Microsoft Graph
    - Sending a test email
    - Optionally testing with attachments (creates a test file)

.PARAMETER IncludeAttachment
    If specified, creates a test file and attempts to attach it to the email.
    Note: VirtToolkit.GraphEmail module needs attachment support to be implemented.

.PARAMETER TestLargeAttachment
    If specified, creates a test file larger than 3MB to test size validation.
    This will trigger a warning in the module and the attachment will be skipped.

.EXAMPLE
    .\Test-GraphEmail.ps1
    Sends a simple test email without attachments

.EXAMPLE
    .\Test-GraphEmail.ps1 -IncludeAttachment
    Sends a test email with a test file attachment

.EXAMPLE
    .\Test-GraphEmail.ps1 -IncludeAttachment -TestLargeAttachment
    Sends a test email with a large (>3MB) attachment to test size validation

.NOTES
    Part of VirtToolkit: Enterprise Virtualization Management Platform
    Test script for validating Graph email and credential management
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$IncludeAttachment,
    
    [Parameter(Mandatory = $false)]
    [switch]$TestLargeAttachment
)

# Script setup
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ToolkitRoot = Split-Path -Parent $ScriptRoot

# Initialize log file
$LogsDir = Join-Path $ToolkitRoot 'logs'
if (-not (Test-Path $LogsDir)) {
    New-Item -Path $LogsDir -ItemType Directory -Force | Out-Null
}
$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$LogFile = Join-Path $LogsDir "Test-GraphEmail_$Timestamp.log"

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                  VirtToolkit Graph Email Connectivity Test                    " -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Import modules
try {
    Write-Host "Loading VirtToolkit modules..." -ForegroundColor Yellow
    Import-Module (Join-Path $ToolkitRoot 'modules\VirtToolkit.Logging.psm1') -Force -ErrorAction Stop
    Import-Module (Join-Path $ToolkitRoot 'modules\VirtToolkit.GraphEmail.psm1') -Force -ErrorAction Stop
    Write-Host "Modules loaded successfully" -ForegroundColor Green
    Write-VirtToolkitLog -Message "VirtToolkit modules loaded successfully" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "Test-GraphEmail"
    Write-Host ""
}
catch {
    Write-Host "Failed to load modules: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Load configuration
$ConfigPath = Join-Path $ToolkitRoot 'shared\config\Configuration.psd1'
Write-Host "Loading configuration from: $ConfigPath" -ForegroundColor Yellow
Write-VirtToolkitLog -Message "Loading configuration from: $ConfigPath" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-GraphEmail"
try {
    $Config = Import-PowerShellDataFile -Path $ConfigPath -ErrorAction Stop
    Write-Host "Configuration loaded" -ForegroundColor Green
    Write-VirtToolkitLog -Message "Configuration loaded successfully" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "Test-GraphEmail"
    Write-Host ""
}
catch {
    Write-Host "Failed to load configuration: $($_.Exception.Message)" -ForegroundColor Red
    Write-VirtToolkitLog -Message "Failed to load configuration: $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile -ModuleName "Test-GraphEmail"
    exit 1
}

# Validate email configuration
if (-not $Config.EmailNotification -or -not $Config.EmailNotification.Enabled) {
    Write-Host "Email notifications are not enabled in Configuration.psd1" -ForegroundColor Red
    Write-Host "  Set EmailNotification.Enabled = `$true to use this test" -ForegroundColor Yellow
    exit 1
}

$EmailConfig = $Config.EmailNotification
$VaultName = $Config.preferredVault

Write-Host "Email Configuration:" -ForegroundColor Cyan
Write-Host "  Tenant ID: $($EmailConfig.TenantId)" -ForegroundColor White
Write-Host "  Client ID: $($EmailConfig.ClientId)" -ForegroundColor White
Write-Host "  Client Secret Name: $($EmailConfig.ClientSecretName)" -ForegroundColor White
Write-Host "  Vault: $VaultName" -ForegroundColor White
Write-Host "  From: $($EmailConfig.From)" -ForegroundColor White
Write-Host "  To: $($EmailConfig.To -join ', ')" -ForegroundColor White
if ($IncludeAttachment) {
    Write-Host "  Include Attachment: Yes" -ForegroundColor Yellow
}
Write-Host ""

# Verify client secret exists in vault
Write-Host "───────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "Verifying client secret in vault..." -ForegroundColor Yellow
try {
    $SecretTest = Get-Secret -Name $EmailConfig.ClientSecretName -Vault $VaultName -ErrorAction Stop
    if ($SecretTest) {
        Write-Host "Client secret found in vault" -ForegroundColor Green
    }
}
catch {
    Write-Host "Client secret not found in vault: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Run: .\scripts\Manage-VirtToolkitSecrets.ps1 -Mode Initialize" -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# Create test attachment if requested
$AttachmentPath = $null
if ($IncludeAttachment) {
    Write-Host "───────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host "Creating test attachment file..." -ForegroundColor Yellow
    
    try {
        $OutputPath = if ($Config.OutputPath) { Join-Path $ToolkitRoot $Config.OutputPath } else { Join-Path $ToolkitRoot 'output' }
        if (-not (Test-Path $OutputPath)) {
            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        }
        
        $Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $AttachmentPath = Join-Path $OutputPath "EmailTest_Attachment_$Timestamp.txt"
        
        if ($TestLargeAttachment) {
            # Create a large file (4MB) to test size validation
            Write-Host "Creating large test file (>3MB) to test size validation..." -ForegroundColor Yellow
            Write-VirtToolkitLog -Message "Creating large test attachment (4MB) for size validation testing" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-GraphEmail"
            
            $AttachmentContent = @"
VirtToolkit Email Test Attachment - LARGE FILE TEST

This is a LARGE test attachment file created to validate file size limits.

Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Toolkit Root: $ToolkitRoot
Test Purpose: Validate email attachment SIZE VALIDATION (>3MB limit)

File Information:
- Filename: $(Split-Path $AttachmentPath -Leaf)
- Path: $AttachmentPath
- Expected Size: ~4MB (exceeds Microsoft Graph 3MB inline attachment limit)

Expected Behavior:
- Module should detect file size exceeds 3MB limit
- Module should log a WARNING message
- Module should SKIP this attachment
- Email should still be sent successfully without attachment

"@
            
            # Add padding to make file larger than 3MB
            $PaddingLine = "=" * 1000 + "`n"  # 1KB per line
            $PaddingContent = $PaddingLine * 4200  # ~4.2MB of padding
            $AttachmentContent += $PaddingContent
            
            $AttachmentContent | Out-File -FilePath $AttachmentPath -Encoding UTF8 -Force
        }
        else {
            # Create a small test file
            $AttachmentContent = @"
VirtToolkit Email Test Attachment

This is a test attachment file created by the Graph Email test script.

Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Toolkit Root: $ToolkitRoot
Test Purpose: Validate email attachment functionality

File Information:
- Filename: $(Split-Path $AttachmentPath -Leaf)
- Path: $AttachmentPath

If you can read this file, the email attachment functionality is working correctly.
"@
            
            $AttachmentContent | Out-File -FilePath $AttachmentPath -Encoding UTF8 -Force
        }
        
        $FileInfo = Get-Item $AttachmentPath
        Write-Host "Test attachment created" -ForegroundColor Green
        Write-Host "  File: $($FileInfo.Name)" -ForegroundColor White
        Write-Host "  Path: $($FileInfo.FullName)" -ForegroundColor White
        $FileSizeMB = [math]::Round($FileInfo.Length / 1MB, 2)
        if ($FileInfo.Length -gt 3MB) {
            Write-Host "  Size: $($FileInfo.Length) bytes ($FileSizeMB MB) - EXCEEDS 3MB LIMIT" -ForegroundColor Yellow
            Write-Host "  Expected: Module will log WARNING and skip this attachment" -ForegroundColor Yellow
        }
        else {
            Write-Host "  Size: $($FileInfo.Length) bytes ($FileSizeMB MB)" -ForegroundColor White
        }
    }
    catch {
        Write-Host "Failed to create test attachment: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Continuing without attachment..." -ForegroundColor Yellow
        $AttachmentPath = $null
    }
    Write-Host ""
}

# Send test email
Write-Host "───────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "Sending test email via Microsoft Graph..." -ForegroundColor Yellow
Write-Host ""

$TestSubject = "VirtToolkit Graph Email Test - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
if ($IncludeAttachment -and $AttachmentPath) {
    $FileInfo = Get-Item $AttachmentPath
    $FileSizeMB = [math]::Round($FileInfo.Length / 1MB, 2)
    if ($TestLargeAttachment) {
        $AttachmentNote = "`n- Attachment Testing: Large File Test (${FileSizeMB}MB - exceeds 3MB limit, should be skipped)"
    }
    else {
        $AttachmentNote = "`n- Attachment Testing: Enabled - file '$(Split-Path $AttachmentPath -Leaf)' (${FileSizeMB}MB) attached"
    }
}
else {
    $AttachmentNote = ""
}
$TestBody = @"
This is a test email from VirtToolkit Graph Email Test Script.

Test Details:
- Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
- Toolkit Root: $ToolkitRoot
- Tenant ID: $($EmailConfig.TenantId)
- Client ID: $($EmailConfig.ClientId)$AttachmentNote

If you received this email, the Microsoft Graph email integration is working correctly.

This is an automated test message from VirtToolkit.
"@

try {
    $EmailParams = @{
        TenantId         = $EmailConfig.TenantId
        ClientId         = $EmailConfig.ClientId
        ClientSecretName = $EmailConfig.ClientSecretName
        VaultName        = $VaultName
        From             = $EmailConfig.From
        To               = $EmailConfig.To
        Subject          = $TestSubject
        Body             = $TestBody
    }
    
    # Add attachment if requested
    if ($IncludeAttachment -and $AttachmentPath) {
        $EmailParams['Attachments'] = @($AttachmentPath)
        Write-VirtToolkitLog -Message "Including attachment in email: $AttachmentPath" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-GraphEmail"
    }
    
    Write-VirtToolkitLog -Message "Attempting to send test email via Microsoft Graph" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-GraphEmail"
    $Result = Send-VirtToolkitGraphEmail @EmailParams
    
    if ($Result) {
        Write-Host ""
        Write-Host "Test email sent successfully" -ForegroundColor Green
        Write-VirtToolkitLog -Message "Test email sent successfully to: $($EmailConfig.To -join ', ')" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "Test-GraphEmail"
        Write-Host "  Subject: $TestSubject" -ForegroundColor White
        Write-Host "  From: $($EmailConfig.From)" -ForegroundColor White
        Write-Host "  To: $($EmailConfig.To -join ', ')" -ForegroundColor White
        if ($IncludeAttachment -and $AttachmentPath) {
            Write-Host "  Attachment: $(Split-Path $AttachmentPath -Leaf)" -ForegroundColor Green
        }
    }
    else {
        Write-Host ""
        Write-Host "Failed to send test email" -ForegroundColor Red
        Write-VirtToolkitLog -Message "Failed to send test email - check errors above" -Level 'ERROR' -LogFile $LogFile -ModuleName "Test-GraphEmail"
        exit 1
    }
}
catch {
    Write-Host ""
    Write-Host "Email sending failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-VirtToolkitLog -Message "Email sending exception: $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile -ModuleName "Test-GraphEmail"
    exit 1
}
Write-Host ""

# Summary
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                          Test Completed Successfully                          " -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-VirtToolkitLog -Message "Graph email test completed successfully" -Level 'SUCCESS' -LogFile $LogFile -ModuleName "Test-GraphEmail"
Write-VirtToolkitLog -Message "Log file: $LogFile" -Level 'INFO' -LogFile $LogFile -ModuleName "Test-GraphEmail"
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Check your inbox at: $($EmailConfig.To -join ', ')" -ForegroundColor White
Write-Host "  2. Verify the test email was received" -ForegroundColor White
Write-Host "  3. Check spam/junk folder if email not in inbox" -ForegroundColor White
if ($IncludeAttachment) {
    Write-Host "  4. Verify the attachment is present in the email" -ForegroundColor White
}
Write-Host ""

exit 0
