[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [string]$TableName = 'CsaTraining_CL',
    [string]$DcrName = 'csa-training-direct-dcr',
    [ValidateRange(30, 730)]
    [int]$RetentionInDays = 30,
    [ValidateRange(30, 2556)]
    [int]$TotalRetentionInDays = 30
)

$ErrorActionPreference = 'Stop'

if (-not (Get-AzContext -ErrorAction SilentlyContinue)) {
    throw 'Connect-AzAccount before running this lab.'
}

if ($RetentionInDays -gt $TotalRetentionInDays) {
    throw 'TotalRetentionInDays must be greater than or equal to RetentionInDays.'
}

$subscriptionId = (Get-AzContext).Subscription.Id
$workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroup -Name $WorkspaceName
$workspaceId = $workspace.ResourceId
$tablePath = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName/tables/$TableName"
$dcrPath = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/dataCollectionRules/$DcrName"
$logicalName = $TableName -replace '_CL$', ''
$inputStream = "Custom-$logicalName"
$outputStream = "Custom-$TableName"

$tablePayload = @{
    properties = @{
        schema = @{
            name = $TableName
            columns = @(
                @{ name = 'TimeGenerated'; type = 'datetime' }
                @{ name = 'Name'; type = 'string' }
                @{ name = 'Source'; type = 'string' }
                @{ name = 'Version'; type = 'string' }
                @{ name = 'OS'; type = 'string' }
                @{ name = 'Hardware'; type = 'dynamic' }
                @{ name = 'Distro'; type = 'dynamic' }
                @{ name = 'OSVersion'; type = 'string' }
                @{ name = 'OSArchitecture'; type = 'string' }
                @{ name = 'GenAI'; type = 'string' }
            )
        }
        plan = 'Analytics'
        retentionInDays = $RetentionInDays
        totalRetentionInDays = $TotalRetentionInDays
    }
} | ConvertTo-Json -Depth 20 -Compress

$dcrPayload = @{
    location = $Location
    kind = 'Direct'
    properties = @{
        streamDeclarations = @{
            $inputStream = @{
                columns = @(
                    @{ name = 'Name'; type = 'string' }
                    @{ name = 'Source'; type = 'string' }
                    @{ name = 'Version'; type = 'string' }
                    @{ name = 'OS'; type = 'string' }
                    @{ name = 'Hardware'; type = 'dynamic' }
                    @{ name = 'Distro'; type = 'dynamic' }
                    @{ name = 'OSVersion'; type = 'string' }
                    @{ name = 'OSArchitecture'; type = 'string' }
                    @{ name = 'GenAI'; type = 'string' }
                )
            }
        }
        destinations = @{
            logAnalytics = @(
                @{
                    workspaceResourceId = $workspaceId
                    name = 'lawDestination'
                }
            )
        }
        dataFlows = @(
            @{
                streams = @($inputStream)
                destinations = @('lawDestination')
                transformKql = 'source | extend TimeGenerated = now()'
                outputStream = $outputStream
            }
        )
    }
} | ConvertTo-Json -Depth 30 -Compress

if ($PSCmdlet.ShouldProcess($tablePath, 'Create or update custom table')) {
    $tableResponse = Invoke-AzRestMethod -Path "$tablePath`?api-version=2023-09-01" -Method PUT -Payload $tablePayload
    if ($tableResponse.StatusCode -notin 200, 201, 202) {
        throw "Table deployment failed with status $($tableResponse.StatusCode): $($tableResponse.Content)"
    }
}

if (-not $WhatIfPreference) {
    for ($attempt = 1; $attempt -le 12; $attempt++) {
        $tableRead = Invoke-AzRestMethod -Path "$tablePath`?api-version=2023-09-01" -Method GET
        if ($tableRead.StatusCode -eq 200) {
            $table = $tableRead.Content | ConvertFrom-Json -Depth 50
            if (-not $table.properties.provisioningState -or $table.properties.provisioningState -eq 'Succeeded') {
                break
            }
        }
        if ($attempt -eq 12) {
            throw "Table '$TableName' did not become ready."
        }
        Start-Sleep -Seconds 5
    }
}

if ($PSCmdlet.ShouldProcess($dcrPath, 'Create or update Direct data collection rule')) {
    $dcrResponse = Invoke-AzRestMethod -Path "$dcrPath`?api-version=2023-03-11" -Method PUT -Payload $dcrPayload
    if ($dcrResponse.StatusCode -notin 200, 201, 202) {
        throw "DCR deployment failed with status $($dcrResponse.StatusCode): $($dcrResponse.Content)"
    }
}

if ($WhatIfPreference) {
    return
}

for ($attempt = 1; $attempt -le 12; $attempt++) {
    $dcrResult = Invoke-AzRestMethod -Path "$dcrPath`?api-version=2023-03-11" -Method GET
    if ($dcrResult.StatusCode -eq 200) {
        $dcr = $dcrResult.Content | ConvertFrom-Json -Depth 50
        if ($dcr.properties.immutableId -and $dcr.properties.endpoints.logsIngestion) {
            break
        }
    }
    if ($attempt -eq 12) {
        throw "DCR '$DcrName' did not expose a Direct ingestion endpoint."
    }
    Start-Sleep -Seconds 5
}

if (-not $dcr.properties.immutableId) {
    throw 'The DCR response did not contain properties.immutableId.'
}
if (-not $dcr.properties.endpoints.logsIngestion) {
    throw 'The Direct DCR response did not contain properties.endpoints.logsIngestion.'
}

[pscustomobject]@{
    TableResourceId = $tablePath
    DcrResourceId = $dcrPath
    LogsIngestionEndpoint = $dcr.properties.endpoints.logsIngestion.TrimEnd('/')
    DcrImmutableId = $dcr.properties.immutableId
    StreamName = $inputStream
    TableName = $TableName
}
