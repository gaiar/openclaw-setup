---
layout: default
title: Claude Code Recipes
nav_order: 8
---

# Claude Code Recipes
{: .no_toc }

All prompts organized by deployment phase for copy-paste into Claude Code. Each recipe tells Claude Code to SSH into your VPS and perform the steps remotely.
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## Prerequisites

All recipes assume you have SSH access configured in `~/.ssh/config`:

```
Host openclaw
    HostName YOUR_VPS_IP
    User deploy
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
```

See [SSH Key Authentication](ssh-keys.md) for setup instructions.

---

## Phase 1: VPS Provisioning & Hardening

```
SSH into my VPS "openclaw" and harden it:
1. Update all packages (apt update && apt upgrade -y)
2. Create a non-root user "deploy" with sudo access
3. Set up UFW firewall: deny all incoming, allow outgoing,
   allow SSH (port 22). Enable the firewall.
4. Verify UFW is active and port 18789 is NOT open
5. Show me the final firewall rules
```

---

## Phase 2: SSH Hardening & fail2ban

```
SSH into my VPS "openclaw" and harden SSH:
1. Verify my SSH key is in authorized_keys
2. Disable password authentication in sshd_config:
   PasswordAuthentication no, ChallengeResponseAuthentication no,
   UsePAM no, PermitRootLogin prohibit-password
3. Validate config with sshd -t, then reload SSH (not restart)
4. Install fail2ban with an [sshd] jail:
   maxretry=5, findtime=10m, bantime=1h
5. Verify: fail2ban-client status sshd
```

---

## Phase 3: Runtime Dependencies

```
SSH into my VPS "openclaw" and install all runtime dependencies:
1. Install build-essential and libopus-dev
2. Install Node.js 22 via NVM (handle zsh compatibility)
3. Install cloudflared from the latest GitHub .deb release
4. Verify all installations: node --version, npm --version,
   cloudflared --version
```

---

## Phase 4: Install OpenClaw

```
SSH into my VPS "openclaw" and install OpenClaw:
1. Run: npm install -g openclaw@latest
2. Run the onboarding wizard: openclaw onboard --install-daemon
   Use these settings:
   - Workspace: ~/.openclaw/workspace
   - LLM provider: Anthropic (Claude Opus 4.6)
   - Gateway port: 18789
   - Gateway bind: 127.0.0.1 (CRITICAL: never 0.0.0.0)
   - Tailscale: Off
3. Verify with: openclaw doctor && openclaw status
```

---

## Phase 5: Cloudflare Tunnel

```
SSH into my VPS "openclaw" and set up a Cloudflare Tunnel:
1. Run: cloudflared tunnel login (I'll handle browser auth)
2. Create tunnel: cloudflared tunnel create openclaw-gateway
3. Write ~/.cloudflared/config.yml with ingress rules for:
   - openclaw.YOURDOMAIN.COM → http://localhost:18789
   - ssh.YOURDOMAIN.COM → ssh://localhost:22
   - Catch-all: http_status:404
4. Route DNS for both hostnames
5. Install as systemd service, start and enable it
6. Verify with: systemctl status cloudflared
```

---

## Phase 6: Zero Trust Access

```
Set up Cloudflare Zero Trust Access for my OpenClaw deployment.
My Cloudflare Account ID: YOUR_ACCOUNT_ID
My API token: YOUR_CF_API_TOKEN
My domain: YOURDOMAIN.COM
My email: you@example.com

1. Create Access app "OpenClaw AI Gateway" on openclaw.YOURDOMAIN.COM
2. Create Allow policy restricted to my email
3. Create Access app "SSH Access" on ssh.YOURDOMAIN.COM
4. Create Allow policy restricted to my email
5. Verify both with: curl -I https://openclaw.YOURDOMAIN.COM
   (should return 302 redirect to Cloudflare login)
6. SSH into my VPS "openclaw" and verify the tunnel is routing
   correctly: cloudflared tunnel ingress validate
```

---

## Phase 7: Agent Identity

```
SSH into my VPS "openclaw" and create the OpenClaw identity files:
1. Create files in ~/.openclaw/workspace/:
   SOUL.md, USER.md, MEMORY.md, HEARTBEAT.md
2. Populate SOUL.md with security boundaries:
   - Never execute destructive commands
   - Never expose API keys in logs
   - Require human approval for emails and file deletions
   - Always run memory_search before asking clarifying questions
3. Populate USER.md with my preferences:
   - Language: English
   - Timezone: (ask me)
   - Output format: concise
   - Risk tolerance: conservative
4. Leave MEMORY.md and HEARTBEAT.md empty for now
5. Restart the daemon: systemctl --user restart openclaw
```

---

## Phase 8: Memory Search

```
SSH into my VPS "openclaw" and enable hybrid memory search:
1. Edit ~/.openclaw/openclaw.json and add memorySearch config:
   enabled: true, provider: voyage, sources: ["memory", "sessions"],
   indexMode: hot, minScore: 0.3, maxResults: 20
2. Restart the daemon: systemctl --user restart openclaw
3. Verify it restarted: systemctl --user status openclaw
4. Check logs for memory indexing:
   journalctl --user -u openclaw --no-pager -n 20
```

---

## Phase 9: Messaging Channels

```
SSH into my VPS "openclaw" and help me connect a messaging channel.
I want to set up [Telegram / WhatsApp / Discord / Slack].
1. Walk me through creating the bot credentials on the platform
2. Add the credentials to ~/.openclaw/openclaw.json
3. Restart the daemon: systemctl --user restart openclaw
4. Verify with: openclaw channels status --probe
5. Test with: openclaw agent --message "Hello, can you hear me?"
```

---

## Phase 10: Backup to R2

```
SSH into my VPS "openclaw" and set up automated backups:
1. Install rclone
2. Configure an R2 remote named "r2" (I'll provide the access keys)
3. Create the R2 bucket if it doesn't exist:
   rclone mkdir r2:openclaw-backup-bucket
4. Verify the bucket is accessible: rclone lsd r2:
5. Set up a cron job to sync every 6 hours:
   rclone sync ~/.openclaw/workspace r2:openclaw-backup-bucket
   with logging to /tmp/rclone-openclaw.log
6. Run an initial manual sync to verify it works
7. Show me the cron entry and sync results
```

---

## Phase 11: Security Audit & Hardening

```
SSH into my VPS "openclaw" and run a full security audit:
1. Verify gateway binds to 127.0.0.1: openclaw config | grep bind
2. Verify UFW: sudo ufw status (port 18789 must NOT appear)
3. Verify tunnel: systemctl status cloudflared
4. Verify Access gate: curl -I https://openclaw.YOURDOMAIN.COM
   (should return 302)
5. Install protection skills:
   npx clawhub@latest install skillguard
   npx clawhub@latest install prompt-guard
6. Set file permissions:
   chmod 600 ~/.openclaw/openclaw.json
   chmod 600 ~/.cloudflared/*.json
   chmod 700 ~/.openclaw/workspace
7. Report back the results of each check
```

---

## Full Diagnostic

```
SSH into my VPS "openclaw" and run a full diagnostic:
1. openclaw doctor
2. openclaw status
3. openclaw config (check bind address is 127.0.0.1)
4. sudo ufw status
5. systemctl status cloudflared
6. systemctl --user status openclaw
7. openclaw channels status --probe
8. journalctl --user -u openclaw --no-pager -n 50
Report any issues found and suggest fixes.
```

---

## Full Deployment (All-in-One)

A single prompt that covers the entire deployment from start to finish.

```
My VPS is accessible via SSH as "openclaw" (in ~/.ssh/config).
SSH into "openclaw" and deploy OpenClaw with Cloudflare Zero Trust:

1. System hardening (updates, UFW firewall — deny all incoming,
   allow SSH only)
2. SSH hardening (disable password auth, PermitRootLogin
   prohibit-password, install fail2ban with sshd jail)
3. Runtime dependencies (build-essential, libopus-dev, Node.js 22
   via NVM, cloudflared)
4. OpenClaw installation (npm install -g openclaw@latest,
   onboard wizard with daemon, bind 127.0.0.1 port 18789)
5. Cloudflare Tunnel (create, configure ingress, route DNS,
   install as systemd service)
6. Zero Trust Access (Access applications for gateway and SSH,
   Allow policies for my email)
7. Agent identity (SOUL.md, USER.md, MEMORY.md, HEARTBEAT.md)
8. Hybrid memory search (Voyage provider, minScore 0.3)
9. Messaging channels (connect Telegram / WhatsApp / Discord /
   Slack — I'll specify which ones)
10. R2 backup (rclone cron every 6 hours)
11. Security hardening (protection skills, file permissions,
    full verification checklist)

CRITICAL: Gateway must bind to 127.0.0.1 only. Never 0.0.0.0.
Never open port 18789 in the firewall.

My domain: YOURDOMAIN.COM
Subdomains: openclaw.YOURDOMAIN.COM and ssh.YOURDOMAIN.COM
```
