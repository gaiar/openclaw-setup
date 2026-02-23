#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# setup-zero-trust.sh — Cloudflare Zero Trust setup for OpenClaw gateway
#
# Creates: DNS CNAME, Access Application + Policy, remote tunnel config
# Requires: curl, jq, ssh access to the OpenClaw host
# =============================================================================

DOMAIN="baimuratov.app"
SUBDOMAIN="agent"
FQDN="${SUBDOMAIN}.${DOMAIN}"
OPENCLAW_PORT=18789
REMOTE_HOST="192.168.0.14"
REMOTE_USER="gaiar"
CF_API="https://api.cloudflare.com/client/v4"

# --- Colors ----------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
step()  { echo -e "\n${BOLD}=== Step $1: $2 ===${NC}"; }

# --- Helper: Cloudflare API call -------------------------------------------
cf_api() {
    local method="$1" endpoint="$2"
    shift 2
    curl -sS -X "$method" \
        "${CF_API}${endpoint}" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json" \
        "$@"
}

# --- Helper: Check API response success ------------------------------------
check_success() {
    local response="$1" context="$2"
    local success
    success=$(echo "$response" | jq -r '.success')
    if [[ "$success" != "true" ]]; then
        err "$context failed:"
        echo "$response" | jq -r '.errors[] | "  - \(.message)"' 2>/dev/null || echo "$response"
        exit 1
    fi
}

# =============================================================================
# Pre-flight checks
# =============================================================================

for cmd in curl jq ssh; do
    if ! command -v "$cmd" &>/dev/null; then
        err "Required command '$cmd' not found. Install it first."
        exit 1
    fi
done

# =============================================================================
# Step 1: Collect credentials
# =============================================================================
step 1 "Collect Cloudflare credentials"

if [[ -z "${CF_API_TOKEN:-}" ]]; then
    echo ""
    echo "You need a Cloudflare API token with these permissions:"
    echo ""
    echo "  Account | Cloudflare Tunnel     | Read"
    echo "  Account | Access: Apps & Policies| Edit"
    echo "  Zone    | DNS                   | Edit"
    echo "  Zone    | Zone                  | Read"
    echo ""
    echo "Create one at: https://dash.cloudflare.com/profile/api-tokens"
    echo ""
    read -rsp "Cloudflare API Token: " CF_API_TOKEN
    echo ""
fi

if [[ -z "${CF_EMAIL:-}" ]]; then
    read -rp "Your email (for Access policy): " CF_EMAIL
fi

if [[ -z "$CF_API_TOKEN" || -z "$CF_EMAIL" ]]; then
    err "Both API token and email are required."
    exit 1
fi

# =============================================================================
# Step 2: Verify token
# =============================================================================
step 2 "Verify API token"

response=$(cf_api GET "/user/tokens/verify")
check_success "$response" "Token verification"

token_status=$(echo "$response" | jq -r '.result.status')
if [[ "$token_status" != "active" ]]; then
    err "Token status is '$token_status', expected 'active'."
    exit 1
fi
ok "Token is valid and active."

# =============================================================================
# Step 3: Get Zone ID (and derive Account ID from it)
# =============================================================================
step 3 "Retrieve Zone ID for ${DOMAIN}"

response=$(cf_api GET "/zones?name=${DOMAIN}")
check_success "$response" "Zone lookup"

zone_count=$(echo "$response" | jq '.result | length')
if [[ "$zone_count" -eq 0 ]]; then
    err "Zone '${DOMAIN}' not found. Is it added to this Cloudflare account?"
    exit 1
fi

ZONE_ID=$(echo "$response" | jq -r '.result[0].id')
zone_status=$(echo "$response" | jq -r '.result[0].status')
ACCOUNT_ID=$(echo "$response" | jq -r '.result[0].account.id')
account_name=$(echo "$response" | jq -r '.result[0].account.name')

ok "Zone: ${DOMAIN} (${ZONE_ID}) — status: ${zone_status}"
ok "Account: ${account_name} (${ACCOUNT_ID})"

# =============================================================================
# Step 5: List tunnels and select one
# =============================================================================
step 4 "List Cloudflare Tunnels"

response=$(cf_api GET "/accounts/${ACCOUNT_ID}/cfd_tunnel?is_deleted=false&per_page=20")
check_success "$response" "Tunnel listing"

tunnel_count=$(echo "$response" | jq '.result | length')
if [[ "$tunnel_count" -eq 0 ]]; then
    err "No active tunnels found. Create one first with: cloudflared tunnel create <name>"
    exit 1
fi

echo ""
echo "Active tunnels:"
echo "$response" | jq -r '.result[] | "  [\(.id)] \(.name) (created: \(.created_at[:10]))"'
echo ""

if [[ "$tunnel_count" -eq 1 ]]; then
    TUNNEL_ID=$(echo "$response" | jq -r '.result[0].id')
    tunnel_name=$(echo "$response" | jq -r '.result[0].name')
    read -rp "Use tunnel '${tunnel_name}' (${TUNNEL_ID})? [Y/n] " confirm
    if [[ "${confirm,,}" == "n" ]]; then
        err "Aborted."
        exit 1
    fi
else
    read -rp "Enter Tunnel ID to use: " TUNNEL_ID
fi

TUNNEL_CNAME="${TUNNEL_ID}.cfargotunnel.com"
ok "Selected tunnel: ${TUNNEL_ID}"
info "CNAME target: ${TUNNEL_CNAME}"

# =============================================================================
# Step 6: Create or verify DNS CNAME
# =============================================================================
step 5 "DNS CNAME for ${FQDN}"

response=$(cf_api GET "/zones/${ZONE_ID}/dns_records?name=${FQDN}&type=CNAME")
check_success "$response" "DNS record lookup"

existing_count=$(echo "$response" | jq '.result | length')

if [[ "$existing_count" -gt 0 ]]; then
    existing_target=$(echo "$response" | jq -r '.result[0].content')
    record_id=$(echo "$response" | jq -r '.result[0].id')
    proxied=$(echo "$response" | jq -r '.result[0].proxied')

    if [[ "$existing_target" == "$TUNNEL_CNAME" && "$proxied" == "true" ]]; then
        ok "CNAME already exists and is correct: ${FQDN} → ${TUNNEL_CNAME} (proxied)"
    else
        warn "CNAME exists but points to '${existing_target}' (proxied=${proxied})"
        read -rp "Update it to point to ${TUNNEL_CNAME}? [Y/n] " confirm
        if [[ "${confirm,,}" != "n" ]]; then
            response=$(cf_api PUT "/zones/${ZONE_ID}/dns_records/${record_id}" \
                -d "{\"type\":\"CNAME\",\"name\":\"${SUBDOMAIN}\",\"content\":\"${TUNNEL_CNAME}\",\"proxied\":true,\"ttl\":1}")
            check_success "$response" "DNS record update"
            ok "Updated CNAME: ${FQDN} → ${TUNNEL_CNAME}"
        else
            warn "Skipping DNS update. The tunnel may not route correctly."
        fi
    fi
else
    info "Creating CNAME record: ${FQDN} → ${TUNNEL_CNAME}"
    response=$(cf_api POST "/zones/${ZONE_ID}/dns_records" \
        -d "{\"type\":\"CNAME\",\"name\":\"${SUBDOMAIN}\",\"content\":\"${TUNNEL_CNAME}\",\"proxied\":true,\"ttl\":1}")
    check_success "$response" "DNS record creation"
    ok "Created CNAME: ${FQDN} → ${TUNNEL_CNAME}"
fi

# =============================================================================
# Step 7: Create Cloudflare Access Application
# =============================================================================
step 6 "Cloudflare Access Application for ${FQDN}"

# Check if an Access app already exists for this domain
response=$(cf_api GET "/accounts/${ACCOUNT_ID}/access/apps")
check_success "$response" "Access apps listing"

existing_app_id=$(echo "$response" | jq -r --arg fqdn "$FQDN" \
    '.result[] | select(.domain == $fqdn) | .id' | head -1)

if [[ -n "$existing_app_id" ]]; then
    ok "Access application already exists for ${FQDN} (ID: ${existing_app_id})"
    APP_ID="$existing_app_id"
else
    info "Creating Access application..."
    response=$(cf_api POST "/accounts/${ACCOUNT_ID}/access/apps" \
        -d "{
            \"name\": \"OpenClaw AI Gateway\",
            \"domain\": \"${FQDN}\",
            \"type\": \"self_hosted\",
            \"session_duration\": \"24h\",
            \"auto_redirect_to_identity\": false,
            \"http_only_cookie_attribute\": true,
            \"same_site_cookie_attribute\": \"lax\"
        }")
    check_success "$response" "Access application creation"

    APP_ID=$(echo "$response" | jq -r '.result.id')
    ok "Created Access application: ${APP_ID}"
fi

# =============================================================================
# Step 7: Create Access Policy (Allow by email)
# =============================================================================
step 7 "Access Policy for ${CF_EMAIL}"

# Check if a policy already exists
response=$(cf_api GET "/accounts/${ACCOUNT_ID}/access/apps/${APP_ID}/policies")
check_success "$response" "Policy listing"

existing_policy=$(echo "$response" | jq -r \
    '.result[] | select(.name == "Allow authorized users") | .id' | head -1)

if [[ -n "$existing_policy" ]]; then
    ok "Policy already exists (ID: ${existing_policy})"
    info "Updating policy to ensure ${CF_EMAIL} is included..."
    response=$(cf_api PUT "/accounts/${ACCOUNT_ID}/access/apps/${APP_ID}/policies/${existing_policy}" \
        -d "{
            \"name\": \"Allow authorized users\",
            \"decision\": \"allow\",
            \"precedence\": 1,
            \"include\": [
                {
                    \"email\": {
                        \"email\": \"${CF_EMAIL}\"
                    }
                }
            ]
        }")
    check_success "$response" "Policy update"
    ok "Updated policy with email: ${CF_EMAIL}"
else
    info "Creating Allow policy..."
    response=$(cf_api POST "/accounts/${ACCOUNT_ID}/access/apps/${APP_ID}/policies" \
        -d "{
            \"name\": \"Allow authorized users\",
            \"decision\": \"allow\",
            \"precedence\": 1,
            \"include\": [
                {
                    \"email\": {
                        \"email\": \"${CF_EMAIL}\"
                    }
                }
            ]
        }")
    check_success "$response" "Policy creation"

    policy_id=$(echo "$response" | jq -r '.result.id')
    ok "Created Allow policy: ${policy_id} for ${CF_EMAIL}"
fi

# =============================================================================
# Step 9: Update tunnel config on remote host
# =============================================================================
step 8 "Update tunnel config on ${REMOTE_HOST}"

info "Connecting to ${REMOTE_USER}@${REMOTE_HOST} via SSH..."

# Build the remote script
read -r -d '' REMOTE_SCRIPT << 'REMOTE_EOF' || true
set -euo pipefail

CONFIG_FILE="$HOME/.cloudflared/config.yml"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: $CONFIG_FILE not found"
    exit 1
fi

echo "Current config.yml:"
cat "$CONFIG_FILE"
echo ""

# Check if the ingress rule already exists
if grep -q "FQDN_PLACEHOLDER" "$CONFIG_FILE"; then
    echo "Ingress rule for FQDN_PLACEHOLDER already exists. Skipping."
else
    echo "Adding ingress rule for FQDN_PLACEHOLDER..."

    # Insert the new ingress rule before the catch-all rule
    # The catch-all is: - service: http_status:404
    if grep -q "http_status:404" "$CONFIG_FILE"; then
        sed -i '/- service: http_status:404/i\  - hostname: FQDN_PLACEHOLDER\n    service: http://localhost:PORT_PLACEHOLDER' "$CONFIG_FILE"
        echo "Ingress rule added."
    else
        echo "WARNING: No catch-all rule found. Adding ingress section."
        cat >> "$CONFIG_FILE" << 'INGRESS'

ingress:
  - hostname: FQDN_PLACEHOLDER
    service: http://localhost:PORT_PLACEHOLDER
  - service: http_status:404
INGRESS
        echo "Ingress section appended."
    fi
fi

echo ""
echo "Updated config.yml:"
cat "$CONFIG_FILE"
echo ""

# Validate the config
echo "Validating tunnel config..."
cloudflared tunnel ingress validate 2>&1 || true

# Restart cloudflared
echo "Restarting cloudflared..."
if systemctl is-active --quiet cloudflared 2>/dev/null; then
    sudo systemctl restart cloudflared
    echo "cloudflared restarted (system service)."
elif systemctl --user is-active --quiet cloudflared 2>/dev/null; then
    systemctl --user restart cloudflared
    echo "cloudflared restarted (user service)."
else
    echo "WARNING: cloudflared service not found. You may need to restart it manually."
    echo "  Try: sudo systemctl restart cloudflared"
    echo "  Or:  cloudflared tunnel run <tunnel-name>"
fi

echo ""
echo "cloudflared status:"
systemctl status cloudflared --no-pager 2>/dev/null || systemctl --user status cloudflared --no-pager 2>/dev/null || echo "Could not determine service status."
REMOTE_EOF

# Substitute placeholders
REMOTE_SCRIPT="${REMOTE_SCRIPT//FQDN_PLACEHOLDER/$FQDN}"
REMOTE_SCRIPT="${REMOTE_SCRIPT//PORT_PLACEHOLDER/$OPENCLAW_PORT}"

ssh "${REMOTE_USER}@${REMOTE_HOST}" bash -s <<< "$REMOTE_SCRIPT"

ok "Remote configuration complete."

# =============================================================================
# Summary
# =============================================================================
echo ""
echo -e "${BOLD}============================================${NC}"
echo -e "${BOLD}  Setup Complete!${NC}"
echo -e "${BOLD}============================================${NC}"
echo ""
echo -e "  Domain:      ${GREEN}${FQDN}${NC}"
echo -e "  Tunnel ID:   ${TUNNEL_ID}"
echo -e "  Account ID:  ${ACCOUNT_ID}"
echo -e "  Zone ID:     ${ZONE_ID}"
echo -e "  Access App:  ${APP_ID}"
echo -e "  Auth email:  ${CF_EMAIL}"
echo ""
echo -e "${BOLD}Verification:${NC}"
echo ""
echo "  1. Test Access gate (should get 302 redirect to Cloudflare login):"
echo "     curl -I https://${FQDN}"
echo ""
echo "  2. Verify tunnel is running on remote host:"
echo "     ssh ${REMOTE_USER}@${REMOTE_HOST} 'systemctl status cloudflared'"
echo ""
echo "  3. Validate tunnel config:"
echo "     ssh ${REMOTE_USER}@${REMOTE_HOST} 'cloudflared tunnel ingress validate'"
echo ""
echo "  4. Open in browser (should see Cloudflare Access OTP page):"
echo "     https://${FQDN}"
echo ""
