# VHS tape — record demo.gif showing the statusline with caveman badge.
# Run with: vhs demo.tape  (https://github.com/charmbracelet/vhs)

Output demo.gif

Require bash
Require git
Require jq

Set Shell bash
Set FontSize 18
Set Width 1400
Set Height 360
Set TypingSpeed 25ms
Set PlaybackSpeed 1.0
Set Theme "Dracula"

# --- Setup: isolated fake HOME with a clean "main" repo for generic display ---
Hide
Type `export DEMO=$(mktemp -d) && mkdir -p "$DEMO/.claude" "$DEMO/project"`
Enter
Type `cp statusline.sh "$DEMO/statusline.sh"`
Enter
Type `git -C "$DEMO/project" -c init.defaultBranch=main init -q`
Enter
Type `git -C "$DEMO/project" -c user.email=demo@example.com -c user.name=demo commit --allow-empty -q -m init`
Enter
Type `export HOME="$DEMO" && cd "$HOME/project"`
Enter
Type `render() { echo "{\"model\":{\"display_name\":\"Opus 4.6\"},\"workspace\":{\"current_dir\":\"$HOME/project\"},\"cost\":{\"total_lines_added\":42,\"total_lines_removed\":7},\"context_window\":{\"used_percentage\":34},\"rate_limits\":{\"five_hour\":{\"used_percentage\":22,\"resets_at\":$(( $(date +%s) + 7200 ))},\"seven_day\":{\"used_percentage\":11,\"resets_at\":$(( $(date +%s) + 518400 ))}}}" | bash "$HOME/statusline.sh"; echo; }`
Enter
Type `clear`
Enter
Show

# --- Demo sequence ---
Type "# Claude Code statusline — caveman badge"
Enter
Sleep 1s

Type "# default: ultra"
Enter
Type `printf ultra > "$HOME/.claude/.caveman-active" && render`
Enter
Sleep 2500ms

Type "# switch to full"
Enter
Type `printf full > "$HOME/.claude/.caveman-active" && render`
Enter
Sleep 2500ms

Type "# switch to lite"
Enter
Type `printf lite > "$HOME/.claude/.caveman-active" && render`
Enter
Sleep 2500ms

Type "# caveman off (no badge)"
Enter
Type `rm -f "$HOME/.claude/.caveman-active" && render`
Enter
Sleep 3s
