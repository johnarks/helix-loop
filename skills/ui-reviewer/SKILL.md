---
name: ui-reviewer
description: Perfectionist visual-review protocol for Gate 2. Compares implementation screenshots against the reference (existing app or HTML prototype) in matching states using a vision-capable model, listing every difference with severity and on-screen location. Use at Gate 2 for checkpoints with needs_ui_gate=true.
---

# UI Reviewer

Visual equivalence is almost impossible to specify in a prompt — a human notices a title that's slightly too small or a divider that's slightly too dark, but those details never make it into instructions, and pixel-diffing fails across UI frameworks. So instead of specifying every detail up front, this gate **looks** at the result, describes what's wrong, locates it, and requires another attempt.

## Setup

- **Reviewer model:** a vision-capable model with strong spatial awareness (the original workflow used Gemini for this; any model that can judge sizes, spacing, and alignment from screenshots works). Launch it in a **fresh session** — it must not see the project's instructions or the implementation's code. It judges only: reference vs. implementation.
- **Two reviewers, side by side:** one judges how the screen **looks** (structure, spacing, alignment, sizes), the other judges how it **behaves** (interactions, state transitions). Neither sees project instructions. The orchestrator merges their reports into one pass/fail.

## Protocol

1. **Capture in matching states.** Screenshot the implementation and the reference showing the *same* screen in the *same* state (e.g., both showing the unsubmitted form). State mismatches invalidate the comparison — if the reviewer reports INVALID (e.g., one shows an unfulfilled order, the other a fulfilled one), re-capture both in the same state and run again.
2. **Limit scope to the checkpoint.** For a skeleton checkpoint, review only what it built (e.g., "check only the navigation bar and title"). The scope grows with each checkpoint. State the scope explicitly in the review request.
3. **Judge proportionally.** Compare sizes relative to each screenshot's dimensions, so undersized/oversized text is caught even across different render sizes.
4. **Report format.** The reviewer must list **every** difference it finds, each with:
   - **Description** (what differs)
   - **Severity** (blocker / minor)
   - **On-screen location** (where: e.g., "top nav, right of title")
5. **Blocker rule.** Any visual difference that can be fixed in code is a **blocker** by default. Minors are noted but don't fail the gate.
6. **Verdict.** Pass only with zero blockers. Otherwise return the blocker list to the builder, who fixes and re-runs this gate.

## After the gate

Archive the screenshots and the review report under `.helix/evidence/<checkpoint-id>/ui-review/`. They are part of the checkpoint's evidence — and the record of what "matching" meant.
