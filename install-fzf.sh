#!/usr/bin/env bash
#
# Install (or upgrade to latest) fzf — https://github.com/junegunn/fzf.
#
# Install methods are tried in order: brew, prebuilt release tarball. Pass
# --cheap-only to skip the tarball path, which is what dotfiles.sh does at shell
# startup so a fresh shell never blocks on a download.
#
# The zsh key bindings (ctrl+r history search, ctrl+t file search, alt+c cd) are
# not set up here — dotfiles.sh evaluates them in every interactive shell.

set -uo pipefail

CHEAP_ONLY=false
if [[ ${1:-} == "--cheap-only" ]]; then
  CHEAP_ONLY=true
fi

PERSONAL_DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO="junegunn/fzf"
LOCAL_BIN="$HOME/.local/bin"

####################################################################################################
## Helpers #########################################################################################
####################################################################################################

function has_command() {
  command -v "$1" >/dev/null 2>&1
}

# Resolve a runnable fzf, including one we just dropped in ~/.local/bin but that
# is not on PATH yet in this process.
function fzf_command() {
  if has_command fzf; then
    command -v fzf
  elif [[ -x "$LOCAL_BIN/fzf" ]]; then
    echo "$LOCAL_BIN/fzf"
  else
    return 1
  fi
}

# `fzf --version` prints e.g. "0.74.1 (refs/tags/v0.74.1)".
function installed_fzf_version() {
  local bin
  bin=$(fzf_command) || return 1
  "$bin" --version 2>/dev/null | awk '{print $1}'
}

function latest_fzf_version() {
  curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" |
    sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v\{0,1\}\([^"]*\)".*/\1/p' |
    head -n 1
}

# Release artifacts are named fzf-<version>-<os>_<arch>.tar.gz.
function detect_platform() {
  local os arch
  case "$(uname -s)" in
    Darwin) os=darwin ;;
    Linux) os=linux ;;
    FreeBSD) os=freebsd ;;
    OpenBSD) os=openbsd ;;
    *) return 1 ;;
  esac
  case "$(uname -m)" in
    arm64 | aarch64) arch=arm64 ;;
    x86_64 | amd64) arch=amd64 ;;
    armv7l) arch=armv7 ;;
    ppc64le) arch=ppc64le ;;
    s390x) arch=s390x ;;
    riscv64) arch=riscv64 ;;
    *) return 1 ;;
  esac
  echo "${os}_${arch}"
}

####################################################################################################
## Install methods #################################################################################
####################################################################################################

function install_via_brew() {
  if brew list --formula fzf >/dev/null 2>&1; then
    echo "Upgrading fzf with brew"
    brew upgrade fzf 2>&1 | grep -v "already installed" || true
  else
    echo "Installing fzf with brew"
    brew install fzf || return 1
  fi
  fzf_command >/dev/null
}

function install_via_tarball() {
  local platform latest installed url tmp status=0
  platform=$(detect_platform) || {
    echo "No fzf release build for $(uname -s)/$(uname -m)" >&2
    return 1
  }

  latest=$(latest_fzf_version)
  if [[ -z $latest ]]; then
    echo "Could not resolve the latest fzf release from GitHub" >&2
    return 1
  fi

  installed=$(installed_fzf_version) || installed=""
  if [[ -n $installed && $installed == "$latest" ]]; then
    echo "fzf $installed is already the latest release"
    return 0
  fi

  url="https://github.com/$REPO/releases/download/v$latest/fzf-$latest-$platform.tar.gz"
  tmp=$(mktemp -d) || return 1
  echo "Downloading fzf $latest for $platform"

  if curl -fL --progress-bar "$url" -o "$tmp/fzf.tar.gz" &&
    tar -xzf "$tmp/fzf.tar.gz" -C "$tmp" &&
    [[ -x "$tmp/fzf" ]]; then
    mkdir -p "$LOCAL_BIN"
    mv -f "$tmp/fzf" "$LOCAL_BIN/fzf"
    echo "Installed fzf $latest to $LOCAL_BIN/fzf"
  else
    echo "Failed to install fzf from $url" >&2
    status=1
  fi

  rm -rf "$tmp"
  return $status
}

####################################################################################################
## Main ############################################################################################
####################################################################################################

installed=false
for method in brew tarball; do
  case $method in
    brew) has_command brew || continue ;;
    tarball) [[ $CHEAP_ONLY == true ]] && continue ;;
  esac

  if "install_via_$method"; then
    installed=true
    break
  fi
  echo "fzf install via $method failed — trying the next method" >&2
done

if [[ $installed == false ]]; then
  if [[ $CHEAP_ONLY == true ]]; then
    echo "fzf is not installed — run $PERSONAL_DOTFILES_DIR/install.sh to install it" >&2
  else
    echo "Failed to install fzf by any method" >&2
  fi
  exit 1
fi

echo "fzf $(installed_fzf_version) is installed at $(fzf_command)"
