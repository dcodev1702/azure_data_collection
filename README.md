## ASSUMPTIONS

1. You have an Azure subscription and access with the requisite permissions (RBAC)
2. You have access to the Azure WebShell or PowerShell with the Az module installed
3. PowerShell knowledge to include an understanding of REST APIs, DCR, DCE, and Custom Table Schemas.

---

## RESOURCES:
[Data Collection Rules](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/data-collection-rule-overview) </br>
[Logs Ingestion API](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/logs-ingestion-api-overview) </br>
[Sample Code Ingestion](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/tutorial-logs-ingestion-code?tabs=powershell) </br>

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
     - THIS THEORY WAS TESTED ON MARCH 16 2025
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

1. **DCR TABLE SCHEMA AND CUSTOM LOG TABLE SCHEMA HAVE TO MATCH (EXACTLY) IN NAME:TYPE**
2. **JSON objects are not encapsulated as an entire string, they have to be in SINGLE LINE FORMAT.**  
   -- Otherwise Log-A will drop the data at the door and you will ONLY see TimeGenerated, TenantId, and Table Type.
3. **If JSON is in it's free form, it will have to be encapsulated as a STRING IN ORDER FOR IT TO BE INGESTED PROPERLY!!!**  
   OTHERWISE, YOU WILL SEE NO DATA IN THE CUSTOM LOG.

---

## EXAMPLE 1

`$TimeGenerated = Get-Date ([datetime]::UtcNow) -Format O`

------------
File: mde_log_original_100.json
```json
[
  {
      "TimeGenerated": "$currentTime",
      "Computer": "PC-$(Get-Random)",
      "AdditionalContext": {
          "InstanceName": "user14",
          "TimeZone": "Pacific Time",
          "Level": 4,
          "CounterValue": 15.3    
      },
      "Location": "Hybrid",
      "CloudEnabled": "True"
  },
  {
      "Time": "$currentTime",
      "Computer": "PC-$(Get-Random)",
      "AdditionalContext": {
          "InstanceName": "user21",
          "TimeZone": "Central Time",
          "Level": 3,
          "CounterValue": 23.5     
      },
      "Location": "On-Site",
      "CloudEnabled": "False"
  }
]
```


-------------------
THIS JSON (ABOVE) HAS TO BE ENCAPSULATED IN A STRING OR ELSE LOG-A WILL DROP IT.

```python
$JSONData = Get-Content -Path ".\mde_data\mde_log_original_100.json" -Raw

$body = @"
    $JSONData
"@


# Make the REST API call to the DCE Ingestion URL and Custom Table Stream
$uri = "${dceEndpoint}/dataCollectionRules/${dcrImmutableId}/streams/${streamName}?api-version=2023-01-01"
Invoke-RestMethod -Uri $uri -Method POST -Body $body -Headers $headers -ErrorVariable $RestError
```

EXAMPLE 2:
----------
THIS JSON DOES NOT REQUIRE TO BE ENCAPSULATED IN A STRING BEC THE OBJECTS ARE SINGLE LINE. 
IT WILL INJEST INTO LOG-A JUST FINE.
```json
[
    {"TimeGenerated":"$currentTime","Computer":"PC-$(Get-Random)","AdditionalContext":{"InstanceName":"user14","TimeZone":"Pacific Time","Level":4,"CounterValue":15.3},"Location":"Hybrid","CloudEnabled":"True"},
    {"Time":"$currentTime","Computer":"PC-$(Get-Random)","AdditionalContext":{"InstanceName":"user21","TimeZone":"Central Time","Level":3,"CounterValue":23.5},"Location":"On-Site","CloudEnabled":"False"}
]
```

Convert JSON to single line JSON using JQ
-----------------------------------------
```bash
jq -c '.[]' mde_log_details_100.json
```


Python Solution
---------------
```python
import json

# Read the file from the provided path
with open("mde_log_original_100.json", "r") as f:
    data = json.load(f)

# Convert each entry to a compact (single-line) JSON string
compact_entries = [json.dumps(entry, separators=(",", ":")) for entry in data]

# Write the compact entries as a JSON array to a file
with open("mde_log_output_01.json", "w") as outfile:
    outfile.write("[\n")
    outfile.write(",\n".join(compact_entries))
    outfile.write("\n]\n")
```

------------------------
#### CUSTOM TEXT LOGS  
Kind: Windows/Linux

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
Kind: Windows/Linux

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
