# Architecture and ingestion paths

## Core resources

| Resource | Responsibility |
|---|---|
| Log Analytics custom table | Stores records and applies plan/retention settings |
| DCR | Declares inputs, transformations, destinations, and data flows |
| DCE | Supplies a regional ingestion endpoint for DCE-based DCRs and some network-isolated designs |
| DCR association | Connects AMA collection configuration to a VM, Arc server, or VM scale set |
| Identity | Authenticates the sender and receives scoped authorization on the DCR |

## Ingestion paths

### 1. Direct DCR ingestion

Use this for an application, script, Logic App, or function that posts JSON to a DCR-provided Logs Ingestion endpoint.

```text
Sender -> Direct DCR logsIngestion endpoint -> transform -> Log Analytics table
```

A Direct DCR does not need a DCE. The sender URL uses the Direct DCR's `logsIngestion` endpoint, immutable DCR ID, and custom input stream.

### 2. DCE-based ingestion

Use this when the DCR is not `Direct` and the endpoint is supplied by a DCE, or when the solution deliberately uses DCE networking and routing.

```text
Sender -> DCE -> DCR -> transform -> Log Analytics table
```

The DCR references the DCE resource ID and the sender uses the DCE endpoint.

### 3. AMA file or event collection

AMA reads a configured Windows event log, Linux file, JSON file, or text file and sends records through its associated DCR.

```text
VM/Arc server -> AMA -> associated DCR -> transform -> Log Analytics table
```

The DCR kind must match the operating-system collection scenario. The association connects the DCR configuration to the agent-bearing resource.

### 4. AgentDirectToStore

AMA sends selected events directly to an Azure Storage destination instead of a Log Analytics table.

```text
VM/Arc server -> AMA -> AgentDirectToStore DCR -> Blob Storage -> ADX or downstream processing
```

The storage destination requires an identity with the appropriate blob data role.

## DCR kind comparison

| Kind | Typical purpose | DCE required? |
|---|---|---|
| `Direct` | REST/API ingestion to a DCR endpoint | No |
| `Windows` | Windows agent collection | Depends on design; DCR-based agent scenarios commonly reference a DCE |
| `Linux` | Linux agent collection | Depends on design; DCR-based agent scenarios commonly reference a DCE |
| `AgentSettings` | AMA local configuration such as disk cache | No data endpoint |
| `AgentDirectToStore` | AMA destination is Blob Storage | No Log Analytics destination is required |

Use the exact kind appropriate to the lab rather than changing only the data source.

## Deployment order

1. Confirm the Log Analytics workspace and required providers.
2. Create the destination custom table.
3. Create the DCR or DCE and DCR.
4. For agent collection, install/confirm AMA.
5. Associate the DCR with the monitored resource.
6. Assign the minimum identity permissions.
7. Send a deliberately small fixture.
8. Validate with KQL.
9. Scale to production volume.

## Cost and privacy checkpoint

Before deployment, state:

- Expected events per second and average record size
- Required interactive retention and total retention
- Whether sensitive values must be projected out
- Whether Auxiliary is valid for the operational query pattern
- Who can query the destination workspace
- Whether storage or ADX is a better destination for large-volume archive use
