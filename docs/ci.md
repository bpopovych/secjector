# CI: CHR smoke test on GitHub Actions (QEMU, no KVM)

This job boots MikroTik Cloud Hosted Router (CHR) under QEMU **without KVM** on GitHub-hosted runners, configures it over the serial console, then runs a tiny smoke test of Secjector via SSH.

- Runner: `ubuntu-latest` (GitHub-hosted)
- Acceleration: TCG (no nested KVM)
- Purpose: quick smoke, not performance benchmarking

## How it works
1. Download CHR image (edit version if needed).
2. Boot with QEMU using user-mode NAT, forwarding host TCP 2222 → guest 22.
3. Connect to the **serial console** with `telnet` + `expect` and configure:
   - IP `10.0.2.15/24` on `ether1`
   - Default route via `10.0.2.2` (QEMU's user-mode gateway)
   - Enable SSH service
4. `scp` test files and run `/import` to verify `secrets.rsc`.
5. Kill QEMU.

## Workflow file
See `.github/workflows/chr-smoke.yml`.
