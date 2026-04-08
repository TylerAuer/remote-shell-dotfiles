#!/usr/bin/env bash

####################################################################################################
## Source dotfiles in shell RC file ################################################################
####################################################################################################

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
SOURCE_LINE="source \"$DOTFILES_DIR/dotfiles.sh\""

# Add source line to .zshrc if not already present
if ! grep -qF "$SOURCE_LINE" "$HOME/.zshrc" 2>/dev/null; then
  echo "" >> "$HOME/.zshrc"
  echo "# Tyler's dotfiles" >> "$HOME/.zshrc"
  echo "$SOURCE_LINE" >> "$HOME/.zshrc"
  echo "Added dotfiles source line to ~/.zshrc"
else
  echo "Source line already present in ~/.zshrc"
fi

