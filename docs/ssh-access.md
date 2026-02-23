---
layout: default
title: SSH via Zero Trust
nav_order: 3
parent: Security
---

# SSH via Zero Trust

## Overview

There are three ways to access your VPS over SSH without exposing any ports to the internet. All three route traffic through the Cloudflare Tunnel you already created, meaning port 22 stays closed in UFW and invisible to scanners.

| Option | Approach | Best for |
|:-------|:---------|:---------|
| **1** | Client-side `cloudflared` ProxyCommand | Single operator, from your own machines |
| **2** | Browser-based SSH terminal | Access from untrusted or borrowed devices |
| **3** | Short-lived certificates | Team access, audit requirements, zero key management |

---

## Option 1: Client-Side cloudflared ProxyCommand (Simplest)

Best for: **single operator, from your own machines.**

### Server side

The SSH ingress rule is already in `~/.cloudflared/config.yml`:

```yaml
- hostname: ssh.YOURDOMAIN.COM
  service: ssh://localhost:22
```

The Access policy was created in the previous step.

### Client side

Install `cloudflared` on your local machine, then add the following to `~/.ssh/config`:

```
Host ssh.YOURDOMAIN.COM
  ProxyCommand cloudflared access ssh --hostname %h
```

### Connect

```bash
ssh user@ssh.YOURDOMAIN.COM
```

A browser opens for identity verification. After auth, the SSH session proceeds transparently.

---

## Option 2: Browser-Based SSH Terminal (Zero Client Software)

Best for: **access from untrusted or borrowed devices.**

No local software is required -- Cloudflare renders a full terminal in your browser.

1. Go to **Access > Applications > your SSH app > Configure**.
2. Under **Browser rendering**, set the option to **SSH**.
3. Visit `https://ssh.YOURDOMAIN.COM` in any browser.
4. Authenticate through the Access policy (email OTP, SSO, etc.).
5. A terminal session renders directly in the browser.

---

## Option 3: Short-Lived Certificates (Eliminate SSH Keys)

Best for: **team access, audit requirements, zero key management.**

Instead of distributing long-lived SSH keys, Cloudflare issues short-lived certificates on every login. Keys are generated per session and expire automatically.

### Server side

#### a. Generate the CA

In the Cloudflare dashboard, navigate to **Access > Service credentials > SSH** and click **Generate SSH CA**. Copy the public key.

#### b. Save the CA on your server

```bash
echo "CA_PUBLIC_KEY" | sudo tee /etc/ssh/ca.pub
sudo chmod 600 /etc/ssh/ca.pub
```

Replace `CA_PUBLIC_KEY` with the actual public key from the dashboard.

#### c. Configure sshd

Edit `/etc/ssh/sshd_config` and add the following lines **at the top, before any `Include` directive**:

```
PubkeyAuthentication yes
TrustedUserCAKeys /etc/ssh/ca.pub
```

#### d. Reload SSH

```bash
sudo systemctl reload ssh
```

### Client side

Add the following to `~/.ssh/config`:

```
Match host ssh.YOURDOMAIN.COM exec "cloudflared access ssh-gen --hostname %h"
    ProxyCommand cloudflared access ssh --hostname %h
    IdentityFile ~/.cloudflared/ssh.YOURDOMAIN.COM-cf_key
    CertificateFile ~/.cloudflared/ssh.YOURDOMAIN.COM-cf_key-cert.pub
```

When you run `ssh user@ssh.YOURDOMAIN.COM`, `cloudflared` requests a short-lived certificate from Cloudflare, authenticates you via the Access policy, and the session proceeds without any permanent SSH keys on disk.

---

## Comparison Table

| Scenario | Recommendation |
|:---------|:---------------|
| Just you, from your own machines | **Option 1** -- simplest setup, one line in SSH config |
| Access from untrusted/borrowed devices | **Option 2** -- browser terminal, no client software |
| Team access, audit requirements | **Option 3** -- short-lived certs, zero key management |

---

{: .note-title }
> **Claude Code Prompt**
>
> Copy this into Claude Code:
> ```
> Set up SSH via Cloudflare Zero Trust for my VPS "openclaw":
> 1. Check if cloudflared is installed locally (cloudflared --version).
>    If not, install it (brew install cloudflared on macOS,
>    or download the .deb from GitHub releases for Linux).
> 2. On my local machine, add to ~/.ssh/config:
>    Host ssh.YOURDOMAIN.COM
>      ProxyCommand cloudflared access ssh --hostname %h
> 3. SSH into my VPS "openclaw" and verify the tunnel config
>    has the ssh.YOURDOMAIN.COM ingress rule pointing to
>    ssh://localhost:22
> 4. Print the command I should test manually:
>    ssh deploy@ssh.YOURDOMAIN.COM
>    (This opens a browser for Cloudflare Access auth —
>    I will run it myself outside Claude Code.)
> ```
