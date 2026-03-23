# Security

- No `/system/script/environment`.
- No persistent global maps — `secretMap` is created fresh on each load.
- Consider ephemeral fetch of `secrets.yaml` (e.g. via `/tool fetch` with a presigned URL), then delete the file immediately after loading.
- Limit file read permissions to admin-level users.
- `$secretCleanup` is not available on RouterOS 7.20+ — the interpreter cannot `:set` a `:global` function variable. To block follow-up access, remove or overwrite the `secrets.yaml` file from the router's filesystem after loading.
