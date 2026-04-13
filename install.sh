#!/usr/bin/env bash
# Install this Claude Code config into ~/.claude and ~/.config/caveman.
# Backs up anything it would overwrite to <file>.bak-<timestamp>.
set -euo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
STAMP=$(date +%Y%m%d-%H%M%S)

install_file() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && ! cmp -s "$src" "$dst"; then
    mv "$dst" "$dst.bak-$STAMP"
    echo "backed up existing $dst -> $dst.bak-$STAMP"
  fi
  cp "$src" "$dst"
  echo "installed $dst"
}

install_file "$HERE/CLAUDE.md"           "$HOME/.claude/CLAUDE.md"
install_file "$HERE/settings.json"       "$HOME/.claude/settings.json"
install_file "$HERE/statusline.sh"       "$HOME/.claude/statusline.sh"
install_file "$HERE/caveman/config.json" "$HOME/.config/caveman/config.json"

chmod +x "$HOME/.claude/statusline.sh"

echo
echo "done. restart Claude Code to pick up the new statusline."
