#!/bin/bash
# ======================================================================
#                MONGODB DB INITIALIZATION (LIQUIBASE)
# ======================================================================

set -e
BASE_DIR="/home/pratyush/software/eip-core-integration/eip-core-environment/demo/mongodb"
LIQUIBASE_JAR="/home/pratyush/software/eip-core-integration/eip-core-liquibase/build/libs/eip-core-liquibase.jar"

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

# Execute Liquibase update
java $JAVA_OPTS -jar $LIQUIBASE_JAR \
    --search-path=${BASE_DIR}/02_initialization/changelog \
    --changelog-file=db.changelog-master.yaml \
    --url="${DB_URL}" \
    update

echo ">>> MONGODB: Schema Industrialization Complete."
