#!/bin/bash

#TLP automatically does the battery profile swapping 
acpi_listen | while read -r event; do
  if [[ "$event" == "ac_adapter"*"00000001" ]]; then
    notify-send "⚡ Power Profile" "Charger plugged in, swapping to performance battery profile." -i battery-full-charging

  elif [[ "$event" == "ac_adapter"*"00000000" ]]; then
    notify-send "🔋 Balanced Profile" "Charger unplugged, swapping to balanced battery profile." -i battery-discharging
  fi
done
