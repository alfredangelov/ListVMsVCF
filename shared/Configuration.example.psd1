# VM Listing Toolkit - Example Configuration

# This is an example configuration file showing all available options.
# Copy this to Configuration.psd1 and customize for your environment.
# 
# Quick Start:
# 1. Copy this file: Copy-Item Configuration.example.psd1 Configuration.psd1
# 2. Edit Configuration.psd1 with your environment details (vCenter, datacenter, folder)
# 3. Run: .\scripts\Initialize-Environment.ps1
# 4. Run: .\scripts\List-VMs.ps1

@{
    # ═══════════════════════════════════════════════════════════
    # VM Listing Toolkit Configuration
    # ═══════════════════════════════════════════════════════════
    
    # Core Settings
    # If $true, shows sample data without creating Excel files (safe for testing)
    # Set to $false to generate actual Excel reports
    DryRun                = $true

    # vSphere Connection Settings
    # Compatible with both standard vSphere and VMware Cloud Foundation (VCF) environments
    SourceServerHost      = 'your-vcenter-server.company.com'  # vCenter FQDN or IP (works with VCF vCenter instances)
    vCenterVersion        = '7.0'                               # vCenter version (6.7, 7.0, 8.0) - VCF versions supported
    
    # Secure Credential Management
    # These settings control how credentials are stored and retrieved
    preferredVault        = 'VCenterVault'                      # Secret vault name for credential storage
    CredentialName        = 'SourceCred'                        # Name of the stored credential

    # SSL Certificate handling (useful for ESXi hosts with self-signed certificates)
    IgnoreSSLCertificates = $true                           # Set to $false for production vCenter with valid certificates

    # Network environment settings
    # Set to $true if running from networks with SSL inspection (Zscaler, etc.)
    NetworkHasSSLInspection = $true                         # Enables additional SSL compatibility measures
    
    # Note: During initialization, you'll be prompted to enter credentials once.
    # They'll be securely stored and automatically used for future connections.

    # vSphere Environment Settings
    dataCenter = 'YourDatacenter'                               # Target datacenter name
    VMFolder = 'YourFolder/SubFolder'                           # VM folder path to analyze
    
    # Example folder paths:
    # VMFolder = 'vm'                                           # Root VM folder
    # VMFolder = 'Production/Web Servers'                       # Nested folder structure  
    # VMFolder = 'Discovered virtual machine'                   # Special folder (good for testing)

    # VM Properties to Export
    # Customize this list to include only the properties you need
    VMProperties = @(
        'Name',                    # VM Display Name
        'UUID',                    # Unique VM Identifier  
        'DNSName',                 # VM DNS Name
        'PowerState',              # Current Power State (PoweredOn, PoweredOff, Suspended)
        'GuestOS',                 # Guest Operating System
        'NumCPU',                  # Number of vCPUs
        'MemoryMB',                # Memory allocation in MB
        'ProvisionedSpaceGB',      # Total provisioned storage in GB
        'UsedSpaceGB',             # Actual used storage in GB
        'Datastore',               # Primary datastore name
        'NetworkAdapters',         # Network adapter information
        'IPAddresses',             # VM IP addresses
        'Annotation',              # VM notes/comments
        'HostSystem',              # ESXi host running the VM
        'VMToolsVersion',          # VMware Tools version
        'VMToolsStatus',           # VMware Tools status
        'Folder'                   # VM folder location
        
        # Additional available properties (uncomment as needed):
        # 'ResourcePool',          # Resource pool assignment
        # 'HARestartPriority',     # HA restart priority
        # 'HAIsolationResponse',   # HA isolation response
        # 'DRSAutomationLevel',    # DRS automation level
        # 'BootDelayTime',         # Boot delay in milliseconds
        # 'FirmwareType',          # Firmware type (BIOS/EFI)
        # 'Version',               # VM hardware version
        # 'CreateDate',            # VM creation date
        # 'ChangeVersion',         # VM change version
        # 'GuestFamily',           # Guest OS family
        # 'GuestFullName'          # Full guest OS name
    )

    # Advanced Settings (Optional)
    
    # Output Configuration
    OutputPath = '.\output'                                     # Directory for generated Excel files
    
    # Performance Settings  
    ConnectionTimeout = 300                                     # vCenter connection timeout (seconds)
    BatchSize = 100                                             # VM processing batch size
    
    # Reporting Options
    IncludeMetadata = $true                                     # Include metadata sheet in Excel
    TimestampFormat = 'yyyyMMdd_HHmmss'                        # File timestamp format
    
    # Filtering Options (Future Enhancement)
    # ExcludePoweredOff = $false                                # Skip powered-off VMs
    # IncludeTemplates = $false                                 # Include VM templates
    # MinMemoryMB = 0                                           # Minimum memory filter
    # ExcludeAnnotationPattern = 'Test*'                       # Exclude VMs matching pattern
    
    # Filtering options (optional)
    Filters = @{
        # Only include VMs with these power states (optional)
        PowerStates = @('PoweredOn', 'PoweredOff', 'Suspended')
        
        # Exclude VMs matching these name patterns (optional)
        ExcludeNames = @()  # Example: @('*template*', '*test*')
        
        # Only include VMs matching these name patterns (optional)
        IncludeNames = @()  # Example: @('*prod*', '*server*')
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
#    - Run .\scripts\Initialize-Environment.ps1 first
#    - Credentials are stored securely and reused automatically
#    - Use preferredVault and CredentialName if you have existing SecretManagement setup
#
# 3. DRY RUN MODE:
#    - Set DryRun = $true for testing (shows sample data, no Excel file)
#    - Set DryRun = $false for production (generates actual Excel report)
#
# 4. VM PROPERTIES:
#    - Include only properties you need to reduce processing time
#    - Full list of available properties documented in README.md
#
# 5. FOLDER PATHS:
#    - Use .\scripts\Toolkit-Utilities.ps1 -Action ListFolders to explore
#    - 'Discovered virtual machine' is good for testing (usually has few VMs)
#
# 6. TESTING WORKFLOW:
#    a) Copy this file: Copy-Item Configuration.example.psd1 Configuration.psd1
#    b) Edit Configuration.psd1 with your environment details (vCenter, datacenter, VM folder)
#    c) Initialize: .\scripts\Initialize-Environment.ps1 (reads config for vault/credential names)
#    d) Test connectivity: .\scripts\Toolkit-Utilities.ps1 -Action TestConnection
#    e) Test with small folder: Set VMFolder = 'Discovered virtual machine'
#    f) Run with DryRun = $true first to validate
#    g) Set DryRun = $false for actual Excel generation
#
# 7. COMMON FOLDER EXAMPLES:
#    VMFolder = 'vm'                              # Root VM folder
#    VMFolder = 'Datacenter/vm'                   # Default VM folder
#    VMFolder = 'Production/Web Servers'          # Nested folders
#    VMFolder = 'Discovered virtual machine'     # Special folder (good for testing)
#    VMFolder = 'vCloud Director'                 # vCloud Director VMs
#
# 8. TROUBLESHOOTING:
#    - Check status: .\scripts\Toolkit-Utilities.ps1 -Action Status
#    - List folders: .\scripts\Toolkit-Utilities.ps1 -Action ListFolders
#    - Test connection: .\scripts\Toolkit-Utilities.ps1 -Action TestConnection
#    - Review README.md for detailed troubleshooting guide
