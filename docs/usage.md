# Usage

## Injection pattern

Two `:parse` calls are required. They cannot be nested into one line — RouterOS does not propagate `:global` variables set inside a nested `:parse` back to the calling scope.

```rsc
[:parse [/file get "secrets.rsc" contents]]
[:parse $OUT]
```

Place these lines near the top of your script. Every subsequent command can then call `$secret`, `$secretHas`, or `$secretRequire`.

## Helpers at a glance

| Helper | Purpose | Notes |
|--------|---------|-------|
| `$secret "key"` | Returns the value for `key` | Errors when missing/empty unless `warn` mode is active |
| `$secretHas "key"` | Boolean existence check | Useful for optional secrets |
| `$secretRequire` | Validates a set of required keys | Aggregates missing keys in the error/warning message |

```rsc
/user add name="ops" group=full password=[$secret "wifi_password"]
:local token [$secret "api_key"]
:if [$secretHas "optional_flag"] do={ ... }
```

## Modes

The default mode is fail-fast (`error`). Set `secretHandlingMode` to `"warn"` **before** the two `:parse` lines to get log warnings and empty strings for missing keys instead:

```rsc
:local secretHandlingMode "warn"
[:parse [/file get "secrets.rsc" contents]]
[:parse $OUT]
```

## Multiline values

```yaml
cert_pem: |
  -----BEGIN CERT-----
  ...
  -----END CERT-----
```

Secjector keeps newline characters intact and escapes only double-quotes, so PEM content and long API payloads remain untouched.

## Keys and quoting

Always use quoted string keys. The parser strips quotes, so you can safely include spaces, colons, or a leading `@`:

- `[$secret "wifi_password"]` ✅
- `[$secret "wifi-password"]` ✅
- `[$secret "space key"]` ✅ (covered by the integration test)
- `[$secret wifi_password]` ⚠️ only works if you previously defined `:local wifi_password "wifi_password"` (not recommended)
- `[$secret wifi-password]` ❌ bare token with hyphen is not a valid RouterOS variable

See [Testing & CI](ci.md#edge-cases-covered) for the full list of edge cases exercised automatically.
