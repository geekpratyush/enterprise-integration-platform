#!/bin/bash
# ======================================================================
#                SOLACE PUBSUB+ PLATFORM MISSION CONTROL               
# ======================================================================

set -e

# Master Directory Reference
BASE_DIR="/home/pratyush/software/eip-core-integration/eip-core-environment/demo/solace"
EIP_ROUTES_DIR="${BASE_DIR}/04_routes"
EIP_CERT_DIR="${BASE_DIR}/02_initialization/certs"
PROJECT_DIR="/home/pratyush/software/eip-core-integration/eip-core-consumer"

clear
echo "======================================================================"
echo "                SOLACE PUBSUB+ PLATFORM MISSION CONTROL               "
echo "======================================================================"
echo "ID  | MODE                 | SECURITY        | PORT / VPN  "
echo "----------------------------------------------------------------------"
echo "1   | tcp-noauth           | No Auth         | 55555 / default"
echo "2   | tcp-auth             | User Auth       | 55555 / eip-vpn"
echo "3   | ssl-oneway           | User Auth/SSL   | 55443 / eip-vpn"
echo "4   | mtls                 | Mutual TLS      | 55443 / eip-vpn"
echo "======================================================================"
echo ""
read -p "Select a number [1-4]: " CHOICE

case $CHOICE in
  1) MODE="tcp-noauth"; SECURITY="PLAINTEXT"; PORT=55555 ;;
  2) MODE="tcp-auth";   SECURITY="PLAINTEXT"; PORT=55555 ;;
  3) MODE="ssl-oneway"; SECURITY="SSL";       PORT=55443 ;;
  4) MODE="mtls";       SECURITY="mTLS";      PORT=55443 ;;
  *) echo "Invalid option"; exit 1 ;;
esac

echo ">>> STARTING SOLACE LIFECYCLE: $MODE"

# PHASE 0: ENVIRONMENT PREP
echo ">>> PHASE 0: ENVIRONMENT PREP"
export EIP_ROUTES_DIR=${EIP_ROUTES_DIR}
export EIP_CERT_DIR=${EIP_CERT_DIR}
PROFILE_FILE="${BASE_DIR}/03_environment/profiles/${MODE}.env"

if [ ! -f "$PROFILE_FILE" ]; then
    echo "Error: Profile $PROFILE_FILE missing."
    exit 1
fi

echo ">>> Loading dynamic profile: ${MODE}.env"
set -a
source "$PROFILE_FILE"
set +a

# Netty/Java 17 Handshake Stabilizers
export GRADLE_OPTS="-Dsolace.transport.netty.native.disable=true -Dquarkus.netty.native-transport=false -Dio.netty.noUnsafe=true -Djava.net.preferIPv4Stack=true"
export JAVA_OPTS="-Dsolace.transport.netty.native.disable=true -Dquarkus.netty.native-transport=false -Dio.netty.noUnsafe=true -Djava.net.preferIPv4Stack=true"

# Initialize paths for Mission Assets (Mission-Specific Isolation)
CERTS_DIR="${BASE_DIR}/02_initialization/certs/${MODE}"
mkdir -p ${CERTS_DIR}
rm -rf ${CERTS_DIR}/*
export EIP_CERT_DIR=${CERTS_DIR}

# PHASE 1: PROVISIONING (Infrastructure)
echo ">>> PHASE 1: PROVISIONING"
docker compose -f ${BASE_DIR}/01_provisioning/docker-isolated.yaml down || true
docker compose -f ${BASE_DIR}/01_provisioning/docker-isolated.yaml up -d

# PHASE 2: INITIALIZATION (Security & Logic)
echo ">>> PHASE 2: INITIALIZATION"
# PHASE 2.1: PKI Assets
if [[ "$SECURITY" == "SSL" || "$SECURITY" == "mTLS" ]]; then
    echo ">>> [2.1] INITIALIZING PKI"
    # Use a new directory to avoid root-owned volume conflicts from previous runs
    ${BASE_DIR}/02_initialization/setup-pki.sh ${CERTS_DIR}
fi

# PHASE 1.5: READINESS CHECK
echo ">>> Waiting for Solace SEMP (Management Interface) to be ready..."
MAX_RETRIES=150
RETRY_COUNT=0
until curl -s -f -u admin:admin http://127.0.0.1:8085/SEMP/v2/config/msgVpns > /dev/null; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo -e "\n\033[31m>>> Error: Solace SEMP failed to start after 300s.\033[0m"
        exit 1
    fi
    echo -n "."
    sleep 2
done
echo ""
echo ">>> Solace SEMP Interface is READY."
echo ">>> Waiting an additional 10s for Message Engine stabilization..."
sleep 10
echo ">>> Solace Broker is FULLY ARMED."

# PHASE 2.5: PLATFORM CONFIGURATION (SEMP)
echo ">>> PHASE 2.5: PLATFORM CONFIGURATION"
chmod +x ${BASE_DIR}/02_initialization/setup-solace.sh
${BASE_DIR}/02_initialization/setup-solace.sh ${SOLACE_VPN} ${CAMEL_KAMELET_SOLACE_SOURCE_QUEUENAME} ${CERTS_DIR} ${MODE}

# PHASE 3: ENVIRONMENT PREP
echo ">>> PHASE 3: ENVIRONMENT PREP"
echo ">>> Loading dynamic profile: ${MODE}.env"

# PHASE 4: LAUNCHING CONSUMER
echo ">>> PHASE 4: LAUNCHING CONSUMER (GRADLE)"
cd $PROJECT_DIR
./gradlew clean quarkusDev \
  -Dsolace.transport.netty.native.disable=true \
  -Dquarkus.netty.native-transport=false \
  -Dio.netty.noUnsafe=true \
  -Djava.net.preferIPv4Stack=true \
  -Dquarkus.args="--add-opens java.base/java.nio=ALL-UNNAMED"
