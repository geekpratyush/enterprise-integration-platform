#!/bin/bash
set -e
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIQUIBASE_JAR="${BASE_DIR}/../../../liquibase/eip-core-liquibase.jar"

if [ ! -f "$LIQUIBASE_JAR" ]; then
    echo "ERROR: eip-core-liquibase.jar not found."
    exit 1
fi

echo ">>> MONGODB: Initializing Collections and Indexes via Liquibase..."

DB_URL="${QUARKUS_MONGODB_MONGOCLIENT_CONNECTION_STRING}"
echo "    >>> Using target: ${DB_URL}"

# Determine Connection String for internal mongosh provisioning
# We use 127.0.0.1:27017 as we are running INSIDE the container
INTERNAL_URI="mongodb://127.0.0.1:27017/?tls=false"
TLS_ARGS=""
if [[ "$SCENARIO" == *"ssl"* ]] || [[ "$SCENARIO" == *"mtls"* ]]; then
    INTERNAL_URI="mongodb://127.0.0.1:27017/?tls=true&tlsAllowInvalidHostnames=true"
    TLS_ARGS="--tlsCertificateKeyFile /etc/mongodb/certs/mongodb.pem --tlsCAFile /etc/mongodb/certs/root.crt"
fi

AUTH_ARGS=""
if [[ -n "$EIP_MONGO_ROOT_USER" ]]; then
    AUTH_ARGS="-u $EIP_MONGO_ROOT_USER -p $EIP_MONGO_ROOT_PASS --authenticationDatabase admin"
fi

# 1. Wait for Primary (Replica Set) OR just Writable (Single Node)
if [[ "$SCENARIO" == *"change-stream"* ]]; then
    echo "    >>> [STREAMS] Waiting for PRIMARY election in Replica Set..."
    RETRIES=20
    while [ $RETRIES -gt 0 ]; do
        IS_PRIMARY=$(docker exec cmongo-platform env -i PATH=$PATH /usr/bin/mongosh "$INTERNAL_URI" $TLS_ARGS $AUTH_ARGS --quiet --eval "db.hello().isWritablePrimary" 2>/dev/null | tr -d '\n' | tr -d '\r')
        if [ "$IS_PRIMARY" == "true" ]; then
            echo "    >>> PRIMARY node found."
            break
        fi
        echo "    >>> Waiting for PRIMARY ($RETRIES attempts left)..."
        RETRIES=$((RETRIES-1))
        sleep 2
    done
    
    if [ "$IS_PRIMARY" != "true" ]; then
        echo -e "\n>>> [ERROR] No PRIMARY elected in time. Liquibase cannot proceed."
        exit 1
    fi
fi


# 3. Execute Liquibase update
echo "    >>> Running Liquibase migration..."
java $JAVA_OPTS -jar $LIQUIBASE_JAR \
    --search-path=${BASE_DIR}/02_initialization/changelog \
    --changelog-file=db.changelog-master.yaml \
    --url="${DB_URL}" \
    update

echo ">>> MONGODB: Schema Industrialization Complete."
