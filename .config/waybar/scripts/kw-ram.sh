#!/bin/bash

mem_total=$(free -h | awk '/^Mem:/ {print $2}' | sed 's/Gi/GB/g')
mem_used=$(free -h | awk '/^Mem:/ {print $3}' | sed 's/Gi/GB/g')
mem_percent=$(free | awk '/^Mem:/ {printf("%.0f", $3/$2 * 100)}')

printf '{"text":"KW","tooltip":"RAM: %s / %s (%s%%)"}\n' "$mem_used" "$mem_total" "$mem_percent"
