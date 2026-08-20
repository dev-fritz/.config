#!/usr/bin/env bash
#
# Summary — what happened, and what is left for a human to do.
#
# Everything the installer decided not to do on its own (because it needs a
# password, a reboot, or a judgement call) is collected here, so the end of the
# run is a checklist and not a scrollback search.

step_summary() {
  section "Done"

  printf '%s%s  The desktop is installed.%s\n\n' "$C_BOLD" "$C_GREEN" "$C_RESET"

  info "what was configured for this machine"
  note "GPU:         ${DOT_GPU_LABEL} → ${DOT_GPUS}${DOT_NVIDIA_BRANCH:+ ($DOT_NVIDIA_BRANCH)}"
  note "temperature: ${DOT_HWMON_NAME:-none} → waybar/hardware.jsonc"
  note "backlight:   ${DOT_BACKLIGHT:-none} → waybar/hardware.jsonc"
  note "session:     hypr/conf/hardware.lua"

  printf '\n'
  info "next steps"

  # A reboot is not optional when the initramfs or the graphics driver changed:
  # the running kernel still has the old module loaded.
  if gpu_has nvidia; then
    note "1. reboot — the NVIDIA module only loads from the new initramfs"
  else
    note "1. reboot, or log out and pick Hyprland at the login screen"
  fi
  note "2. log in and press SUPER + SHIFT + T to pick a theme variant"
  note "3. SUPER + SHIFT + W picks a wallpaper (put images in ~/Images/Pictures/)"

  # GRUB is the one bootloader that does not pick up a newly installed
  # microcode package on its own.
  if [[ -d /boot/grub ]] && [[ -n "$DOT_UCODE" ]]; then
    printf '\n'
    warn "GRUB detected: run \`sudo grub-mkconfig -o /boot/grub/grub.cfg\` once so"
    note "the $DOT_UCODE image is actually loaded at boot"
  fi

  # Left behind by the relocation step.
  if [[ -n "${DOT_OLD_CLONE:-}" && -d "${DOT_OLD_CLONE}" ]]; then
    printf '\n'
    note "the original clone at $DOT_OLD_CLONE is no longer used and can be deleted"
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    printf '\n'
    warn "this was a dry run — nothing above was actually done"
    note "run without --dry-run to apply it"
  fi

  printf '\n'
  return 0
}
