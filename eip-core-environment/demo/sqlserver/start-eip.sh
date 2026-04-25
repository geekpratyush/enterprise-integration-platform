#!/bin/bash
# ======================================================================
#                SQLSERVER PLATFORM MISSION CONTROL
# ======================================================================

set -e
BASE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_DIR="/home/pratyush/software/eip-core-integration/eip-core-consumer"

clear
echo "======================================================================"
echo "                SQLSERVER PLATFORM MISSION CONTROL                     "
echo "======================================================================"
echo "ID  | MODE                 | SECURITY        | PORT / SCHEMA"
echo "----------------------------------------------------------------------"
echo "1   | non-ssl-sqlserver    | Plaintext       | 1433 / eip_db"
echo "2   | ssl-oneway           | SSL (Server)    | 1433 / eip_db"
echo "3   | ssl-sqlserver        | Enforced SSL    | 1433 / eip_db"
echo "======================================================================"
echo ""
read -p "Select a number [1-3]: " CHOICE

case $CHOICE in
  1) MODE="non-ssl-sqlserver" ;;
  2) MODE="ssl-oneway" ;;
  3) MODE="ssl-sqlserver" ;;
  *) echo "Invalid option"; exit 1 ;;
esac

export MODE
# Ensure cert directory exists before volume mount
mkdir -p "${BASE_DIR}/02_initialization/certs/${MODE}"

# Load environment profile
PROFILE_FILE="${BASE_DIR}/03_environment/profiles/${MODE}.env"
set -a
source $PROFILE_FILE
set +a

echo ">>> STARTING SQLSERVER LIFECYCLE: $MODE"

# PHASE 1: PROVISIONING
echo ">>> PHASE 1: PROVISIONING"
docker rm -f sqlserver-platform 2>/dev/null || true

if [[ "$MODE" == "ssl-"* ]] || [[ "$MODE" == "tcps-"* ]]; then
    echo "    >>> Orchestrating PKI for $MODE..."
    bash ${BASE_DIR}/02_initialization/setup-pki.sh
    echo "    >>> Generating mssql.conf for $MODE..."
    cat > "${BASE_DIR}/02_initialization/certs/${MODE}/mssql.conf" <<EOF
[network]
tlscert = /etc/ssl/sqlserver/server-cert.pem
tlskey = /etc/ssl/sqlserver/server-key.pem
tlsprotocols = 1.2
forceencryption = 1
EOF
else
    echo "    >>> Creating default mssql.conf for $MODE..."
    cat > "${BASE_DIR}/02_initialization/certs/${MODE}/mssql.conf" <<EOF
[network]
forceencryption = 0
EOF
fi

docker compose -f ${BASE_DIR}/01_provisioning/docker-sqlserver.yaml up -d

# PHASE 2: INITIALIZATION
echo ">>> PHASE 2: INITIALIZATION"
echo "    >>> Waiting for SQL Server to be ready..."
# SQL Server takes a while to start
until docker exec sqlserver-platform /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P Password123! -C -Q "SELECT 1" &>/dev/null; do
    echo -n "."
    sleep 5
done
echo ""
echo "    >>> SQL Server is READY."

echo "    >>> Initializing DB Schema (Liquibase)..."
bash ${BASE_DIR}/02_initialization/setup-db.sh

# PHASE 4: LAUNCHING CONSUMER
echo ">>> PHASE 4: LAUNCHING CONSUMER (GRADLE)"
cd $PROJECT_DIR
./gradlew clean quarkusDev
