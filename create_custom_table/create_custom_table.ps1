<#
  Date: 3/19/2025
  
  Link: https://learn.microsoft.com/en-us/azure/azure-monitor/logs/tutorial-logs-ingestion-api?tabs=dce
  Run script this via the Azure Cloud Shell or PowerShell CLI w/ Az Module installed on your VM/Machine
  Be sure to define your schema (column names and data types) and name of your Custom Log Table

  Provide the name of your resource group and the name of your log analytics workspace

  Lastly, be sure to CHANGE the table name at the bottom towards the end of the REST API call!!

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
            "name": "MyTable_CL",
            "columns": [
                {
                    "name": "TimeGenerated",
                    "type": "datetime",
                    "description": "The time at which the data was generated"
                },
               {
                    "name": "Computer",
                    "type": "string",
                    "description": "The computer that generated the data"
                },
                {
                    "name": "AdditionalContext",
                    "type": "dynamic",
                    "description": "Additional message properties"
                },
                {
                    "name": "CounterName",
                    "type": "string",
                    "description": "Name of the computer"
                },
                {
                    "name": "CounterValue",
                    "type": "real",
                    "description": "Value collected for the counter"
                }
            ]
        }
    }
}
'@

Invoke-AzRestMethod -Path "/subscriptions/$subscription/resourcegroups/$rgName/providers/microsoft.operationalinsights/workspaces/$wsName/tables/MyTable_CL?api-version=2022-10-01" -Method PUT -payload $tableParams
