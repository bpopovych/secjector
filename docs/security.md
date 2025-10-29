# Security

- No `/system/script/environment`.
- No global maps in caller scope.
- Consider ephemeral fetch of `secrets.yaml`, then delete it.
- Limit file read permissions to admin-level users.
- Use `$secret_cleanup` if you want to block any follow-up access in a long script.
