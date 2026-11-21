# JSON formats

The accepted shape depends on the ingestion channel. Do not apply a single “compressed-only” rule to every scenario.

## REST ingestion

The Logs Ingestion API receives a JSON array in the request body:

```json
[
  {
    "Name": "Example",
    "Version": "1.0"
  }
]
```

Pretty printing is semantically irrelevant. The object names and types in the DCR stream still matter.

For volume efficiency, serialize many records into one JSON array and batch them below the platform limit rather than issuing one request per record.

## AMA custom JSON logs

A JSON DCR file source uses the format expected by the configured `logFiles.format`. Common agent examples use newline-delimited JSON records. Keep the final record followed by a newline:

```text
{"Name":"A","Version":"1.0"}
{"Name":"B","Version":"1.1"}
```

This format is called NDJSON.

## Conversion matrix

| Input | REST sender |
|---|---|
| JSON array | Parse into objects, batch, serialize the array |
| Single JSON object | Parse and wrap in an array |
| NDJSON file | Parse each nonempty line and serialize a batch as an array |

## Data-shape cases

The curriculum should test:

- A flat scalar-only record
- A nested object stored as `dynamic`
- A nested object projected into scalar columns
- An array stored as `dynamic`
- An array expanded into one row per element
- Missing optional fields
- Explicit `null`
- Numeric data represented as a number
- Numeric data represented as a string and converted in KQL
- Case-sensitive field-name changes
- A malformed line that must fail validation without producing a partial success message

## Type and case discipline

Names are case-sensitive for schema contracts. `Hardware` and `hardware` are different source columns. Keep JSON fixture names, stream declarations, transform expressions, and table column names synchronized.

## Validation before sending

The sender scripts:

1. Require an existing file.
2. Parse every record.
3. Reject an invalid JSON array or NDJSON line.
4. Convert records into an array.
5. Send in bounded batches.
6. Stop and return a nonzero error on a failed request.

Use `-WhatIf` on deployment scripts; sender scripts are non-destructive but still consume API quota.
