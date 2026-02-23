# OpenClaw VPS Deployment & Zero Trust Setup

## Project Overview

This project contains configuration, scripts, and documentation for deploying **OpenClaw** — an open-source persistent AI agent framework — on a VPS with Cloudflare Zero Trust security.

OpenClaw is NOT an inference engine. It is a **gateway/orchestration daemon** that routes messages, manages memory, and coordinates tool execution. All LLM inference happens externally via API calls (Anthropic Claude Opus 4.6, OpenAI, DeepSeek, Gemini, OpenRouter, etc.).

## About OpenClaw

- **Creator**: Peter Steinberger (Austrian developer, joined OpenAI on Feb 14, 2026; project transitioning to open-source foundation)
- **License**: MIT
- **Language**: TypeScript (Swift for macOS/iOS apps)
- **Repo**: https://github.com/openclaw/openclaw
- **Docs**: https://docs.openclaw.ai/ (Mintlify-hosted)
- **npm**: https://www.npmjs.com/package/openclaw (versioning: `YYYY.M.D`)
- **Stars**: 199,000+ (fastest to 100k in GitHub history)
- **Discord**: https://discord.gg/clawd (13,000+ members)

### Name History

| Name | Dates | Reason |
|------|-------|--------|
| Clawdbot | Nov 2025 — Jan 27, 2026 | Original name (pun on Claude + claw) |
| Moltbot | Jan 27 — Jan 30, 2026 | Anthropic trademark complaint |
| OpenClaw | Jan 30, 2026 — present | Final name; lobster theme preserved |

## Target Infrastructure

| Parameter | Value |
|-----------|-------|
| VPS Provider | Hetzner or DigitalOcean |
| OS | Ubuntu 24.04 LTS |
| Min specs | 2 vCPU, 2 GB RAM |
| Runtime | Node.js 22+ (`engines.node: ">=22.12.0"`) |
| Package manager | pnpm (preferred), also supports Bun and npm |
| Gateway port | 18789 (localhost only) |
| Gateway bind | `127.0.0.1` (NEVER `0.0.0.0`) |
| Process manager | systemd user service (Linux) / launchd (macOS) |

## Repository Structure

```
openclaw/
  src/
    cli/                  # CLI wiring
    commands/             # Command implementations
    provider-web.ts       # Web provider
    infra/                # Infrastructure
    media/                # Media pipeline
    telegram/             # Telegram channel (grammY)
    discord/              # Discord channel (discord.js)
    slack/                # Slack channel (@slack/bolt)
    signal/               # Signal channel (signal-cli)
    imessage/             # iMessage (legacy)
    web/                  # WhatsApp Web (@whiskeysockets/baileys)
    channels/             # Channel abstraction layer
    routing/              # Message routing
  dist/                   # Compiled JS output
  extensions/             # Plugin packages (workspace packages)
    msteams/              # Microsoft Teams
    matrix/               # Matrix
    zalo/                 # Zalo
    zalouser/             # Zalo Personal
    voice-call/           # Voice call
  apps/
    macos/                # macOS menu bar app (Swift)
    ios/                  # iOS app (Swift)
    android/              # Android app
  ui/                     # Web UI (Lit components)
  docs/                   # Documentation source
  scripts/                # Build and automation
  package.json
  pnpm-lock.yaml
  pnpm-workspace.yaml
  tsconfig.json
  AGENTS.md               # AI coding agent instructions
  VISION.md
```

## Key Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| `@whiskeysockets/baileys` | 7.0.0-rc.9 | WhatsApp Web protocol |
| `grammy` | ^1.39.3 | Telegram Bot API |
| `@slack/bolt` | ^4.6.0 | Slack integration |
| `discord-api-types` | ^0.38.37 | Discord integration |
| `playwright-core` | 1.58.0 | Browser automation |
| `sharp` | ^0.34.5 | Image processing |
| `sqlite-vec` | 0.1.7-alpha.2 | Vector search in SQLite |
| `hono` | 4.11.4 | HTTP framework |
| `ws` | ^8.19.0 | WebSocket server |
| `zod` | ^4.3.6 | Schema validation |
| `croner` | ^9.1.0 | Cron scheduling |
| `chromium-bidi` | 13.0.1 | Chrome DevTools Protocol |
| `commander` | ^14.0.2 | CLI framework |
| `node-edge-tts` | ^1.2.9 | Text-to-speech |

## Architecture

### How It Works

```
WhatsApp / Telegram / Slack / Discord / Google Chat / Signal /
iMessage / BlueBubbles / MS Teams / Matrix / Zalo / WebChat
               |
               v
+-------------------------------+
|           Gateway             |
|       (control plane)         |
|    ws://127.0.0.1:18789       |
+---------------+---------------+
                |
                +-- Pi agent (RPC)
                +-- CLI (openclaw ...)
                +-- WebChat UI
                +-- macOS / iOS / Android apps
```

### Core Subsystems

1. **Channel Adapters** — normalize messages from all platforms into a unified internal format; serialize model output back to platform-native format
2. **Session Manager** — identifies senders, manages conversation context, distinguishes DMs (merged into primary session) from group chats (multi-participant tracking)
3. **Queueing Mechanism** — holds incoming messages during active tool chains; decides whether to inject into current generation or queue for next turn; prevents race conditions
4. **Control Plane (Gateway)** — WebSocket RPC server + HTTP on port 18789; multiplexes both protocols on single port; CLI, desktop, mobile clients connect here
5. **Agent Runtime + Heartbeat Scheduler** — iterative cognitive loop (context assembly → LLM call → tool execution → repeat); heartbeat triggers every 30 min for proactive autonomous tasks

### DM Security: Pairing Mode

Default behavior for unknown senders: **pairing mode** — bot sends a short pairing code, does not process the message until approved via `openclaw pairing approve <channel> <code>`.

### Heartbeat Details

- Default interval: 30 minutes (60 min with Anthropic OAuth)
- Reads `HEARTBEAT.md` for pending tasks
- If response is only `HEARTBEAT_OK` (or content < 300 chars after removing token), response is silently discarded
- Configurable `activeHours` and timezone to prevent activity during off-hours

## Memory Architecture

Memory is **plain Markdown on disk**. Files are loaded at session start and injected into the system prompt.

### Core Memory Files

| File | Purpose | Mutability |
|------|---------|------------|
| `SOUL.md` | Behavioral core — voice, temperament, values, constraints, security protocols | Rarely changes |
| `USER.md` | Operator profile — name, timezone, work context, communication preferences | Updated as needed |
| `MEMORY.md` | Curated long-term facts — OS versions, architectural decisions, constraints | Keep compact |
| `HEARTBEAT.md` | Heartbeat daemon config and async task checklist | Volatile |
| `IDENTITY.md` | Agent presentation/persona | Stable |
| `AGENTS.md` | Agent instructions and mandatory execution steps | Stable |
| `TOOLS.md` | Tool capabilities documentation | Stable |
| `BOOT.md` / `BOOTSTRAP.md` | Startup instructions | Stable |
| `memory/YYYY-MM-DD.md` | Daily logs (raw event journal) | Append-only |

### Memory Tools

| Tool | Function |
|------|----------|
| `memory_search` | Semantic recall over indexed Markdown chunks (~400 token chunks, 80-token overlap) |
| `memory_get` | Read a specific Markdown file or line range |
| `memory_store` | Explicitly save facts |
| `memory_list` | View all stored memories |
| `memory_forget` | Delete memories |

### Hybrid Memory Search

Configured in `~/.openclaw/openclaw.json`:

```json
{
  "memorySearch": {
    "enabled": true,
    "provider": "voyage",
    "sources": ["memory", "sessions"],
    "indexMode": "hot",
    "minScore": 0.3,
    "maxResults": 20
  }
}
```

- **Semantic search** — dense vector embeddings (Voyage API, OpenAI, Gemini, Ollama/node-llama-cpp)
- **Lexical search (BM25)** — exact keyword matching for code, names, error messages
- **Blend ratio** — 70% semantic / 30% lexical
- **Storage** — SQLite with sqlite-vec at `~/.openclaw/memory/<agentId>.sqlite` (default); Milvus/Qdrant for enterprise
- **Optional QMD backend** — experimental local-first BM25 + vectors + reranking sidecar
- **Pre-compaction flush** — silent agentic turn writes critical findings to disk before context truncation
- **Embedding cache** — prevents re-vectorizing unchanged text (`indexMode: "hot"`)
- **Plugin alternative**: `@mem0/openclaw-mem0` with `"mode": "open-source"` for Qdrant/Milvus

## Messaging Channels

### Built-in

| Channel | Library/Protocol | Status |
|---------|-----------------|--------|
| WhatsApp | `@whiskeysockets/baileys` | Production |
| Telegram | `grammy` | Production |
| Slack | `@slack/bolt` | Production |
| Discord | `discord-api-types` / discord.js | Production |
| Signal | `signal-cli` | Production |
| iMessage | Legacy `imsg` / BlueBubbles | Production |
| Google Chat | Chat API | Production |
| WebChat | Built-in | Production |

### Extensions (plugins)

- Microsoft Teams (`extensions/msteams/`)
- Matrix (`extensions/matrix/`)
- Zalo (`extensions/zalo/`)
- Zalo Personal (`extensions/zalouser/`)
- Line (`@line/bot-sdk`)

## Security Model — Zero Trust

### Principles

1. **Loopback binding** — gateway listens ONLY on `127.0.0.1:18789`
2. **UFW firewall** — deny all incoming except SSH (port 22); port 18789 is NOT opened
3. **Cloudflare Tunnel** (`cloudflared`) — outbound-only encrypted connection to Cloudflare Edge; no inbound ports required
4. **Cloudflare Access** — identity-aware proxy with email OTP/SSO; JWT validation before any packet reaches the VPS

### Critical Security Rules

- **NEVER** bind gateway to `0.0.0.0` — this exposes the agent to the entire internet
- **NEVER** open port 18789 in UFW
- An exposed gateway is worse than a compromised web app — the agent can execute shell commands, modify files, send emails
- Install protection skills (`skillguard`, `prompt-guard`) as additional defense layers

### Known Security Concerns

OpenClaw has drawn significant security scrutiny:

- **Prompt injection** — susceptible to attacks embedding harmful instructions in data the agent processes
- **Malicious ClawHub skills** — Cisco AI security team found 341 skills performing data exfiltration; VirusTotal scanning now integrated
- **RCE vulnerability** — one-click remote code execution via malicious link was discovered and patched
- **Supply chain attack** — compromised npm token published malicious Cline CLI 2.3.0 that silently installed OpenClaw
- **Infostealer targeting** — malware observed targeting OpenClaw config files and gateway tokens

Security analyses from: Cisco, CrowdStrike, Bitsight, Sophos, 1Password, Aikido.

## Deployment Steps (Summary)

1. **VPS init** — Ubuntu 24.04, `apt update && upgrade`, UFW (deny incoming, allow SSH)
2. **Install deps** — Node.js 22 via NVM, `cloudflared` from GitHub releases
3. **Install OpenClaw** — `npm install -g openclaw@latest && openclaw onboard --install-daemon`
   - Bind: `127.0.0.1`, Port: `18789`, Tailscale: Off
4. **Cloudflare Tunnel** — `cloudflared tunnel create`, config at `~/.cloudflared/config.yml`, route DNS, install as systemd service
5. **Cloudflare Access** — create Self-Hosted app, Allow policy with authorized emails only
6. **Identity files** — create and populate `SOUL.md`, `USER.md`, `MEMORY.md`, `HEARTBEAT.md`
7. **Hybrid search** — enable `memorySearch` in `openclaw.json` (provider: voyage, minScore: 0.3, maxResults: 20)
8. **R2 backup** — configure `rclone` with Cloudflare R2, cron sync every 6 hours

## Skills Ecosystem — ClawHub

- **Registry**: https://clawhub.ai (repo: https://github.com/openclaw/clawhub)
- **SOUL.md templates**: https://onlycrabs.ai
- **Count**: 3,286+ skills (vetted via `clawskillshield` scanner + VirusTotal)
- **Tech stack**: TanStack Start (React), Convex backend, OpenAI embeddings for search

### Skill Format

Skills are a `SKILL.md` file with YAML frontmatter plus supporting files:

```yaml
---
name: my-skill
description: Does a thing with an API.
metadata:
  openclaw:
    requires:
      env:
        - MY_API_KEY
      bins:
        - curl
    primaryEnv: MY_API_KEY
---
```

### ClawHub CLI

```bash
clawhub login                 # Authenticate (GitHub OAuth)
clawhub search <query>        # Discover skills
clawhub explore               # Browse
clawhub install <slug>        # Install skill
clawhub uninstall <slug>      # Remove
clawhub list                  # List installed
clawhub update --all          # Update all
clawhub inspect <slug>        # View without installing
clawhub publish <path>        # Publish new skill
```

Install globally in `~/.openclaw/skills/` or per-workspace.

### Key Skills

- **GitHub** — OAuth, PRs, issues, code review, commits
- **AgentMail** — programmatic email infrastructure for agent identities
- **Linear / Monday** — project management via GraphQL
- **Playwright Scraper** — full browser automation with anti-bot bypass
- **Obsidian Direct** — markdown knowledge base with fuzzy search, tags, wiki-links

## Backup & Recovery

- **Tool**: `rclone` syncing to Cloudflare R2 (S3-compatible, zero egress fees)
- **Schedule**: cron every 6 hours
- **Path**: `~/.openclaw/workspace` → `r2:openclaw-backup-bucket`
- **Recovery**: provision new VPS → pull from R2 → restart daemon → full agent identity restored

## Key Config Files

| Path | Purpose |
|------|---------|
| `~/.openclaw/openclaw.json` | Main gateway config (memory search, LLM provider, ports) |
| `~/.openclaw/workspace/SOUL.md` | Agent constitution |
| `~/.openclaw/workspace/USER.md` | Operator preferences |
| `~/.openclaw/workspace/MEMORY.md` | Long-term curated facts |
| `~/.openclaw/workspace/HEARTBEAT.md` | Async task checklist |
| `~/.openclaw/workspace/AGENTS.md` | Agent instructions |
| `~/.openclaw/workspace/IDENTITY.md` | Agent persona |
| `~/.openclaw/memory/<agentId>.sqlite` | Vector search index |
| `~/.cloudflared/config.yml` | Cloudflare Tunnel routing |
| systemd user service | OpenClaw daemon auto-restart |

## CLI Reference

```bash
# Setup
openclaw onboard --install-daemon    # Guided setup wizard

# Gateway
openclaw gateway --port 18789        # Start gateway
openclaw doctor                      # Diagnose issues
openclaw status                      # Gateway status
openclaw dashboard                   # Open browser UI

# Agent
openclaw agent --message "..."       # Talk to agent
openclaw message send --to ...       # Send message

# Channels
openclaw channels status --probe     # Channel health
openclaw pairing approve <ch> <code> # Approve DM sender

# Config
openclaw config set ...              # Configuration
openclaw update --channel stable|beta|dev  # Switch update channels

# Daemon management
systemctl --user restart openclaw    # Restart after config changes
systemctl status cloudflared         # Verify tunnel status

# Backup
rclone sync ~/.openclaw/workspace r2:openclaw-backup-bucket

# Skills
clawhub install <skill-slug>         # Install a skill
clawhub list                         # List installed skills
```

## Dev Commands (for contributing to OpenClaw itself)

```bash
pnpm install           # Install deps
pnpm build             # Build (tsc + canvas bundling + copy scripts)
pnpm gateway:watch     # Dev loop with auto-reload
pnpm test              # Run tests (Vitest, 70% coverage threshold)
pnpm check             # Lint (Oxlint)
pnpm format            # Format (Oxfmt)
pnpm openclaw ...      # Run CLI in dev mode
```

## Related Projects

| Project | URL | Description |
|---------|-----|-------------|
| ClawHub | github.com/openclaw/clawhub | Official skill registry |
| nix-openclaw | github.com/openclaw/nix-openclaw | Nix flake for declarative config |
| ClawWork | github.com/HKUDS/ClawWork | "OpenClaw as Your AI Coworker" |
| secure-openclaw | github.com/ComposioHQ/secure-openclaw | Security-hardened fork |
| openclaw-mission-control | github.com/abhi1693/openclaw-mission-control | Multi-agent orchestration |
| ClawControl | github.com/ipenywis/clawcontrol | Third-party VPS deployment tool (Bun) |
| soul.md | github.com/aaronjmars/soul.md | Tool to build SOUL.md personality files |
| awesome-openclaw-skills | github.com/VoltAgent/awesome-openclaw-skills | Curated skill collection |

## Resources

- **Docs**: https://docs.openclaw.ai/
- **GitHub**: https://github.com/openclaw/openclaw
- **ClawHub**: https://clawhub.ai
- **Discord**: https://discord.gg/clawd
- **DeepWiki**: https://deepwiki.com/openclaw/openclaw
- **SOUL.md templates**: https://onlycrabs.ai
