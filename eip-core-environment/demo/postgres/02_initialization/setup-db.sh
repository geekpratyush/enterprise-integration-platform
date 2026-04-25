#!/bin/bash
# ======================================================================
#                POSTGRES DB INITIALIZATION (LIQUIBASE)
# ======================================================================

set -e
BASE_DIR="/home/pratyush/software/eip-core-integration/eip-core-environment/demo/postgres"
LIQUIBASE_JAR="/home/pratyush/software/eip-core-integration/eip-core-liquibase/build/libs/eip-core-liquibase.jar"

echo ">>> POSTGRES: Initializing Schema via Liquibase..."

# Safety Check: Ensure variables are set and exported
if [ -z "$QUARKUS_DATASOURCE_JDBC_URL" ]; then
    echo "ERROR: QUARKUS_DATASOURCE_JDBC_URL is not set. Reloading profile..."
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

# Final Check
if [ -z "$QUARKUS_DATASOURCE_JDBC_URL" ]; then
    echo "CRITICAL ERROR: Environment variables were not successfully propagated."
    exit 1
fi

echo "    >>> Using URL: $QUARKUS_DATASOURCE_JDBC_URL"

java -jar $LIQUIBASE_JAR \
    --search-path=${BASE_DIR}/02_initialization/changelog \
    --changelog-file=db.changelog-master.yaml \
    --url="$QUARKUS_DATASOURCE_JDBC_URL" \
    --username="$QUARKUS_DATASOURCE_USERNAME" \
    --password="$QUARKUS_DATASOURCE_PASSWORD" \
    update

echo ">>> POSTGRES: Schema Ready."
