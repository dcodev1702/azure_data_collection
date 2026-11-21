# Troubleshooting

## 400 payload or schema failure

Check:

1. The request body is a valid JSON array.
2. The URL uses the input stream, not the table name.
3. Names match exactly, including case.
4. Stream types accept the incoming values.
5. The transform output matches the destination table.
6. Required `TimeGenerated` exists.

Send one record and query it before sending a batch.

## 401 or 403

- Confirm the token audience is Azure Monitor.
- Confirm the identity exists in the tenant.
- Assign the publisher role on the specific DCR, not only on the workspace.
- Wait for RBAC propagation.
- Verify the sender uses the intended endpoint type.

## 404 resource or endpoint

- Direct DCR: use its `logsIngestion` endpoint and immutable ID.
- DCE-based DCR: use the DCE endpoint and immutable ID.
- Confirm the subscription, region, DCR name, and stream spelling.
- Do not substitute the ARM resource ID for the immutable DCR ID.

## Rows are present but fields are empty

The transform and table likely disagree. Query:

```kusto
CsaTraining_CL
| take 10
| extend record = pack_all()
```

Then compare `record` with the DCR transform output.

## AMA does not send file records

- Confirm the file pattern escapes correctly for the operating system.
- Verify the AMA extension is installed and healthy.
- Verify the DCR association.
- Confirm the DCR kind matches Windows or Linux.
- Check that NDJSON ends with a newline.
- Confirm the agent can read the source path.

## AgentDirectToStore troubleshooting

- Verify the DCR has kind `AgentDirectToStore`.
- Verify the storage destination container exists.
- Verify the identity reference and Blob Data Contributor scope.
- Verify the VM is associated with the DCR and AMA uses the intended identity.
- Inspect the storage container before debugging ADX mappings.

## KQL validation starter

```kusto
CsaTraining_CL
| where TimeGenerated > ago(30m)
| summarize Rows=count() by bin(TimeGenerated, 1m)
| order by TimeGenerated desc
```

## Debugging checklist

```text
[ ] Table exists with expected plan and columns
[ ] DCR kind matches the ingestion path
[ ] Input stream name matches URL
[ ] Output stream matches table
[ ] Transform output types and names match table
[ ] Token identity has DCR-scoped permission
[ ] One-record payload succeeds
[ ] Query result contains expected values
[ ] Batching and retry behavior are tested
[ ] Cleanup behavior is documented
```
