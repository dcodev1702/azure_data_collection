# Schemas and naming

## Three schemas, one data flow

A common learning trap is treating the input stream and table as the same schema.

```text
raw record
    -> stream declaration (input types and names)
    -> transformKql
    -> transform output (must match destination)
    -> output stream / table
```

The input declaration describes incoming records. The transform can:

- add `TimeGenerated`
- cast strings to `long` or `datetime`
- rename fields
- remove fields
- parse nested JSON
- expand or pack arrays

The transform output and destination table must use compatible names and data types.

## Canonical naming

Assume the table resource is named `CsaTraining_CL`.

| Concept | Value |
|---|---|
| Logical name | `CsaTraining` |
| Input stream | `Custom-CsaTraining` |
| Output stream | `Custom-CsaTraining_CL` |
| Table | `CsaTraining_CL` |
| URL stream segment | `Custom-CsaTraining` |

Do not append `_CL` to the input stream unless the DCR was intentionally declared that way. Do not replace the input stream in the URL with the output table name.

## Type mapping exercises

| Source value | Suggested destination |
|---|---|
| ISO-8601 timestamp | `datetime` |
| Integer such as an incident ID | `long` |
| Boolean | `boolean` where the table/DCR type supports it; otherwise explicitly model it |
| Text | `string` |
| Nested object | `dynamic` or projected scalar columns |
| Array | `dynamic`, or `mv-expand` during transformation when one record per element is desired |

## Safe schema evolution

1. Add a column to the table.
2. Update the DCR stream declaration or transform as needed.
3. Deploy with the same API version baseline used by the lab.
4. Send one validation record.
5. Query the expected fields.
6. Roll out the change.

Avoid treating a source timestamp field as `TimeGenerated` without validating its value and timezone. Add `TimeGenerated` in the transform when the source has no trustworthy event timestamp.

## Contract example

Input:

```json
{"Title":"Example","Count":"42","OccurredAt":"2025-01-01T12:00:00Z"}
```

Stream declaration:

```json
[
  {"name":"Title","type":"string"},
  {"name":"Count","type":"string"},
  {"name":"OccurredAt","type":"string"}
]
```

Transform:

```kusto
source
| extend
    TimeGenerated = todatetime(OccurredAt),
    EventCount = tolong(Count)
| project TimeGenerated, Title, EventCount
```

Destination:

```text
TimeGenerated: datetime
Title: string
EventCount: long
```
