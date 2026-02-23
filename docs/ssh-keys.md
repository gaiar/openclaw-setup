---
layout: default
title: SSH Key Authentication
nav_order: 4
parent: Getting Started
---

# SSH Key Authentication
{: .no_toc }

Set up key-based SSH access, disable password login, and ensure you never get locked out.
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## Why Keys Instead of Passwords?

Password authentication is vulnerable to brute-force attacks. Every VPS with password login enabled sees thousands of automated login attempts per day. SSH keys eliminate this attack surface entirely — only someone with your private key file can connect.

---

## Step 1: Generate an SSH Key Pair

Run this on your **local machine** (MacBook, Linux workstation — not the VPS).

### macOS

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```

When prompted:
- **File location**: press Enter to accept the default (`~/.ssh/id_ed25519`)
- **Passphrase**: enter a strong passphrase (recommended) or press Enter for none

This creates two files:

| File | What it is | Share it? |
|:-----|:-----------|:----------|
| `~/.ssh/id_ed25519` | Private key | **Never.** This stays on your machine only. |
| `~/.ssh/id_ed25519.pub` | Public key | Yes — this goes on every server you want to access. |

### Ubuntu / Linux

The command is identical:

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```

{: .note }
> If you already have a key pair at `~/.ssh/id_ed25519`, the command will ask whether to overwrite. Say **no** and use your existing key, or choose a different filename like `~/.ssh/id_ed25519_openclaw`.

### Verify your key exists

```bash
ls -la ~/.ssh/id_ed25519*
```

You should see both `id_ed25519` (private) and `id_ed25519.pub` (public).

---

## Step 2: Copy the Public Key to the VPS

### Option A: ssh-copy-id (easiest)

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@YOUR_VPS_IP
```

This appends your public key to `~/.ssh/authorized_keys` on the VPS. You will be prompted for the password one last time.

### Option B: Manual copy

If `ssh-copy-id` is not available (some macOS versions):

```bash
cat ~/.ssh/id_ed25519.pub | ssh user@YOUR_VPS_IP 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
```

### Option C: Paste during VPS creation

Most providers (Hetzner, DigitalOcean) let you paste your public key during server creation. Copy it with:

```bash
# macOS
cat ~/.ssh/id_ed25519.pub | pbcopy

# Linux
cat ~/.ssh/id_ed25519.pub | xclip -selection clipboard
```

---

## Step 3: Test Key-Based Login

**Before changing anything else**, verify that key login works:

```bash
ssh -i ~/.ssh/id_ed25519 user@YOUR_VPS_IP
```

If you get in without being asked for a password, the key is working.

{: .warning }
> **Do not proceed to Step 4 until this works.** If you disable password authentication before confirming key access, you will lock yourself out.

---

## Step 4: Disable Password Authentication

Once key login is confirmed, harden the SSH server on the VPS.

### Edit sshd_config

```bash
sudo nano /etc/ssh/sshd_config
```

Find and change (or add) these lines:

```
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM no
PermitRootLogin prohibit-password
```

| Setting | What it does |
|:--------|:-------------|
| `PasswordAuthentication no` | Disables password login entirely |
| `PubkeyAuthentication yes` | Enables key-based login (usually already yes) |
| `ChallengeResponseAuthentication no` | Disables keyboard-interactive auth (another password vector) |
| `UsePAM no` | Prevents PAM from re-enabling password auth |
| `PermitRootLogin prohibit-password` | Root can only login with keys, not passwords |

### Validate the config before reloading

```bash
sudo sshd -t
```

If this prints nothing, the config is valid. If it prints errors, fix them before continuing.

### Reload SSH

```bash
sudo systemctl reload ssh
```

{: .note }
> Use `reload` not `restart`. Reload applies the new config without dropping your current SSH session. If something goes wrong, your existing connection stays alive so you can fix it.

---

## Step 5: Verify Lockdown

**From a new terminal** (keep your existing session open as a safety net):

```bash
# This should work (key auth)
ssh -i ~/.ssh/id_ed25519 user@YOUR_VPS_IP

# This should fail (password auth disabled)
ssh -o PubkeyAuthentication=no user@YOUR_VPS_IP
```

The second command should return `Permission denied (publickey)`. If it still asks for a password, the config change did not take effect — check for duplicate or overriding settings in `/etc/ssh/sshd_config.d/`.

---

## Convenience: SSH Config File

Add an entry to `~/.ssh/config` on your local machine so you don't have to type the full command every time:

```
Host openclaw
    HostName YOUR_VPS_IP
    User deploy
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
```

Now you can connect with just:

```bash
ssh openclaw
```

---

## Using Claude Code to SSH to a Remote Machine

Claude Code can connect to your VPS and execute commands remotely. Add the SSH config entry above, then tell Claude Code:

```
SSH into my VPS at "openclaw" and check if the system is up to date.
```

Claude Code will use `ssh openclaw` which resolves via your `~/.ssh/config`. No password prompt — the key handles authentication.

For longer remote sessions, you can ask Claude Code to:

```
Connect to my VPS "openclaw" via SSH and:
1. Check system updates
2. Verify OpenClaw daemon status
3. Check Cloudflare tunnel health
4. Report back with the results
```

{: .note }
> Claude Code runs SSH commands via the Bash tool. Make sure your SSH key does **not** have a passphrase, or use `ssh-agent` to cache it — Claude Code cannot enter passphrases interactively.

### Add key to ssh-agent (if passphrase-protected)

```bash
# macOS (persists across reboots via Keychain)
ssh-add --apple-use-keychain ~/.ssh/id_ed25519

# Linux (lasts until logout)
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

---

## Bonus: Install fail2ban via Claude Code

Even with key-only auth, brute-force attempts still hit your SSH port and fill your logs. `fail2ban` automatically bans IPs after repeated failed login attempts.

{: .note-title }
> **Claude Code Prompt**
>
> Copy this into Claude Code on your Mac to remotely set up fail2ban:
> ```
> SSH into my VPS "openclaw" and set up fail2ban:
> 1. Install fail2ban (apt install fail2ban)
> 2. Create /etc/fail2ban/jail.local with an [sshd] section:
>    - enabled = true
>    - port = ssh
>    - maxretry = 5
>    - findtime = 10m
>    - bantime = 1h
> 3. Enable and start the fail2ban service
> 4. Verify it's running with: fail2ban-client status sshd
> 5. Show me the current jail status and ban count
> ```

This bans any IP that fails 5 login attempts within 10 minutes for 1 hour. Even though password auth is disabled, this catches bots hammering your SSH port and reduces log noise.

---

## What to Do If You Lose Access

### Scenario 1: Key file deleted or lost, password auth disabled

**You cannot SSH in.** Recovery options:

1. **VPS provider console** — Hetzner, DigitalOcean, and most providers offer a browser-based VNC/serial console in their dashboard. This bypasses SSH entirely.
   - Log in to your provider dashboard
   - Open the console for your server
   - Log in with your user password (this is local login, not SSH — `PasswordAuthentication no` only affects SSH)
   - Re-add your public key to `~/.ssh/authorized_keys` or re-enable password auth temporarily

2. **Recovery mode / rescue system** — Most providers let you boot into a rescue OS, mount your disk, and edit files:
   - Boot into rescue mode from the provider dashboard
   - Mount the root partition: `mount /dev/sda1 /mnt`
   - Edit: `nano /mnt/etc/ssh/sshd_config` — set `PasswordAuthentication yes`
   - Reboot into normal mode
   - SSH in with password, fix keys, re-disable password auth

3. **Snapshot restore** — If you have a VPS snapshot from before the lockout, restore it.

### Scenario 2: Key works but wrong user or permissions

SSH is strict about file permissions. Fix on the VPS:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chown -R $(whoami):$(whoami) ~/.ssh
```

### Scenario 3: Locked out of root, but non-root user works

SSH in as the non-root user, then:

```bash
sudo -i
# Fix root's authorized_keys or sshd_config as needed
```

### Scenario 4: Cloudflare Tunnel down, SSH via Zero Trust broken

If your Cloudflare Tunnel is down and you configured SSH only through Zero Trust (no direct SSH port open), you have two options:

1. **Temporarily open port 22** via the VPS provider's firewall/console (not UFW, since you can't reach UFW without SSH)
2. **Fix the tunnel** via the provider's VNC console

{: .warning }
> **Always keep VPS provider console access available.** It is your last-resort recovery path when SSH fails. Make sure you know your provider dashboard login credentials and that your account has 2FA set up.

---

## Safety Checklist

Before disabling password authentication, confirm **all** of these:

- [ ] SSH key pair generated on your local machine
- [ ] Public key copied to VPS `~/.ssh/authorized_keys`
- [ ] Key-based login tested and working from a new terminal
- [ ] VPS provider console access verified (log in to dashboard, find the console button)
- [ ] `~/.ssh/config` entry created for convenience
- [ ] ssh-agent running if key has a passphrase

Only then disable password auth and reload SSH.

---

{: .note-title }
> **Claude Code Prompt**
>
> Copy this into Claude Code:
> ```
> Harden SSH on my VPS at YOUR_VPS_IP:
> 1. Check if my SSH key is already in authorized_keys
> 2. Test that key-based login works
> 3. Disable password authentication in sshd_config
>    (PasswordAuthentication no, ChallengeResponseAuthentication no,
>    UsePAM no, PermitRootLogin prohibit-password)
> 4. Validate the config with sshd -t
> 5. Reload SSH (not restart, to keep my session alive)
> 6. Verify password login is rejected from a new connection
> ```
