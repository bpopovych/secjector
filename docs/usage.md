# Usage

## One-liner
```rsc
[:parse [[:parse [/file get "secrets.rsc" contents]]]]
```

## Accessors
```rsc
[$secret_require {"wifi_password";"api_key"}]
/user add name="ops" group=full password=[$secret "wifi_password"]
```

## Modes
- Default: `error` on missing keys
- Optional: `warn`
```rsc
:local __secret__handling__mode "warn"
[:parse [[:parse [/file get "secrets.rsc" contents]]]]
```

## Multiline values
```yaml
cert_pem: |
  -----BEGIN CERT-----
  ...
  -----END CERT-----
```

## Hyphens, underscores, and quoting
Use quoted string keys:
- `[$secret "wifi_password"]` ✔
- `[$secret "wifi-password"]` ✔
- `[$secret wifi_password]` only if you defined `:local wifi_password "wifi_password"` beforehand (not recommended)
- `[$secret wifi-password]` ✖ (bare token with hyphen is not a valid variable)
