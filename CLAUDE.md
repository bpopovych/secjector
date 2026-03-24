# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Is

**Secjector** is a MikroTik RouterOS secrets injector. It generates RouterOS code from a flat `secrets.yaml` file. The main deliverable is a single RouterOS script (`secrets.rsc`) that parses YAML and exposes `$secret`, `$secretHas`, and `$secretRequire` accessor functions.

Target platform: RouterOS 7.20+. CI-tested against CHR 7.22 (`mikrotik/chr:stable`) on every push.

## Commands

```bash
make test             # Unit tests + regression checks (~1-2 seconds, no hardware needed)
make test-integration # Integration test against live RouterOS (requires ROUTER_HOST, ROUTER_USER, ROUTER_IDENT)
make lint             # yamllint + markdownlint (tools optional)
make docs             # Build MkDocs site
```

Run unit tests directly:
```bash
python3 tests/unit/test_parser.py
python3 tests/unit/test_regressions.py
```

Integration test env vars:
```bash
export ROUTER_HOST=192.168.88.1
export ROUTER_USER=admin
export ROUTER_IDENT=~/.ssh/id_ed25519
make test-integration
```

Expected integration output: `TEST_OK:12:19:5:6:7:T:F:SKIP:N/A`

## Architecture

### Data Flow
```
secrets.yaml (flat YAML)
    → secrets.rsc (192-line RouterOS generator)
    → Generated RouterOS code (returned in $OUT)
    → User scripts call $secret "key", $secretHas "key", etc.
```

### Injection Pattern
```routeros
[:parse [/file get "secrets.rsc" contents]]
[:parse $OUT]
```
Two separate `:parse` calls are required — they cannot be nested (tested on 7.20 and 7.22). The first parse evaluates `secrets.rsc` and stores generated code in `$OUT`; the second parse executes that code. `/import` cannot be used because it creates an isolated scope where globals don't persist.

### RouterOS Constraints
These constraints drove key design decisions in `secrets.rsc`:
- All functions and the secret map **must be `:global`** — RouterOS cannot assign arrays or functions to `:local`
- Function names use camelCase (`$secretHas`, `$secretRequire`) — underscores in `:local` names are rejected
- `$secretCleanup` is disabled — RouterOS cannot `:set` a `:global` function to undefine it

### `secrets.rsc` Structure (the core file)
| Lines | Purpose |
|-------|---------|
| 1–63  | Header, mode setup, file validation |
| 64–78 | Helper functions: `helperTrim`, `helperUnquote`, `helperEsc`, `helperFindColon` |
| 79–126 | YAML parsing loop — reads `secrets.yaml` line by line, splits key:value |
| 127–150 | Generates `$secret`, `$secretHas`, `$secretRequire` accessor functions |
| 151–192 | Returns generated code in `$OUT` |

`helperFindColon` is critical: it finds the first colon *outside* quoted sections, which is what enables keys like `"colon:key"` to work correctly.

### YAML Constraints (by design)
Only flat (non-nested) YAML is supported. Keys may be quoted or unquoted. Multiline values via YAML `|` blocks are supported. Special characters in keys (colons, spaces, `@`) require quoting.

### Modes
```routeros
:local secretHandlingMode "error"  # default: missing key → :error
:local secretHandlingMode "warn"   # missing key → :log warning + return ""
```
Set this before the injection lines.

## Tests

`tests/unit/test_parser.py` — simulates the YAML parser in Python and validates edge cases (colons in keys/values, spaces, special characters, multiline).

`tests/unit/test_regressions.py` — grep-based guards ensuring critical code patterns remain in `secrets.rsc` (e.g., `$helperUnquote` used for key unquoting, `---` YAML marker handled, cleanup comment present).

`tests/integration/example_main.rsc` — example script used by the manual `make test-integration` target.

`tests/integration/ci_runner.rsc` — self-contained integration script used by CI. Loads secrets directly, writes result to `ci-result.txt` (read via a second SSH call, since `/import` suppresses `:put` over SSH).

## CI

`.github/workflows/ci.yml` — runs on every push/PR: `make lint && make test && mkdocs build --strict`.

`.github/workflows/chr-smoke.yml` — runs on every push/PR to `main` (also `workflow_dispatch`). Boots `mikrotik/chr:stable` (7.22) via Docker with KVM passthrough, configures via serial/expect, pushes test files over SSH, runs `ci_runner.rsc`, verifies exact output `TEST_OK:12:19:5:6:7:T:F:SKIP:N/A`.
