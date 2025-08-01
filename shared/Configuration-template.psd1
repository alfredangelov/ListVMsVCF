@{
    # If $true, actions will be simulated and no changes will be made
    DryRun                = $true

    # vSphere source server connection details
    SourceServerHost      = 'vcenter.example.com'
    vCenterVersion        = '8.0'  # vCenter version (affects API endpoint availability) - Options: '6.7', '7.0', '8.0'

    # Permission export options
    ExportGlobalPermissions = $true  # Export global permissions
    ExportNormalPermissions = $false # Export normal (object-level) permissions
    
    # SSO Analysis options
    EnableSsoAnalysis = $false                       # Analyze SSO groups for external domain members
 
    # Permission filtering options
    EnablePermissionExclusion = $false                    # Set to $true to enable exclusion filtering
    #ExclusionFilePath = 'exclude-permissions.txt'       # Path to exclusion file (relative to script root)
    
    # Optional: Tooltip configuration
    EnableTooltips = $false        # Set to $true to auto-enhance reports with tooltips
    TooltipTheme = 'Dark'          # Options: Dark, Light, Blue
    TooltipMaxWidth = 320          # Maximum tooltip width in pixels
    TooltipChunkSize = 300         # Number of tooltips to process per chunk (helps manage memory)
}
