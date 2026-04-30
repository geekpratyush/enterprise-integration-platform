#!/bin/bash
echo "======================================================================"
echo "                   REDIS PLATFORM MISSION CONTROL                      "
echo "======================================================================"
echo "ID  | MODE                           | SECURITY       "
echo "----------------------------------------------------------------------"
echo "1   | Standalone                     | None           "
echo "2   | Standalone                     | Password       "
echo "3   | Standalone                     | ACL            "
echo "4   | Standalone                     | TLS            "
echo "5   | Sentinel                       | Password       "
echo "======================================================================"

read -p "Select a number [1-5]: " CHOICE
case $CHOICE in
    1) SCENARIO="redis-noauth" ;;
    2) SCENARIO="redis-pass" ;;
    3) SCENARIO="redis-acl" ;;
    4) SCENARIO="redis-tls" ;;
    5) SCENARIO="redis-sentinel" ;;
    *) echo "Invalid choice"; exit 1 ;;
esac

export SCENARIO
EIP_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# PHASE 0.5: LOADING CONFIGURATION
source "$EIP_SCRIPT_DIR/03_environment/setup-env.sh" "$SCENARIO"

echo ">>> PHASE 0: CLEANUP"
# Determine Docker File
DOCKER_FILE="$EIP_SCRIPT_DIR/01_provisioning/docker-isolated.yaml"
[[ "$SCENARIO" == *"sentinel"* ]] && DOCKER_FILE="$EIP_SCRIPT_DIR/01_provisioning/docker-sentinel.yaml"
[[ "$SCENARIO" == *"acl"* ]] && DOCKER_FILE="$EIP_SCRIPT_DIR/01_provisioning/docker-auth.yaml"

docker compose -f "$DOCKER_FILE" down -v
echo "    >>> Environment purged."


echo ">>> PHASE 0.7: PKI INITIALIZATION"
[[ "$SCENARIO" == *"tls"* ]] || [[ "$SCENARIO" == *"acl"* ]] || [[ "$SCENARIO" == *"sentinel"* ]] && \
[ -f "$EIP_SCRIPT_DIR/02_initialization/setup-pki.sh" ] && bash "$EIP_SCRIPT_DIR/02_initialization/setup-pki.sh" "$SCENARIO"

echo ">>> PHASE 1: PROVISIONING"
docker compose -f "$DOCKER_FILE" up -d --force-recreate

TARGET_PORT=${EIP_REDIS_PORT:-6379}
echo -n ">>> Waiting for Redis listener (Port $TARGET_PORT)..."
while ! nc -z 127.0.0.1 $TARGET_PORT; do echo -n "."; sleep 1; done
echo -e "\n>>> REDIS is ACTIVE."

echo ">>> PHASE 4: LAUNCHING CONSUMER"
echo ">>> [SYSTEM] Bootstrapping EIP Redis Consumer..."
