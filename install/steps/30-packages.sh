#!/usr/bin/env bash
#
# Packages — turns the lists in install/pkg/ plus the detected hardware into
# one set of names and installs it.
#
# The lists hold what is always true ("this desktop needs waybar"); this file
# holds what depends on the machine ("this one has an NVIDIA card, and that card
# is an Ada, so it takes the open modules").

# Which kernel module package an NVIDIA card needs.
#
# DKMS variants are used on purpose: `nvidia-open` only matches the `linux`
# kernel and breaks the moment linux-lts is installed alongside it, while the
# DKMS build follows every kernel that has headers.
nvidia_packages() {
  local branch="$1"

  case "$branch" in
    open)
      echo "nvidia-open-dkms"
      ;;
    580xx)
      # Maxwell, Pascal and Volta were dropped by the current branch; the last
      # one that supports them is frozen in the AUR and brings its own
      # userspace, which conflicts with nvidia-utils — hence the substitution
      # in step_packages_nvidia.
      echo "nvidia-580xx-dkms nvidia-580xx-utils"
      ;;
    470xx)
      echo "nvidia-470xx-dkms nvidia-470xx-utils"
      ;;
    *)
      echo ""
      ;;
  esac
}

step_packages() {
  section "Packages"

  # With --only=packages the AUR step never ran, so the helper has not been
  # looked for yet — and without it every AUR package would be reported as
  # "not found anywhere" instead of being installed.
  if [[ -z "$AUR_HELPER" && "$USE_AUR" == "1" ]]; then
    aur_helper_find || warn "no AUR helper found — AUR packages will be skipped"
  fi

  local -a pkgs=()
  local -a list

  # ── Core, always ─────────────────────────────────────────────────────────
  mapfile -t list < <(pkg_list_read "$DOT_INSTALL/pkg/core.lst")
  pkgs+=("${list[@]}")

  # ── Optional groups ──────────────────────────────────────────────────────
  local group
  for group in apps dev extras; do
    if group_enabled "$group"; then
      mapfile -t list < <(pkg_list_read "$DOT_INSTALL/pkg/$group.lst")
      pkgs+=("${list[@]}")
      note "group $group: ${#list[@]} packages"
    else
      note "group $group: skipped"
    fi
  done

  # ── CPU microcode ────────────────────────────────────────────────────────
  #
  # The bootloader picks it up on its own with a systemd-boot or UKI setup; on
  # GRUB, `grub-mkconfig` has to run once afterwards (the summary says so).
  [[ -n "$DOT_UCODE" ]] && pkgs+=("$DOT_UCODE")

  # ── Hardware-conditional extras ──────────────────────────────────────────
  if group_enabled extras; then
    [[ "$DOT_BTRFS" == "yes" ]] && pkgs+=(btrfs-progs) && note "btrfs filesystem detected: adding btrfs-progs"
    [[ "$DOT_EFI" == "yes" ]] && pkgs+=(efibootmgr) && note "EFI boot detected: adding efibootmgr"
  fi

  if [[ "$DOT_FORM_FACTOR" == "laptop" ]]; then
    mapfile -t list < <(pkg_list_read "$DOT_INSTALL/pkg/laptop.lst")
    pkgs+=("${list[@]}")
    note "laptop: adding battery and power packages"
  fi

  if [[ "$DOT_BLUETOOTH" == "yes" ]]; then
    mapfile -t list < <(pkg_list_read "$DOT_INSTALL/pkg/bluetooth.lst")
    pkgs+=("${list[@]}")
    note "bluetooth controller detected: adding the stack"
  fi

  [[ "$DOT_WIFI" == "yes" ]] && pkgs+=(wpa_supplicant)

  # ── Graphics ─────────────────────────────────────────────────────────────
  local -a gpu_targets=()
  if [[ "$GPU_OVERRIDE" != "auto" ]]; then
    gpu_targets=("$GPU_OVERRIDE")
    info "GPU forced to $GPU_OVERRIDE (--gpu)"
  else
    read -ra gpu_targets <<< "$DOT_GPUS"
  fi

  local gpu
  for gpu in "${gpu_targets[@]}"; do
    case "$gpu" in
      nvidia)
        step_packages_nvidia pkgs
        ;;
      amd | intel)
        mapfile -t list < <(pkg_list_read "$DOT_INSTALL/pkg/gpu-$gpu.lst")
        pkgs+=("${list[@]}")
        note "$gpu graphics: Mesa userspace"
        ;;
      *)
        mapfile -t list < <(pkg_list_read "$DOT_INSTALL/pkg/gpu-none.lst")
        pkgs+=("${list[@]}")
        note "no supported GPU: software rendering"
        ;;
    esac
  done

  # A hybrid laptop can send a single program to the discrete card with
  # `prime-run`, which is the whole point of keeping both drivers installed.
  if gpu_is_hybrid && gpu_has nvidia; then
    pkgs+=(nvidia-prime)
    note "hybrid graphics: adding nvidia-prime (prime-run)"
  fi

  # ── Install ──────────────────────────────────────────────────────────────
  #
  # Duplicates are expected (mesa shows up in two GPU lists on a hybrid
  # machine) and pacman would refuse the transaction, so they are collapsed
  # here.
  local -a unique=()
  mapfile -t unique < <(printf '%s\n' "${pkgs[@]}" | awk 'NF && !seen[$0]++')

  info "${#unique[@]} packages selected"
  pkg_install "packages" "${unique[@]}"
  return 0
}

# The NVIDIA half, kept separate because it is the only one that has to pick
# between four driver branches and swap out the userspace packages to match.
#
# Takes the name of the array to append to (bash has no return value for
# arrays, and a subshell would lose the changes).
step_packages_nvidia() {
  local -n target="$1"
  local -a list
  local branch="${NVIDIA_BRANCH_OVERRIDE:-$DOT_NVIDIA_BRANCH}"
  branch="${branch:-open}"

  # Arch dropped the proprietary kernel module: `nvidia-dkms` no longer exists,
  # only the open one. Saying so beats installing something the flag did not
  # ask for without a word.
  if [[ "$branch" == "proprietary" ]]; then
    warn "Arch no longer ships the proprietary kernel module — using nvidia-open-dkms"
    branch="open"
  fi

  if [[ "$branch" == "nouveau" || "$branch" == "none" ]]; then
    warn "this NVIDIA card is too old for the current drivers — using nouveau"
    note "device id ${DOT_NVIDIA_DEVID:-unknown}; nouveau is part of mesa"
    mapfile -t list < <(pkg_list_read "$DOT_INSTALL/pkg/gpu-none.lst")
    target+=("${list[@]}")
    return 0
  fi

  local -a modules=()
  read -ra modules < <(nvidia_packages "$branch")
  target+=("${modules[@]}")

  mapfile -t list < <(pkg_list_read "$DOT_INSTALL/pkg/gpu-nvidia.lst")

  # The frozen AUR branches ship their own nvidia-utils and conflict with the
  # current one, so the shared list is filtered down to what does not clash.
  if [[ "$branch" == "580xx" || "$branch" == "470xx" ]]; then
    local -a filtered=()
    local p
    for p in "${list[@]}"; do
      case "$p" in
        nvidia-utils | nvidia-settings | libva-nvidia-driver) continue ;;
        *) filtered+=("$p") ;;
      esac
    done
    list=("${filtered[@]}")
    warn "using the frozen $branch branch from the AUR — expect a long build"
  fi

  target+=("${list[@]}")

  # DKMS compiles the module against every installed kernel, and needs the
  # headers of each one. Miss this and the next boot has no driver.
  local k
  for k in $DOT_KERNELS; do
    target+=("$k-headers")
  done
  target+=(dkms)

  note "NVIDIA branch $branch (device ${DOT_NVIDIA_DEVID:-unknown}), headers for: $DOT_KERNELS"
  return 0
}
