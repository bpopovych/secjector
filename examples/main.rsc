# Example usage of Secjector

# Optional: switch to warnings instead of errors on missing keys
# :local secretHandlingMode "warn"

# Two-line injection (the two :parse calls cannot be nested)
[:parse [/file get "secrets.rsc" contents]]
[:parse $OUT]

# Validate required keys up-front
[$secretRequire {"wifi_password";"api_key"}]

# Use secrets directly in commands (preferred)
/user add name="ops" group=full password=[$secret "wifi_password"]

# Or store in a variable
:local apiKey [$secret "api_key"]
:put ("API key length: " . [:len $apiKey])

# Check if an optional secret exists
:if ([$secretHas "optional_secret"]) do={
  :put "Optional secret is present"
}
