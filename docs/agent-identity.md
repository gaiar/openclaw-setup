---
layout: default
title: Agent Identity & Memory
nav_order: 1
parent: Configuration
---

# Agent Identity & Memory
{: .no_toc }

How OpenClaw develops a persistent identity through plain Markdown memory files.
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## Overview

Memory in OpenClaw is plain Markdown on disk. Files are loaded at session start and injected into the system prompt. This is how the agent develops a persistent identity and operational context.

There is no database, no proprietary format, and no vendor lock-in. Every piece of the agent's knowledge lives in human-readable `.md` files inside `~/.openclaw/workspace/`. You can read, edit, version-control, and back up these files with standard tools.

---

## Core Memory Files

| File | Purpose | Mutability |
|:-----|:--------|:-----------|
| `SOUL.md` | Behavioral core -- voice, temperament, values, constraints, security protocols | Rarely changes |
| `USER.md` | Operator profile -- name, timezone, work context, communication preferences | Updated as needed |
| `MEMORY.md` | Curated long-term facts -- OS versions, architectural decisions, constraints | Keep compact |
| `HEARTBEAT.md` | Heartbeat daemon config and async task checklist | Volatile |
| `IDENTITY.md` | Agent presentation/persona | Stable |
| `AGENTS.md` | Agent instructions and mandatory execution steps | Stable |
| `TOOLS.md` | Tool capabilities documentation | Stable |
| `memory/YYYY-MM-DD.md` | Daily logs (raw event journal) | Append-only |

All files are located in `~/.openclaw/workspace/` unless otherwise configured in `openclaw.json`.

---

## Create the Identity Files

Create the core memory files that the agent reads on every session start:

```bash
cd ~/.openclaw/workspace
touch SOUL.md USER.md MEMORY.md HEARTBEAT.md
```

The agent will function without these files, but it will have no persistent identity, no operator context, and no behavioral constraints. Populating them is strongly recommended before connecting any messaging channels.

---

## SOUL.md -- The Agent Constitution

`SOUL.md` is the most important memory file. It defines the agent's non-negotiable behavioral rules -- its constitution. Everything in this file is injected at the top of the system prompt on every turn, making it the highest-priority instruction set the agent follows.

Use `SOUL.md` for **rules**, not facts. Facts belong in `MEMORY.md`. The soul file should answer: "What must this agent always do, and what must it never do?"

**Example:**

```markdown
# OpenClaw Constitution

## Security Boundary
- You operate on an isolated VPS running Ubuntu.
- Never execute destructive commands (rm -rf, DROP TABLE, etc.).
- Never expose API keys in chat logs or daily journals.

## Tool Usage
- Require explicit human approval for all outgoing emails, financial transactions, and file deletions.

## Memory Protocol
- Always run memory_search before asking clarifying questions about operational history or project configuration.
```

Keep `SOUL.md` concise and focused on constraints. A shorter, tighter constitution is more reliably followed than a sprawling one. Aim for rules that are unambiguous, actionable, and testable.

---

## USER.md -- Operator Profile

`USER.md` tells the agent who it is working for and how the operator prefers to interact. This file shapes the tone, format, and assumptions of every response.

**Example:**

```markdown
# Operator Profile

- Language: English
- Timezone: America/New_York
- Output format: concise, copy-paste friendly commands
- Risk tolerance: conservative — always confirm before destructive actions
```

Update this file whenever your preferences change. The agent reads it fresh on every session start, so changes take effect immediately after a gateway restart.

---

## HEARTBEAT.md -- Autonomous Tasks

The heartbeat scheduler is OpenClaw's built-in autonomous trigger. Every 30 minutes (60 minutes when using Anthropic OAuth), the agent reads `HEARTBEAT.md` and processes any tasks listed in it.

**How it works:**

1. The heartbeat fires on the configured interval
2. The agent reads `HEARTBEAT.md` for pending tasks
3. Each task is processed in an agent turn
4. If the response is only `HEARTBEAT_OK` (or fewer than 300 characters after removing the heartbeat token), the response is silently discarded -- no message is sent to any channel
5. If the response exceeds 300 characters, it is delivered to the configured notification channel

**Example:**

```markdown
# Heartbeat Tasks

- [ ] Check if deployment at openclaw.YOURDOMAIN.COM is healthy
- [ ] Review any new GitHub issues in the project repo
- [ ] Send a daily summary to Telegram if it is 9:00 AM in the operator's timezone
```

To disable the heartbeat entirely, leave `HEARTBEAT.md` empty. The agent will still wake up on each cycle, but it will produce a short `HEARTBEAT_OK` response that gets silently discarded.

You can configure active hours and timezone in `openclaw.json` to prevent the heartbeat from firing during off-hours.

---

## Best Practices

**SOUL.md -- keep it about rules, not facts.**
The soul file defines what the agent must and must not do. Do not put operational facts (server IPs, project names, dependency versions) here. Those belong in `MEMORY.md`. A soul file cluttered with facts becomes harder for the model to follow reliably.

**MEMORY.md -- keep it compact.**
This file is injected into every system prompt, so every byte counts toward your context window. Curate aggressively. Remove stale facts. Use bullet points, not prose. If a fact is only relevant to a specific project, consider putting it in a project-specific memory file or daily log instead.

**Daily logs (`memory/YYYY-MM-DD.md`) -- use for raw data.**
Daily logs are append-only journals where the agent records events, decisions, and findings throughout the day. They are not injected into the system prompt by default but are indexed for semantic search via `memory_search`. Use them as the agent's scratch pad and audit trail.

**HEARTBEAT.md -- be specific.**
Vague tasks like "check things" produce vague responses. Write tasks as concrete, verifiable actions: "Check if the HTTP endpoint at openclaw.example.com returns 200" or "Count open GitHub issues labeled `bug` in repo X".

**Version control your workspace.**
Since all memory files are plain Markdown, you can (and should) track them in git. This gives you a full history of how the agent's identity and knowledge evolve over time, and makes recovery trivial.

---

## SOUL.md Templates

The community maintains a collection of pre-built `SOUL.md` templates at [onlycrabs.ai](https://onlycrabs.ai). These templates provide starting points for different agent personas and use cases -- from conservative operational assistants to creative writing companions.

Browse the templates for inspiration, but always customize them to match your specific security requirements and operational context. A template is a starting point, not a finished product.

---

{: .claude }
> Copy this into Claude Code:
> ```
> Create the core identity files for the OpenClaw agent:
>
> cd ~/.openclaw/workspace
> touch SOUL.md USER.md MEMORY.md HEARTBEAT.md
>
> Then populate SOUL.md with security boundaries (never expose API keys,
> never run destructive commands, require approval for emails and
> file deletions), and USER.md with operator preferences (language,
> timezone, output format, risk tolerance).
>
> Leave HEARTBEAT.md empty for now — it can be populated later
> with autonomous tasks for the heartbeat scheduler.
> ```
