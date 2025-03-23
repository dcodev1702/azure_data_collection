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

# Read the file content
$JSONData = Get-Content -Raw -Path $DataIngestFile

# Determine if it's JSON or NDJSON
$isValidJson = $false
$JSONType = $null
# Check if the file is standard JSON or NDJSON (newline-delimited JSON objects)
try {
    $parsed = $JSONData | ConvertFrom-Json -ErrorAction Stop
    $isValidJson = $true
    $JSONType = "json"
} catch {
    # If not standard JSON, try NDJSON (line-delimited JSON objects)
    try {
        $JSONData = Get-Content -Path $DataIngestFile
        $JSONData | ForEach-Object {
            $_ | ConvertFrom-Json -ErrorAction Stop | Out-Null
        }
        $isValidJson = $true
        $JSONType = "ndjson"
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

# Information needed to send data to the DCR endpoint
$logIngestionEp = "ENTER YOUR DCE OR LOG INGESTION URI/ENDPOINT HERE"
$dcrImmutableId = "ENTER YOUR DCR IMMUTABLE ID HERE"

$currentTime    = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ") # current time in UTC format
$streamName     = "Custom-PJL_HAWK_CL" # name of the stream in the DCR that represents the destination table

### Step 1: Obtain a bearer token used later to authenticate against the DCE.
### The App Registration must have the "Metrics Publishing" RBAC role assigned to the DCR and the DCE must be linked to the DCR.
$scope = [System.Web.HttpUtility]::UrlEncode("https://monitor.azure.com//.default")   
$body  = "client_id=${appId}&scope=${scope}&client_secret=${appSecret}&grant_type=client_credentials"

$headers = @{"Content-Type"="application/x-www-form-urlencoded"}
$uri = "https://login.microsoftonline.com/${tenantId}/oauth2/v2.0/token"

$bearerToken = (Invoke-RestMethod -Uri $uri -Method POST -Body $body -Headers $headers).access_token
$headers = @{"Authorization"="Bearer $bearerToken";"Content-Type"="application/json"}

#------------ ONLY NEED IF DATA IS NOT IN NDJSON FORMAT  ----------------
## The JSON data must be in the same format as the CL in the DCR.
## The JSON data must be in SINGLE LINE format (no line breaks).
if ($JSONType -eq "json") {
    $body = @"
    $JSONData
"@
}

### Step 3: Send the data to the Log Analytics workspace via the DCE.
#$body    = $staticData
#------------ ONLY NEED IF DATA IS NOT IN NDJSON FORMAT  ----------------

# DCR Stream REST API ENDPOINT
$uri     = "${logIngestionEp}/dataCollectionRules/${dcrImmutableId}/streams/${streamName}?api-version=2023-01-01"

# Loop over each NDJSON object individually and make a stream REST API call
foreach ($NDJSONObj in $NDJSONData) {
    
    # Wrap the single line in square brackets to make it a valid JSON one dimensional array
    # This is REQUIRED (documented) to send a JSON array via the Log Analytics API. Not needed for AMA but for Stream REST API
    if ($JSONType -eq "ndjson") {
        $body = "[${JSONObj}]"
    } else {
        $body = $JSONObj
    }
    
    Invoke-RestMethod -Uri $uri -Method POST -Body $body -Headers $headers -ErrorVariable RestError
    
    if ($RestError) {
        Write-Host "Error uploading: $body to the Log-A Custom Table `"$streamName`". Error: $RestError" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "CX dummy data $body - successfully uploaded to the Log-A Custom Table: `"$streamName`"." -ForegroundColor Green
    
    }
}
