# FAQ

**Q: Can I reference `$"wifi-password"` directly?**  
A: No. Only `$secret "wifi-password"` works by design.

**Q: Can I log the secret?**  
A: Strongly discouraged. Use lengths or checksums if needed.

**Q: Does this support nested YAML?**  
A: No. Flat keys only by design to keep code small and predictable.
