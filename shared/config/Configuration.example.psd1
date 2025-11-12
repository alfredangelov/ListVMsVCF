# This is an example configuration file showing all available options.
# Copy this to Configuration.psd1 and customize for your environment.
# 
# Quick Start:
# 1. Copy this file: Copy-Item Configuration.example.psd1 Configuration.psd1
# 2. Edit Configuration.psd1 with your environment details (vCenter, datacenter, folder)

@{
    # Core Settings
    # If $true, shows sample data without creating Excel files (safe for testing)
    # Set to $false to generate actual Excel reports
    DryRun                  = $true                                 # Safe testing mode vs. actual export
    ScheduledExecution      = $false                                # Set to $true if running as a scheduled task (no timeout for vault)

    # vSphere Connection Settings
    # Compatible with both standard vSphere and VMware Cloud Foundation (VCF) environments
    SourceServerHost        = 'vcenter01.company.com'               # vCenter FQDN or IP (works with VCF vCenter instances)
    vCenterVersion          = '7.0'                                 # vCenter version (6.7, 7.0, 8.0) - VCF versions supported
    
    # Secure Credential Management
    # These settings control how credentials are stored and retrieved using server-centric naming
    preferredVault          = 'VirtToolkitVault'                    # Secret vault name for credential storage
    PreferredUsername       = 'administrator@vsphere.local'         # Preferred username for vSphere authentication
    # If multiple credentials exist for the same server, this one will be used
    # Leave as $null to be prompted or auto-select if only one exists
    
    # Credential Storage Pattern:
    # Credentials are stored as: vSphere-{hostname}-{username}
    # Example: vSphere-vcenter01.company.com-administrator@vsphere.local
    # This enables credential reuse across different VirtToolkit modules

    # SSL Certificate handling (useful for ESXi hosts with self-signed certificates)
    IgnoreSSLCertificates   = $true                                 # Set to $false for production vCenter with valid certificates

    # Network environment settings
    # Set to $true if running from networks with SSL inspection (Zscaler, etc.)
    NetworkHasSSLInspection = $true                                 # Enables additional SSL compatibility measures
    
    # Note: During initialization, run Manage-VirtToolkitSecrets.ps1 -Mode Initialize
    # to securely store credentials. They'll be automatically used for future connections.

    # vSphere Environment Settings
    dataCenter              = 'YourDatacenter'                      # Target datacenter name
    VMFolder                = 'YourFolder'                          # VM folder name (not path) to analyze
    
    # Example folder names:
    # VMFolder = 'vm'                                           # Root VM folder
    # VMFolder = 'Production'                                   # Production folder
    # VMFolder = 'VDI'                                          # VDI folder
    # VMFolder = 'Discovered virtual machine'                   # Special folder (good for testing)

    # VM Properties to Output
    # Key = Property Name, Value = Description/Display Name
    # Customize this hashtable to include only the properties you need
    VMProperties            = @{
        Name               = 'VM Display Name'
        UUID               = 'Unique VM Identifier'
        DNSName            = 'VM DNS Name'
        PowerState         = 'Current Power State (PoweredOn, PoweredOff, Suspended)'
        GuestOS            = 'Guest Operating System'
        NumCPU             = 'Number of vCPUs'
        MemoryMB           = 'Memory allocation in MB'
        ProvisionedSpaceGB = 'Total provisioned storage in GB'
        UsedSpaceGB        = 'Actual used storage in GB'
        Datastore          = 'Primary datastore name'
        NetworkAdapters    = 'Network adapter information'
        IPAddresses        = 'VM IP addresses'
        Annotation         = 'VM notes/comments'
        HostSystem         = 'ESXi host running the VM'
        VMToolsVersion     = 'VMware Tools version'
        VMToolsStatus      = 'VMware Tools status'
        Folder             = 'VM folder location'
        
        # Additional available properties (uncomment and add as needed):
        # ResourcePool      = 'Resource pool assignment'
        # HARestartPriority = 'HA restart priority'
        # DRSAutomationLevel = 'DRS automation level'
        # FirmwareType      = 'Firmware type (BIOS/EFI)'
        # Version           = 'VM hardware version'
        # CreateDate        = 'VM creation date'
    }

    # Advanced Settings
    
    # Output Configuration
    OutputPath              = '.\output'                            # Directory for generated Excel files
    LogsPath                = '.\logs'                              # Directory for log files
    
    # Performance Settings  
    ConnectionTimeout       = 300                                   # vCenter connection timeout (seconds)
    BatchSize               = 100                                   # VM processing batch size
    
    # Reporting Options
    IncludeMetadata         = $true                                 # Include metadata sheet in Excel
    TimestampFormat         = 'yyyyMMdd_HHmmss'                     # File timestamp format
    
    # Filtering Options (Future Enhancement)
    # ExcludePoweredOff     = $false                                # Skip powered-off VMs
    # IncludeTemplates      = $false                                # Include VM templates
    # MinMemoryMB           = 0                                     # Minimum memory filter
    # ExcludeAnnotationPattern = 'Test*'                            # Exclude VMs matching pattern
    
    # Filtering options (optional)
    Filters                 = @{
        # Only include VMs with these power states (optional)
        # PowerStates  = @('PoweredOn', 'PoweredOff', 'Suspended')
        PowerStates  = @('PoweredOn')                               # Example: Only powered-on VMs
        
        # Exclude VMs matching these name patterns (optional)
        ExcludeNames = @('*!ARCHIVE*')                              # Example: @('*template*', '*test*', '*!ARCHIVE*')
        
        # Only include VMs matching these name patterns (optional)
        IncludeNames = @()                                          # Example: @('*prod*', '*server*')
    }

    # Email Notification Settings (Optional - requires Microsoft Graph API setup)
    # Used by VirtToolkit.GraphEmail module for automated report delivery
    EmailNotification       = @{
        Enabled           = $false                                   # Set to $true to enable email notifications
        
        # Microsoft Graph API Authentication
        TenantId          = ''                                       # Azure AD Tenant ID (GUID)
        ClientId          = ''                                       # Azure AD Application (Client) ID (GUID)
        
        # Client Secret Management
        # Option 1: Store secret name in vault (recommended for security)
        ClientSecretName  = 'MicrosoftGraph-ClientSecret'            # Name of secret stored in SecretVault
        
        # Option 2: Direct client secret (NOT RECOMMENDED - use vault instead)
        # ClientSecret   = ''                                       # Direct secret (leave empty to use vault)
        
        # Email Configuration
        From              = 'vmreports@contoso.com'                  # Sender email address (must have SendAs permission)
        To                = @(                                       # Array of recipient email addresses
            'admin@contoso.com'
            'team@contoso.com'
        )
        Subject           = 'VM Inventory Report - {{DATE}}'         # Email subject ({{DATE}} will be replaced with timestamp)
        
        # Email Body Template
        BodyTemplate      = @'
VM Inventory Report

Report Generated: {{DATE}}
vCenter Server: {{SERVER}}
Total VMs: {{COUNT}}

The attached Excel file contains the complete VM inventory report.

This is an automated report from VirtToolkit.
'@                                                                  # Email body template (supports {{DATE}}, {{SERVER}}, {{COUNT}} placeholders)
        
        # Attachment Settings
        IncludeAttachment = $true                                   # Attach the generated Excel file to email
        AttachmentName    = 'VM-Inventory-{{DATE}}.xlsx'            # Attachment filename ({{DATE}} will be replaced)
    }
}

# ═══════════════════════════════════════════════════════════
# Configuration Guide and Notes
# ═══════════════════════════════════════════════════════════
# 
# 1. REQUIRED SETTINGS:
#    - SourceServerHost: Your vCenter server FQDN or IP
#    - dataCenter: Exact datacenter name as shown in vCenter
#    - VMFolder: Folder path containing VMs to analyze
#
# 2. CREDENTIAL SETUP:
#    - Credentials are stored securely and reused automatically
#    - Use preferredVault and CredentialName if you have existing SecretManagement setup
#
# 3. DRY RUN MODE:
#    - Set DryRun = $true for testing (shows sample data, no Excel file)
#    - Set DryRun = $false for production (generates actual Excel report)
#
# 4. VM PROPERTIES:
#    - VMProperties is now a hashtable with property names as keys and descriptions as values
#    - Include only properties you need to reduce processing time
#    - The hashtable format provides better documentation and flexibility
#    - Example:
#      VMProperties = @{
#          Name       = 'VM Display Name'
#          PowerState = 'Current Power State'
#          NumCPU     = 'Number of vCPUs'
#      }
#
# 5. VM FOLDER:
#    - VMFolder expects the folder NAME (not path)
#    - PowerCLI's Get-VM -Location parameter works with folder names
#    - Examples:
#      VMFolder = 'vm'                              # Root VM folder
#      VMFolder = 'Production'                      # Production folder
#      VMFolder = 'VDI'                             # VDI folder
#      VMFolder = 'Discovered virtual machine'      # Special folder (good for testing)
#    - Note: For nested folders with same names, you may need to use Get-Folder first
#
# 6. FILTERING:
#    - PowerStates: Filter by VM power state (@('PoweredOn'), @('PoweredOff'), etc.)
#    - ExcludeNames: Exclude VMs matching wildcard patterns (@('*template*', '*!ARCHIVE*'))
#    - IncludeNames: Include only VMs matching wildcard patterns (@('*prod*', '*web*'))
#
# 7. EMAIL NOTIFICATIONS (OPTIONAL):
#    - Requires Microsoft Graph API setup in Azure AD
#    - Set EmailNotification.Enabled = $true to activate
#    
#    Azure AD Application Setup:
#    a) Register new application in Azure AD portal
#    b) Grant API permissions: Mail.Send, Mail.ReadWrite
#    c) Create client secret and note the value
#    d) Store secret securely:
#       Set-Secret -Name 'GraphAPI-ClientSecret' -Secret 'your-secret-value' -Vault 'VCenterVault'
#    e) Configure sender mailbox with SendAs permissions for the app
#    
#    Configuration example:
#    EmailNotification = @{
#        Enabled          = $true
#        TenantId         = '12345678-1234-1234-1234-123456789abc'
#        ClientId         = '87654321-4321-4321-4321-cba987654321'
#        ClientSecretName = 'GraphAPI-ClientSecret'
#        From             = 'vmreports@contoso.com'
#        To               = @('admin@contoso.com', 'team@contoso.com')
#        Subject          = 'VM Inventory Report - {{DATE}}'
#    }
#    
#    Template placeholders supported:
#    - {{DATE}}: Replaced with current timestamp
#    - {{SERVER}}: Replaced with vCenter server name
#    - {{COUNT}}: Replaced with total VM count
#
# 7. REQUIRED POWERSHELL MODULES:
#    Core modules (always required):
#    - VMware.PowerCLI (>= 13.0.0)
#    - Microsoft.PowerShell.SecretManagement (>= 1.1.0)
#    - Microsoft.PowerShell.SecretStore (>= 1.0.0)
#    - ImportExcel (>= 7.0.0)
#    
#    Optional modules (for email notifications):
#    - Microsoft.Graph.Authentication (>= 2.0.0)
#    - Microsoft.Graph.Users.Actions (>= 2.0.0)
#    
#    Install commands:
#    Install-Module VMware.PowerCLI -Scope CurrentUser
#    Install-Module Microsoft.PowerShell.SecretManagement -Scope CurrentUser
#    Install-Module Microsoft.PowerShell.SecretStore -Scope CurrentUser
#    Install-Module ImportExcel -Scope CurrentUser
#    Install-Module Microsoft.Graph.Authentication -Scope CurrentUser  # Optional
#    Install-Module Microsoft.Graph.Users.Actions -Scope CurrentUser  # Optional