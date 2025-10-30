# FAQ

**Q: Can I reference `$"wifi-password"` directly?**  
A: No. Only `$secret "wifi-password"` works by design.

**Q: Can I log the secret?**  
A: Strongly discouraged. Use lengths or checksums if needed.

**Q: Does this support nested YAML?**  
A: No. Flat keys only by design to keep code small and predictable.

**Q: How do I run the tests?**  
A: `make test` runs static regression guards. `make test-integration` pushes to a RouterOS host if you export `ROUTER_HOST`, `ROUTER_USER`, and `ROUTER_IDENT`. See [Testing & CI](ci.md#test-matrix) for the full matrix (including the GitHub-hosted CHR smoke job).

**Q: Why is the CHR smoke workflow billable on GitHub?**  
A: It runs on GitHub-hosted `ubuntu-latest` runners under QEMU, so each minute counts against your hosted-runner quota. Use a self-hosted runner or manual triggers if you need to avoid charges.
