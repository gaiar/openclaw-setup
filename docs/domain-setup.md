---
layout: default
title: Domain & Cloudflare Setup
nav_order: 2
parent: Getting Started
---

# Domain & Cloudflare Setup

Before deploying OpenClaw behind Cloudflare Zero Trust, you need a domain and a Cloudflare account. This guide walks you through registering a domain, onboarding it to Cloudflare, planning your subdomains, and creating an API token for automation.

---

## 1. Register a Domain

If you do not already own a domain, register one from any ICANN-accredited registrar. Recommended options:

| Registrar | Notes |
|:----------|:------|
| **Cloudflare Registrar** | Cheapest option -- at-cost pricing with zero markup. Requires a Cloudflare account first. |
| **Namecheap** | Popular, competitive pricing, free WHOIS privacy. |
| **Google Domains** | Clean UI, transparent pricing (now transitioning to Squarespace Domains). |
| **Porkbun** | Low prices, free WHOIS privacy, good developer experience. |

{: .important }
> If you register through Cloudflare Registrar, your nameservers are already set correctly and you can skip the nameserver update step in Section 3.

---

## 2. Create a Cloudflare Account

1. Go to [dash.cloudflare.com](https://dash.cloudflare.com) and click **Sign Up**.
2. Create an account with your email and a strong password.
3. The **Free plan** is sufficient for everything in this guide -- Cloudflare Tunnel, Access, and DNS are all included at no cost.

---

## 3. Add Your Site to Cloudflare

1. In the Cloudflare dashboard, click **Add a Site**.
2. Enter your domain name (e.g., `YOURDOMAIN.COM`).
3. Select the **Free** plan when prompted.
4. Cloudflare will scan your existing DNS records. Review and confirm them.
5. Cloudflare will provide two nameservers (e.g., `ada.ns.cloudflare.com` and `bob.ns.cloudflare.com`).
6. Log in to your domain registrar and **replace the existing nameservers** with the Cloudflare nameservers.
7. Wait for propagation -- this typically takes a few minutes but can take up to 24 hours.
8. Once active, Cloudflare will show your domain status as **Active**.

{: .note }
> Nameserver propagation usually completes within 15-30 minutes, but DNS caching at various levels can delay full propagation up to 24 hours.

---

## 4. Plan Your Subdomains

You will need two subdomains for your OpenClaw deployment. The DNS records for these will be created **automatically** when you set up the Cloudflare Tunnel later -- you do not need to create them manually now.

| Subdomain | Purpose |
|:----------|:--------|
| `openclaw.YOURDOMAIN.COM` | Gateway access (WebSocket + HTTP on port 18789) |
| `ssh.YOURDOMAIN.COM` | SSH access (remote terminal via Cloudflare Zero Trust) |

{: .note }
> These are just suggestions. You can use any subdomain names you prefer (e.g., `agent.YOURDOMAIN.COM`, `shell.YOURDOMAIN.COM`). Just be consistent when configuring the tunnel and Access policies later.

---

## 5. Create an API Token

An API token allows automation tools (including `cloudflared` and scripts) to manage your Cloudflare resources programmatically.

1. Navigate to [dash.cloudflare.com/profile/api-tokens](https://dash.cloudflare.com/profile/api-tokens).
2. Click **Create Token**.
3. Select **Create Custom Token** (at the bottom).
4. Configure the following permissions:

   | Scope | Resource | Permission |
   |:------|:---------|:-----------|
   | Account | Cloudflare Tunnel | Read |
   | Account | Access: Apps and Policies | Edit |
   | Zone | DNS | Edit |
   | Zone | Zone | Read |

5. Under **Zone Resources**, select **Include -- Specific zone -- YOURDOMAIN.COM** (or **All zones** if you prefer).
6. Click **Continue to summary**, then **Create Token**.
7. **Copy the token immediately** -- it will not be shown again.

{: .warning }
> Store your API token securely. Never commit it to version control. Use environment variables or a secrets manager to reference it in scripts.

---

{: .note-title }
> **Claude Code Prompt**
>
> Copy this into Claude Code:
> ```
> Help me set up Cloudflare for my domain YOURDOMAIN.COM:
> 1. Verify the domain is added and active in Cloudflare
> 2. Create an API token with permissions for Tunnel (Read),
>    Access Apps & Policies (Edit), DNS (Edit), Zone (Read)
> 3. Save the token securely
> ```

---

## Next Steps

With your domain active on Cloudflare and an API token ready, you can proceed to setting up the Cloudflare Tunnel and Zero Trust Access policies for your OpenClaw gateway.
