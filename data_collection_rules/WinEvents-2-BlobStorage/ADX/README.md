# ADX ingestion choices

## External table

Best for query-at-rest exploration of the Blob Storage path. No duplicate persisted copy is created in ADX. Use the external-table commands in the parent README after inspecting the actual blob path.

## Internal table

Use [InternalTableSolution.kql](InternalTableSolution.kql) when an Event Grid connection continuously ingests blobs into an ADX cluster.

Order:

1. Create raw table.
2. Create ingestion mapping.
3. Create destination schema.
4. Create expansion function.
5. Enable update policy.
6. Create the Event Grid ingestion connection.

The one-day raw retention is long enough to inspect and troubleshoot ingestion but short enough to avoid turning staging into a second archive.
