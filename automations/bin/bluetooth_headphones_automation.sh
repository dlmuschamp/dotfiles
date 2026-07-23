#!/bin/bash

# Arguments passed by epoll_manager.c
readonly DEV_PATH=$1
readonly DEV_ALIAS=$2
readonly CONNECT_STATUS=$3

# Constants
readonly SLEEP_TIME_SEC=0.5
readonly DEFAULT_VOL_PERCENT=0.3
readonly NOTIFY_TIME_MS=5000

# Text 
readonly EQ_FAIL_MSG="Failed to apply an easyeffects eq."
readonly DAEMON_NAME="Bluetooth Automation Daemon"

# Globals (to be overwritten)
DEV_AUDIO_SINK_ID=-1

# Fatal error if unable to set sink.
init_sink() {
  sleep 2 #let sink udpate
  DEV_AUDIO_SINK_ID=$(wpctl status | grep "$DEV_ALIAS" | grep "vol" | grep -oE '[0-9]+\.' | head -n 1 | tr -d '.')
  [[ -n "$DEV_AUDIO_SINK_ID" ]] && echo "Located the device audio sink ID Successfully: $DEV_AUDIO_SINK_ID" \
  || { echo "Failed to locate the device audio sink ID, exiting."; exit 1; }
}

# Non-fatal error if unable to set volume.
set_vol() {
  local TARGET_VOL=$DEFAULT_VOL_PERCENT
  local TARGET_SINK=$DEV_AUDIO_SINK_ID
  [[ -n "$1" ]] && TARGET_VOL=$1
  [[ "$TARGET_SINK" == "-1" ]] && TARGET_SINK="@DEFAULT_AUDIO_SINK@"
  wpctl set-volume "$TARGET_SINK" "$TARGET_VOL" -l 1.0 || echo "Failed to set the device volume."
}

init_eq() {
  case "$DEV_ALIAS" in
    "MOONDROP EDGE") 
      echo "MOONDROP EDGE recognized, applying EDGE eq."
      easyeffects -l "EDGE" || echo "$EQ_FAIL_MSG"
      ;;
    "onn Bone Conduction") 
      echo "onn Bone Conduction recognized, applying BONE eq."
      easyeffects -l "BONE" || echo "$EQ_FAIL_MSG"
      ;;
    *) 
      echo "Device not recognized, applying ARIA eq."
      easyeffects -l "ARIA" || echo "$EQ_FAIL_MSG"
      ;;
  esac
}

init_spotify() {
  # Spawns Spotify directly on workspace 5
  hyprctl dispatch exec "[workspace 5] spotify" || echo "Failed to launch spotify."
}

init_on() {
  notify-send -a "$DAEMON_NAME" -t "$NOTIFY_TIME_MS" -i bluetooth-active "Initializing device." "Initializing the connected bleutooth device and applying the desired configuration."
  echo "Initializing..."
  init_sink
  set_vol
  init_eq
  init_spotify
  echo "Successfully initialized."
  notify-send -a "$DAEMON_NAME" -t "$NOTIFY_TIME_MS" -i bluetooth-active "Successfully Initialized."
}

init_off() {
  notify-send -a "$DAEMON_NAME" -t "$NOTIFY_TIME_MS" -i bluetooth-disable "Shutting down device." "Shutting down the connected bleutooth device and reseting to default configuration."
  pkill -f spotify || true # || true prevents script from failing if spotify is already dead
  set_vol 0 "Reset"
  easyeffects -l "ARIA"
  echo "Shutdown sequence successful."
  notify-send -a "$DAEMON_NAME" -t "$NOTIFY_TIME_MS" -i bluetooth-disable "Shut down successful." 
}

# Main()
sleep "$SLEEP_TIME_SEC"

echo "DEBUG - PATH: '$DEV_PATH', STATUS: '$CONNECT_STATUS', ALIAS: '$DEV_ALIAS'"

# Check if ANY variables are empty
[[ -z "$DEV_PATH" || -z "$CONNECT_STATUS" || -z "$DEV_ALIAS" ]] \
&& { echo "Missing an argument, exiting..."; exit 1; }

# Execute based on status
[[ "$CONNECT_STATUS" == "1" ]] && init_on || init_off
