<#
.SYNOPSIS
Creates an Auxiliary custom table matching the Windows event DCR example.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)][string]$ResourceGroup,
    [Parameter(Mandatory)][string]$WorkspaceName,
    [string]$TableName = 'MSEVENT_AUX_CL',
    [ValidateRange(30, 2556)][int]$TotalRetentionInDays = 730
)

$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext -ErrorAction SilentlyContinue)) {
    throw 'Connect-AzAccount before creating a table.'
}

$subscriptionId = (Get-AzContext).Subscription.Id
$path = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName/tables/$TableName"
$columns = @(
    @{ name = 'SourceSystem'; type = 'string' },
    @{ name = 'TimeGenerated'; type = 'datetime' },
    @{ name = 'Source'; type = 'string' },
    @{ name = 'EventLog'; type = 'string' },
    @{ name = 'Computer'; type = 'string' },
    @{ name = 'EventLevel'; type = 'int' },
    @{ name = 'EventLevelName'; type = 'string' },
    @{ name = 'ParameterXml'; type = 'string' },
    @{ name = 'EventData'; type = 'string' },
    @{ name = 'EventID'; type = 'int' },
    @{ name = 'RenderedDescription'; type = 'string' },
    @{ name = 'AzureDeploymentID'; type = 'string' },
    @{ name = 'Role'; type = 'string' },
    @{ name = 'EventCategory'; type = 'int' },
    @{ name = 'UserName'; type = 'string' },
    @{ name = 'Message'; type = 'string' },
    @{ name = 'ManagementGroupName'; type = 'string' }
)
$payload = @{
    properties = @{
        schema = @{ name = $TableName; columns = $columns }
        plan = 'Auxiliary'
        totalRetentionInDays = $TotalRetentionInDays
    }
} | ConvertTo-Json -Depth 20 -Compress

if ($PSCmdlet.ShouldProcess($TableName, 'Create or update Auxiliary custom table')) {
    $response = Invoke-AzRestMethod -Path "$path`?api-version=2023-09-01" -Method PUT -Payload $payload
    if ($response.StatusCode -notin 200, 201, 202) {
        throw "Table deployment failed: HTTP $($response.StatusCode) $($response.Content)"
    }
    Write-Host "Auxiliary table '$TableName' deployed." -ForegroundColor Green
}
