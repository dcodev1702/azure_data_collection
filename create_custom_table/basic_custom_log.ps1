<#
.SYNOPSIS
Creates a deliberately small two-column Log Analytics custom table.

.DESCRIPTION
Use this as the first custom-table lab. The here-string payload makes the ARM REST
representation visible to the learner. Compare it with basic_custom_table_v2.ps1,
which produces the same payload from PowerShell objects.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)][string]$ResourceGroup,
    [Parameter(Mandatory)][string]$WorkspaceName,
    [string]$TableName = 'SuricataTmp_CL',
    [ValidateSet('Analytics', 'Basic', 'Auxiliary')]
    [string]$Plan = 'Analytics',
    [ValidateRange(30, 730)][int]$RetentionInDays = 30,
    [ValidateRange(30, 2556)][int]$TotalRetentionInDays = 180
)

$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext -ErrorAction SilentlyContinue)) {
    throw 'Connect-AzAccount before creating a table.'
}
if ($RetentionInDays -gt $TotalRetentionInDays) {
    throw 'TotalRetentionInDays must be greater than or equal to RetentionInDays.'
}

$subscriptionId = (Get-AzContext).Subscription.Id
$path = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName/tables/$TableName"
$payload = @"
{
  "properties": {
    "schema": {
      "name": "$TableName",
      "columns": [
        { "name": "TimeGenerated", "type": "datetime" },
        { "name": "RawData", "type": "string" }
      ]
    },
    "plan": "$Plan",
    "retentionInDays": $RetentionInDays,
    "totalRetentionInDays": $TotalRetentionInDays
  }
}
"@

if ($PSCmdlet.ShouldProcess($TableName, 'Create or update custom table')) {
    $response = Invoke-AzRestMethod -Path "$path`?api-version=2023-09-01" -Method PUT -Payload $payload
    if ($response.StatusCode -notin 200, 201, 202) {
        throw "Table deployment failed: HTTP $($response.StatusCode) $($response.Content)"
    }
    Write-Host "Table '$TableName' is available in workspace '$WorkspaceName'." -ForegroundColor Green
}
