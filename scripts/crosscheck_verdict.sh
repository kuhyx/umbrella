#!/bin/bash

# ============================================================================
# Independent re-computation of the app's rain share, with curl + jq only.
#
# Shares no code with lib/: it re-derives the window mapping (a value stamped
# T is the total for the hour BEFORE T) and the member vote from the raw API,
# so agreement with the phone's notification is evidence, not a tautology.
#
# Usage: crosscheck_verdict.sh <lat> <lon> <leave HH:MM> <back HH:MM> [date]
#   date defaults to today (local). Prints wet/usable members and the share.
# ============================================================================

set -euo pipefail

readonly WET_MM=0.2

usage() {
    echo "Usage: $(basename "$0") <lat> <lon> <leave HH:MM> <back HH:MM> [YYYY-MM-DD]" >&2
    exit 2
}

main() {
    (( $# >= 4 )) || usage
    command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }
    local lat="$1" lon="$2" leave="$3" back="$4" day="${5:-$(date +%F)}"
    local start end
    start=$(date -d "$day $leave" +%s)
    end=$(date -d "$day $back" +%s)
    (( end > start )) || end=$(( end + 86400 ))

    curl -fsS "https://ensemble-api.open-meteo.com/v1/ensemble?latitude=$lat&longitude=$lon&hourly=rain,showers&models=icon_seamless&timeformat=unixtime&forecast_days=4" |
        jq -r --argjson s "$start" --argjson e "$end" --argjson wet "$WET_MM" '
            .hourly as $h
            | [range(0; $h.time | length) | select($h.time[.] > $s and $h.time[.] - 3600 < $e)] as $idx
            | [$h | keys[] | select(. == "rain" or startswith("rain_member"))] as $keys
            | [ $keys[] as $k
                | ($k | sub("^rain"; "showers")) as $sk
                | [ $idx[] as $i | if $h[$k][$i] == null then null
                                   else $h[$k][$i] + ($h[$sk][$i] // 0) end ] ]
            | map(select(all(. != null))) as $usable
            | ($usable | map(select(any(. >= $wet))) | length) as $n
            | "hours=\($idx | length) usable=\($usable | length) wet=\($n) share=\(if ($usable|length) == 0 then "n/a" else ($n * 100 / ($usable | length) | round | tostring) + "%" end)"'
}

main "$@"
