<#
.SYNOPSIS
Creates or deletes a table, DCE, and AMA log-file DCR as one guided lab.

.DESCRIPTION
This is the agent-based counterpart to the Direct DCR lab. It creates a
two-column table, a DCE, and a Windows or Linux log-file DCR. Provisioning is
idempotent and updates desired state. Deletion is explicit, and table deletion is
controlled separately with -RetainCustomTable.

.EXAMPLE
Invoke-DCR-API -Action Provision -ResourceGroup rg-training `
  -WorkspaceName law-training -Location eastus2 `
  -DceName training-dce -DcrName training-file-dcr `
  -CustomTable TrainingFiles_CL -DcrKind Windows `
  -DcrLogFilePattern 'C:\Training\*.json' -Format json
#>
function Invoke-DCR-API {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Provision', 'Delete')]
        [string]$Action,

        [Parameter(Mandatory)][string]$ResourceGroup,
        [Parameter(Mandatory)][string]$WorkspaceName,
        [Parameter(Mandatory)][string]$Location,
        [string]$DceName = 'csa-training-dce',
        [string]$DcrName = 'csa-training-file-dcr',
        [string]$CustomTable = 'TrainingFiles_CL',
        [bool]$RetainCustomTable = $true,
        [ValidateSet('Windows', 'Linux')]
        [string]$DcrKind = 'Windows',
        [ValidateSet('json', 'text')]
        [string]$Format = 'json',
        [string]$DcrLogFilePattern = 'C:\Training\*.json',
        [ValidateRange(30, 730)][int]$RetentionInDays = 30,
        [ValidateRange(30, 2556)][int]$TotalRetentionInDays = 180
    )

    $ErrorActionPreference = 'Stop'
    if (-not (Get-AzContext -ErrorAction SilentlyContinue)) {
        throw 'Connect-AzAccount before managing DCR resources.'
    }
    if ($RetentionInDays -gt $TotalRetentionInDays) {
        throw 'TotalRetentionInDays must be greater than or equal to RetentionInDays.'
    }

    $subscriptionId = (Get-AzContext).Subscription.Id
    $resourceManagerUrl = (Get-AzContext).Environment.ResourceManagerUrl.TrimEnd('/')
    $basePath = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup"
    $workspacePath = "$basePath/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName"
    $tablePath = "$workspacePath/tables/$CustomTable"
    $dcePath = "$basePath/providers/Microsoft.Insights/dataCollectionEndpoints/$DceName"
    $dcrPath = "$basePath/providers/Microsoft.Insights/dataCollectionRules/$DcrName"

    function Invoke-ResourceRequest {
        param(
            [Parameter(Mandatory)][string]$Path,
            [Parameter(Mandatory)][ValidateSet('GET', 'PUT', 'DELETE')][string]$Method,
            [string]$Payload
        )
        $result = Invoke-AzRestMethod -Path $Path -Method $Method -Payload $Payload
        if ($result.StatusCode -ge 400) {
            throw "$Method $Path failed with HTTP $($result.StatusCode): $($result.Content)"
        }
        return $result
    }

    if ($Action -eq 'Delete') {
        $resources = @(
            @{ Name = $DcrName; Path = "$dcrPath`?api-version=2023-03-11"; Retain = $false }
            @{ Name = $DceName; Path = "$dcePath`?api-version=2023-03-11"; Retain = $false }
            @{ Name = $CustomTable; Path = "$tablePath`?api-version=2023-09-01"; Retain = $RetainCustomTable }
        )
        foreach ($resource in $resources) {
            if ($resource.Retain) {
                Write-Host "Retaining custom table '$($resource.Name)'." -ForegroundColor Magenta
                continue
            }
            if ($PSCmdlet.ShouldProcess($resource.Name, 'Delete Azure resource')) {
                Invoke-ResourceRequest -Path $resource.Path -Method DELETE
                Write-Host "Deleted '$($resource.Name)'." -ForegroundColor Yellow
            }
        }
        return
    }

    $workspaceResponse = Invoke-ResourceRequest -Path "$workspacePath`?api-version=2023-09-01" -Method GET
    $workspace = $workspaceResponse.Content | ConvertFrom-Json -Depth 50
    if (-not $workspace.id) {
        throw "Workspace '$WorkspaceName' did not return a resource ID."
    }

    $tablePayload = @{
        properties = @{
            schema = @{
                name = $CustomTable
                columns = @(
                    @{ name = 'TimeGenerated'; type = 'datetime' }
                    @{ name = 'RawData'; type = 'string' }
                )
            }
            plan = 'Analytics'
            retentionInDays = $RetentionInDays
            totalRetentionInDays = $TotalRetentionInDays
        }
    } | ConvertTo-Json -Depth 20 -Compress

    $dcePayload = @{
        location = $Location
        properties = @{
            networkAcls = @{ publicNetworkAccess = 'Enabled' }
        }
    } | ConvertTo-Json -Depth 10 -Compress

    if ($PSCmdlet.ShouldProcess($CustomTable, 'Create or update custom table')) {
        Invoke-ResourceRequest -Path "$tablePath`?api-version=2023-09-01" -Method PUT -Payload $tablePayload
    }
    if ($PSCmdlet.ShouldProcess($DceName, 'Create or update data collection endpoint')) {
        Invoke-ResourceRequest -Path "$dcePath`?api-version=2023-03-11" -Method PUT -Payload $dcePayload
    }

    if ($WhatIfPreference) {
        return
    }

    $inputStream = "Custom-$($CustomTable -replace '_CL$', '')"
    $outputStream = "Custom-$CustomTable"
    $logFileSource = @{
        streams = @($inputStream)
        filePatterns = @($DcrLogFilePattern)
        format = $Format
        name = "$DcrKind-$Format-source"
    }
    if ($Format -eq 'text') {
        $logFileSource.settings = @{
            text = @{ recordStartTimestampFormat = 'ISO 8601' }
        }
    }
    $dcrPayload = @{
        location = $Location
        kind = $DcrKind
        properties = @{
            dataCollectionEndpointId = $dcePath
            streamDeclarations = @{
                $inputStream = @{
                    columns = @(
                        @{ name = 'RawData'; type = 'string' }
                    )
                }
            }
            dataSources = @{
                logFiles = @(
                    $logFileSource
                )
            }
            destinations = @{
                logAnalytics = @(
                    @{
                        workspaceResourceId = $workspace.id
                        name = 'lawDestination'
                    }
                )
            }
            dataFlows = @(
                @{
                    streams = @($inputStream)
                    destinations = @('lawDestination')
                    transformKql = 'source | extend TimeGenerated = now() | project TimeGenerated, RawData'
                    outputStream = $outputStream
                }
            )
        }
    } | ConvertTo-Json -Depth 30 -Compress

    if ($PSCmdlet.ShouldProcess($DcrName, 'Create or update agent data collection rule')) {
        Invoke-ResourceRequest -Path "$dcrPath`?api-version=2023-03-11" -Method PUT -Payload $dcrPayload
    }

    [pscustomobject]@{
        TableResourceId = "$resourceManagerUrl$tablePath"
        DceResourceId = "$resourceManagerUrl$dcePath"
        DcrResourceId = "$resourceManagerUrl$dcrPath"
        InputStream = $inputStream
        OutputStream = $outputStream
    }
}
