#!/bin/bash
# start-eip.sh (MySQL Edition)
# MISSION: Industrialized Mission Control for MySQL Integration Tracks
# ----------------------------------------------------------------------
echo "======================================================================"
echo "                   MYSQL PLATFORM MISSION CONTROL                      "
echo "======================================================================"
echo "ID  | MODE                           | SECURITY       "
echo "----------------------------------------------------------------------"
echo "1   | Single Node                    | None           "
echo "2   | Single Node                    | SSL (1-Way)    "
echo "3   | Single Node                    | Mutual TLS     "
echo "======================================================================"

read -p "Select a number [1-3]: " CHOICE
case $CHOICE in
    1) SCENARIO="non-ssl-mysql" ;;
    2) SCENARIO="ssl-oneway" ;;
    3) SCENARIO="ssl-mysql" ;;
    *) echo "Invalid choice"; exit 1 ;;
esac

export SCENARIO
EIP_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export MODE="$SCENARIO"

# PHASE 0: CLEAN SLATE & INFRA PURGE
echo -e "\033[34m>>> PHASE 0: CLEAN SLATE\033[0m"
# Stop any existing consumer or containers
pkill -f "eip-core-consumer" > /dev/null 2>&1 || true

echo "    >>> Purging previous infrastructure and mounts..."
docker rm -f mysql-platform > /dev/null 2>&1 || true
docker compose -p mysql -f "$EIP_SCRIPT_DIR/01_provisioning/docker-mysql.yaml" down -v --remove-orphans > /dev/null 2>&1 || true
docker compose -p mysql -f "$EIP_SCRIPT_DIR/01_provisioning/docker-mysql-secure.yaml" down -v --remove-orphans > /dev/null 2>&1 || true
docker network rm mysql_eip-net > /dev/null 2>&1 || true

# Purge Local Certificate Mounts (Prevent stale cert leakage)
rm -rf "$EIP_SCRIPT_DIR/02_initialization/certs/"* > /dev/null 2>&1 || true
echo "    >>> Environmental state and mounts purged."

# Select appropriate Docker strategy
if [[ "$SCENARIO" == "ssl-"* ]]; then
    DOCKER_FILE="$EIP_SCRIPT_DIR/01_provisioning/docker-mysql-secure.yaml"
    echo "    >>> [MODE] Industrialized Secure Image Strategy"
else
    DOCKER_FILE="$EIP_SCRIPT_DIR/01_provisioning/docker-mysql.yaml"
    echo "    >>> [MODE] Standard Baseline Image Strategy"
fi

# PHASE 1: LOADING ENVIRONMENT
source "$EIP_SCRIPT_DIR/03_environment/setup-env.sh" "$SCENARIO"

# PHASE 2: PKI INITIALIZATION
echo -e "\033[34m>>> PHASE 2: PKI INITIALIZATION\033[0m"
if [[ "$SCENARIO" == "ssl-"* ]]; then
    bash "$EIP_SCRIPT_DIR/02_initialization/setup-pki.sh" "$SCENARIO"
else
    echo "    (Non-SSL Scenario: Skipping PKI)"
fi

# PHASE 3: PROVISIONING
echo -e "\033[34m>>> PHASE 3: PROVISIONING\033[0m"
# Build and Launch MySQL
MYSQL_OPTS="$MYSQL_OPTS" docker compose -p mysql -f "$DOCKER_FILE" up -d --build --force-recreate

TARGET_PORT=${EIP_MYSQL_PORT:-3306}
echo -n ">>> Waiting for MySQL to stabilize (Port $TARGET_PORT)..."
# Industrialized Health Check: Use mysqladmin ping via root for reliability
until docker exec mysql-platform mysqladmin ping -ueip_user -peip_password > /dev/null 2>&1; do
  echo -n "."
  sleep 2
done
echo -e "\n>>> MYSQL is FULLY ACTIVE."

# PHASE 4: SCHEMA PROVISIONING
echo -e "\033[34m>>> PHASE 4: SCHEMA PROVISIONING\033[0m"
bash "$EIP_SCRIPT_DIR/02_initialization/setup-db.sh" "$SCENARIO"

# PHASE 5: LAUNCH CONSUMER
echo -e "\033[34m>>> PHASE 5: LAUNCH EIP CONSUMER\033[0m"
CONSUMER_JAR="$EIP_SCRIPT_DIR/../../../eip-core-consumer/build/quarkus-app/quarkus-run.jar"
java $JAVA_OPTS -jar "$CONSUMER_JAR"
