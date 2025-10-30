# Smoke entrypoint for CI (covers quoted keys)
# Updated for RouterOS 7.20.x compatibility
[:parse [/file get "secrets.rsc" contents]]
[:parse $OUT]
[$secretRequire {"wifi_password";"api_key"}]

# Use :global for storing values (RouterOS 7.20.x limitation)
:global wifiVal [$secret "wifi_password"]
:global apiVal [$secret "api_key"]
:global colonVal [$secret "colon:key"]
:global spaceVal [$secret "space key"]
:global leadingVal [$secret "@leading"]
:global certVal [$secret "multiline_cert"]

:local wifiLen [:len $wifiVal]
:local apiLen [:len $apiVal]
:local colonLen [:len $colonVal]
:local spaceLen [:len $spaceVal]
:local leadingLen [:len $leadingVal]

:local certHas "F"
:if ([:find $certVal "CERTIFICATE"] != nil) do={ :set certHas "T" }

:local hasMissing "T"
:if (![$secretHas "missing_key"]) do={ :set hasMissing "F" }

# secretCleanup not supported in RouterOS 7.20.x (cannot :set :local functions)
:local cleanupRes "SKIP"
:local hasAfter "N/A"

:put ("TEST_OK:" . $wifiLen . ":" . $apiLen . ":" . $colonLen . ":" . $spaceLen . ":" . $leadingLen . ":" . $certHas . ":" . $hasMissing . ":" . $cleanupRes . ":" . $hasAfter)
