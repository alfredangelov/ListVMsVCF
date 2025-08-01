# VM Listing Toolkit - Example Configuration

# This is an example configuration file showing all available options.
# Copy this to Configuration.psd1 and customize for your environment.

@{
    # ═══════════════════════════════════════════════════════════
    # VM Listing Toolkit Configuration
    # ═══════════════════════════════════════════════════════════
    
    # Core Settings
    # If $true, actions will be simulated and no changes will be made
    DryRun                = $true

    # vSphere source server connection details
    SourceServerHost      = 'your-vcenter-server.company.com'
    vCenterVersion        = '7.0'  # vCenter version (affects API endpoint availability)

    # Datacenter name for object-level permissions
    dataCenter = 'YourDatacenter'

    # Folder to analyze VMs in
    VMFolder = 'YourFolder/SubFolder'

    # Which VM properties to show in the output
    VMProperties = @(
        'Name',
        'UUID',
        'DNSName',
        'PowerState',
        'GuestOS',
        'NumCPU',
        'MemoryMB',
        'ProvisionedSpaceGB',
        'UsedSpaceGB',
        'Datastore',
        'NetworkAdapters',
        'IPAddresses',
        'Annotation',
        'HostSystem',
        'VMToolsVersion',
        'VMToolsStatus',
        'Folder'
    )

    # Additional optional settings
    
    # Output settings
    OutputPath = '.\output'  # Directory for Excel files
    
    # Excel formatting options
    ExcelOptions = @{
        AutoSize = $true
        FreezeTopRow = $true
        BoldHeaders = $true
        AddMetadataSheet = $true
    }
    
    # Connection settings
    ConnectionTimeout = 300  # Seconds
    
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
