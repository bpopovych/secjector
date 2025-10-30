# Secjector

Secjector is a tiny RouterOS v7 secrets injector that keeps credentials scoped to the caller by generating local helper functions on demand. It is designed for air-gapped, one-off provisioning flows where you need repeatable scripts without dumping secrets into `/system/script/environment`.

## Highlights
- Single `[:parse ...]` line to load helpers from `secrets.rsc`
- Flat YAML input (multiline blocks supported) → `$secret "key"` lookups
- Fail-fast validation via `$secret_require` and opt-in warning mode
- No globals or environment variables left behind after execution

## Quick start
```rsc
# optional: :local __secret__handling__mode "warn"
[:parse [[:parse [/file get "secrets.rsc" contents]]]]
[$secret_require {"wifi_password";"api_key"}]
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
Start with the [Usage guide](usage.md) to see the helper surface and best practices, then review [Testing & CI](ci.md) for details on regression coverage (quoted keys, spaces, cleanup, multiline blocks, and more). When you are ready to automate, `.github/workflows/chr-smoke.yml` shows how the nightly QEMU job exercises the same flow end-to-end.
