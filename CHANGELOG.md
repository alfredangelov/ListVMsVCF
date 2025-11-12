# Changelog

All notable changes to the VirtToolkit project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-11-12

### Added

#### Production Scripts

- **Get-vSphereVMInventory.ps1** - Main production script for vCenter/vSphere VM inventory
  - Connects to vCenter and retrieves VMs from specified folder
  - Configurable VM property retrieval (17+ properties supported)
  - Three-tier filtering system (PowerState, ExcludeNames, IncludeNames)
  - Excel export with metadata sheet
  - Optional email delivery via Microsoft Graph API
  - Comprehensive logging with multiple log levels
  - DryRun mode for testing configurations
  - Parameters: `-ConfigPath`, `-SkipEmail`

- **Get-ESXiVMInventory.ps1** - Production script for ESXi host VM inventory
  - Direct connection to ESXi hosts
  - Retrieves all VMs on specified host
  - Same filtering, export, and email capabilities as vSphere script
  - ESXi-specific metadata (version, build)
  - Parameters: `-ESXiHost`, `-ConfigPath`, `-SkipEmail`

#### Utility Scripts

- **Initialize-Environment.ps1** - Automated module installation
  - Checks for and installs required PowerShell modules
  - Validates minimum versions
  - Supports both user and system-wide installation

- **Manage-VirtToolkitSecrets.ps1** - Comprehensive credential management
  - Multiple modes: Initialize, Update, List, Verify, Remove, Clean
  - Standardized credential naming convention: `vSphere-{hostname}-{username}`
  - Integration with PowerShell SecretManagement and SecretStore
  - Interactive credential input and verification
  - Bulk credential management

#### PowerShell Modules

- **VirtToolkit.Credentials.psm1** - Secure credential management
  - `Get-VirtToolkitCredential`: Retrieve stored credentials
  - `Get-VirtToolkitServerCredentials`: Get all credentials for a server
  - Automatic credential discovery by username preference
  - Support for scheduled execution (no vault unlock prompt)

- **VirtToolkit.Excel.psm1** - Excel export functionality
  - `Export-VirtToolkitExcel`: Create formatted Excel reports
  - Dual-sheet format: VM Inventory + Metadata
  - Automatic column sizing and table formatting
  - Custom metadata support for report context
  - Uses ImportExcel module

- **VirtToolkit.GraphEmail.psm1** - Email notifications via Microsoft Graph
  - `Send-VirtToolkitGraphEmail`: Send emails with attachments
  - Azure AD application authentication
  - Template placeholder support ({{DATE}}, {{SERVER}}, {{COUNT}})
  - Attachment size validation (3MB limit)
  - Base64 encoding for attachments

- **VirtToolkit.Logging.psm1** - Unified logging system
  - `Write-VirtToolkitLog`: Write structured log entries
  - Multiple log levels: INFO, SUCCESS, WARN, ERROR
  - Dual output: console + file
  - Automatic log directory creation
  - Timestamped log files

#### Configuration System

- **Configuration.psd1** - Main configuration file
  - Hashtable-based VMProperties structure for better documentation
  - Server connection settings (SourceServerHost, credentials)
  - VM folder configuration (folder name, not path)
  - Output path and DryRun mode settings
  - Comprehensive filtering options (PowerState, name patterns)
  - Email notification configuration (Microsoft Graph)
  - Credential vault settings

- **Configuration.example.psd1** - Template configuration
  - Detailed documentation for all settings
  - Example configurations for common scenarios
  - Section-based organization for readability
  - Filtering examples with multiple patterns
  - Email template examples

#### Test Scripts

- **Test-VSphereConnectivity.ps1** - vCenter connectivity testing
  - Validates vCenter connection using stored credentials
  - Tests credential retrieval with server-centric pattern
  - Retrieves basic datacenter information
  - Verifies clean connection/disconnection lifecycle
  - Logs all operations for troubleshooting

- **Test-ESXiConnectivity.ps1** - ESXi host connectivity testing
  - Direct ESXi host connection validation
  - Optional ESXi host parameter or interactive prompt
  - Tests credential retrieval and authentication
  - Retrieves basic host information
  - Verifies connection lifecycle management
  - Comprehensive logging

- **Test-ExcelExport.ps1** - Excel export functionality testing
  - Test 1: Basic Excel export with sample data
  - Test 2: Configuration file parsing
  - Test 3: VM property hashtable structure validation
  - Test 4: Full production workflow simulation
  - Detailed progress reporting and validation
  - Support for running individual or all tests

- **Test-GraphEmail.ps1** - Email functionality testing
  - Microsoft Graph authentication validation
  - Email sending with attachments
  - Template placeholder testing
  - Configuration-based test parameters

#### Documentation

- **README.md** - Comprehensive project documentation
  - Feature overview and capabilities
  - Prerequisites and installation instructions
  - Quick start guide
  - Detailed configuration guide
  - Usage examples for all scripts
  - VM properties reference
  - Filtering guide with examples
  - Email notification setup
  - Credential management guide
  - Troubleshooting section
  - Project structure overview

#### Features

- **VM Property Retrieval**: 17+ configurable VM properties
  - Basic: Name, UUID, DNSName, PowerState, GuestOS
  - Resources: NumCPU, MemoryMB, ProvisionedSpaceGB, UsedSpaceGB
  - Storage: Datastore (comma-separated list)
  - Network: NetworkAdapters, IPAddresses (IPv4 filtered)
  - Tools: VMToolsVersion, VMToolsStatus
  - Location: HostSystem, Folder
  - Metadata: Annotation (notes/comments)

- **Advanced Filtering**
  - PowerState filtering (PoweredOn, PoweredOff, Suspended)
  - Exclude patterns with wildcard support
  - Include patterns with wildcard support
  - Sequential filter application with statistics
  - Logging of filter results

- **Excel Export Features**
  - Professional formatting with tables
  - Auto-sized columns for readability
  - Metadata sheet with report context
  - Timestamped filenames
  - Configurable output directory

- **Email Notifications**
  - Microsoft Graph API integration
  - Azure AD application authentication
  - Attachment support (Excel reports)
  - Template-based subject and body
  - Multiple recipients support
  - Optional delivery (can be skipped via parameter)

- **Credential Management**
  - Secure storage with PowerShell SecretManagement
  - Multiple credentials per server support
  - Username preference configuration
  - Interactive credential update
  - Credential verification against vSphere/ESXi
  - Scheduled execution support (no unlock prompt)

- **Logging System**
  - Separate log files per script execution
  - Multiple log levels (INFO, SUCCESS, WARN, ERROR)
  - Color-coded console output
  - Detailed operation tracking
  - Error context and stack traces

- **DryRun Mode**
  - Test configurations without file generation
  - Display sample data and settings
  - Validate filters and property selections
  - No credentials required

### Changed

- Configuration structure refactored from array to hashtable for VMProperties
  - Keys: Property names (e.g., "Name", "UUID")
  - Values: Property descriptions (e.g., "VM Display Name")
  - Benefits: Better documentation, extensibility, self-describing configuration

- VMFolder setting simplified to use folder name instead of path
  - Old: `VMFolder = 'COMPANY/VDI'` (path format)
  - New: `VMFolder = 'VDI'` (folder name only)
  - Aligns with PowerCLI's `Get-VM -Location` parameter expectations

### Fixed

- Email function name mismatch in production scripts
  - Issue: Scripts called `Send-VirtToolkitEmail` (incorrect name)
  - Fix: Updated to `Send-VirtToolkitGraphEmail` (correct function name)
  - Affected files: Get-vSphereVMInventory.ps1, Get-ESXiVMInventory.ps1

- Test scripts updated to work with hashtable configuration structure
  - Test-ExcelExport.ps1 Test 2: Property enumeration with descriptions
  - Test-ExcelExport.ps1 Test 4: Metadata property list generation

### Technical Details

#### Module Dependencies

- VMware.PowerCLI >= 13.0.0
- Microsoft.PowerShell.SecretManagement >= 1.1.0
- Microsoft.PowerShell.SecretStore >= 1.0.0
- ImportExcel >= 7.0.0
- Microsoft.Graph.Authentication >= 2.0.0 (optional, for email)
- Microsoft.Graph.Users.Actions >= 2.0.0 (optional, for email)

#### Compatibility

- PowerShell 5.1+
- PowerShell 7.x
- VMware vSphere 6.7, 7.0, 8.0+
- VMware Cloud Foundation (VCF)
- Windows OS (primary development platform)
- Cross-platform support for PowerShell 7 on Linux/macOS (not fully tested)

#### Security Features

- Credentials stored encrypted in PowerShell SecretStore
- No plaintext passwords in configuration files
- Azure AD application authentication for email
- Client secrets stored in credential vault
- SSL certificate validation (configurable)

#### Performance Considerations

- Sequential VM property retrieval (reliable but can be slow for large inventories)
- Filter statistics tracked and logged
- Automatic disconnection from vCenter/ESXi after operation
- Log file size management through timestamped files

### Known Limitations

- Excel files limited to ImportExcel module capabilities
- Email attachment size limited to 3MB (Microsoft Graph restriction)
- Sequential property retrieval (no parallel processing)
- Folder name conflicts require manual folder object resolution
- Windows-focused (PowerShell 7 cross-platform support not fully validated)

### Migration Notes

If upgrading from internal development versions:

1. Update Configuration.psd1 to use hashtable format for VMProperties
2. Change VMFolder to use folder name instead of path
3. Verify email function name in any custom scripts
4. Test filters with new sequential application order
5. Review and update credential names if using custom patterns

## [Unreleased]

### Planned Features

- Support for multiple vCenter connections in single execution
- HTML report generation alongside Excel
- Custom property mapping and calculated fields
- Scheduled task automation helper script
- Advanced filtering with regex support
- Export to CSV and JSON formats
- Performance metrics collection
- Storage analytics reporting
- Parallel property retrieval for better performance
- Custom Excel themes and formatting options
- Report history and comparison features

---

## Release Notes

### Version 1.0.0 - Initial Release

This is the first public release of VirtToolkit. The toolkit has been developed and tested internally against VMware vSphere 7.0 and 8.0 environments with successful production usage. All core features are functional and tested:

✅ vSphere/vCenter VM inventory  
✅ ESXi host VM inventory  
✅ Advanced filtering (PowerState, name patterns)  
✅ Excel export with metadata  
✅ Email notifications via Microsoft Graph  
✅ Secure credential management  
✅ Comprehensive logging  
✅ DryRun mode for testing  

**Tested Environments:**

- vSphere 7.0 and 8.0
- VMware Cloud Foundation
- PowerShell 5.1 and 7.4
- Windows Server 2019, 2022
- Windows 10, 11

**Known Working Scenarios:**

- vCenter with folder-based VM retrieval
- Direct ESXi host connections
- Multiple credentials per server
- Email delivery with Excel attachments
- All 17 VM properties retrieval
- Complex filter combinations

For issues, feature requests, or contributions, please use the GitHub repository.
