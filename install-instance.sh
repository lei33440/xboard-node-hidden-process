#!/bin/bash
# Xboard-Node Hidden Process Multi-Panel Installer for Debian/Ubuntu
#
# Usage:
#   curl -fsSL URL | sudo bash -s -- --name INSTANCE --panel URL --token TOKEN --machine-id ID
#
# Documentation: https://github.com/lei33440/xboard-node-hidden-process

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

VERSION="1.0.0"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Check root
if [ "$(id -u)" -ne 0 ]; then
    log_error "Please run as root (use sudo)"
    exit 1
fi

# Check Debian/Ubuntu
if [ ! -f /etc/debian_version ]; then
    log_error "This script only supports Debian/Ubuntu"
    exit 1
fi

# Parse arguments
INSTANCE_NAME=""
PANEL_URL=""
TOKEN=""
MACHINE_ID=""
INSTALL_VERSION="latest"

while [ $# -gt 0 ]; do
    case "$1" in
        --name) INSTANCE_NAME="$2"; shift 2;;
        --panel) PANEL_URL="$2"; shift 2;;
        --token) TOKEN="$2"; shift 2;;
        --machine-id) MACHINE_ID="$2"; shift 2;;
        --version) INSTALL_VERSION="$2"; shift 2;;
        --help) cat <<'HELP'
Xboard-Node Hidden Process Installer v1.0.0 (Debian/Ubuntu)

Usage:
  curl -fsSL URL | sudo bash -s -- --name INSTANCE --panel URL --token TOKEN --machine-id ID

Arguments:
  --name NAME       Instance name (required, unique identifier)
  --panel URL       Panel URL (required)
  --token TOKEN     Auth token (required)
  --machine-id ID   Machine ID (required)
  --version VER     Xboard-Node version (default: latest)
  --help            Show this help

Features:
  - Hidden process name (randomized)
  - Multi-panel support
  - systemd service management

Examples:
  curl -fsSL https://raw.githubusercontent.com/lei33440/xboard-node-hidden-process/main/install-instance.sh | sudo bash -s -- \
    --name mypanel --panel http://panel.com --token xxx --machine-id 1

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
if [ -z "$PANEL_URL" ]; then
    log_error "Missing --panel argument"
    exit 1
fi
if [ -z "$TOKEN" ]; then
    log_error "Missing --token argument"
    exit 1
fi
if [ -z "$MACHINE_ID" ]; then
    log_error "Missing --machine-id argument"
    exit 1
fi

# Validate instance name (alphanumeric and hyphen only)
if [[ ! "$INSTANCE_NAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
    log_error "Instance name must contain only letters, numbers, and hyphens"
    exit 1
fi

# Paths
SERVICE_NAME="xboard-node-${INSTANCE_NAME}"
CONFIG_DIR="/etc/xboard-node-${INSTANCE_NAME}"
BINARY_PATH="/usr/local/bin/xboard-node"
LOG_DIR="/var/log/xboard-node"

# Banner
echo ""
echo "=============================================="
echo "  Xboard-Node Hidden Process Installer v${VERSION}"
echo "  (Debian/Ubuntu)"
echo "=============================================="
echo ""
log_info "Instance: ${INSTANCE_NAME}"
log_info "Panel: ${PANEL_URL}"
log_info "Machine ID: ${MACHINE_ID}"
echo ""

# Check if instance already exists
if [ -d "$CONFIG_DIR" ]; then
    log_warn "Instance '${INSTANCE_NAME}' already exists!"
    printf "Do you want to overwrite it? (y/N): "
    read -r confirm
    case "$confirm" in
        y|Y) log_info "Overwriting..." ;;
        *) log_info "Aborted." && exit 0 ;;
    esac
fi

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH_NAME="amd64" ;;
    aarch64|arm64) ARCH_NAME="arm64" ;;
    *) log_error "Unsupported architecture: $ARCH" && exit 1 ;;
esac
log_info "Architecture: $ARCH ($ARCH_NAME)"

# Install dependencies
log_step "Installing dependencies..."
apt-get update -qq >/dev/null 2>&1
apt-get install -y -qq curl ca-certificates >/dev/null 2>&1

# Create directories
mkdir -p "$CONFIG_DIR"
mkdir -p "$LOG_DIR"

# Download binary
if [ ! -f "$BINARY_PATH" ]; then
    log_step "Downloading xboard-node..."
    BASE="https://github.com/cedar2025/xboard-node/releases"
    if [ "$INSTALL_VERSION" = "latest" ]; then
        DOWNLOAD_URL="$BASE/latest/download/xboard-node-linux-$ARCH_NAME"
    else
        DOWNLOAD_URL="$BASE/download/$INSTALL_VERSION/xboard-node-linux-$ARCH_NAME"
    fi
    curl -fsSL -o "$BINARY_PATH" "$DOWNLOAD_URL" || {
        log_error "Failed to download xboard-node"
        exit 1
    }
    chmod +x "$BINARY_PATH"
    log_info "Binary downloaded"
else
    log_info "Binary exists, skipping"
fi

# Generate random process name
RANDOM_NAME="system-$(head /dev/urandom | tr -dc 'a-z0-9' | head -c 8)"
log_info "Hidden process name: ${RANDOM_NAME}"

# Create wrapper script with hidden process name
log_step "Creating hidden wrapper..."
cat > "/usr/local/bin/${RANDOM_NAME}" <<WRAPPER
#!/bin/bash
exec /usr/local/bin/xboard-node "\$@"
WRAPPER
chmod +x "/usr/local/bin/${RANDOM_NAME}"

# Save wrapper name to config
WRAPPER_PATH="/usr/local/bin/${RANDOM_NAME}"

# Create config
log_step "Creating configuration..."
INSTANCE_ID="$(echo "$PANEL_URL" | sed 's|https\?://||' | tr './' '-')-machine-${MACHINE_ID}-$(date +%s)"
cat > "$CONFIG_DIR/config.yml" <<EOF
instances:
    - id: ${INSTANCE_ID}
      panel:
        url: ${PANEL_URL}
      machine:
        machine_id: ${MACHINE_ID}
        token: ${TOKEN}
EOF

# Save wrapper info
echo "$WRAPPER_NAME" > "$CONFIG_DIR/wrapper"
log_info "Config: ${CONFIG_DIR}/config.yml"

# Create systemd service with hidden process name
log_step "Creating systemd service..."
cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=System Service - ${INSTANCE_NAME}
After=network.target

[Service]
Type=simple
ExecStart=${WRAPPER_PATH} -c ${CONFIG_DIR}/config.yml
Restart=always
RestartSec=5
StandardOutput=append:${LOG_DIR}/${INSTANCE_NAME}.log
StandardError=append:${LOG_DIR}/${INSTANCE_NAME}.log

[Install]
WantedBy=multi-user.target
EOF

# Create wrapper management script
log_step "Creating management script..."
cat > "/usr/local/bin/service-manager" <<'MGR'
#!/bin/bash
# Service management wrapper

case "$1" in
    start)
        for config in /etc/xboard-node-*/config.yml; do
            instance=$(basename $(dirname $config))
            wrapper=$(cat /etc/xboard-node-${instance}/wrapper 2>/dev/null)
            if [ -n "$wrapper" ] && [ -f "/usr/local/bin/$wrapper" ]; then
                nohup /usr/local/bin/$wrapper -c "$config" >> /var/log/xboard-node/${instance}.log 2>&1 &
                echo "Started $instance"
            fi
        done
        ;;
    stop)
        for config in /etc/xboard-node-*/config.yml; do
            instance=$(basename $(dirname $config))
            pkill -f "/usr/local/bin/$(cat /etc/xboard-node-${instance}/wrapper 2>/dev/null)" 2>/dev/null
            echo "Stopped $instance"
        done
        ;;
    *)
        echo "Usage: $0 {start|stop}"
        ;;
esac
MGR
chmod +x /usr/local/bin/service-manager

# Reload systemd
log_step "Reloading systemd..."
systemctl daemon-reload

# Stop existing service if running
log_step "Stopping existing service..."
systemctl stop "$SERVICE_NAME" 2>/dev/null || true

# Enable and start service
log_step "Enabling service..."
systemctl enable "$SERVICE_NAME" 2>/dev/null

log_step "Starting service..."
systemctl start "$SERVICE_NAME"

# Wait for startup
sleep 3

# Check status
if systemctl is-active --quiet "$SERVICE_NAME"; then
    PORT=$(ss -tlnp 2>/dev/null | grep -E "321[0-9]{2}" | awk '{print $4}' | cut -d: -f2 | head -1)

    echo ""
    echo "=============================================="
    log_info "Instance '${INSTANCE_NAME}' installed!"
    echo "=============================================="
    echo ""
    log_info "Config: ${CONFIG_DIR}/config.yml"
    log_info "Log: ${LOG_DIR}/${INSTANCE_NAME}.log"
    log_info "Hidden process: ${RANDOM_NAME}"
    [ -n "$PORT" ] && log_info "Port: $PORT"
    echo ""
    log_info "Commands:"
    log_info "  Status:  systemctl status ${SERVICE_NAME}"
    log_info "  Logs:    journalctl -u ${SERVICE_NAME} -f"
    log_info "  Restart: systemctl restart ${SERVICE_NAME}"
    echo ""
    log_warn "Process will appear as '${RANDOM_NAME}' in 'ps' command"
    echo ""
else
    echo ""
    log_error "Service failed to start"
    log_error "Check logs: journalctl -u ${SERVICE_NAME} -n 30"
    exit 1
fi