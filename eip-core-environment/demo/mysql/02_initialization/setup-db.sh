#!/bin/bash
# setup-db.sh (MySQL Edition)
# MISSION: Industrialized Liquibase Schema Migration
# ----------------------------------------------------------------------
set -e

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIQUIBASE_JAR="${BASE_DIR}/../../../liquibase/eip-core-liquibase.jar"

if [ ! -f "$LIQUIBASE_JAR" ]; then 
    echo "ERROR: Liquibase JAR not found at $LIQUIBASE_JAR"; 
    exit 1; 
fi

echo ">>> MYSQL: Initializing Schema via Liquibase..."

# Resolve Core Credentials
JDBC_URL="${QUARKUS_DATASOURCE_JDBC_URL:-$QUARKUS_DATASOURCE_EIP_JDBC_URL}"
USERNAME="${QUARKUS_DATASOURCE_USERNAME:-$QUARKUS_DATASOURCE_EIP_USERNAME}"
PASSWORD="${QUARKUS_DATASOURCE_PASSWORD:-$QUARKUS_DATASOURCE_EIP_PASSWORD}"

# Execute Migration
java $JAVA_OPTS -jar $LIQUIBASE_JAR \
    --search-path=${BASE_DIR}/02_initialization/changelog \
    --changelog-file=db.changelog-master.yaml \
    --url="$JDBC_URL" \
    --username="$USERNAME" \
    --password="$PASSWORD" \
    update

echo ">>> MYSQL: Schema Industrialized Successfully."
