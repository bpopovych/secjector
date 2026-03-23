# Testing & CI

Secjector ships with fast local checks plus a full MikroTik Cloud Hosted Router (CHR) smoke test that runs in GitHub Actions on every push and PR. The combination guards both the RouterOS script generator and the workflow that exercises it on real firmware.

## Test matrix

| Scope | Command / Workflow | What it covers |
|-------|--------------------|----------------|
| Static regression guard | `make test` | Repo sanity plus `tests/unit/test_regressions.py`, which enforces key unquoting, key escaping, and other critical code patterns in `secrets.rsc` |
| RouterOS integration (ad-hoc) | `make test-integration` | Pushes test fixtures to a live RouterOS host (via `ROUTER_HOST`/`ROUTER_USER`/`ROUTER_IDENT`) and asserts the exact result string |
| CHR smoke on GitHub Actions | `.github/workflows/chr-smoke.yml` | Boots CHR 7.22 via Docker with KVM, configures it over the serial console, copies the fixtures, runs the integration script, and verifies the exact output |

## Edge cases covered

The integration script (`tests/integration/ci_runner.rsc`) prints a `TEST_OK` marker with counters that confirm:

- YAML keys that require quoting (spaces, colons, leading `@`) resolve correctly
- Multiline block scalars preserve the word `CERTIFICATE`
- `$secretHas` returns `false` for missing keys

Expected result: `TEST_OK:12:19:5:6:7:T:F:SKIP:N/A`

The static regression guard also ensures critical patterns in `secrets.rsc` remain intact across edits (e.g. `$helperUnquote` used for key unquoting, `---` YAML marker handling).

## CHR smoke workflow

The `chr-smoke` GitHub Action runs on every push and PR to `main`, and can also be triggered manually via `workflow_dispatch`.

- Runner: `ubuntu-latest` (GitHub-hosted)
- Image: `mikrotik/chr:stable` (RouterOS 7.22)
- Acceleration: KVM passthrough (`--device /dev/kvm` + `--group-add`) — boot takes ~12 seconds

### How it works

1. Start the `mikrotik/chr:stable` Docker container with a custom QEMU startup script that enables KVM and forwards host TCP 2222 → guest SSH port 22.
2. Connect to the **serial console** via telnet + expect and configure:
   - Skip the first-login wizard (Ctrl-C)
   - Add default route via `10.0.2.2` (QEMU user-mode gateway)
   - Enable the SSH service
3. Wait for SSH to become available.
4. `scp` `secrets.rsc`, `tests/secrets.yaml`, and the integration scripts to the router.
5. Run `/import file-name=ci_runner.rsc` via SSH; the script writes its result to `ci-result.txt`.
6. Read `ci-result.txt` via a second SSH call and assert the exact expected string.
7. Tear down the Docker container (happens even on failure).

### Cost considerations

GitHub bills this workflow as standard hosted-runner VM minutes. Each push and PR to `main` triggers a run (~2 minutes). Use `workflow_dispatch` for on-demand runs, or a self-hosted runner to eliminate charges.
