# Table plans and retention

## Plan comparison

| Plan | Typical use | Query considerations | Retention guidance |
|---|---|---|---|
| Analytics | Operational investigation, alerting, joins, frequent queries | Supports the richest Log Analytics query experience | Set interactive retention deliberately; use total retention for longer archive |
| Basic | High-volume data queried occasionally | Intended for occasional retrieval; costs and query capabilities differ from Analytics | Validate query and alert requirements before choosing |
| Auxiliary | High-volume verbose records with limited direct investigation needs | Designed for supplemental data; plan and feature limitations must be checked for the workload | Set total retention for the archive use case |

Plan selection is an architecture decision, not a script detail. Use the same table schema and compare representative queries and volume assumptions before selecting a plan.

## Retention fields

ARM/table REST payloads may include:

- `retentionInDays`: interactive retention
- `totalRetentionInDays`: total retention including archive
- `plan`: `Analytics`, `Basic`, or `Auxiliary`

If `plan` is omitted, verify the resulting plan rather than assuming it.

## Decision prompts

Choose Analytics when:

- The data feeds frequent investigations or dashboards
- Joins and regular analytics are central
- Alert and search latency matters

Consider Basic or Auxiliary when:

- Data volume is high
- Query frequency is low
- The workload can tolerate the plan's feature and cost model

## Repository examples

- [basic_custom_log.ps1](../create_custom_table/basic_custom_log.ps1) demonstrates an Analytics-style two-column table.
- [create_custom_table.ps1](../create_custom_table/create_custom_table.ps1) demonstrates an Auxiliary table with nested fields.
- [create_msevent_aux_table.ps1](../create_custom_table/AuxiliaryTable/create_msevent_aux_table.ps1) demonstrates an Auxiliary event schema.

All scripts expose retention and plan settings as parameters rather than requiring source edits.

## Cost exercise

Estimate:

```text
daily GB = events per day * average payload bytes / 1,000,000,000
retained GB = daily GB * total retention days
```

Compare the estimate with each selected plan's Azure Monitor pricing and your workspace commitment. Payload sampling should include encoded transport overhead and realistic variance.
