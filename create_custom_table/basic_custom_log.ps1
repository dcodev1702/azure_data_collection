<#
  Date: 6 NOV 2025
  
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
$rgName       = 'SecOps'
$wsName       = 'SecOps-LA'
$tableName    = 'SuricataTmp_CL'

# Use a recent supported API version
$apiVersion   = '2025-07-01'

$tableParams = @"
{
    "properties": {
        "schema": {
            "name": "$tableName",
            "columns": [
                {
                    "name": "TimeGenerated",
                    "type": "datetime"
                },
                {
                    "name": "RawData",
                    "type": "string"
                }
            ]
        },
        "retentionInDays": 120
    }
}
"@

$url = "/subscriptions/${subscription}/resourcegroups/${rgName}/providers/microsoft.operationalinsights/workspaces/${wsName}/tables/${tableName}?api-version=${apiVersion}"
Invoke-AzRestMethod -Path $url -Method PUT -payload $tableParams
