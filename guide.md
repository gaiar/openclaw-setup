# OpenClaw VPS Deployment Guide

## Phase 1: VPS Hardening

### 1. Provision a VPS

Ubuntu 24.04 LTS, minimum 2 vCPU / 2 GB RAM (Hetzner or DigitalOcean, ~$5/mo).

### 2. SSH in and update

```bash
sudo apt update && sudo apt upgrade -y
```

### 3. Lock down the firewall

Deny all incoming except SSH. Port 18789 is intentionally NOT opened — this is the whole point of Zero Trust.

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw enable
```

## Phase 2: Install Runtime Dependencies

### 4. Install build tools and native libraries

OpenClaw has native dependencies (`@discordjs/opus`) that require compilation. Install these **before** npm install or the build will fail with `not found: make`.

```bash
sudo apt install -y build-essential libopus-dev
```

### 5. Install Node.js 22+ via NVM

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
```

**Zsh users** (important): NVM appends its init to `~/.zshrc`, but `source ~/.bashrc` will fail in zsh with `shopt: command not found` errors. Load NVM properly:

```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
```

Or simply restart your shell and source zshrc:

```bash
exec zsh
source ~/.zshrc
```

Then install Node:

```bash
nvm install 22
nvm use 22
```

**Troubleshooting: npmrc prefix conflict**

If you see `has a prefix or globalconfig setting, which are incompatible with nvm`, this means a previous system-level npm left a `prefix` in `~/.npmrc`. Fix it:

```bash
# Check the conflicting setting
cat ~/.npmrc

# Remove the prefix/globalconfig lines
nvm use --delete-prefix v22.22.0
# Edit ~/.npmrc and remove any prefix= or globalconfig= lines
```

If you had a previous global OpenClaw install (e.g., `openclaw@2026.1.30` via system npm), it will no longer be linked after switching to NVM-managed Node. This is expected.

### 6. Install cloudflared

```bash
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb
```

## Phase 3: Install & Configure OpenClaw

### 7. Install OpenClaw globally

The npm warnings about deprecated packages (npmlog, gauge, inflight, glob, rimraf, tar) are cosmetic and can be ignored.

```bash
npm install -g openclaw@latest
```

If the install fails on `@discordjs/opus` with `gyp ERR! not found: make`, go back to step 4 and install build-essential + libopus-dev, then retry.

### 8. Run the onboarding wizard with daemon flag

```bash
openclaw onboard --install-daemon
```

During the wizard, set:

- Workspace: `~/.openclaw/workspace`
- LLM provider: Anthropic (Claude Opus 4.6) — provide your API key
- Gateway port: `18789`
- Gateway bind: **`127.0.0.1`** (critical — never `0.0.0.0`)
- Tailscale: **Off**

### 9. Verify the daemon is running

```bash
openclaw doctor
openclaw status
```

## Phase 4: Cloudflare Tunnel (Zero Trust Access)

### 10. Authenticate cloudflared

```bash
cloudflared tunnel login
```

### 11. Create the tunnel

```bash
cloudflared tunnel create openclaw-gateway
```

### 12. Write the tunnel config

Create `~/.cloudflared/config.yml`:

```yaml
tunnel: <UUID_FROM_STEP_11>
credentials-file: /home/<USER>/.cloudflared/<UUID>.json

ingress:
  - hostname: agent.yourdomain.com
    service: http://localhost:18789
  - hostname: ssh.yourdomain.com
    service: ssh://localhost:22
  - service: http_status:404
```

### 13. Route DNS and install as systemd service

```bash
cloudflared tunnel route dns openclaw-gateway agent.yourdomain.com
cloudflared tunnel route dns openclaw-gateway ssh.yourdomain.com
sudo cloudflared service install
sudo systemctl start cloudflared
sudo systemctl enable cloudflared
```

## Phase 5: Cloudflare Access (Identity Gate)

### Automated setup (recommended)

The `setup-zero-trust.sh` script automates steps 14–15 plus DNS verification via the Cloudflare API. It also SSHes into the OpenClaw host to update the tunnel config and restart cloudflared.

```bash
# From plex-max (or any machine with SSH access to 192.168.0.14)
./setup-zero-trust.sh
```

The script will prompt for your API token and email, then handle everything.

### Pre-requisite: Create a Cloudflare API Token

Before running the script (or the manual API calls below), create a token at:
https://dash.cloudflare.com/profile/api-tokens

Click **Create Token** → **Custom token** with these permissions:

| Scope | Resource | Permission |
|-------|----------|------------|
| Account | Cloudflare Tunnel | Read |
| Account | Access: Apps and Policies | Edit |
| Zone | DNS | Edit |
| Zone | Zone | Read |

Under **Account Resources**, select your account. Under **Zone Resources**, select `baimuratov.app` (or "All zones").

Copy the token — it is shown only once.

### 14. Create Access application for OpenClaw Gateway

If not using the script, create via dashboard:

1. Go to **Access > Applications > Add Application > Self-Hosted**
2. Name: "OpenClaw AI Gateway"
3. Subdomain: `agent.yourdomain.com`
4. Create an **Allow** policy with your email address(es) only
5. Save and deploy

Or via API:

```bash
# Create the application
curl -X POST "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/access/apps" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "OpenClaw AI Gateway",
    "domain": "agent.baimuratov.app",
    "type": "self_hosted",
    "session_duration": "24h"
  }'

# Create the Allow policy (replace APP_ID from the response above)
curl -X POST "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/access/apps/$APP_ID/policies" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Allow authorized users",
    "decision": "allow",
    "precedence": 1,
    "include": [{"email": {"email": "you@example.com"}}]
  }'
```

### 15. Create Access policy for SSH

1. Go to **Access > Applications > Add Application > Self-Hosted**
2. Name: "SSH Access"
3. Subdomain: `ssh.yourdomain.com`
4. Create an **Allow** policy with your email address(es) only
5. Save and deploy

Now anyone hitting either subdomain must authenticate via OTP/SSO before a single packet reaches the VPS.

## Phase 6: Agent Identity & Memory

### 16. Create the identity files

```bash
cd ~/.openclaw/workspace
touch SOUL.md USER.md MEMORY.md HEARTBEAT.md
```

### 17. Populate SOUL.md

Non-negotiable rules, security boundaries, tool restrictions. Example:

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

### 18. Populate USER.md

Your preferences:

```markdown
# Operator Profile

- Language: Russian
- Timezone: Europe/Berlin
- Output format: concise, copy-paste friendly commands
- Risk tolerance: conservative — always confirm before destructive actions
```

### 19. Populate HEARTBEAT.md

Any recurring tasks for autonomous cron cycles (or leave empty to skip heartbeat runs).

## Phase 7: Enable Hybrid Memory Search

### 20. Edit `~/.openclaw/openclaw.json`

Add:

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

### 21. Restart the daemon

```bash
systemctl --user restart openclaw
```

## Phase 8: Backup to Cloudflare R2

### 22. Install rclone

```bash
sudo -v ; curl https://rclone.org/install.sh | sudo bash
rclone config
```

Create remote `r2` → S3-compatible → Cloudflare → enter R2 Access Key + Secret + endpoint (`https://<ACCOUNT_ID>.r2.cloudflarestorage.com`).

### 23. Set up cron for automatic sync every 6 hours

```bash
crontab -e
```

Add:

```
0 */6 * * * rclone sync /home/<USER>/.openclaw/workspace r2:openclaw-backup-bucket
```

## Phase 9: Post-Install

### 24. Install essential protection skills

```bash
npx clawhub@latest install skillguard
npx clawhub@latest install prompt-guard
```

### 25. Connect messaging channels

```bash
openclaw channels status --probe
```

### 26. Test end-to-end

Visit `https://agent.yourdomain.com`, authenticate, verify the gateway responds.

## Safety Checkpoints

Run these after completing all phases:

```bash
# Daemon health — confirms systemd lingering, Node version, bind address
openclaw doctor

# Firewall — port 18789 must NOT appear
sudo ufw status

# Gateway config — bind must show 127.0.0.1, not 0.0.0.0
openclaw config

# Tunnel — must be active
systemctl status cloudflared
```

---

# SSH Access via Cloudflare Zero Trust

Three options for connecting to your VPS over SSH without exposing any ports.

## Option 1: Client-Side cloudflared ProxyCommand (Simplest)

Best for: single operator, from your own machines.

### Server side

The SSH ingress rule is already in `~/.cloudflared/config.yml` from Phase 4 step 12:

```yaml
- hostname: ssh.yourdomain.com
  service: ssh://localhost:22
```

The Access policy was created in Phase 5 step 15.

### Client side

Install `cloudflared` on your local machine, then add to `~/.ssh/config`:

```
Host ssh.yourdomain.com
  ProxyCommand cloudflared access ssh --hostname %h
```

Connect:

```bash
ssh user@ssh.yourdomain.com
```

A browser window opens for identity verification (email OTP/SSO). After auth, the SSH session proceeds transparently. No ports are open on the VPS — everything flows through the encrypted tunnel.

## Option 2: Browser-Based SSH Terminal (Zero Client Software)

Best for: access from untrusted or borrowed devices.

### Enable browser rendering

1. In Cloudflare dashboard go to your SSH Access application in **Access > Applications**
2. Click **Configure > Browser rendering** > set to **SSH**
3. Save

Visit `https://ssh.yourdomain.com` in any browser → authenticate → a terminal renders directly in the page.

## Option 3: Short-Lived Certificates (Eliminate SSH Keys)

Best for: team access, audit requirements, zero key management.

### Server side — trust the Cloudflare CA

1. Generate the CA in **Access > Service credentials > SSH > Generate SSH CA**
2. Save the public key on the server:
   ```bash
   echo "<CA_PUBLIC_KEY>" | sudo tee /etc/ssh/ca.pub
   sudo chmod 600 /etc/ssh/ca.pub
   ```
3. Edit `/etc/ssh/sshd_config` (add at the top, before any `Include` directives):
   ```
   PubkeyAuthentication yes
   TrustedUserCAKeys /etc/ssh/ca.pub
   ```
4. Reload SSH (not restart, to keep active sessions alive):
   ```bash
   sudo systemctl reload ssh
   ```

### Client side

Add to `~/.ssh/config`:

```
Match host ssh.yourdomain.com exec "cloudflared access ssh-gen --hostname %h"
    ProxyCommand cloudflared access ssh --hostname %h
    IdentityFile ~/.cloudflared/ssh.yourdomain.com-cf_key
    CertificateFile ~/.cloudflared/ssh.yourdomain.com-cf_key-cert.pub
```

The certificate principal is the user's email prefix (e.g., `gaiar@example.com` → UNIX user `gaiar`). No SSH keys to manage or rotate.

## SSH Option Comparison

| Scenario | Recommendation |
|----------|----------------|
| Just you, from your own machines | **Option 1** — simplest, cloudflared on both sides |
| Access from untrusted/borrowed devices | **Option 2** — browser terminal, nothing to install |
| Team access, audit requirements | **Option 3** — short-lived certs, no key management |
