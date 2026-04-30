#!/bin/bash
set -e
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIQUIBASE_JAR="${BASE_DIR}/../../../liquibase/eip-core-liquibase.jar"
if [ ! -f "$LIQUIBASE_JAR" ]; then echo "ERROR: Liquibase JAR not found."; exit 1; fi
echo ">>> POSTGRES: Initializing Schema via Liquibase..."
JDBC_URL="${QUARKUS_DATASOURCE_EIP_JDBC_URL}"
USERNAME="${QUARKUS_DATASOURCE_EIP_USERNAME}"
PASSWORD="${QUARKUS_DATASOURCE_EIP_PASSWORD}"
java $JAVA_OPTS -jar $LIQUIBASE_JAR --search-path=${BASE_DIR}/02_initialization/changelog --changelog-file=db.changelog-master.yaml --url="$JDBC_URL" --username="$USERNAME" --password="$PASSWORD" update
echo ">>> POSTGRES: Schema Industrialized."
