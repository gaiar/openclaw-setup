---
layout: default
title: Zero Trust Access
nav_order: 2
parent: Security
---

# Zero Trust Access
{: .no_toc }

Create a Cloudflare Access application to enforce identity-aware authentication in front of your OpenClaw gateway and SSH.
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## What is Cloudflare Access?

Cloudflare Access is an **identity-aware proxy** that sits between users and your application. Every incoming request must pass an authentication check before it reaches your server. Without a valid session, the request never arrives at your VPS -- Cloudflare blocks it at the edge.

Access supports multiple identity providers out of the box:

| Method | Description |
|:-------|:------------|
| Email OTP | One-time passcode sent to an authorized email address (no IdP required) |
| Google | Google Workspace or personal Google account SSO |
| GitHub | GitHub OAuth SSO |
| SAML | Any SAML 2.0 compliant identity provider |
| OpenID Connect | Generic OIDC provider |

For a single-operator OpenClaw deployment, **email OTP** is the simplest option. It requires no external identity provider configuration -- Cloudflare sends a one-time code to your email, and you enter it to authenticate. The resulting JWT is then attached to all subsequent requests to your protected domain.

The key property: **no unauthenticated traffic ever reaches port 18789 on your VPS**. The Cloudflare Tunnel established in the previous step creates an outbound-only connection from your server. Cloudflare Access gates who can use that tunnel. Together, they form a zero-trust perimeter around your agent.

---

## Option A: Dashboard Setup (Manual)

This is the quickest way to create an Access application if you prefer a point-and-click workflow.

### Step 1: Open the Access Applications page

Navigate to the [Cloudflare Zero Trust dashboard](https://one.dash.cloudflare.com/) and go to **Access > Applications**.

### Step 2: Add a new application

Click **Add Application** and select **Self-Hosted**.

### Step 3: Configure the application

| Field | Value |
|:------|:------|
| Application name | `OpenClaw AI Gateway` |
| Subdomain | `openclaw` |
| Domain | `YOURDOMAIN.COM` |
| Session duration | `24h` |

### Step 4: Create an Allow policy

Add a policy with the following settings:

| Field | Value |
|:------|:------|
| Policy name | `Allow authorized users` |
| Action | Allow |
| Include rule | Emails -- `you@example.com` |

Replace `you@example.com` with your actual email address. You can add multiple emails or switch to a domain-based rule (e.g., allow all `@yourcompany.com` addresses) if needed.

### Step 5: Save and deploy

Click **Save**. Cloudflare Access will immediately begin enforcing authentication on `openclaw.YOURDOMAIN.COM`. Any unauthenticated request will be redirected to a Cloudflare login page.

---

## Option B: API Setup (Automatable)

If you prefer scripting your infrastructure or want to include Access configuration in a reproducible setup, use the Cloudflare API directly.

### Prerequisites

You need a Cloudflare API token with the permissions listed in the [API Token Permissions](#api-token-permissions) section below, and your Cloudflare Account ID (found on the Workers & Pages overview page or in the URL of the Zero Trust dashboard).

### Create the Access application

```bash
curl -X POST "https://api.cloudflare.com/client/v4/accounts/YOUR_ACCOUNT_ID/access/apps" \
  -H "Authorization: Bearer YOUR_CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "OpenClaw AI Gateway",
    "domain": "openclaw.YOURDOMAIN.COM",
    "type": "self_hosted",
    "session_duration": "24h"
  }'
```

The response includes an `id` field -- this is the **APP_ID** you need for the next step.

### Create the Allow policy

Replace `APP_ID` with the `id` value from the previous response:

```bash
curl -X POST "https://api.cloudflare.com/client/v4/accounts/YOUR_ACCOUNT_ID/access/apps/APP_ID/policies" \
  -H "Authorization: Bearer YOUR_CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Allow authorized users",
    "decision": "allow",
    "precedence": 1,
    "include": [{"email": {"email": "you@example.com"}}]
  }'
```

Replace `you@example.com` with your actual email address.

---

## Create SSH Access Application

Repeat the same process for your SSH subdomain. This protects browser-based SSH access (if configured) with the same identity-aware proxy.

### Dashboard method

Follow the same steps as Option A, but use these values:

| Field | Value |
|:------|:------|
| Application name | `OpenClaw SSH` |
| Subdomain | `ssh` |
| Domain | `YOURDOMAIN.COM` |
| Session duration | `24h` |

Create an identical Allow policy with your email address.

### API method

```bash
curl -X POST "https://api.cloudflare.com/client/v4/accounts/YOUR_ACCOUNT_ID/access/apps" \
  -H "Authorization: Bearer YOUR_CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "OpenClaw SSH",
    "domain": "ssh.YOURDOMAIN.COM",
    "type": "self_hosted",
    "session_duration": "24h"
  }'
```

Then create an Allow policy for the new SSH application using the same `curl` command as above, substituting the new `APP_ID`.

---

## API Token Permissions

If you use Option B (API setup), your Cloudflare API token must have the following permissions:

| Scope | Resource | Permission |
|:------|:---------|:-----------|
| Account | Cloudflare Tunnel | Read |
| Account | Access: Apps and Policies | Edit |
| Zone | DNS | Edit |
| Zone | Zone | Read |

To create this token:

1. Go to [Cloudflare API Tokens](https://dash.cloudflare.com/profile/api-tokens)
2. Click **Create Token**
3. Select **Custom token**
4. Add the four permission rows from the table above
5. Under **Zone Resources**, select **Specific zone** and choose your domain
6. Under **Account Resources**, select **Specific account** and choose your account
7. Click **Continue to summary**, then **Create Token**
8. Copy the token immediately -- it is only shown once

{: .warning }
> Store the API token securely. It has the ability to modify DNS records and Access policies for your domain. Never commit it to version control or include it in scripts that are shared publicly.

---

## Verify Access is Working

After creating the Access application (via either method), verify that unauthenticated requests are blocked:

```bash
curl -I https://openclaw.YOURDOMAIN.COM
```

You should see a **302 redirect** to the Cloudflare login page:

```
HTTP/2 302
location: https://openclaw.YOURDOMAIN.COM/cdn-cgi/access/login/openclaw.YOURDOMAIN.COM?...
```

If you see the redirect, Access is correctly intercepting requests. If you get a direct response from the gateway (or a connection error), double-check that:

1. The Cloudflare Tunnel is running and routing `openclaw.YOURDOMAIN.COM` to `localhost:18789`
2. The Access application domain matches the tunnel's public hostname exactly
3. The DNS record for `openclaw.YOURDOMAIN.COM` is proxied through Cloudflare (orange cloud icon)

To test full authentication, open `https://openclaw.YOURDOMAIN.COM` in a browser. You should be prompted for your email address, receive a one-time code, and then see the OpenClaw WebChat UI after entering the code.

---

{: .claude }
> Copy this into Claude Code to automate the API setup:
> ```
> Set up Cloudflare Access for my OpenClaw deployment using the API.
> My Cloudflare Account ID is <ACCOUNT_ID> and my API token is
> <CF_API_TOKEN>. My domain is <YOURDOMAIN.COM>.
>
> 1. Create a self-hosted Access application named "OpenClaw AI Gateway"
>    for subdomain openclaw.<YOURDOMAIN.COM> with 24h session duration
> 2. Create an Allow policy for the application with my email <EMAIL>
> 3. Repeat for an SSH application at ssh.<YOURDOMAIN.COM>
> 4. Verify both applications by checking for a 302 redirect with curl -I
>
> Show me the APP_IDs from each response so I can save them.
> ```
