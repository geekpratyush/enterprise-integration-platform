#!/bin/bash
# EIP IBMMQ ORCHESTRATOR - Standardized 4-Phase Lifecycle

EIP_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONSUMER_DIR=$(realpath "$EIP_SCRIPT_DIR/../../../eip-core-consumer")

echo "======================================================================"
echo "                   IBMMQ PLATFORM MISSION CONTROL                     "
echo "======================================================================"
printf "%-3s | %-20s | %-15s | %-12s\n" "ID" "MODE" "SECURITY" "TX"
echo "----------------------------------------------------------------------"

# Standardized ROADMAP (Source of Truth)
ROADMAP=(
    "non-ssl-no-auth|No Auth|None"
    "non-ssl-user-auth|User Auth|None"
    "ssl-oneway|User/Cert|Local-TX"
    "mtls|Mutual Cert|Local-TX"
    "mtls-auth-mfa|MFA|Local-TX"
    "kerberos|GSSAPI|Local-TX"
    "mtls-xa|Global Auth|Global JTA"
)

# Display Menu (Roadmap only)
COUNT=1
declare -A ACTIVE_PROFILES
for ITEM in "${ROADMAP[@]}"; do
    IFS='|' read -r SCEN SEC TX <<< "$ITEM"
    if [[ -f "$EIP_SCRIPT_DIR/03_environment/profiles/${SCEN}.env" ]]; then
        printf "%-3d | %-20s | %-15s | %-12s\n" "$COUNT" "$SCEN" "$SEC" "$TX"
        ACTIVE_PROFILES[$COUNT]=$SCEN
        ((COUNT++))
    fi
done

echo "======================================================================"
echo ""
read -p "Select a number [1-$((COUNT-1))]: " CHOICE
SCENARIO=${ACTIVE_PROFILES[$CHOICE]}

if [[ -z "$SCENARIO" ]]; then
    echo "Invalid selection. Exiting."
    exit 1
fi

# PHASE 0: CLEANUP (Total Reset)
echo -e "\033[34m>>> PHASE 0: CLEANUP\033[0m"
pkill -f "eip-core-consumer" > /dev/null 2>&1 || true
docker compose -f "$EIP_SCRIPT_DIR/01_provisioning/docker-isolated.yaml" down -v --remove-orphans
# Reclaim certs directory (may be root-owned from docker mounts)
rm -rf "$EIP_SCRIPT_DIR/02_initialization/certs"
mkdir -p "$EIP_SCRIPT_DIR/02_initialization/certs"
echo "    >>> Environmental state purged."

# PHASE 1: PROVISIONING
echo -e "\033[34m>>> PHASE 1: PROVISIONING\033[0m"
export SCENARIO=$SCENARIO
# Pre-create the scenario directory so it's not created by root during volume mount
mkdir -p "$EIP_SCRIPT_DIR/02_initialization/certs/$SCENARIO"
docker compose -f "$EIP_SCRIPT_DIR/01_provisioning/docker-isolated.yaml" up -d --remove-orphans

# PHASE 2: INITIALIZATION (Smart Policy Application)
echo -e "\033[34m>>> PHASE 2: INITIALIZATION\033[0m"
if [[ "$SCENARIO" != *"non-ssl"* ]] && [[ "$SCENARIO" != *"kerberos"* ]]; then
    bash "$EIP_SCRIPT_DIR/02_initialization/setup-pki.sh" "$SCENARIO"
else
    echo "    (Non-SSL/Kerberos Scenario: Resetting Channel to Plain-Text & Open-Auth)"
    # Allow MQ to bootstrap
    sleep 15
    docker exec -i ibmmq-platform runmqsc QM1 << 'MQSC'
ALTER CHANNEL(DEV.APP.SVRCONN) CHLTYPE(SVRCONN) SSLCIPH(' ') SSLCAUTH(OPTIONAL)
SET CHLAUTH(DEV.APP.SVRCONN) TYPE(ADDRESSMAP) ADDRESS('*') USERSRC(CHANNEL) ACTION(REPLACE)
REFRESH SECURITY TYPE(SSL)
REFRESH SECURITY TYPE(AUTHSERV)
MQSC
    echo "    >>> Channel DEV.APP.SVRCONN reset to Plain-Text and Open-Auth successfully."
fi

# PHASE 3: ENVIRONMENT SETUP
echo -e "\033[34m>>> PHASE 3: ENVIRONMENT SETUP\033[0m"
source "$EIP_SCRIPT_DIR/03_environment/setup-env.sh" "$SCENARIO"

# PHASE 4: LAUNCHING CONSUMER
echo -e "\033[34m>>> PHASE 4: LAUNCHING CONSUMER\033[0m"
cd "$CONSUMER_DIR"
./gradlew clean quarkusDev -Dquarkus.profile=prod
