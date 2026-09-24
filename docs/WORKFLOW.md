# The Helix Loop, in depth

This document explains the workflow this repo reconstructs: where it came from, the ideas behind it, and exactly how the loop runs.

## Origin

In 2026, Shopify set out to move their mobile apps from React Native back to native Swift and Kotlin — starting with the Shop app (rebuilt and published in 12 weeks) and then their largest app, with 300+ screens. They used LLMs for the rebuild, but found that getting consistent, high-quality, maintainable results out of the box was difficult. So they built **Helix**: a set of tools and skills that wrap the model in a loop where **an imperfect attempt cannot move forward until it becomes a good result**.

Helix itself is internal, but Shopify published the full design of the loop on their engineering blog ([shopify.engineering/helix](https://shopify.engineering/helix)). The AI LABS video *"Shopify Just Released The Greatest Claude Code Workflow Ever"* walks through that design and rebuilds it as Claude Code skills. This repo is an original, open reconstruction of that same loop.

## The two load-bearing ideas

**1. Checkpoints small enough to review at a glance.** A migration starts from the existing code and the running app. The engineer picks a target (a screen or subscreen) and the work is broken into checkpoints of *increasing complexity* — skeleton first, then one deliberately small section, growing only after early decisions pass review. Each checkpoint is described in a few words, deliberately: the engineer checks whether the *sequence* makes sense. Nobody can effectively review a wall of generated text; one decision beats ten pages they'll skim. Small checkpoints also fit in a small context window, so the agent reads the relevant part of the reference directly instead of relying on a giant spec. **The reference is the spec.**

**2. Gates strict enough to stop anything unproven.** Each checkpoint goes through four gates, in order. If a gate fails, the agent uses the feedback to fix the implementation and runs the check again — as many times as needed. It cannot override a failed check because it thinks the result is good enough.

## The four gates

### Gate 1 — Behavior
The agent analyzes how the reference works, replicates it, and validates functionality through tests that exercise the feature the way a user would — without a browser or simulator. Shopify exposed screen state and actions through a CLI so the loop stays fast; the agent can iterate on behavior dozens of times before a single screenshot. The test cases generated per checkpoint define what "proven" means, and every relevant case must pass — including edge cases outside the happy path.

### Gate 2 — UI review
The most interesting gate, and the main reason output lands close to 1:1. UI equivalence is almost impossible to specify: humans notice a title that's slightly too small or a divider that's slightly too dark, but those details never make it into a prompt — and pixel-diffing doesn't work across UI frameworks. The solution: a vision model with strong spatial awareness (Shopify used Gemini) acts as a **perfectionist design reviewer**, comparing implementation and reference screenshots captured in **matching states**. It must list *every* difference with severity and on-screen location; anything fixable in code is a **blocker** by default. It can also mark a comparison INVALID if the states don't match. Review scope is limited to what the checkpoint built and grows per checkpoint. The first rendering doesn't need to be perfect — the system can *see* what's wrong, describe it, locate it, and require another attempt.

### Gate 3 — Adversarial reviews
Working code that looks right can still be badly built. Two **independent, context-isolated** reviewer agents check the checkpoint's code against the project's documented architecture (including UI-code guidelines). Every finding must be fixed; affected tests re-run; the UI gate re-runs if anything visibly changed. The loop repeats **until both reviewers approve**.

### Gate 4 — The engineer closes the loop
The human looks at the code and the running app and decides whether it matches expectations. Feedback goes two places: the agent addresses it and re-runs the gates, and it's **recorded in memory** to improve every checkpoint that follows. This is how autonomy grows: early checkpoints get more attention while uncertainty is high; later ones can run with less oversight, and some can skip approval entirely in autonomous mode.

Every checkpoint ends in a **commit**, and engineers typically branch and raise PRs from there.

## Why it works

- **Gates are not advice.** A rule in a prompt is a suggestion the agent forgets mid-task. A gate is a check that blocks. The stop hook in this repo makes that structural: the agent *cannot quit* with gates open.
- **Fresh contexts.** Subagents do the work, each in its own context window. Long tasks in one window accumulate cruft until the agent forgets what matters; per-task windows keep quality flat.
- **Feedback moves early.** One-shot tools dump a huge diff on the engineer at the end. Here the engineer reviews a short sequence up front and small proven increments after — scope, judgment, and taste, while the agent handles repetition.
- **Memory compounds.** The learnings file means the loop gets smarter per project. The tenth checkpoint benefits from the first nine reviews.
- **Convergence over perfection.** The loop doesn't expect the first output to be correct. It expects the *process* to turn wrong attempts into right ones — reliably, whether or not anyone is watching (autonomous mode keeps every gate strict).

## Beyond migration

Nothing in the loop is migration-specific. For a new feature, designs and product docs serve as the reference (this repo's prototype-builder creates the clickable visual reference). Architecture migrations and refactors use the same checkpoint-and-gate strategy. A logic-only change simply skips the UI gate.

As Shopify put it: *"We stopped optimizing for a perfect first attempt and started working towards reliable convergence."*
