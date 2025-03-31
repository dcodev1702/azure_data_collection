<#
    Basic PowerShell script to retrieve all devices from Microsoft Graph API using the Microsoft Graph PowerShell SDK.
    The script checks if the user is authenticated, retrieves the devices, and outputs them in various formats.
    It also handles errors and provides feedback to the user.
#>
function List-InTuneDevices {
    [CmdletBinding()]
    param(
        # Restrict valid environment choices
        [Parameter(Mandatory = $true)]
        [ValidateSet("USGov", "Germany", "USGovDoD", "Global")]
        [string] $Environment,

        # Optional parameters to control file output locations
        [string] $CsvOutputPath  = "$PWD\InTuneDevices.csv",
        [string] $JsonOutputPath = "$PWD\InTuneDevices.json"
    )

    # ------------------------------------------------------------------------
    # 1) Pick the correct Graph base URI for the chosen environment
    # ------------------------------------------------------------------------
    switch ($Environment) {
        "USGov"    { $graphApiBaseUri = "https://graph.microsoft.us" }
        "Germany"  { $graphApiBaseUri = "https://graph.microsoft.de" }
        "USGovDoD" { $graphApiBaseUri = "https://dod-graph.microsoft.us" }
        "Global"   { $graphApiBaseUri = "https://graph.microsoft.com" }
    }

    if (-not (get-mgcontext)) {
        Write-Host "No context found. Please authenticate to Microsoft Graph."
        Connect-MgGraph -Scopes "User.Read.All", "Directory.Read.All, DeviceManagementManagedDevices.Read.All" -TenantId 'c51a30d6-028b-45bd-9af6-09e0ab30cc80' -Environment $Environment
    }

    $response = Invoke-MgGraphRequest -Uri "$graphApiBaseUri/v1.0/deviceManagement/managedDevices" -Method GET


    Write-Host "Retrieving all devices from Microsoft Graph API..."

    # Let's assume $response is from your Invoke-MgGraphRequest
    # (i.e., $response = Invoke-MgGraphRequest -Uri '/v1.0/deviceManagement/managedDevices' ...)

    # Create a list of PS custom objects, one per device
    <# $devices = foreach ($item in $response.Value) {
        # Build a hashtable of properties for the new custom object
        $props = @{}
        foreach ($kvp in $item.GetEnumerator()) {
            $props[$kvp.Key] = $kvp.Value
        }

        # Convert to a PSCustomObject
        New-Object -TypeName PSObject -Property $props
    } 
    #>

    # ------------------------------------------------------------------------
    # 3) Query Intune Managed Devices (following nextLink for paging)
    # ------------------------------------------------------------------------
    $allDevices = @()
    $nextLink   = "$graphApiBaseUri/v1.0/deviceManagement/managedDevices"

    while ($nextLink) {
        # Call Microsoft Graph using the dynamic base URL
        $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET

        # Convert each returned hashtable into a PSCustomObject
        $allDevices += foreach ($item in $response.Value) {
            $props = @{}
            foreach ($kvp in $item.GetEnumerator()) {
                $props[$kvp.Key] = $kvp.Value
            }
            New-Object -TypeName PSObject -Property $props
        }

        # Move on to the next page if '@odata.nextLink' is present
        $nextLink = $response.'@odata.nextLink'
    }

    # ------------------------------------------------------------------------
    # 4) Output the devices to CSV and JSON
    # ------------------------------------------------------------------------
    $allDevices | Export-Csv -Path $CsvOutputPath -NoTypeInformation
    $allDevices | ConvertTo-Json -Depth 25 | Out-File $JsonOutputPath -Encoding UTF8

    Write-Host "Devices exported to CSV:   $CsvOutputPath"
    Write-Host "Devices exported to JSON: $JsonOutputPath"

    # Return the collection as well, in case the caller wants to process them
    return $allDevices
    
}
