#!/bin/bash
echo "======================================================================"
echo "                   SQLSERVER PLATFORM MISSION CONTROL                  "
echo "======================================================================"
echo "ID  | MODE                           | SECURITY       "
echo "----------------------------------------------------------------------"
echo "1   | Single Node                    | None           "
echo "2   | Single Node                    | SSL (1-Way)    "
echo "3   | Single Node                    | Mutual TLS     "
echo "======================================================================"

read -p "Select a number [1-3]: " CHOICE
case $CHOICE in
    1) SCENARIO="non-ssl-sqlserver" ;;
    2) SCENARIO="ssl-oneway-sqlserver" ;;
    3) SCENARIO="ssl-mtls-sqlserver" ;;
    *) echo "Invalid choice"; exit 1 ;;
esac

export SCENARIO
EIP_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export MODE="$SCENARIO"
export EIP_CERT_DIR="${EIP_SCRIPT_DIR}/02_initialization/certs/${MODE}"
mkdir -p "$EIP_CERT_DIR"

# PHASE 0.5: LOADING CONFIGURATION
source "$EIP_SCRIPT_DIR/03_environment/setup-env.sh" "$SCENARIO"

# PHASE 0: CLEANUP
echo -e "\033[34m>>> PHASE 0: CLEANUP\033[0m"
pkill -f "eip-core-consumer" > /dev/null 2>&1 || true

# Select appropriate Docker strategy
if [[ "$SCENARIO" == "ssl-"* ]]; then
    DOCKER_FILE="$EIP_SCRIPT_DIR/01_provisioning/docker-sqlserver-secure.yaml"
    echo "    >>> [MODE] Industrialized Secure Image Strategy"
else
    DOCKER_FILE="$EIP_SCRIPT_DIR/01_provisioning/docker-sqlserver.yaml"
    echo "    >>> [MODE] Standard Baseline Image Strategy"
fi

docker compose -p sqlserver -f "$DOCKER_FILE" down -v --remove-orphans
docker rm -f sqlserver-platform > /dev/null 2>&1 || true
echo "    >>> Environmental state purged."

# PHASE 0.7: PKI INITIALIZATION
echo -e "\033[34m>>> PHASE 0.7: PKI INITIALIZATION\033[0m"
if [[ "$SCENARIO" == "ssl-"* ]]; then
    bash "$EIP_SCRIPT_DIR/02_initialization/setup-pki.sh" "$SCENARIO"
else
    echo "    (Non-SSL Scenario: Skipping PKI)"
fi

# PHASE 1: PROVISIONING
echo -e "\033[34m>>> PHASE 1: PROVISIONING"
docker compose -p sqlserver -f "$DOCKER_FILE" up -d --force-recreate

TARGET_PORT=${EIP_SQLSERVER_PORT:-1433}
echo -n ">>> Waiting for SQLServer listener (Port $TARGET_PORT)..."
until nc -z 127.0.0.1 $TARGET_PORT; do
  echo -n "."
  sleep 2
done
echo -e "\n>>> SQLSERVER is ACTIVE."

# PHASE 2.5: SCHEMA PROVISIONING
echo -e "\033[34m>>> PHASE 2.5: SCHEMA PROVISIONING\033[0m"
bash "$EIP_SCRIPT_DIR/02_initialization/setup-db.sh" "$SCENARIO"

# PHASE 4: LAUNCHING CONSUMER
echo -e "\033[34m>>> PHASE 4: LAUNCHING CONSUMER\033[0m"
echo ">>> [SYSTEM] Bootstrapping EIP SQLServer Consumer..."

declare -a EXTRA_OPTS
for var in $(env | grep -E "^(QUARKUS_|CAMEL_|EIP_)" | cut -d= -f1); do
    prop_name=$(echo "$var" | tr '[:upper:]' '[:lower:]' | tr '_' '.')
    EXTRA_OPTS+=("-D$prop_name=${!var}")
done

export JDK_JAVA_OPTIONS="--add-opens java.base/java.nio=ALL-UNNAMED --add-opens java.base/jdk.internal.misc=ALL-UNNAMED --add-opens java.base/sun.nio.ch=ALL-UNNAMED --add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED --add-opens java.base/jdk.internal.ref=ALL-UNNAMED"

CONSUMER_JAR="$EIP_SCRIPT_DIR/../../../eip-core-consumer/build/quarkus-app/quarkus-run.jar"
java $JAVA_OPTS "${EXTRA_OPTS[@]}" -jar "$CONSUMER_JAR"
