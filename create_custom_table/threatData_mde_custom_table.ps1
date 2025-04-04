<#
  Date: 3/19/2025
  
  Link: https://learn.microsoft.com/en-us/azure/azure-monitor/logs/tutorial-logs-ingestion-api?tabs=dce
  Run script this via the Azure Cloud Shell or PowerShell CLI w/ Az Module installed on your VM/Machine
  Be sure to define your schema (column names and data types) and name of your Custom Log Table

  1. Provide the name of your resource group and the name of your log analytics workspace

  2. Be sure to CHANGE the table name at the bottom towards the end of the REST API call!!

  3. Note: title column had to be renamed to ThreatTitle
     In DCR / transformKql: "source | extend TimeGenerated = now() | project-rename ThreatTitle = ['title']"

  Helpful Hints:
  --------------
  1. Your Custom Table has to be created first before creating data collection rules and endpoints
  2. The schema (colunm names and data types) must match between the DCR and Custom Table. If not
     during the creation of your DCR, you will most likely experience errors.

#>
$subscription = $(Get-AzContext).Subscription.Id
$rgName = 'RCC-E'
$wsName = 'rccelab-law'


$tableParams = @'
{
    "properties": {
        "schema": {
            "name": "ThreatData_MDE_CL",
            "columns": [
                {
                    "name": "TimeGenerated",
                    "type": "datetime",
                },
                {
                    "name": "id",
                    "type": "string"
                },
                {
                    "name": "incidentId",
                    "type": "long"
                },
                {
                    "name": "investigationId",
                    "type": "long"
                },
                {
                    "name": "assignedTo",
                    "type": "string"
                },
                {
                    "name": "severity",
                    "type": "dynamic"
                },
                {
                    "name": "status",
                    "type": "string"
                },
                {
                    "name": "classification",
                    "type": "string"
                },
                {
                    "name": "determination",
                    "type": "string"
                },
                {
                    "name": "investigationState",
                    "type": "string"
                },
                {
                    "name": "detectionSource",
                    "type": "string"
                },
                {
                    "name": "detectorId",
                    "type": "string"
                },
                {
                    "name": "category",
                    "type": "dynamic"
                },
                {
                    "name": "threatFamilyName",
                    "type": "string"
                },
                {
                    "name": "ThreatTitle",
                    "type": "string"
                },
                {
                    "name": "description",
                    "type": "string"
                },
                {
                    "name": "alertCreationTime",
                    "type": "datetime"
                },
                {
                    "name": "firstEventTime",
                    "type": "datetime"
                },
                {
                    "name": "lastEventTime",
                    "type": "datetime"
                },
                {
                    "name": "lastUpdateTime",
                    "type": "datetime"
                },
                {
                    "name": "resolvedTime",
                    "type": "datetime"
                },
                {
                    "name": "machineId",
                    "type": "string"
                },
                {
                    "name": "computerDnsName",
                    "type": "datetime"
                },
                {
                    "name": "rbacGroupName",
                    "type": "string"
                },
                {
                    "name": "aadTenantId",
                    "type": "string"
                },
                {
                    "name": "threatName",
                    "type": "string"
                },
                {
                    "name": "mitreTechniques",
                    "type": "dynamic"
                },
                {
                    "name": "relatedUser",
                    "type": "string"
                },
                {
                    "name": "loggedOnUsers",
                    "type": "dynamic"
                },
                {
                    "name": "comments",
                    "type": "dynamic"
                },
                {
                    "name": "evidence",
                    "type": "dynamic"
                },
                {
                    "name": "domains",
                    "type": "dynamic"
                }
            ]
        },
        "retentionInDays": 120,
        "totalRetentionInDays": 180
    }
}
'@

$url = "/subscriptions/${subscription}/resourcegroups/${rgName}/providers/microsoft.operationalinsights/workspaces/${wsName}/tables/ThreatData_MDE_CL?api-version=2025-02-01"
Invoke-AzRestMethod -Path $url -Method PUT -payload $tableParams
