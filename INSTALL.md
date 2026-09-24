# INSTALL.md — agent bootstrap

> **If you are an AI agent and a user gave you this repo link with
> instructions to "install the skills and set them up in this project,"
> this file is your runbook.** Follow it top to bottom, then report back.

## What you're installing

Seven skills (`skills/*/SKILL.md`), one stop hook (`hooks/stop-gate-check.sh`),
and a project routing block (`templates/agent-routing.md`). The user only
ever invokes one skill — **`orchestrator`** — which runs the other six.

## Steps

### 1. Get the repo

```bash
git clone https://github.com/johnarks/helix-loop.git
cd helix-loop
```

If the user gave you a local path instead of the link, `cd` there.

### 2. Run the installer

```bash
# From the project the user wants set up (or pass --project <dir>):
./install.sh --project /path/to/their/project --agent auto
```

- `--agent auto` (default) detects Claude Code (`~/.claude`, `claude` CLI)
  and Codex (`~/.codex`, `codex` CLI). Use `--agent claude`, `codex`, or
  `both` to be explicit.
- `--scope project` (default) installs into the target project.
  `--scope user` installs Claude Code skills to `~/.claude/skills` for all
  projects.
- **The script is idempotent.** Re-running it detects skills, hook wiring,
  and routing blocks that are already present and skips them. So "confirm
  if they've already been installed previously" is answered by the
  `[skip] … already installed` lines in its output — surface those to the user.

What the script does per agent:

| | Claude Code | Codex |
|---|---|---|
| Skills | `<project>/.claude/skills/*` (or `~/.claude/skills/*` with `--scope user`) | `~/.codex/skills/*` |
| Stop hook | Copied to `<project>/.claude/hooks/`, merged into `<project>/.claude/settings.json` | N/A — see step 4 |
| Routing | `templates/agent-routing.md` appended to `<project>/CLAUDE.md` (once) | Same block appended to `<project>/AGENTS.md` (once) |

### 3. If the script couldn't do something, do it by hand

- **Hook merge failed** (no python3): add to the project's
  `.claude/settings.json` under `hooks.Stop`:
  ```json
  { "hooks": [{ "command": "<project>/.claude/hooks/stop-gate-check.sh", "type": "command" }] }
  ```
  and `chmod +x` the script. The repo's `.claude/settings.example.json`
  shows the shape.
- **No git / can't clone**: copy the `skills/`, `hooks/`, and `templates/`
  directories out of the repo by whatever means you have, then perform the
  per-agent placement from the table above manually.

### 4. Codex caveat (important)

Codex has no equivalent of Claude Code's Stop hook (exit code 2 blocks
stopping). On Codex the gates are enforced by **orchestrator convention**,
not structurally: the orchestrator skill instructs the agent to never end a
turn with open gates and to re-check `.helix/state.json` before finishing.
Everything else — checkpoints, the four gates, fresh-context subagents,
learnings memory — works the same.

### 5. Verify, then confirm to the user

Run these checks and report the results:

1. **Skills present:** list the installed skill directories —
   7 expected (`orchestrator`, `checkpoint-planner`, `test-planner`,
   `prototype-builder`, `ui-reviewer`, `adversarial-review`, `design-planner`).
2. **Hook (Claude Code):** `bash -n` the hook script parses; run the repo's
   own test if you want (`hooks/stop-gate-check.sh` returns exit 2 with
   open gates, 0 when complete — it reads `.helix/state.json`).
3. **Routing:** the `HELIX-LOOP:ROUTING:START` marker exists in the project's
   `CLAUDE.md` and/or `AGENTS.md`.

Then tell the user, plainly: what's installed, what was already there
(quote the `[skip]` lines), which agent(s) were set up, and the Codex
caveat if it applies. End with: *"Say `/orchestrator <your feature>` (or
just describe the feature) and I'll route it through the loop from now on."*

## Manual install (no script)

```bash
# Claude Code, project-level
mkdir -p <project>/.claude/skills <project>/.claude/hooks
cp -r skills/* <project>/.claude/skills/
cp hooks/stop-gate-check.sh <project>/.claude/hooks/ && chmod +x <project>/.claude/hooks/stop-gate-check.sh
# merge hook into <project>/.claude/settings.json per step 3 above
cat templates/agent-routing.md >> <project>/CLAUDE.md

# Codex (user-level skills + project routing)
mkdir -p ~/.codex/skills
cp -r skills/* ~/.codex/skills/
cat templates/agent-routing.md >> <project>/AGENTS.md
```

## For agents with no skills system at all

The skills are plain Markdown. Read `skills/orchestrator/SKILL.md` and
follow it directly — it references the other six by role. The loop is a
procedure; the skills system is just packaging.
