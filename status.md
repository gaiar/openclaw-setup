# Project Status

**Date**: 2026-02-22

## Target Architecture

```
Browser/Client
      |
      v
Cloudflare Access (email OTP gate)
      |
      v
Cloudflare Tunnel (encrypted, outbound-only)
      |
      v
192.168.0.14 (mini PC, local network)
  ├── agent.baimuratov.app → OpenClaw gateway (localhost:18789)
  └── ssh.baimuratov.app   → SSH (localhost:22, browser-rendered terminal)
```

## What's Done

| Item | Status | Notes |
|------|--------|-------|
| OpenClaw host (192.168.0.14) | Running | Mini PC on local network |
| `cloudflared` installed + authenticated | Done | Locally-managed tunnel, `config.yml` on host |
| Tunnel created (`cloudflared tunnel create`) | Done | UUID + credentials JSON on host |
| DNS record `agent.baimuratov.app` | Created | In Cloudflare DNS |
| Domain `baimuratov.app` | Active | Cloudflare-managed zone |
| API token created | Done | Tunnel R/W, Access Edit, DNS Edit, Zone Read |
| `setup-zero-trust.sh` script | Written | Automates Access app + policy + DNS + remote config |
| `guide.md` | Written | Full deployment guide with SSH options |
| `report.md` | Written | Research document |
| `CLAUDE.md` | Written | Project context for AI assistants |

## What's Left

### 1. Run setup-zero-trust.sh (agent.baimuratov.app)

The script failed on step 3 (`/accounts` endpoint returned empty). **Fixed** — now derives Account ID from the zone response instead.

```bash
cd ~/developer/openclaw-setup
./setup-zero-trust.sh
```

This will:
- Verify the API token
- Get Account ID + Zone ID from zone lookup
- List tunnels for selection
- Create/verify DNS CNAME `agent.baimuratov.app` → `<tunnel-id>.cfargotunnel.com`
- Create Access Application + Allow policy (email OTP for `gaiar@baimuratov.app`)
- SSH into 192.168.0.14 to add ingress rule and restart cloudflared

### 2. Set up web-based SSH (ssh.baimuratov.app)

After `agent.baimuratov.app` is working, set up browser-based SSH access. Three sub-tasks:

#### 2a. Tunnel ingress rule (on 192.168.0.14)

Add to `~/.cloudflared/config.yml` on the host (before the catch-all):

```yaml
  - hostname: ssh.baimuratov.app
    service: ssh://localhost:22
```

Then restart cloudflared.

#### 2b. DNS + Access Application + Policy

Same pattern as the gateway — either extend `setup-zero-trust.sh` or run manually:

1. Create CNAME: `ssh.baimuratov.app` → `<tunnel-id>.cfargotunnel.com` (proxied)
2. Create Access Application: "SSH Access", domain `ssh.baimuratov.app`, type `self_hosted`
3. Create Allow policy: email include `gaiar@baimuratov.app`

#### 2c. Enable browser rendering (dashboard only)

This step **cannot** be done via API — it requires the Cloudflare dashboard:

1. Go to **Zero Trust > Access > Applications**
2. Click the SSH Access application
3. **Settings** (or **Configure**) > **Browser rendering** > set to **SSH**
4. Save

After this, visiting `https://ssh.baimuratov.app` in any browser will:
- Show the Cloudflare Access OTP login page
- After authentication, render a full SSH terminal in the browser
- No client software needed

### 3. Verify everything

```bash
# Gateway — should return 302 to Cloudflare Access login
curl -I https://agent.baimuratov.app

# SSH — same 302 redirect (browser rendering serves terminal after auth)
curl -I https://ssh.baimuratov.app

# Tunnel health on the host
ssh gaiar@192.168.0.14 'systemctl status cloudflared'
ssh gaiar@192.168.0.14 'cloudflared tunnel ingress validate'
```

### 4. Remaining guide phases (post Zero Trust)

These are independent of the tunnel/access setup:

| Phase | Description | Priority |
|-------|-------------|----------|
| Phase 6 | Agent identity files (SOUL.md, USER.md, etc.) | After gateway works |
| Phase 7 | Hybrid memory search (Voyage embeddings) | After gateway works |
| Phase 8 | R2 backup (rclone cron) | After gateway works |
| Phase 9 | Protection skills + channel connections | After gateway works |

## Execution Order

```
1. Run ./setup-zero-trust.sh          ← next action
2. Verify agent.baimuratov.app works
3. Add SSH ingress + Access app (extend script or manual)
4. Enable browser rendering in dashboard
5. Verify ssh.baimuratov.app works
6. Proceed with guide phases 6–9
```
