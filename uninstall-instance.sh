#!/bin/bash
# Xboard-Node Hidden Process Instance Uninstaller for Debian/Ubuntu
#
# Usage:
#   curl -fsSL URL | sudo bash -s -- --name INSTANCE
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

# Parse arguments
INSTANCE_NAME=""
WRAPPER_NAME=""

while [ $# -gt 0 ]; do
    case "$1" in
        --name) INSTANCE_NAME="$2"; shift 2;;
        --help) cat <<'HELP'
Xboard-Node Hidden Process Instance Uninstaller

Usage:
  curl -fsSL URL | sudo bash -s -- --name INSTANCE

Arguments:
  --name INSTANCE   Instance name to uninstall (required)
  --help            Show this help

Examples:
  curl -fsSL https://raw.githubusercontent.com/lei33440/xboard-node-hidden-process/main/uninstall-instance.sh | sudo bash -s -- --name mypanel

Documentation: https://github.com/lei33440/xboard-node-hidden-process
HELP
exit 0 ;;
        *) shift;;
    esac
done

# Validate arguments
if [ -z "$INSTANCE_NAME" ]; then
    log_error "Missing --name argument"
    exit 1
fi

SERVICE_NAME="xboard-node-${INSTANCE_NAME}"
CONFIG_DIR="/etc/xboard-node-${INSTANCE_NAME}"
LOG_DIR="/var/log/xboard-node"
BINARY_PATH="/usr/local/bin/xboard-node"
WRAPPER_FILE="${CONFIG_DIR}/wrapper"

echo ""
echo "=============================================="
echo "  Xboard-Node Hidden Process Uninstaller"
echo "=============================================="
echo ""
log_info "Uninstalling instance: ${INSTANCE_NAME}"
echo ""

# Check if instance exists
if [ ! -d "$CONFIG_DIR" ]; then
    log_error "Instance '${INSTANCE_NAME}' not found!"
    log_info "Available instances:"
    ls -d /etc/xboard-node-* 2>/dev/null | while read dir; do
        basename "$dir" | sed 's/^xboard-node-//'
    done
    exit 1
fi

# Read wrapper name
if [ -f "$WRAPPER_FILE" ]; then
    WRAPPER_NAME=$(cat "$WRAPPER_FILE")
fi

# Confirm uninstallation
log_warn "This will remove:"
log_warn "  - Service: ${SERVICE_NAME}"
log_warn "  - Config: ${CONFIG_DIR}"
log_warn "  - Logs: ${LOG_DIR}/${INSTANCE_NAME}.log"
[ -n "$WRAPPER_NAME" ] && log_warn "  - Wrapper: /usr/local/bin/${WRAPPER_NAME}"
echo ""

printf "Are you sure? (y/N): "
read -r confirm
case "$confirm" in
    y|Y) ;;
    *) log_info "Aborted." && exit 0 ;;
esac

# Stop and disable service
log_info "Stopping service..."
systemctl stop "$SERVICE_NAME" 2>/dev/null || true
systemctl disable "$SERVICE_NAME" 2>/dev/null || true

# Remove wrapper if exists
if [ -n "$WRAPPER_NAME" ] && [ -f "/usr/local/bin/${WRAPPER_NAME}" ]; then
    log_info "Removing wrapper: ${WRAPPER_NAME}"
    rm -f "/usr/local/bin/${WRAPPER_NAME}"
fi

# Remove files
log_info "Removing files..."
rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
rm -rf "$CONFIG_DIR"
rm -f "${LOG_DIR}/${INSTANCE_NAME}.log"
systemctl daemon-reload

# Check if any other instances exist
if [ ! "$(ls -A /etc/xboard-node-* 2>/dev/null)" ]; then
    log_info "No more instances, removing binary and manager..."
    rm -f "$BINARY_PATH"
    rm -f /usr/local/bin/service-manager
fi

echo ""
echo "=============================================="
log_info "Instance '${INSTANCE_NAME}' uninstalled!"
echo "=============================================="
echo ""