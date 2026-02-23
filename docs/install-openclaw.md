---
layout: default
title: Install OpenClaw
nav_order: 2
parent: Installation
---

# Install OpenClaw
{: .no_toc }

Install the OpenClaw gateway and run the onboarding wizard.
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## Install OpenClaw Globally

```bash
npm install -g openclaw@latest
```

npm will print warnings about deprecated packages (`npmlog`, `gauge`, `inflight`, `glob`, `rimraf`, `tar`). These are cosmetic warnings from transitive dependencies and can be safely ignored -- they do not affect OpenClaw's functionality.

If the install fails on `@discordjs/opus` with `gyp ERR! not found: make`, go back to [Runtime Dependencies](runtime-deps.md) and install `build-essential` and `libopus-dev` first.

---

## Run the Onboarding Wizard

The `--install-daemon` flag sets up the systemd user service automatically, so the gateway starts on boot and restarts on failure.

```bash
openclaw onboard --install-daemon
```

During the wizard, set the following values:

| Setting | Value |
|:--------|:------|
| Workspace | `~/.openclaw/workspace` |
| LLM provider | Anthropic (Claude Opus 4.6) -- provide your API key |
| Gateway port | `18789` |
| Gateway bind | `127.0.0.1` |
| Tailscale | Off |

{: .warning }
> When asked for the gateway bind address, you **MUST** enter `127.0.0.1`. Entering `0.0.0.0` exposes your agent to the entire internet. The gateway can execute shell commands, modify files, and send messages -- treat it like root SSH access.

---

## Verify the Daemon

After onboarding completes, check that everything is healthy:

```bash
openclaw doctor
openclaw status
```

Both commands should report no errors. If `openclaw doctor` flags an issue, address it before proceeding to the next step.

---

## What `openclaw doctor` Checks

| Check | What it verifies |
|:------|:-----------------|
| systemd lingering | User services persist after logout |
| Node.js version | >= 22.12.0 |
| Gateway bind | `127.0.0.1` (not `0.0.0.0`) |
| Gateway port | `18789` reachable on localhost |
| Workspace | `~/.openclaw/workspace` exists |

---

## Key Configuration File

The main config is at `~/.openclaw/openclaw.json`. You can view current settings with:

```bash
openclaw config
```

This file controls the LLM provider, memory search settings, gateway port and bind address, and channel configuration. Most values are set during onboarding, but you can edit the file directly or use `openclaw config set` to change them later.

---

{: .claude }
> Copy this into Claude Code:
> ```
> Install OpenClaw globally with npm, then run the onboarding wizard
> with --install-daemon. Use these settings:
> - Workspace: ~/.openclaw/workspace
> - LLM provider: Anthropic (Claude Opus 4.6)
> - Gateway port: 18789
> - Gateway bind: 127.0.0.1 (NEVER 0.0.0.0)
> - Tailscale: Off
> After onboarding, run openclaw doctor and openclaw status to verify.
> ```
