---
layout: default
title: Runtime Dependencies
nav_order: 1
parent: Installation
---

# Runtime Dependencies

## Build Tools & Native Libraries

OpenClaw has native dependencies (`@discordjs/opus`) that require compilation. Install these **before** running `npm install` or it fails with `not found: make`.

```bash
sudo apt install -y build-essential libopus-dev
```

## Node.js 22+ via NVM

Install NVM, then Node 22:

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
```

{: .warning }
> **Zsh users**: NVM appends its init to `~/.zshrc`, but `source ~/.bashrc` will fail in zsh with `shopt: command not found`. Load NVM properly:
>
> ```bash
> export NVM_DIR="$HOME/.nvm"
> [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
> ```
>
> Or restart your shell: `exec zsh && source ~/.zshrc`

Then install Node:

```bash
nvm install 22
nvm use 22
```

## Troubleshooting: npmrc prefix conflict

If you see `has a prefix or globalconfig setting, which are incompatible with nvm`, a previous system-level npm left a prefix in `~/.npmrc`. Fix:

```bash
nvm use --delete-prefix v22.22.0
# Edit ~/.npmrc and remove any prefix= or globalconfig= lines
```

## Install cloudflared

Install from GitHub releases:

```bash
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb
```

## Verify installations

```bash
node --version    # Should show v22.x.x
npm --version     # Should show 10.x.x
cloudflared --version
```

{: .note-title }
> **Claude Code Prompt**
>
> Copy this into Claude Code:
> ```
> Install all runtime dependencies on this Ubuntu 24.04 VPS:
> 1. build-essential and libopus-dev
> 2. Node.js 22 via NVM
> 3. cloudflared from GitHub releases
> Verify each installation after completing it.
> ```
