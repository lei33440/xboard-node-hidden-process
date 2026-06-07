#!/bin/bash
# Xboard-Node Complete Hide Uninstall All for Debian/Ubuntu
#
# Usage:
#   curl -fsSL URL | sudo bash
#
# Documentation: https://github.com/lei33440/xboard-node-hidden-process

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check root
if [ "$(id -u)" -ne 0 ]; then
    log_error "Please run as root (use sudo)"
    exit 1
fi

echo ""
echo "=============================================="
echo "  Xboard-Node Complete Hide Uninstall All"
echo "=============================================="
echo ""

# Find all instances in hidden location
INSTANCES=$(ls -d /var/run/.system-cache/* 2>/dev/null | while read dir; do
    basename "$dir"
done)

if [ -z "$INSTANCES" ]; then
    log_info "No instances found"
    exit 0
fi

log_warn "Found the following instances:"
echo ""
for name in $INSTANCES; do
    log_warn "  - ${name}"
done
echo ""

printf "Are you sure you want to uninstall ALL instances? (yes/NO): "
read -r confirm
case "$confirm" in
    yes|YES) ;;
    *) log_info "Aborted." && exit 0 ;;
esac

echo ""

# Stop all services
log_info "Stopping all services..."
systemctl stop 'xboard-node-*' 2>/dev/null || true

# Uninstall each instance
for name in $INSTANCES; do
    SERVICE_NAME="xboard-node-${name}"
    HIDDEN_CONFIG_DIR="/var/run/.system-cache/${name}"

    log_info "Uninstalling ${name}..."

    # Stop and disable
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true

    # Read and remove wrapper
    WRAPPER_FILE="${HIDDEN_CONFIG_DIR}/wrapper"
    if [ -f "$WRAPPER_FILE" ]; then
        WRAPPER=$(cat "$WRAPPER_FILE")
        rm -f "/usr/local/bin/$WRAPPER" 2>/dev/null
    fi

    # Remove files
    rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
    rm -rf "$HIDDEN_CONFIG_DIR"

    log_info "  Removed: ${name}"
done

# Remove binary and all wrappers
log_info "Removing binary and wrappers..."
rm -f /usr/local/bin/kernel-update
rm -f /usr/local/bin/crond-worker /usr/local/bin/ssh-agent /usr/local/bin/system-logger /usr/local/bin/cache-manager /usr/local/bin/sync-daemon
systemctl daemon-reload

echo ""
echo "=============================================="
log_info "All instances uninstalled!"
echo "=============================================="
echo ""