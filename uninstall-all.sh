#!/bin/bash
# Xboard-Node Hidden Process Uninstall All for Debian/Ubuntu
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
echo "  Xboard-Node Hidden Process Uninstall All"
echo "=============================================="
echo ""

# Find all instances
INSTANCES=$(ls -d /etc/xboard-node-* 2>/dev/null | while read dir; do
    basename "$dir" | sed 's/^xboard-node-//'
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

# Collect all wrappers first
WRAPPERS=""
for dir in /etc/xboard-node-*; do
    if [ -f "$dir/wrapper" ]; then
        WRAPPERS="$WRAPPERS $(cat "$dir/wrapper")"
    fi
done

# Uninstall each instance
for name in $INSTANCES; do
    SERVICE_NAME="xboard-node-${name}"
    CONFIG_DIR="/etc/xboard-node-${name}"
    LOG_DIR="/var/log/xboard-node"

    log_info "Uninstalling ${name}..."

    # Stop and disable
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true

    # Remove wrapper
    if [ -f "$CONFIG_DIR/wrapper" ]; then
        WRAPPER=$(cat "$CONFIG_DIR/wrapper")
        rm -f "/usr/local/bin/$WRAPPER"
    fi

    # Remove files
    rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
    rm -rf "$CONFIG_DIR"
    rm -f "${LOG_DIR}/${name}.log"

    log_info "  Removed: ${name}"
done

# Remove binary and manager
log_info "Removing binary and manager..."
rm -f /usr/local/bin/xboard-node
rm -f /usr/local/bin/service-manager
systemctl daemon-reload

echo ""
echo "=============================================="
log_info "All instances uninstalled!"
echo "=============================================="
echo ""