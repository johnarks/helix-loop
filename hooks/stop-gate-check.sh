#!/usr/bin/env bash
#
# helix-loop stop hook — "the gate is not advice"
#
# Claude Code runs this on the Stop event. If the current checkpoint still has
# unpassed gates, the hook exits 2, which tells Claude Code to block the stop
# and feed the message below back to the agent so it keeps working.
#
# This is the structural enforcement behind the loop's core rule: an attempt is
# allowed to be wrong; it is not allowed to ship until it isn't.
#
# State file: .helix/state.json (project root), maintained by the orchestrator:
# {
#   "current_checkpoint": "cp-02",
#   "checkpoints": {
#     "cp-01": { "status": "done",
#       "gates": { "behavior": "passed", "ui": "passed",
#                  "adversarial": "passed", "human": "passed" } },
#     "cp-02": { "status": "in_progress",
#       "gates": { "behavior": "passed", "ui": "pending",
#                  "adversarial": "pending", "human": "pending" } }
#   }
# }
#
# Wire-up (Claude Code): .claude/settings.json ->
#   { "hooks": { "Stop": [ { "hooks": [
#       { "type": "command", "command": "<repo>/hooks/stop-gate-check.sh" } ] } ] } }
#
# The hook receives the project dir via CLAUDE_PROJECT_DIR (Claude Code sets it).
# Falls back to the current working directory.

set -u

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_FILE="$PROJECT_DIR/.helix/state.json"

# No loop state yet (orchestrator hasn't started or already finished and
# cleaned up): nothing to enforce, allow the stop.
if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

# python3 is the only dependency. If it's missing, fail open with a warning
# rather than wedging the session.
if ! command -v python3 >/dev/null 2>&1; then
  echo "helix stop hook: python3 not found; cannot verify gates. Allowing stop." >&2
  exit 0
fi

python3 - "$STATE_FILE" <<'EOF'
import json, sys

state_file = sys.argv[1]
try:
    with open(state_file) as f:
        state = json.load(f)
except (json.JSONDecodeError, OSError) as e:
    print(f"helix stop hook: cannot read state file ({e}); allowing stop.", file=sys.stderr)
    sys.exit(0)

checkpoints = state.get("checkpoints", {})
current = state.get("current_checkpoint")

if not current or current not in checkpoints:
    sys.exit(0)  # nothing in flight

entry = checkpoints[current]
gates = entry.get("gates", {})
# "skipped" counts as satisfied (logic-only checkpoints skip the UI gate
# with an explicit reason recorded by the orchestrator).
open_gates = [g for g, s in gates.items() if s not in ("passed", "skipped")]

if not open_gates:
    sys.exit(0)  # all gates clear — allow the stop

# Block the stop: exit code 2 feeds this message back to the agent.
print(
    f"HELIX GATE BLOCK: checkpoint '{current}' still has open gates: "
    f"{', '.join(open_gates)}. "
    "You may not stop until every gate passes (or is explicitly skipped with a "
    "recorded reason). Return to the loop: fix what the failing gate reported, "
    "re-run the gate, update .helix/state.json, and try again. "
    "An attempt is allowed to be wrong; it is not allowed to ship until it isn't."
)
sys.exit(2)
EOF
