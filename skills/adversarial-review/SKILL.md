---
name: adversarial-review
description: Gate 3 protocol. Two independent, context-isolated reviewer agents check checkpoint code against the project's architecture doc; every finding is fixed and both reviewers must approve. Use at Gate 3 for every checkpoint.
---

# Adversarial Review

The feature works and looks right. The code underneath can still be a mess. This gate exists to catch that — and it's enforceable only because the architecture is **written down** (see `design-planner`). Reviewers check code against the doc, not against vibes.

## Setup

Launch **two independent reviewer subagents** with:
- The checkpoint's changed files (diff).
- The architecture doc (`ARCHITECTURE.md` / `design.md`), including UI-code guidelines.
- `.helix/learnings.md`.
- Explicitly **no** access to the builder's reasoning, the test plan, or each other's output. Context isolation is what makes the reviews independent.

Each reviewer assumes an adversarial stance: the code is guilty until proven consistent with the standard. They check: architecture layering, component/pattern compliance, naming, error handling, security basics, test quality, and anything the learnings file flags as a known past mistake.

## The loop

1. Reviewers return findings, each with file, line, rule violated, and severity.
2. A **builder subagent** (fresh context — not one of the reviewers) fixes every finding.
3. Re-run the **affected behavior tests** (Gate 1 scope for the changed code).
4. If anything **visibly changed**, re-run **Gate 2** (UI review).
5. Reviewers re-examine the changed code.
6. Repeat until **both reviewers approve** with no outstanding findings.

The gate passes only on dual approval. A single reviewer's approval is not enough; the builder's confidence is irrelevant.

## Output

Archive under `.helix/evidence/<checkpoint-id>/adversarial/`: each review round's findings, the fixes applied, test re-run results, and both final approvals. This is the paper trail that the checkpoint's code was held to the standard.
