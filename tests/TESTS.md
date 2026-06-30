# Tests

## How to run

```sh
/path/to/venv/bin/python3 -m unittest tests/test_config.py -v
```

## What is tested

**`test_config.py`** — validates `config.yaml` against `config.schema.yaml` and
provides a place for tool-specific parameter checks.

| Test | Description |
|---|---|
| `test_config_valid_against_schema` | Full JSON-schema (Draft-7) validation of `config.yaml` |
| `test_random_seed_allows_null` | `common_parameters.random_seed` may be `null` |

## Adding tests for your tool

When you fill in `advanced_parameters`, add matching assertions under section 3 of
`test_config.py` (commented examples are provided): numeric bounds, enum membership,
and any cross-field invariants (e.g. `min < max`). Keep the two baseline tests above.
