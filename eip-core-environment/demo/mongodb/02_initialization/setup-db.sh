#!/bin/bash
# ======================================================================
#                MONGODB DB INITIALIZATION (LIQUIBASE)
# ======================================================================

set -e
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIQUIBASE_JAR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../eip-core-liquibase" && pwd)/build/libs/eip-core-liquibase.jar"

echo ">>> MONGODB: Initializing Collections and Indexes via Liquibase..."

# Safety Check: Load environment if needed
if [ -z "$QUARKUS_MONGODB_CLIENT1_CONNECTION_STRING" ]; then
    echo "ERROR: MongoDB Connection String is not set. Reloading profile..."
    PROFILE_FILE="${BASE_DIR}/03_environment/profiles/${MODE}.env"
    if [ -f "$PROFILE_FILE" ]; then
        set -a
        source "$PROFILE_FILE"
        set +a
    else
        echo "CRITICAL ERROR: Profile for mode '$MODE' not found."
        exit 1
    fi
fi

# Liquibase for MongoDB requires the "mongodb://" URL
DB_URL="${QUARKUS_MONGODB_CLIENT1_CONNECTION_STRING}"

echo "    >>> Using target: ${DB_URL}"

# PHASE 2.1: Wait for Primary (Replica Set support)
if [[ "$DB_URL" == *"replSet"* ]] || [[ "$MODE" == *"change-stream"* ]]; then
    echo "    >>> Detected Replica Set scenario. Waiting for PRIMARY election..."
    # Determine container name based on scenario
    if [[ "$MODE" == *"change-stream"* ]]; then
        CONTAINER="mongo-change-stream"
    else
        CONTAINER="mongo-eip"
    fi

    # Loop until isMaster/isPrimary returns true
    # We use a simple ping and check for isWritablePrimary or isMaster
    RETRIES=10
    while [ $RETRIES -gt 0 ]; do
        IS_PRIMARY=$(docker exec $CONTAINER mongosh --quiet --eval "db.hello().isWritablePrimary || db.isMaster().ismaster" | tr -d '\n' | tr -d '\r')
        if [ "$IS_PRIMARY" == "true" ]; then
            echo "    >>> PRIMARY node found. Proceeding with migration."
            break
        fi
        echo "    >>> Waiting for PRIMARY election ($RETRIES attempts left)..."
        RETRIES=$((RETRIES-1))
        sleep 3
    done
    if [ $RETRIES -eq 0 ]; then
        echo "WARNING: Could not confirm PRIMARY status. Liquibase might fail if node is SECONDARY."
    fi
fi

# Execute Liquibase update
echo "    >>> Running Liquibase..."
java $JAVA_OPTS -jar $LIQUIBASE_JAR \
    --search-path=${BASE_DIR}/02_initialization/changelog \
    --changelog-file=db.changelog-master.yaml \
    --url="${DB_URL}" \
    update

echo ">>> MONGODB: Schema Industrialization Complete."
