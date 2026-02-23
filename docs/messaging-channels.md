---
layout: default
title: Messaging Channels
nav_order: 3
parent: Configuration
---

# Messaging Channels
{: .no_toc }

OpenClaw normalizes messages from all platforms into a unified internal format. Each channel has a dedicated adapter that translates platform-specific events into the common schema and serializes model output back to the native format.
{: .fs-6 .fw-300 }

---

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## Overview

OpenClaw supports a wide range of messaging platforms through its **channel adapter** architecture. Every incoming message -- whether from WhatsApp, Telegram, Slack, or any other supported platform -- is normalized into a unified internal format before being passed to the agent runtime. When the agent responds, the adapter serializes the output back into the platform's native format (rich embeds for Discord, markdown for Telegram, etc.).

This design means the agent logic is completely decoupled from any specific messaging platform. Adding a new channel requires only writing a new adapter, not modifying the core agent.

---

## Built-in Channels

These channels ship with the core OpenClaw package and are available immediately after installation.

| Channel | Library / Protocol | Status |
|:--------|:-------------------|:-------|
| WhatsApp | `@whiskeysockets/baileys` | Production |
| Telegram | `grammy` | Production |
| Slack | `@slack/bolt` | Production |
| Discord | `discord-api-types` / `discord.js` | Production |
| Signal | `signal-cli` | Production |
| iMessage | Legacy `imsg` / BlueBubbles | Production |
| Google Chat | Chat API | Production |
| WebChat | Built-in | Production |

---

## Extension Channels

These channels are maintained as separate plugin packages in the `extensions/` directory of the OpenClaw repository. Install them individually as needed.

- **Microsoft Teams** (`extensions/msteams/`)
- **Matrix** (`extensions/matrix/`)
- **Zalo** (`extensions/zalo/`)
- **Line** (`@line/bot-sdk`)

---

## Check Channel Status

Use the `--probe` flag to verify that all configured channels are connected and healthy:

```bash
openclaw channels status --probe
```

This command checks each enabled channel adapter, verifies authentication credentials, and reports connectivity status. Run it after initial setup or whenever a channel stops responding.

---

## DM Security: Pairing Mode

By default, OpenClaw uses **pairing mode** for unknown senders. When someone sends a direct message for the first time, the bot responds with a short pairing code and does **not** process the message. The operator must explicitly approve the sender before the agent will interact with them:

```bash
openclaw pairing approve <channel> <code>
```

Replace `<channel>` with the channel name (e.g., `telegram`, `whatsapp`) and `<code>` with the pairing code displayed to the sender.

{: .warning }
> **Do not disable pairing mode in production.** Without it, anyone who discovers your bot's identifier can interact with your agent. The agent has access to shell commands, files, and potentially API keys.

---

## Channel Setup Tips

Brief guidance for the most popular channels:

### Telegram

1. Create a bot via [@BotFather](https://t.me/BotFather) on Telegram.
2. Copy the bot token.
3. Add the token to your `~/.openclaw/openclaw.json` under the Telegram channel configuration.

### WhatsApp

1. WhatsApp uses the Baileys library, which implements the WhatsApp Web protocol.
2. On first run, a **QR code** is displayed in the terminal.
3. Scan the QR code with your WhatsApp mobile app to pair the session.

### Discord

1. Create an application at [discord.com/developers](https://discord.com/developers/applications).
2. Add a bot to the application and copy the bot token.
3. Invite the bot to your server using the OAuth2 URL generator with the appropriate scopes and permissions.
4. Add the token to your OpenClaw configuration.

### Slack

1. Create a new app at [api.slack.com](https://api.slack.com/apps).
2. Configure the required OAuth scopes for bot messaging.
3. Install the app to your workspace and copy the bot token.
4. Add the token to your OpenClaw configuration.

---

## Testing Channels

After configuring a channel, verify end-to-end connectivity by sending a test message through the agent CLI:

```bash
openclaw agent --message "Hello, can you hear me?"
```

If the agent responds, the gateway and agent runtime are working correctly. Then send a message through your configured channel to verify the full path from platform to agent and back.

{: .claude }
> Copy this into Claude Code:
> ```
> I have OpenClaw running on my VPS. Help me configure a new messaging
> channel. I want to connect [Telegram / WhatsApp / Discord / Slack].
> Walk me through creating the bot credentials, adding them to
> openclaw.json, and verifying the channel is working with
> openclaw channels status --probe.
> ```
