# Lab 1: Direct DCR ingestion

## Goal

Create an Analytics custom table and a Direct DCR, submit a JSON array with the Azure PowerShell token, and validate nested JSON and derived fields.

This lab establishes the naming and schema contract used by later examples.

## Resources

- Existing Log Analytics workspace
- `CsaTraining_CL` custom table
- `csa-training-direct-dcr` DCR of kind `Direct`
- No DCE
- No application secret

## 1. Deploy

```powershell
Connect-AzAccount

pwsh -File .\labs\01-direct-ingestion\deploy-lab.ps1 `
  -ResourceGroup <resource-group> `
  -WorkspaceName <workspace-name> `
  -Location <region>
```

The script prints and returns:

- Table resource ID
- DCR resource ID
- Direct Logs Ingestion endpoint
- Immutable DCR ID
- Input stream `Custom-CsaTraining`

Use `-WhatIf` before the first deployment.

## 2. Assign data-plane permission

The interactive lab can use a token from the signed-in identity, but the identity still needs `Monitoring Metrics Publisher` on the DCR if it is not already authorized through a suitable role.

```powershell
$objectId = (Get-AzADUser -UserPrincipalName (Get-AzContext).Account.Id).Id
New-AzRoleAssignment `
  -ObjectId $objectId `
  -RoleDefinitionName "Monitoring Metrics Publisher" `
  -Scope <dcr-resource-id>
```

For a service or application, assign the role to its managed identity or service principal instead of a personal account.

## 3. Send one dataset

```powershell
$config = .\labs\01-direct-ingestion\deploy-lab.ps1 `
  -ResourceGroup <resource-group> `
  -WorkspaceName <workspace-name> `
  -Location <region>

.\labs\01-direct-ingestion\send-sample.ps1 `
  -LogsIngestionEndpoint $config.LogsIngestionEndpoint `
  -DcrImmutableId $config.DcrImmutableId `
  -StreamName $config.StreamName `
  -DataFile .\data\json\dummy_data.json
```

The sender validates the input, serializes bounded batches, and uses the current Azure Monitor token. It does not use a client secret.

## 4. Validate

Open [validate.kql](validate.kql) in the workspace query editor. Within a few minutes:

```kusto
CsaTraining_CL
| where TimeGenerated > ago(30m)
| project TimeGenerated, Name, Source, OS, OSArchitecture, Hardware, Distro, GenAI
| order by TimeGenerated desc
```

Expected learning checks:

- One row per fixture record
- `TimeGenerated` added by the transform
- `Hardware` and `Distro` remain queryable `dynamic` values
- Missing `Distro` values are represented as an empty dynamic field rather than failing ingestion

## 5. Cleanup

Delete the DCR independently:

```powershell
Remove-AzResource -ResourceId <dcr-resource-id> -Force
```

Table deletion has separate retention and data-loss implications. Do not delete `CsaTraining_CL` unless the lab owner explicitly authorizes it.

## Common intentional variations

- Change `Name` case in the fixture and observe the stream mismatch.
- Add an integer field and declare it as `long`.
- Move `TimeGenerated` from the transform to a trusted source field.
- Change `Hardware` to scalar projected columns.
- Send an NDJSON fixture with the same sender.
