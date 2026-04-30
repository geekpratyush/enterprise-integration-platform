#!/bin/bash
# EIP IBMMQ ORCHESTRATOR - Standardized 4-Phase Lifecycle

EIP_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONSUMER_DIR=$(realpath "$EIP_SCRIPT_DIR/../../../eip-core-consumer")

echo "======================================================================"
echo "                   IBMMQ PLATFORM MISSION CONTROL                     "
echo "======================================================================"
printf "%-3s | %-20s | %-15s | %-12s\n" "ID" "MODE" "SECURITY" "TX"
echo "----------------------------------------------------------------------"

# Standardized ROADMAP
ROADMAP=(
    "non-ssl-no-auth|No Auth|None"
    "non-ssl-user-auth|User Auth|None"
    "ssl-oneway|User/Cert|Local-TX"
    "mtls|Mutual Cert|Local-TX"
    "mtls-auth-mfa|MFA|Local-TX"
    "kerberos|GSSAPI|Local-TX"
    "mtls-xa|Global Auth|Global JTA"
)

# Display Menu
COUNT=1
declare -A ACTIVE_PROFILES
for ITEM in "${ROADMAP[@]}"; do
    IFS='|' read -r SCEN SEC TX <<< "$ITEM"
    if [[ -f "$EIP_SCRIPT_DIR/03_environment/profiles/${SCEN}.yaml" ]]; then
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
export SCENARIO

# PHASE 0.5: LOADING CONFIGURATION
source "$EIP_SCRIPT_DIR/03_environment/setup-env.sh" "$SCENARIO"

# PHASE 0: CLEANUP
echo -e "\033[34m>>> PHASE 0: CLEANUP\033[0m"
pkill -f "eip-core-consumer" > /dev/null 2>&1 || true
docker compose -p ibmmq -f "$EIP_SCRIPT_DIR/01_provisioning/docker-isolated.yaml" down -v --remove-orphans
rm -rf ~/.eip/certs/ibmmq/$SCENARIO
mkdir -p ~/.eip/certs/ibmmq/$SCENARIO
echo "    >>> Environmental state purged."

# PHASE 0.5: ENVIRONMENT LOADING (CRITICAL)

# PHASE 1: PROVISIONING
echo -e "\033[34m>>> PHASE 1: PROVISIONING\033[0m"
mkdir -p ~/.eip/certs/ibmmq/$SCENARIO
docker compose -p ibmmq -f "$EIP_SCRIPT_DIR/01_provisioning/docker-isolated.yaml" up -d --remove-orphans

# PHASE 2: INITIALIZATION
echo -e "\033[34m>>> PHASE 2: INITIALIZATION\033[0m"
if [[ "$SCENARIO" != *"non-ssl"* ]] && [[ "$SCENARIO" != *"kerberos"* ]]; then
    bash "$EIP_SCRIPT_DIR/02_initialization/setup-pki.sh" "$SCENARIO"
else
    echo "    (Non-SSL/Kerberos Scenario: Resetting Channel to Plain-Text & Open-Auth)"
    echo -n "    >>> Waiting for IBM MQ Queue Manager (QM1) to reach RUNNING state..."
    until docker exec ibmmq-platform dspmq 2>/dev/null | grep -q "Running"; do
      echo -n "."
      sleep 2
    done
    echo -e "\n    >>> IBM MQ is ACTIVE."
    docker exec -i ibmmq-platform runmqsc QM1 << 'MQSC'
ALTER CHANNEL(DEV.APP.SVRCONN) CHLTYPE(SVRCONN) SSLCIPH(' ') SSLCAUTH(OPTIONAL)
SET CHLAUTH(DEV.APP.SVRCONN) TYPE(ADDRESSMAP) ADDRESS('*') USERSRC(CHANNEL) ACTION(REPLACE)
DEFINE QLOCAL(DEV.QUEUE.1) REPLACE
REFRESH SECURITY TYPE(SSL)
REFRESH SECURITY TYPE(AUTHSERV)
MQSC
fi

# PHASE 4: LAUNCHING CONSUMER
echo -e "\033[34m>>> PHASE 4: LAUNCHING CONSUMER\033[0m"

# Fix for Netty 'CleanerJava9' NPE on Java 17+ and Route Discovery
export JDK_JAVA_OPTIONS="--add-opens java.base/java.nio=ALL-UNNAMED --add-opens java.base/jdk.internal.misc=ALL-UNNAMED --add-opens java.base/sun.nio.ch=ALL-UNNAMED --add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED --add-opens java.base/jdk.internal.ref=ALL-UNNAMED"

CONSUMER_JAR="$EIP_SCRIPT_DIR/../../../eip-core-consumer/build/quarkus-app/quarkus-run.jar"
java $JAVA_OPTS -jar "$CONSUMER_JAR"

