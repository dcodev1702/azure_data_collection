<#
.SYNOPSIS
Creates a nested-field custom table that matches the repository JSON fixtures.

.DESCRIPTION
The default Auxiliary plan makes this a useful comparison with the canonical
Analytics lab. Change -Plan to compare the same schema under another supported plan.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)][string]$ResourceGroup,
    [Parameter(Mandatory)][string]$WorkspaceName,
    [string]$TableName = 'PJL_HAWK_AUX_CL',
    [ValidateSet('Analytics', 'Basic', 'Auxiliary')]
    [string]$Plan = 'Auxiliary',
    [ValidateRange(30, 730)][int]$RetentionInDays = 120,
    [ValidateRange(30, 2556)][int]$TotalRetentionInDays = 730
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
$columns = @(
    @{ name = 'TimeGenerated'; type = 'datetime'; description = 'Time the event was ingested' },
    @{ name = 'Name'; type = 'string'; description = 'Source record name' },
    @{ name = 'Source'; type = 'string'; description = 'Producer or ingestion channel' },
    @{ name = 'Version'; type = 'string'; description = 'Source record version' },
    @{ name = 'OS'; type = 'string'; description = 'Operating system label' },
    @{ name = 'Hardware'; type = 'dynamic'; description = 'Nested hardware object' },
    @{ name = 'Distro'; type = 'dynamic'; description = 'Nested distribution object' },
    @{ name = 'OSVersion'; type = 'string'; description = 'Operating system version' },
    @{ name = 'OSArchitecture'; type = 'string'; description = 'Operating system architecture' },
    @{ name = 'GenAI'; type = 'string'; description = 'Associated model label' }
)
$payload = @{
    properties = @{
        schema = @{ name = $TableName; columns = $columns }
        plan = $Plan
        retentionInDays = $RetentionInDays
        totalRetentionInDays = $TotalRetentionInDays
    }
} | ConvertTo-Json -Depth 30 -Compress

if ($PSCmdlet.ShouldProcess($TableName, 'Create or update custom table')) {
    $response = Invoke-AzRestMethod -Path "$path`?api-version=2023-09-01" -Method PUT -Payload $payload
    if ($response.StatusCode -notin 200, 201, 202) {
        throw "Table deployment failed: HTTP $($response.StatusCode) $($response.Content)"
    }
    Write-Host "Table '$TableName' deployed with plan '$Plan'." -ForegroundColor Green
}
