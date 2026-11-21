# Azure Monitor custom table and data collection training

This repository is a hands-on curriculum for Cloud Solution Architects (CSAs) learning how Azure Monitor custom tables, Data Collection Rules (DCRs), Data Collection Endpoints (DCEs), transformations, and ingestion channels fit together.

The examples are designed to answer four questions:

1. Where does data enter Azure Monitor?
2. Which resource defines the input schema?
3. Which KQL transformation maps input to the destination?
4. Which table plan and retention model should receive the data?

## Start here

| Step | Lab or guide | Outcome |
|---|---|---|
| 1 | [Architecture and ingestion paths](docs/01-architecture-and-ingestion-paths.md) | Distinguish Direct DCR, DCE, AMA, and direct-to-store paths |
| 2 | [Schemas and naming](docs/02-schemas-and-naming.md) | Understand input stream, transform output, output stream, and table schema |
| 3 | [Table plans and retention](docs/03-table-plans-and-retention.md) | Select Analytics, Basic, or Auxiliary |
| 4 | [JSON and NDJSON formats](docs/04-json-formats.md) | Choose and validate a payload format for the ingestion channel |
| 5 | [Canonical Direct ingestion lab](labs/01-direct-ingestion/README.md) | Deploy a table and Direct DCR, then ingest and query sample data |
| 6 | [Security and operations](docs/05-security-and-operations.md) | Apply least privilege, safe lifecycle practices, monitoring, and cleanup |
| 7 | [Troubleshooting](docs/06-troubleshooting.md) | Diagnose authorization, endpoint, schema, stream, and transformation failures |

## Prerequisites

- An Azure subscription and permission to create Microsoft.OperationalInsights and Microsoft.Insights resources
- PowerShell 7 and the `Az.Accounts`, `Az.Resources`, `Az.Monitor`, and `Az.OperationalInsights` modules for the PowerShell labs
- Azure CLI for the commands documented in the AgentSettings example
- A resource group and an existing Log Analytics workspace in a supported region
- Access to assign `Monitoring Metrics Publisher` to an identity on a DCR if API ingestion is used outside the signed-in lab flow

You do not need to already understand DCRs or DCEs. Complete the concept guides in order.

## The resource model

```text
Input source
   |
   +-- Logs Ingestion API --> Direct DCR endpoint
   |                              |
   +-- Logs Ingestion API --> DCE --> DCR
   |                              |
   +-- AMA file/event collection -> DCR
   |                              |
   +-- AMA AgentDirectToStore -----> ADLS / Blob
                                  |
                                  v
                           transformKql / routing
                                  |
                                  v
                      Log Analytics custom table
```

The diagram is intentionally conceptual. A Direct DCR does not require a DCE. An agent collection DCR can have a DCE when required by its configured resources. `AgentSettings` and `AgentDirectToStore` DCR kinds have different roles and destinations.

## Naming contract

For a table resource named `CsaTraining_CL`, the canonical Direct ingestion names are:

- DCR stream declaration: `Custom-CsaTraining`
- REST path stream: `Custom-CsaTraining`
- DCR output stream: `Custom-CsaTraining_CL`
- Log Analytics table: `CsaTraining_CL`

The stream in the ingestion URL is not the table name. The DCR data flow maps the input stream to the output stream.

## Example map

| Area | Example | Purpose |
|---|---|---|
| Core | [labs/01-direct-ingestion](labs/01-direct-ingestion) | Recommended first lab |
| Custom tables | [create_custom_table](create_custom_table) | Analytics and Auxiliary table creation |
| DCRs and DCEs | [data_collection_rules/ARM Templates](data_collection_rules/ARM%20Templates) | Direct and DCE ARM patterns |
| Log file collection | [data_collection_rules/create_dcr_dce_and_customTable.ps1](data_collection_rules/create_dcr_dce_and_customTable.ps1) | AMA JSON file collection |
| Direct-to-store | [data_collection_rules/WinEvents-2-BlobStorage](data_collection_rules/WinEvents-2-BlobStorage) | AgentDirectToStore and ADX |
| Agent settings | [data_collection_rules/agent_settings](data_collection_rules/agent_settings) | AMA cache configuration |
| API producer | [send_json_data_to_loga.ps1](send_json_data_to_loga.ps1) | Batched JSON/NDJSON submission |
| Sample data | [data](data) | Small and volume-test fixtures |
| Microsoft Graph | [Mg-Graph/InTune](Mg-Graph/InTune) | A realistic source producer that exports data |

## Recommended validation workflow

Run the repository checks before deploying an example:

```powershell
pwsh -File .\tests\validate-repository.ps1
```

Then run the canonical lab:

```powershell
pwsh -File .\labs\01-direct-ingestion\deploy-lab.ps1 `
  -ResourceGroup <resource-group> `
  -WorkspaceName <workspace-name> `
  -Location <region>
```

The deployment prints the endpoint, immutable ID, and stream name needed by `send-sample.ps1`. Use the signed-in Azure PowerShell identity by default. The script does not require a client secret.

The local validation script uses PowerShell's built-in parser. CI additionally installs the real PSScriptAnalyzer module directly from the `PSGallery` repository and fails the build on analyzer errors.

## Learning objectives

By completing the repository, a CSA should be able to:

- Explain why custom tables are created before a DCR is deployed
- Select a table plan and retention policy
- Distinguish a DCR input stream from its destination table
- Build a stream declaration for flat, nested, and dynamic JSON
- Write transformations that align with the destination schema
- Send a valid JSON array over the Logs Ingestion API
- Configure AMA JSON and text file collection
- Associate DCRs with agents, VMs, and managed identities
- Configure AgentSettings and AgentDirectToStore DCR kinds
- Troubleshoot authorization, endpoint, stream, payload, and schema failures
- Tear down resources without deleting a custom table unintentionally

## Official references

- [Azure Monitor data collection rules](https://learn.microsoft.com/azure/azure-monitor/essentials/data-collection-rule-overview)
- [DCR structure](https://learn.microsoft.com/azure/azure-monitor/essentials/data-collection-rule-structure)
- [Logs ingestion API](https://learn.microsoft.com/azure/azure-monitor/logs/logs-ingestion-api-overview)
- [Logs ingestion API tutorial](https://learn.microsoft.com/azure/azure-monitor/logs/tutorial-logs-ingestion-api)
- [Data collection transformations](https://learn.microsoft.com/azure/azure-monitor/essentials/data-collection-transformations-kql)
- [Custom text and JSON logs](https://learn.microsoft.com/azure/azure-monitor/essentials/data-collection-rule-samples)
