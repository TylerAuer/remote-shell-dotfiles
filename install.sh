#!/usr/bin/env bash

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for file in "$DOTFILES_DIR"/src/*.sh; do
  # shellcheck source=/dev/null
  source "$file"
done
