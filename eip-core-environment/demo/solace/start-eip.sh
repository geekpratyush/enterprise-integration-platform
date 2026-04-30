#!/bin/bash
echo "======================================================================"
echo "                   SOLACE PLATFORM MISSION CONTROL                     "
echo "======================================================================"
echo "ID  | MODE                           | SECURITY       "
echo "----------------------------------------------------------------------"
echo "1   | Standard                       | None           "
echo "2   | Standard                       | SSL            "
echo "3   | Standard                       | Mutual TLS     "
echo "======================================================================"

read -p "Select a number [1-3]: " CHOICE
case $CHOICE in
    1) SCENARIO="non-ssl" ;;
    2) SCENARIO="ssl-oneway" ;;
    3) SCENARIO="mtls" ;;
    *) echo "Invalid choice"; exit 1 ;;
esac

export SCENARIO
EIP_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# PHASE 0.5: LOADING CONFIGURATION
source "$EIP_SCRIPT_DIR/03_environment/setup-env.sh" "$SCENARIO"

echo ">>> PHASE 0: CLEANUP"
DOCKER_FILE="$EIP_SCRIPT_DIR/01_provisioning/docker-isolated.yaml"
docker compose -f "$DOCKER_FILE" down -v
echo "    >>> Environment purged."


echo ">>> PHASE 0.7: PKI INITIALIZATION"
[[ "$SCENARIO" == *"ssl"* ]] || [[ "$SCENARIO" == *"mtls"* ]] && \
[ -f "$EIP_SCRIPT_DIR/02_initialization/setup-pki.sh" ] && bash "$EIP_SCRIPT_DIR/02_initialization/setup-pki.sh" "$SCENARIO"

echo ">>> PHASE 1: PROVISIONING"
docker compose -f "$DOCKER_FILE" up -d --force-recreate

# Wait for Solace SMF Port (usually 55555 or 55443)
TARGET_PORT=${EIP_SOLACE_PORT:-55555}
echo -n ">>> Waiting for Solace listener (Port $TARGET_PORT)..."
while ! nc -z 127.0.0.1 $TARGET_PORT; do echo -n "."; sleep 1; done
echo -e "\n>>> SOLACE is ACTIVE."

echo ">>> PHASE 4: LAUNCHING CONSUMER"
echo ">>> [SYSTEM] Bootstrapping EIP Solace Consumer..."
