# VM Listing Toolkit - Quick Start Guide

## 🚀 Getting Started in 5 Minutes

### Step 1: Initialize Environment

Run this command first to set up your PowerShell environment:

```powershell
.\scripts\Initialize-Environment.ps1
```

This will:

- ✅ Check your PowerShell version
- ✅ Install required modules (VMware.PowerCLI, ImportExcel, etc.)
- ✅ Verify everything is ready

### Step 2: Configure Your Settings

Edit the configuration file: `shared\Configuration.psd1`

**Required Changes:**

```powershell
# Change these to match your environment:
SourceServerHost = 'your-vcenter-server.company.com'  # Your vCenter server
dataCenter = 'YourDatacenterName'                     # Your datacenter
VMFolder = 'YourFolder/SubFolder'                     # VM folder path

# For first run, keep this as $true for testing:
DryRun = $true
```

### Step 3: Test Your Configuration

Verify your settings work:

```powershell
# Check environment status
.\scripts\Toolkit-Utilities.ps1 -Action Status

# Test vCenter connection
.\scripts\Toolkit-Utilities.ps1 -Action TestConnection

# List available folders (to validate your VMFolder configuration)
.\scripts\Toolkit-Utilities.ps1 -Action ListFolders
```

### Step 4: Run VM Listing (Test Mode)

```powershell
.\scripts\List-VMs.ps1
```

This runs in **DryRun mode** - no files are created, you just see what would happen.

### Step 5: Generate Real Excel Report

When you're happy with the test results:

1. Edit `shared\Configuration.psd1` and set `DryRun = $false`
2. Run: `.\scripts\List-VMs.ps1`
3. Find your Excel file in the `output\` folder

## 📊 Excel Output

Your Excel file will have:

- **Sheet 1 (VM_List)**: All VM data with custom headers
- **Sheet 2 (Metadata)**: Export details and summary

## 🔧 Common Customizations

### Change VM Properties

Edit the `VMProperties` array in `Configuration.psd1`:

```powershell
VMProperties = @(
    'Name', 'PowerState', 'GuestOS', 'NumCPU', 'MemoryMB'
    # Add or remove properties as needed
)
```

### Custom Output Location

```powershell
.\scripts\List-VMs.ps1 -OutputPath "C:\Reports"
```

### Use Different Config File

```powershell
.\scripts\List-VMs.ps1 -ConfigPath ".\my-custom-config.psd1"
```

## ❓ Troubleshooting

### "Module installation failed"

- Run PowerShell as Administrator
- Check internet connectivity

### "Cannot connect to vCenter"

- Verify server hostname/IP in configuration
- Check your network connection to vCenter
- Run: `.\scripts\Toolkit-Utilities.ps1 -Action TestConnection`

### "Folder not found"

- Run: `.\scripts\Toolkit-Utilities.ps1 -Action ListFolders`
- Check the exact folder name/path in your configuration
- Verify you have permissions to access the folder

### "No VMs found"

- Verify your VMFolder path is correct
- Check you have permissions to see VMs in that folder
- Try a different folder path

## 📁 File Structure

```Plain text
ListVMsVCF/
├── scripts/           # Main scripts to run
├── modules/           # Reusable PowerShell modules  
├── shared/            # Configuration files
├── output/            # Generated Excel files
└── README.md          # Full documentation
```

## 🎯 Next Steps

Once you're comfortable with the basics:

- Review the full README.md for advanced features
- Customize VM properties in the configuration
- Set up scheduled runs if needed
- Explore the utility functions for ongoing management

---
**Need Help?** Check the full README.md or run: `.\scripts\Toolkit-Utilities.ps1 -Action Help`
