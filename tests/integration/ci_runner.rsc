# CI runner - executes example_main.rsc and writes result to ci-result.txt
# /import suppresses :put output from SSH sessions, so we write to a file
# and read it with a second SSH call from the CI host.

# Run the main test
:parse [/file get "example_main.rsc" contents]

# Re-read globals set by example_main.rsc
:global wifiVal; :global apiVal; :global colonVal
:global spaceVal; :global leadingVal; :global certVal
:global secretHas

:local wifiLen [:len $wifiVal]
:local apiLen [:len $apiVal]
:local colonLen [:len $colonVal]
:local spaceLen [:len $spaceVal]
:local leadingLen [:len $leadingVal]

:local certHas "F"
:if ([:find $certVal "CERTIFICATE"] != nil) do={ :set certHas "T" }

:local hasMissing "T"
:if (![$secretHas "missing_key"]) do={ :set hasMissing "F" }

:local cleanupRes "SKIP"
:local hasAfter "N/A"

:local ciResult ("TEST_OK:" . $wifiLen . ":" . $apiLen . ":" . $colonLen . ":" . $spaceLen . ":" . $leadingLen . ":" . $certHas . ":" . $hasMissing . ":" . $cleanupRes . ":" . $hasAfter)
:do { /file remove [find name=ci-result.txt] } on-error={}
/file add name=ci-result.txt type=.txt contents=$ciResult
