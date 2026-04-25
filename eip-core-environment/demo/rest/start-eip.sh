#!/bin/bash
# EIP REST ORCHESTRATOR - 3-Track Industrial Consolidation (Absolute Anchor)
set -e

EIP_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONSUMER_DIR=$(realpath "$EIP_SCRIPT_DIR/../../../eip-core-consumer")
BASE_DIR="${EIP_SCRIPT_DIR}"
export BASE_DIR

# Export Absolute Root for Docker Volumes
export EIP_ROOT_DIR="${BASE_DIR}"

echo "======================================================================"
echo "                   REST PLATFORM MISSION CONTROL                     "
echo "======================================================================"
printf "%-3s | %-15s | %-30s\n" "ID" "TRACK" "SECURITY DESCRIPTION"
echo "----------------------------------------------------------------------"

printf "%-3s | %-15s | %-30s\n" "1" "Plaintext" "Full Suite (HTTP - Port 8081)"
printf "%-3s | %-15s | %-30s\n" "2" "Secure One-Way" "Full Suite (HTTPS - Port 8443)"
printf "%-3s | %-15s | %-30s\n" "3" "Secure mTLS" "Full Suite (mTLS - Port 8443)"
echo "======================================================================"

read -p "Select a track [1-3]: " CHOICE
case $CHOICE in
    1) SCENARIO="http-rest";   INFRA="docker-rest-plain.yaml" ;;
    2) SCENARIO="https-oneway"; INFRA="docker-rest-oneway.yaml" ;;
    3) SCENARIO="https-mtls";   INFRA="docker-rest-mtls.yaml" ;;
    *) echo "Invalid selection"; exit 1 ;;
esac

# All tracks now use the consolidated Full Suite
export EIP_ROUTES_DIR="${BASE_DIR}/04_routes/4_full"

echo -e "\033[33m>>> STARTING REST [$SCENARIO] USING INFRA [$INFRA]\033[0m"

# PHASE 0: CLEANUP
echo -e "\033[34m>>> PHASE 0: CLEANUP\033[0m"
pkill -f "eip-core-consumer" > /dev/null 2>&1 || true
docker compose -f "$EIP_SCRIPT_DIR/01_provisioning/docker-rest-plain.yaml" down -v --remove-orphans > /dev/null 2>&1 || true
docker compose -f "$EIP_SCRIPT_DIR/01_provisioning/docker-rest-oneway.yaml" down -v --remove-orphans > /dev/null 2>&1 || true
docker compose -f "$EIP_SCRIPT_DIR/01_provisioning/docker-rest-mtls.yaml" down -v --remove-orphans > /dev/null 2>&1 || true

# PHASE 1: PKI / INITIALIZATION
echo -e "\033[34m>>> PHASE 1: INITIALIZATION (PKI)\033[0m"
bash "$EIP_SCRIPT_DIR/02_initialization/setup-pki.sh" "$SCENARIO"

# PHASE 2: PROVISIONING
echo -e "\033[34m>>> PHASE 2: PROVISIONING\033[0m"
export SCENARIO=$SCENARIO
export EIP_CERT_DIR="${EIP_SCRIPT_DIR}/02_initialization/certs/${SCENARIO}"

# Gather variables from profile
set -a
source "$EIP_SCRIPT_DIR/03_environment/profiles/${SCENARIO}.env"
set +a

docker compose -f "$EIP_SCRIPT_DIR/01_provisioning/$INFRA" up -d
echo ">>> Waiting for WireMock..."
until curl -s http://localhost:8081/__admin/mappings > /dev/null || curl -sk https://localhost:8443/__admin/mappings > /dev/null; do echo -n "."; sleep 1; done
echo -e "\n>>> WireMock is READY."

# PHASE 4: RUNNING CONSUMER (Explicit Scenario Filtering)
echo -e "\033[34m>>> PHASE 4: RUNNING CONSUMER\033[0m"
cd "$CONSUMER_DIR"
./gradlew clean quarkusDev -Dquarkus.profile=prod 
