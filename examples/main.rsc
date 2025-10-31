# Example usage of Secjector (v0.1.3 - RouterOS 7.20.x compatible)

# Optional: switch to warnings
# :local secretHandlingMode "warn"

# Two-line injection (RouterOS 7.20.x pattern)
[:parse [/file get "secrets.rsc" contents]]
[:parse $OUT]

# Validate and use (note: camelCase function names)
[$secretRequire {"wifi_password";"api_key"}]

# Use secrets directly in commands
/user add name="ops" group=full password=[$secret "wifi_password"]

# Or store in :global variable (NOT :local - RouterOS 7.20.x limitation)
:global myApiKey [$secret "api_key"]
:put ("API key length: " . [:len $myApiKey])

# Check if secret exists
:if ([$secretHas "optional_secret"]) do={
  :put "Optional secret is present"
}

# Note: secretCleanup not available in v0.1.3 (RouterOS 7.20.x limitation)
