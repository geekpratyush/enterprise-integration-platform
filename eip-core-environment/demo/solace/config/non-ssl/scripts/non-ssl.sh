#!/bin/bash
# non-ssl/scripts/non-ssl.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
DEMO_DIR="$(cd "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"
CONTAINER_DIR="$DEMO_DIR/container"

echo -e "\n\033[36m>>> Starting Solace Non-SSL Infrastructure (Port 55555)...\033[0m"

# 1. Start Solace Standard Node
pushd "$CONTAINER_DIR" >/dev/null
docker compose -f solace-standard.yaml down -v --remove-orphans
docker compose -f solace-standard.yaml up -d
popd >/dev/null

echo -e "\033[33m>>> Waiting for Solace SEMP (Management Interface) to be ready...\033[0m"
MAX_RETRIES=150
RETRY_COUNT=0
until curl -s -f -u admin:admin http://127.0.0.1:8085/SEMP/v2/config/msgVpns > /dev/null; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo -e "\n\033[31m>>> Error: Solace SEMP failed to start after 300s.\033[0m"
        exit 1
    fi
    echo -n "."
    sleep 2
done
echo -e "\n\033[32m>>> Solace SEMP is Ready.\033[0m"

# 2. Unlock Client Profile & ACLs
echo -e "\033[36m>>> Unlocking Security Permissions (Fixes 403)...\033[0m"
# a) Patch Client Profile
curl -s -X PATCH -u admin:admin \
     -H "Content-Type: application/json" \
     -d '{"allowGuaranteedEndpointCreate":true,"allowReceiveGuaranteed":true,"allowGuaranteedMsgSend":true,"allowGuaranteedMsgReceive":true}' \
     http://127.0.0.1:8085/SEMP/v2/config/msgVpns/default/clientProfiles/default > /dev/null

# b) Patch ACL Profile (allow all)
curl -s -X PATCH -u admin:admin \
     -H "Content-Type: application/json" \
     -d '{"clientConnectDefaultAction":"allow","subscribeTopicDefaultAction":"allow","publishTopicDefaultAction":"allow"}' \
     http://127.0.0.1:8085/SEMP/v2/config/msgVpns/default/aclProfiles/default > /dev/null

# 3. Provision Local Queues with explicit Owner
echo -e "\033[36m>>> Provisioning Queue Q.DEMO.1...\033[0m"
MAX_QUEUE_RETRIES=15
QUEUE_RETRY=0
QUEUE_CREATED=false
while [ $QUEUE_RETRY -lt $MAX_QUEUE_RETRIES ]; do
    if curl -s -f -u admin:admin http://127.0.0.1:8085/SEMP/v2/config/msgVpns/default/queues/Q.DEMO.1 > /dev/null; then
        echo -e "\033[32m>>> Queue Q.DEMO.1 is ACTIVE and Verified.\033[0m"
        QUEUE_CREATED=true
        break
    else
        # Create with 'default' owner and 'consume' permission
        curl -s -X POST -u admin:admin \
             -H "Content-Type: application/json" \
             -d '{"msgVpnName":"default","queueName":"Q.DEMO.1","egressEnabled":true,"ingressEnabled":true,"permission":"consume","owner":"default"}' \
             http://127.0.0.1:8085/SEMP/v2/config/msgVpns/default/queues > /dev/null
        sleep 3
        QUEUE_RETRY=$((QUEUE_RETRY + 1))
    fi
done

if [ "$QUEUE_CREATED" = false ]; then
    echo -e "\033[31m>>> Error: Critical failure creating or verifying Queue Q.DEMO.1.\033[0m"
    exit 1
fi

echo -e "\033[32m>>> Solace Non-SSL Silo Ready.\033[0m"
