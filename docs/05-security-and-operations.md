# Security and operations

## Authentication

Preferred choices:

1. Managed identity for an Azure-hosted producer
2. Federated workload identity for CI/CD
3. The current signed-in Azure PowerShell identity for interactive labs
4. A client secret only for a short-lived transitional scenario, supplied from a secret store

Never commit an application secret. The repository intentionally contains no executable secret placeholders.

For the Logs Ingestion API, the identity needs permission on the target DCR. The lab validates the token against the Azure Monitor resource audience and keeps table-control and data-plane permissions separate.

## Least privilege

Separate roles:

- Resource deployment: rights to create the table, DCE, DCR, and association
- Data producer: `Monitoring Metrics Publisher` or equivalent scoped to the DCR
- Query operator: read/query rights on the workspace
- Cost/retention administrator: workspace/table retention permissions

Do not grant the producer workspace Owner.

## Safe deployments

Every mutating PowerShell function in this repository uses `SupportsShouldProcess`. A deployment should:

1. Read current resource state.
2. Validate existing kind/schema compatibility.
3. Use `WhatIf` to preview.
4. Return an error rather than silently skipping a drifted resource.
5. Be idempotent only when the desired state matches.

Deletion requires an explicit `-Confirm` or `-Delete` action. Table deletion is separate from DCR and DCE deletion.

## Operational checks

After deployment:

- Verify the DCR association, if agent-based
- Query the table for one test record
- Confirm timestamps and event count
- Validate nested `dynamic` fields
- Record the immutable DCR ID and endpoint
- Validate the expected RBAC scope
- Monitor throttling and failed requests; the sender retries 429 and 5xx failures with bounded incremental delays
- Document the rollback and retention implications

## Payload hygiene

Do not ingest:

- Credentials or tokens
- Personal data not required for the use case
- Unbounded raw request bodies
- Data whose query/retention owner is undefined

Prefer projection and transformation to remove sensitive fields before storage.
