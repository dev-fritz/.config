#!/usr/bin/env bash
#
# Shell and home directories.
#
# ~/.zshrc lives in this repository as zsh/.zshrc and is linked into place, for
# one reason: everything else here is under ~/.config and is versioned by
# construction, while the shell config sits directly in $HOME and would be lost
# on the next reinstall. A symlink keeps it versioned without moving what zsh
# looks for.

step_shell() {
  section "Shell and directories"
  shell_ohmyzsh
  shell_link_zshrc
  shell_default
  shell_directories
  return 0
}

# ── oh-my-zsh ──────────────────────────────────────────────────────────────
#
# Installed by cloning rather than through the upstream install.sh: that script
# writes its own ~/.zshrc from a template and would overwrite the one this
# repository provides.
shell_ohmyzsh() {
  local omz="$HOME/.oh-my-zsh"

  if [[ -d "$omz" ]]; then
    ok "oh-my-zsh already installed"
    return 0
  fi

  if ! ask "install oh-my-zsh? (zsh/.zshrc sources it)" y; then
    warn "skipped — zsh will complain about a missing \$ZSH on every start"
    return 0
  fi

  run git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$omz"
  return 0
}

# ── ~/.zshrc → ~/.config/zsh/.zshrc ────────────────────────────────────────
shell_link_zshrc() {
  local source="$DOT_ROOT/zsh/.zshrc"
  local target="$HOME/.zshrc"

  [[ -f "$source" ]] || {
    warn "$source not found — skipping the shell link"
    return 0
  }

  # Already pointing at the repository: nothing to do. -ef compares inodes, so
  # it is true for the symlink as well as for a hard copy of the same file.
  if [[ -L "$target" && "$target" -ef "$source" ]]; then
    ok "~/.zshrc already links to zsh/.zshrc"
    return 0
  fi

  if [[ -e "$target" && ! -L "$target" ]]; then
    local backup="$target.bak-$(date +%Y%m%d-%H%M%S)"
    info "an existing ~/.zshrc is in the way"
    note "moving it to ${backup/#$HOME/\~}"
    run mv "$target" "$backup"
  elif [[ -L "$target" ]]; then
    run rm "$target"
  fi

  run ln -s "$source" "$target"
  return 0
}

# ── Default shell ──────────────────────────────────────────────────────────
#
# chsh asks for the password itself and writes to /etc/passwd; it is not run
# through sudo. The change only takes effect on the next login.
shell_default() {
  local zsh_bin
  zsh_bin="$(command -v zsh || true)"

  [[ -n "$zsh_bin" ]] || {
    warn "zsh is not installed — skipping"
    return 0
  }

  if [[ "${SHELL:-}" == "$zsh_bin" ]]; then
    ok "zsh is already the login shell"
    return 0
  fi

  if ask "make zsh the login shell? (asks for your password)" y; then
    run chsh -s "$zsh_bin" || warn "chsh failed — run it by hand later"
  fi
  return 0
}

# ── Directories the scripts expect ─────────────────────────────────────────
#
# None of these are created on demand by the scripts that use them, so a fresh
# machine would hit "no such file or directory" on the first screenshot.
shell_directories() {
  local d
  for d in \
    "$HOME/Images/Screenshots" \
    "$HOME/Images/Pictures/_geral" \
    "$HOME/.local/bin" \
    "$HOME/.local/share/themes" \
    "$HOME/.local/state"; do
    [[ -d "$d" ]] && continue
    run mkdir -p "$d"
  done
  ok "screenshot, wallpaper and local directories in place"
  note "wallpapers go in ~/Images/Pictures/<theme>/ — download some with"
  note "  ~/.config/theme/baixar-wallpapers.py"
  return 0
}
