# Usage

Loading `secrets.rsc` defines helpers that keep your secrets local to the invocation scope. The helpers are generated freshly with every call, so they never leak a global map.

## Injection one-liner
```rsc
[:parse [[:parse [/file get "secrets.rsc" contents]]]]
```

Place the line near the top of your script so every subsequent command can call `$secret`, `$secret_has`, or `$secret_require`.

## Helpers at a glance
| Helper | Purpose | Notes |
| --- | --- | --- |
| `$secret "key"` | Returns the value for `key` | Errors when the key is missing/empty (unless warn mode is active) |
| `$secret_has "key"` | Boolean existence check | Useful for optional secrets |
| `$secret_require {"k1";"k2"}` | Validates required keys | Aggregates missing keys in the error/warning message |
| `$secret_cleanup` | Disables helper access | Second call errors so callers cannot re-enable by mistake |

```rsc
[$secret_require {"wifi_password";"api_key"}]
/user add name="ops" group=full password=[$secret "wifi_password"]
```

## Modes
The default mode is fail-fast (`error`). Switch to `warn` before loading the injector if you prefer log warnings plus empty strings for missing keys.

```rsc
:local __secret__handling__mode "warn"
[:parse [[:parse [/file get "secrets.rsc" contents]]]]
```

## Cleanup
Call `$secret_cleanup` once you are done to hard-stop any accidental reuse later in the script:

```rsc
[$secret_cleanup]
# Subsequent calls now error out:
# $secret "wifi_password" => "secrets cleaned"
```

This helper also powers the [integration smoke test](ci.md#test-matrix) to guarantee secrets really become inaccessible.

## Multiline values
```yaml
cert_pem: |
  -----BEGIN CERT-----
  ...
  -----END CERT-----
```

Secjector keeps newline characters intact and escapes only double-quotes, so PEM content and long API payloads remain untouched.

## Keys and quoting
Always use quoted string keys. The parser unquotes them, so you can safely include characters such as spaces, colons, or a leading `@`.

- `[$secret "wifi_password"]` ✔
- `[$secret "wifi-password"]` ✔
- `[$secret "space key"]` ✔ (covered by the integration test)
- `[$secret wifi_password]` works only if you saved the key in a variable first (not recommended)
- `[$secret wifi-password]` ✖ (bare token with hyphen is not a valid RouterOS variable)

See [Testing & CI](ci.md#edge-cases-covered) for the full list of edge cases we exercise automatically.
