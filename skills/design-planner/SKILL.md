---
name: design-planner
description: Produces the project's design.md — the opinionated architecture and design-system doc that the prototype builder follows and the adversarial reviewers enforce. Use when a project has no written architecture standard, before the first orchestrated build.
---

# Design Planner

Reviewers can only enforce a standard that exists. Your job is to write it: a single `design.md` that is opinionated enough to settle arguments.

## Process

1. **Survey the project.** Read the existing code, components, and any design assets (Figma exports, mockups, brand guidelines). Ask the human for anything missing — especially the parts engineers argue about (state management, data flow, error handling).
2. **Be opinionated.** "Use X for Y" beats "consider X or Y." Every section should let a reviewer point at a line of code and say "this violates the doc" or "this follows it."
3. **Keep it implementable by agents.** Small checkpoints are built by subagents with small contexts — the doc must be skimmable, with clear do/don't examples.

## Document structure

```markdown
# <Project> design system & architecture

## Principles
<3–6 non-negotiable principles, one line each>

## Tech & structure
<stack, folder layout, module boundaries, what lives where>

## Components
<the component set; when to build new vs reuse; props conventions>

## Visual language
<spacing scale, type scale, color tokens, radius, elevation — exact values>

## State & data flow
<how state moves; server/client boundaries; caching rules>

## Errors & edge cases
<how errors surface; empty/loading/error states — required everywhere>

## Code standards
<naming, file conventions, testing requirements, things that are banned>

## UI-code guidelines
<platform-specific rules reviewers enforce at Gate 3>
```

## Done when

A reviewer given only this doc and a diff can produce specific, cited findings. If a section is too vague to cite, rewrite it. Store at the project root as `design.md` (or merge into the existing `ARCHITECTURE.md` — one standard, one place).
