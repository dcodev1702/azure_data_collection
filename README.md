## ASSUMPTIONS

1. You have an [Azure](https://azure.microsoft.com/en-us/) subscription and access with the requisite permissions (RBAC)
2. You have access to the Azure WebShell or [PowerShell](https://learn.microsoft.com/en-us/powershell/) with the [Az](https://learn.microsoft.com/en-us/powershell/azure/new-azureps-module-az?view=azps-13.2.0) module installed
3. PowerShell knowledge to include an understanding of REST APIs, DCR, DCE, and Custom Table Schemas.

---

## RESOURCES:
[Data Collection Rules](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/data-collection-rule-overview) </br>
[Data Collection Rule - Structure](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/data-collection-rule-structure) </br>
[Create & Edit Data Collection Rules](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/data-collection-rule-create-edit?tabs=arm) </br>
[Logs Ingestion API](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/logs-ingestion-api-overview) </br>
[Logs Ingestion API - Tutorial](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/tutorial-logs-ingestion-api?tabs=dcr) </br>
[Sample Code Ingestion](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/tutorial-logs-ingestion-code?tabs=powershell) </br>
[How-To send Custom Text & JSON Logs](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/data-collection-rule-samples) </br>

## CUSTOM TABLE, DCE, DCR CREATION VIA USER INTERFACE (UI) INSTRUCTIONS

1. Create the Data Collection Endpoint (DCE)
2. Have JSON data available for import via UI when creating Custom Table via DCR
3. Go to **Log Analytics** → **Tables** → **Create Table via DCR**
   - Name your Custom Log (CL) table
   - Assign the DCE to the DCR
   - Create DCR
   - Select Transformation Editor and import JSON
     - Make required KQL adjustments for the DCR. This is the transformKql (KQL commands are limited)
     - [https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/data-collection-transformations-kql](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/data-collection-transformations-kql)
   - The UI will create the DCR columns **AND** Custom Log columns with matching names and dataTypes
   - **THE CUSTOM LOG TABLE AND DCR COLUMN NAMES AND DATATYPES HAVE TO MATCH!!!!!**
   - **YOU CANNOT MAKE CHANGES TO ONE WITHOUT CHANGING THE OTHER TO THE EXACT SAME DATATYPE!!!**
   - THIS THEORY WAS TESTED & VALIDATED ON MARCH 16 2025
4. Assign the Application Registration to the DCR with the 'Log Metrics Publisher' role (RBAC)
5. Associate VM's to the Data Collection Rule (DCR)

---

## CUSTOM TABLE, DCE, DCR CREATION VIA COMMAND LINE INTERFACE (CLI) INSTRUCTIONS

1. The script allows you the ability to create DCE's and DCR's w/o deleting the Custom Log (CL) table via CmdLet switch `-RetainCustomTable $true`
2. Download this [create_dcr_dce_and_customTable.ps1] script to a location where it run (Cloud Shell, VM, or Machine)
3. Familiarize yourself with usage (above) to understand the CmdLet switches
4. Create an Application Registration w/ Secret via Entra ID
5. Rename variables as required on line 40 - 42  
   - `$dceName     = DCE NAME`  
   - `$dcrName     = DCR NAME`  
   - `$customTable = CUSTOM LOG (CL) NAME`
6. If you're using LogFile DCR feature ensure you set the `kind`: to either Windows or Linux.
7. If you're using the LogFile DCR feature, ensure you utilize the CmdLet switch and escape `\\ //`  
   - **Windows:** `"C:\\mde\\mde*.json"`  
   - **GNU\Linux:** `"//home//user//mde//mde*.json"`
8. It is critical to remember that the schemas (in the file) you design for your Custom Log Table **HAS TO BE THE EXACT SAME** as your Data Collection Rule (DCR)
9. Once your Custom Log (CL) Table, DCE, and DCR has been provisioned, you will need to assign your application registration with the Monitoring Metrics Publisher role to your DCR! If this is not done, you will see that you are unable to send your telemetry to your DCE custom log table stream [send_data_to_loga.ps1].

---

## SENDING DATA (JSON) TO A CUSTOM TABLE WITHIN A LOG ANALYTICS WORKSPACE

[https://learn.microsoft.com/en-us/azure/azure-monitor/vm/data-collection-log-json](https://learn.microsoft.com/en-us/azure/azure-monitor/vm/data-collection-log-json)

---

## JSON REQUIREMENTS

In order for data to be ingested correctly into a Log Analytics Custom Table there are a couple rules of the road that are in order.

1. **DCR TABLE SCHEMA / TRANSFORM KQL AND CUSTOM LOG TABLE SCHEMA HAVE TO MATCH (EXACTLY) IN NAME:DATA_TYPE**
2. **Log Analytics Workspace processes NDJSON by default, this is the optimal format and method to employ. </br>
   -- Ensure the LAST NDJSON object is followed by a NEW LINE otherwise it will NOT get ingested. </br>
   -- Azure Monitor Agent w/ custom logs will ingest NDJSON w/o any further modification. </br>
   -- Sending NDJSON via REST API requires EACH NDJSON Object to be wrapped as a 1D JSON Array -> "[$NDJSONObj]" in the body of the Rest API call! </br>
4. **Standard JSON objects can be encapsulated as an entire string, however, it is best that they are in SINGLE LINE FORMAT.**  
   -- Otherwise Log-A will drop the data at the door and you will ONLY see TimeGenerated, TenantId, and Table Type.
      -- This is intentional by design and is Log Analytics way of telling you that your content is MALFORMED and DROPPED.
6. **If Standard JSON is in its RAW form, it will have to be encapsulated as a STRING IN ORDER FOR IT TO BE INGESTED PROPERLY!!!**  
   OTHERWISE, YOU WILL SEE NO DATA IN THE CUSTOM LOG TABLE.

---
## NDJSON EXAMPLE
File: dummy_data.ndjson
```json
{ "Name": "DCODEV - Cloud Hunter", "Version": "14.8.0987", "OS": "Gentoo - GNU/Linux", "Hardware": { "model": "Dell XPS 15", "chip": "Intel Core i9-13900H", "ram": "96GB", "storage": "4TB SSD", "release_year": 2025 }, "Distro": { "name": "Gentoo", "version": "Rolling Release", "init": "OpenRC", "package_manager": "Portage" }, "OSVersion": "6.8.0-1052-azure", "OSArchitecture": "x86_64", "GenAI": "OpenAI / GPT-4.5 Turbo" }
{ "Name": "T0pCyber - Hawk", "Version": "8.8.6.2304", "OS": "Macbook Pro", "OSVersion": "macOS Ventura - 15.3.26100.3476", "OSArchitecture": "arm64", "Hardware": { "model": "Macbook Pro 16-inch", "chip": "Apple M3 Pro", "ram": "128GB", "storage": "4TB SSD", "release_year": 2024 }, "GenAI": "Grok 3" }
{ "Name": "JJ-BOTTLES - Hawk", "Version": "3.7.6.0004", "OS": "Windows 11 24H2", "OSVersion": "10.0.26100.3476", "OSArchitecture": "x86_32", "Hardware": { "manufacturer": "HP", "model": "Spectre x760", "ram": "96GB", "storage": "2TB SSD", "release_year": 2023 }, "GenAI": "Anthropic / Claude 3.7 Sonnet" }

```
-- Azure Monitor Agent: No furthre action required </br>
-- REST API Call to DCR Log Ingestion / DCR Uri: BODY = "[$NDJSONObj]" </br>

## RAW JSON - EXAMPLE 1
-----------------------
File: dummy_data.json
```json
[
    {
        "Name": "DCODEV - Cloud Hunter",
        "Version": "14.8.0987",
        "OS": "Gentoo - GNU/Linux",
        "Hardware": {
            "model": "Dell XPS 15",
            "chip": "Intel Core i9-13900H",
            "ram": "96GB",
            "storage": "4TB SSD",
            "release_year": 2025
        },
        "Distro": {
            "name": "Gentoo",
            "version": "Rolling Release",
            "init": "OpenRC",
            "package_manager": "Portage"
        },
        "OSVersion": "6.8.0-1052-azure",
        "OSArchitecture": "x86_64",
        "GenAI": "OpenAI / GPT-4.5 Turbo"
    },
    {
        "Name": "T0pCyber - Hawk",
        "Version": "8.8.6.2304",
        "OS": "Macbook Pro",
        "OSVersion": "macOS Ventura - 15.3.26100.3476",
        "OSArchitecture": "arm64",
        "Hardware": {
            "model": "Macbook Pro 16-inch",
            "chip": "Apple M3 Pro",
            "ram": "128GB",
            "storage": "4TB SSD",
            "release_year": 2024
        },
        "GenAI": "Grok 3"  
    },
    {
        "Name": "JJ-BOTTLES - Hawk",
        "Version": "3.7.6.0004",
        "OS": "Windows 11 24H2",
        "OSVersion": "10.0.26100.3476",
        "OSArchitecture": "x86_32",
        "Hardware": {
            "manufacturer": "HP",
            "model": "Spectre x760",
            "ram": "96GB",
            "storage": "2TB SSD",
            "release_year": 2023
        },
        "GenAI": "Anthropic / Claude 3.7 Sonnet"  
    }
]
```


-------------------
THIS JSON (ABOVE) HAS TO BE ENCAPSULATED AS A SINGLE STRING OR COMPRESSED, OTHERWISE LOG-A WILL DROP IT!

```powershell
$JSONData = Get-Content -Path ".\mde_data\dummy_data.json" -Raw

$body = @"
    $JSONData
"@


# Make the REST API call to the DCE Ingestion URL and Custom Table Stream
$uri = "${dceEndpoint}/dataCollectionRules/${dcrImmutableId}/streams/${streamName}?api-version=2023-01-01"
Invoke-RestMethod -Uri $uri -Method POST -Body $body -Headers $headers -ErrorVariable $RestError
```

EXAMPLE 2:
----------
THIS JSON IS NEW LINE DELIMITED (ND) AND WILL INGEST W/O ANY ISSUES. IT STILL REQUIRES "[ ]" AROUND EACH JSON OBJECT.
CONVERTTO-JSON -COMPRESS WILL CONVERT RAW JSON TO NDJSON!
```json
   {"Name":"DCODEV - Cloud Hunter","Version":"14.8.0987","OS":"Gentoo - GNU/Linux","Hardware":{"model":"Dell XPS 15","chip":"Intel Core i9-13900H","ram":"96GB","storage":"4TB SSD","release_year":2025},"Distro":{"name":"Gentoo","version":"Rolling Release","init":"OpenRC","package_manager":"Portage"},"OSVersion":"6.8.0-1052-azure","OSArchitecture":"x86_64","GenAI":"OpenAI / GPT-4.5 Turbo"}
   {"Name":"T0pCyber - Hawk","Version":"8.8.6.2304","OS":"Macbook Pro","OSVersion":"macOS Ventura - 15.3.26100.3476","OSArchitecture":"arm64","Hardware":{"model":"Macbook Pro 16-inch","chip":"Apple M3 Pro","ram":"128GB","storage":"4TB SSD","release_year":2024},"GenAI":"Grok 3"}
   {"Name":"JJ-BOTTLES - Hawk","Version":"3.7.6.0004","OS":"Windows 11 24H2","OSVersion":"10.0.26100.3476","OSArchitecture":"x86_32","Hardware":{"manufacturer":"HP","model":"Spectre x760","ram":"96GB","storage":"2TB SSD","release_year":2023},"GenAI":"Anthropic / Claude 3.7 Sonnet"}

```

Turn a JSON array of objects into single inline objects (JQ / PWSH / Python) </br>
Convert JSON to single line JSON using JQ
-----------------------------------------
```bash
jq -c '.[]' .\data\dummy_data_100.json
```

PowerShell Solution
-------------------
```powershell
# Read the JSON file as a single string and convert it to objects
$JSONData = Get-Content ".\data\dummy_data_100.json" -Raw | ConvertFrom-Json -Depth 50

### Step 2: Send the telemetry (JSON Objects) to a Log Analytics Workspace via the DCR stream and Log Ingestion or DC Endpoint.
# DCR Stream (Custom-PJL-HAWK) REST API ENDPOINT
$uri  = "${logIngestionEp}/dataCollectionRules/${dcrImmutableId}/streams/${streamName}?api-version=2023-01-01"
$cntr = $null
foreach ($JSONObj in $JSONData) {

    try {
       if ($JSONType -eq 'json') { 
           # Process each object separately & serialize the entire object to ensure proper formatting (NDJSON)
           $JSONObj = $JSONObj | ConvertTo-Json -Depth 50 -Compress -ErrorAction Stop
       }
    
       # Wrap the single line in square brackets to make it a valid JSON array (NDJSON)
       # This is required (documented) to send a JSON array via the Log Analytics API. Not needed for AMA but is needed for Code/Logic App/etc.
       $body = "[${JSONObj}]"
    
       $cntr++
       Invoke-RestMethod -Uri $uri -Method POST -Body $body -Headers $headers -ErrorAction Stop
       Write-Host "CX dummy data record::[$cntr]: `n$body - successfully uploaded to the Log-A Custom Table: `"$streamName`"." -ForegroundColor Green
    } catch {
       Write-Host "Error uploading record::[$cntr] `n$body to the Log-A Custom Table `"$streamName`". Error: $RestError" -ForegroundColor Red
    }
}
```

Python Solution
---------------
```python
import json

# Read the file from the provided path
with open(".\data\dummy_data_100.json", "r") as f:
    data = json.load(f)

# Convert each entry to a compact (single-line) JSON string
compact_entries = [json.dumps(entry, separators=(",", ":")) for entry in data]

# Write the compact entries as a JSON array to a file
with open(".\data\dummy_data_100_sl.json", "w") as outfile:
    outfile.write("[\n")
    outfile.write(",\n".join(compact_entries))
    outfile.write("\n]\n")
```

------------------------
#### CUSTOM TEXT LOGS  
[Kind](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/data-collection-rule-structure#kind): Windows/Linux

------------------------
```json
"dataSources": {
    "logFiles": [
        {
            "streams": [
            "Custom-ACEDEV_CL"
            ],
            "filePatterns": [
            "c:\\mde\\mde*.json"
            ],
            "format": "text",
            "settings": {
            "text": {
                "recordStartTimestampFormat": "ISO 8601"
            }
            },
            "name": "ACEDEV_CL"
        }
    ]
}
```

-------------------------
#### CUSTOM JSON LOGS  
[Kind](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/data-collection-rule-structure#kind): Windows/Linux

-------------------------
```json
"dataSources": {
    "logFiles": [
        {
            "streams": [
            "Custom-ACEDEV_CL"
            ],
            "filePatterns": [
            "C:\\mde\\mde*.json"
            ],
            "format": "json",
            "name": "Custom-ACEDEV_CL"
        }
    ]
}
```
