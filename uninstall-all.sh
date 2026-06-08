#!/bin/bash
# Xboard-Node Complete Hide Uninstall All for Debian/Ubuntu

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [ "$(id -u)" -ne 0 ]; then
    log_error "Please run as root (use sudo)"
    exit 1
fi

echo ""
echo "=============================================="
echo "  Xboard-Node Complete Hide Uninstall All"
echo "=============================================="
echo ""

INSTANCES=$(ls -d /var/run/.system-cache/* 2>/dev/null | while read dir; do basename "$dir"; done)

if [ -z "$INSTANCES" ]; then
    log_info "No instances found"
    exit 0
fi

log_warn "Found instances:"
for name in $INSTANCES; do
    log_warn "  - ${name}"
done
echo ""

printf "Uninstall all? (yes/NO): "
read confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

echo ""
log_info "Stopping services..."
systemctl stop 'xboard-node-*' 2>/dev/null

for name in $INSTANCES; do
    log_info "Removing ${name}..."
    systemctl stop "xboard-node-${name}" 2>/dev/null
    systemctl disable "xboard-node-${name}" 2>/dev/null

    WRAPPER_FILE="/var/run/.system-cache/${name}/wrapper"
    if [ -f "$WRAPPER_FILE" ]; then
        WRAPPER=$(cat "$WRAPPER_FILE")
        rm -f "/usr/local/bin/$WRAPPER" 2>/dev/null
    fi

    rm -f "/etc/systemd/system/xboard-node-${name}.service"
    rm -rf "/var/run/.system-cache/${name}"
    log_info "  Done: ${name}"
done

log_info "Removing binary..."
rm -f /usr/local/bin/kernel-update
rm -f /usr/local/bin/crond-worker /usr/local/bin/ssh-agent /usr/local/bin/system-logger /usr/local/bin/cache-manager /usr/local/bin/sync-daemon 2>/dev/null
systemctl daemon-reload

echo ""
echo "=============================================="
log_info "All instances uninstalled!"
echo "=============================================="