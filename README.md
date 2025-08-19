# VM Listing Toolkit for vCenter Foundation (VCF)

A comprehensive PowerShell toolkit for listing virtual machines from vSphere/vCenter environments and exporting the data to Excel with custom formatting. Features complete environment initialization, secure credential management, and configuration-driven automation.

## 🌟 Key Features

- **🚀 One-Command Setup**: Automated environment initialization with dependency management
- **🔒 Secure Credential Management**: Automatic vault creation and encrypted credential storage
- **⚙️ Configuration-Driven**: All settings centralized in configuration files
- **📊 Professional Excel Export**: Dual-header format with metadata and server-aware filenames
- **🔍 Environment Validation**: Comprehensive PowerShell and module dependency checking
- **🌐 Dual Connectivity**: Support for both vCenter and direct ESXi host connections
- **📁 Smart Folder Management**: Intelligent folder validation and VM discovery
- **🧪 Dry Run Mode**: Safe testing without making changes
- **🛠️ Utility Functions**: Built-in tools for diagnostics and exploration
- **🔐 SSL Compatibility**: Configurable SSL certificate handling for various network environments
- **🏢 VCF Support**: Optional VMware Cloud Foundation module integration

## 📋 Prerequisites

- **PowerShell 5.1** or higher (PowerShell 7+ recommended)
- **Network access** to vCenter server
- **vSphere permissions** to read VM information
- **Windows PowerShell** or **PowerShell Core**

## 📦 Required Modules

The toolkit automatically installs these modules during initialization:

| Module | Min Version | Purpose |
|--------|-------------|---------|
| **VMware.PowerCLI** | ≥13.0.0 | vSphere connectivity and VM data retrieval |
| **Microsoft.PowerShell.SecretManagement** | ≥1.1.0 | Secure credential management framework |
| **Microsoft.PowerShell.SecretStore** | ≥1.0.0 | Encrypted credential storage backend |
| **ImportExcel** | ≥7.0.0 | Professional Excel file generation |

## 🔧 Optional Modules

The following modules can be installed for enhanced functionality:

| Module | Min Version | Purpose | Auto-Install |
|--------|-------------|---------|--------------|
| **VCF.PowerCLI** | ≥1.0.0 | VMware Cloud Foundation support | Prompted during setup |

**Note**: The toolkit works with both standard vSphere and VCF environments. The VCF.PowerCLI module is only needed for advanced VCF-specific features and is not required for basic VM listing functionality.

## 🚀 Quick Start Guide

### 1. **Configuration Setup** (First - Required)

Copy and customize the configuration template:

```powershell
# Copy the example configuration
Copy-Item .\shared\Configuration.example.psd1 .\shared\Configuration.psd1

# Edit the configuration file with your environment details
notepad .\shared\Configuration.psd1
```

**Required settings to configure:**

- `SourceServerHost` - Your vCenter server FQDN or IP
- `dataCenter` - Exact datacenter name as shown in vCenter  
- `VMFolder` - VM folder path to analyze
- `preferredVault` and `CredentialName` - Credential storage settings

### 2. **Environment Initialization** (Second - One Time Setup)

Run the initialization script after configuring your settings:

```powershell
.\scripts\Initialize-Environment.ps1
```

This command will:

- ✅ Validate PowerShell version
- ✅ Install missing modules
- ✅ Create secure credential vault using your configured vault name
- ✅ Prompt for and store vCenter credentials under your configured credential name
- ✅ Validate the complete setup

### 3. **Configuration Reference**

Example `shared\Configuration.psd1` settings:

```powershell
@{
    # Core Settings
    DryRun                = $false                           # Set to $false for actual Excel export
    
    # vSphere Connection
    SourceServerHost      = 'your-vcenter.company.com'      # Your vCenter server
    vCenterVersion        = '6.7'                            # vCenter version
    dataCenter           = 'YourDatacenter'                 # Target datacenter
    VMFolder             = 'YourFolder/SubFolder'           # VM folder path
    
    # Credential Management
    preferredVault        = 'VCenterVault'                  # Secret vault name
    CredentialName        = 'SourceCred'                    # Stored credential name
    
    # SSL Certificate handling (useful for ESXi hosts with self-signed certificates)
    IgnoreSSLCertificates = $true                           # Set to $false for production vCenter with valid certificates
    
    # Network environment settings  
    # Set to $true if running from networks with SSL inspection (Zscaler, etc.)
    NetworkHasSSLInspection = $true                         # Enables additional SSL compatibility measures
    
    # Export Properties
    VMProperties = @(
        'Name', 'UUID', 'DNSName', 'PowerState', 'GuestOS',
        'NumCPU', 'MemoryMB', 'ProvisionedSpaceGB', 'UsedSpaceGB',
        'Datastore', 'NetworkAdapters', 'IPAddresses', 'Annotation',
        'HostSystem', 'VMToolsVersion', 'VMToolsStatus', 'Folder'
    )
}
```

### 4. **Run VM Listing**

Execute the main script to list VMs and generate Excel output:

```powershell
.\scripts\List-VMs.ps1
```

## 📖 Detailed Usage

### Script Reference

| Script | Purpose | Usage |
|--------|---------|-------|
| **`Initialize-Environment.ps1`** | Complete environment setup and credential management | Run once for initial setup |
| **`List-VMs.ps1`** | Main VM listing and Excel export functionality | Primary script for VM data collection from vCenter |
| **`List-VMs-esxi.ps1`** | ESXi host VM listing and Excel export | Direct ESXi host VM data collection |
| **`Toolkit-Utilities.ps1`** | Diagnostic and utility functions | Testing, status checks, and exploration |
| **`Quick-CredentialUpdate.ps1`** | Quick credential update utility | Fast credential updates without full setup |

### Advanced Script Usage

#### **🏢 vCenter vs ESXi Usage**

**When to use `List-VMs.ps1` (vCenter):**

- ✅ **Large Environments**: Multiple ESXi hosts managed by vCenter
- ✅ **Folder Organization**: VMs organized in specific folders
- ✅ **Datacenter Context**: Need datacenter-specific VM listing
- ✅ **VCF Environments**: VMware Cloud Foundation deployments
- ✅ **Enterprise Management**: Centralized VM management scenarios

**When to use `List-VMs-esxi.ps1` (Direct ESXi):**

- ✅ **Standalone ESXi**: Single ESXi hosts not managed by vCenter
- ✅ **Lab Environments**: Development or testing ESXi hosts
- ✅ **Direct Host Access**: When vCenter is unavailable
- ✅ **Simple Inventories**: All VMs on a single host
- ✅ **Troubleshooting**: Bypassing vCenter for direct host assessment

**Configuration Notes:**

- Both scripts use the same `Configuration.psd1` file
- Set `SourceServerHost` to vCenter FQDN for `List-VMs.ps1`
- Set `SourceServerHost` to ESXi host FQDN for `List-VMs-esxi.ps1`
- Credentials stored in the same vault work for both scenarios

#### List-VMs.ps1 Examples

```powershell
# Basic execution (uses Configuration.psd1)
.\scripts\List-VMs.ps1

# Dry run mode (shows sample data without creating Excel file)
# Set DryRun = $true in Configuration.psd1

# Custom output directory
.\scripts\List-VMs.ps1 -OutputPath "C:\Reports\VMReports"

# Use different configuration file
.\scripts\List-VMs.ps1 -ConfigPath ".\configs\production.psd1"
```

#### List-VMs-esxi.ps1 Examples

```powershell
# Basic ESXi execution (uses Configuration.psd1 for ESXi host)
.\scripts\List-VMs-esxi.ps1

# Dry run mode for ESXi (shows sample data without creating Excel file)
.\scripts\List-VMs-esxi.ps1 -DryRun

# Custom output directory for ESXi reports
.\scripts\List-VMs-esxi.ps1 -OutputPath "C:\Reports\ESXiReports"

# Use different configuration file for specific ESXi host
.\scripts\List-VMs-esxi.ps1 -ConfigPath ".\configs\esxi-prod.psd1"
```

#### Quick-CredentialUpdate.ps1 Examples

```powershell
# Quick credential update (uses Configuration.psd1 for server info)
.\scripts\Quick-CredentialUpdate.ps1
```

#### Toolkit-Utilities.ps1 Actions

```powershell
# Environment and credential status
.\scripts\Toolkit-Utilities.ps1 -Action Status

# Test vCenter connectivity
.\scripts\Toolkit-Utilities.ps1 -Action TestConnection

# Validate and explore VM folders
.\scripts\Toolkit-Utilities.ps1 -Action ListFolders

# Create vault if needed and (re)store credentials from Configuration.psd1
.\scripts\Toolkit-Utilities.ps1 -Action SetupCredentials

# Display help information
.\scripts\Toolkit-Utilities.ps1 -Action Help
```

### Initialize-Environment and Credentials

The initializer is idempotent for credentials:

- It determines the preferred vault (prefers existing `VCenterVault`, else uses your `preferredVault`)
- If the configured `CredentialName` already exists in that vault, it skips seeding
- If missing, it creates/configures the vault (when needed) and prompts you once to store credentials

## 🏗️ Architecture

### Module Overview

The toolkit is built with a modular architecture for maintainability and reusability:

#### **EnvironmentValidator.psm1**

- **Purpose**: Environment validation, credential management, and optional module support
- **Key Functions**:
  - `Initialize-Environment` - Complete environment setup with optional module handling
  - `Initialize-CredentialManagement` - Secure vault creation and configuration
  - `Get-VCenterCredential` - Retrieve stored credentials
  - `Set-VCenterCredential` - Store new credentials securely
  - `Test-StoredCredential` - Validate credential accessibility
  - `Test-OptionalModule` - Check for optional modules (VCF.PowerCLI)
  - `Install-OptionalModule` - Install optional modules with user consent

#### **vSphereConnector.psm1**

- **Purpose**: vCenter/ESXi connectivity and VM data retrieval
- **Key Functions**:
  - `Connect-vSphereServer` - Establish secure vCenter/ESXi connections with SSL handling
  - `Get-VMsFromFolder` - Retrieve VM data from specified vCenter folders
  - `Get-VMsFromESXiHost` - Direct ESXi host VM discovery (bypasses vCenter)
  - `Get-VMProperties` - Extract comprehensive VM properties
  - `Disconnect-vSphereServer` - Clean connection teardown

#### **ExcelExporter.psm1**

- **Purpose**: Professional Excel file generation
- **Key Functions**:
  - `Export-VMsToExcelSimple` - Create formatted Excel reports
  - `New-ExcelFileName` - Generate timestamped file names
  - Custom formatting with dual headers and metadata sheets

### 🌐 VCF (VMware Cloud Foundation) Compatibility

The toolkit is **fully compatible** with VMware Cloud Foundation environments:

- **Native Support**: Uses standard VMware PowerCLI cmdlets that work across vSphere and VCF
- **No Code Changes Required**: Existing scripts work without modification in VCF environments
- **Enhanced Features**: Optional VCF.PowerCLI module provides additional VCF-specific capabilities
- **Flexible Deployment**: Can connect to vCenter instances within VCF management domains

**Key Compatibility Features**:

- ✅ **Standard vSphere APIs**: All VM data retrieval uses standard PowerCLI commands
- ✅ **VCF Management Domain Support**: Can target specific vCenter instances in VCF
- ✅ **Workload Domain VMs**: Retrieves VMs from any workload domain
- ✅ **Same Configuration**: Uses identical configuration format for both environments

**To use with VCF**:

1. **Point to VCF vCenter**: Set `SourceServerHost` to your VCF vCenter instance
2. **Use VCF Credentials**: Store appropriate VCF vCenter credentials
3. **Optional Enhancement**: Install VCF.PowerCLI module when prompted for additional features

## 🔐 Network Compatibility & SSL Handling

The toolkit includes robust SSL certificate handling for various network environments:

### **SSL Certificate Configuration**

Configure SSL handling in `Configuration.psd1`:

```powershell
# SSL Certificate handling (useful for ESXi hosts with self-signed certificates)
IgnoreSSLCertificates = $true                           # Set to $false for production vCenter with valid certificates

# Network environment settings
# Set to $true if running from networks with SSL inspection (Zscaler, etc.)
NetworkHasSSLInspection = $true                         # Enables additional SSL compatibility measures
```

### **Common Network Scenarios**

#### **Enterprise Networks with SSL Inspection**

**Symptoms**: SSL connection failures when connecting to vCenter/ESXi from corporate networks
**Common Appliances**: Zscaler, BlueCoat, Palo Alto with SSL decryption

**Solutions**:

1. **Configuration Approach** (Recommended):

   ```powershell
   # In Configuration.psd1
   IgnoreSSLCertificates = $true
   NetworkHasSSLInspection = $true
   ```

2. **Network Bypass** (Work with IT team):
   - Add ESXi/vCenter hosts to SSL inspection bypass list
   - Configure firewall rules for direct SSL passthrough
   - Use internal network segments that bypass security appliances

3. **VPN/Internal Access**:
   - Connect via VPN that bypasses SSL inspection
   - Use jump hosts/bastion servers on internal network
   - Run scripts from internal network segments

#### **ESXi Direct Connections**

**Use Case**: Connecting directly to standalone ESXi hosts
**Challenges**: Self-signed certificates, older TLS versions

**Configuration**:

```powershell
# Optimal settings for ESXi direct connections
IgnoreSSLCertificates = $true
NetworkHasSSLInspection = $false  # Unless corporate network involved
```

#### **Production vCenter with Valid Certificates**

**Use Case**: Enterprise vCenter with proper CA-signed certificates
**Configuration**:

```powershell
# Strict SSL validation for production
IgnoreSSLCertificates = $false
NetworkHasSSLInspection = $false
```

### **Troubleshooting SSL Issues**

**Common Error Messages**:

- "The SSL connection could not be established"
- "The underlying connection was closed: Could not establish trust relationship"
- "Authentication failed because the remote party has closed the transport stream"

**Diagnostic Steps**:

1. **Test Basic Connectivity**:

   ```powershell
   Test-NetConnection your-vcenter.company.com -Port 443
   ```

2. **Test from Internal Network**:
   - Try the same connection from a machine on the internal network
   - If it works internally, the issue is network-level SSL inspection
   - ESXi scripts are particularly sensitive to SSL inspection appliances

3. **Check PowerCLI Configuration**:

   ```powershell
   Get-PowerCLIConfiguration
   Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Scope Session
   ```

4. **Work with Network Team**:
   - Request SSL bypass for VMware infrastructure
   - Identify internal network access options
   - Configure VPN access that bypasses SSL inspection

## 🔒 Advanced Credential Management

### Automatic Vault Creation

The toolkit intelligently manages secret vaults:

1. **Existing Vault Detection**: Checks for existing `VCenterVault` or configured vault
2. **Smart Creation**: Creates vaults only when needed
3. **Configuration Integration**: Uses vault names from `Configuration.psd1`
4. **Fallback Logic**: Prioritizes existing vaults to avoid conflicts

### Configuration-Driven Credentials

All credential settings are configurable:

```powershell
# In Configuration.psd1
preferredVault  = 'VCenterVault'     # Vault to create/use
CredentialName  = 'SourceCred'       # Name for stored credentials
```

### Manual Credential Operations

```powershell
# Initialize credentials for first time or reset
.\scripts\Initialize-Environment.ps1

# Check credential status
.\scripts\Toolkit-Utilities.ps1 -Action Status

# Test specific credentials
Import-Module .\modules\EnvironmentValidator.psm1
Test-StoredCredential -CredentialName "SourceCred" -VaultName "VCenterVault"

# Manually store credentials
Set-VCenterCredential -CredentialName "SourceCred" -ServerHost "vcenter.company.com" -VaultName "VCenterVault"
```

### Security Features

- **Encrypted Storage**: All credentials encrypted using Windows DPAPI
- **User-Scoped**: Credentials isolated per user account
- **No Plain Text**: No passwords stored in configuration files
- **Secure Prompting**: Uses PowerShell's secure credential prompting
- **Automatic Cleanup**: Secure memory handling for credential objects

## 📊 Excel Output Format

### Professional Report Structure

The generated Excel files include:

### **Intelligent File Naming**

Excel files are automatically named with server-aware formatting:

**vCenter Files**: `VMList_hostname_YYYYMMDD_HHMMSS.xlsx`
**ESXi Files**: `VMList_ESXi_hostname_YYYYMMDD_HHMMSS.xlsx`

**Examples**:

- `VMList_vcenter-prod_20250819_143052.xlsx` - Production vCenter export
- `VMList_ESXi_esx01_20250819_143052.xlsx` - Direct ESXi host export
- `VMList_vcf-mgmt01_20250819_143052.xlsx` - VCF management domain export
- `VMList_ESXi_clvm19_20250819_143052.xlsx` - Lab ESXi host export

**Benefits**:

- ✅ **Environment Identification**: Instantly identify source server and connection type
- ✅ **Multi-Environment Support**: Easy to distinguish between vCenter and ESXi exports
- ✅ **Chronological Sorting**: Timestamp enables easy file organization
- ✅ **VCF Compatibility**: Works with VCF management and workload domain vCenters
- ✅ **Network Troubleshooting**: ESXi prefix identifies direct host connections

### **Report Content Structure**

1. **Dual Header System**:
   - **Row 1**: Combined header with vCenter server, datacenter, and folder information
   - **Row 2**: Column names for each VM property

2. **Data Formatting**:
   - **Consistent Data Types**: Proper formatting for numbers, dates, and text
   - **Null Handling**: "NULL" displayed for missing values
   - **Auto-Sizing**: Columns automatically sized for readability

3. **Metadata Sheet**:
   - Export timestamp and user information
   - Configuration summary
   - Statistics (VM count, export duration)
   - Source environment details

### Example Output Structure

```text
┌─────────────────────────────────────────────────────────────────┐
│ vCenter: vcenter.company.com | Datacenter: Prod | Folder: VMs   │
├──────────┬────────┬─────────┬─────────────┬──────────┬─────────┤
│   Name   │  UUID  │ DNSName │ PowerState  │ GuestOS  │ NumCPU  │
├──────────┼────────┼─────────┼─────────────┼──────────┼─────────┤
│  VM-001  │ 123... │ vm1.com │ PoweredOn   │ Windows  │    4    │
│  VM-002  │ 456... │ vm2.com │ PoweredOff  │ Linux    │    2    │
└──────────┴────────┴─────────┴─────────────┴──────────┴─────────┘
```

## 📁 Directory Structure

```text
ListVMsVCF/
├── scripts/
│   ├── Initialize-Environment.ps1      # Complete environment setup
│   ├── List-VMs.ps1                   # Main VM listing script (vCenter)
│   ├── List-VMs-esxi.ps1              # ESXi host VM listing script
│   ├── Toolkit-Utilities.ps1          # Diagnostic and utility functions
│   └── Quick-CredentialUpdate.ps1     # Quick credential update utility
├── modules/
│   ├── EnvironmentValidator.psm1       # Environment validation and credentials
│   ├── vSphereConnector.psm1          # vCenter/ESXi connectivity and VM data
│   └── ExcelExporter.psm1             # Excel file generation and formatting
├── shared/
│   ├── Configuration.psd1             # Main configuration file
│   └── Configuration.example.psd1     # Example configuration template
├── output/
│   └── (Generated Excel files)        # VMList_hostname_YYYYMMDD_HHMMSS.xlsx
├── test/
│   └── (Test scripts and validation)  # Future test framework
└── README.md                          # This documentation
```

## 🛠️ Troubleshooting

### Common Issues and Solutions

#### 1. **Module Installation Failures**

**Symptoms**: Errors during `Initialize-Environment.ps1` execution
**Solutions**:

```powershell
# Run PowerShell as Administrator
Start-Process powershell -Verb runAs

# Check execution policy
Get-ExecutionPolicy
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# Manual module installation
Install-Module VMware.PowerCLI -Scope CurrentUser -Force
Install-Module Microsoft.PowerShell.SecretManagement -Scope CurrentUser -Force
Install-Module ImportExcel -Scope CurrentUser -Force
```

#### 2. **vCenter Connection Issues**

**Symptoms**: "Failed to connect to vSphere server" errors
**Solutions**:

```powershell
# Test network connectivity
Test-NetConnection your-vcenter.company.com -Port 443

# Verify credentials
.\scripts\Toolkit-Utilities.ps1 -Action Status

# Test connection manually
.\scripts\Toolkit-Utilities.ps1 -Action TestConnection

# Reset stored credentials
Remove-Secret -Name "SourceCred" -Vault "VCenterVault"
.\scripts\Initialize-Environment.ps1
```

#### 3. **Folder Not Found Errors**

**Symptoms**: "Could not find folder" messages
**Solutions**:

```powershell
# List available folders
.\scripts\Toolkit-Utilities.ps1 -Action ListFolders

# Verify datacenter name
# Check Configuration.psd1 dataCenter setting

# Test with smaller test folder
# Use 'Discovered virtual machine' for testing
```

#### 4. **Excel Export Failures**

**Symptoms**: Script completes but no Excel file created
**Solutions**:

```powershell
# Verify DryRun setting
# Set DryRun = $false in Configuration.psd1

# Check output directory permissions
Test-Path .\output -PathType Container
New-Item -ItemType Directory -Path .\output -Force

# Verify ImportExcel module
Get-Module ImportExcel -ListAvailable
Import-Module ImportExcel
```

#### 5. **SecretStore Vault Issues**

**Symptoms**: Vault creation or credential storage failures
**Solutions**:

```powershell
# Check existing vaults
Get-SecretVault

# Reset SecretStore configuration
Set-SecretStoreConfiguration -Authentication Password -Interaction Prompt -Scope CurrentUser

# Manual vault creation
Register-SecretVault -Name "VCenterVault" -ModuleName Microsoft.PowerShell.SecretStore

# Test vault functionality
Set-Secret -Name "test" -Secret "testvalue" -Vault "VCenterVault"
Get-Secret -Name "test" -Vault "VCenterVault" -AsPlainText
Remove-Secret -Name "test" -Vault "VCenterVault"
```

### Diagnostic Commands

Use these commands for troubleshooting:

```powershell
# Complete environment status
.\scripts\Toolkit-Utilities.ps1 -Action Status

# Test all connectivity
.\scripts\Toolkit-Utilities.ps1 -Action TestConnection

# Explore VM folders
.\scripts\Toolkit-Utilities.ps1 -Action ListFolders

# Check PowerShell environment
$PSVersionTable
Get-ExecutionPolicy

# Verify module installations
Get-Module VMware.PowerCLI, Microsoft.PowerShell.SecretManagement, ImportExcel -ListAvailable

# Test credential access
Import-Module .\modules\EnvironmentValidator.psm1
Test-StoredCredential -CredentialName "SourceCred" -VaultName "VCenterVault"
```

## 🔧 Advanced Configuration

### Custom VM Properties

Add or modify VM properties in `Configuration.psd1`:

```powershell
VMProperties = @(
    'Name',                    # VM Display Name
    'UUID',                    # Unique Identifier
    'DNSName',                 # DNS Name
    'PowerState',              # Current Power State
    'GuestOS',                 # Guest Operating System
    'NumCPU',                  # CPU Count
    'MemoryMB',                # Memory in MB
    'ProvisionedSpaceGB',      # Provisioned Storage
    'UsedSpaceGB',             # Used Storage
    'Datastore',               # Storage Location
    'NetworkAdapters',         # Network Configuration
    'IPAddresses',             # IP Address List
    'Annotation',              # VM Notes/Comments
    'HostSystem',              # ESXi Host
    'VMToolsVersion',          # VMware Tools Version
    'VMToolsStatus',           # VMware Tools Status
    'Folder',                  # VM Folder Location
    'ResourcePool',            # Resource Pool Assignment
    'HARestartPriority',       # HA Restart Priority
    'HAIsolationResponse'      # HA Isolation Response
)
```

### Multiple Environment Support

Create separate configuration files for different environments:

```powershell
# Production environment
Copy-Item .\shared\Configuration.psd1 .\shared\Production.psd1

# Development environment  
Copy-Item .\shared\Configuration.psd1 .\shared\Development.psd1

# Use specific configuration
.\scripts\List-VMs.ps1 -ConfigPath ".\shared\Production.psd1"
```

### Scheduled Execution

Set up automated VM reporting using Windows Task Scheduler:

```powershell
# Create scheduled task script
$script = @"
Set-Location "C:\Path\To\ListVMsVCF"
.\scripts\List-VMs.ps1
"@

$script | Out-File -FilePath "C:\Scripts\VMReport.ps1" -Encoding UTF8

# Register scheduled task (run as Administrator)
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File C:\Scripts\VMReport.ps1"
$trigger = New-ScheduledTaskTrigger -Daily -At "06:00"
$principal = New-ScheduledTaskPrincipal -UserId "DOMAIN\ServiceAccount" -LogonType Password
Register-ScheduledTask -TaskName "VM Inventory Report" -Action $action -Trigger $trigger -Principal $principal
```

## 🤝 Contributing

This toolkit is designed to be modular and extensible. Consider these areas for enhancement:

- **Additional VM Properties**: Extend the VM data collection
- **Export Formats**: Add CSV, JSON, or XML export options  
- **Reporting Features**: Add charts and visualizations
- **Multi-vCenter Support**: Aggregate data from multiple vCenters
- **Filtering Options**: Add VM filtering capabilities
- **Performance Monitoring**: Add VM performance metrics

## 📄 License

Internal use toolkit - please follow your organization's software usage policies.

---

## 🆘 Support

For issues and questions:

1. **Check Documentation**: Review this README and inline help
2. **Run Diagnostics**: Use `.\scripts\Toolkit-Utilities.ps1 -Action Status`  
3. **Check Logs**: Review PowerShell error messages and verbose output
4. **Validate Environment**: Ensure all prerequisites are met
5. **Test Components**: Use individual utility functions to isolate issues

**Toolkit Version**: 2.0.0  
**Last Updated**: August 19, 2025  
**PowerShell Compatibility**: 5.1+ (7.0+ recommended)

**Author**: Alfred Angelov
