<!-- HELIX-LOOP:ROUTING:START -->
## Helix Loop — default build workflow for this project

This project uses the **Helix Loop** skill pack (checkpoints + four enforced
gates per checkpoint: behavior tests → UI review → adversarial code review →
human approval).

**Routing rule:** when the user asks for feature work — a new feature, a
migration, or a substantial refactor — handle it with the **`orchestrator`**
skill. Do not build it as a single unreviewed pass. The orchestrator plans
checkpoints, runs each through all four gates, and stops for the human only
to approve the checkpoint plan and for final review.

**Non-negotiables while the loop runs:**
- A checkpoint is done only when every gate that applies to it passes.
  A failed gate blocks: fix and re-run, never skip.
- Keep working state in the project's `.helix/` directory
  (`checkpoints.json`, `state.json`, `learnings.md`, `evidence/`).
- Read `.helix/learnings.md` before starting any checkpoint; append new
  human feedback to it after every human review.
- Small, one-off questions and trivial edits do not need the loop —
  use judgment.
<!-- HELIX-LOOP:ROUTING:END -->
