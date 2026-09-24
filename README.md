# Helix Loop

An open, from-scratch reconstruction of the **checkpoint-and-gate agentic coding workflow** that Shopify described publicly for rebuilding their mobile apps with AI coding agents — popularized by the AI LABS video *"Shopify Just Released The Greatest Claude Code Workflow Ever."*

No signup. No paywall. No gated files. Just the workflow, rebuilt as a Claude Code skill pack you can run today.

> **Attribution:** This is an unofficial, original reconstruction. It is not affiliated with Shopify or AI LABS. The workflow design is based on Shopify's public engineering writeup ([shopify.engineering/helix](https://shopify.engineering/helix)) and the public description in the video. All prompts, skills, and code here were written from scratch for this repo.

---

## What this is

Most AI coding tools work like this: gather everything into one giant prompt, generate a huge chunk of code, and hope the first result works. You get a massive diff and all the verification work lands on you at the end.

The Helix loop works the opposite way:

1. **Checkpoints** — the work is split into small, ordered slices (simplest first). Each one is small enough to review at a glance and small enough to fit in a small context window.
2. **Gates** — each checkpoint must pass four strict checks before the next one begins: **behavior tests → UI review → adversarial code review → human approval**. A failed gate blocks progress. The agent can retry as many times as it needs, but it cannot override a failed check.
3. **Fresh contexts** — subagents do the actual work, each in its own context window, so quality doesn't decay over a long run.
4. **A stop hook** — the agent is physically prevented from stopping (Ralph-loop style) until every gate for the current checkpoint passes.
5. **Memory** — feedback from every human review is written to a learnings file that every agent reads before starting, so the loop gets more autonomous as it goes.

The governing principle, in Shopify's words: **an attempt is allowed to be wrong; it is not allowed to ship until it isn't.**

## Why it's useful

- **Reliable convergence instead of a perfect first attempt.** You stop optimizing your prompt for one-shot perfection and start optimizing the loop that turns wrong attempts into right ones.
- **Review moves to the earliest useful point.** Instead of reviewing one giant uncertain diff at the end, you review a checkpoint sequence up front (minutes, not hours) and small proven increments as they land.
- **Quality doesn't decay.** Fresh subagent contexts per task eliminate the "long conversation, forgotten instructions" failure mode.
- **Gates beat rules.** A rule in a prompt is advice the agent forgets. A gate is a check that blocks. The stop hook makes this structural, not aspirational.
- **Evidence per checkpoint.** Every committed checkpoint ships with passing tests, UI review records, and reviewer verdicts — not just code.
- **It generalizes.** Built for migrations (reference app = the spec), but works for new features (designs/docs = the reference) and refactors. Logic-only changes simply skip the UI gate.

## How it works (the loop)

```
                    ┌─────────────────────────────────────────────────┐
                    │              HUMAN INPUT #1                     │
                    │   Review checkpoint sequence in the viewer.     │
                    │   Approve, or request changes.                  │
                    └──────────────────────┬──────────────────────────┘
                                           ▼
              ┌─────────────────────────────────────────┐
              │  For EACH checkpoint, in order:         │
              │                                         │
              │  1. Subagents write tests (fail first)   │
              │  2. Subagent implements the checkpoint  │
              │  3. Subagent runs tests                 │
              │                                         │
              │  GATE 1 ─ Behavior: all tests pass      │
              │     │ fail → fix, re-run                │
              │     ▼ pass                              │
              │  GATE 2 ─ UI review (if applicable):    │
              │     screenshot vs reference/prototype,  │
              │     vision reviewer lists every diff    │
              │     │ fail → fix, re-run                │
              │     ▼ pass                              │
              │  GATE 3 ─ Adversarial review: two       │
              │     isolated reviewers vs the arch doc; │
              │     every finding fixed; both approve   │
              │     │ fail → fix, re-run tests (+ UI    │
              │     │         gate if visibly changed)  │
              │     ▼ pass                              │
              │  GATE 4 ─ Human review: approve, or     │
              │     feedback → learnings file + re-run  │
              │                                         │
              │  Commit checkpoint with evidence.       │
              └─────────────────────────────────────────┘
                                           │
                                           ▼
                    ┌─────────────────────────────────────────────────┐
                    │              HUMAN INPUT #2                     │
                    │   Test the finished feature. Request changes    │
                    │   → they become new checkpoints, same gates.    │
                    └─────────────────────────────────────────────────┘
```

The **orchestrator skill** runs this entire loop. You prompt it once with your feature; it stops for you exactly twice (the two boxes above). The **stop hook** guarantees it can't quit early.

Full deep-dive: [`docs/WORKFLOW.md`](docs/WORKFLOW.md)

## Setup

**Requirements:** [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (skills, subagents, and hooks). A vision-capable model for the UI gate (any model with strong spatial awareness — the original used Gemini; the skill is model-agnostic).

**Install (2 minutes):**

```bash
# 1. Clone
git clone https://github.com/johnarks/helix-loop.git
cd helix-loop

# 2. Install the skills (project-level)
mkdir -p .claude/skills
cp -r skills/* .claude/skills/
#    …or user-level, to use in every project:
# cp -r skills/* ~/.claude/skills/

# 3. Wire up the stop hook (project-level .claude/settings.json)
cp .claude/settings.example.json .claude/settings.json
#    Make sure the hook path points at hooks/stop-gate-check.sh

# 4. Make the hook executable
chmod +x hooks/stop-gate-check.sh
```

That's it. The skills are plain Markdown (`SKILL.md`) files Claude Code discovers automatically.

**Per-project state:** the loop keeps its working state in a `.helix/` directory inside your project (created automatically on first run):

```
.helix/
├── checkpoints.json      # the checkpoint plan
├── state.json            # current checkpoint + gate statuses (drives the stop hook)
├── learnings.md          # human feedback memory — every agent reads this first
└── evidence/             # per-checkpoint: test reports, UI reviews, reviewer verdicts
    └── cp-01/
```

## Usage

**Starting a feature or migration:**

> /orchestrator — Add user authentication to this app. Reference: the Figma export in /designs and the API spec in docs/api.md. Follow the architecture in ARCHITECTURE.md.

Or invoke the skill directly and describe the work in plain language. The orchestrator will:

1. Verify your app builds/runs (subagent).
2. Plan checkpoints with the checkpoint-planner (it will ask you questions if anything is ambiguous).
3. Plan tests for every checkpoint.
4. Open the **checkpoint viewer** (`viewer/index.html` + your `.helix/checkpoints.json`) so you can review the plan — this is Human Input #1.
5. Build checkpoint by checkpoint through all four gates.
6. Commit each checkpoint with its evidence.
7. Hand you the finished feature for final review — Human Input #2. Your change requests become new checkpoints and go through the same gates.

**Reviewing the plan:** open `viewer/index.html` in a browser and load your project's `.helix/checkpoints.json` (file picker, or serve the project dir and let it fetch relatively). Each checkpoint shows its order, scope, done-criteria, and which gates apply.

**Autonomous mode:** tell the orchestrator "approve the next 3 checkpoints" or "run to completion, I'll review at the end." Gates do not get lax — every checkpoint still proves behavior, passes UI review, and satisfies both adversarial reviewers.

**New feature vs migration:** point the orchestrator at a reference (existing app/screen = the spec, per the original) or at designs/docs for greenfield work. Logic-only changes skip the UI gate automatically.

## What's in this repo

| Path | What it is |
|---|---|
| `skills/orchestrator/` | The one skill you prompt — runs the entire loop |
| `skills/checkpoint-planner/` | Splits work into small, ordered, reviewable checkpoints |
| `skills/test-planner/` | Generates behavior test cases per checkpoint (user's perspective, incl. edge cases) |
| `skills/prototype-builder/` | Builds a single-file clickable HTML prototype as the UI reference |
| `skills/ui-reviewer/` | Vision-reviewer protocol: matching states, every difference listed with severity + location |
| `skills/adversarial-review/` | Two isolated reviewers vs. your architecture doc; fix-loop until both approve |
| `skills/design-planner/` | Produces the `design.md` architecture doc that reviewers enforce |
| `hooks/stop-gate-check.sh` | Stop hook — blocks the agent from quitting until gates pass (exit code 2) |
| `viewer/index.html` | Checkpoint plan viewer (dependency-free, runs in a browser) |
| `schemas/checkpoints.schema.json` | JSON schema for the checkpoint plan |
| `templates/` | Example checkpoints file, `design.md` template, `learnings.md` template |
| `docs/WORKFLOW.md` | The loop explained in depth |
| `docs/ORIGINAL-RESEARCH.md` | Sources: Shopify's Helix writeup, the video, and open alternatives |

## How this differs from the alternatives

| | This repo | Shopify's Helix | AILABS Pro (video's pitch) |
|---|---|---|---|
| Availability | Free, open (MIT) | Internal only | Paid community |
| Checkpoints + 4 gates | ✅ | ✅ | ✅ |
| Stop hook (can't quit early) | ✅ | ✅ (their infra) | ✅ |
| Adversarial review | ✅ two independent reviewers (faithful to original) | ✅ two reviewers, both must approve | Variant: critic + fixer loop |
| UI reviewer model | Your choice (model-agnostic) | Gemini | Fresh Claude session |
| Checkpoint viewer | ✅ dependency-free HTML | Internal tooling | ✅ |
| Learnings memory | ✅ | ✅ (grows autonomy) | ✅ |

## FAQ

**Do I need the reference app?** No. Migrations use the existing app as the spec ("the reference *is* the spec"). New features use designs/product docs; the prototype-builder skill creates the clickable reference.

**Which model does the UI gate need?** Any vision-capable model with good spatial awareness. The original used Gemini; configure whichever you have in the ui-reviewer skill.

**Will this work outside Claude Code?** The concepts transfer anywhere (checkpoints, gates, fresh contexts, adversarial review). The skills and hook are written for Claude Code's skills/subagents/hooks system.

**How is this different from just "use subagents and review"?** The difference is structural enforcement: gates *block*, the hook *prevents quitting*, checkpoints are *small by construction*, and learnings *accumulate*. It's a loop that converges, not advice that gets forgotten.

## License

MIT — see [LICENSE](LICENSE).
