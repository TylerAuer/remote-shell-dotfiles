#!/usr/bin/env bash

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
STATUSLINE_SCRIPT="$CLAUDE_DIR/claude_statusline.sh"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

####################################################################################################
## Source dotfiles in shell RC file ################################################################
####################################################################################################

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

####################################################################################################
## Install Claude statusline #######################################################################
####################################################################################################

mkdir -p "$CLAUDE_DIR"
cp "$DOTFILES_DIR/claude_statusline.sh" "$STATUSLINE_SCRIPT"
echo "Installed claude_statusline.sh to $CLAUDE_DIR/"

####################################################################################################
## Install Claude skills ###########################################################################
####################################################################################################

SKILLS_DIR="$CLAUDE_DIR/skills"
mkdir -p "$SKILLS_DIR"
for skill in "$DOTFILES_DIR/claude-skills"/*/; do
  [[ -d "$skill" || -L "${skill%/}" ]] || continue
  skill_name=$(basename "$skill")
  cp -RL "$skill" "$SKILLS_DIR/"
  echo "Installed skill: $skill_name -> $SKILLS_DIR/$skill_name"
done

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found — skipping settings.json update; install jq and re-run." >&2
  exit 1
fi

[[ -f "$SETTINGS_FILE" ]] || echo '{}' > "$SETTINGS_FILE"
TMP_SETTINGS=$(mktemp)
trap 'rm -f "$TMP_SETTINGS"' EXIT
if jq --arg cmd "$STATUSLINE_SCRIPT" \
      '.statusLine = {type: "command", command: $cmd}' \
      "$SETTINGS_FILE" > "$TMP_SETTINGS" && mv "$TMP_SETTINGS" "$SETTINGS_FILE"; then
  echo "Updated $SETTINGS_FILE statusLine to $STATUSLINE_SCRIPT"
else
  echo "Failed to update $SETTINGS_FILE" >&2
  exit 1
fi

