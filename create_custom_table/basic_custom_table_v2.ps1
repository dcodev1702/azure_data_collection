<#
  Date: 6 NOV 2025
  
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

# Set your variables
$subscription = $(Get-AzContext).Subscription.Id
$rgName = 'SecOps'
$wsName = 'SecOps-LA'
$apiVersion = '2025-07-01'

# Parameterized table name
$tableName = "SuricataTmp_CL"
$retentionDays = 180

# Build the parameters using a hashtable instead of here-string
$tableParams = @{
    properties = @{
        schema = @{
            name = $tableName
            columns = @(
                @{ name = "TimeGenerated"; type = "datetime" }
                @{ name = "RawData"; type = "string" }
            )
        }
        retentionInDays = $retentionDays
    }
} | ConvertTo-Json -Depth 10

# Build the REST API URL
$url = "/subscriptions/${subscription}/resourcegroups/${rgName}/providers/Microsoft.OperationalInsights/workspaces/${wsName}/tables/${tableName}?api-version=${apiVersion}"

# Create the table
Write-Host "Creating table: $tableName" -ForegroundColor Yellow
$response = Invoke-AzRestMethod -Path $url -Method PUT -Payload $tableParams

# Check response
if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 201) {
    Write-Host "Table '$tableName' created successfully!" -ForegroundColor Green
} else {
    Write-Host "Error: $($response.StatusCode)" -ForegroundColor Red
    $response.Content
}
