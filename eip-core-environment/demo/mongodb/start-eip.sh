#!/bin/bash
echo "======================================================================"
echo "                   MONGODB PLATFORM MISSION CONTROL                    "
echo "======================================================================"
echo "ID  | MODE                           | SECURITY       "
echo "----------------------------------------------------------------------"
echo "1   | Single Node                    | None           "
echo "2   | Single Node                    | User/Pass      "
echo "3   | Single Node                    | SSL            "
echo "4   | Single Node                    | Mutual TLS     "
echo "5   | Replica Set                    | None           "
echo "6   | Replica Set                    | SSL            "
echo "7   | Replica Set                    | Mutual TLS     "
echo "======================================================================"

read -p "Select a number [1-7]: " CHOICE

case $CHOICE in
    1) SCENARIO="non-ssl-mongo" ;;
    2) SCENARIO="non-ssl-user-mongo" ;;
    3) SCENARIO="ssl-oneway" ;;
    4) SCENARIO="mtls-mongo" ;;
    5) SCENARIO="change-stream-mongo" ;;
    6) SCENARIO="change-stream-ssl-oneway" ;;
    7) SCENARIO="change-stream-mtls" ;;
    *) echo "Invalid choice"; exit 1 ;;
esac

export SCENARIO
EIP_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CERT_ROOT=~/.eip/certs/mongodb
SCENARIO_CERT_DIR="$CERT_ROOT/$SCENARIO"

# Phase -1: Clean Slate (Unset EIP/Quarkus variables to prevent pollution)
echo ">>> [SYSTEM] Resetting environment for $SCENARIO..."
for var in $(env | grep -E "^(EIP_|QUARKUS_|JAVA_OPTS|CAMEL_|MONGO)" | cut -d= -f1); do
    unset "$var"
done
export SCENARIO # Re-export after cleanup

# Phase -1.5: Host Ownership Restore
echo ">>> [SECURITY] Restoring host ownership for PKI management..."
mkdir -p "$CERT_ROOT"
docker run --rm -v "$CERT_ROOT":/certs busybox chown -R $(id -u):$(id -g) /certs

# PHASE 0.5: LOADING CONFIGURATION
source "$EIP_SCRIPT_DIR/03_environment/setup-env.sh" "$SCENARIO"

echo ">>> PHASE 0: CLEANUP"
DOCKER_FILE="$EIP_SCRIPT_DIR/01_provisioning/docker-isolated.yaml"
docker compose -p mongodb -f "$DOCKER_FILE" down -v
echo "    >>> Environment purged."

echo ">>> PHASE 0.7: PKI INITIALIZATION"
if [ ! -f "$SCENARIO_CERT_DIR/mongodb.pem" ]; then
    bash "$EIP_SCRIPT_DIR/02_initialization/setup-pki.sh" "$SCENARIO"
else
    echo "    >>> [LAZY PKI] Using existing assets."
fi

# Industrial Replica Key Management (Flat Base64)
if [[ "$SCENARIO" == *"change-stream"* ]]; then
    echo ">>> [SECURITY] Refreshing Replica Key..."
    rm -f "$CERT_ROOT/replica.key"
    openssl rand -base64 756 | tr -d '\n' > "$CERT_ROOT/replica.key"
    chmod 400 "$CERT_ROOT/replica.key"
fi

# Final Flip to MongoDB (UID 999)
echo ">>> [SECURITY] Finalizing PKI ownership for MongoDB container..."
docker run --rm -v "$CERT_ROOT":/certs busybox chown -R 999:999 /certs

echo ">>> PHASE 1: PROVISIONING"
docker compose -p mongodb -f "$DOCKER_FILE" up -d --force-recreate

echo -n ">>> Waiting for MongoDB listener (Port $EIP_MONGO_PORT)..."
while ! nc -z 127.0.0.1 $EIP_MONGO_PORT; do echo -n "."; sleep 0.5; done
echo -e "\n>>> MongoDB is ACTIVE."

if [[ "$SCENARIO" == *"change-stream"* ]]; then
    echo -n ">>> [STREAMS] Initializing Replica Set (rs0)..."
    TLS_ARGS=""
    if [[ "$SCENARIO" == *"ssl"* ]] || [[ "$SCENARIO" == *"mtls"* ]]; then
        TLS_ARGS="--tls --tlsCertificateKeyFile /etc/mongodb/certs/mongodb.pem --tlsCAFile /etc/mongodb/certs/root.crt --tlsAllowInvalidHostnames"
    fi
    AUTH_ARGS=""
    if [[ -n "$EIP_MONGO_ROOT_USER" ]]; then
        AUTH_ARGS="-u $EIP_MONGO_ROOT_USER -p $EIP_MONGO_ROOT_PASS --authenticationDatabase admin"
    fi
    
    # Retry loop for rs.initiate (SSL nodes take longer to handshake)
    INIT_RETRIES=15
    until docker exec cmongo-platform mongosh $TLS_ARGS $AUTH_ARGS --quiet --eval "rs.initiate({_id:'rs0',members:[{_id:0,host:'127.0.0.1:27017'}]})" > /dev/null 2>&1; do
      echo -n "."
      sleep 2
      ((INIT_RETRIES--))
      if [ $INIT_RETRIES -le 0 ]; then
        echo -e "\n>>> [ERROR] Failed to initiate Replica Set. Check container logs."
        exit 1
      fi
    done
    echo -e "\n>>> [STREAMS] Replica Set HEALTHY."
fi

echo ">>> PHASE 2.5: SCHEMA PROVISIONING"
bash "$EIP_SCRIPT_DIR/02_initialization/setup-db.sh" "$SCENARIO"

echo ">>> PHASE 4: LAUNCHING CONSUMER"
echo ">>> [SYSTEM] Bootstrapping EIP MongoDB Consumer..."

# Fix for Netty 'CleanerJava9' NPE on Java 17+ and Route Discovery
export JDK_JAVA_OPTIONS="--add-opens java.base/java.nio=ALL-UNNAMED --add-opens java.base/jdk.internal.misc=ALL-UNNAMED --add-opens java.base/sun.nio.ch=ALL-UNNAMED --add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED --add-opens java.base/jdk.internal.ref=ALL-UNNAMED"

CONSUMER_JAR="$EIP_SCRIPT_DIR/../../../eip-core-consumer/build/quarkus-app/quarkus-run.jar"
java $JAVA_OPTS -jar "$CONSUMER_JAR"
