---
layout: default
title: VPS Provisioning
nav_order: 3
parent: Getting Started
---

# VPS Provisioning

This guide walks you through provisioning a minimal VPS for running OpenClaw. The gateway itself is lightweight --- it only orchestrates API calls and manages memory, so modest hardware is sufficient.

## Choose a Provider

| Feature | Hetzner CX22 | DigitalOcean Droplet |
|:--------|:-------------|:---------------------|
| **Price** | ~4 EUR/mo | $6/mo |
| **vCPU** | 2 | 1 (Basic) or 2 (Premium) |
| **RAM** | 4 GB | 1--2 GB |
| **Storage** | 40 GB NVMe | 25--50 GB SSD |
| **OS** | Ubuntu 24.04 LTS | Ubuntu 24.04 LTS |
| **Regions** | EU (Falkenstein, Nuremberg, Helsinki), US (Ashburn, Hillsboro) | Global (NYC, SFO, AMS, FRA, SGP, etc.) |
| **Latency** | Excellent for EU-based users | Good global coverage |
| **Billing** | Hourly, capped monthly | Hourly, capped monthly |

Both providers are well-suited for OpenClaw. **Hetzner** offers better value in Europe, while **DigitalOcean** provides broader geographic coverage. Pick whichever is closer to your primary LLM provider's API endpoints to minimize round-trip latency.

## Create the Server

1. Log in to your provider's dashboard.
2. Create a new server/droplet with the following settings:
   - **OS**: Ubuntu 24.04 LTS
   - **Plan**: 4 vCPU / 8 GB RAM recommended
   - **Region**: closest to you or your LLM provider
3. **Add your SSH public key** during creation. This avoids password-based authentication entirely.
4. Assign a hostname (e.g., `openclaw-vps`).
5. Launch the server and note the public IP address.

{: .note }
> If you do not already have an SSH key pair, generate one with `ssh-keygen -t ed25519` on your local machine before creating the server.

## Initial SSH Connection

Connect to your new server as root:

```bash
ssh root@YOUR_VPS_IP
```

Replace `YOUR_VPS_IP` with the public IPv4 address shown in your provider's dashboard. On first connection, you will be prompted to accept the server's host key fingerprint.

## System Update

Bring the system up to date immediately after first login:

```bash
sudo apt update && sudo apt upgrade -y
```

If the kernel was upgraded, reboot the server:

```bash
sudo reboot
```

Wait a minute, then reconnect via SSH.

## Create a Non-Root User

{: .note }
> This step is optional but strongly recommended. Running services as a non-root user limits the blast radius of any compromise.

Create a dedicated deployment user and grant it sudo privileges:

```bash
adduser deploy
usermod -aG sudo deploy
```

Copy your SSH key to the new user so you can log in directly:

```bash
rsync --archive --chown=deploy:deploy ~/.ssh /home/deploy
```

Verify you can connect as the new user from your local machine:

```bash
ssh deploy@YOUR_VPS_IP
```

Once confirmed, you can optionally disable root SSH login by setting `PermitRootLogin no` in `/etc/ssh/sshd_config` and restarting the SSH service.

## Configure UFW Firewall

This is the most critical step in the entire provisioning process. The firewall configuration is a foundational layer of the Zero Trust security model.

Set the default policies and allow only SSH:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw enable
```

Verify the rules are active:

```bash
sudo ufw status verbose
```

You should see output similar to:

```
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere
22/tcp (v6)                ALLOW IN    Anywhere (v6)
```

{: .warning }
> **Never open port 18789 in your firewall.** The entire security model relies on the gateway being accessible ONLY via Cloudflare Tunnel. An exposed gateway is worse than a compromised web app --- the agent can execute shell commands, modify files, and send emails.

{: .important }
> Port 18789 is intentionally absent from the UFW rules. The OpenClaw gateway binds to `127.0.0.1:18789` (loopback only), and external access is provided exclusively through a Cloudflare Tunnel. This means there are **zero inbound ports** serving the application --- even if an attacker scans your VPS, they will find nothing listening on the public interface except SSH.

---

Your VPS is now provisioned and hardened. Next, proceed to installing Node.js and OpenClaw.

---

{: .note-title }
> **Claude Code Prompt**
>
> Copy this into Claude Code:
> ```
> SSH into my new VPS "openclaw" and harden it:
> 1. Update all packages (apt update && apt upgrade -y)
> 2. Create a non-root user "deploy" with sudo access
> 3. Set up UFW firewall: deny all incoming, allow outgoing,
>    allow SSH (port 22). Enable the firewall.
> 4. Verify UFW is active and port 18789 is NOT open
> 5. Show me the final firewall rules
> ```
