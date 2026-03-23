# FAQ

**Q: Can I reference `$"wifi-password"` directly?**
A: No. Only `$secret "wifi-password"` works by design.

**Q: Can I log the secret?**
A: Strongly discouraged. Use lengths or checksums if needed.

**Q: Does this support nested YAML?**
A: No. Flat keys only, by design, to keep code small and predictable.

**Q: Can I do this in one line instead of two `:parse` calls?**
A: No. `[:parse [:parse [/file get "secrets.rsc" contents]]]` does not work — RouterOS does not propagate `:global` variables set inside a nested `:parse` back to the outer scope. This behaviour is consistent across RouterOS 7.20 and 7.22.

**Q: How do I run the tests?**
A: `make test` runs static regression guards locally. `make test-integration` pushes to a live RouterOS host — set `ROUTER_HOST`, `ROUTER_USER`, and `ROUTER_IDENT` first. See [Testing & CI](ci.md#test-matrix) for the full matrix.

**Q: Why is the CHR smoke workflow billable on GitHub?**
A: It runs on GitHub-hosted `ubuntu-latest` runners (standard VM minutes). Each push and PR to `main` triggers a run. Use `workflow_dispatch` for on-demand runs, or switch to a self-hosted runner to avoid charges.
