# Original research

How this repo was reconstructed, and what else exists. All sources below are public and were accessed read-only; nothing gated or paid was copied.

## The original: Shopify's Helix

- **Source:** "Helix: The internal tool powering our Shopify app's native migration (2026)" — [shopify.engineering/helix](https://shopify.engineering/helix)
- **What it is:** the internal set of tools and skills Shopify built to rebuild their mobile apps (React Native → native Swift/Kotlin) with LLMs. Used on the Shop app (12 weeks, rebuilt and published) and then their 300+ screen flagship app.
- **What was published:** the full loop design (checkpoints, the four gates, memory, autonomous mode) — but not Helix's code. The tool itself remains internal.
- **Key mechanics from the original** (faithfully reconstructed here): checkpoints described in a few words and ordered by increasing complexity; behavior tests via a CLI exposing screen state (no simulator); Gemini as perfectionist UI reviewer with severity + on-screen location per difference, blockers by default, INVALID state handling, scope limited per checkpoint; **two** independent adversarial reviewers with dual approval required; engineer feedback recorded to memory; every checkpoint ends in a commit; autonomous mode with undiminished gates; evidence archived per checkpoint.

## The video that popularized it

- **Video:** "Shopify Just Released The Greatest Claude Code Workflow Ever" — AI LABS (14:50). Full transcript was captured for research; the video walks through Shopify's design and rebuilds it as Claude Code skills, demoed on an HR-system app.
- **Additions in the video's rebuild** (not in Shopify's original): a stop hook using exit code 2 (borrowed from the "Ralph loop" concept) to prevent the agent quitting before gates pass; a single-file HTML **prototype** as the UI reference for greenfield work; a `design.md` planner skill; a **checkpoints viewer** webpage; a **learnings file** every agent reads; test planning up front via a TDD planner skill.
- **One deliberate difference:** for Gate 3 the video uses a critic + fixer adversarial *loop* (one agent criticizes, another fixes). Shopify's original uses **two independent reviewers that must both approve**. This repo implements the original's dual-reviewer design, since it's the published source of truth.
- **The pitch:** the video's prebuilt skills are sold via the creator's **AILABS Pro** community (ailabspro.io). No pricing is stated in the video. This repo is the no-signup alternative — everything rebuilt from scratch from the public descriptions.

## Related public work (not copies — adjacent pieces of the puzzle)

These informed the reconstruction and are worth knowing about:

- **[obra/superpowers](https://github.com/obra/superpowers)** (MIT) — composable Markdown skills for Claude Code: brainstorm → design doc → implementation plan → subagent-driven development → TDD ("no production code without a failing test") → code review. The closest open equivalent to disciplined agent workflows; installable via `/plugin install superpowers@claude-plugins-official`.
- **Anthropic's [commerce-agents](https://github.com/anthropics/commerce-agents)** — public reference architecture for agent builds.
- **Ralph loop** (community technique) — the "keep going until done" loop pattern; this repo's stop hook is the same idea applied to gates (exit code 2 on Stop = blocked, agent re-prompted).
- **kevinschawinski/claude-agents** — Markdown/YAML Claude Code crew (planner, researcher, coder, critic…).
- **primo737/agents** — multi-agent orchestration on the Claude Agent SDK with 47+ skills.
- **coder-sjw/open-design** — open-source design-system/prototype tooling with MCP server for Claude Code; a natural companion for the prototype-builder skill.

## What was NOT used

The AILABS Pro community materials are gated; they were not accessed, copied, or reproduced. Every skill, prompt, template, and line of code in this repo was written originally for it, based only on the public Shopify writeup and the video's public description.
