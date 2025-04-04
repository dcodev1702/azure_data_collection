# Author: DCODEV1702
# Date: 03/18/2025
### Step 0: Set variables required for the rest of the script.
# This script sends data to a Custom Log (CL) via Log Analytics Workspace w/ a Data Collection Endpoint (DCE) using a Data Collection Rule (DCR).
# Create an application registration and give it the Metrics Publishing RBAC role to the DCR!

<#
Pre-requisites:
1. Ensure you have an Azure subscription and appropriate role based access.
2. IF your DCR is 'kind' = 'direct', you do NOT need a DCE. You can use the log ingestion uri (API: 2023-03-11)
   - Create a Data Collection Endpoint (DCE) in the Azure portal.
   - The DCE must be in the same region as the Log Analytics workspace.
   - The DCE must be assigned to a Data Collection Rule (DCR).
3. Create a Data Collection Rule (DCR) in the Azure portal and assign it to the DCE.
4. Create a Custom Log (CL) in the Azure portal and assign it to the DCR. The CL must have the same name as the stream name in the DCR.
5. Create an application registration in Entra ID and assign it the Metrics Publishing RBAC role to the DCR.
6. Create a secret for the application registration and copy it to the $appSecret variable in this script.
7. Create a NDJSON file with the data you want to send to the CL and copy it to the $staticData variable in this script.
   -- The NDJSON file MUST be in the same format/schema as the CL in the DCR.

#----------------- JSON ESSENTIAL UNDERSTANDING  --------------------
## JSON data source must be in the same format as the CL in the DCR.
## Columns (Fields) ARE CASE SENSITIVE (e.g. 'hardware' != 'Hardware')
## JSON data must be in SINGLE LINE (compressed) delimited by a new-line (NDJSON).
#----------------- JSON ESSENTIAL UNDERSTANDING  --------------------

Usage:
./send_json_data_to_loga.ps1 -DataIngestFile ./data/dummy_data.[nd]json

#>
param(
    [Parameter(Mandatory=$true)]
    [string]$DataIngestFile
)

# Check if the file exists
if (-not (Test-Path $DataIngestFile)) {
    Write-Error "The file '$DataIngestFile' does not exist."
    exit 1
}

if (-not (Get-AzContext)) {
    Write-Error "Not logged into Azure. Please run Connect-AzAccount."
    exit 1
}

# Read the file content
$JSONData = Get-Content -Raw -Path $DataIngestFile

# Determine if it's JSON or NDJSON
$isValidJson = $false
$JSONType    = $null
# Check if the file is standard JSON or NDJSON (newline-delimited JSON objects)
try {
    $JSONData = $JSONData | ConvertFrom-Json -Depth 25 -ErrorAction Stop

    $isValidJson = $true
    $JSONType    = 'json'
} catch {
    # If not standard JSON, try NDJSON (line-delimited JSON objects)
    try {
        $JSONData = Get-Content -Path $DataIngestFile
        $JSONData | ForEach-Object {
            $_ | ConvertFrom-Json -ErrorAction Stop | Out-Null
        }
        $isValidJson = $true
        $JSONType    = 'ndjson'
    } catch {
        $isValidJson = $false
    }
}

if (-not $isValidJson) {
    Write-Error "The file '$DataIngestFile' is not valid JSON or NDJSON."
    exit 1
}

Write-Host "Valid JSON/NDJSON file detected :: $DataIngestFile. Continuing..."

# Information needed to authenticate to Entra ID and obtain a bearer token
$tenantId  = "$((Get-AzContext).Tenant.Id)"
$appId     = "ENTER YOUR APP ID HERE"
$appSecret = "ENTER YOUR APP SECRET HERE"

# Information needed to send data to the DCR/DCE endpoint
$logIngestionEp = "ENTER YOUR DCE OR LOG INGESTION URI/ENDPOINT HERE"
$dcrImmutableId = "ENTER YOUR DCR IMMUTABLE ID HERE"

# Stream name to send the data to via DCR which then sends it to the Custom Log Table (CL) in the Log Analytics workspace
$streamName     = "Custom-PJL_HAWK" # name of the stream in the DCR that represents the destination table

### Step 1: Obtain a bearer token used later to authenticate against the DCE.
### The App Registration must have the "Metrics Publishing" RBAC role assigned to the DCR and the DCE must be linked to the DCR.
$scope = [System.Web.HttpUtility]::UrlEncode("https://monitor.azure.com//.default")   
$body  = "client_id=${appId}&scope=${scope}&client_secret=${appSecret}&grant_type=client_credentials"

$headers = @{"Content-Type"="application/x-www-form-urlencoded"}
$uri = "https://login.microsoftonline.com/${tenantId}/oauth2/v2.0/token"

$bearerToken = (Invoke-RestMethod -Uri $uri -Method POST -Body $body -Headers $headers).access_token
$headers = @{"Authorization"="Bearer $bearerToken";"Content-Type"="application/json"}


### Step 2: Send the telemetry (JSON Objects) to a Log Analytics Workspace via the DCR stream and Log Ingestion or DC Endpoint.
# DCR Stream (Custom-PJL-HAWK) REST API ENDPOINT
$uri  = "${logIngestionEp}/dataCollectionRules/${dcrImmutableId}/streams/${streamName}?api-version=2023-01-01"
$cntr = $null
foreach ($JSONObj in $JSONData) {

    try {
       if ($JSONType -eq 'json') { 
           # Process each object separately & serialize the entire object to ensure proper formatting
           $JSONObj = $JSONObj | ConvertTo-Json -Depth 50 -Compress -ErrorAction Stop
       }
    
       # Wrap the single line in square brackets to make it a valid JSON array
       # This is required (documented) to send a JSON array via the Log Analytics API. Not needed for AMA but is needed for Code/Logic App/etc.
       $body = "[${JSONObj}]"
    
       $cntr++
       Invoke-RestMethod -Uri $uri -Method POST -Body $body -Headers $headers -ErrorAction Stop
       Write-Host "CX dummy data record::[$cntr]: `n$body - successfully uploaded to the Log-A Custom Table: `"$streamName`"." -ForegroundColor Green
    } catch {
       Write-Host "Error uploading record::[$cntr] `n$body to the Log-A Custom Table `"$streamName`". Error: $RestError" -ForegroundColor Red
    }
}
