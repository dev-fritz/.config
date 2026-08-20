#!/usr/bin/env bash
#
# Drivers — the parts of graphics support that live outside ~/.config.
#
# Only NVIDIA needs anything here. AMD and Intel are handled entirely by the
# kernel plus the Mesa packages from the previous step: nothing to configure,
# nothing to regenerate.
#
# Everything this step writes is backed up first and listed before it happens,
# because a broken /etc/mkinitcpio.conf is a machine that does not boot.

NVIDIA_MODPROBE=/etc/modprobe.d/nvidia.conf
MKINITCPIO=/etc/mkinitcpio.conf

step_drivers() {
  section "Graphics drivers"

  local vendors="$DOT_GPUS"
  [[ "$GPU_OVERRIDE" != "auto" ]] && vendors="$GPU_OVERRIDE"

  if ! gpu_has nvidia || [[ "$GPU_OVERRIDE" != "auto" && "$GPU_OVERRIDE" != "nvidia" ]]; then
    ok "nothing to configure outside ~/.config for: ${vendors}"
    note "Mesa needs no kernel-side setup — amdgpu and i915/xe are built in"
    return 0
  fi

  local branch="${NVIDIA_BRANCH_OVERRIDE:-$DOT_NVIDIA_BRANCH}"
  if [[ "$branch" == "nouveau" || "$branch" == "none" ]]; then
    info "nouveau needs no extra configuration"
    return 0
  fi

  info "NVIDIA detected — the kernel side needs two files"
  note "1. $NVIDIA_MODPROBE       DRM modesetting, without which Wayland has no display"
  note "2. $MKINITCPIO   load the module early, before anything claims the console"

  if ! ask "write them? (a backup is kept of anything that already exists)" y; then
    warn "skipped — Hyprland may start on a black screen until this is done by hand"
    note "see https://wiki.hyprland.org/Nvidia/"
    return 0
  fi

  nvidia_write_modprobe
  nvidia_patch_mkinitcpio
  return 0
}

# ── /etc/modprobe.d/nvidia.conf ────────────────────────────────────────────
#
# modeset=1 is the one that matters: without DRM modesetting the NVIDIA driver
# exposes no KMS device and every Wayland compositor refuses to start. fbdev=1
# gives the kernel a framebuffer console on the same device, which is what
# stops the screen going black between the bootloader and the login manager.
#
# On a laptop, PreserveVideoMemoryAllocations makes the driver save VRAM to
# disk on suspend instead of throwing it away — the difference between waking up
# to your session and waking up to a corrupted one.
nvidia_write_modprobe() {
  local content
  content="# Written by ~/.config/install.sh — safe to edit, it is not regenerated.
#
# DRM modesetting. Wayland compositors need it; without it Hyprland starts on a
# black screen or refuses to open a display at all.
options nvidia_drm modeset=1 fbdev=1
"

  if [[ "$DOT_FORM_FACTOR" == "laptop" ]]; then
    content+="
# Keep video memory across suspend. Together with the nvidia-suspend,
# nvidia-hibernate and nvidia-resume services (enabled by this installer) this
# is what makes closing the lid safe on a Wayland session.
options nvidia NVreg_PreserveVideoMemoryAllocations=1
"
  fi

  if [[ -f "$NVIDIA_MODPROBE" ]] && ! grep -q "install.sh" "$NVIDIA_MODPROBE" 2> /dev/null; then
    local backup="$NVIDIA_MODPROBE.bak-$(date +%Y%m%d-%H%M%S)"
    sudo_run cp -a "$NVIDIA_MODPROBE" "$backup"
    note "existing file backed up to $backup"
  fi

  printf '%s' "$content" | sudo_write "$NVIDIA_MODPROBE"
}

# ── /etc/mkinitcpio.conf ───────────────────────────────────────────────────
#
# Two edits, both from the Arch wiki's NVIDIA page:
#
#   MODULES  gains the four nvidia modules, so they are in the initramfs and
#            load before anything else touches the GPU.
#   HOOKS    loses `kms`, whose job is to load *every* KMS driver early —
#            including nouveau, which then holds the card the real driver wants.
#
# The file is only rewritten when something actually changes, so running the
# installer twice does not pile up backups.
nvidia_patch_mkinitcpio() {
  [[ -r "$MKINITCPIO" ]] || {
    warn "$MKINITCPIO not found — skipping (is this an mkinitcpio system?)"
    return 0
  }

  local modules hooks changed=0
  modules="$(sed -nE 's/^MODULES=\((.*)\)$/\1/p' "$MKINITCPIO" | head -1)"
  hooks="$(sed -nE 's/^HOOKS=\((.*)\)$/\1/p' "$MKINITCPIO" | head -1)"

  local m
  for m in nvidia nvidia_modeset nvidia_uvm nvidia_drm; do
    if [[ " $modules " != *" $m "* ]]; then
      modules="${modules:+$modules }$m"
      changed=1
    fi
  done

  if [[ " $hooks " == *" kms "* ]]; then
    hooks="$(printf '%s' " $hooks " | sed -E 's/ kms / /g')"
    changed=1
  fi

  # Collapse the whitespace the edits above may have left behind.
  modules="$(printf '%s' "$modules" | xargs || true)"
  hooks="$(printf '%s' "$hooks" | xargs || true)"

  if ((changed == 0)); then
    ok "$MKINITCPIO already has the NVIDIA modules"
    return 0
  fi

  note "MODULES=($modules)"
  note "HOOKS=($hooks)"

  local backup="$MKINITCPIO.bak-$(date +%Y%m%d-%H%M%S)"
  sudo_run cp -a "$MKINITCPIO" "$backup"
  sudo_run sed -i -E "s|^MODULES=\(.*\)$|MODULES=($modules)|; s|^HOOKS=\(.*\)$|HOOKS=($hooks)|" "$MKINITCPIO"
  ok "patched $MKINITCPIO (backup: $backup)"

  # -P rebuilds every preset, which is what covers linux and linux-lts at once.
  info "rebuilding the initramfs — this takes a minute"
  sudo_run mkinitcpio -P
  return 0
}
