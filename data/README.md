# Sample data

## Fixtures

| File | Format | Purpose |
|---|---|---|
| [json/dummy_data.json](json/dummy_data.json) | JSON array | Small Direct-ingestion lab |
| [json/dummy_data_100.json](json/dummy_data_100.json) | JSON array | Batching and volume exercise |
| [json/schema_lab.json](json/schema_lab.json) | JSON array | Types, arrays, nested objects, null, and missing fields |
| [ndjson/dummy_data.ndjson](ndjson/dummy_data.ndjson) | NDJSON | AMA file and sender parsing |
| [ndjson/dummy_data_100.ndjson](ndjson/dummy_data_100.ndjson) | NDJSON | Batching and volume exercise |
| [ndjson/schema_lab.ndjson](ndjson/schema_lab.ndjson) | NDJSON | Equivalent shape cases for line-oriented collection |

## Schema exercise

[schema_lab.json](json/schema_lab.json) intentionally contains:

- `Count` as a number and as a string
- A nested object
- An array
- An explicit `null`
- A missing optional field
- Mixed hardware and operating-system values

Use `docs/02-schemas-and-naming.md` and `docs/04-json-formats.md` to define how these values are declared, converted, projected, and validated.

## Delimiter rules

- JSON array: one valid JSON document containing an array.
- NDJSON: one JSON object per nonempty line, with a newline after the last record.
- Logs Ingestion sender: reads either format and batches records into a JSON array.

## Malformed fixtures

The invalid example is stored under `tests/fixtures/invalid.ndjson` so production sample validation cannot accidentally ingest it. Tests verify that the production fixtures are valid and the invalid fixture is rejected by parser-oriented exercises.
