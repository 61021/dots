#!/bin/bash

# Get CPU usage
cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')

# Get memory usage
mem_total=$(free -h | awk '/^Mem:/ {print $2}' | sed 's/Gi/GB/g')
mem_used=$(free -h | awk '/^Mem:/ {print $3}' | sed 's/Gi/GB/g')
mem_percent=$(free | awk '/^Mem:/ {printf("%.0f", $3/$2 * 100)}')

# Get disk usage
disk_usage=$(df -h / | awk 'NR==2 {print $5}')
disk_used=$(df -h / | awk 'NR==2 {print $3}' | sed 's/Gi/GB/g' | sed 's/G/GB/g')
disk_total=$(df -h / | awk 'NR==2 {print $2}' | sed 's/Gi/GB/g' | sed 's/G/GB/g')

# Format tooltip
tooltip="CPU: ${cpu_usage}%\n"
tooltip+="MEM: ${mem_used}/${mem_total} (${mem_percent}%)\n"
tooltip+="DISK: ${disk_used}/${disk_total} (${disk_usage})"

echo "{\"text\":\"Silence\",\"tooltip\":\"$tooltip\"}"

