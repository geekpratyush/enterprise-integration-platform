#!/bin/bash
# EIP MONGODB ORCHESTRATOR - Standardized 4-Phase Lifecycle
# REFACTORED: Decentralized Profile Mode (No Dynamic .env Generation)

EIP_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONSUMER_DIR=$(realpath "$EIP_SCRIPT_DIR/../../../eip-core-consumer")
export BASE_DIR="$EIP_SCRIPT_DIR"

echo "======================================================================"
echo "                   MONGODB PLATFORM MISSION CONTROL                    "
echo "======================================================================"
printf "%-3s | %-25s | %-15s | %-12s\n" "ID" "SCENARIO" "SECURITY" "DATABASE"
echo "----------------------------------------------------------------------"

# Standardized ROADMAP
ROADMAP=(
    "non-ssl-mongo|No Auth|eip-db"
    "non-ssl-user-mongo|SCRAM-SHA|eip-db"
    "ssl-oneway|User Auth|eip-db"
    "mtls-mongo|Certificate|eip-db"
    "change-stream-mongo|REPLICA-SET|eip-db"
    "change-stream-ssl-oneway|RS SSL|eip-db"
    "change-stream-mtls|RS mTLS|eip-db"
)

# Display Menu
COUNT=1
declare -A ACTIVE_PROFILES
for ITEM in "${ROADMAP[@]}"; do
    IFS='|' read -r SCEN SEC DB <<< "$ITEM"
    if [[ -f "$EIP_SCRIPT_DIR/03_environment/profiles/${SCEN}.env" ]]; then
        printf "%-3d | %-25s | %-15s | %-12s\n" "$COUNT" "$SCEN" "$SEC" "$DB"
        ACTIVE_PROFILES[$COUNT]=$SCEN
        ((COUNT++))
    fi
done

echo "======================================================================"
echo ""
read -p "Select a number [1-$((COUNT-1))]: " CHOICE
SCENARIO=${ACTIVE_PROFILES[$CHOICE]}

if [[ -z "$SCENARIO" ]]; then echo "Invalid selection. Exiting."; exit 1; fi

echo -e "\033[33m>>> STARTING MONGODB [${SCENARIO}]\033[0m"

# PHASE 0: CLEANUP
echo -e "\033[34m>>> PHASE 0: CLEANUP\033[0m"
pkill -f "eip-core-consumer" > /dev/null 2>&1 || true

# Determine which file to down (Standardize on downing both just in case)
docker compose -f "$EIP_SCRIPT_DIR/01_provisioning/docker-isolated.yaml" down -v --remove-orphans > /dev/null 2>&1 || true
docker compose -f "$EIP_SCRIPT_DIR/01_provisioning/docker-change-stream-mongo.yaml" down -v --remove-orphans > /dev/null 2>&1 || true

# Remove generated sidecar .env (Decentralization complete)
rm -f "$EIP_SCRIPT_DIR/01_provisioning/.env"
rm -rf "$EIP_SCRIPT_DIR/02_initialization/certs/${SCENARIO}"
mkdir -p "$EIP_SCRIPT_DIR/02_initialization/certs/${SCENARIO}"

# PHASE 1: INITIALIZATION (Asset Prep)
echo -e "\033[34m>>> PHASE 1: INITIALIZATION\033[0m"
if [[ "$SCENARIO" == *"ssl"* ]] || [[ "$SCENARIO" == *"mtls"* ]]; then
    bash "$EIP_SCRIPT_DIR/02_initialization/setup-pki.sh" "$SCENARIO"
fi

# PHASE 2: PROVISIONING (Now using sourced Profile)
echo -e "\033[34m>>> PHASE 2: PROVISIONING\033[0m"
export SCENARIO=$SCENARIO
export EIP_CERT_DIR="${EIP_SCRIPT_DIR}/02_initialization/certs/${SCENARIO}"

# SOURCE THE PROFILE (This is the 'Space where demos are being done')
# We source it here to export variables that Docker Compose will pick up
set -a
source "$EIP_SCRIPT_DIR/03_environment/profiles/${SCENARIO}.env"
set +a

if [[ "$SCENARIO" == *"change-stream"* ]]; then
    DOCKER_FILE="docker-change-stream-mongo.yaml"
    CONTAINER_NAME="mongo-change-stream"
else
    DOCKER_FILE="docker-isolated.yaml"
    CONTAINER_NAME="mongo-eip"
fi

docker compose -f "$EIP_SCRIPT_DIR/01_provisioning/$DOCKER_FILE" up -d --remove-orphans

# PHASE 3: HEALTH & REPLICA SETUP
echo -e "\033[34m>>> PHASE 3: HEALTH & INITIALIZATION\033[0m"
echo -n ">>> Waiting for MongoDB container [$CONTAINER_NAME]... "
# Health Logic (Uses variables from sourced profile)
if [[ -n "$EIP_MONGO_ROOT_USER" ]]; then
    AUTH_PART="-u $EIP_MONGO_ROOT_USER -p $EIP_MONGO_ROOT_PASS --authenticationDatabase admin"
else
    AUTH_PART=""
fi

if [[ "$EIP_MONGO_CMD_ARGS" == *"tls"* ]]; then
    # Point to the internal CA file mounted in the container
    TLS_PART="--tls --tlsCAFile /etc/mongodb/certs/root.crt"
    # If mTLS is required, provide the client certificate for the health check
    if [[ "$SCENARIO" == *"mtls"* ]]; then
        TLS_PART="$TLS_PART --tlsCertificateKeyFile /etc/mongodb/certs/mongodb.pem"
    fi
else
    TLS_PART=""
fi

H_CMD="mongosh $AUTH_PART $TLS_PART --port 27017 --quiet --eval 'db.runCommand({ping:1})'"
while ! docker exec $CONTAINER_NAME sh -c "$H_CMD" > /dev/null 2>&1; do echo -n "."; sleep 2; done
echo -e "\n>>> MongoDB is READY."

if [[ "$EIP_MONGO_CMD_ARGS" == *"replSet"* ]]; then
    echo ">>> Initiating Replica Set [rs0]..."
    docker exec $CONTAINER_NAME sh -c "mongosh $AUTH_PART $TLS_PART --port 27017 --quiet --eval 'rs.initiate({_id:\"rs0\", members:[{_id:0, host:\"127.0.0.1:27017\"}]})'" > /dev/null 2>&1 || true
    sleep 3
fi

# 3.1 Schema Initialization (Liquibase)
export MODE=$SCENARIO
bash "$EIP_SCRIPT_DIR/02_initialization/setup-db.sh"

# PHASE 4: RUNNING CONSUMER
echo -e "\033[34m>>> PHASE 4: RUNNING CONSUMER\033[0m"
cd "$CONSUMER_DIR"
./gradlew clean quarkusDev -Dquarkus.profile=prod
