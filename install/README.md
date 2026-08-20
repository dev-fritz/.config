# install

The installer. Turns a freshly formatted Arch Linux into this desktop, adapting
to whatever hardware it finds.

```sh
git clone https://github.com/dev-fritz/.config.git ~/dotfiles
~/dotfiles/install.sh
```

The entry point is [`../install.sh`](../install.sh); everything under this
directory is what it reads and runs.

## What it does

| # | Step | What happens |
|---|---|---|
| 1 | `relocate` | moves the repository to `~/.config` — these dotfiles *are* `~/.config`, backing up anything already there |
| 2 | `preflight` | checks the distribution, sudo, network and disk, then `pacman -Syu` |
| 3 | `aur` | finds an AUR helper, or builds `paru-bin` (nothing else can be built without one) |
| 4 | `packages` | installs the lists in [`pkg/`](pkg/) plus what the hardware asks for |
| 5 | `drivers` | NVIDIA only: `/etc/modprobe.d/nvidia.conf`, mkinitcpio modules, new initramfs |
| 6 | `hardware` | generates `hypr/conf/hardware.lua` and `waybar/hardware.jsonc` |
| 7 | `shell` | oh-my-zsh, links `~/.zshrc` to [`../zsh/.zshrc`](../zsh/.zshrc), creates the directories the scripts use |
| 8 | `services` | enables NetworkManager, sddm, bluetooth, power profiles, the NVIDIA suspend units |
| 9 | `theme` | runs [`../theme/apply.py`](../theme/apply.py) — without it no config has colors |
| 10 | `summary` | what was configured, and what still needs a human |

Any step can be run on its own:

```sh
./install.sh --only=hardware     # after swapping a graphics card
./install.sh --only=theme        # regenerate the color files
./install.sh --skip=packages     # everything except the downloads
```

## How it adapts

Nothing about the machine is written down in this repository. Every value below
is read from `/sys` at install time ([`lib/detect.sh`](lib/detect.sh)) and
turned into packages, services and two generated files.

| Detected | Read from | What changes |
|---|---|---|
| GPU vendor | `/sys/bus/pci/devices/*/{class,vendor,device}` | which driver packages, and `LIBVA_DRIVER_NAME` in the session |
| NVIDIA generation | the card's PCI device id | `nvidia-open-dkms`, `nvidia-dkms`, a frozen AUR branch, or nouveau |
| hybrid graphics | more than one GPU on the bus | adds `nvidia-prime`, writes an `AQ_DRM_DEVICES` hint |
| CPU vendor | `/proc/cpuinfo` | `intel-ucode` or `amd-ucode` |
| laptop | battery in `/sys/class/power_supply`, DMI chassis type | power profiles, `sof-firmware`, NVIDIA suspend units, VRAM preservation |
| CPU sensor | `/sys/class/hwmon/*/name` | the Waybar temperature module's device path |
| backlight | `/sys/class/backlight/` | the Waybar brightness module's device |
| bluetooth | `/sys/class/bluetooth/` | the `bluez` stack and `bluetooth.service` |
| wifi | `/sys/class/net/*/wireless` | `wpa_supplicant` |
| kernels | installed `linux*` packages | headers for each, so DKMS builds for all of them |
| btrfs, EFI | `/proc/mounts`, `/sys/firmware/efi` | `btrfs-progs`, `efibootmgr` |
| virtual machine | `systemd-detect-virt` | software rendering, no hardware cursors |

See it without installing anything:

```sh
./install.sh --detect
```

```
system         Arch Linux · virt: none
form factor    laptop · battery: BAT0
cpu            12th Gen Intel(R) Core(TM) i9-12900HX · intel-ucode
gpu            NVIDIA AD107M [GeForce RTX 4060 Max-Q / Mobile]
gpu drivers    nvidia (primary: nvidia) · nvidia branch: open
temperature    coretemp (/sys/devices/platform/coretemp.0/hwmon)
backlight      nvidia_0
radios         bluetooth: yes · wifi: yes
kernels        linux
storage        btrfs: yes · efi: yes
```

### The NVIDIA branch

NVIDIA ships four drivers at once and each supports a different set of cards.
The PCI device id is allocated in generation order, which is enough to pick:

| Device id | Generation | Package |
|---|---|---|
| `>= 0x1e00` | Turing, Ampere, Ada, Blackwell | `nvidia-open-dkms` |
| `>= 0x1340` | Maxwell, Pascal, Volta | `nvidia-580xx-dkms` (AUR, frozen) |
| `>= 0x0f00` | Kepler | `nvidia-470xx-dkms` (AUR, frozen) |
| below that | Fermi and older | nouveau, from mesa |

DKMS variants on purpose: `nvidia-open` only matches the `linux` kernel and
breaks the day `linux-lts` is installed next to it. The proprietary module is
not an option any more — Arch ships only the open one.

The frozen branches move on as NVIDIA retires generations. `paru -Ss
"nvidia-.*-dkms"` lists what the AUR has today, and any of them can be forced:

```sh
./install.sh --nvidia-driver=470xx
./install.sh --gpu=amd            # or force the vendor outright
```

## Package groups

`core` is not optional — every package in it is referenced by a config file, a
keybinding or a script in this repository. The rest can be turned off with
`--groups=`.

| Group | File | What is in it |
|---|---|---|
| core | [`pkg/core.lst`](pkg/core.lst) | compositor, bar, terminal, editor, fonts, audio, theming engine |
| apps | [`pkg/apps.lst`](pkg/apps.lst) | firefox, discord, telegram, obsidian, media, desktop utilities |
| dev | [`pkg/dev.lst`](pkg/dev.lst) | go, rust, docker, node tooling, tmux, database TUI |
| extras | [`pkg/extras.lst`](pkg/extras.lst) | printing, firewall, zram, archive tools |

Hardware groups are added on their own when they apply: `laptop.lst`,
`bluetooth.lst`, `gpu-nvidia.lst`, `gpu-amd.lst`, `gpu-intel.lst`,
`gpu-none.lst`.

```sh
./install.sh --groups=core            # only what the dotfiles need
./install.sh --groups=core,dev        # plus the toolchains
```

The lists hold **names only**. Whether a package comes from the official
repositories or from the AUR is asked to pacman at install time, so a package
that moves between the two — `satty` and `yazi` both did — never turns into a
stale comment.

## What it touches outside `~/.config`

Everything else is confined to this repository. These are the exceptions, all
of them announced before they happen and skippable:

| Path | When | Backup |
|---|---|---|
| `/etc/modprobe.d/nvidia.conf` | NVIDIA card | yes, if a file was there |
| `/etc/mkinitcpio.conf` | NVIDIA card | yes, timestamped, plus `mkinitcpio -P` |
| `/etc/systemd/zram-generator.conf` | `extras`, and only if absent | not needed |
| `~/.zshrc` | always | moved to `~/.zshrc.bak-<date>`, replaced by a symlink |
| `~/.oh-my-zsh` | if missing | cloned |
| `~/Images/{Screenshots,Pictures}` | always | created only |
| systemd units | see the `services` step | `enable`, never `--now` |
| the `docker` group | only if you say yes | — |

`ufw` is installed but never enabled: turning on a firewall from a script is
how remote access gets lost. The commands are printed at the end instead.

## Options

| Flag | Effect |
|---|---|
| `-y`, `--yes` | take the default for every prompt — unattended install |
| `-n`, `--dry-run` | print every command and every generated file, change nothing |
| `--detect` | show the hardware report and exit |
| `--groups=LIST` | which optional groups to install |
| `--only=LIST` / `--skip=LIST` | run part of it |
| `--gpu=VENDOR` | force `nvidia`, `amd`, `intel` or `none` |
| `--nvidia-driver=BRANCH` | force `open`, `proprietary`, `570xx`, `470xx`, `nouveau` |
| `--theme=VARIANT` | apply a palette other than the default |
| `--wallpapers` | download a wallpaper set without asking |
| `--no-aur` | skip the AUR helper (and the packages that need it) |
| `--no-upgrade` | do not run `pacman -Syu` first |

A dry run prints the full contents of both generated files, which is the
easiest way to check what the installer thinks of a machine before letting it
near `/etc`.

## Layout

```
install.sh              entry point: options, order, error handling
install/
├── lib/
│   ├── ui.sh           colors, prompts, `run` and `write_file` (dry-run aware)
│   ├── detect.sh       everything read from /sys — no writes
│   └── pkg.sh          reading the lists, repo-or-AUR, batch install
├── pkg/*.lst           package lists, names only
└── steps/*.sh          one file per step, in order
```

Every command that changes something goes through `run`, `sudo_run` or
`write_file` in [`lib/ui.sh`](lib/ui.sh). That is what makes `--dry-run`
truthful rather than a guess, and it means `grep -rn sudo_run install/` lists
everything the installer does with elevated privileges.

## Adding to it

**A package**: one line in the right `.lst`, with a comment saying what breaks
without it. Nothing else — the repo/AUR split is automatic.

**A step**: a file in `steps/` named `NN-name.sh` defining `step_name`, plus
its name in `STEPS_ALL` and in the `case` block of `install.sh`. The files are
sourced in alphabetical order, so the number is the order.

**A detection**: a `DOT_*` variable in `lib/detect.sh` and a line in
`detect_report`, so `--detect` keeps showing everything that was decided.

## When something fails

The failing step is named in the error, and the run continues from there:

```sh
./install.sh --only=packages
```

Common cases:

| Symptom | Cause |
|---|---|
| `target not found` on a real package | the database was never synced — do not use `--no-upgrade` on a fresh install |
| signature errors | outdated keyring; `sudo pacman -Sy archlinux-keyring` |
| an AUR build fails | `base-devel` is missing, or the PKGBUILD needs a manual answer — build it by hand with `paru -S <name>` |
| black screen after reboot on NVIDIA | the `drivers` step was skipped; run `./install.sh --only=drivers` |
| Hyprland starts with no colors | the `theme` step was skipped; run `~/.config/theme/apply.py` |
