#!/bin/bash
# ssl-jms/scripts/ssl-jms.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
DEMO_DIR="$(cd "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"
CONTAINER_DIR="$DEMO_DIR/container"
CERT_DIR="$DEMO_DIR/certs"

echo -e "\n\033[36m>>> Starting Solace SSL (One-way) Infrastructure...\033[0m"

# 1. Start Solace Standard Node
pushd "$CONTAINER_DIR" >/dev/null
docker compose -f solace-standard.yaml down -v --remove-orphans
docker compose -f solace-standard.yaml up -d
popd >/dev/null

echo -e "\033[33m>>> Waiting for Solace SEMP (Management Interface) to be ready...\033[0m"
MAX_RETRIES=150
RETRY_COUNT=0
until curl -s -k -f -u admin:admin http://127.0.0.1:8085/SEMP/v2/config/msgVpns > /dev/null; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo -e "\n\033[31m>>> Error: Solace SEMP failed to start.\033[0m"
        docker logs solace-ssl | tail -n 20
        return 1
    fi
    echo -n "."
    sleep 2
done
echo -e "\n\033[32m>>> Solace SEMP is Ready.\033[0m"

# 2. Upload server TLS certificate and private key to the broker
# Without this step the broker has no cert to present and immediately closes the TLS handshake.
echo -e "\033[36m>>> Uploading server TLS certificate to broker...\033[0m"
if [ ! -f "$CERT_DIR/server.crt" ] || [ ! -f "$CERT_DIR/server.key" ]; then
    echo -e "\033[31m>>> Error: server.crt or server.key not found in $CERT_DIR\033[0m"
    return 1
fi
# Combine cert + key into a single PEM bundle and JSON-encode (escape newlines)
CERT_AND_KEY_JSON=$(cat "$CERT_DIR/server.crt" "$CERT_DIR/server.key" | \
    python3 -c "import sys, json; print(json.dumps(sys.stdin.read()))" 2>/dev/null)
if [ -z "$CERT_AND_KEY_JSON" ]; then
    # Fallback: manual newline escaping without python3
    CERT_AND_KEY_JSON="\"$(cat "$CERT_DIR/server.crt" "$CERT_DIR/server.key" | awk '{printf "%s\\n", $0}')\""
fi
SEMP_RESULT=$(curl -s -k -o /dev/null -w "%{http_code}" -X PATCH -u admin:admin \
    -H "Content-Type: application/json" \
    -d "{\"tlsServerCertContent\":$CERT_AND_KEY_JSON}" \
    http://127.0.0.1:8085/SEMP/v2/config/)
if [ "$SEMP_RESULT" != "200" ]; then
    echo -e "\033[31m>>> Error: Failed to upload server certificate (HTTP $SEMP_RESULT). Check SEMP API response.\033[0m"
    return 1
fi
echo -e "\033[32m>>> Server certificate uploaded (HTTP $SEMP_RESULT).\033[0m"

# 3. Smart Verification Loop — wait for SSL port to become reachable
echo -e "\033[33m>>> Waiting for SSL Handshake Readiness (Port 55443)...\033[0m"
MAX_INIT_RETRIES=60
INIT_RETRY=0
while [ $INIT_RETRY -lt $MAX_INIT_RETRIES ]; do
    if echo -n | openssl s_client -connect 127.0.0.1:55443 2>/dev/null | grep -q "CONNECTED"; then
        echo -e "\n\033[32m>>> SSL Messaging Engine is ONLINE and Handshake-Verified.\033[0m"
        break
    fi
    echo -n "."
    sleep 5
    INIT_RETRY=$((INIT_RETRY + 1))
    if [ $INIT_RETRY -eq $MAX_INIT_RETRIES ]; then
        echo -e "\n\033[31m>>> Error: SSL Engine handshake failed after multiple attempts.\033[0m"
        echo -e "\033[33m>>> Broker Internal Events:\033[0m"
        docker exec solace-ssl cat /usr/sw/var/soltr/log/event.log | tail -n 20 2>/dev/null
        return 1
    fi
done

# 4. Final Security Patches
curl -s -k -X PATCH -u admin:admin -H "Content-Type: application/json" -d '{"allowGuaranteedEndpointCreate":true,"allowReceiveGuaranteed":true,"allowGuaranteedMsgSend":true,"allowGuaranteedMsgReceive":true,"allowTransactedSessions":true}' http://127.0.0.1:8085/SEMP/v2/config/msgVpns/default/clientProfiles/default > /dev/null
curl -s -k -X PATCH -u admin:admin -H "Content-Type: application/json" -d '{"clientConnectDefaultAction":"allow","subscribeTopicDefaultAction":"allow","publishTopicDefaultAction":"allow"}' http://127.0.0.1:8085/SEMP/v2/config/msgVpns/default/aclProfiles/default > /dev/null

# 5. Provision Queue — retry loop to handle brief SEMP unavailability after cert reload
echo -e "\033[33m>>> Provisioning queue Q.DEMO.SSL...\033[0m"
QUEUE_MAX_RETRIES=10
QUEUE_RETRY=0
while [ $QUEUE_RETRY -lt $QUEUE_MAX_RETRIES ]; do
    Q_RESULT=$(curl -s -k -o /dev/null -w "%{http_code}" -X POST -u admin:admin \
        -H "Content-Type: application/json" \
        -d '{"msgVpnName":"default","queueName":"Q.DEMO.SSL","egressEnabled":true,"ingressEnabled":true,"permission":"consume","owner":"default"}' \
        http://127.0.0.1:8085/SEMP/v2/config/msgVpns/default/queues)
    # 200/201 = created, 400 with "already exists" is also fine — check for non-5xx
    if [ "$Q_RESULT" = "200" ] || [ "$Q_RESULT" = "201" ]; then
        echo -e "\033[32m>>> Queue Q.DEMO.SSL provisioned (HTTP $Q_RESULT).\033[0m"
        break
    elif [ "$Q_RESULT" = "400" ]; then
        # 400 can mean "already exists" — verify by checking if queue is present
        QUEUE_EXISTS=$(curl -s -k -u admin:admin \
            http://127.0.0.1:8085/SEMP/v2/config/msgVpns/default/queues/Q.DEMO.SSL \
            | grep -c '"queueName"')
        if [ "$QUEUE_EXISTS" -gt 0 ]; then
            echo -e "\033[32m>>> Queue Q.DEMO.SSL already exists.\033[0m"
            break
        fi
    fi
    QUEUE_RETRY=$((QUEUE_RETRY + 1))
    if [ $QUEUE_RETRY -eq $QUEUE_MAX_RETRIES ]; then
        echo -e "\033[31m>>> Error: Failed to provision queue Q.DEMO.SSL after $QUEUE_MAX_RETRIES attempts (last HTTP $Q_RESULT).\033[0m"
        return 1
    fi
    echo -n "."
    sleep 3
done

echo -e "\033[32m>>> Solace SSL Track Ready.\033[0m"
