# Smoke entrypoint for CI
[:parse [[:parse [/file get "secrets.rsc" contents]]]]
[$secret_require {"wifi_password";"api_key"}]
:put ("TEST_OK:" . [:len [$secret "wifi_password"]] . ":" . [:len [$secret "api_key"]])
