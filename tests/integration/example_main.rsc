# Smoke entrypoint for CI (covers quoted keys + cleanup)
[:parse [[:parse [/file get "secrets.rsc" contents]]]]
[$secret_require {"wifi_password";"api_key"}]

:local wifiLen [:len [$secret "wifi_password"]]
:local apiLen [:len [$secret "api_key"]]
:local colonLen [:len [$secret "colon:key"]]
:local spaceLen [:len [$secret "space key"]]
:local leadingLen [:len [$secret "@leading"]]

:local certHas "F"
:if ([:find [$secret "multiline_cert"] "CERTIFICATE"] != nil) do={ :set certHas "T" }

:local hasMissing "T"
:if (![$secret_has "missing_key"]) do={ :set hasMissing "F" }

:local cleanupRes "INIT"
:local hasAfter "?"
:do {
    [$secret_cleanup]
    :do { $secret "cleanup_target"; :set cleanupRes "FAIL" } on-error={ :set cleanupRes "OK" }
    :if ([$secret_has "wifi_password"]) do={ :set hasAfter "T" } else={ :set hasAfter "F" }
} on-error={ :set cleanupRes "ERR"; :set hasAfter "E" }

:put ("TEST_OK:" . $wifiLen . ":" . $apiLen . ":" . $colonLen . ":" . $spaceLen . ":" . $leadingLen . ":" . $certHas . ":" . $hasMissing . ":" . $cleanupRes . ":" . $hasAfter)
