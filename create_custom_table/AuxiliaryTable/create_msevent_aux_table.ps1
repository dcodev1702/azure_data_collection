<#
  Date: 6/2/2025
  
  Link: https://learn.microsoft.com/en-us/azure/azure-monitor/logs/tutorial-logs-ingestion-api?tabs=dce
  Run script this via the Azure Cloud Shell or PowerShell CLI w/ Az Module installed on your VM/Machine
  Be sure to define your schema (column names and data types) and name of your Custom Log Table

  1. Provide the name of your resource group and the name of your log analytics workspace

  2. Be sure to CHANGE the table name at the bottom towards the end of the REST API call!!

  Helpful Hints:
  --------------
  1. Your Custom Table has to be created first before creating data collection rules and endpoints
  2. The schema (colunm names and data types) must match between the DCR and Custom Table. If not
     during the creation of your DCR, you will most likely experience errors.

#>
$subscription = $(Get-AzContext).Subscription.Id
$rgName       = 'SecOps'
$wsName       = 'SecOps-LA'
$cTable       = 'MSEVENT_AUX_CL'
$apiVersion   = '2023-01-01-preview'

$tableParams = @"
{
    "properties": {
        "schema": {
            "name": "$cTable",
            "columns": [
                {
                    "name": "SourceSystem",
                    "type": "string",
                    "description": "The system that generated the source event"
                },
                {
                    "name": "TimeGenerated",
                    "type": "datetime",
                    "description": "The time the event was generated"
                },
                {
                    "name": "Source",
                    "type": "string",
                    "description": "The origin of the event"
                },
                {
                    "name": "EventLog",
                    "type": "string",
                    "description": "Name of the event log"
                },
                {
                    "name": "Computer",
                    "type": "string",
                    "description": "The computer where the event occurred"
                },
                {
                    "name": "EventLevel",
                    "type": "int",
                    "description": "Numeric level indicating event severity"
                },
                {
                    "name": "EventLevelName",
                    "type": "string",
                    "description": "Name of the event severity level"
                },
                {
                    "name": "ParameterXml",
                    "type": "string",
                    "description": "XML containing event parameters"
                },
                {
                    "name": "EventData",
                    "type": "string",
                    "description": "Data associated with the event"
                },
                {
                    "name": "EventID",
                    "type": "int",
                    "description": "Identifier of the event"
                },
                {
                    "name": "RenderedDescription",
                    "type": "string",
                    "description": "Rendered description of the event"
                },
                {
                    "name": "AzureDeploymentID",
                    "type": "string",
                    "description": "ID of the Azure deployment"
                },
                {
                    "name": "Role",
                    "type": "string",
                    "description": "Role associated with the event"
                },
                {
                    "name": "EventCategory",
                    "type": "int",
                    "description": "Category of the event"
                },
                {
                    "name": "UserName",
                    "type": "string",
                    "description": "Name of the user associated with the event"
                },
                {
                    "name": "Message",
                    "type": "string",
                    "description": "Message content of the event"
                },
                {
                    "name": "ManagementGroupName",
                    "type": "string",
                    "description": "Name of the management group"
                }
            ]
        },
        "totalRetentionInDays": 730,
        "plan": "Auxiliary"
    }
}
"@

$url = "/subscriptions/${subscription}/resourcegroups/${rgName}/providers/microsoft.operationalinsights/workspaces/${wsName}/tables/${cTable}?api-version=${apiVersion}"
Invoke-AzRestMethod -Path $url -Method PUT -payload $tableParams
