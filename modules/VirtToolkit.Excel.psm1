<#
.SYNOPSIS
    VirtToolkit shared Excel export utilities for standardized Excel output across all modules.

.DESCRIPTION
    This module provides unified Excel export functionality for all VirtToolkit modules.
    It consolidates Excel export patterns from ListVMs, PermissionToolkit, MigrationToolkit, and RVToolsDump
    to provide consistent formatting, metadata handling, and error management.

    Key Features:
    - Standardized Excel export with consistent formatting
    - Automatic metadata sheet generation
    - Support for multiple worksheets and complex data structures
    - Custom headers and styling options
    - Filename generation with timestamp patterns
    - Error handling and cleanup

.NOTES
    Part of VirtToolkit: Enterprise Virtualization Management Platform
    Integrates with shared modules and unified configuration system
#>

function Export-VirtToolkitExcel {
    <#
    .SYNOPSIS
        Exports data to Excel with standardized VirtToolkit formatting and metadata.

    .DESCRIPTION
        Export-VirtToolkitExcel provides a unified interface for Excel export across
        all VirtToolkit modules. It handles complex data structures, applies consistent
        formatting, and automatically generates metadata sheets.

    .PARAMETER Data
        Array of data objects to export. Can be hashtables, PSCustomObjects, or mixed.

    .PARAMETER FilePath
        Path where the Excel file will be saved. Directory will be created if needed.

    .PARAMETER WorksheetName
        Name of the primary data worksheet. Default: "Data"

    .PARAMETER Title
        Optional title for the worksheet header. If provided, will be displayed as a merged header row.

    .PARAMETER Properties
        Array of property names to include in export. If not specified, all properties will be included.

    .PARAMETER ModuleName
        Name of the calling VirtToolkit module for metadata and logging.

    .PARAMETER Server
        Server name for metadata (e.g., vCenter server).

    .PARAMETER AdditionalMetadata
        Hashtable of additional metadata key-value pairs to include.

    .PARAMETER IncludeMetadataSheet
        Create a separate metadata worksheet with export information. Default: $true

    .PARAMETER AutoSize
        Auto-size columns to fit content. Default: $true

    .PARAMETER FreezeHeaders
        Freeze the header row(s) for easier scrolling. Default: $true

    .PARAMETER UseAdvancedFormatting
        Apply advanced formatting including colors, borders, and styles. Default: $true

    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Returns export result with success status, file path, and metadata

    .EXAMPLE
        $vmData = Get-VM | Select-Object Name, PowerState, NumCpu, MemoryGB
        $result = Export-VirtToolkitExcel -Data $vmData -FilePath "C:\exports\vms.xlsx" -ModuleName "ListVMs" -Server "vcenter01.contoso.local"

        Description
        -----------
        Exports VM data with automatic metadata generation

    .EXAMPLE
        $result = Export-VirtToolkitExcel -Data $permissions -FilePath "permissions.xlsx" -Title "vCenter Permissions Report" -Properties @('User', 'Role', 'Entity') -ModuleName "PermissionToolkit"

        Description
        -----------
        Exports permission data with custom title and specific properties

    .EXAMPLE
        $metadata = @{ Environment = "Production"; ExportType = "Full"; Notes = "Quarterly report" }
        $result = Export-VirtToolkitExcel -Data $data -FilePath "report.xlsx" -AdditionalMetadata $metadata

        Description
        -----------
        Exports data with custom metadata information
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Data,

        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [string]$WorksheetName = "Data",

        [Parameter(Mandatory = $false)]
        [string]$Title,

        [Parameter(Mandatory = $false)]
        [string[]]$Properties,

        [Parameter(Mandatory = $false)]
        [string]$ModuleName,

        [Parameter(Mandatory = $false)]
        [string]$Server,

        [Parameter(Mandatory = $false)]
        [hashtable]$AdditionalMetadata = @{},

        [Parameter(Mandatory = $false)]
        [bool]$IncludeMetadataSheet = $true,

        [Parameter(Mandatory = $false)]
        [bool]$AutoSize = $true,

        [Parameter(Mandatory = $false)]
        [bool]$FreezeHeaders = $true,

        [Parameter(Mandatory = $false)]
        [bool]$UseAdvancedFormatting = $true
    )

    # Import required modules
    $requiredModules = @('ImportExcel')
    foreach ($module in $requiredModules) {
        if (-not (Get-Module -Name $module -ListAvailable)) {
            throw "Required module '$module' not found. Please install ImportExcel module: Install-Module ImportExcel"
        }
        Import-Module $module -ErrorAction Stop
    }

    # Import logging module if available
    $loggingModule = Join-Path (Split-Path $PSScriptRoot -Parent) 'VirtToolkit.Logging.psm1'
    if (Test-Path $loggingModule) {
        Import-Module $loggingModule -Force
        Write-VirtToolkitLog -Message "Starting Excel export to: $FilePath" -Level 'INFO' -ModuleName $ModuleName
    }

    try {
        # Ensure the directory exists
        $directory = Split-Path -Path $FilePath -Parent
        if ($directory -and -not (Test-Path -Path $directory)) {
            New-Item -Path $directory -ItemType Directory -Force | Out-Null
        }

        # Remove existing file if it exists
        if (Test-Path -Path $FilePath) {
            Remove-Item -Path $FilePath -Force
        }

        # Convert data to consistent format
        $processedData = ConvertTo-VirtToolkitExcelData -Data $Data -Properties $Properties

        # Prepare export parameters
        $exportParams = @{
            Path          = $FilePath
            WorksheetName = $WorksheetName
        }
        
        # Add switch parameters conditionally
        if ($AutoSize) {
            $exportParams.AutoSize = $true
        }
        if ($FreezeHeaders) {
            $exportParams.FreezeTopRow = $true
        }
        $exportParams.BoldTopRow = $true

        # Add title if provided
        if ($Title) {
            $exportParams.Title = $Title
            $exportParams.TitleSize = 14
            $exportParams.TitleBold = $true
        }

        # Apply advanced formatting if requested
        if ($UseAdvancedFormatting) {
            $exportParams.TableStyle = 'Medium2'
        }

        # Export main data
        $processedData | Export-Excel @exportParams

        # Create metadata sheet if requested
        if ($IncludeMetadataSheet) {
            $metadata = New-VirtToolkitExcelMetadata -ModuleName $ModuleName -Server $Server -DataCount $processedData.Count -AdditionalMetadata $AdditionalMetadata
            
            $metadataParams = @{
                Path          = $FilePath
                WorksheetName = "Metadata"
                BoldTopRow    = $true
            }
            if ($AutoSize) {
                $metadataParams.AutoSize = $true
            }
            
            $metadata | Export-Excel @metadataParams
        }

        $result = [PSCustomObject]@{
            Success          = $true
            FilePath         = $FilePath
            RecordCount      = $processedData.Count
            WorksheetName    = $WorksheetName
            MetadataIncluded = $IncludeMetadataSheet
            Message          = "Excel export completed successfully"
            ExportTime       = Get-Date
        }

        if ($loggingModule -and (Test-Path $loggingModule)) {
            Write-VirtToolkitLog -Message "SUCCESS: Successfully exported $($processedData.Count) records to Excel: $FilePath" -Level 'SUCCESS' -ModuleName $ModuleName
        }

        return $result
    }
    catch {
        $errorMessage = "Excel export failed: $($_.Exception.Message)"
        
        if ($loggingModule -and (Test-Path $loggingModule)) {
            Write-VirtToolkitLog -Message $errorMessage -Level 'ERROR' -ModuleName $ModuleName
        }

        return [PSCustomObject]@{
            Success          = $false
            FilePath         = $FilePath
            RecordCount      = 0
            WorksheetName    = $WorksheetName
            MetadataIncluded = $false
            Message          = $errorMessage
            ExportTime       = Get-Date
        }
    }
}

function ConvertTo-VirtToolkitExcelData {
    <#
    .SYNOPSIS
        Converts mixed data types to consistent format for Excel export.

    .DESCRIPTION
        ConvertTo-VirtToolkitExcelData normalizes hashtables, PSCustomObjects,
        and other data types into a consistent format suitable for Excel export.

    .PARAMETER Data
        Array of data objects to convert.

    .PARAMETER Properties
        Array of property names to include. If not specified, all properties are included.

    .OUTPUTS
        System.Array
        Returns array of PSCustomObjects ready for Excel export

    .EXAMPLE
        $data = @(@{Name="VM1"; CPUs=2}, @{Name="VM2"; CPUs=4})
        $converted = ConvertTo-VirtToolkitExcelData -Data $data

        Description
        -----------
        Converts hashtable array to PSCustomObject array
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Data,

        [Parameter(Mandatory = $false)]
        [string[]]$Properties
    )

    if ($Data.Count -eq 0) {
        return @()
    }

    # Determine properties to include
    if (-not $Properties) {
        # Get all unique properties from the data
        $allProperties = @()
        foreach ($item in $Data) {
            if ($item -is [hashtable]) {
                $allProperties += $item.Keys
            }
            elseif ($item -is [PSCustomObject] -or $item -is [PSObject]) {
                $allProperties += $item.PSObject.Properties.Name
            }
            else {
                # For other object types, get all properties
                $allProperties += $item | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name
            }
        }
        $Properties = $allProperties | Sort-Object -Unique
    }

    # Convert each item to PSCustomObject with consistent properties
    $convertedData = @()
    foreach ($item in $Data) {
        $obj = New-Object PSCustomObject
        
        foreach ($property in $Properties) {
            $value = $null
            
            if ($item -is [hashtable]) {
                $value = if ($item.ContainsKey($property)) { $item[$property] } else { $null }
            }
            elseif ($item -is [PSCustomObject] -or $item -is [PSObject]) {
                $value = if ($item.PSObject.Properties.Name -contains $property) { $item.$property } else { $null }
            }
            else {
                # For other object types
                try {
                    $value = $item.$property
                }
                catch {
                    $value = $null
                }
            }
            
            # Convert null values to empty string for better Excel display
            if ($null -eq $value) {
                $value = ""
            }
            
            $obj | Add-Member -MemberType NoteProperty -Name $property -Value $value
        }
        
        $convertedData += $obj
    }

    return $convertedData
}

function New-VirtToolkitExcelMetadata {
    <#
    .SYNOPSIS
        Creates standardized metadata for VirtToolkit Excel exports.

    .DESCRIPTION
        New-VirtToolkitExcelMetadata generates consistent metadata information
        that can be included in Excel exports for audit and tracking purposes.

    .PARAMETER ModuleName
        Name of the VirtToolkit module that generated the export.

    .PARAMETER Server
        Server name related to the export (e.g., vCenter server).

    .PARAMETER DataCount
        Number of records in the export.

    .PARAMETER AdditionalMetadata
        Hashtable of additional metadata key-value pairs.

    .OUTPUTS
        System.Array
        Returns array of metadata objects suitable for Excel export

    .EXAMPLE
        $metadata = New-VirtToolkitExcelMetadata -ModuleName "ListVMs" -Server "vcenter01.contoso.local" -DataCount 150

        Description
        -----------
        Creates standard metadata for a VM listing export
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ModuleName,

        [Parameter(Mandatory = $false)]
        [string]$Server,

        [Parameter(Mandatory = $false)]
        [int]$DataCount = 0,

        [Parameter(Mandatory = $false)]
        [hashtable]$AdditionalMetadata = @{}
    )

    # Import timestamp utility
    $loggingModule = Join-Path (Split-Path $PSScriptRoot -Parent) 'VirtToolkit.Logging.psm1'
    if (Test-Path $loggingModule) {
        Import-Module $loggingModule -Force
        $timestamp = Get-VirtToolkitTimestamp -Format 'Display'
    }
    else {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    }

    $metadata = @()

    # Core metadata
    $metadata += [PSCustomObject]@{ Property = "Export Date"; Value = $timestamp }
    $metadata += [PSCustomObject]@{ Property = "VirtToolkit Version"; Value = "4.1.0" }
    
    if ($ModuleName) {
        $metadata += [PSCustomObject]@{ Property = "Generated By"; Value = $ModuleName }
    }
    
    if ($Server) {
        $metadata += [PSCustomObject]@{ Property = "Source Server"; Value = $Server }
    }
    
    $metadata += [PSCustomObject]@{ Property = "Record Count"; Value = $DataCount }
    $metadata += [PSCustomObject]@{ Property = "Export User"; Value = "$env:USERDOMAIN\$env:USERNAME" }
    $metadata += [PSCustomObject]@{ Property = "Export Machine"; Value = $env:COMPUTERNAME }

    # Add additional metadata
    foreach ($key in $AdditionalMetadata.Keys) {
        $metadata += [PSCustomObject]@{ Property = $key; Value = $AdditionalMetadata[$key] }
    }

    return $metadata
}

function New-VirtToolkitExcelFileName {
    <#
    .SYNOPSIS
        Generates standardized Excel filenames for VirtToolkit exports.

    .DESCRIPTION
        New-VirtToolkitExcelFileName creates consistent filename patterns
        across all VirtToolkit modules with optional timestamps and prefixes.

    .PARAMETER BasePath
        Base directory path for the file.

    .PARAMETER ModuleName
        Name of the VirtToolkit module (used as filename prefix).

    .PARAMETER Server
        Server name to include in filename (optional).

    .PARAMETER IncludeTimestamp
        Include timestamp in filename. Default: $true

    .PARAMETER CustomPrefix
        Custom prefix instead of module name.

    .PARAMETER Extension
        File extension. Default: 'xlsx'

    .OUTPUTS
        System.String
        Returns full path to the Excel file

    .EXAMPLE
        $fileName = New-VirtToolkitExcelFileName -BasePath "C:\exports" -ModuleName "ListVMs" -Server "vcenter01"
        # Returns: C:\exports\ListVMs-vcenter01-20250130_143022.xlsx

    .EXAMPLE
        $fileName = New-VirtToolkitExcelFileName -BasePath "." -CustomPrefix "VMReport" -IncludeTimestamp:$false
        # Returns: .\VMReport.xlsx
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,

        [Parameter(Mandatory = $false)]
        [string]$ModuleName,

        [Parameter(Mandatory = $false)]
        [string]$Server,

        [Parameter(Mandatory = $false)]
        [bool]$IncludeTimestamp = $true,

        [Parameter(Mandatory = $false)]
        [string]$CustomPrefix,

        [Parameter(Mandatory = $false)]
        [string]$Extension = 'xlsx'
    )

    # Determine prefix
    $prefix = if ($CustomPrefix) {
        $CustomPrefix
    }
    elseif ($ModuleName) {
        $ModuleName
    }
    else {
        "VirtToolkit"
    }

    # Build filename components
    $components = @($prefix)
    
    if ($Server) {
        # Clean server name for filename
        $cleanServer = $Server -replace '[^a-zA-Z0-9.-]', ''
        $components += $cleanServer
    }
    
    if ($IncludeTimestamp) {
        # Import timestamp utility
        $loggingModule = Join-Path (Split-Path $PSScriptRoot -Parent) 'VirtToolkit.Logging.psm1'
        if (Test-Path $loggingModule) {
            Import-Module $loggingModule -Force
            $timestamp = Get-VirtToolkitTimestamp -Format 'FileExport'
        }
        else {
            $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        }
        $components += $timestamp
    }

    # Join components and add extension
    $filename = ($components -join '-') + ".$Extension"
    $fullPath = Join-Path -Path $BasePath -ChildPath $filename

    return $fullPath
}

# Export module functions
Export-ModuleMember -Function Export-VirtToolkitExcel, ConvertTo-VirtToolkitExcelData, New-VirtToolkitExcelMetadata, New-VirtToolkitExcelFileName
