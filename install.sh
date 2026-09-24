#!/usr/bin/env bash
#
# install.sh — install the Helix Loop skill pack for Claude Code and/or Codex.
#
# Idempotent: already-installed skills are detected and skipped.
#
# Usage:
#   ./install.sh [--project DIR] [--agent claude|codex|both|auto] [--scope project|user]
#
#   --project DIR   Target project directory (default: current directory).
#                   Skills go to <project>/.claude/skills (Claude Code).
#   --agent         Which agent to set up (default: auto-detect).
#   --scope         "project" installs into the target project (default);
#                   "user" installs into ~/.claude/skills (Claude Code only,
#                   usable in every project).
#
# Examples:
#   ./install.sh                                   # auto-detect, current project
#   ./install.sh --project ~/my-app --agent both   # Claude Code + Codex
#   ./install.sh --scope user                      # every Claude Code project
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(pwd)"
AGENT="auto"
SCOPE="project"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT_DIR="$(cd "$2" && pwd)"; shift 2 ;;
    --agent)   AGENT="$2"; shift 2 ;;
    --scope)   SCOPE="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,/^#$/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "Unknown option: $1 (try --help)" >&2; exit 1 ;;
  esac
done

have_claude=false
have_codex=false
case "$AGENT" in
  claude) have_claude=true ;;
  codex)  have_codex=true ;;
  both)   have_claude=true; have_codex=true ;;
  auto)
    if [[ -d "$HOME/.claude" ]] || command -v claude >/dev/null 2>&1; then have_claude=true; fi
    if [[ -d "$HOME/.codex"  ]] || command -v codex  >/dev/null 2>&1; then have_codex=true;  fi
    if ! $have_claude && ! $have_codex; then
      echo "No Claude Code or Codex detected; defaulting to Claude Code layout." >&2
      have_claude=true
    fi
    ;;
  *) echo "Unknown --agent: $AGENT (claude|codex|both|auto)" >&2; exit 1 ;;
esac

INSTALLED=0
SKIPPED=0

install_skill_dir() {
  # install_skill_dir <skill-src-dir> <dest-parent-dir>
  local src="$1" dest_parent="$2"
  local name; name="$(basename "$src")"
  local dest="$dest_parent/$name"
  if [[ -f "$dest/SKILL.md" ]] && cmp -s "$src/SKILL.md" "$dest/SKILL.md"; then
    echo "  [skip] $name — already installed"
    SKIPPED=$((SKIPPED+1))
  else
    mkdir -p "$dest"
    cp -r "$src"/. "$dest"/
    echo "  [ok]   $name"
    INSTALLED=$((INSTALLED+1))
  fi
}

install_skills_to() {
  local dest_parent="$1"
  mkdir -p "$dest_parent"
  for skill in "$REPO_DIR"/skills/*/; do
    [[ -d "$skill" ]] || continue
    install_skill_dir "$skill" "$dest_parent"
  done
}

ROUTING_START="HELIX-LOOP:ROUTING:START"

ensure_routing() {
  # ensure_routing <file> — append routing snippet once
  local file="$1"
  if [[ -f "$file" ]] && grep -q "$ROUTING_START" "$file"; then
    echo "  [skip] routing block already present in $file"
    SKIPPED=$((SKIPPED+1))
    return
  fi
  {
    echo ""
    cat "$REPO_DIR/templates/agent-routing.md"
  } >> "$file"
  echo "  [ok]   routing block appended to $file"
  INSTALLED=$((INSTALLED+1))
}

# ---------------- Claude Code ----------------
if $have_claude; then
  echo "== Claude Code =="
  if [[ "$SCOPE" == "user" ]]; then
    DEST="$HOME/.claude/skills"
    echo "-- user-level skills: $DEST"
    install_skills_to "$DEST"
  else
    DEST="$PROJECT_DIR/.claude/skills"
    echo "-- project skills: $DEST"
    install_skills_to "$DEST"

    # Stop hook: copy into the project so the path is stable, then merge into settings.json
    HOOK_DEST_DIR="$PROJECT_DIR/.claude/hooks"
    mkdir -p "$HOOK_DEST_DIR"
    cp "$REPO_DIR/hooks/stop-gate-check.sh" "$HOOK_DEST_DIR/"
    chmod +x "$HOOK_DEST_DIR/stop-gate-check.sh"
    SETTINGS="$PROJECT_DIR/.claude/settings.json"
    mkdir -p "$(dirname "$SETTINGS")"
    if [[ ! -f "$SETTINGS" ]]; then echo '{}' > "$SETTINGS"; fi
    HOOK_CMD="$HOOK_DEST_DIR/stop-gate-check.sh"
    if grep -q "stop-gate-check.sh" "$SETTINGS"; then
      echo "  [skip] stop hook already wired in $SETTINGS"
      SKIPPED=$((SKIPPED+1))
    elif command -v python3 >/dev/null 2>&1; then
      python3 - "$SETTINGS" "$HOOK_CMD" <<'PYEOF'
import json, sys
path, cmd = sys.argv[1], sys.argv[2]
try:
    with open(path) as f:
        data = json.load(f)
except Exception:
    data = {}
if not isinstance(data, dict):
    data = {}
hooks = data.setdefault("hooks", {})
stop = hooks.setdefault("Stop", [])
entry = {"hooks": [{"command": cmd, "type": "command"}]}
if not any(e.get("hooks", [{}])[0].get("command") == cmd for e in stop):
    stop.append(entry)
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF
      echo "  [ok]   stop hook wired in $SETTINGS"
      INSTALLED=$((INSTALLED+1))
    else
      echo "  [warn] python3 not found — wire the hook manually:"
      echo "         see $REPO_DIR/INSTALL.md (step 3)"
    fi

    # Default routing: future feature requests go to the orchestrator
    echo "-- project routing: $PROJECT_DIR/CLAUDE.md"
    ensure_routing "$PROJECT_DIR/CLAUDE.md"
  fi
fi

# ---------------- Codex ----------------
if $have_codex; then
  echo "== Codex =="
  DEST="$HOME/.codex/skills"
  echo "-- user-level skills: $DEST"
  install_skills_to "$DEST"
  echo "   Note: Codex has no Stop-hook equivalent; gates are enforced by"
  echo "   orchestrator convention (see INSTALL.md). The skills themselves"
  echo "   are plain SKILL.md and work as-is."
  if [[ "$SCOPE" == "project" ]]; then
    echo "-- project routing: $PROJECT_DIR/AGENTS.md"
    ensure_routing "$PROJECT_DIR/AGENTS.md"
  fi
fi

echo ""
echo "Done: $INSTALLED installed/updated, $SKIPPED already present."
echo "Verify: ask your agent to list the 'orchestrator' skill, then say"
echo "  \"/orchestrator <your feature>\"  to start a gated build."
