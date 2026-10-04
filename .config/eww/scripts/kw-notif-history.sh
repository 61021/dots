#!/usr/bin/env bash
# Last dunst notifications as compact JSON for the sidebar, newest first, max 2.
# Ones that look identical (app + summary) collapse into one entry with a count:
# [{"ids": "52 51", "app": "...", "summary": "...", "count": 2, "age": "5m"}]
# dunst timestamps are microseconds on CLOCK_BOOTTIME, the clock /proc/uptime reads.
set -eu
if ! command -v dunstctl >/dev/null 2>&1; then
  echo '[]'; exit 0
fi
now=$(awk '{printf "%d", $1 * 1000000}' /proc/uptime)
dunstctl history 2>/dev/null | jq -c --argjson now "$now" '
  def age: (($now - .) / 1000000 | floor) as $s
    | if $s < 60 then "now"
      elif $s < 3600 then "\($s / 60 | floor)m"
      elif $s < 86400 then "\($s / 3600 | floor)h"
      else "\($s / 86400 | floor)d" end;
  reduce .data[0][] as $n ({order: [], g: {}};
    ([$n.appname.data, $n.summary.data] | map(. // "") | join("\u001f")) as $k
    | if .g[$k] then
        .g[$k].ids += [$n.id.data] | .g[$k].count += 1
      else
        .order += [$k]
        | .g[$k] = {
            ids: [$n.id.data],
            app: ($n.appname.data // ""),
            summary: (($n.summary.data // "") | .[0:40]),
            count: 1,
            ts: $n.timestamp.data
          }
      end)
  | [.g[.order[:2][]] | {ids: (.ids | map(tostring) | join(" ")), app, summary, count, age: (.ts | age)}]
' 2>/dev/null || echo '[]'
