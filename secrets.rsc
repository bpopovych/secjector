# secrets.rsc - Secjector (RouterOS local-secrets injector, flat YAML)
# Version: 0.1.2
#
# What it does
# - Reads ./secrets.yaml (flat YAML: key: value, with support for multiline via `|`)
# - Generates local functions in the caller scope:
#     $secret "key"            -> returns value or errors (default) / warns (optional)
#     $secret_has "key"        -> boolean
#     $secret_require {..}     -> validates required keys, error or warn per mode
#     $secret_cleanup          -> disables accessors for the rest of the script
# - NOTE: No /system/script/environment usage, and no map is exposed in caller scope.
#         Secrets exist only inside the helpers when called.
#
# Usage (in your main .rsc):
#   # optional: :local __secret__handling__mode "warn"
#   [:parse [[:parse [/file get "secrets.rsc" contents]]]]
#   [$secret_require {"wifi_password";"api_key"}]
#   /user add name="ops" group=full password=[$secret "wifi_password"]
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
:local __secret__handling__mode "error"
:do { :set __secret__handling__mode $"__secret__handling__mode" } on-error={}

# --- source file ---
:local F "secrets.yaml"
:if ([:len [/file find name=$F]] = 0) do={ :error "secrets_injector: secrets.yaml not found" }

# --- helpers ---
:local __trim do={
    :local s $1
    :while (([:len $s]>0) && ([:pick $s 0 1]~" |\t")) do={ :set s [:pick $s 1 [:len $s]] }
    :while (([:len $s]>0) && ([:pick $s ([:len $s]-1) [:len $s]]~" |\t")) do={ :set s [:pick $s 0 ([:len $s]-1)] }
    :return $s
}
:local __unquote do={
    :local v $1
    :if (([:len $v]>=2) && ([:pick $v 0 1] = "\"" ) && ([:pick $v ([:len $v]-1) [:len $v]] = "\"" )) do={ :set v [:pick $v 1 ([:len $v]-1)] }
    :if (([:len $v]>=2) && ([:pick $v 0 1] = "'"  ) && ([:pick $v ([:len $v]-1) [:len $v]] = "'"  )) do={ :set v [:pick $v 1 ([:len $v]-1)] }
    :return $v
}
:local __esc do={
    # escape only double quotes; preserve newlines
    :local v $1; :local o ""
    :for i from=0 to=([:len $v]-1) do={
        :local c [:pick $v $i ($i+1)]
        :if ($c="\"") do={ :set o ($o."\\\"") } else={ :set o ($o.$c) }
    }; :return $o
}

# --- parse secrets.yaml once, produce a snippet that populates a local map ---
:local txt [/file get $F contents]
:local N [:len $txt]; :local p 0
:local POP ""    # code to populate the map inside each function

:while ($p < $N) do={
    :local nl [:find $txt "\n" $p]; :if ($nl=nil) do={ :set nl $N }
    :local line [:pick $txt $p $nl]; :set p ($nl+1)
    :if (([:len $line]>0) && ([:pick $line ([:len $line]-1) [:len $line]]="\r")) do={ :set line [:pick $line 0 ([:len $line]-1)] }
    :set line [$__trim $line]
    :if (($line="") || ([:pick $line 0 1]="#")) do={ :continue }

    :local pos [:find $line ":" 0]
    :if ($pos=nil) do={ :error ("secrets_injector: malformed line: " . $line) }

    :local key [$__trim [:pick $line 0 $pos]]
    :local tail [$__trim [:pick $line ($pos+1) [:len $line]]]

    # block scalar: key: |
    :if ($tail = "|") do={
        :local raw ""; :local indent -1
        :while ($p < $N) do={
            :local nl2 [:find $txt "\n" $p]; :if ($nl2=nil) do={ :set nl2 $N }
            :local l2 [:pick $txt $p $nl2]
            :if (([:len $l2]>0) && ([:pick $l2 ([:len $l2]-1) [:len $l2]]="\r")) do={ :set l2 [:pick $l2 0 ([:len $l2]-1)] }

            :if (!(([:len $l2]=0) || ([:pick $l2 0 1]~" |\t"))) do={ :break }

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
        :set POP ($POP . ":set (\$M->\"" . $key . "\") \"" . [$__esc $raw] . "\";\n")
        :set indent -1
        :continue
    }

    # simple scalar: key: value
    :local val [$__unquote $tail]
    :set POP ($POP . ":set (\$M->\"" . $key . "\") \"" . [$__esc $val] . "\";\n")
}

# inline behavior mode
:local MODE $__secret__handling__mode

# --- build helpers (each constructs its own local map M and never exposes it) ---
:local OUT ""

# secret(key) -> return value or error/warn
:set OUT ($OUT . ":local secret do={ \
    :local MODE \"" . $MODE . "\"; \
    :local M {}; " . $POP . " \
    :local k $1; \
    :if ([:len \$k]=0) do={ :error \"secret(): key required\" }; \
    :local v (\$M->\$k); \
    :if ([:typeof \$v]=\"nothing\" || [:len \$v]=0) do={ \
        :if (\$MODE=\"warn\") do={ :log warning (\"secret missing/empty: \".\$k); :return \"\" } else={ :error (\"secret missing/empty: \".\$k) } \
    }; \
    :return \$v \
};\n")

# secret_has(key) -> boolean
:set OUT ($OUT . ":local secret_has do={ \
    :local M {}; " . $POP . " \
    :local k $1; :local v (\$M->\$k); \
    :return ([:typeof \$v]!=\"nothing\" && [:len \$v]>0) \
};\n")

# secret_require({k1;k2}) -> error/warn if any missing
:set OUT ($OUT . ":local secret_require do={ \
    :local MODE \"" . $MODE . "\"; \
    :local M {}; " . $POP . " \
    :local arr $1; :local miss \"\"; \
    :foreach k in=\$arr do={ :local v (\$M->\$k); :if (!([:typeof \$v]!=\"nothing\" && [:len \$v]>0)) do={ :set miss (\$miss . \$k . \" \") } } \
    :if (\$miss != \"\") do={ :if (\$MODE=\"warn\") do={ :log warning (\"missing/empty secrets: \".\$miss) } else={ :error (\"missing/empty secrets: \".\$miss) } } \
};\n")

# secret_cleanup() -> disable accessors for the rest of this script run
:set OUT ($OUT . ":local secret_cleanup do={ \
    :local secret do={ :error \"secrets cleaned\" }; \
    :local secret_has do={ :return false }; \
    :local secret_require do={ :error \"secrets cleaned\" }; \
};\n")

:return $OUT
