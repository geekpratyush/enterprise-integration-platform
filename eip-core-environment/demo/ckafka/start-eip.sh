#!/bin/bash
# start-eip.sh - CONFLUENT KAFKA MISSION CONTROL
# Lifecycle: Provision -> PKI -> Env -> Topics -> Consumer

EIP_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONSUMER_DIR=$(realpath "$EIP_SCRIPT_DIR/../../../eip-core-consumer")
CONTAINER_NAME="kafka-platform"

echo "======================================================================"
echo "                CONFLUENT KAFKA PLATFORM MISSION CONTROL               "
echo "======================================================================"
echo "ID  | MODE                 | SECURITY        | PORT        "
echo "----------------------------------------------------------------------"
echo "1   | non-ssl-kafka        | PLAINTEXT       | 9092        "
echo "2   | mtls-kafka           | Mutual TLS      | 9095        "
echo "======================================================================"
echo ""
read -p "Select a number [1-2]: " CHOICE

case $CHOICE in
    1) SCENARIO="non-ssl-kafka" ;;
    2) SCENARIO="mtls-kafka" ;;
    *) echo "Invalid choice."; exit 1 ;;
esac

echo -e "\033[33m>>> STARTING CONFLUENT KAFKA LIFECYCLE: $SCENARIO\033[0m"

# PHASE 0: ENVIRONMENT RESOLUTION (Source of Truth)
echo -e "\033[34m>>> PHASE 0: ENVIRONMENT PREP\033[0m"
source "$EIP_SCRIPT_DIR/03_environment/setup-env.sh" "$SCENARIO"

# PHASE 1: DEEP PURGE
echo -e "\033[34m>>> PHASE 1: DEEP PURGE\033[0m"
pkill -f "eip-core-consumer" > /dev/null 2>&1 || true
docker compose -f "$EIP_SCRIPT_DIR/01_provisioning/docker-isolated.yaml" down -v --remove-orphans
rm -rf "$EIP_SCRIPT_DIR/02_initialization/certs"
mkdir -p "$EIP_SCRIPT_DIR/02_initialization/certs"
echo "    >>> Clean State Achieved."

# PHASE 2: INITIALIZATION (Security & Storage)
echo -e "\033[34m>>> PHASE 2: INITIALIZATION\033[0m"
if [[ "$SCENARIO" == "mtls-kafka" ]]; then
    bash "$EIP_SCRIPT_DIR/02_initialization/setup-pki.sh" "$SCENARIO"
fi

# PHASE 3: PROVISIONING (Orchestration)
echo -e "\033[34m>>> PHASE 3: PROVISIONING\033[0m"
DOCKER_FILE="docker-isolated.yaml"
# All variables are now sourced from the environment profile directly
docker compose -f "$EIP_SCRIPT_DIR/01_provisioning/$DOCKER_FILE" --project-directory "$EIP_SCRIPT_DIR/01_provisioning" up -d --remove-orphans

if [[ "$SCENARIO" == "mtls-kafka" ]]; then
    echo -e ">>> \033[33m[READINESS-CHECK] Waiting for Confluent JVM to bind SSL Port 9095...\033[0m"
    sleep 15
    while ! (echo > /dev/tcp/127.0.0.1/9095) >/dev/null 2>&1; do echo -n "."; sleep 2; done
    echo -e "\n>>> \033[32m[READINESS-CHECK] SSL Listener 9095 is ACTIVE.\033[0m"

    echo ">>> [SSL-GATE] Performing authoritative mTLS handshake probe..."
    if openssl s_client -connect 127.0.0.1:9095 -cert "$EIP_CERT_DIR/client.crt" -key "$EIP_CERT_DIR/client.key" -CAfile "$EIP_CERT_DIR/root.crt" < /dev/null > /tmp/ssl_probe.log 2>&1; then
        echo -e ">>> \033[32m[SSL-GATE] Handshake Verified: 0 (ok). PERIMETER SECURE.\033[0m"
    else
        echo -e ">>> \033[31m[SSL-GATE] Handshake FAILED!\033[0m"
        exit 1
    fi
fi

# Wait for Kafka to be ready via standard plaintext port (internal topics/admin)
echo ">>> Waiting for Kafka Broker bootstrap..."
COUNT=0
while ! docker exec $CONTAINER_NAME kafka-topics --bootstrap-server localhost:9092 --list > /dev/null 2>&1; do
    echo -n "."; sleep 2; ((COUNT++))
    if [ $COUNT -ge 30 ]; then echo -e "\n\033[31mTimeout: Kafka Broker failed to start.\033[0m"; exit 1; fi
done
echo -e "\n>>> Kafka Broker is READY."

echo ">>> Initializing Standard Topics [audit_log, telemetry]..."
docker exec $CONTAINER_NAME kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic audit_log --replication-factor 1 --partitions 1 > /dev/null 2>&1
docker exec $CONTAINER_NAME kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic telemetry --replication-factor 1 --partitions 1 > /dev/null 2>&1
echo "Created topics audit_log & telemetry."

# PHASE 4: LAUNCHING CONSUMER
echo -e "\033[34m>>> PHASE 4: LAUNCHING CONSUMER\033[0m"
cd "$CONSUMER_DIR"

# Standard SSL injection for mTLS scenarios (JVM level identity propagation)
SSL_OPTS=""
if [[ "$SCENARIO" == "mtls-kafka" ]]; then
    SSL_OPTS="-Djavax.net.ssl.keyStore=$EIP_CERT_DIR/client.keystore.p12 -Djavax.net.ssl.keyStorePassword=password -Djavax.net.ssl.trustStore=$EIP_CERT_DIR/audit-truststore.p12 -Djavax.net.ssl.trustStorePassword=password"
    echo ">>> [IDENTITY] Injected mTLS System Properties."
fi

./gradlew quarkusDev -Dquarkus.profile=prod $SSL_OPTS
