# Capstone: Windows events directly to Blob Storage and ADX

## Goal

Use an `AgentDirectToStore` DCR to route selected Windows Security events to Azure Storage, then either query the files as an ADX external table or ingest them into an ADX internal table.

This is an advanced lab. Complete the Direct DCR and AMA concepts first.

## Staged architecture

1. [PoC_provision.json](PoC_provision.json) creates:
   - User-assigned managed identity
   - StorageV2 account and private blob container
   - Storage Blob Data Contributor assignment
   - `AgentDirectToStore` DCR
2. Assign the identity to the existing VM:

```bash
az vm identity assign \
  --resource-group <resource-group> \
  --name <vm-name> \
  --identities <user-assigned-identity-resource-id>
```

3. Deploy [default_templates/dcr_to_vm_association.json](default_templates/dcr_to_vm_association.json) to:
   - Associate the DCR with the VM
   - Configure/upgrade the Azure Monitor Windows Agent to use the identity
4. Generate one of the selected Windows events and verify the container receives JSON.
5. Choose an ADX path:
   - [ADX/InternalTableSolution.kql](ADX/InternalTableSolution.kql) for Event Grid ingestion and an internal table
   - The external-table query below for query-at-rest on Blob Storage

Separating resource creation from VM modification is intentional. ARM templates should not attempt to PUT an existing VM with only a subset of its normal compute configuration.

## Stage 1 deployment

```bash
az deployment group what-if \
  --resource-group <resource-group> \
  --template-file PoC_provision.json \
  --parameters storageAccountName=<globally-unique-name>

az deployment group create \
  --resource-group <resource-group> \
  --template-file PoC_provision.json \
  --parameters storageAccountName=<globally-unique-name>
```

Use `--parameters` for any names that must differ. Do not edit hard-coded resource IDs.

## Stage 2 validation

Check:

- The DCR kind is `AgentDirectToStore`.
- The storage destination includes the intended container and identity.
- The identity has Storage Blob Data Contributor at the storage account scope.
- The VM has the identity.
- The VM has the DCR association and AMA extension.
- Blob public access and shared-key access are disabled.

## External ADX table

First attach the identity to ADX with [map_uai_2_adx.json](map_uai_2_adx.json), then allow that identity to use `ExternalTable` in the cluster policy. Use the real managed-identity object ID and storage endpoint.

```kusto
let options = dynamic({
  'StorageContainers': [
    h@'https://<storage-account>.blob.core.windows.net/<container>;impersonate'
  ],
  'fileExtension': '.json',
  'kind': 'storage',
  'dataformat': 'json'
});
evaluate infer_storage_schema(options)
```

Create the external table only after inspecting the actual generated path and schema. Replace the partition and `pathformat` clauses with the path pattern observed in your container:

```kusto
.create external table WinEventsEXT (records: dynamic)
kind=storage
partition by (InstanceId:string, IngestTime:datetime)
pathformat = ("i=" InstanceId "/" datetime_pattern("y={yyyy}/m={MM}/d={dd}/h={HH}/m={mm}", IngestTime))
dataformat = multijson
(
  h@'https://<storage-account>.blob.core.windows.net/<container>;managed_identity=<identity-object-id>'
)
with (filesPreview=true, fileExtension=".json")
```

```kusto
external_table("WinEventsEXT")
| mv-expand records
| evaluate bag_unpack(records)
```

## Internal ADX table

The internal-table solution uses:

1. Raw staging table
2. JSON ingestion mapping
3. Typed destination table
4. Expand function
5. Update policy
6. Event Grid ingestion connection created after the preceding resources exist

Do not create the Event Grid connection first; the target table, mapping, and update policy must already exist.

## Troubleshooting

- No blobs: inspect identity assignment, RBAC propagation, DCR association, selected XPath, and AMA health.
- Blobs exist but ADX returns none: inspect path format, container URL, identity usage, and `multijson` requirements.
- ADX sees rows but fields are missing: compare actual blob records with the expansion function and update mapping.
- Deployment fails at storage authorization: verify the principal deploying the template can create role assignments.
