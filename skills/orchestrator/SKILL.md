---
name: orchestrator
description: Runs the full Helix-style build loop for a feature or migration. Splits work into checkpoints, enforces four gates per checkpoint (behavior tests, UI review, adversarial code review, human approval), and stops for the human only twice: checkpoint-plan approval and final review. Use when the user wants a feature built or a screen/app migrated with enforced quality gates.
---

# Orchestrator

You run the entire build loop. The human prompts you once with the work to do. You stop for them exactly twice: (1) to approve the checkpoint plan, (2) for final review of the finished work. Everything else, you handle via subagents.

**Governing principle:** an attempt is allowed to be wrong; it is not allowed to ship until it isn't. Gates block. You do not move to the next checkpoint until every gate on the current one passes. You do not stop until the loop is complete — the stop hook enforces this structurally, but you must also honor it intentionally.

**Environments without hook support** (e.g. Codex, or any agent that can't run a Stop hook): there is no structural backstop, so enforcement is on you. Before ending *any* turn, read `.helix/state.json`; if any gate on the current checkpoint is open, keep working — fix and re-run, never declare the checkpoint done. Treat "I can't stop with open gates" as a hard rule, not a suggestion.

## 0. Read before anything else

1. The project's architecture/standards doc (`ARCHITECTURE.md`, `design.md`, or equivalent — ask the human where it lives if you can't find it). This is the standard every reviewer enforces. If none exists, run the `design-planner` skill first to create one.
2. `.helix/learnings.md` if it exists. This is accumulated human feedback. It overrides your defaults. If it doesn't exist, create it from the template at the end of this run's first human review.
3. The task: either a **reference** (existing screen/app to migrate — "the reference *is* the spec") or a **feature description + designs/docs** (for new work).

## 1. Planning phase

Launch two subagents in parallel:

- **App-state checker:** verify the project builds and runs right now. Report the exact commands that work (`npm run dev`, `pytest`, etc.). If it doesn't build, stop and tell the human — do not plan work on a broken base.
- **Checkpoint planner** (use the `checkpoint-planner` skill): reads the reference or feature description and produces `.helix/checkpoints.json` following `schemas/checkpoints.schema.json`. Checkpoints must be ordered by **increasing complexity** — skeleton/foundation first, details later. Each checkpoint gets a short title (a few words — the human reviews the *sequence*, not an essay), done-criteria, and a `needs_ui_gate` flag (false for logic-only checkpoints).

If the planner has questions it cannot resolve from the reference, **ask the human now** — an hour of planning questions is cheaper than a wasted build.

Then launch a third subagent:

- **Test planner** (use the `test-planner` skill): for each checkpoint, generate behavior test cases from the *user's perspective*, including edge cases outside the happy path. These define what "proven" means for Gate 1. Store the plan at `.helix/test-plan.md`.

Initialize `.helix/state.json`:

```json
{
  "current_checkpoint": "<first checkpoint id>",
  "checkpoints": {
    "<id>": {
      "status": "planned",
      "gates": { "behavior": "pending", "ui": "pending", "adversarial": "pending", "human": "pending" }
    }
  }
}
```

## 2. Human Input #1 — plan approval (MANDATORY STOP)

Tell the human: "Open `viewer/index.html` in your browser and load `.helix/checkpoints.json` to review the plan." Summarize the checkpoint sequence in a few short lines (titles only — respect the "one decision, not ten pages" rule).

Wait for approval. If the human requests changes, update `checkpoints.json` (and the test plan if scope changed) and re-present. Do not start building on an unapproved plan.

## 3. Build loop — one checkpoint at a time, in order

For the current checkpoint:

**3a. Tests first.** Spawn subagents to write the checkpoint's tests (from the test plan). They must FAIL initially — the feature doesn't exist yet. If any test passes before implementation, the test is wrong; fix the test.

**3b. Implement.** Spawn a fresh subagent to write the checkpoint code. Fresh context per checkpoint: the implementer gets the checkpoint description, done-criteria, relevant reference excerpt, architecture doc, and learnings — not the entire conversation history.

**3c. Run tests.** Spawn a subagent to run the full checkpoint test suite. Iterate on failures (implementer fixes, runner re-runs) until green.

### Gate 1 — Behavior
All checkpoint test cases pass. These are code/integration-level tests — no browser, no screenshots. Fast loop: iterate dozens of times here before any visual check. Mark `gates.behavior = "passed"` in state.json.

### Gate 2 — UI review (skip if `needs_ui_gate` is false)
Use the `ui-reviewer` skill. Requirements:
- There must be a visual reference: the reference app (migration) or the HTML prototype (new feature — build it with the `prototype-builder` skill *before* this gate, per `design.md`).
- Capture implementation and reference in **matching states** (e.g., both showing the unsubmitted form). If the reviewer flags a state mismatch as INVALID, re-capture and re-run.
- Limit the review scope to what this checkpoint built (a skeleton checkpoint reviews only the nav bar and title, not the whole screen).
- The reviewer lists **every** difference with severity and on-screen location. Any difference fixable in code is a **blocker** by default.
- Fix blockers, re-run. Mark `gates.ui = "passed"` (or `"skipped"` with reason for logic-only checkpoints).

### Gate 3 — Adversarial review
Use the `adversarial-review` skill: two **independent, context-isolated** reviewer subagents check the checkpoint's code against the architecture doc (including UI-code guidelines). Rules:
- Every finding must be fixed by the builder (a fresh subagent, not the reviewers).
- After fixes: re-run the affected behavior tests. If anything visibly changed, re-run Gate 2.
- Reviewers re-examine the changed code. Repeat **until both reviewers approve**.
- Mark `gates.adversarial = "passed"`.

### Gate 4 — Human review of the checkpoint
Present: what was built, test results, UI review summary, reviewer verdicts. The human approves or gives feedback.
- Approval → mark `gates.human = "passed"`.
- Feedback → append it to `.helix/learnings.md` (this is the memory that makes later checkpoints more autonomous), address it via the builder, and **re-run every gate** the change could affect.

**Commit.** Every finished checkpoint ends in a commit: `helix(cp-<id>): <short title>`. Include the evidence (test report, UI review, verdicts) under `.helix/evidence/<id>/` in the commit. Advance `current_checkpoint` in state.json.

## 4. Human Input #2 — final review (MANDATORY STOP)

When all checkpoints are done, hand the human the running feature/app. They test it as a user. Change requests become **new checkpoints** appended to `checkpoints.json` and go through the full loop (all four gates). Their feedback goes into `learnings.md`.

## Operating rules

- **Never skip a gate.** Not for "small" checkpoints, not when you're confident, not in autonomous mode. Logic-only checkpoints skip Gate 2 with an explicit `"skipped"` reason — that is the only exception.
- **Never work two checkpoints at once** in the same thread of the loop. (Parallel *screens*, each with their own loop and gates, are fine.)
- **One decision per human interruption.** When you stop for the human, ask for the decision you need — don't dump ten pages.
- **Update state.json at every gate transition.** The stop hook reads it. If your session ends unexpectedly, the next session resumes from state.
- **Autonomous mode** (only if the human explicitly requests it): "run the next N checkpoints" or "run to completion." Gates are unchanged. Human gate becomes recorded self-review against the learnings file, and all evidence must be archived for later human audit. Some checkpoints may skip Human Input #1-style approval only if the human said so.
- **Keep contexts small.** Subagents get the minimum they need: checkpoint scope, done-criteria, relevant reference excerpt, architecture doc, learnings. Never paste the whole plan or history into a worker.
- **The reference is the spec** (migrations). Don't invent behavior the reference doesn't have; don't drop behavior it does. Discrepancies → ask the human.

## Failure handling

- Gate fails → fix → re-run that gate. Unlimited retries; zero overrides.
- Reviewer marks UI comparison INVALID → re-capture in matching states, re-run.
- Tests pass before implementation → the tests are wrong; fix them.
- App doesn't build at phase 1 → stop, report to human, do not plan.
- Human rejects the plan twice → ask what outcome they actually want; don't thrash.
