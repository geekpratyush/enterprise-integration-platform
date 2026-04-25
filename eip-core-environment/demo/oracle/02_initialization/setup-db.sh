#!/bin/bash
# ======================================================================
#                ORACLE DB INITIALIZATION (LIQUIBASE)
# ======================================================================

set -e
BASE_DIR="/home/pratyush/software/eip-core-integration/eip-core-environment/demo/oracle"
LIQUIBASE_JAR="/home/pratyush/software/eip-core-integration/eip-core-liquibase/build/libs/eip-core-liquibase.jar"

echo ">>> ORACLE: Initializing Schema via Liquibase..."

# Safety Check: Support both standard and named datasource variables
JDBC_URL="${QUARKUS_DATASOURCE_EIP_JDBC_URL:-$QUARKUS_DATASOURCE_JDBC_URL}"
USERNAME="${QUARKUS_DATASOURCE_EIP_USERNAME:-$QUARKUS_DATASOURCE_USERNAME}"
PASSWORD="${QUARKUS_DATASOURCE_EIP_PASSWORD:-$QUARKUS_DATASOURCE_PASSWORD}"

if [ -z "$JDBC_URL" ]; then
    echo "ERROR: Datasource URL is not set. Reloading profile..."
    PROFILE_FILE="${BASE_DIR}/03_environment/profiles/${MODE}.env"
    if [ -f "$PROFILE_FILE" ]; then
        set -a
        source "$PROFILE_FILE"
        set +a
        JDBC_URL="${QUARKUS_DATASOURCE_EIP_JDBC_URL:-$QUARKUS_DATASOURCE_EIP_JDBC_URL}"
        USERNAME="${QUARKUS_DATASOURCE_EIP_USERNAME:-$QUARKUS_DATASOURCE_EIP_USERNAME}"
        PASSWORD="${QUARKUS_DATASOURCE_EIP_PASSWORD:-$QUARKUS_DATASOURCE_EIP_PASSWORD}"
    else
        echo "CRITICAL ERROR: Profile for mode '$MODE' not found."
        exit 1
    fi
fi

echo "    >>> Using URL: $JDBC_URL"

java $JAVA_OPTS -jar $LIQUIBASE_JAR \
    --search-path=${BASE_DIR}/02_initialization/changelog \
    --changelog-file=db.changelog-master.yaml \
    --url="$JDBC_URL" \
    --username="$USERNAME" \
    --password="$PASSWORD" \
    update

echo ">>> ORACLE: Schema Ready."
