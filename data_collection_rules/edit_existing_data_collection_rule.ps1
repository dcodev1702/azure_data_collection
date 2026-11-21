<#
.SYNOPSIS
Exports or imports a Data Collection Rule without embedding authentication.

.DESCRIPTION
The Get action exports a deployment-safe representation of a DCR. The Set action
validates a JSON file, removes read-only Azure response fields, previews the
operation with ShouldProcess, and updates the existing DCR.

.EXAMPLE
Invoke-DCRModify -DCR_Action Get -ResourceGroup rg-training -DcrName training-dcr

.EXAMPLE
Invoke-DCRModify -DCR_Action Set -ResourceGroup rg-training -DcrName training-dcr `
  -DcrJsonPath ./training-dcr.json
#>
function Invoke-DCRModify {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Get', 'Set')]
        [string]$DCR_Action,

        [Parameter(Mandatory)][string]$ResourceGroup,
        [Parameter(Mandatory)][string]$DcrName,
        [string]$DcrJsonPath = "./$DcrName.json"
    )

    $ErrorActionPreference = 'Stop'
    if (-not (Get-AzContext -ErrorAction SilentlyContinue)) {
        throw 'Connect-AzAccount before editing a DCR.'
    }

    $subscriptionId = (Get-AzContext).Subscription.Id
    $dcrPath = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/dataCollectionRules/$DcrName"
    $dcrUrl = "$dcrPath`?api-version=2023-03-11"

    if ($DCR_Action -eq 'Get') {
        if ($PSCmdlet.ShouldProcess($DcrName, 'Export data collection rule')) {
            $response = Invoke-AzRestMethod -Path $dcrUrl -Method GET
            if ($response.StatusCode -ne 200) {
                throw "DCR export failed with HTTP $($response.StatusCode): $($response.Content)"
            }
            $dcr = $response.Content | ConvertFrom-Json -Depth 100
            foreach ($field in @('id', 'name', 'type', 'systemData', 'etag')) {
                $null = $dcr.PSObject.Properties.Remove($field)
            }
            foreach ($field in @('provisioningState', 'immutableId', 'endpoints')) {
                $null = $dcr.properties.PSObject.Properties.Remove($field)
            }
            $json = $dcr | ConvertTo-Json -Depth 100
            $json | Set-Content -Path $DcrJsonPath -Encoding UTF8
            Write-Host "Exported '$DcrName' to '$DcrJsonPath'." -ForegroundColor Green
            return Get-Item $DcrJsonPath
        }
        return
    }

    if (-not (Test-Path $DcrJsonPath -PathType Leaf)) {
        throw "DCR file '$DcrJsonPath' does not exist."
    }
    $dcr = try {
        Get-Content -Path $DcrJsonPath -Raw | ConvertFrom-Json -Depth 100 -ErrorAction Stop
    } catch {
        throw "DCR file '$DcrJsonPath' is not valid JSON: $($_.Exception.Message)"
    }

    if (-not $dcr.location -or -not $dcr.properties) {
        throw "DCR file '$DcrJsonPath' must contain location and properties."
    }
    foreach ($field in @('id', 'name', 'type', 'systemData', 'etag')) {
        $null = $dcr.PSObject.Properties.Remove($field)
    }
    foreach ($field in @('provisioningState', 'immutableId', 'endpoints')) {
        $null = $dcr.properties.PSObject.Properties.Remove($field)
    }

    $payload = $dcr | ConvertTo-Json -Depth 100 -Compress
    if ($PSCmdlet.ShouldProcess($DcrName, 'Update data collection rule from JSON')) {
        $response = Invoke-AzRestMethod -Path $dcrUrl -Method PUT -Payload $payload
        if ($response.StatusCode -notin 200, 201, 202) {
            throw "DCR update failed with HTTP $($response.StatusCode): $($response.Content)"
        }
        Write-Host "Updated '$DcrName' from '$DcrJsonPath'." -ForegroundColor Green
    }
}
