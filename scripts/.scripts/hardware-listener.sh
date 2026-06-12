#!/bin/bash

# Give Hyprland and background daemons 3 seconds to fully initialize
sleep 3

#--TABLET MODE OPTIMIZATIONS--#
(
# Using 'sudo -n' forces it to fail rather than hang if permissions are wrong
sudo -n libinput debug-events | while read -r line; do
    if echo "$line" | grep -q "switch tablet-mode state 1"; then
        notify-send "📱 Tablet Mode" "Disabling trackpad & optimizing for touch." -i tablet
        
        # Kill the status bar for full screen drawing
        killall waybar

        # Disables the physical trackpad
        hyprctl keyword "device[gxtp5100:00-27c6:01e0-touchpad]:enabled" false

        # Dynamically finds the stylus battery path
        stylus_path=$(upower -e | grep -m 1 'wacom_battery')
        if [ -n "$stylus_path" ]; then
            stylus_batt_percentage=$(upower -i "$stylus_path" | awk '/percentage:/ {print $2}')
            notify-send "🖊️ Stylus Battery" "Stylus is at $stylus_batt_percentage battery."
        fi
        
        # SAFETY VALVE: Cooldown prevents hardware signal spam
        sleep 2
    fi

    if echo "$line" | grep -q "switch tablet-mode state 0"; then
        notify-send "💻 Laptop Mode" "Re-enabling trackpad." -i computer
        
        # Bring the status bar back
        waybar > /dev/null 2>&1 &
        
        # Dynamically finds the stylus battery path
        stylus_path=$(upower -e | grep -m 1 'wacom_battery')
        if [ -n "$stylus_path" ]; then
            stylus_batt_percentage=$(upower -i "$stylus_path" | awk '/percentage:/ {print $2}')
            notify-send "🖊️ Stylus Battery" "Stylus is at $stylus_batt_percentage battery."
        fi
        
        # Re-enables the physical trackpad
        hyprctl keyword "device[gxtp5100:00-27c6:01e0-touchpad]:enabled" true
        
        # SAFETY VALVE: Cooldown prevents hardware signal spam
        sleep 2
    fi
done
) &


#--GENERAL HARDWARE EVENT AUTOMATIONS--#

acpi_listen | while read -r event; do
  case "$event" in 

  #--BATTERY & CHARGING NOTIFICATIONS--#
    *"ac_adapter"*"00000001"*)
        batt_percent=$(acpi -b | grep "Battery 0" | awk -F', ' '{print $2}')
        
        notify-send "⚡ Performance Profile" "Charger connected, swapping to the performance profile." -i battery-full-charging
        notify-send "Battery Overview" "Percentage: $batt_percent"
        
        # SAFETY VALVE
        sleep 2
        ;;

    *"ac_adapter"*"00000000"*)
        batt_percent=$(acpi -b | grep "Battery 0" | awk -F', ' '{print $2}')
        batt_time=$(acpi -b | grep "Battery 0" | awk -F', ' '{print $3}' | awk '{print $1}')
       
        notify-send "🔋 Balanced Profile" "Charger disconnected, swapping to the balanced profile." -i battery-discharging
        notify-send "Battery Overview" "Percentage: $batt_percent\nRemaining: $batt_time"
        
        # SAFETY VALVE
        sleep 2
        ;;

  #--AUDIO & MUSIC NOTIFICATIONS--#
    *"jack/headphone"*" plug"*)
        notify-send "🔊 IEMs Connected" "IEMs plugged in, launching Spotify." -i audio-volume-unmuted

        wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.3
        wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
       
        hyprctl dispatch exec spotify 
        
        # SAFETY VALVE
        sleep 2
        ;;

    *"jack/headphone"*"unplug"*)
        notify-send "🔈 IEMs Disconnected" "IEMs unplugged, muting media and closing Spotify." -i audio-volume-muted
       
        wpctl set-mute @DEFAULT_AUDIO_SINK@ 1
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.0
       
        pkill -f spotify
        
        # SAFETY VALVE
        sleep 2
        ;;

  esac 
done
