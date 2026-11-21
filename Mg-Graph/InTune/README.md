# Microsoft Intune as a source producer

[List-InTuneDevices.ps1](List-InTuneDevices.ps1) is a source-system example rather than an Azure Monitor resource example. It shows how a CSA can collect realistic structured records before designing the DCR.

## Learning flow

1. Connect to Microsoft Graph.
2. Export managed-device records.
3. Inspect the actual JSON shape.
4. Select scalar and `dynamic` columns.
5. Design the destination table.
6. Design a DCR stream declaration.
7. Add a transform for fields that should be renamed or normalized.
8. Submit the JSON array with [send_json_data_to_loga.ps1](../../send_json_data_to_loga.ps1).

## Run

```powershell
. .\List-InTuneDevices.ps1
$devices = List-InTuneDevices `
  -Environment Global `
  -TenantId <tenant-id> `
  -JsonOutputPath .\IntuneDevices.json
```

The script fails on Graph request errors rather than returning a partial successful export. It follows paging and emits the complete in-memory collection.

## Schema exercise

Before ingesting the export:

- Verify every field name and type in a representative record.
- Do not ingest fields that are not needed.
- Convert device timestamps to `datetime` in the transform.
- Keep variable nested device properties as `dynamic` or select specific paths.
- Treat the Graph export as a source contract that can evolve.

## Security

The script uses delegated Graph access. Prefer application permissions with a managed workload identity for unattended production collection, and grant only the device-management permission needed by the query.
