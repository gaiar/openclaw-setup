---
layout: default
title: Troubleshooting
nav_order: 2
parent: Operations
---

# Troubleshooting
{: .no_toc }

Common issues and their solutions when deploying and operating OpenClaw on a VPS with Cloudflare Zero Trust.
{: .fs-6 .fw-300 }

<details open markdown="block">
  <summary>Table of contents</summary>
  {: .text-delta }
1. TOC
{:toc}
</details>

---

## NVM / Node.js Issues

### `shopt: command not found` when sourcing NVM in zsh

**Problem:** Running `source ~/.bashrc` in zsh triggers `shopt: command not found` errors because `shopt` is a bash-only builtin.

**Solution:** Do not source `~/.bashrc` in zsh. Instead, load NVM directly in your shell profile:

```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
```

Add these lines to `~/.zshrc` and reload with `source ~/.zshrc`.

---

### `prefix or globalconfig setting incompatible with nvm`

**Problem:** NVM refuses to switch Node versions because of conflicting npm configuration in `~/.npmrc`.

**Solution:** Remove the `prefix` and `globalconfig` lines from `~/.npmrc`, then re-select the Node version:

```bash
nvm use --delete-prefix v22.22.0
```

---

## OpenClaw Installation Failures

### `gyp ERR! not found: make` during npm install

**Problem:** Native addon compilation fails because build tools are not installed on the system.

**Solution:** Install the required build tools before running the OpenClaw installation:

```bash
sudo apt install -y build-essential libopus-dev
```

Then retry the installation with `npm install -g openclaw@latest`.

---

### npm deprecation warnings (npmlog, gauge, inflight, glob, rimraf, tar)

**Problem:** During installation, npm prints deprecation warnings for transitive dependencies.

**Solution:** These warnings are cosmetic and can be safely ignored. They do not affect the functionality of OpenClaw. The upstream packages will update these dependencies in future releases.

---

## Firewall Issues

### Can't access gateway externally

**Problem:** Attempting to reach the OpenClaw gateway from outside the VPS results in a connection timeout or refusal.

**Solution:** This is **by design**. The gateway binds to `127.0.0.1:18789` and is intentionally not exposed to the public internet. All external access must go through the Cloudflare Tunnel. Never open port 18789 in UFW:

- Do **not** run `sudo ufw allow 18789`
- Do **not** change the bind address to `0.0.0.0`

If you need external access, ensure your Cloudflare Tunnel and Access policies are properly configured.

---

## Tunnel Not Connecting

### cloudflared service fails to start

**Problem:** The `cloudflared` systemd service fails to start or enters a crash loop.

**Solution:** Check the service status, inspect logs, and validate the ingress configuration:

```bash
sudo systemctl status cloudflared
sudo journalctl -u cloudflared -f
cloudflared tunnel ingress validate
```

Common causes include missing or expired tunnel credentials, incorrect paths in the config file, or a malformed `config.yml`.

---

### "failed to connect to edge" errors

**Problem:** cloudflared logs show repeated "failed to connect to edge" messages.

**Solution:** This indicates an outbound connectivity issue. cloudflared requires outbound HTTPS access to Cloudflare's edge network. Verify connectivity:

```bash
curl -I https://api.cloudflare.com
```

If this fails, check:
- DNS resolution is working (`dig api.cloudflare.com`)
- No outbound firewall rules are blocking HTTPS (port 443)
- The VPS provider is not restricting outbound traffic

---

## Daemon Issues

### OpenClaw daemon crashes or doesn't start

**Problem:** The OpenClaw gateway daemon fails to start, crashes on launch, or exits unexpectedly.

**Solution:** Use the built-in diagnostic tools and systemd to investigate:

```bash
openclaw doctor
systemctl --user status openclaw
journalctl --user -u openclaw -f
```

Check the output of `openclaw doctor` for configuration errors, missing dependencies, or port conflicts.

---

### "systemd lingering not enabled"

**Problem:** The OpenClaw user service stops when you log out of the VPS because systemd terminates user services on logout by default.

**Solution:** Enable lingering for your user so that user services persist after logout:

```bash
loginctl enable-linger $USER
```

This allows `systemctl --user` services to run even when no active login session exists.

---

## Access / Authentication

### Getting 403 instead of login page

**Problem:** When navigating to the OpenClaw tunnel URL, you receive a 403 Forbidden error instead of the Cloudflare Access login page.

**Solution:** The 403 indicates that the Access policy is rejecting the request before authentication. Verify the following:

1. Open the Cloudflare dashboard and navigate to **Access > Applications**
2. Confirm your application exists and the domain matches
3. Check the **Allow** policy includes your email address or identity provider group
4. If using email OTP, ensure the email domain is permitted in the policy

---

## Memory Search

### memory_search returns no results

**Problem:** The `memory_search` tool returns empty results even though memory files exist in the workspace.

**Solution:** Verify that the embedding provider API key is correctly set in `~/.openclaw/openclaw.json` and that the memory search configuration is valid:

1. Check the `memorySearch` section in `~/.openclaw/openclaw.json` has `"enabled": true`
2. Confirm the provider API key (e.g., Voyage, OpenAI) is set as an environment variable
3. Restart the daemon to pick up configuration changes:

```bash
systemctl --user restart openclaw
```

If using the `voyage` provider, ensure the `VOYAGE_API_KEY` environment variable is available to the systemd service (set it in the service unit file or in `~/.openclaw/openclaw.json`).

---

## Useful Diagnostic Commands

Quick reference for common troubleshooting commands:

| Command | What it checks |
|:--------|:---------------|
| `openclaw doctor` | Overall health and configuration |
| `openclaw status` | Gateway status |
| `openclaw config` | Current configuration |
| `openclaw channels status --probe` | Channel connectivity |
| `systemctl status cloudflared` | Tunnel service |
| `sudo ufw status` | Firewall rules |
| `journalctl --user -u openclaw -f` | Daemon logs (live) |

---

{: .note-title }
> **Claude Code Prompt**
>
> Copy this into Claude Code:
> ```
> SSH into my VPS "openclaw" and run a full diagnostic:
> 1. openclaw doctor
> 2. openclaw status
> 3. openclaw config (check bind address is 127.0.0.1)
> 4. sudo ufw status
> 5. systemctl status cloudflared
> 6. systemctl --user status openclaw
> 7. openclaw channels status --probe
> 8. journalctl --user -u openclaw --no-pager -n 50
> Report any issues found and suggest fixes.
> ```
