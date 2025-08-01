# VM Listing Toolkit for vCenter Foundation (VCF)

A comprehensive PowerShell toolkit for listing virtual machines from vSphere/vCenter environments and exporting the data to Excel with custom formatting.

## Features

- **Environment Validation**: Automatically checks PowerShell version and required modules
- **Module Installation**: Installs missing PowerShell modules with proper error handling
- **vSphere Connectivity**: Secure connection to vCenter servers with credential management
- **VM Data Collection**: Retrieves comprehensive VM properties from specified folders
- **Excel Export**: Creates professionally formatted Excel files with custom headers
- **Dry Run Mode**: Test operations without making changes
- **Utility Functions**: Additional tools for testing connections and exploring folder structures

## Prerequisites

- PowerShell 5.1 or higher
- Network access to vCenter server
- Appropriate vSphere permissions to read VM information

## Required Modules

The toolkit will automatically install these modules if missing:

- **VMware.PowerCLI** (≥13.0.0) - vSphere connectivity
- **Microsoft.PowerShell.SecretManagement** (≥1.1.0) - Credential management
- **Microsoft.PowerShell.SecretStore** (≥1.0.0) - Secure credential storage
- **ImportExcel** (≥7.0.0) - Excel file generation

## Quick Start

1. **Initialize Environment** (first time setup):

   ```powershell
   .\scripts\Initialize-Environment.ps1
   ```

2. **Configure Settings** (edit `shared\Configuration.psd1`):
   - Update `SourceServerHost` with your vCenter server
   - Set `dataCenter` to your datacenter name
   - Configure `VMFolder` path
   - Customize `VMProperties` as needed

3. **List VMs**:

   ```powershell
   .\scripts\List-VMs.ps1
   ```

## Configuration

Edit `shared\Configuration.psd1` to customize:

```powershell
@{
    # Core Settings
    DryRun                = $true          # Set to $false for actual execution
    SourceServerHost      = 'your-vcenter.company.com'
    vCenterVersion        = '6.7'
    dataCenter           = 'YourDatacenter'
    VMFolder             = 'YourFolder/SubFolder'
    
    # VM Properties to export
    VMProperties = @(
        'Name', 'UUID', 'DNSName', 'PowerState', 'GuestOS',
        'NumCPU', 'MemoryMB', 'ProvisionedSpaceGB', 'UsedSpaceGB',
        'Datastore', 'NetworkAdapters', 'IPAddresses', 'Annotation',
        'HostSystem', 'VMToolsVersion', 'VMToolsStatus', 'Folder'
    )
}
```

## Scripts

### Core Scripts

- **`Initialize-Environment.ps1`** - Environment setup and module installation
- **`List-VMs.ps1`** - Main VM listing and Excel export script
- **`Toolkit-Utilities.ps1`** - Utility functions for testing and exploration

### Usage Examples

```powershell
# Initialize environment (run once)
.\scripts\Initialize-Environment.ps1

# List VMs with default configuration
.\scripts\List-VMs.ps1

# Test mode (dry run)
.\scripts\List-VMs.ps1 -DryRun

# Custom configuration file
.\scripts\List-VMs.ps1 -ConfigPath ".\custom-config.psd1"

# Custom output directory
.\scripts\List-VMs.ps1 -OutputPath "C:\Reports"

# Check environment status
.\scripts\Toolkit-Utilities.ps1 -Action Status

# Test vCenter connection
.\scripts\Toolkit-Utilities.ps1 -Action TestConnection

# List available VM folders
.\scripts\Toolkit-Utilities.ps1 -Action ListFolders
```

## Modules

The toolkit includes reusable PowerShell modules:

### EnvironmentValidator.psm1

- PowerShell version validation
- Module dependency checking
- Automated module installation

### vSphereConnector.psm1

- vCenter connection management
- VM data retrieval
- Folder navigation

### ExcelExporter.psm1

- Excel file generation
- Custom formatting and headers
- Metadata inclusion

## Excel Output Format

The generated Excel file includes:

1. **First Header Row**: Combined header showing vCenter server, datacenter, and folder path
2. **Second Header Row**: Column names for VM properties
3. **Data Rows**: VM information with "NULL" for missing values
4. **Metadata Sheet**: Export details and summary information

## Directory Structure

``` Plain text
ListVMsVCF/
├── scripts/
│   ├── Initialize-Environment.ps1
│   ├── List-VMs.ps1
│   └── Toolkit-Utilities.ps1
├── modules/
│   ├── EnvironmentValidator.psm1
│   ├── vSphereConnector.psm1
│   └── ExcelExporter.psm1
├── shared/
│   └── Configuration.psd1
├── output/
│   └── (Generated Excel files)
└── README.md
```

## Security & Credential Management

The toolkit provides secure credential management using PowerShell SecretManagement:

### Automatic Credential Storage

- **First Run**: During environment initialization, you'll be prompted to store vCenter credentials
- **Secure Storage**: Credentials are encrypted and stored using Microsoft.PowerShell.SecretStore
- **Reusable**: Once stored, credentials are automatically used for subsequent connections
- **Vault Integration**: Uses existing secret vaults to minimize credential entry

### Credential Features

- **Multiple Vault Support**: Can use existing secret vaults from other projects
- **Automatic Detection**: Finds and uses stored credentials automatically
- **Fallback Prompting**: Prompts for credentials if none are stored
- **Secure Storage**: All credentials are encrypted at rest
- **User-Scoped**: Credentials are stored per user account

### Manual Credential Management

```powershell
# Check credential status
.\scripts\Toolkit-Utilities.ps1 -Action Status

# Set up credentials manually (if needed)
Initialize-VCenterCredentials -ServerHost "your-vcenter.company.com" -CredentialName "SourceCred"

# Test stored credentials
Test-StoredCredential -CredentialName "SourceCred"
```

## Error Handling

The toolkit includes comprehensive error handling:

- Connection failures are logged and reported
- Missing permissions are identified
- Module installation issues are resolved automatically
- All vSphere connections are properly cleaned up

## Security

- Credentials are prompted securely when needed
- No passwords are stored in configuration files
- Uses PowerShell SecretManagement for credential storage
- Supports Windows authentication where available

## Troubleshooting

### Common Issues

1. **Module Installation Fails**:
   - Run PowerShell as Administrator
   - Check internet connectivity
   - Verify PowerShell execution policy

2. **vCenter Connection Issues**:
   - Verify server hostname/IP
   - Check network connectivity
   - Confirm vSphere permissions
   - Test with `.\scripts\Toolkit-Utilities.ps1 -Action TestConnection`

3. **Folder Not Found**:
   - Use `.\scripts\Toolkit-Utilities.ps1 -Action ListFolders` to see available folders
   - Check datacenter name in configuration
   - Verify folder path format

4. **Excel Export Fails**:
   - Ensure output directory is writable
   - Check available disk space
   - Verify ImportExcel module installation

### Getting Help

Use the utility script for diagnostics:

```powershell
# Check overall status
.\scripts\Toolkit-Utilities.ps1 -Action Status

# Test connections
.\scripts\Toolkit-Utilities.ps1 -Action TestConnection

# Explore folder structure
.\scripts\Toolkit-Utilities.ps1 -Action ListFolders

# Show help
.\scripts\Toolkit-Utilities.ps1 -Action Help
```

## Contributing

This toolkit is designed to be modular and extensible.

## License

Internal use toolkit - please follow your organization's software usage policies.
