<#
  Date: 3/19/2025
  
  Link: https://learn.microsoft.com/en-us/azure/azure-monitor/logs/tutorial-logs-ingestion-api?tabs=dce
  Run script this via the Azure Cloud Shell or PowerShell CLI w/ Az Module installed on your VM/Machine
  Be sure to define your schema (column names and data types) and name of your Custom Log Table

  1. Provide the name of your resource group and the name of your log analytics workspace

  2. Be sure to CHANGE the table name at the bottom towards the end of the REST API call!!

  3. If you're so included, you can create a CL table via ARM Templates/Bicep/Terraform
     Link: https://learn.microsoft.com/en-us/azure/templates/microsoft.operationalinsights/workspaces/tables?pivots=deployment-language-arm-template

  Helpful Hints:
  --------------
  1. Your Custom Table has to be created first before creating data collection rules and endpoints
  2. The schema (colunm names and data types) must match between the DCR and Custom Table. If not
     during the creation of your DCR, you will most likely experience errors.

#>
$subscription = $(Get-AzContext).Subscription.Id
$rgName = 'RCC-E'
$wsName = 'rccelab-law'
$cTable = "PJL_HAWK_CL"


$tableParams = @'
{
    "properties": {
        "schema": {
            "name": "PJL_HAWK_CL",
            "columns": [
                {
                    "name": "TimeGenerated",
                    "type": "datetime",   
                    "description": "The time the event was generated"
                },
                {
                    "name": "Name",
                    "type": "string",
                    "description": "The name of the Hacker"
                },
               {
                    "name": "Version",
                    "type": "string",
                    "description": "The computer they use to hack"
                },
                {
                    "name": "OS",
                    "type": "string",
                    "description": "The OS they use to hack with"
                },
                {
                    "name": "Hardware",
                    "type": "dynamic",
                    "description": "The hardware they use to hack with"
                },
                {
                    "name": "Distro",
                    "type": "dynamic",
                    "description": "Linux distro of choice"
                },
                {
                    "name": "OSVersion",
                    "type": "string",
                    "description": "The version of the OS"
                },
                {
                    "name": "OSArchitecture",
                    "type": "string",
                    "description": "The architecture of the OS"
                },
                {
                    "name": "GenAI",
                    "type": "string",
                    "description": "The GenAI they use to hack with"
                }
            ]
        }
    }
}
'@

$url = "/subscriptions/${subscription}/resourcegroups/${rgName}/providers/microsoft.operationalinsights/workspaces/${wsName}/tables/${cTable}?api-version=2023-01-01-preview"
Invoke-AzRestMethod -Path $url -Method PUT -payload $tableParams
