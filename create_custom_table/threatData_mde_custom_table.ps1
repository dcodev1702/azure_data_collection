<#
.SYNOPSIS
Creates the destination table for the Microsoft Defender for Endpoint threat-data example.

.DESCRIPTION
The matching Direct DCR declares source field "title". Its transform renames that
field to "ThreatTitle", so the table contains only the transformed name.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)][string]$ResourceGroup,
    [Parameter(Mandatory)][string]$WorkspaceName,
    [string]$TableName = 'ThreatData_MDE_CL',
    [ValidateRange(30, 730)][int]$RetentionInDays = 120,
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
$columns = @(
    @{ name = 'TimeGenerated'; type = 'datetime' },
    @{ name = 'id'; type = 'string' },
    @{ name = 'incidentId'; type = 'long' },
    @{ name = 'investigationId'; type = 'long' },
    @{ name = 'assignedTo'; type = 'string' },
    @{ name = 'severity'; type = 'string' },
    @{ name = 'status'; type = 'string' },
    @{ name = 'classification'; type = 'string' },
    @{ name = 'determination'; type = 'string' },
    @{ name = 'investigationState'; type = 'string' },
    @{ name = 'detectionSource'; type = 'string' },
    @{ name = 'detectorId'; type = 'string' },
    @{ name = 'category'; type = 'string' },
    @{ name = 'threatFamilyName'; type = 'string' },
    @{ name = 'ThreatTitle'; type = 'string' },
    @{ name = 'description'; type = 'string' },
    @{ name = 'alertCreationTime'; type = 'datetime' },
    @{ name = 'firstEventTime'; type = 'datetime' },
    @{ name = 'lastEventTime'; type = 'datetime' },
    @{ name = 'lastUpdateTime'; type = 'datetime' },
    @{ name = 'resolvedTime'; type = 'datetime' },
    @{ name = 'machineId'; type = 'string' },
    @{ name = 'computerDnsName'; type = 'string' },
    @{ name = 'rbacGroupName'; type = 'string' },
    @{ name = 'aadTenantId'; type = 'string' },
    @{ name = 'threatName'; type = 'string' },
    @{ name = 'mitreTechniques'; type = 'dynamic' },
    @{ name = 'relatedUser'; type = 'string' },
    @{ name = 'loggedOnUsers'; type = 'dynamic' },
    @{ name = 'comments'; type = 'dynamic' },
    @{ name = 'evidence'; type = 'dynamic' },
    @{ name = 'domains'; type = 'dynamic' }
)
$payload = @{
    properties = @{
        schema = @{ name = $TableName; columns = $columns }
        plan = 'Analytics'
        retentionInDays = $RetentionInDays
        totalRetentionInDays = $TotalRetentionInDays
    }
} | ConvertTo-Json -Depth 30 -Compress

if ($PSCmdlet.ShouldProcess($TableName, 'Create or update threat-data table')) {
    $response = Invoke-AzRestMethod -Path "$path`?api-version=2023-09-01" -Method PUT -Payload $payload
    if ($response.StatusCode -notin 200, 201, 202) {
        throw "Table deployment failed: HTTP $($response.StatusCode) $($response.Content)"
    }
    Write-Host "Threat-data table '$TableName' deployed." -ForegroundColor Green
}
