#!/bin/bash
# ======================================================================
#                REDIS PLATFORM MISSION CONTROL                         
# ======================================================================

set -e

# Master Directory Reference
BASE_DIR="/home/pratyush/software/eip-core-integration/eip-core-environment/demo/redis"
EIP_ROUTES_DIR="${BASE_DIR}/04_routes"
PROJECT_DIR="/home/pratyush/software/eip-core-integration/eip-core-consumer"

clear
echo "======================================================================"
echo "                REDIS PLATFORM MISSION CONTROL                        "
echo "======================================================================"
echo "ID  | MODE                 | SECURITY        | PORT / INSTANCE"
echo "----------------------------------------------------------------------"
echo "1   | redis-noauth         | None            | 6379 / Standalone"
echo "2   | redis-pass           | Password        | 6379 / Standalone"
echo "3   | redis-acl            | ACL (User/Pass) | 6379 / Standalone"
echo "4   | redis-tls            | mTLS (Certs)    | 6379 / Standalone"
echo "5   | redis-sentinel       | Cluster         | 26379 / Sentinel"
echo "======================================================================"
echo ""
read -p "Select a number [1-5]: " CHOICE

case $CHOICE in
  1) MODE="redis-noauth" ;;
  2) MODE="redis-pass" ;;
  3) MODE="redis-acl" ;;
  4) MODE="redis-tls" ;;
  5) MODE="redis-sentinel" ;;
  *) echo "Invalid option"; exit 1 ;;
esac

export MODE
echo ">>> STARTING REDIS LIFECYCLE: $MODE"

# PHASE 0: ENVIRONMENT PREP
echo ">>> PHASE 0: ENVIRONMENT PREP"
ENV_FILE="${BASE_DIR}/03_environment/profiles/${MODE}.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: Profile $ENV_FILE missing."
    exit 1
fi

# Load Environment purely for orchestration
set -a
source $ENV_FILE
set +a

# PHASE 1: PROVISIONING (Infrastructure)
echo ">>> PHASE 1: PROVISIONING"
DOCKER_FILE="${BASE_DIR}/01_provisioning/docker-isolated.yaml"
if [ "$MODE" == "redis-pass" ] || [ "$MODE" == "redis-acl" ]; then
    DOCKER_FILE="${BASE_DIR}/01_provisioning/docker-auth.yaml"
elif [ "$MODE" == "redis-tls" ] || [ "$MODE" == "redis-sentinel" ]; then
    echo "    >>> Orchestrating PKI for $MODE..."
    bash ${BASE_DIR}/02_initialization/setup-pki.sh
    if [ "$MODE" == "redis-sentinel" ]; then
        DOCKER_FILE="${BASE_DIR}/01_provisioning/docker-sentinel.yaml"
    else
        DOCKER_FILE="${BASE_DIR}/01_provisioning/docker-auth.yaml"
    fi
else
    DOCKER_FILE="${BASE_DIR}/01_provisioning/docker-isolated.yaml"
fi

# Pre-cleanup: kill any orphan containers from previous runs
docker rm -f redis-platform redis-master redis-replica redis-sentinel 2>/dev/null || true
docker network rm redis-sentinel-network redis-network 2>/dev/null || true

docker compose -f ${DOCKER_FILE} down || true
docker rm -f redis-platform 2>/dev/null || true

# Dynamic Config Selection (Symlink Strategy)
REDIS_CONFIG="redis-noauth.conf"
if [ "$MODE" == "redis-pass" ]; then REDIS_CONFIG="redis-pass.conf"; fi
if [ "$MODE" == "redis-acl" ]; then REDIS_CONFIG="redis-acl.conf"; fi
if [ "$MODE" == "redis-tls" ]; then REDIS_CONFIG="redis-tls.conf"; fi

echo "    >>> Mapping Infrastructure Config: ${REDIS_CONFIG}"
ln -sf ${BASE_DIR}/01_provisioning/${REDIS_CONFIG} ${BASE_DIR}/01_provisioning/redis.conf

# Standard Launch
docker compose -f ${DOCKER_FILE} up -d

# PHASE 2: INITIALIZATION (Platform Readiness)
echo ">>> PHASE 2: INITIALIZATION"
chmod +x ${BASE_DIR}/02_initialization/setup-redis.sh
${BASE_DIR}/02_initialization/setup-redis.sh

# PHASE 3: IDENTITY MOUNTING (Metadata Injection)
echo ">>> PHASE 3: IDENTITY MOUNTING"
ID_FILE="standalone-identity.yaml"
if [ "$MODE" == "redis-sentinel" ]; then
    ID_FILE="sentinel-identity.yaml"
fi
echo "    >>> Mounting Identity Metadata: ${ID_FILE}"
ln -sf ${BASE_DIR}/identities/${ID_FILE} ${BASE_DIR}/04_routes/beans.yaml

# PHASE 4: LAUNCHING CONSUMER (GRADLE)
echo ">>> PHASE 4: LAUNCHING CONSUMER (GRADLE)"
echo "    >>> Payload Direction: ${REDIS_CHANNEL}"

# Final cleanup of environment variables for the child process
set -a
source ${ENV_FILE}
set +a

cd $PROJECT_DIR
./gradlew clean quarkusDev 
