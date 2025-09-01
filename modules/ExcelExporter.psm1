#Requires -Version 5.1

<#
.SYNOPSIS
    Excel export module for the VM listing toolkit
.DESCRIPTION
    This module provides functions to export VM data to Excel with custom formatting
.AUTHOR
    VM Listing Toolkit
.VERSION
    1.0.0
#>

function Export-VMsToExcel {
    <#
    .SYNOPSIS
        Exports VM data to an Excel file with custom headers
    .PARAMETER VMData
        Array of VM data hashtables
    .PARAMETER FilePath
        Path where the Excel file will be saved
    .PARAMETER SourceServerHost
        vCenter server hostname for the header
    .PARAMETER DataCenter
        Datacenter name for the header
    .PARAMETER VMFolder
        VM folder path for the header
    .PARAMETER Properties
        Array of property names for the column headers
    .OUTPUTS
        [bool] True if export succeeded, False otherwise
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$VMData,
        
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [Parameter(Mandatory = $true)]
        [string]$SourceServerHost,
        
        [Parameter(Mandatory = $true)]
        [string]$DataCenter,
        
        [Parameter(Mandatory = $true)]
        [string]$VMFolder,
        
        [Parameter(Mandatory = $true)]
        [string[]]$Properties
    )
    
    try {
        Write-Host "Exporting VM data to Excel: $FilePath" -ForegroundColor Blue
        
        # Ensure the directory exists
        $directory = Split-Path -Path $FilePath -Parent
        if (-not (Test-Path -Path $directory)) {
            New-Item -Path $directory -ItemType Directory -Force | Out-Null
        }
        
        # Remove existing file if it exists
        if (Test-Path -Path $FilePath) {
            Remove-Item -Path $FilePath -Force
        }
        
        # Create the Excel package
        $excel = New-Object -TypeName OfficeOpenXml.ExcelPackage
        $worksheet = $excel.Workbook.Worksheets.Add("VM_List")
        
        # Set up the first header row (combined header)
        $combinedHeader = "$SourceServerHost - $DataCenter - $VMFolder"
        $worksheet.Cells[1, 1].Value = $combinedHeader
        
        # Merge cells for the first header row
        $lastColumn = $Properties.Count
        $worksheet.Cells[1, 1, 1, $lastColumn].Merge = $true
        
        # Format the first header row
        $headerRange1 = $worksheet.Cells[1, 1, 1, $lastColumn]
        $headerRange1.Style.Font.Bold = $true
        $headerRange1.Style.Font.Size = 14
        $headerRange1.Style.HorizontalAlignment = [OfficeOpenXml.Style.ExcelHorizontalAlignment]::Center
        $headerRange1.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
        $headerRange1.Style.Fill.BackgroundColor.SetColor([System.Drawing.Color]::LightBlue)
        $headerRange1.Style.Border.BorderAround([OfficeOpenXml.Style.ExcelBorderStyle]::Medium)
        
        # Set up the second header row (property names)
        for ($i = 0; $i -lt $Properties.Count; $i++) {
            $worksheet.Cells[2, $i + 1].Value = $Properties[$i]
        }
        
        # Format the second header row
        $headerRange2 = $worksheet.Cells[2, 1, 2, $Properties.Count]
        $headerRange2.Style.Font.Bold = $true
        $headerRange2.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
        $headerRange2.Style.Fill.BackgroundColor.SetColor([System.Drawing.Color]::LightGray)
        $headerRange2.Style.Border.BorderAround([OfficeOpenXml.Style.ExcelBorderStyle]::Thin)
        
        # Add VM data rows
        $row = 3
        foreach ($vm in $VMData) {
            for ($col = 0; $col -lt $Properties.Count; $col++) {
                $propertyName = $Properties[$col]
                $value = if ($vm.ContainsKey($propertyName)) { $vm[$propertyName] } else { "NULL" }
                $worksheet.Cells[$row, $col + 1].Value = $value
            }
            $row++
        }
        
        # Auto-fit columns
        $worksheet.Cells.AutoFitColumns()
        
        # Add borders to data
        if ($VMData.Count -gt 0) {
            $dataRange = $worksheet.Cells[2, 1, $row - 1, $Properties.Count]
            $dataRange.Style.Border.Top.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $dataRange.Style.Border.Bottom.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $dataRange.Style.Border.Left.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $dataRange.Style.Border.Right.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
        }
        
        # Add metadata as a comment or additional worksheet
        $metadataWorksheet = $excel.Workbook.Worksheets.Add("Metadata")
        $metadataWorksheet.Cells[1, 1].Value = "Export Information"
        $metadataWorksheet.Cells[1, 1].Style.Font.Bold = $true
        $metadataWorksheet.Cells[2, 1].Value = "Generated Date:"
        $metadataWorksheet.Cells[2, 2].Value = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $metadataWorksheet.Cells[3, 1].Value = "vCenter Server:"
        $metadataWorksheet.Cells[3, 2].Value = $SourceServerHost
        $metadataWorksheet.Cells[4, 1].Value = "Datacenter:"
        $metadataWorksheet.Cells[4, 2].Value = $DataCenter
        $metadataWorksheet.Cells[5, 1].Value = "VM Folder:"
        $metadataWorksheet.Cells[5, 2].Value = $VMFolder
        $metadataWorksheet.Cells[6, 1].Value = "Total VMs:"
        $metadataWorksheet.Cells[6, 2].Value = $VMData.Count
        $metadataWorksheet.Cells.AutoFitColumns()
        
        # Save the Excel file
        $fileInfo = New-Object System.IO.FileInfo($FilePath)
        $excel.SaveAs($fileInfo)
        $excel.Dispose()
        
        Write-Host "✓ Successfully exported $($VMData.Count) VMs to Excel file: $FilePath" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Error exporting VM data to Excel: $($_.Exception.Message)"
        if ($excel) {
            $excel.Dispose()
        }
        return $false
    }
}

function Export-VMsToExcelSimple {
    <#
    .SYNOPSIS
        Exports VM data to Excel using the ImportExcel module (simpler approach)
    .PARAMETER VMData
        Array of VM data hashtables
    .PARAMETER FilePath
        Path where the Excel file will be saved
    .PARAMETER SourceServerHost
        vCenter server hostname for the header
    .PARAMETER DataCenter
        Datacenter name for the header
    .PARAMETER VMFolder
        VM folder path for the header
    .PARAMETER Properties
        Array of property names for the column headers
    .OUTPUTS
        [bool] True if export succeeded, False otherwise
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$VMData,
        
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [Parameter(Mandatory = $true)]
        [string]$SourceServerHost,
        
        [Parameter(Mandatory = $true)]
        [string]$DataCenter,
        
        [Parameter(Mandatory = $true)]
        [string]$VMFolder,
        
        [Parameter(Mandatory = $true)]
        [string[]]$Properties
    )
    
    try {
        Write-Host "Exporting VM data to Excel: $FilePath" -ForegroundColor Blue
        
        # Ensure the directory exists
        $directory = Split-Path -Path $FilePath -Parent
        if (-not (Test-Path -Path $directory)) {
            New-Item -Path $directory -ItemType Directory -Force | Out-Null
        }
        
        # Remove existing file if it exists
        if (Test-Path -Path $FilePath) {
            Remove-Item -Path $FilePath -Force
        }
        
        # Convert hashtables to PSCustomObjects for better Excel export
        $vmObjects = @()
        foreach ($vm in $VMData) {
            $vmObject = New-Object PSObject
            foreach ($property in $Properties) {
                $value = if ($vm.ContainsKey($property)) { $vm[$property] } else { "NULL" }
                $vmObject | Add-Member -MemberType NoteProperty -Name $property -Value $value
            }
            $vmObjects += $vmObject
        }
        
        # Create the combined header information
        $combinedHeader = "$SourceServerHost - $DataCenter - $VMFolder"
        
        # Export to Excel with custom formatting
        $vmObjects | Export-Excel -Path $FilePath -WorksheetName "VM_List" -Title $combinedHeader -TitleSize 14 -TitleBold -AutoSize -FreezeTopRow -BoldTopRow
        
        # Add metadata sheet
        $metadata = @(
            [PSCustomObject]@{Property = "Generated Date"; Value = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")},
            [PSCustomObject]@{Property = "vCenter Server"; Value = $SourceServerHost},
            [PSCustomObject]@{Property = "Datacenter"; Value = $DataCenter},
            [PSCustomObject]@{Property = "VM Folder"; Value = $VMFolder},
            [PSCustomObject]@{Property = "Total VMs"; Value = $VMData.Count}
        )
        
        $metadata | Export-Excel -Path $FilePath -WorksheetName "Metadata" -AutoSize -BoldTopRow
        
        Write-Host "✓ Successfully exported $($VMData.Count) VMs to Excel file: $FilePath" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Error exporting VM data to Excel: $($_.Exception.Message)"
        return $false
    }
}

function New-ExcelFileName {
    <#
    .SYNOPSIS
        Generates a unique Excel filename based on current timestamp
    .PARAMETER BasePath
        Base directory path for the file
    .PARAMETER Prefix
        Prefix for the filename (default: "VMList")
    .OUTPUTS
        [string] Full path to the Excel file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,
        
        [Parameter(Mandatory = $false)]
        [string]$Prefix = "VMList"
    )
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $fileName = "${Prefix}_${timestamp}.xlsx"
    $fullPath = Join-Path -Path $BasePath -ChildPath $fileName
    
    return $fullPath
}

# Export functions
Export-ModuleMember -Function @(
    'Export-VMsToExcel',
    'Export-VMsToExcelSimple',
    'New-ExcelFileName'
)
