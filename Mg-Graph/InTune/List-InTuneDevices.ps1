<#
.SYNOPSIS
    Author: DCODEV1702
    Date: 03/31/2025
    Version: 0.2.1beta

    List-InTuneDevices retrieves Intune managed devices from Microsoft Graph API.
    Basic PowerShell script to retrieve all devices from Microsoft Graph API using the Microsoft Graph PowerShell SDK.
    The script checks if the user is authenticated, retrieves the devices, and outputs them in various formats.
    It also handles errors and provides feedback to the user.

.DESCRIPTION
    List-InTuneDevices will:
    1) Determine the Microsoft Graph base URI based on the -Environment parameter
    2) Connect to Graph with user-based delegated credentials
    3) Retrieve all Intune Managed Devices (following nextLink if >100 devices)
    4) Save the result to CSV & JSON, then return the in-memory objects

.PARAMETER Environment
    - USGov
    - Germany
    - USGovDoD
    - Global

.EXAMPLE
    PS> List-InTuneDevices -Environment USGov

    Retrieves Intune managed devices from the USGov environment 
    (graph.microsoft.us), outputs to IntuneDevices.csv & IntuneDevices.json, 
    and returns the device objects for further use in PowerShell.

.EXAMPLE
    PS> $devices = List-InTuneDevices -Environment Global
    PS> $devices.Count
    PS> $devices | Format-Table
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

    $context = Get-MgContext
    if ($context -eq $null) {
        Write-Host "No context found. Please authenticate to Microsoft Graph."
        Connect-MgGraph -Scopes "User.Read.All", "Directory.Read.All", "DeviceManagementManagedDevices.Read.All" -TenantId 'c51a30d6-028b-45bd-9af6-09e0ab30cc80' -Environment $Environment
    }

    Write-Host "Retrieving all devices from Microsoft Graph API..."
    # ------------------------------------------------------------------------
    # 2) Query Intune Managed Devices (following nextLink for paging)
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
    # 3) Output the devices to CSV and JSON
    # ------------------------------------------------------------------------
    $allDevices | Export-Csv -Path $CsvOutputPath -NoTypeInformation
    $allDevices | ConvertTo-Json -Depth 25 | Out-File $JsonOutputPath -Encoding UTF8

    Write-Host "Devices exported to CSV:   $CsvOutputPath"
    Write-Host "Devices exported to JSON: $JsonOutputPath"

    # Return the collection as well, in case the caller wants to process them
    return $allDevices
    
}
