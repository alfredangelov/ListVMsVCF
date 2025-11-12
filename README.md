# VirtToolkit - VMware vSphere VM Inventory Management

A comprehensive PowerShell toolkit for automated VM inventory reporting from VMware vSphere/vCenter and ESXi hosts. Generate detailed Excel reports with optional email delivery via Microsoft Graph API.

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![VMware PowerCLI](https://img.shields.io/badge/VMware%20PowerCLI-13.0%2B-green.svg)](https://www.powershellgallery.com/packages/VMware.PowerCLI)

## 🌟 Features

### Core Capabilities

- **Automated VM Inventory Reports** - Retrieve comprehensive VM information from vCenter or ESXi hosts
- **Flexible Filtering** - Filter by PowerState, name patterns (include/exclude)
- **Configurable Properties** - Select which VM properties to retrieve (17+ properties supported)
- **Excel Export** - Professional Excel reports with metadata sheets and formatting
- **Email Delivery** - Optional automated email delivery via Microsoft Graph API
- **Secure Credential Management** - Store and reuse credentials securely with PowerShell SecretManagement
- **Comprehensive Logging** - Detailed logs for all operations with multiple log levels
- **DryRun Mode** - Test configurations without generating files

### Supported Environments

- ✅ VMware vSphere 6.7, 7.0, 8.0+
- ✅ VMware Cloud Foundation (VCF)
- ✅ Direct ESXi host connections
- ✅ Windows PowerShell 5.1+
- ✅ PowerShell 7+

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Usage](#usage)
- [Scripts](#scripts)
- [VM Properties](#vm-properties)
- [Filtering](#filtering)
- [Email Notifications](#email-notifications)
- [Credential Management](#credential-management)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## 🔧 Prerequisites

### Required PowerShell Modules

```powershell
# Core modules (always required)
Install-Module VMware.PowerCLI -Scope CurrentUser -Force
Install-Module Microsoft.PowerShell.SecretManagement -Scope CurrentUser -Force
Install-Module Microsoft.PowerShell.SecretStore -Scope CurrentUser -Force
Install-Module ImportExcel -Scope CurrentUser -Force

# Optional modules (for email notifications)
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force
Install-Module Microsoft.Graph.Users.Actions -Scope CurrentUser -Force
```

### Minimum Versions

- PowerShell 5.1 or PowerShell 7+
- VMware.PowerCLI 13.0.0+
- ImportExcel 7.0.0+

### Network Requirements

- Network access to vCenter/ESXi hosts
- (Optional) Internet access for Microsoft Graph API email delivery

## 📦 Installation

### Option 1: Clone Repository (Recommended)

```powershell
git clone https://github.com/yourusername/VirtToolkit.git
cd VirtToolkit
```

### Option 2: Download ZIP

1. Download the repository as ZIP
2. Extract to your desired location
3. Unblock files if needed:

   ```powershell
   Get-ChildItem -Path .\VirtToolkit -Recurse | Unblock-File
   ```

## 🚀 Quick Start

### 1. Initialize Environment

```powershell
# Install required modules
.\scripts\Initialize-Environment.ps1

# Initialize credential vault
.\scripts\Manage-VirtToolkitSecrets.ps1 -Mode Initialize
```

### 2. Configure Settings

```powershell
# Copy example configuration
Copy-Item .\shared\config\Configuration.example.psd1 .\shared\config\Configuration.psd1

# Edit configuration with your environment details
notepad .\shared\config\Configuration.psd1
```

**Minimum required settings:**

```powershell
@{
    SourceServerHost = 'vcenter.company.com'  # Your vCenter/ESXi host
    VMFolder         = 'Production'            # Folder name to scan
    DryRun           = $false                  # Set to $false for production
}
```

### 3. Store Credentials

```powershell
# Store vCenter/ESXi credentials
.\scripts\Manage-VirtToolkitSecrets.ps1 -Mode Update
```

### 4. Generate Report

```powershell
# vCenter/vSphere inventory
.\scripts\Get-vSphereVMInventory.ps1

# ESXi host inventory
.\scripts\Get-ESXiVMInventory.ps1 -ESXiHost "esxi01.company.com"
```

## ⚙️ Configuration

### Configuration File Structure

The main configuration file is located at `shared\config\Configuration.psd1`:

```powershell
@{
    # Server Connection
    SourceServerHost      = 'vcenter.company.com'
    IgnoreSSLCertificates = $true
    
    # Environment Settings
    dataCenter            = 'Datacenter01'
    VMFolder              = 'Production'  # Folder name (not path)
    
    # Output Settings
    OutputPath            = '.\output'
    DryRun                = $false
    
    # Credential Management
    preferredVault        = 'VirtToolkitVault'
    PreferredUsername     = 'administrator@vsphere.local'
    
    # VM Properties (Hashtable format)
    VMProperties          = @{
        Name               = 'VM Display Name'
        UUID               = 'Unique VM Identifier'
        PowerState         = 'Current Power State'
        NumCPU             = 'Number of vCPUs'
        MemoryMB           = 'Memory allocation in MB'
        # ... add more properties as needed
    }
    
    # Filtering Options
    Filters               = @{
        PowerStates  = @('PoweredOn')           # Only powered-on VMs
        ExcludeNames = @('*template*', '*test*') # Exclude patterns
        IncludeNames = @()                       # Include patterns (optional)
    }
    
    # Email Notifications (Optional)
    EmailNotification     = @{
        Enabled           = $false
        # ... see Email Notifications section
    }
}
```

### Important Notes

**VMFolder Setting:**

- Use the **folder name** (e.g., `'Production'`), not a path
- PowerCLI's `Get-VM -Location` expects folder names
- For nested folders with duplicate names, you may need to use `Get-Folder` first

**VM Properties:**

- Use hashtable format with property names as keys
- Values are descriptions for documentation
- Only configured properties will be retrieved

## 📝 Usage

### vSphere/vCenter Inventory

```powershell
# Standard execution
.\scripts\Get-vSphereVMInventory.ps1

# Skip email notification
.\scripts\Get-vSphereVMInventory.ps1 -SkipEmail

# Use custom configuration
.\scripts\Get-vSphereVMInventory.ps1 -ConfigPath "C:\Custom\Config.psd1"
```

### ESXi Host Inventory

```powershell
# Specify ESXi host
.\scripts\Get-ESXiVMInventory.ps1 -ESXiHost "esxi01.company.com"

# Use configuration file's SourceServerHost
.\scripts\Get-ESXiVMInventory.ps1

# Skip email
.\scripts\Get-ESXiVMInventory.ps1 -ESXiHost "esxi01.company.com" -SkipEmail
```

### Testing with DryRun Mode

```powershell
# Edit Configuration.psd1
DryRun = $true

# Run script - shows sample data, doesn't create files
.\scripts\Get-vSphereVMInventory.ps1
```

## 📜 Scripts

### Main Production Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| **Get-vSphereVMInventory.ps1** | vCenter/vSphere inventory | `.\scripts\Get-vSphereVMInventory.ps1` |
| **Get-ESXiVMInventory.ps1** | ESXi host inventory | `.\scripts\Get-ESXiVMInventory.ps1 -ESXiHost "esxi01.company.com"` |

### Utility Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| **Initialize-Environment.ps1** | Install required modules | `.\scripts\Initialize-Environment.ps1` |
| **Manage-VirtToolkitSecrets.ps1** | Credential management | `.\scripts\Manage-VirtToolkitSecrets.ps1 -Mode Initialize` |

### Test Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| **Test-VSphereConnectivity.ps1** | Test vCenter connectivity | `.\test\Test-VSphereConnectivity.ps1` |
| **Test-ESXiConnectivity.ps1** | Test ESXi host connectivity | `.\test\Test-ESXiConnectivity.ps1 -ESXiHost "esxi01.company.com"` |
| **Test-ExcelExport.ps1** | Test Excel export functionality | `.\test\Test-ExcelExport.ps1 -All` |
| **Test-GraphEmail.ps1** | Test email functionality | `.\test\Test-GraphEmail.ps1` |

### Manage-VirtToolkitSecrets.ps1 Modes

```powershell
# Initialize credential vault
.\scripts\Manage-VirtToolkitSecrets.ps1 -Mode Initialize

# Add/Update credentials
.\scripts\Manage-VirtToolkitSecrets.ps1 -Mode Update

# List stored credentials
.\scripts\Manage-VirtToolkitSecrets.ps1 -Mode List

# Verify credentials work
.\scripts\Manage-VirtToolkitSecrets.ps1 -Mode Verify

# Remove a credential
.\scripts\Manage-VirtToolkitSecrets.ps1 -Mode Remove -CredentialName "vSphere-vcenter.company.com-admin"

# Clean/reset vault
.\scripts\Manage-VirtToolkitSecrets.ps1 -Mode Clean
```

## 🔍 VM Properties

### Available Properties

The following properties can be configured in the `VMProperties` hashtable:

| Property | Description | Type |
|----------|-------------|------|
| **Name** | VM display name | String |
| **UUID** | Unique VM identifier | String |
| **DNSName** | VM DNS hostname | String |
| **PowerState** | Power state (PoweredOn, PoweredOff, Suspended) | String |
| **GuestOS** | Guest operating system | String |
| **NumCPU** | Number of vCPUs | Integer |
| **MemoryMB** | Memory allocation in MB | Integer |
| **ProvisionedSpaceGB** | Total provisioned storage in GB | Decimal |
| **UsedSpaceGB** | Actual used storage in GB | Decimal |
| **Datastore** | Datastore names (comma-separated) | String |
| **NetworkAdapters** | Network adapter names | String |
| **IPAddresses** | IP addresses (IPv4 only) | String |
| **Annotation** | VM notes/comments | String |
| **HostSystem** | ESXi host running the VM | String |
| **VMToolsVersion** | VMware Tools version | String |
| **VMToolsStatus** | VMware Tools status | String |
| **Folder** | VM folder location | String |

### Configuration Example

```powershell
VMProperties = @{
    Name               = 'VM Display Name'
    UUID               = 'Unique VM Identifier'
    PowerState         = 'Current Power State'
    NumCPU             = 'Number of vCPUs'
    MemoryMB           = 'Memory allocation in MB'
    GuestOS            = 'Guest Operating System'
    IPAddresses        = 'VM IP addresses'
}
```

## 🔎 Filtering

### PowerState Filtering

Filter VMs by power state:

```powershell
Filters = @{
    PowerStates = @('PoweredOn')                # Only powered-on VMs
    # PowerStates = @('PoweredOff')             # Only powered-off VMs
    # PowerStates = @('PoweredOn', 'Suspended') # Multiple states
}
```

### Name Pattern Filtering

**Exclude VMs:**

```powershell
Filters = @{
    ExcludeNames = @('*template*', '*test*', '*-old')
}
```

**Include Only Specific VMs:**

```powershell
Filters = @{
    IncludeNames = @('*prod*', '*web*', 'DB-*')
}
```

**Combine Filters:**

```powershell
Filters = @{
    PowerStates  = @('PoweredOn')
    ExcludeNames = @('*template*', '*!ARCHIVE*')
    IncludeNames = @('*prod*')
}
```

### Filter Processing Order

1. **PowerState** - Filter by power state
2. **ExcludeNames** - Remove VMs matching exclude patterns
3. **IncludeNames** - Keep only VMs matching include patterns

## 📧 Email Notifications

### Prerequisites

1. **Azure AD Application Registration**
   - Create app registration in Azure AD portal
   - Grant API permissions: `Mail.Send`, `Mail.ReadWrite`
   - Create client secret
   - Configure sender mailbox with `SendAs` permissions

2. **Microsoft Graph Modules**

   ```powershell
   Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
   Install-Module Microsoft.Graph.Users.Actions -Scope CurrentUser
   ```

### Configuration

```powershell
EmailNotification = @{
    Enabled           = $true
    
    # Azure AD Application
    TenantId          = '12345678-1234-1234-1234-123456789abc'
    ClientId          = '87654321-4321-4321-4321-cba987654321'
    
    # Client Secret (store in vault - recommended)
    ClientSecretName  = 'MicrosoftGraph-ClientSecret'
    
    # Email Settings
    From              = 'reports@company.com'
    To                = @(
        'admin@company.com'
        'team@company.com'
    )
    Subject           = 'VM Inventory Report - {{DATE}}'
    
    # Email Body Template
    BodyTemplate      = @'
VM Inventory Report

Report Generated: {{DATE}}
vCenter Server: {{SERVER}}
Total VMs: {{COUNT}}

The attached Excel file contains the complete VM inventory report.

This is an automated report from VirtToolkit.
'@
    
    # Attachment Settings
    IncludeAttachment = $true
}
```

### Store Client Secret

```powershell
# Store the client secret securely
.\scripts\Manage-VirtToolkitSecrets.ps1 -Mode Update
# Select "Other" and enter secret name: MicrosoftGraph-ClientSecret
```

### Template Placeholders

The following placeholders are supported in `Subject` and `BodyTemplate`:

- `{{DATE}}` - Current timestamp
- `{{SERVER}}` - vCenter/ESXi server name
- `{{COUNT}}` - Total VM count

## 🔐 Credential Management

### Credential Storage Pattern

Credentials are stored with a standardized naming convention:

```Plain text
vSphere-{hostname}-{username}
```

**Examples:**

- `vSphere-vcenter.company.com-administrator@vsphere.local`
- `vSphere-esxi01.company.com-root`

### Managing Credentials

**Initialize Vault:**

```powershell
.\scripts\Manage-VirtToolkitSecrets.ps1 -Mode Initialize
```

**Add/Update Credentials:**

```powershell
.\scripts\Manage-VirtToolkitSecrets.ps1 -Mode Update
```

**List All Credentials:**

```powershell
.\scripts\Manage-VirtToolkitSecrets.ps1 -Mode List
```

**Verify Credentials:**

```powershell
.\scripts\Manage-VirtToolkitSecrets.ps1 -Mode Verify
```

**Remove Credential:**

```powershell
.\scripts\Manage-VirtToolkitSecrets.ps1 -Mode Remove -CredentialName "vSphere-vcenter.company.com-admin"
```

### PreferredUsername

If multiple credentials exist for the same server, `PreferredUsername` in configuration determines which one to use:

```powershell
PreferredUsername = 'administrator@vsphere.local'
```

## 📊 Output Files

### Excel Reports

Reports are saved to the configured `OutputPath` (default: `.\output\`):

**vSphere Reports:**

```Plain text
vSphere-VM-Inventory_YYYYMMDD_HHMMSS.xlsx
```

**ESXi Reports:**

```Plain text
ESXi-VM-Inventory_hostname_YYYYMMDD_HHMMSS.xlsx
```

### Excel File Structure

Each report contains two worksheets:

1. **VM Inventory** - Main data with all configured properties
2. **Metadata** - Report metadata including:
   - Report type and timestamp
   - Server information
   - VM counts (total, filtered)
   - Filter details
   - Property list

### Log Files

Logs are saved to `.\logs\`:

```Plain text
vSphereVMInventory_YYYYMMDD_HHMMSS.log
ESXiVMInventory_YYYYMMDD_HHMMSS.log
```

**Log Levels:**

- `INFO` - Informational messages
- `SUCCESS` - Successful operations
- `WARN` - Warnings
- `ERROR` - Errors

## 🛠️ Troubleshooting

### Common Issues

#### PowerCLI Connection Issues

**Problem:** SSL certificate errors

```powershell
# Solution: Enable SSL certificate bypass
IgnoreSSLCertificates = $true
```

**Problem:** "Cannot find VIContainer with name"

```Plain text
# Solution: Use folder NAME, not path
VMFolder = 'Production'  # ✅ Correct
VMFolder = 'Datacenter/vm/Production'  # ❌ Incorrect
```

#### Credential Issues

**Problem:** "Failed to retrieve credential"

```powershell
# Solution: Verify credentials are stored
.\scripts\Manage-VirtToolkitSecrets.ps1 -Mode List

# Re-add if missing
.\scripts\Manage-VirtToolkitSecrets.ps1 -Mode Update
```

#### Email Issues

**Problem:** "The term 'Send-VirtToolkitGraphEmail' is not recognized"

```powershell
# Solution: Ensure correct module path
Import-Module .\modules\VirtToolkit.GraphEmail.psm1 -Force
```

**Problem:** "Failed to send email"

```Plain text
# Check:
1. Azure AD app permissions (Mail.Send)
2. Client secret is stored correctly
3. Sender mailbox has SendAs permissions
4. TenantId and ClientId are correct
```

#### Module Import Issues

**Problem:** "Cannot find module"

```powershell
# Solution: Install missing modules
.\scripts\Initialize-Environment.ps1
```

### Enable Debug Logging

For detailed troubleshooting, check log files in `.\logs\`:

```powershell
# View latest log
Get-Content .\logs\vSphereVMInventory_*.log | Select-Object -Last 50
```

### Test Individual Components

```powershell
# Test Excel export
.\test\Test-ExcelExport.ps1 -BasicExcelExport

# Test email (without sending)
.\test\Test-GraphEmail.ps1

# Test with DryRun mode
# Set DryRun = $true in Configuration.psd1
.\scripts\Get-vSphereVMInventory.ps1
```

## 📁 Project Structure

```Plain text
VirtToolkit/
├── scripts/                    # Main production scripts
│   ├── Get-vSphereVMInventory.ps1
│   ├── Get-ESXiVMInventory.ps1
│   ├── Initialize-Environment.ps1
│   └── Manage-VirtToolkitSecrets.ps1
├── modules/                    # Shared PowerShell modules
│   ├── VirtToolkit.Credentials.psm1
│   ├── VirtToolkit.Excel.psm1
│   ├── VirtToolkit.GraphEmail.psm1
│   └── VirtToolkit.Logging.psm1
├── test/                       # Test scripts
│   ├── Test-ExcelExport.ps1
│   ├── Test-ESXiConnectivity.ps1
│   ├── Test-VSphereConnectivity.ps1
│   └── Test-GraphEmail.ps1
├── shared/                     # Shared resources
│   └── config/
│       ├── Configuration.psd1
│       └── Configuration.example.psd1
├── output/                     # Generated Excel reports
├── logs/                       # Log files
├── README.md
├── CHANGELOG.md
└── .gitignore
```

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Development Guidelines

- Follow PowerShell best practices
- Include comment-based help for new functions
- Add logging for all operations
- Test with both PowerShell 5.1 and 7+
- Update documentation for new features

## 🙏 Acknowledgments

- VMware PowerCLI team for the excellent PowerShell modules
- ImportExcel module by dfinke
- Microsoft Graph PowerShell SDK team
- PowerShell SecretManagement team

## 🗺️ Roadmap

- [ ] Support for multiple vCenter connections
- [ ] HTML report generation
- [ ] Custom property mapping from configuration
- [ ] Scheduled task automation helper
- [ ] Advanced filtering with regex support
- [ ] Export to CSV/JSON formats
- [ ] Performance metrics collection
- [ ] Storage analytics reporting

---

**Made with ❤️ for VMware administrators everywhere**
