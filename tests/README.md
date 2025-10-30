# Tests

- `test` target: lightweight repo checks + static regression guard for `secrets.rsc`.
- `test-integration`: uploads to a live RouterOS and verifies behavior.

Set env:
```
export ROUTER_HOST=192.168.88.1
export ROUTER_USER=admin
export ROUTER_IDENT=~/.ssh/id_ed25519
```

Then:
```
make test-integration
```
