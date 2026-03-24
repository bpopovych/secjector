# Secjector

Secjector is a tiny RouterOS 7.20+ secrets injector for MikroTik devices. It generates global helper functions to access secrets from flat YAML files. CI-tested against CHR 7.22 on every push.

## Highlights
- Two-line `[:parse ...]` injection pattern
- Flat YAML input (multiline blocks supported) → `$secret "key"` lookups
- Supports keys with colons, spaces, and special characters
- Fail-fast validation via `$secretRequire` and opt-in warning mode
- Uses `:global` functions and map (RouterOS requirement)

## Quick start
```rsc
# optional: :local secretHandlingMode "warn"
[:parse [/file get "secrets.rsc" contents]]
[:parse $OUT]
/user add name="ops" group=full password=[$secret "wifi_password"]
```

Pair it with a `secrets.yaml` file in the same directory:

```yaml
wifi_password: my_super_secret_password
api_key: "some long key with spaces"
```

## Documentation map
- [Usage](usage.md) – helper catalogue, quoting rules, cleanup flow
- [Security](security.md) – operational notes and hardening tips
- [Testing & CI](ci.md) – local checks, integration smoke, and edge cases covered
- [FAQ](faq.md) – quick answers to common RouterOS quirks
- [Roadmap](roadmap.md) – upcoming features and ideas

## What to read next
Start with the [Usage guide](usage.md) to see the helper surface and best practices, then review [Testing & CI](ci.md) for details on regression coverage (quoted keys, spaces, multiline blocks, and more). When you are ready to automate, `.github/workflows/chr-smoke.yml` shows how the CHR smoke job exercises the same flow end-to-end against real firmware.
