# DCE and DCR ARM examples

Choose the template that matches the ingestion path:

| Template | DCR kind | DCE | Purpose |
|---|---|---|---|
| [DCE-Template.json](DCE-Template.json) | N/A | Creates it | Regional endpoint resource |
| [DCR_Kind-Direct.json](DCR_Kind-Direct.json) | `Direct` | No | Direct Logs Ingestion API |
| [DCR-Template.json](DCR-Template.json) | `Windows` | Yes | AMA JSON/text file collection |
| [AuxiliaryTable/msevent_aux_cl.json](AuxiliaryTable/msevent_aux_cl.json) | `Windows` | No | Native Windows events to an Auxiliary table |
| [ThreatData/TD_MDE_DCR_Direct.json](ThreatData/TD_MDE_DCR_Direct.json) | `Direct` | No | Renaming and typed fields |

## Direct DCR contract

A `Direct` DCR exposes its own `logsIngestion` endpoint. Send to:

```text
<logsIngestion endpoint>/dataCollectionRules/<immutable DCR ID>/streams/<input stream>?api-version=2023-01-01
```

Do not add a DCE solely because the sender uses REST.

## DCE-backed agent collection

AMA file/event collection examples use a DCR kind of `Windows` or `Linux` and reference the DCE with `dataCollectionEndpointId`. The monitored resource is connected to the DCR through a DCR association.

## Input versus output streams

For a table named `TrainingFiles_CL`:

- Input stream: `Custom-TrainingFiles`
- REST URL stream: `Custom-TrainingFiles`
- Output stream: `Custom-TrainingFiles_CL`

The `streamDeclarations` section describes the input stream. The `dataFlows.outputStream` value selects the destination custom table.

## Deployment order

1. Create the workspace table.
2. For a DCE-backed path, deploy `DCE-Template.json`.
3. Deploy the matching DCR template.
4. For agent collection, associate the DCR and confirm AMA.
5. Send one test record.
6. Validate the table with KQL.

Use `az deployment group validate` and `az deployment group what-if` before applying an ARM template.
