#!/bin/bash
# ======================================================================
#                ORACLE PLATFORM MISSION CONTROL                         
# ======================================================================

set -e

# Master Directory Reference
BASE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_DIR=$(cd "${BASE_DIR}/../../../eip-core-consumer" && pwd)

clear
echo "======================================================================"
echo "                ORACLE PLATFORM MISSION CONTROL                     "
echo "======================================================================"
echo "ID  | MODE                 | SECURITY        | PORT / SCHEMA"
echo "----------------------------------------------------------------------"
echo "1   | non-ssl-oracle       | Plaintext       | 1521 / FREEPDB1"
echo "2   | ssl-oneway           | SSL (Server-Only)| 2484 / FREEPDB1"
echo "3   | tcps-oracle          | Mutual TLS      | 2484 / FREEPDB1"
echo "======================================================================"
echo ""
read -p "Select a number [1-3]: " CHOICE

case $CHOICE in
  1) MODE="non-ssl-oracle" ;;
  2) MODE="ssl-oneway" ;;
  3) MODE="tcps-oracle" ;;
  *) echo "Invalid option"; exit 1 ;;
esac

export MODE
# Ensure cert directory exists
mkdir -p "${BASE_DIR}/02_initialization/certs/${MODE}"
echo ">>> STARTING ORACLE LIFECYCLE: $MODE"

# PHASE 0: HARD CLEANUP
echo ">>> PHASE 0: HARD CLEANUP (Pruning EIP Resources)"
docker rm -f postgres-platform mysql-platform oracle-platform sqlserver-platform mongo-eip redis-platform 2>/dev/null || true
docker network rm eip-network 2>/dev/null || true

# If switching back to Plaintext, purge lingering TCPS configurations from the persistent volume so Oracle does not crash searching for empty certificates!
if [[ "$MODE" == "non-ssl-oracle" ]]; then
    docker run --rm -v "eip_oracle_data:/work" alpine rm -f /work/dbconfig/FREE/listener.ora /work/dbconfig/FREE/sqlnet.ora 2>/dev/null || true
fi

# PHASE 1: PROVISIONING
echo ">>> PHASE 1: PROVISIONING"
# Load environment profile
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

docker compose -f ${BASE_DIR}/01_provisioning/docker-oracle.yaml up -d

# PHASE 2: INITIALIZATION
echo ">>> PHASE 2: INITIALIZATION"
echo "    >>> Waiting for Oracle to be ready (this can take a few minutes)..."
MAX_RETRIES=60
COUNT=0
# Oracle health check using Go template to handle missing Health field gracefully
until [ "$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}starting{{end}}' oracle-platform 2>/dev/null)" == "healthy" ] || [ $COUNT -eq $MAX_RETRIES ]; do
    echo -n "."
    sleep 5
    COUNT=$((COUNT + 1))
done

echo ""
echo "    >>> Oracle is READY."

# TCPS Listener Orchestration
if [[ "$MODE" == "ssl-"* ]] || [[ "$MODE" == "tcps-"* ]]; then
    echo "    >>> Orchestrating Oracle TCPS Listener (2484)..."
    docker cp ${BASE_DIR}/02_initialization/setup-tcps.sh oracle-platform:/tmp/setup-tcps.sh
    docker exec -u root oracle-platform chmod +x /tmp/setup-tcps.sh
    docker exec -u oracle -e MODE=$MODE oracle-platform /tmp/setup-tcps.sh

    # NOW enable the Java 21 security override (AFTER PKI, so keytool is not affected)
    ORACLE_SECURITY_FILE="${BASE_DIR}/03_environment/java-oracle.security"
    export JAVA_TOOL_OPTIONS="-Djava.security.properties=${ORACLE_SECURITY_FILE}"
    echo "    >>> Java 21 TLS_RSA security override activated."
fi

echo "    >>> Initializing DB Schema..."
bash ${BASE_DIR}/02_initialization/setup-db.sh

# PHASE 4: LAUNCHING CONSUMER (GRADLE)
echo ">>> PHASE 4: LAUNCHING CONSUMER (GRADLE)"
cd $PROJECT_DIR

# Collect all EIP/QUARKUS/CAMEL variables into an array for Gradle
declare -a EXTRA_OPTS
for var in $(env | grep -E "^(QUARKUS_|CAMEL_|EIP_)" | cut -d= -f1); do
    # Convert ENV_VAR_NAME to quarkus.dot.notation
    prop_name=$(echo "$var" | tr '[:upper:]' '[:lower:]' | tr '_' '.')
    # Add to array
    EXTRA_OPTS+=("-D$prop_name=${!var}")
done

./gradlew clean quarkusDev "${EXTRA_OPTS[@]}"
