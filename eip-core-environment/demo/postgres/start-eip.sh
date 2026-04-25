#!/bin/bash
# ======================================================================
#                POSTGRES PLATFORM MISSION CONTROL                         
# ======================================================================

set -e

# Master Directory Reference
BASE_DIR="/home/pratyush/software/eip-core-integration/eip-core-environment/demo/postgres"
PROJECT_DIR="/home/pratyush/software/eip-core-integration/eip-core-consumer"

clear
echo "======================================================================"
echo "                POSTGRES PLATFORM MISSION CONTROL                     "
echo "======================================================================"
echo "ID  | MODE                 | SECURITY        | PORT / SCHEMA"
echo "----------------------------------------------------------------------"
echo "1   | non-ssl-postgres     | Plaintext       | 5432 / eip_db"
echo "2   | ssl-oneway           | SSL (Server-Only)| 5432 / eip_db"
echo "3   | ssl-postgres         | Mutual SSL      | 5432 / eip_db"
echo "======================================================================"
echo ""
read -p "Select a number [1-3]: " CHOICE

case $CHOICE in
  1) MODE="non-ssl-postgres" ;;
  2) MODE="ssl-oneway" ;;
  3) MODE="ssl-postgres" ;;
  *) echo "Invalid option"; exit 1 ;;
esac

export MODE
# Ensure cert directory exists to avoid Docker auto-creating it as root
mkdir -p "${BASE_DIR}/02_initialization/certs/${MODE}"
echo ">>> STARTING POSTGRES LIFECYCLE: $MODE"

# PHASE 0: HARD CLEANUP
echo ">>> PHASE 0: HARD CLEANUP (Pruning EIP Resources)"
docker rm -f postgres-platform mysql-platform oracle-platform sqlserver-platform mongo-eip redis-platform 2>/dev/null || true
docker network rm eip-network 2>/dev/null || true

# PHASE 1: PROVISIONING
echo ">>> PHASE 1: PROVISIONING"
# Load environment profile for Liquibase/JDBC info
PROFILE_FILE="${BASE_DIR}/03_environment/profiles/${MODE}.env"
if [ -f "$PROFILE_FILE" ]; then
    set -a
    source $PROFILE_FILE
    set +a
fi

if [[ "$MODE" == "ssl-"* ]] || [[ "$MODE" == "tcps-"* ]]; then
    echo "    >>> Orchestrating PKI for $MODE..."
    bash ${BASE_DIR}/02_initialization/setup-pki.sh
fi

docker compose -f ${BASE_DIR}/01_provisioning/docker-postgres.yaml up -d

# PHASE 2: INITIALIZATION
echo ">>> PHASE 2: INITIALIZATION"
echo "    >>> Waiting for PostgreSQL to be ready..."
# Use a timeout so we don't hang forever
MAX_RETRIES=30
COUNT=0
until docker exec postgres-platform pg_isready -U eip_user -d eip_db &>/dev/null || [ $COUNT -eq $MAX_RETRIES ]; do
    echo -n "."
    sleep 2
    COUNT=$((COUNT + 1))
done

if [ $COUNT -eq $MAX_RETRIES ]; then
    echo ""
    echo "ERROR: PostgreSQL failed to become ready. Checking logs..."
    docker logs postgres-platform
    exit 1
fi

echo ""
echo "    >>> PostgreSQL is READY."

echo "    >>> Initializing DB Schema..."
bash ${BASE_DIR}/02_initialization/setup-db.sh

# PHASE 4: LAUNCHING CONSUMER (GRADLE)
echo ">>> PHASE 4: LAUNCHING CONSUMER (GRADLE)"

cd $PROJECT_DIR
./gradlew clean quarkusDev
