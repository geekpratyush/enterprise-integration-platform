#!/bin/bash
# start-eip.sh (MySQL Edition)
# MISSION: Interactive Orchestrator for MySQL Lifecycle
# ----------------------------------------------------------------------

set -e

BASE_DIR="/home/pratyush/software/eip-core-integration/eip-core-environment/demo/mysql"

echo "======================================================================"
echo "                MYSQL PLATFORM MISSION CONTROL                        "
echo "======================================================================"
echo "ID  | MODE                 | SECURITY        | PORT / SCHEMA"
echo "----------------------------------------------------------------------"
echo "1   | non-ssl-mysql        | Plaintext       | 3306 / eip_db"
echo "2   | ssl-oneway           | SSL (Server-Only)| 3306 / eip_db"
echo "3   | ssl-mysql            | Mutual SSL      | 3306 / eip_db"
echo "======================================================================"
echo ""
read -p "Select a number [1-3]: " CHOICE

case $CHOICE in
  1) MODE="non-ssl-mysql" ;;
  2) MODE="ssl-oneway" ;;
  3) MODE="ssl-mysql" ;;
  *) echo "Invalid selection. Exit."; exit 1 ;;
esac

echo ">>> STARTING MYSQL LIFECYCLE: $MODE"

# PHASE 0: ENVIRONMENT PREP
export MODE=$MODE
# Ensure cert directory exists to avoid Docker auto-creating it as root
mkdir -p "${BASE_DIR}/02_initialization/certs/${MODE}"
PROFILE_FILE="${BASE_DIR}/03_environment/profiles/${MODE}.env"
if [ ! -f "$PROFILE_FILE" ]; then
    echo "Error: Profile $PROFILE_FILE not found."
    exit 1
fi

# Load Env for Provisioning
set -a
source $PROFILE_FILE
set +a

# PHASE 1: PROVISIONING
echo ">>> PHASE 1: PROVISIONING"
# Mandatory Cleanup
docker rm -f mysql-platform 2>/dev/null || true

if [[ "$MODE" == "ssl-"* ]] || [[ "$MODE" == "tcps-"* ]]; then
    echo "    >>> Orchestrating PKI for $MODE..."
    bash ${BASE_DIR}/02_initialization/setup-pki.sh
fi

docker compose -f ${BASE_DIR}/01_provisioning/docker-mysql.yaml up -d

# PHASE 2: INITIALIZATION
echo ">>> PHASE 2: INITIALIZATION"
echo "    >>> Waiting for MySQL and 'eip_db' to be fully established..."
until docker exec mysql-platform mysql -ueip_user -peip_password -e "SELECT 1" eip_db &>/dev/null; do
    echo -n "."
    sleep 3
done
echo ""
echo "    >>> MySQL and eip_db are READY."

# 1.1 Schema Initialization
echo "    >>> Initializing DB Schema..."
bash ${BASE_DIR}/02_initialization/setup-db.sh

# PHASE 3: IDENTITY MOUNTING (Not strictly needed for SQL but reserved for metadata)

# PHASE 4: LAUNCHING CONSUMER
echo ">>> PHASE 4: LAUNCHING CONSUMER (GRADLE)"
cd /home/pratyush/software/eip-core-integration/eip-core-consumer
# Inject profile into Quarkus Dev
export QUARKUS_PROFILE=dev
./gradlew quarkusDev --no-daemon
