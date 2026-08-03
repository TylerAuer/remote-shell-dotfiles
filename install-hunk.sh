#!/usr/bin/env bash
#
# Install (or upgrade to latest) hunk — https://github.com/modem-dev/hunk — plus
# its user config and its Claude Code review skill.
#
# Install methods are tried in order: brew, npm, prebuilt release tarball. Pass
# --cheap-only to skip the tarball path, which is what dotfiles.sh does at shell
# startup so a fresh shell never blocks on a ~45MB download.

set -uo pipefail

CHEAP_ONLY=false
if [[ ${1:-} == "--cheap-only" ]]; then
  CHEAP_ONLY=true
fi

PERSONAL_DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO="modem-dev/hunk"
LOCAL_BIN="$HOME/.local/bin"
HUNK_LIBEXEC="$HOME/.local/share/hunk"
HUNK_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hunk"
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"

####################################################################################################
## Helpers #########################################################################################
####################################################################################################

function has_command() {
  command -v "$1" >/dev/null 2>&1
}

# Resolve a runnable hunk, including one we just dropped in ~/.local/bin but that
# is not on PATH yet in this process.
function hunk_command() {
  if has_command hunk; then
    command -v hunk
  elif [[ -x "$LOCAL_BIN/hunk" ]]; then
    echo "$LOCAL_BIN/hunk"
  else
    return 1
  fi
}

function installed_hunk_version() {
  local bin
  bin=$(hunk_command) || return 1
  "$bin" --version 2>/dev/null | tr -d '[:space:]'
}

function latest_hunk_version() {
  curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" |
    sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v\{0,1\}\([^"]*\)".*/\1/p' |
    head -n 1
}

# Release artifacts are named hunkdiff-<os>-<arch>.tar.gz.
function detect_platform() {
  local os arch
  case "$(uname -s)" in
    Darwin) os=darwin ;;
    Linux) os=linux ;;
    *) return 1 ;;
  esac
  case "$(uname -m)" in
    arm64 | aarch64) arch=arm64 ;;
    x86_64 | amd64) arch=x64 ;;
    *) return 1 ;;
  esac
  echo "$os-$arch"
}

####################################################################################################
## Install methods #################################################################################
####################################################################################################

function install_via_brew() {
  if brew list --formula hunk >/dev/null 2>&1; then
    echo "Upgrading hunk with brew"
    brew upgrade hunk 2>&1 | grep -v "already installed" || true
  else
    echo "Installing hunk with brew"
    brew install hunk || return 1
  fi
  hunk_command >/dev/null
}

function install_via_npm() {
  echo "Installing hunk with npm"
  npm install -g hunkdiff@latest || return 1

  # nodenv (and asdf) do not see a new global bin until their shims are rebuilt,
  # so an otherwise successful install would leave `hunk` unreachable.
  if has_command nodenv; then
    nodenv rehash || true
  fi
  if has_command asdf; then
    asdf reshim nodejs >/dev/null 2>&1 || true
  fi

  hunk_command >/dev/null
}

function install_via_tarball() {
  local platform latest installed url tmp status=0
  platform=$(detect_platform) || {
    echo "No hunk release build for $(uname -s)/$(uname -m)" >&2
    return 1
  }

  latest=$(latest_hunk_version)
  if [[ -z $latest ]]; then
    echo "Could not resolve the latest hunk release from GitHub" >&2
    return 1
  fi

  installed=$(installed_hunk_version) || installed=""
  if [[ -n $installed && $installed == "$latest" ]]; then
    echo "hunk $installed is already the latest release"
    return 0
  fi

  url="https://github.com/$REPO/releases/download/v$latest/hunkdiff-$platform.tar.gz"
  tmp=$(mktemp -d) || return 1
  echo "Downloading hunk $latest for $platform"

  if curl -fL --progress-bar "$url" -o "$tmp/hunk.tar.gz" &&
    tar -xzf "$tmp/hunk.tar.gz" -C "$tmp" &&
    [[ -x "$tmp/hunkdiff-$platform/hunk" ]]; then
    mkdir -p "$HUNK_LIBEXEC" "$LOCAL_BIN"
    rm -rf "$HUNK_LIBEXEC/hunkdiff-$platform"
    mv "$tmp/hunkdiff-$platform" "$HUNK_LIBEXEC/hunkdiff-$platform"
    ln -sfn "$HUNK_LIBEXEC/hunkdiff-$platform/hunk" "$LOCAL_BIN/hunk"
    echo "Installed hunk $latest to $LOCAL_BIN/hunk"
  else
    echo "Failed to install hunk from $url" >&2
    status=1
  fi

  rm -rf "$tmp"
  return $status
}

####################################################################################################
## Config and Claude skill #########################################################################
####################################################################################################

function install_hunk_config() {
  local target="$HUNK_CONFIG_DIR/config.toml"
  mkdir -p "$HUNK_CONFIG_DIR"
  if [[ -f $target ]]; then
    echo "hunk config already exists at $target — leaving it alone"
  else
    cp "$PERSONAL_DOTFILES_DIR/hunk/config.toml" "$target"
    echo "Installed hunk config to $target"
  fi
}

# hunk ships its own review skill for coding agents. Copy (rather than symlink)
# it into ~/.claude/skills so it cannot dangle when brew moves the Cellar path on
# upgrade; it is refreshed every time this script runs.
function install_hunk_claude_skill() {
  local bin skill_src skill_dir="$CLAUDE_SKILLS_DIR/hunk-review"
  bin=$(hunk_command) || return 1

  skill_src=$("$bin" skill path 2>/dev/null)
  if [[ -z $skill_src || ! -f $skill_src ]]; then
    echo "Could not locate hunk's review skill (\`hunk skill path\`) — skipping" >&2
    return 1
  fi

  mkdir -p "$skill_dir"
  cp "$skill_src" "$skill_dir/SKILL.md"
  echo "Installed skill: hunk-review -> $skill_dir/SKILL.md"
}

####################################################################################################
## Main ############################################################################################
####################################################################################################

installed=false
for method in brew npm tarball; do
  case $method in
    brew) has_command brew || continue ;;
    npm) has_command npm || continue ;;
    tarball) [[ $CHEAP_ONLY == true ]] && continue ;;
  esac

  if "install_via_$method"; then
    installed=true
    break
  fi
  echo "hunk install via $method failed — trying the next method" >&2
done

if [[ $installed == false ]]; then
  if [[ $CHEAP_ONLY == true ]]; then
    echo "hunk is not installed — run $PERSONAL_DOTFILES_DIR/install.sh to install it" >&2
  else
    echo "Failed to install hunk by any method" >&2
  fi
  exit 1
fi

echo "hunk $(installed_hunk_version) is installed at $(hunk_command)"
install_hunk_config
install_hunk_claude_skill
