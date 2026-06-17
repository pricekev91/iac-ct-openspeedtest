#!/bin/bash
# ============================================================================
# Deploy OpenSpeedTest into HLH-Docker LXC (192.168.1.13)
# ============================================================================
# Uses macvlan networking on parent=eth0 so the container gets its own
# public IP (192.168.1.5/24) on the LAN.
#
# Prerequisites:
#   - SSH key auth to root@192.168.1.13
#   - Docker Engine + compose plugin on hlh-docker
#   - macvlan network created (see --init flag)
#
# USAGE:
#   ./deploy-iac-ct-openspeedtest.sh          # Deploy (or redeploy)
#   ./deploy-iac-ct-openspeedtest.sh --init   # Create macvlan network only
#   ./deploy-iac-ct-openspeedtest.sh --nuke   # Nuke existing + redeploy
#   ./deploy-iac-ct-openspeedtest.sh --status # Show container status only
# ============================================================================
set -euo pipefail

REMOTE="root@192.168.1.13"
COMPOSE_FILE="openspeedtest-docker-compose.yml"
CONTAINER_NAME="openspeedtest"
CONTAINER_IP="192.168.1.5"
MACVLAN_NAME="macvlan"
MACVLAN_PARENT="eth0"
MACVLAN_SUBNET="192.168.1.0/24"
MACVLAN_GW="192.168.1.1"

MODE="deploy"
if [[ $# -gt 0 ]]; then
    case "$1" in
        --init)    MODE="init" ;;
        --nuke)    MODE="nuke" ;;
        --status)  MODE="status" ;;
        --help)
            echo "Usage: $0 [--init|--nuke|--status|--help]"
            exit 0 ;;
        *)
            echo "Unknown option: $1"; exit 1 ;;
    esac
fi

ssh_cmd() {
    ssh -o StrictHostKeyChecking=no "$REMOTE" "$*"
}

# --- INIT MODE: Create macvlan network only -----------------------------------
if [[ "$MODE" == "init" ]]; then
    echo "[INIT] Checking macvlan network on $REMOTE ..."
    if ssh_cmd "docker network inspect $MACVLAN_NAME >/dev/null 2>&1"; then
        echo "[ OK ] macvlan network already exists"
        exit 0
    fi
    echo "[INIT] Creating macvlan network (parent=$MACVLAN_PARENT) ..."
    ssh_cmd "docker network create -d macvlan \
        --subnet $MACVLAN_SUBNET \
        --gateway $MACVLAN_GW \
        --opt parent=$MACVLAN_PARENT \
        $MACVLAN_NAME"
    echo "[ OK ] macvlan network created"
    echo "  Subnet: $MACVLAN_SUBNET"
    echo "  Gateway: $MACVLAN_GW"
    echo "  Parent: $MACVLAN_PARENT"
    exit 0
fi

# --- STATUS MODE: Show container status only ----------------------------------
if [[ "$MODE" == "status" ]]; then
    echo "[STATUS] Container '$CONTAINER_NAME' on $REMOTE ..."
    ssh_cmd "docker ps -a --filter name=$CONTAINER_NAME --format \"table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Networks}}\""
    if ssh_cmd "docker network inspect $MACVLAN_NAME >/dev/null 2>&1"; then
        echo ""
        echo "[STATUS] macvlan network:"
        ssh_cmd "docker network inspect $MACVLAN_NAME --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}'"
    fi
    exit 0
fi

# --- DEPLOY / NUKE MODE -------------------------------------------------------
echo "[PRECHECK] Verifying SSH to $REMOTE ..."
if ! ssh_cmd "echo OK" >/dev/null 2>&1; then
    echo "[FAIL] Cannot reach $REMOTE. Check SSH key auth." >&2
    exit 1
fi
echo "[ OK ] SSH reachable"

# Check for existing container
EXISTING=$(ssh_cmd "docker ps -a --filter name=$CONTAINER_NAME --format '{{.Status}}' 2>/dev/null" || true)

if [[ -n "$EXISTING" ]]; then
    echo ""
    echo "WARNING: Existing container '$CONTAINER_NAME' found:"
    echo "  Status: $EXISTING"
    echo ""
    read -rp "Stop, remove, and redeploy? (y/n) " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "[ABORT] Cancelled by user."
        exit 0
    fi
    echo "[NUKE] Stopping and removing existing container ..."
    ssh_cmd "docker stop $CONTAINER_NAME 2>/dev/null; docker rm -f $CONTAINER_NAME 2>/dev/null || true"
    echo "[ OK ] Container removed"
    echo ""
elif [[ "$MODE" == "nuke" ]]; then
    echo "[NUKE] No existing container found; nothing to remove."
fi

# --- Ensure macvlan network exists -------------------------------------------
echo "[NET] Checking macvlan network ..."
if ! ssh_cmd "docker network inspect $MACVLAN_NAME >/dev/null 2>&1"; then
    echo "[NET] macvlan network not found — creating now ..."
    ssh_cmd "docker network create -d macvlan \
        --subnet $MACVLAN_SUBNET \
        --gateway $MACVLAN_GW \
        --opt parent=$MACVLAN_PARENT \
        $MACVLAN_NAME"
    echo "[ OK ] macvlan network created"
else
    echo "[ OK ] macvlan network already exists"
fi

# --- Pull image ---------------------------------------------------------------
echo "[PULL] Pulling openspeedtest/latest:latest ..."
ssh_cmd "docker pull openspeedtest/latest:latest"
echo "[ OK ] Image pulled"

# --- Deploy -------------------------------------------------------------------
# Copy compose file to remote host before running docker compose
echo "[DEPLOY] Uploading compose config to $REMOTE ..."
scp -o StrictHostKeyChecking=no "$COMPOSE_FILE" "${REMOTE}:/tmp/$COMPOSE_FILE"
echo "[ OK ] Compose config uploaded"

echo "[DEPLOY] Deploying with docker compose ..."
ssh_cmd "docker compose -f /tmp/$COMPOSE_FILE up -d"
echo "[ OK ] Container deployed"

# --- Verification -------------------------------------------------------------
echo ""
echo "[VERIFY] Checking container status ..."
sleep 3
ssh_cmd "docker ps -a --filter name=$CONTAINER_NAME --format \"table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}\""

echo ""
echo "[VERIFY] Testing connectivity ..."
if ssh_cmd "docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $CONTAINER_NAME" 2>/dev/null; then
    echo "[ OK ] Container has IP assigned"
fi

echo ""
echo "============================================================"
echo "  OpenSpeedTest is live at http://$CONTAINER_IP"
echo "============================================================"
