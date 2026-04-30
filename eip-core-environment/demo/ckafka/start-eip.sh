#!/bin/bash
echo "======================================================================"
echo "                   KAFKA PLATFORM MISSION CONTROL                     "
echo "======================================================================"
echo "ID  | MODE                           | SECURITY       "
echo "----------------------------------------------------------------------"
echo "1   | Single Node                    | None           "
echo "2   | Single Node                    | Mutual TLS     "
echo "======================================================================"

read -p "Select a number [1-2]: " CHOICE

case $CHOICE in
    1) SCENARIO="non-ssl-kafka" ;;
    2) SCENARIO="mtls-kafka" ;;
    *) echo "Invalid choice"; exit 1 ;;
esac

export SCENARIO
EIP_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Phase -1: Clean Slate (Unset EIP/Quarkus variables to prevent pollution)
echo ">>> [SYSTEM] Resetting environment for $SCENARIO..."
for var in $(env | grep -E "^(EIP_|QUARKUS_|JAVA_OPTS|CAMEL_|MONGO|KAFKA)" | cut -d= -f1); do
    unset "$var"
done
export SCENARIO # Re-export after cleanup

# PHASE 0.5: LOADING CONFIGURATION
source "$EIP_SCRIPT_DIR/03_environment/setup-env.sh" "$SCENARIO"

echo ">>> PHASE 0: CLEANUP"
docker compose -p ckafka -f "$EIP_SCRIPT_DIR/01_provisioning/docker-isolated.yaml" down -v
echo "    >>> Environment purged."


echo ">>> PHASE 0.7: PKI INITIALIZATION"
# Only run PKI if it's an SSL scenario
if [[ "$SCENARIO" == "mtls-"* ]] || [[ "$SCENARIO" == "ssl-"* ]]; then
    if [ -f "$EIP_SCRIPT_DIR/02_initialization/setup-pki.sh" ]; then
        bash "$EIP_SCRIPT_DIR/02_initialization/setup-pki.sh" "$SCENARIO"
    fi
fi

echo ">>> PHASE 1: PROVISIONING"
docker compose -p ckafka -f "$EIP_SCRIPT_DIR/01_provisioning/docker-isolated.yaml" up -d --force-recreate

# Wait for Port (using EIP_KAFKA_PORT or default 9092)
TARGET_PORT=${EIP_KAFKA_PORT:-9092}
echo -n ">>> Waiting for Kafka listener (Port $TARGET_PORT)..."
while ! nc -z 127.0.0.1 $TARGET_PORT; do
  echo -n "."
  sleep 1
done
echo -e "\n>>> [HEALTH] Port $TARGET_PORT is OPEN."

# Phase 1.5: Metadata Engine Warmup (Prevents 'Bootstrap broker disconnected' logs)
echo -n ">>> Waiting for Kafka Metadata Engine (Internal Warmup)..."
until docker exec ckafka-platform kafka-topics --bootstrap-server localhost:29092 --list > /dev/null 2>&1; do
  echo -n "."
  sleep 1
done
echo -e "\n>>> KAFKA is FULLY ACTIVE."

echo ">>> PHASE 4: LAUNCHING CONSUMER"
echo ">>> [SYSTEM] Bootstrapping EIP Kafka Consumer..."

CONSUMER_JAR="$EIP_SCRIPT_DIR/../../../eip-core-consumer/build/quarkus-app/quarkus-run.jar"
if [ ! -f "$CONSUMER_JAR" ]; then
    echo ">>> [ERROR] Consumer JAR not found at $CONSUMER_JAR"
    echo ">>> Please build the project using ./gradlew build"
    exit 1
fi

# Fix for Netty 'CleanerJava9' NPE on Java 17+ and Route Discovery
export JDK_JAVA_OPTIONS="--add-opens java.base/java.nio=ALL-UNNAMED --add-opens java.base/jdk.internal.misc=ALL-UNNAMED --add-opens java.base/sun.nio.ch=ALL-UNNAMED --add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED --add-opens java.base/jdk.internal.ref=ALL-UNNAMED"

java $JAVA_OPTS -jar "$CONSUMER_JAR"
