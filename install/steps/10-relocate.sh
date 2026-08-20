#!/usr/bin/env bash
#
# Relocate — make sure the repository ends up at ~/.config.
#
# These dotfiles are not a collection of files that get symlinked somewhere:
# the repository *is* ~/.config. Every path in every config assumes it
# (`$HOME/.config/hypr/scripts/...`, `require("conf.programs")`, the @imports in
# the CSS files), so a clone sitting in ~/dotfiles would half-work at best.
#
# Cloning straight into ~/.config only works while that directory is empty,
# which it rarely is — a fresh Arch user already has ~/.config/pulse and
# friends after the first login. So the documented flow is:
#
#     git clone https://github.com/dev-fritz/.config.git ~/dotfiles
#     ~/dotfiles/install.sh
#
# and this step moves the repository into place, backing up whatever was
# already there under the same name.

step_relocate() {
  section "Repository location"

  if [[ "$DOT_ROOT" == "$CONFIG_HOME" ]]; then
    ok "repository is already at $CONFIG_HOME"
    return 0
  fi

  info "the repository has to live at $CONFIG_HOME — it is ~/.config itself"
  note "now at: $DOT_ROOT"

  git -C "$DOT_ROOT" rev-parse --git-dir > /dev/null 2>&1 ||
    die "$DOT_ROOT is not a git repository — clone it, do not copy the files"

  # A second repository already installed at ~/.config is the one case where
  # guessing would be destructive: it could be this same repo (already set up)
  # or somebody else's dotfiles. Stop and let a human decide.
  if [[ -d "$CONFIG_HOME/.git" ]]; then
    err "$CONFIG_HOME is already a git repository"
    note "if it is this same repo, run $CONFIG_HOME/install.sh instead"
    note "if it is a different one, move it out of the way first"
    die "refusing to overwrite an existing repository"
  fi

  # ── What would be overwritten ────────────────────────────────────────────
  local -a tracked=() conflicts=()
  mapfile -t tracked < <(git -C "$DOT_ROOT" ls-files)

  local f
  for f in "${tracked[@]}"; do
    [[ -e "$CONFIG_HOME/$f" ]] && conflicts+=("$f")
  done

  local backup="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"

  info "${#tracked[@]} files to install into $CONFIG_HOME"
  if ((${#conflicts[@]})); then
    warn "${#conflicts[@]} of them already exist and will be moved to ${backup/#$HOME/\~}"
    printf '     %s\n' "${conflicts[@]:0:10}"
    ((${#conflicts[@]} > 10)) && note "... and $((${#conflicts[@]} - 10)) more"
  fi

  ask "move the repository into $CONFIG_HOME?" y || die "cannot continue with the repository outside ~/.config"

  # ── Back up, then move ───────────────────────────────────────────────────
  if ((${#conflicts[@]})); then
    for f in "${conflicts[@]}"; do
      run mkdir -p "$backup/$(dirname "$f")"
      run mv "$CONFIG_HOME/$f" "$backup/$f"
    done
    ok "backup at $backup"
  fi

  run mkdir -p "$CONFIG_HOME"
  # `.` as the source copies the dotfiles too, .git included — which is the
  # point: the repository itself moves, so `git pull` keeps working from
  # ~/.config afterwards.
  run cp -a "$DOT_ROOT/." "$CONFIG_HOME/"

  if [[ "$DRY_RUN" == "1" ]]; then
    note "dry run: stopping here, the rest would run from $CONFIG_HOME"
    return 0
  fi

  git -C "$CONFIG_HOME" rev-parse --git-dir > /dev/null 2>&1 ||
    die "the copy did not produce a working repository at $CONFIG_HOME"

  ok "repository installed at $CONFIG_HOME"

  # ── Re-exec from the new location ────────────────────────────────────────
  #
  # From here on every path the installer touches has to be the new one, and
  # the simplest way to guarantee that is to start over from there. The marker
  # variable is what stops this from looping.
  info "restarting from $CONFIG_HOME/install.sh"
  export DOT_RELOCATED=1
  export DOT_OLD_CLONE="$DOT_ROOT"
  exec "$CONFIG_HOME/install.sh" "${DOT_ARGS[@]}"
}
