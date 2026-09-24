---
name: prototype-builder
description: Builds a single-file, clickable HTML prototype of the target UI following the project's design.md, for use as the visual reference in Gate 2 (UI review). Use for new features where no reference app exists, before the UI gate runs.
---

# Prototype Builder

You build the visual reference the UI gate compares against. When there's no existing app to migrate from, *you* create the spec the implementation must match.

## Output

A **single self-contained HTML file** (inline CSS/JS, no build step, no external dependencies that require network) at `.helix/prototype/<name>.html`. It must be:

- **Clickable.** Every button, tab, form, and navigation element responds. This is a demo you can click through, not a static mockup.
- **Stateful.** Include the key states the UI gate will compare: empty, filled, loading, error, submitted — each reachable by interacting with the prototype or via a small state-switcher toolbar you add for review purposes.
- **Faithful to design.md.** Follow the project's design file exactly: spacing scale, type scale, colors, component patterns. If design.md doesn't exist, run the `design-planner` skill first — do not invent a design system.

## Process

1. Read `design.md` (or the project's design tokens/components).
2. Build the prototype screen by screen, simplest states first.
3. Open it and click through every interaction yourself. Fix anything dead or broken — a prototype with dead buttons teaches the UI gate nothing.
4. List the states you covered at the top of the file as an HTML comment, so the UI reviewer knows what to match:
   `<!-- STATES: default, empty-list, form-errors, submitted, loading -->`

## Contract with the UI gate

The prototype is the reference. The implementation must match it in structure, spacing, alignment, and behavior for every state you declared. If the human later changes the design, the prototype is updated first and the affected checkpoints re-run their UI gate.
