<#
    Basic PowerShell script to retrieve all devices from Microsoft Graph API using the Microsoft Graph PowerShell SDK.
    The script checks if the user is authenticated, retrieves the devices, and outputs them in various formats.
    It also handles errors and provides feedback to the user.
    
    Sources:
    https://learn.microsoft.com/en-us/graph/api/intune-devices-manageddevice-list?view=graph-rest-1.0"
    https://learn.microsoft.com/en-us/graph/deployments"
#>

if (-not (get-mgcontext)) {
    Write-Host "No context found. Please authenticate to Microsoft Graph."
    Connect-MgGraph -Scopes "User.Read.All", "Directory.Read.All, DeviceManagementManagedDevices.Read.All" -TenantId 'c51a30d6-028b-45bd-9af6-09e0ab30cc80' -Environment USGov
}

$graphApiBaseUri = "https://graph.microsoft.us"
$response = Invoke-MgGraphRequest -Uri "$graphApiBaseUri/v1.0/deviceManagement/managedDevices" -Method GET


Write-Host "Retrieving all devices from Microsoft Graph API..."

# Let's assume $response is from your Invoke-MgGraphRequest
# (i.e., $response = Invoke-MgGraphRequest -Uri '/v1.0/deviceManagement/managedDevices' ...)

# Create a list of PS custom objects, one per device
$devices = foreach ($item in $response.Value) {
    # Build a hashtable of properties for the new custom object
    $props = @{}
    foreach ($kvp in $item.GetEnumerator()) {
        $props[$kvp.Key] = $kvp.Value
    }

    # Convert to a PSCustomObject
    New-Object -TypeName PSObject -Property $props
}

# Now $devices holds a list of strongly-typed PSObjects
# You can see them in a table, or any other format
$devices | Format-Table

# Or get one device:
$devices[0] | Format-List *

# Or export to CSV, JSON, etc.
$devices | Export-Csv -Path 'devices.csv' -NoTypeInformation
$devices | ConvertTo-Json -Depth 25 | Out-File -FilePath 'devices.json' -Encoding utf8 
