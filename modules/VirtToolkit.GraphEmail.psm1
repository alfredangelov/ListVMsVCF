<#
.SYNOPSIS
    Sends Output reports via Microsoft Graph API email integration.

.DESCRIPTION
    This function handles the automated distribution of Output reports through Microsoft
    Graph API email services. It manages authentication, formatting, and delivery of
    exported data to configured recipients for streamlined reporting workflows.

.NOTES
    Part of VirtToolkit: Enterprise Virtualization Management Platform
    Integrates with shared modules and unified configuration system
#>
function Send-VirtToolkitGraphEmail {
    <#
    .SYNOPSIS
        Sends email using Microsoft Graph API for Output reports.

    .DESCRIPTION
        This function sends email notifications using Microsoft Graph with secure
        credential management for Output daily reports.

    .PARAMETER TenantId
        Azure AD Tenant ID.

    .PARAMETER ClientId
        Azure AD Application Client ID.

    .PARAMETER ClientSecret
        Client secret (if provided directly).

    .PARAMETER ClientSecretName
        Name of the client secret stored in SecretManagement vault.

    .PARAMETER VaultName
        Name of the SecretManagement vault containing the client secret.

    .PARAMETER From
        Sender email address.

    .PARAMETER To
        Array of recipient email addresses.

    .PARAMETER Subject
        Email subject line.

    .PARAMETER Body
        Email body content.

    .PARAMETER Attachments
        Array of file paths to attach to the email. Each file will be read and encoded as base64.

    .EXAMPLE
        Send-VirtToolkitGraphEmail -TenantId "tenant-id" -ClientId "client-id" -ClientSecretName "Graph-Secret" -From "sender@domain.com" -To @("recipient@domain.com") -Subject "Report" -Body "Content"

    .EXAMPLE
        Send-VirtToolkitGraphEmail -TenantId "tenant-id" -ClientId "client-id" -ClientSecretName "Graph-Secret" -From "sender@domain.com" -To @("recipient@domain.com") -Subject "Report" -Body "Content" -Attachments @("C:\Reports\data.xlsx", "C:\Logs\summary.txt")

    .OUTPUTS
        System.Boolean - Returns $true if email was sent successfully, $false otherwise.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TenantId,
        
        [Parameter(Mandatory)]
        [string]$ClientId,
        
        [Parameter()]
        [string]$ClientSecret,
        
        [Parameter()]
        [string]$ClientSecretName,
        
        [Parameter()]
        [string]$VaultName = 'SecretVault',
        
        [Parameter(Mandatory)]
        [string]$From,
        
        [Parameter(Mandatory)]
        [string[]]$To,
        
        [Parameter(Mandatory)]
        [string]$Subject,
        
        [Parameter(Mandatory)]
        [string]$Body,
        
        [Parameter()]
        [string[]]$Attachments,
        
        [Parameter()]
        [string]$LogFile,
        
        [Parameter()]
        [string]$ConfigLogLevel = 'INFO'
    )
    
    try {
        # Resolve ClientSecret from vault if ClientSecretName is provided
        if ($ClientSecretName -and -not $ClientSecret) {
            try {
                $ClientSecret = Get-Secret -Name $ClientSecretName -Vault $VaultName -AsPlainText -ErrorAction Stop
                Write-VirtToolkitLog -Message "Retrieved ClientSecret from vault: $ClientSecretName" -Level 'DEBUG' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
            }
            catch {
                Write-VirtToolkitLog -Message "Failed to retrieve ClientSecret from vault '$VaultName' with name '$ClientSecretName': $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                return $false
            }
        }
        
        # Validate that we have a ClientSecret
        if ([string]::IsNullOrWhiteSpace($ClientSecret)) {
            Write-VirtToolkitLog -Message "ClientSecret is required but not provided or retrieved from vault" -Level 'ERROR' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
            return $false
        }
        
        # Import required modules
        Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
        Import-Module Microsoft.Graph.Users.Actions -ErrorAction Stop
        
        Write-VirtToolkitLog -Message "Connecting to Microsoft Graph (Tenant: $TenantId)" -Level 'INFO' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
        
        # Create client secret credential
        $SecureSecret = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
        $ClientSecretCredential = New-Object System.Management.Automation.PSCredential($ClientId, $SecureSecret)
        
        # Connect to Microsoft Graph
        Connect-MgGraph -TenantId $TenantId -ClientSecretCredential $ClientSecretCredential -NoWelcome -ErrorAction Stop
        
        Write-VirtToolkitLog -Message "Successfully connected to Microsoft Graph" -Level 'SUCCESS' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
        
        # Create the email message structure for Send-MgUserMail
        $ToRecipients = @()
        foreach ($recipient in $To) {
            $ToRecipients += @{
                emailAddress = @{
                    address = $recipient
                }
            }
        }

        # Build the message object
        $Message = @{
            subject      = $Subject
            body         = @{
                contentType = "Text"
                content     = $Body
            }
            toRecipients = $ToRecipients
        }

        # Process attachments if provided
        if ($Attachments -and $Attachments.Count -gt 0) {
            $AttachmentArray = @()
            
            foreach ($attachmentPath in $Attachments) {
                try {
                    if (-not (Test-Path -Path $attachmentPath -PathType Leaf)) {
                        Write-VirtToolkitLog -Message "Attachment file not found: $attachmentPath" -Level 'WARN' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                        continue
                    }

                    $fileInfo = Get-Item -Path $attachmentPath
                    $fileName = $fileInfo.Name
                    $fileSize = $fileInfo.Length
                    
                    # Check file size (Microsoft Graph has a limit of 3MB for inline attachments)
                    $maxSize = 3MB
                    if ($fileSize -gt $maxSize) {
                        Write-VirtToolkitLog -Message "Attachment '$fileName' exceeds 3MB limit ($([math]::Round($fileSize/1MB, 2))MB). Skipping." -Level 'WARN' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                        continue
                    }

                    Write-VirtToolkitLog -Message "Processing attachment: $fileName ($([math]::Round($fileSize/1KB, 2))KB)" -Level 'INFO' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                    
                    # Read file and convert to base64
                    $fileBytes = [System.IO.File]::ReadAllBytes($attachmentPath)
                    $base64Content = [System.Convert]::ToBase64String($fileBytes)
                    
                    # Add to attachments array
                    $AttachmentArray += @{
                        "@odata.type" = "#microsoft.graph.fileAttachment"
                        name          = $fileName
                        contentType   = "application/octet-stream"
                        contentBytes  = $base64Content
                    }
                    
                    Write-VirtToolkitLog -Message "Successfully encoded attachment: $fileName" -Level 'DEBUG' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                }
                catch {
                    Write-VirtToolkitLog -Message "Failed to process attachment '$attachmentPath': $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
                }
            }
            
            if ($AttachmentArray.Count -gt 0) {
                $Message.attachments = $AttachmentArray
                Write-VirtToolkitLog -Message "Added $($AttachmentArray.Count) attachment(s) to email" -Level 'INFO' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
            }
        }

        $MailParams = @{
            message         = $Message
            saveToSentItems = $true
        }
        
        Write-VirtToolkitLog -Message "Sending email to: $($To -join ', ')" -Level 'INFO' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
        
        # Send the email
        Send-MgUserMail -UserId $From -BodyParameter $MailParams -ErrorAction Stop
        
        # Disconnect from Microsoft Graph
        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
        
        Write-VirtToolkitLog -Message "Successfully sent Microsoft Graph email to $($To -join ', ')" -Level 'SUCCESS' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
        return $true
        
    }
    catch {
        $errorDetails = $_.Exception.Message
        if ($_.ErrorDetails.Message) {
            $errorDetails += " | Details: $($_.ErrorDetails.Message)"
        }
        Write-VirtToolkitLog -Message "Microsoft Graph email error: $errorDetails" -Level 'ERROR' -LogFile $LogFile -ConfigLogLevel $ConfigLogLevel
        Write-Host "ERROR: Microsoft Graph email failed: $errorDetails" -ForegroundColor Red
        try { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null } catch { }
        return $false
    }
}
