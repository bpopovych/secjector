# CI runner - executes example_main.rsc and outputs results
# This wrapper is needed because :parse suppresses output from the parsed script

# Run the main test
:parse [/file get "example_main.rsc" contents]

# Now output the results (globals are available after :parse)
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

:put ("TEST_OK:" . $wifiLen . ":" . $apiLen . ":" . $colonLen . ":" . $spaceLen . ":" . $leadingLen . ":" . $certHas . ":" . $hasMissing . ":" . $cleanupRes . ":" . $hasAfter)
