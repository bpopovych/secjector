# Testing & CI

Secjector ships with fast local checks plus a full MikroTik Cloud Hosted Router (CHR) smoke test that runs under QEMU in GitHub Actions. The combination guards both the RouterOS script generator and the workflow that exercises it on real firmware.

## Test matrix

| Scope | Command / Workflow | What it covers |
| --- | --- | --- |
| Static regression guard | `make test` | README and example sanity plus `tests/unit/test_regressions.py`, which enforces key unquoting, key escaping, and the `$secret_cleanup` rebinding contract |
| RouterOS integration (ad-hoc) | `make test-integration` | Pushes test fixtures to a RouterOS host (via `ROUTER_HOST`/`ROUTER_USER`/`ROUTER_IDENT`) and asserts lengths + cleanup behaviour reported by the script |
| CHR smoke on GitHub Actions | `.github/workflows/chr-smoke.yml` | Boots CHR 7.17.x under QEMU (no KVM), configures it over the serial console, copies the fixtures, and runs the same integration script nightly |

All tests share the same fixtures (`tests/secrets.yaml`, `tests/integration/example_main.rsc`), so any additional edge cases you add to those files will automatically flow through every layer.

## Edge cases covered

The integration script prints a `TEST_OK` marker with several counters that confirm:

- YAML keys that require quoting (spaces, colons, leading `@`) resolve correctly
- Multiline block scalars preserve the word `CERTIFICATE`
- `$secret_has` returns `false` for missing keys
- `$secret_cleanup` prevents all subsequent helper access and errors on re-entry

The static regression guard also ensures the RouterOS parser keeps unquoting keys and escaping them before populating the local map.

## CHR smoke workflow

The `chr-smoke` GitHub Action uses the same integration script but runs it on a freshly booted CHR instance.

- Runner: `ubuntu-latest` (GitHub-hosted)
- Acceleration: Tiny Code Generator (TCG), because KVM is unavailable in GitHub-hosted runners
- Purpose: nightly correctness smoke, not performance benchmarking

### How it works
1. Download the CHR image (update the version in the workflow when you need newer firmware).
2. Boot with QEMU using user-mode NAT, forwarding host TCP 2222 → guest 22.
3. Connect to the **serial console** with `telnet` + `expect` and configure:
   - IP `10.0.2.15/24` on `ether1`
   - Default route via `10.0.2.2` (QEMU's user-mode gateway)
   - Enable the SSH service
4. `scp` the test files and run `/import file-name=example_main.rsc` to verify `secrets.rsc`.
5. Tear down QEMU gracefully even if the run fails, so the runner is left clean.

### Cost considerations

GitHub bills this workflow as a standard VM job. If you want free runs, switch to a self-hosted runner, reduce the schedule in the workflow, or execute it on demand via `workflow_dispatch`.
