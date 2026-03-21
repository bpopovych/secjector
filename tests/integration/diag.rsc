# Diagnostic script — run on failure to understand parser state.
# Shows files on the router, loads secrets, and prints key values.

:put "=== files ==="
:foreach f in=[/file find] do={
    :put [/file get $f name]
}

:put "=== load secrets.rsc ==="
:do {
    [:parse [/file get "secrets.rsc" contents]]
    :global OUT
    :put ("OUT len=" . [:len $OUT])
    :put "=== parse OUT ==="
    [:parse $OUT]
    :global secret
    :global secretMap
    :put "=== secretMap ==="
    :put $secretMap
    :put "=== wifi_password ==="
    :put [$secret "wifi_password"]
} on-error={
    :put ("error: " . $0)
}
