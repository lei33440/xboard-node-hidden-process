#!/bin/bash
# Xboard-Node Complete Hide Installer for Debian/Ubuntu
#
# 完全隐藏安装：进程名、二进制、配置全部隐藏
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

VERSION="2.0.3"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Download with retry
download_with_retry() {
    local url=$1
    local output=$2
    local max_try=5
    local try=1

    while [ $try -le $max_try ]; do
        log_info "Download attempt $try/$max_try..."
        if curl -fsSL --connect-timeout 30 --max-time 300 -o "$output" "$url" 2>/dev/null; then
            return 0
        fi
        log_warn "Download failed, retry in 3 seconds..."
        sleep 3
        try=$((try + 1))
    done
    return 1
}

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
Xboard-Node Complete Hide Installer v2.0.3 (Debian/Ubuntu)

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
  - Process name hidden (appears as crond-worker/ssh-agent)
  - Binary renamed to kernel-update
  - Config in hidden directory
  - ps -ef | grep xboard shows nothing

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

# Validate instance name
if [[ ! "$INSTANCE_NAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
    log_error "Instance name must contain only letters, numbers, and hyphens"
    exit 1
fi

# Paths
SERVICE_NAME="xboard-node-${INSTANCE_NAME}"
BINARY_PATH="/usr/local/bin/kernel-update"
# 使用持久化存储路径（/var/run 在重启后会被清空）
HIDDEN_CONFIG_DIR="/etc/.system-cache/${INSTANCE_NAME}"

# Wrapper names pool
WRAPPER_NAMES=("crond-worker" "ssh-agent" "system-logger" "cache-manager" "sync-daemon")

# Banner
echo ""
echo "=============================================="
echo "  Xboard-Node Complete Hide Installer v${VERSION}"
echo "  (Debian/Ubuntu)"
echo "=============================================="
echo ""
log_info "Instance: ${INSTANCE_NAME}"
log_info "Panel: ${PANEL_URL}"
log_info "Machine ID: ${MACHINE_ID}"
echo ""

# Check if instance already exists in hidden location
if [ -d "$HIDDEN_CONFIG_DIR" ]; then
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

# Create persistent directories
mkdir -p /etc/.system-cache
mkdir -p "$HIDDEN_CONFIG_DIR"

# Download binary and rename
if [ ! -f "$BINARY_PATH" ]; then
    log_step "Downloading xboard-node..."

    # Download URLs (try multiple sources)
    BASE_URLS=(
        "https://github.com/cedar2025/Xboard-Node/releases"
        "https://ghproxy.com/https://github.com/cedar2025/Xboard-Node/releases"
        "https://mirror.ghproxy.com/https://github.com/cedar2025/Xboard-Node/releases"
    )

    DOWNLOADED=false
    for BASE in "${BASE_URLS[@]}"; do
        if [ "$INSTALL_VERSION" = "latest" ]; then
            DOWNLOAD_URL="$BASE/latest/download/xboard-node-linux-$ARCH_NAME"
        else
            DOWNLOAD_URL="$BASE/download/$INSTALL_VERSION/xboard-node-linux-$ARCH_NAME"
        fi
        log_info "Trying: $DOWNLOAD_URL"
        if download_with_retry "$DOWNLOAD_URL" "$BINARY_PATH"; then
            DOWNLOADED=true
            break
        fi
    done

    if [ "$DOWNLOADED" = false ]; then
        log_error "Failed to download xboard-node after multiple attempts"
        exit 1
    fi

    chmod +x "$BINARY_PATH"
    log_info "Binary downloaded as kernel-update"
else
    log_info "Binary exists, skipping"
fi

# Assign wrapper name (use different names for different instances)
WRAPPER_INDEX=$(ls /usr/local/bin/ 2>/dev/null | grep -E "^(crond-worker|ssh-agent|system-logger|cache-manager|sync-daemon)$" | wc -l)
WRAPPER_NAME="${WRAPPER_NAMES[$WRAPPER_INDEX]}"
if [ -z "$WRAPPER_NAME" ]; then
    WRAPPER_NAME="crond-worker"
fi
log_info "Hidden process name: ${WRAPPER_NAME}"

# Create wrapper script
log_step "Creating hidden wrapper..."
cat > "/usr/local/bin/${WRAPPER_NAME}" <<WRAPPER
#!/bin/bash
CONFIG=${HIDDEN_CONFIG_DIR}/config.yml
exec -a ${WRAPPER_NAME} ${BINARY_PATH} -c \$CONFIG
WRAPPER
chmod +x "/usr/local/bin/${WRAPPER_NAME}"

# Create config
log_step "Creating configuration..."
INSTANCE_ID="$(echo "$PANEL_URL" | sed 's|https\?://||' | tr './' '-')-machine-${MACHINE_ID}-$(date +%s)"
cat > "$HIDDEN_CONFIG_DIR/config.yml" <<EOF
instances:
    - id: ${INSTANCE_ID}
      panel:
        url: ${PANEL_URL}
      machine:
        machine_id: ${MACHINE_ID}
        token: ${TOKEN}
EOF
log_info "Config: ${HIDDEN_CONFIG_DIR}/config.yml"

# Save wrapper info
echo "$WRAPPER_NAME" > "$HIDDEN_CONFIG_DIR/wrapper"

# Create systemd service
log_step "Creating systemd service..."
cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=System Service - ${INSTANCE_NAME}
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/${WRAPPER_NAME}
Restart=always
RestartSec=5
StandardOutput=null
StandardError=null

[Install]
WantedBy=multi-user.target
EOF

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
    echo ""
    echo "=============================================="
    log_info "Instance '${INSTANCE_NAME}' installed!"
    echo "=============================================="
    echo ""
    log_info "Hidden process: ${WRAPPER_NAME}"
    log_info "Binary: ${BINARY_PATH}"
    log_info "Config: ${HIDDEN_CONFIG_DIR}/config.yml"
    echo ""
    log_info "Commands:"
    log_info "  Status:  systemctl status ${SERVICE_NAME}"
    log_info "  Logs:    journalctl -u ${SERVICE_NAME} -f"
    log_info "  Restart: systemctl restart ${SERVICE_NAME}"
    echo ""
    log_warn "Check: ps -ef | grep xboard (shows nothing!)"
    log_warn "Check: ps -ef | grep ${WRAPPER_NAME} (shows hidden process)"
    echo ""
else
    echo ""
    log_error "Service failed to start"
    log_error "Check logs: journalctl -u ${SERVICE_NAME} -n 30"
    exit 1
fi