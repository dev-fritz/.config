#!/usr/bin/env bash
#
# Services — what has to be running for the desktop to behave.
#
# Everything here is `systemctl enable`, never `enable --now`: starting sddm on
# a machine that is already inside a graphical session kills that session, and
# restarting NetworkManager mid-install can drop the connection the installer
# is downloading through. They all come up on the next boot.

# Enables a unit if it exists and is not enabled already. A missing unit is not
# an error: the package it belongs to may simply not have been selected.
service_enable() {
  local unit="$1"
  local why="${2:-}"

  if ! systemctl list-unit-files "$unit" --no-legend 2> /dev/null | grep -q .; then
    note "$unit is not installed, skipping"
    return 0
  fi

  local state
  state="$(systemctl is-enabled "$unit" 2> /dev/null || true)"
  if [[ "$state" == "enabled" || "$state" == "enabled-runtime" || "$state" == "static" ]]; then
    ok "$unit already enabled${why:+ — $why}"
    return 0
  fi

  sudo_run systemctl enable "$unit"
  [[ -n "$why" ]] && note "$why"
  return 0
}

step_services() {
  section "Services"

  # ── Network ──────────────────────────────────────────────────────────────
  service_enable NetworkManager.service "the Waybar network module and nmtui talk to it"

  # ── Login screen ─────────────────────────────────────────────────────────
  #
  # The Hyprland session file comes from the hyprland package, so sddm shows it
  # in the session list without any extra configuration.
  if ask "start the login screen (sddm) at boot?" y; then
    service_enable sddm.service "graphical login on the next boot"
  else
    note "no display manager: log in on a TTY and run \`Hyprland\`"
  fi

  # ── Bluetooth ────────────────────────────────────────────────────────────
  if [[ "$DOT_BLUETOOTH" == "yes" ]]; then
    service_enable bluetooth.service "a controller was detected"
  fi

  # ── Power ────────────────────────────────────────────────────────────────
  if [[ "$DOT_FORM_FACTOR" == "laptop" ]]; then
    service_enable power-profiles-daemon.service "power profiles on a laptop"
  fi

  # ── NVIDIA suspend ───────────────────────────────────────────────────────
  #
  # These three save and restore video memory around suspend. Without them a
  # Wayland session on NVIDIA often comes back with corrupted windows — the
  # matching kernel option is in /etc/modprobe.d/nvidia.conf (step 40).
  if gpu_has nvidia && [[ "$DOT_FORM_FACTOR" == "laptop" ]]; then
    service_enable nvidia-suspend.service "keeps the session across suspend"
    service_enable nvidia-hibernate.service
    service_enable nvidia-resume.service
  fi

  # ── Printing ─────────────────────────────────────────────────────────────
  #
  # The socket, not the service: cups then starts on the first print job
  # instead of sitting in memory all the time.
  if group_enabled extras; then
    service_enable cups.socket "printing starts on demand"
  fi

  # ── Docker ───────────────────────────────────────────────────────────────
  if group_enabled dev && command -v docker > /dev/null 2>&1; then
    if ask "start docker at boot?" y; then
      service_enable docker.service
    fi
    # Membership in the docker group is equivalent to root on this machine —
    # anyone in it can mount the host filesystem into a container. Worth a
    # deliberate yes.
    if ! id -nG "$USER" | grep -qw docker; then
      if ask "add $USER to the docker group? (lets you run docker without sudo — it is equivalent to root access)" n; then
        sudo_run usermod -aG docker "$USER"
        note "log out and back in for the group to take effect"
      fi
    fi
  fi

  # ── Firewall ─────────────────────────────────────────────────────────────
  #
  # ufw is installed but deliberately left off: enabling a firewall with its
  # default policy from a script is how remote access gets lost. The commands
  # are printed instead.
  if group_enabled extras && command -v ufw > /dev/null 2>&1; then
    # `ufw status` needs root. sudo -n so a dry run never stops on a password
    # prompt for a command that only prints advice.
    local ufw_state=""
    ufw_state="$(sudo -n ufw status 2> /dev/null | head -1 || true)"
    if [[ "$ufw_state" != *active* ]]; then
      note "ufw is installed but not enabled. To turn it on:"
      note "  sudo ufw default deny incoming && sudo ufw default allow outgoing"
      note "  sudo ufw enable && sudo systemctl enable ufw.service"
    fi
  fi

  # ── Compressed swap ──────────────────────────────────────────────────────
  #
  # zram-generator does nothing without a config file, which is why the package
  # alone is not enough.
  if group_enabled extras && pkg_installed zram-generator; then
    if [[ ! -f /etc/systemd/zram-generator.conf ]]; then
      if ask "configure zram (compressed swap in RAM, half of it, up to 8G)?" y; then
        printf '%s\n' \
          "# Written by ~/.config/install.sh" \
          "[zram0]" \
          "zram-size = min(ram / 2, 8192)" \
          "compression-algorithm = zstd" | sudo_write /etc/systemd/zram-generator.conf
        note "active on the next boot; check with \`zramctl\`"
      fi
    else
      ok "zram already configured"
    fi
  fi
  return 0
}
