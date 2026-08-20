#!/usr/bin/env bash
#
# Hardware and system detection.
#
# This is what makes one script work on the laptop with an RTX and on a machine
# with no discrete GPU at all: nothing about the hardware is written down, it is
# read from the running system every time.
#
# Everything here is read-only — no package is installed and no file is written.
# The results land in DOT_* variables that the steps consume:
#
#   DOT_DISTRO_ID     arch, cachyos, endeavouros, ...
#   DOT_CPU_VENDOR    intel | amd | other
#   DOT_UCODE         intel-ucode | amd-ucode | (empty)
#   DOT_GPUS          every GPU vendor found: "intel nvidia"
#   DOT_GPU_PRIMARY   the one the firmware booted with (boot_vga)
#   DOT_GPU_LABEL     human readable model, for the report
#   DOT_NVIDIA_DEVID  PCI device id of the NVIDIA card, e.g. 0x28a0
#   DOT_NVIDIA_BRANCH open | 580xx | 470xx | nouveau
#   DOT_VIRT          none, kvm, vmware, oracle, ...
#   DOT_FORM_FACTOR   laptop | desktop | vm
#   DOT_BATTERY       BAT0 or empty
#   DOT_BACKLIGHT     intel_backlight, amdgpu_bl0, nvidia_0 or empty
#   DOT_HWMON_PATH    absolute hwmon directory for the CPU temperature
#   DOT_HWMON_NAME    coretemp, k10temp, ...
#   DOT_BLUETOOTH     yes | no
#   DOT_WIFI          yes | no
#   DOT_KERNELS       installed kernel packages: "linux linux-lts"
#   DOT_BTRFS         yes | no
#   DOT_EFI           yes | no
#
# The PCI scan reads /sys/bus/pci directly instead of calling lspci: a freshly
# installed Arch may not have pciutils, and sysfs is always there.

# ── PCI vendor ids ─────────────────────────────────────────────────────────
readonly PCI_NVIDIA="0x10de"
readonly PCI_AMD="0x1002"
readonly PCI_AMD_ALT="0x1022" # AMD APUs occasionally register here
readonly PCI_INTEL="0x8086"

# ── Distribution ───────────────────────────────────────────────────────────

detect_distro() {
  DOT_DISTRO_ID="unknown"
  DOT_DISTRO_LIKE=""
  DOT_DISTRO_NAME="unknown"

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    DOT_DISTRO_ID="${ID:-unknown}"
    DOT_DISTRO_LIKE="${ID_LIKE:-}"
    DOT_DISTRO_NAME="${PRETTY_NAME:-$DOT_DISTRO_ID}"
  fi
}

# True on Arch and on anything that declares itself Arch-based (EndeavourOS,
# CachyOS, Garuda, Manjaro). pacman is what the installer actually needs.
distro_is_arch() {
  [[ -f /etc/arch-release ]] && return 0
  [[ "$DOT_DISTRO_ID" == "arch" ]] && return 0
  [[ " $DOT_DISTRO_LIKE " == *" arch "* ]] && return 0
  return 1
}

# ── CPU ────────────────────────────────────────────────────────────────────

detect_cpu() {
  local vendor
  vendor="$(awk -F': ' '/^vendor_id/{print $2; exit}' /proc/cpuinfo 2>/dev/null || true)"
  DOT_CPU_MODEL="$(awk -F': ' '/^model name/{print $2; exit}' /proc/cpuinfo 2>/dev/null || echo unknown)"

  case "$vendor" in
    GenuineIntel)
      DOT_CPU_VENDOR="intel"
      DOT_UCODE="intel-ucode"
      ;;
    AuthenticAMD)
      DOT_CPU_VENDOR="amd"
      DOT_UCODE="amd-ucode"
      ;;
    *)
      DOT_CPU_VENDOR="other"
      DOT_UCODE=""
      ;;
  esac
}

# ── GPU ────────────────────────────────────────────────────────────────────

# Which NVIDIA driver branch a card needs, from its PCI device id.
#
# The open kernel modules support Turing and newer, and are the only ones Arch
# still ships — the proprietary module was dropped from the repositories along
# with the generations it covered. Everything older lives in a frozen branch in
# the AUR. Device ids are allocated in generation order, which makes a numeric
# comparison a good enough classifier:
#
#   >= 0x1e00   Turing, Ampere, Ada, Blackwell   nvidia-open-dkms
#   >= 0x1340   Maxwell, Pascal, Volta           nvidia-580xx-dkms  (AUR, frozen)
#   >= 0x0f00   Kepler                           nvidia-470xx-dkms  (AUR, frozen)
#   <  0x0f00   Fermi and older                  nouveau (mesa)
#
# The frozen branches move on: when 580xx is retired the AUR will have a newer
# last-supported one. `paru -Ss "nvidia-.*-dkms"` lists what exists today, and
# --nvidia-driver= forces any of them.
nvidia_branch_for() {
  local devid="$1" n
  n=$((devid))

  if ((n >= 0x1e00)); then
    echo "open"
  elif ((n >= 0x1340)); then
    echo "580xx"
  elif ((n >= 0x0f00)); then
    echo "470xx"
  else
    echo "nouveau"
  fi
}

detect_gpu() {
  DOT_GPUS=""
  DOT_GPU_PRIMARY="none"
  DOT_GPU_LABEL=""
  DOT_NVIDIA_DEVID=""
  DOT_NVIDIA_BRANCH=""

  local dev class vendor device boot_vga name found=""

  for dev in /sys/bus/pci/devices/*; do
    [[ -r "$dev/class" ]] || continue
    class="$(< "$dev/class")"

    # 0x0300 VGA controller, 0x0302 3D controller (discrete GPU in a laptop
    # with no output of its own), 0x0380 "display controller".
    case "$class" in
      0x0300* | 0x0302* | 0x0380*) ;;
      *) continue ;;
    esac

    vendor="$(< "$dev/vendor")"
    device="$(< "$dev/device")"
    boot_vga=0
    [[ -r "$dev/boot_vga" ]] && boot_vga="$(< "$dev/boot_vga")"

    case "$vendor" in
      "$PCI_NVIDIA")
        name="nvidia"
        DOT_NVIDIA_DEVID="$device"
        ;;
      "$PCI_AMD" | "$PCI_AMD_ALT") name="amd" ;;
      "$PCI_INTEL") name="intel" ;;
      *) name="generic" ;; # virtio-gpu, VMware SVGA, QXL, Aspeed BMC
    esac

    [[ " $found " == *" $name "* ]] || found="$found $name"

    # The firmware marks exactly one card as the boot device. On a hybrid
    # laptop that is the integrated GPU, which is also the one the compositor
    # renders on by default — so it decides which VA-API driver we set.
    if [[ "$boot_vga" == "1" || "$DOT_GPU_PRIMARY" == "none" ]]; then
      [[ "$boot_vga" == "1" ]] && DOT_GPU_PRIMARY="$name"
      [[ "$DOT_GPU_PRIMARY" == "none" ]] && DOT_GPU_PRIMARY="$name"
    fi

    # A readable model name, only for the report. modalias is always present;
    # the pretty name needs `lspci`, which may not be installed.
    if command -v lspci > /dev/null 2>&1; then
      local slot
      slot="$(basename "$dev")"
      slot="${slot#0000:}"
      DOT_GPU_LABEL+="${DOT_GPU_LABEL:+, }$(lspci -s "$slot" 2> /dev/null | sed 's/^[^ ]* //; s/ (rev .*)//' | head -1)"
    else
      DOT_GPU_LABEL+="${DOT_GPU_LABEL:+, }$name ${device}"
    fi
  done

  DOT_GPUS="${found# }"

  # No PCI graphics at all: a virtual machine on virtio without a PCI class
  # match, or a headless box. Software rendering is the honest fallback.
  [[ -z "$DOT_GPUS" ]] && {
    DOT_GPUS="none"
    DOT_GPU_PRIMARY="none"
    DOT_GPU_LABEL="no PCI graphics device"
  }

  [[ -n "$DOT_NVIDIA_DEVID" ]] && DOT_NVIDIA_BRANCH="$(nvidia_branch_for "$DOT_NVIDIA_DEVID")"
  return 0
}

gpu_has() { [[ " $DOT_GPUS " == *" $1 "* ]]; }
gpu_is_hybrid() { [[ "$(wc -w <<< "$DOT_GPUS")" -gt 1 ]]; }

# ── Form factor ────────────────────────────────────────────────────────────

detect_form_factor() {
  # systemd-detect-virt prints "none" *and* exits 1 on bare metal, so the exit
  # code has to be swallowed or the whole run dies under `set -e`.
  DOT_VIRT="none"
  if command -v systemd-detect-virt > /dev/null 2>&1; then
    DOT_VIRT="$(systemd-detect-virt 2> /dev/null | head -1 || true)"
    DOT_VIRT="${DOT_VIRT:-none}"
  fi

  DOT_BATTERY=""
  local ps
  for ps in /sys/class/power_supply/*; do
    [[ -r "$ps/type" ]] || continue
    [[ "$(< "$ps/type")" == "Battery" ]] || continue
    DOT_BATTERY="$(basename "$ps")"
    break
  done

  # DMI chassis types: 8-11 and 14 are the portable ones, 30-32 tablets and
  # convertibles. A battery is the stronger signal, so it wins.
  local chassis="0"
  [[ -r /sys/class/dmi/id/chassis_type ]] && chassis="$(< /sys/class/dmi/id/chassis_type)"

  if [[ "$DOT_VIRT" != "none" ]]; then
    DOT_FORM_FACTOR="vm"
  elif [[ -n "$DOT_BATTERY" ]] || [[ "$chassis" =~ ^(8|9|10|11|14|30|31|32)$ ]]; then
    DOT_FORM_FACTOR="laptop"
  else
    DOT_FORM_FACTOR="desktop"
  fi
}

# ── Sensors ────────────────────────────────────────────────────────────────

detect_sensors() {
  DOT_HWMON_PATH=""
  DOT_HWMON_NAME=""
  DOT_BACKLIGHT=""

  # Waybar wants the directory that *contains* the hwmonN entry, not the entry
  # itself: hwmonN is numbered in driver load order and changes between reboots,
  # while the device path does not (see waybar/README.md).
  #
  # Preference order is by usefulness: the package sensor of the CPU first
  # (coretemp on Intel, k10temp on AMD), the SoC sensor on ARM, and the ACPI
  # thermal zone only as a last resort — it often reports the chipset, not the
  # CPU.
  local want h name
  for want in coretemp k10temp zenpower cpu_thermal acpitz; do
    for h in /sys/class/hwmon/hwmon*; do
      [[ -r "$h/name" ]] || continue
      name="$(< "$h/name")"
      [[ "$name" == "$want" ]] || continue
      [[ -r "$h/temp1_input" ]] || continue
      DOT_HWMON_PATH="$(dirname "$(readlink -f "$h")")"
      DOT_HWMON_NAME="$name"
      break 2
    done
  done

  # Screen brightness device. Desktops have none, and then Waybar picks
  # whatever it finds — which is nothing, so the module hides itself.
  local b
  for b in /sys/class/backlight/*; do
    [[ -e "$b" ]] || continue
    DOT_BACKLIGHT="$(basename "$b")"
    # An internal panel is the one worth controlling; prefer it over a
    # secondary device when both exist.
    [[ "$DOT_BACKLIGHT" == *_backlight || "$DOT_BACKLIGHT" == *_bl* ]] && break
  done
  return 0
}

# ── Radios, kernels, storage ───────────────────────────────────────────────

detect_peripherals() {
  DOT_BLUETOOTH="no"
  local d
  for d in /sys/class/bluetooth/*; do
    if [[ -e "$d" ]]; then
      DOT_BLUETOOTH="yes"
      break
    fi
  done

  DOT_WIFI="no"
  for d in /sys/class/net/*/wireless /sys/class/net/*/phy80211; do
    if [[ -e "$d" ]]; then
      DOT_WIFI="yes"
      break
    fi
  done
  return 0
}

detect_kernels() {
  # DKMS modules (the NVIDIA driver) need the headers of every installed
  # kernel, not just the running one — otherwise the next `linux-lts` boot has
  # no driver.
  DOT_KERNELS=""
  if command -v pacman > /dev/null 2>&1; then
    DOT_KERNELS="$(pacman -Qq 2> /dev/null | grep -E '^linux(-lts|-zen|-hardened|-rt|-rt-lts)?$' | tr '\n' ' ' || true)"
  fi
  DOT_KERNELS="${DOT_KERNELS:-linux }"
  DOT_KERNELS="${DOT_KERNELS% }"
}

detect_storage() {
  DOT_BTRFS="no"
  grep -qw btrfs /proc/mounts 2> /dev/null && DOT_BTRFS="yes"

  DOT_EFI="no"
  [[ -d /sys/firmware/efi ]] && DOT_EFI="yes"

  # Both tests above are allowed to fail; without this the function would
  # return their exit code and take `set -e` down with it.
  return 0
}

# ── Entry point ────────────────────────────────────────────────────────────

detect_all() {
  detect_distro
  detect_cpu
  detect_gpu
  detect_form_factor
  detect_sensors
  detect_peripherals
  detect_kernels
  detect_storage
  return 0
}

# Printed at the start of every run, and on its own with `--detect`. Reading
# this line before anything is installed is the cheapest way to catch a wrong
# guess.
detect_report() {
  local w="%s%-14s%s %s\n"
  printf "$w" "$C_DIM" "system" "$C_RESET" "$DOT_DISTRO_NAME${DOT_VIRT:+ · virt: $DOT_VIRT}"
  printf "$w" "$C_DIM" "form factor" "$C_RESET" "$DOT_FORM_FACTOR${DOT_BATTERY:+ · battery: $DOT_BATTERY}"
  printf "$w" "$C_DIM" "cpu" "$C_RESET" "$DOT_CPU_MODEL${DOT_UCODE:+ · $DOT_UCODE}"
  printf "$w" "$C_DIM" "gpu" "$C_RESET" "$DOT_GPU_LABEL"
  printf "$w" "$C_DIM" "gpu drivers" "$C_RESET" "$DOT_GPUS (primary: $DOT_GPU_PRIMARY)${DOT_NVIDIA_BRANCH:+ · nvidia branch: $DOT_NVIDIA_BRANCH}"
  printf "$w" "$C_DIM" "temperature" "$C_RESET" "${DOT_HWMON_NAME:-none found} ${DOT_HWMON_PATH:+($DOT_HWMON_PATH)}"
  printf "$w" "$C_DIM" "backlight" "$C_RESET" "${DOT_BACKLIGHT:-none (desktop)}"
  printf "$w" "$C_DIM" "radios" "$C_RESET" "bluetooth: $DOT_BLUETOOTH · wifi: $DOT_WIFI"
  printf "$w" "$C_DIM" "kernels" "$C_RESET" "$DOT_KERNELS"
  printf "$w" "$C_DIM" "storage" "$C_RESET" "btrfs: $DOT_BTRFS · efi: $DOT_EFI"
}
