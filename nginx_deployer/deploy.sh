#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# deploy.sh — Deploy a random-template nginx site for a given domain.
#
# Usage:
#   ./deploy.sh <domain>            # e.g. ./deploy.sh example.com
#   ./deploy.sh <domain> --dry-run  # preview without applying changes
#
# Requirements: nginx, sudo privileges
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }

# ── Parse arguments ───────────────────────────────────────────────────────────
DOMAIN="${1:-}"
DRY_RUN=false

[[ -z "$DOMAIN" ]] && error "Domain not specified.\nUsage: $0 <domain> [--dry-run]"
shift

for arg in "$@"; do
  [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
done

# ── Paths ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"
WEB_ROOT="/var/www/${DOMAIN}"
NGINX_CONF="/etc/nginx/sites-available/${DOMAIN}"
NGINX_LINK="/etc/nginx/sites-enabled/${DOMAIN}"

# ── Pick a random template ────────────────────────────────────────────────────
mapfile -t TEMPLATES < <(find "$TEMPLATES_DIR" -maxdepth 1 -name "*.html" | sort)

[[ ${#TEMPLATES[@]} -eq 0 ]] && error "No HTML templates found in: $TEMPLATES_DIR"

TEMPLATE="${TEMPLATES[RANDOM % ${#TEMPLATES[@]}]}"
TEMPLATE_NAME="$(basename "$TEMPLATE")"

echo ""
echo -e "${BOLD}═══════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  nginx deployer${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════════${RESET}"
echo ""
info "Domain   : ${BOLD}$DOMAIN${RESET}"
info "Template : ${BOLD}$TEMPLATE_NAME${RESET}"
info "Web root : $WEB_ROOT"
info "Config   : $NGINX_CONF"
$DRY_RUN && warn "DRY RUN — no changes will be made"
echo ""

# ── Helpers ───────────────────────────────────────────────────────────────────
run() {
  if $DRY_RUN; then
    echo -e "  ${YELLOW}[dry-run]${RESET} $*"
  else
    eval "$@"
  fi
}

# ── Check dependencies ────────────────────────────────────────────────────────
command -v nginx &>/dev/null || error "nginx is not installed. Run: sudo apt install nginx"

# ── 1. Create web root ────────────────────────────────────────────────────────
info "Creating web root..."
run "sudo mkdir -p \"$WEB_ROOT\""
success "Directory ready: $WEB_ROOT"

# ── 2. Render template (replace {{DOMAIN}} placeholder) ──────────────────────
info "Rendering template '$TEMPLATE_NAME' → index.html..."

RENDERED_HTML="$(sed "s/{{DOMAIN}}/$DOMAIN/g" "$TEMPLATE")"

if $DRY_RUN; then
  warn "Would write rendered HTML to $WEB_ROOT/index.html"
else
  echo "$RENDERED_HTML" | sudo tee "$WEB_ROOT/index.html" > /dev/null
fi

success "index.html written."

# ── 3. Set permissions ────────────────────────────────────────────────────────
info "Setting permissions..."
run "sudo chown -R www-data:www-data \"$WEB_ROOT\""
run "sudo chmod -R 755 \"$WEB_ROOT\""
success "Permissions set."

# ── 4. Write nginx server block ───────────────────────────────────────────────
info "Writing nginx config..."

NGINX_CONFIG="server {
    listen 80;
    listen [::]:80;

    server_name $DOMAIN www.$DOMAIN;

    root $WEB_ROOT;
    index index.html;

    access_log /var/log/nginx/${DOMAIN}_access.log;
    error_log  /var/log/nginx/${DOMAIN}_error.log;

    location / {
        try_files \$uri \$uri/ =404;
    }

    # Security headers
    add_header X-Frame-Options \"SAMEORIGIN\" always;
    add_header X-Content-Type-Options \"nosniff\" always;
    add_header Referrer-Policy \"no-referrer-when-downgrade\" always;

    # Gzip
    gzip on;
    gzip_types text/html text/css application/javascript;
}"

if $DRY_RUN; then
  warn "Would write nginx config to $NGINX_CONF"
  echo ""
  echo -e "${YELLOW}── Preview of nginx config ──${RESET}"
  echo "$NGINX_CONFIG"
  echo ""
else
  echo "$NGINX_CONFIG" | sudo tee "$NGINX_CONF" > /dev/null
fi

success "Config written."

# ── 5. Enable site ────────────────────────────────────────────────────────────
info "Enabling site..."

if ! $DRY_RUN; then
  if [[ -L "$NGINX_LINK" ]]; then
    warn "Symlink already exists: $NGINX_LINK — skipping."
  else
    sudo ln -s "$NGINX_CONF" "$NGINX_LINK"
    success "Symlink created."
  fi
else
  warn "Would create symlink: $NGINX_LINK → $NGINX_CONF"
fi

# ── 6. Test & reload nginx ────────────────────────────────────────────────────
info "Testing nginx config..."

if $DRY_RUN; then
  warn "Would run: sudo nginx -t && sudo systemctl reload nginx"
else
  sudo nginx -t 2>&1 | sed 's/^/  /'
  sudo systemctl reload nginx
fi

echo ""
success "${BOLD}Deployment complete!${RESET}"
echo -e "  ${CYAN}http://$DOMAIN${RESET}"
echo ""
