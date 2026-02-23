---
layout: default
title: Prerequisites
nav_order: 1
parent: Getting Started
---

# Prerequisites
{: .no_toc }

Everything you need before starting the OpenClaw VPS deployment.
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## Checklist

Before you begin, make sure you have the following:

- [ ] **VPS account** -- Hetzner or DigitalOcean recommended. The smallest tier (~$5/month) is sufficient: Ubuntu 24.04 LTS, 4 vCPU / 8 GB RAM recommended. While OpenClaw is a gateway (not an inference engine), native dependencies, embedding indexing, and multiple channel adapters benefit from headroom.

- [ ] **Domain name** -- Any registrar works (Namecheap, Porkbun, GoDaddy, etc.). You can also purchase a domain directly from [Cloudflare Registrar](https://www.cloudflare.com/products/registrar/) at cost, which simplifies DNS setup later.

- [ ] **Cloudflare account** -- The [free tier](https://www.cloudflare.com/plans/) is sufficient. You will use Cloudflare Tunnel and Cloudflare Access to secure the gateway behind Zero Trust, with no inbound ports exposed on your VPS.

- [ ] **LLM API key** -- Anthropic is recommended for Claude Opus 4.6, which is the most capable model for agentic workflows. Alternatively, an **Anthropic Max** subscription includes API access and Claude Code. OpenClaw also supports OpenAI, DeepSeek, Gemini, and OpenRouter if you prefer a different provider.

- [ ] **SSH client on your local machine** -- You need to be able to SSH into your VPS. macOS and Linux ship with `ssh` built in. On Windows, use Windows Terminal with OpenSSH, PuTTY, or WSL.

- [ ] **Claude Code** *(optional but recommended)* -- This guide provides copy-paste prompts you can feed directly to Claude Code for each deployment step. It is not required; every step also includes manual instructions you can run yourself.

---

## Estimated costs

| Item | Cost | Notes |
|:-----|:-----|:------|
| VPS (Hetzner/DigitalOcean) | ~$5/month | Smallest shared CPU tier is enough |
| Domain name | ~$10/year | Varies by TLD and registrar |
| Cloudflare (Tunnel + Access) | Free | Free tier covers everything in this guide |
| LLM API (Anthropic, OpenAI, etc.) | Pay-per-use | Depends on usage; expect $5--$50/month for moderate use |
| Anthropic Max (alternative) | $100--$200/month | Includes API access and Claude Code; replaces separate API key |

**Total fixed cost**: roughly **$6/month** (VPS + amortized domain).

---

## Time estimate

The full setup -- from a fresh VPS to a working, secured OpenClaw deployment -- takes approximately **1 hour**. This includes:

- VPS provisioning and initial hardening (~10 min)
- Node.js and OpenClaw installation (~10 min)
- Cloudflare Tunnel and Zero Trust configuration (~15 min)
- Agent identity files and memory setup (~15 min)
- Verification and first conversation (~10 min)

---

## What you will end up with

By the end of this guide, you will have:

- A **fully autonomous AI agent** running on your own VPS, managed as a systemd service that starts on boot and restarts on failure.
- **Cloudflare Zero Trust** protecting the gateway -- no ports are exposed to the public internet. All traffic flows through an outbound-only encrypted tunnel to Cloudflare's edge network.
- **Identity-aware access control** via Cloudflare Access, so only your authorized email addresses can reach the agent.
- **Messaging channel support** ready to connect WhatsApp, Telegram, Slack, Discord, Signal, and more.
- **Persistent memory** with hybrid semantic and lexical search, backed by Markdown files and SQLite vector storage.

The gateway binds exclusively to `127.0.0.1:18789` and is never directly reachable from the internet. Even if the Cloudflare layer were bypassed, the port is not open in the firewall.

---

{: .note-title }
> **Claude Code Prompt**
>
> Copy this into Claude Code:
> ```
> I'm preparing to deploy OpenClaw on a VPS. Help me verify
> I have everything ready:
> 1. Check if I can SSH into my VPS: ssh openclaw
> 2. Verify the OS: cat /etc/os-release (should be Ubuntu 24.04)
> 3. Check resources: free -h and nproc (need 2+ vCPU, 2+ GB RAM)
> 4. Confirm I have a Cloudflare API token ready
> 5. Confirm I have an LLM API key (Anthropic recommended)
> Report what's ready and what's missing.
> ```
