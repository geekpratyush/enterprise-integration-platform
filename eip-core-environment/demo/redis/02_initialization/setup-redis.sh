#!/bin/bash
# setup-redis.sh
# Industrialized Platform Initializer for Redis
# ----------------------------------------------------------------------

set -e

# Detect Container Name (Compatibility for Standalone vs Sentinel)
CONTAINER_NAME="redis-platform"
if [ ! -z "$(docker ps -q -f name=redis-master)" ]; then
    CONTAINER_NAME="redis-master"
fi

echo ">>> REDIS: Initializing Platform Logic (Container: $CONTAINER_NAME)..."

# 1. Readiness Check (Simple PING via Docker)
echo "    >>> Waiting for Redis to be ready (via Container CLI)..."
MAX_RETRIES=30
RETRY=0
AUTH_CMD=""

# Logic for AUTH_CMD based on available identity
if [ ! -z "$REDIS_USER" ] && [ "$MODE" == "redis-tls" ]; then
    # TLS + ACL mode
    AUTH_CMD="--tls --cert /certs/redis.crt --key /certs/redis.key --cacert /certs/ca.crt --user $REDIS_USER -a $REDIS_PASSWORD"
elif [ ! -z "$REDIS_USER" ]; then
    # ACL Plaintext mode
    AUTH_CMD="--user $REDIS_USER -a $REDIS_PASSWORD"
elif [ ! -z "$REDIS_PASSWORD" ]; then
    # Legacy Password Only mode
    AUTH_CMD="-a $REDIS_PASSWORD"
fi

until docker exec $CONTAINER_NAME redis-cli $AUTH_CMD PING 2>/dev/null | grep -q "PONG"; do
    RETRY=$((RETRY+1))
    if [ $RETRY -ge $MAX_RETRIES ]; then
        echo "    >>> Error: Redis failed to start."
        exit 1
    fi
    echo -n "."
    sleep 2
done
echo ""
echo "    >>> Redis Master is READY."

# 1.1 Sentinel Readiness Check (if applicable)
if [ "$MODE" == "redis-sentinel" ]; then
    echo "    >>> Waiting for Redis Sentinel (26379) to be ready..."
    RETRY=0
    until docker exec redis-sentinel redis-cli -p 26379 PING 2>/dev/null | grep -q "PONG"; do
        RETRY=$((RETRY+1))
        if [ $RETRY -ge $MAX_RETRIES ]; then
            echo "    >>> Error: Redis Sentinel failed to start."
            exit 1
        fi
        echo -n "s"
        sleep 2
    done
    echo ""
    echo "    >>> Redis Sentinel is READY."
fi

# 2. Cleanup / Reset
echo "    >>> Flushing existing keys (Clean Slate)..."
docker exec $CONTAINER_NAME redis-cli $AUTH_CMD FLUSHALL || true

# 3. Seed Metadata (Optional)
echo "    >>> Seeding initial metadata..."
docker exec $CONTAINER_NAME redis-cli $AUTH_CMD SET "eip:platform:status" "ONLINE" || true
docker exec $CONTAINER_NAME redis-cli $AUTH_CMD SET "eip:platform:version" "1.0.0-SNAPSHOT" || true

echo ">>> REDIS Platform Initialization Complete."
