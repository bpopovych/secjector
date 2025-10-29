# Example usage of Secjector

# Optional: switch to warnings
# :local __secret__handling__mode "warn"

# One-line injection
[:parse [[:parse [/file get "secrets.rsc" contents]]]]

# Validate and use
[$secret_require {"wifi_password";"api_key"}]

/user add name="ops" group=full password=[$secret "wifi_password"]
:put ("TEST_OK:" . [:len [$secret "wifi_password"]] . ":" . [:len [$secret "api_key"]])

# Optional cleanup to block further access
# [$secret_cleanup]
