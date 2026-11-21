<#
.SYNOPSIS
Creates the same two-column custom table as basic_custom_log.ps1.

.DESCRIPTION
This variant demonstrates how to build an ARM REST payload from PowerShell
hashtables. Use ConvertTo-Json instead of interpolation when payload values or
descriptions are sourced from structured configuration.
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
$payload = @{
    properties = @{
        schema = @{
            name = $TableName
            columns = @(
                @{ name = 'TimeGenerated'; type = 'datetime' }
                @{ name = 'RawData'; type = 'string' }
            )
        }
        plan = $Plan
        retentionInDays = $RetentionInDays
        totalRetentionInDays = $TotalRetentionInDays
    }
} | ConvertTo-Json -Depth 20 -Compress

if ($PSCmdlet.ShouldProcess($TableName, 'Create or update custom table')) {
    $response = Invoke-AzRestMethod -Path "$path`?api-version=2023-09-01" -Method PUT -Payload $payload
    if ($response.StatusCode -notin 200, 201, 202) {
        throw "Table deployment failed: HTTP $($response.StatusCode) $($response.Content)"
    }
    Write-Host "Table '$TableName' is available in workspace '$WorkspaceName'." -ForegroundColor Green
}
