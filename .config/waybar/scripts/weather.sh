#!/bin/bash

# Get weather data from wttr.in
# You can change the location by modifying the city name
LOCATION="Baghdad"  # Change this to your city

# Fetch weather data
weather_data=$(curl -s "wttr.in/${LOCATION}?format=%c+%t")

if [ -z "$weather_data" ]; then
    echo '{"text":"N/A","tooltip":"Weather data unavailable"}'
    exit
fi

# Get more detailed info for tooltip
weather_details=$(curl -s "wttr.in/${LOCATION}?format=%c+%t+%w+%h+%p")

# Format output
echo "{\"text\":\"${weather_data}\",\"tooltip\":\"${LOCATION}: ${weather_details}\"}"

