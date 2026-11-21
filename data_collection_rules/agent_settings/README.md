# AMA AgentSettings: disk cache

This example changes the Azure Monitor Agent (AMA) disk cache through a DCR of kind `AgentSettings`. It is separate from a data-collection DCR: a VM can be associated with both.

## Files

- [ama-agent-settings-dcr.json](ama-agent-settings-dcr.json): ARM template
- [ama_disk_cache_reporting.sh](ama_disk_cache_reporting.sh): Linux verification script

## Learning objectives

- Explain the `AgentSettings` DCR kind.
- Parameterize a cache size instead of editing the template.
- Use the required `agentSettings` DCR association.
- Verify the configured value and distinguish it from current disk usage.
- Associate the same settings DCR with multiple managed resources.

## 1. Deploy

```bash
az deployment group create \
  --resource-group <resource-group> \
  --template-file ama-agent-settings-dcr.json \
  --parameters \
    dcrName=ama-cache-training \
    location=<region> \
    diskCacheSizeMB=15360
```

The template validates a value between 4000 MB and 1000000 MB.

## 2. Associate

The association name is intentionally `agentSettings`:

```bash
az monitor data-collection rule association create \
  --name agentSettings \
  --rule-id <agent-settings-dcr-resource-id> \
  --resource <vm-or-arc-resource-id>
```

Use a normal DCRA name such as `trainingAssociation` for a data-collection DCR. The fixed `agentSettings` name applies to this special association type.

## 3. Verify

On Linux:

```bash
sudo ./ama_disk_cache_reporting.sh
```

On Windows, inspect the AMA configuration cache under the documented AMA data directory and confirm `MaxDiskQuotaInMB`.

## Sizing guidance

| Environment | Example cache |
|---|---:|
| Development | 4000-10000 MB |
| Standard production | 10000-100000 MB |
| High-volume/offline workload | 100000-400000 MB |
| Maximum supported example | 1000000 MB |

Larger caches consume local disk. Base the value on outage duration, event rate, average payload size, available disk, and the organization's recovery objective.

## Troubleshooting

| Symptom | Check |
|---|---|
| Association name rejected | Use exactly `agentSettings` |
| DCR does not apply | Verify kind `AgentSettings` and correct resource ID |
| No change after deployment | Allow propagation, then check the agent configuration and service health |
| Cache appears full | Compare configured quota, current local usage, filesystem capacity, and upload health |

## Operations

- Associate the settings DCR before relying on offline collection.
- Monitor local disk capacity independently of the configured AMA quota.
- Version the ARM template and review cache changes as capacity changes.
- Delete the association before removing a settings DCR when a resource should revert to defaults.
