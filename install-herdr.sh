#!/usr/bin/env bash
#
# Install (or upgrade to latest) herdr — https://herdr.dev.
#
# Uses herdr's own installer, which always downloads and overwrites the
# binary at $HOME/.local/bin/herdr (already on PATH via dotfiles.sh). The
# upstream script has no version check of its own, so this wrapper only adds
# one to skip the download when already on the latest release.

set -uo pipefail

LOCAL_BIN="$HOME/.local/bin"
MANIFEST_URL="https://herdr.dev/latest.json"

function has_command() {
  command -v "$1" >/dev/null 2>&1
}

function herdr_command() {
  if has_command herdr; then
    command -v herdr
  elif [[ -x "$LOCAL_BIN/herdr" ]]; then
    echo "$LOCAL_BIN/herdr"
  else
    return 1
  fi
}

function installed_herdr_version() {
  local bin
  bin=$(herdr_command) || return 1
  "$bin" --version 2>/dev/null | awk '{print $NF}'
}

function latest_herdr_version() {
  curl -fsSL "$MANIFEST_URL" |
    sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"v\{0,1\}\([^"]*\)".*/\1/p' |
    head -n 1
}

latest=$(latest_herdr_version) || latest=""
installed=$(installed_herdr_version) || installed=""
if [[ -n $installed && -n $latest && $installed == "$latest" ]]; then
  echo "herdr $installed is already the latest release"
  exit 0
fi

echo "Installing herdr"
if ! curl -fsSL https://herdr.dev/install.sh | sh; then
  echo "Failed to install herdr" >&2
  exit 1
fi

echo "herdr $(installed_herdr_version) is installed at $(herdr_command)"
