---
layout: default
title: Claude Code Recipes
nav_order: 8
---

# Claude Code Recipes
{: .no_toc }

All prompts organized by deployment phase for copy-paste into Claude Code.
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## Overview

This page compiles all Claude Code prompts for each deployment phase. Copy any prompt below directly into Claude Code to automate that step. Each recipe is self-contained and can be run independently, or you can use the all-in-one prompt at the bottom to walk through the entire deployment in a single session.

---

## Phase 1: VPS Provisioning & Hardening

### Recipe 1 -- Initial Server Setup

```
I just provisioned a fresh Ubuntu 24.04 VPS. Please:
1. Update all packages
2. Set up UFW firewall: deny all incoming, allow outgoing, allow SSH only
3. Verify the firewall is active and port 18789 is NOT open
4. Create a non-root user called "deploy" with sudo access
```

---

## Phase 2: Runtime Dependencies

### Recipe 2 -- Install All Dependencies

```
Install all runtime dependencies on this Ubuntu 24.04 VPS:
1. build-essential and libopus-dev (needed for @discordjs/opus)
2. Node.js 22 via NVM (handle zsh compatibility if needed)
3. cloudflared from the latest GitHub .deb release
Verify each installation after completing it.
```

---

## Phase 3: Install OpenClaw

### Recipe 3 -- Install and Configure

```
Install OpenClaw globally via npm and run the onboarding wizard:
1. npm install -g openclaw@latest
2. Run openclaw onboard --install-daemon with these settings:
   - Workspace: ~/.openclaw/workspace
   - Gateway port: 18789
   - Gateway bind: 127.0.0.1 (NEVER 0.0.0.0)
   - Tailscale: Off
3. Verify with openclaw doctor and openclaw status
```

---

## Phase 4: Cloudflare Tunnel

### Recipe 4 -- Create Tunnel

```
Set up a Cloudflare Tunnel on this VPS:
1. Run cloudflared tunnel login (I'll handle the browser auth)
2. Create a tunnel named "openclaw-gateway"
3. Write ~/.cloudflared/config.yml with ingress rules for:
   - openclaw.YOURDOMAIN.COM → http://localhost:18789
   - ssh.YOURDOMAIN.COM → ssh://localhost:22
   - Catch-all: http_status:404
4. Route DNS for both hostnames
5. Install cloudflared as a systemd service and start it
6. Verify the tunnel is running
```

---

## Phase 5: Zero Trust Access

### Recipe 5 -- Configure Access (API)

```
Set up Cloudflare Zero Trust Access using the API:
- Account ID: YOUR_ACCOUNT_ID
- API Token: YOUR_CF_API_TOKEN
- Email to authorize: you@example.com

Create two Access applications:
1. "OpenClaw AI Gateway" on openclaw.YOURDOMAIN.COM
2. "SSH Access" on ssh.YOURDOMAIN.COM

For each, create an Allow policy restricted to my email.
Verify both return 302 redirects with curl -I.
```

---

## Phase 6: Agent Identity

### Recipe 6 -- Create Identity Files

```
Create the OpenClaw agent identity files in ~/.openclaw/workspace/:

1. SOUL.md — Agent constitution with:
   - Security boundary rules (no destructive commands, no exposed API keys)
   - Tool usage rules (require human approval for emails, financial transactions, file deletions)
   - Memory protocol (always search before asking clarifying questions)

2. USER.md — Operator profile with:
   - Language: English
   - Timezone: America/New_York
   - Output format: concise
   - Risk tolerance: conservative

3. MEMORY.md — Start empty, will be populated over time

4. HEARTBEAT.md — Start empty (no autonomous tasks yet)
```

---

## Phase 7: Memory Search

### Recipe 7 -- Enable Hybrid Search

```
Enable hybrid memory search in OpenClaw:
1. Edit ~/.openclaw/openclaw.json and add memorySearch config:
   - enabled: true
   - provider: voyage
   - sources: ["memory", "sessions"]
   - indexMode: hot
   - minScore: 0.3
   - maxResults: 20
2. Restart the OpenClaw daemon
3. Verify the daemon restarted successfully
```

---

## Phase 8: Backup

### Recipe 8 -- Setup R2 Backup

```
Set up automated backups of ~/.openclaw/workspace to Cloudflare R2:
1. Install rclone
2. Help me configure an R2 remote (I'll provide the access keys)
3. Set up a cron job to sync every 6 hours with logging
4. Run an initial manual sync to verify
```

---

## Phase 9: Post-Install

### Recipe 9 -- Security & Testing

```
Finalize the OpenClaw deployment:
1. Install protection skills: skillguard and prompt-guard
2. Set file permissions:
   - chmod 600 ~/.openclaw/openclaw.json
   - chmod 600 ~/.cloudflared/*.json
   - chmod 700 ~/.openclaw/workspace
3. Run the full safety checklist:
   - openclaw doctor
   - sudo ufw status (verify port 18789 is NOT listed)
   - openclaw config (verify bind is 127.0.0.1)
   - systemctl status cloudflared
   - curl -I https://openclaw.YOURDOMAIN.COM (should get 302)
```

---

## Full Deployment (All-in-One)

A comprehensive single prompt that covers the entire deployment from start to finish.

```
I want to deploy OpenClaw on this fresh Ubuntu 24.04 VPS with
Cloudflare Zero Trust security. Walk me through the full setup:

1. System hardening (updates, UFW firewall)
2. Runtime dependencies (build-essential, Node.js 22 via NVM, cloudflared)
3. OpenClaw installation (npm install, onboard wizard with daemon)
4. Cloudflare Tunnel (create, configure, install as service)
5. Zero Trust Access (Access applications for gateway and SSH)
6. Agent identity (SOUL.md, USER.md, MEMORY.md, HEARTBEAT.md)
7. Hybrid memory search (Voyage provider)
8. R2 backup (rclone cron every 6 hours)
9. Security hardening (protection skills, file permissions, verification)

CRITICAL: Gateway must bind to 127.0.0.1 only. Never 0.0.0.0.
Never open port 18789 in the firewall.

My domain: YOURDOMAIN.COM
Subdomains: openclaw.YOURDOMAIN.COM and ssh.YOURDOMAIN.COM
```
