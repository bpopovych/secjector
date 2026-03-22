# CI runner - directly tests the injection pattern.
# Mirrors real-world usage:
#   [:parse [/file get "secrets.rsc" contents]]
#   [:parse $OUT]
# and then calls the accessor functions.
#
# Writes result to ci-result.txt (read via a second SSH call) because
# /import suppresses :put output on SSH sessions.

[:parse [/file get "secrets.rsc" contents]]
[:parse $OUT]

:global secret
:global secretHas
:global secretRequire

[$secretRequire {"wifi_password";"api_key"}]

:local wifiLen   [:len [$secret "wifi_password"]]
:local apiLen    [:len [$secret "api_key"]]
:local colonLen  [:len [$secret "colon:key"]]
:local spaceLen  [:len [$secret "space key"]]
:local leadingLen [:len [$secret "@leading"]]

:local certVal [$secret "multiline_cert"]
:local certHas "F"
:if ([:find $certVal "CERTIFICATE"] != nil) do={ :set certHas "T" }

:local hasMissing "T"
:if (![$secretHas "missing_key"]) do={ :set hasMissing "F" }

:local cleanupRes "SKIP"
:local hasAfter   "N/A"

:local ciResult ("TEST_OK:" . $wifiLen . ":" . $apiLen . ":" \
    . $colonLen . ":" . $spaceLen . ":" . $leadingLen . ":" \
    . $certHas . ":" . $hasMissing . ":" . $cleanupRes . ":" . $hasAfter)
:do { /file remove [find name=ci-result.txt] } on-error={}
/file add name=ci-result.txt contents=$ciResult
