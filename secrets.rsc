# secrets.rsc - Secjector (RouterOS local-secrets injector, flat YAML)
# Version: 0.1.3
#
# What it does
# - Reads ./secrets.yaml (flat YAML: key: value, with support for multiline via `|`)
# - Generates global functions and variables (RouterOS 7.20.x requirement):
#     $secret "key"            -> returns value or errors (default) / warns (optional)
#     $secretHas "key"         -> boolean
#     $secretRequire {..}      -> validates required keys, error or warn per mode
# - NOTE: Uses :global for both $secretMap and accessor functions (RouterOS 7.20.x limitation).
#
# Usage:
#   Method 1 - Interactive terminal (recommended for manual setup):
#     [:parse [/file get "secrets.rsc" contents]]
#     [:parse $OUT]
#     /user add name="ops" group=full password=[$secret "wifi_password"]
#
#   Method 2 - From another script (use :parse, NOT /import):
#     :parse [/file get "my_setup.rsc" contents]
#     # Inside my_setup.rsc:
#     [:parse [/file get "secrets.rsc" contents]]
#     [:parse $OUT]
#     /user add name="ops" password=[$secret "wifi_password"]
#
#   IMPORTANT: Use :global for variables, :local assignment fails in RouterOS 7.20.x
#   Example: :global mypass [$secret "wifi_password"]
#
# Quoting & hyphens
# - Always pass a STRING key: [$secret "wifi_password"] or [$secret "wifi-password"]
# - Bare tokens without quotes only work if you already stored the key name in a variable.
#   Example (not recommended): :local k "wifi_password"; [$secret $k]
#
# Requirements:
#   - RouterOS v7.+ (associative arrays and do-{} function blocks)
#   - File "secrets.yaml" in the same directory
#
# Security notes:
#   - This injector does not persist secrets anywhere global.
#   - Consider removing secrets.yaml after use if it was fetched temporarily.
#
# Roadmap:
#   - v0.2: optional /tool fetch support for remote sources (see docs/roadmap.md)

# --- mode (caller can override before injection) ---
:local secretHandlingMode "error"
:do { :set secretHandlingMode $secretHandlingMode } on-error={}

# --- source file ---
:local F "secrets.yaml"
:if ([:len [/file find name=$F]] = 0) do={
    :error "secrets_injector: secrets.yaml not found in /file. Available files: [/file print]"
}

# --- helpers ---
:local helperTrim do={
    :local s $1
    :while (([:len $s]>0) && ([:pick $s 0 1]~" |\t")) do={ :set s [:pick $s 1 [:len $s]] }
    :while (([:len $s]>0) && ([:pick $s ([:len $s]-1) [:len $s]]~" |\t")) do={ :set s [:pick $s 0 ([:len $s]-1)] }
    :return $s
}
:local helperUnquote do={
    :local v $1
    :if (([:len $v]>=2) && ([:pick $v 0 1] = "\"" ) && ([:pick $v ([:len $v]-1) [:len $v]] = "\"" )) do={ :set v [:pick $v 1 ([:len $v]-1)] }
    :if (([:len $v]>=2) && ([:pick $v 0 1] = "'"  ) && ([:pick $v ([:len $v]-1) [:len $v]] = "'"  )) do={ :set v [:pick $v 1 ([:len $v]-1)] }
    :return $v
}
:local helperEsc do={
    # escape double quotes and newlines for code generation
    :local v $1; :local o ""
    :for i from=0 to=([:len $v]-1) do={
        :local c [:pick $v $i ($i+1)]
        :if ($c="\"") do={ :set o ($o."\\\"") } else={
        :if ($c="\n") do={ :set o ($o."\\n") } else={
        :if ($c="\r") do={ :set o ($o."\\r") } else={
            :set o ($o.$c)
        }}}
    }; :return $o
}
:local helperFindColon do={
    # find first colon that is NOT inside quotes
    :local s $1; :local L [:len $s]; :local inQuote 0; :local quoteChar ""
    :for i from=0 to=($L-1) do={
        :local c [:pick $s $i ($i+1)]
        :if ($inQuote=1) do={
            :if ($c=$quoteChar) do={ :set inQuote 0; :set quoteChar "" }
        } else={
            :if ($c="\"" || $c="'") do={ :set inQuote 1; :set quoteChar $c }
            :if ($c=":") do={ :return $i }
        }
    }
    :return nil
}

# --- parse secrets.yaml once, produce a snippet that populates a local map ---
:local txt [/file get $F contents]
:local N [:len $txt]; :local p 0
# code to populate the map inside each function
:global POP ""

:while ($p < $N) do={
    :local nl [:find $txt "\n" $p]; :if ($nl=nil) do={ :set nl $N }
    :local line [:pick $txt $p $nl]; :set p ($nl+1)
    :if (([:len $line]>0) && ([:pick $line ([:len $line]-1) [:len $line]]="\r")) do={ :set line [:pick $line 0 ([:len $line]-1)] }
    :set line [$helperTrim $line]
    :local skip 0
    :if (($line="") || ([:pick $line 0 1]="#")) do={ :set skip 1 }
    :if (([:len $line] >= 3) && ([:pick $line 0 3]="---")) do={
        :if (([:len $line]=3) || ([:pick $line 3 4]~" |\t#")) do={ :set skip 1 }
    }
    :if (([:len $line] >= 3) && ([:pick $line 0 3]="...")) do={
        :if (([:len $line]=3) || ([:pick $line 3 4]~" |\t#")) do={ :set skip 1 }
    }
    :if ($skip=1) do={} else={

    :local pos [$helperFindColon $line]
    :if ($pos=nil) do={ :error ("secrets_injector: malformed line (no colon separator): " . $line) }

    :local key [$helperUnquote [$helperTrim [:pick $line 0 $pos]]]
    :local tail [$helperTrim [:pick $line ($pos+1) [:len $line]]]

    # block scalar: key: |
    :if ($tail = "|") do={
        :local raw ""; :local indent -1
        :local blockDone 0
        :while (($p < $N) && ($blockDone = 0)) do={
            :local nl2 [:find $txt "\n" $p]; :if ($nl2=nil) do={ :set nl2 $N }
            :local l2 [:pick $txt $p $nl2]
            :if (([:len $l2]>0) && ([:pick $l2 ([:len $l2]-1) [:len $l2]]="\r")) do={ :set l2 [:pick $l2 0 ([:len $l2]-1)] }

            :if (!(([:len $l2]=0) || ([:pick $l2 0 1]~" |\t"))) do={ :set blockDone 1 } else={

            :if (($indent = -1) && ([:len $l2] > 0)) do={
                :local i 0
                :while (($i < [:len $l2]) && ([:pick $l2 $i ($i+1)]~" |\t")) do={ :set i ($i+1) }
                :set indent $i
            }
            :local cut 0; :if ($indent > 0) do={ :set cut $indent }
            :local payload [:pick $l2 $cut [:len $l2]]

            :set raw ($raw . $payload)
            :if ($nl2 != $N) do={ :set raw ($raw . [:pick $txt $nl2 ($nl2+1)]) }
            :set p ($nl2+1)
            }
        }
        :if ([:len $POP] > 0) do={ :set POP ($POP . "; ") }
        :set POP ($POP . "\"" . [$helperEsc $key] . "\"=\"" . [$helperEsc $raw] . "\"")
        :set indent -1
    } else={
        # simple scalar: key: value
        :local val [$helperUnquote $tail]
        :if ([:len $POP] > 0) do={ :set POP ($POP . "; ") }
        :set POP ($POP . "\"" . [$helperEsc $key] . "\"=\"" . [$helperEsc $val] . "\"")
    }
    }
}

# inline behavior mode
:local MODE $secretHandlingMode

# --- build helpers ---
:global OUT ""

# Initialize the global secretMap ONCE at the top level
:set OUT ($OUT . ":global secretMap {" . $POP . "};\n")

# secret(key) -> return value or error/warn
:set OUT ($OUT . ":global secret do={ :local MODE \"" . $MODE . "\"; :global secretMap; :local k " . "\$" . "1; ")
:set OUT ($OUT . ":if ([:len " . "\$" . "k]=0) do={ :error \"secret(): key required\" }; ")
:set OUT ($OUT . ":local v (" . "\$" . "secretMap->" . "\$" . "k); ")
:set OUT ($OUT . ":if ([:typeof " . "\$" . "v]=\"nothing\" || [:len " . "\$" . "v]=0) do={ ")
:set OUT ($OUT . ":if (" . "\$" . "MODE=\"warn\") do={ :log warning (\"secret missing/empty: \"." . "\$" . "k); :return \"\" } ")
:set OUT ($OUT . "else={ :error (\"secret missing/empty: \"." . "\$" . "k) } }; ")
:set OUT ($OUT . ":return " . "\$" . "v };\n")

# secretHas(key) -> boolean
:set OUT ($OUT . ":global secretHas do={ :global secretMap; :local k " . "\$" . "1; ")
:set OUT ($OUT . ":local v (" . "\$" . "secretMap->" . "\$" . "k); ")
:set OUT ($OUT . ":return ([:typeof " . "\$" . "v]!=\"nothing\" && [:len " . "\$" . "v]>0) };\n")

# secretRequire({k1;k2}) -> error/warn if any missing
:set OUT ($OUT . ":global secretRequire do={ :local MODE \"" . $MODE . "\"; :global secretMap; :local arr " . "\$" . "1; :global secretRequireMiss; :set secretRequireMiss \"\"; ")
:set OUT ($OUT . ":foreach k in=" . "\$" . "arr do={ :local v (" . "\$" . "secretMap->" . "\$" . "k); ")
:set OUT ($OUT . ":if (!([:typeof " . "\$" . "v]!=\"nothing\" && [:len " . "\$" . "v]>0)) do={ :set secretRequireMiss (" . "\$" . "secretRequireMiss." . "\$" . "k.\" \") } }; ")
:set OUT ($OUT . ":if (" . "\$" . "secretRequireMiss != \"\") do={ ")
:set OUT ($OUT . ":if (" . "\$" . "MODE=\"warn\") do={ :log warning (\"missing/empty secrets: \"." . "\$" . "secretRequireMiss) } ")
:set OUT ($OUT . "else={ :error (\"missing/empty secrets: \"." . "\$" . "secretRequireMiss) } } };\n")

# secretCleanup() -> disable accessors (NOTE: not supported in RouterOS 7.20.x due to :set/:local restrictions)
# :set OUT ($OUT . ":local secretCleanup do={ :set secret do={ :error \"secrets cleaned\" }; :set secretHas do={ :return false }; :set secretRequire do={ :error \"secrets cleaned\" }; :set secretCleanup do={ :error \"secrets already cleaned\" }; };\n")

# NOTE: Due to RouterOS limitations, result is in global $OUT
# Caller should use: [:parse $OUT] instead of [:parse [return value]]
