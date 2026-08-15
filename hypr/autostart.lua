-- Minimal user-space startup: no Omarchy provisioners, installers, or bundled
-- application launches.
hl.on("hyprland.start", function()
  hl.exec_cmd("systemctl --user import-environment $(env | cut -d'=' -f 1)")
  hl.exec_cmd("dbus-update-activation-environment --systemd --all")

  hl.exec_cmd("gnome-keyring-daemon --start --components=secrets,ssh")
  hl.exec_cmd("omarchy-launch-shell")
  hl.exec_cmd("hypridle")
  hl.exec_cmd("bluetooth-notify")
  hl.exec_cmd(o.launch("hyprsunset"))

  -- Personal hardware automations from the published dotfiles.
  hl.exec_cmd([=[bash -c 'until busctl --user status >/dev/null 2>&1; do sleep 0.2; done; exec epoll_manager']=])
  hl.exec_cmd("hardwareListener.sh")
end)
