# Lab 2: JSON shapes and transformations

## Goal

Compare nested objects, arrays, `null`, missing fields, numeric strings, conversion success, and conversion failure.

Use [schema_lab.json](../../data/json/schema_lab.json) and [schema_lab.ndjson](../../data/ndjson/schema_lab.ndjson). Both contain the same records.

## Input declaration exercise

Declare these source fields:

| Field | Input type |
|---|---|
| `EventId` | `long` |
| `Count` | `dynamic` if both number and string values must be accepted |
| `CountAsText` | `string` |
| `OccurredAt` | `string` |
| `Device` | `dynamic` |
| `OptionalNote` | `string` or compatible optional value |

In a production source, do not intentionally mix a number and a numeric string. The mixed values here demonstrate why source contracts matter.

## Transform exercise

```kusto
source
| extend
    TimeGenerated = todatetime(OccurredAt),
    EventCount = tolong(Count),
    ConvertedCount = tolong(CountAsText),
    DeviceName = tostring(Device.Name),
    TagCount = array_length(Device.Tags)
| project
    TimeGenerated,
    EventId,
    EventCount,
    ConvertedCount,
    DeviceName,
    TagCount,
    OptionalNote
```

## Expected outcomes

- Record 1001 converts cleanly.
- Record 1002 converts the `Count` string through `tolong`.
- Record 1003 produces a null `ConvertedCount`.
- The missing `OptionalNote` is distinct from an explicit null only if the source pipeline preserves that distinction.
- `Device` can be retained as `dynamic` or projected into columns.

Add an explicit error projection if malformed conversions must be visible:

```kusto
| extend ConversionFailed = isnull(ConvertedCount) and isnotempty(CountAsText)
```

## Intentional failure test

Run the sender against `tests/fixtures/invalid.ndjson`. The script must reject line 2 and must not report a successful upload.

## Learning checkpoint

Explain:

1. Which values belong in the input declaration
2. Which types are introduced by the transform
3. Which output columns must exist in the table
4. When `dynamic` is useful and when explicit columns are safer
5. How the sender handles JSON arrays differently from NDJSON
