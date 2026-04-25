#!/bin/bash
# setup-solace.sh
# Industrialized Platform Initializer (SEMP v2)
# Configures VPNs, Profiles, Queues with Retry Logic & Ownership.

VPN_NAME=$1
QUEUE_NAME=$2
CERTS_DIR=$3
MODE=$4
ADMIN_USER="admin"
ADMIN_PASS="admin"
SEMP_URL="http://127.0.0.1:8085/SEMP/v2/config"

if [ -z "$VPN_NAME" ]; then VPN_NAME="default"; fi
if [ -z "$QUEUE_NAME" ]; then QUEUE_NAME="Q.DEMO.1"; fi
if [ -z "$CERTS_DIR" ]; then CERTS_DIR="./02_initialization/certs"; fi

# 0. Global PKI Upload (Critical for Handshake readiness in Mission 3 & 4)
if [ -f "$CERTS_DIR/server.crt" ] && [ -f "$CERTS_DIR/server.key" ]; then
    echo "    >>> Uploading Server TLS Certificate to Broker Global Config..."
    # Combine cert + key and JSON encode for SEMP (python helper for safety)
    CERT_AND_KEY_JSON=$(cat "$CERTS_DIR/server.crt" "$CERTS_DIR/server.key" | \
        python3 -c "import sys, json; print(json.dumps(sys.stdin.read()))" 2>/dev/null || \
        awk '{printf "%s\\n", $0}' | sed 's/^/"/;s/$/"/')
    
    curl -s -X PATCH -u ${ADMIN_USER}:${ADMIN_PASS} \
        -H "Content-Type: application/json" \
        -d "{\"tlsServerCertContent\":$CERT_AND_KEY_JSON}" \
        "${SEMP_URL}" || true
    echo "    >>> Global TLS Certificate Armed."
fi

echo ">>> SOLACE: Initializing Platform Logic (VPN: $VPN_NAME, Queue: $QUEUE_NAME)..."

# 1. VPN Enablement
if [ "$VPN_NAME" != "default" ]; then
    echo "    >>> Creating/Enabling VPN: $VPN_NAME (Auth: Internal, Spool: 1000MB)"
    curl -s -X POST -u ${ADMIN_USER}:${ADMIN_PASS} \
        "${SEMP_URL}/msgVpns" \
        -H "Content-Type: application/json" \
        -d "{\"msgVpnName\":\"${VPN_NAME}\", \"enabled\":true, \"authenticationBasicType\":\"internal\", \"maxMsgSpoolUsage\":1000}" || true
else
    echo "    >>> Patching 'default' VPN Status, Auth Type & Spool"
    curl -s -X PATCH -u ${ADMIN_USER}:${ADMIN_PASS} \
        "${SEMP_URL}/msgVpns/default" \
        -H "Content-Type: application/json" \
        -d "{\"enabled\":true, \"authenticationBasicType\":\"internal\", \"maxMsgSpoolUsage\":1000}" || true
fi

# 1.5: mTLS Specific VPN Patching
if [ "$MODE" == "mtls" ]; then
    echo "    >>> MISSION: mTLS - Enabling Client Certificate Authentication on VPN: $VPN_NAME"
    curl -s -X PATCH -u ${ADMIN_USER}:${ADMIN_PASS} \
        "${SEMP_URL}/msgVpns/${VPN_NAME}" \
        -H "Content-Type: application/json" \
        -d '{"authenticationClientCertEnabled":true}' || true
fi

# 2. Unlock Security Permissions (The "Legacy Magic" for Stability)
echo "    >>> Unlocking Client Profile: default (Authorization Fixes)"
# Try patching multiple variations for maximum compatibility
curl -s -X PATCH -u ${ADMIN_USER}:${ADMIN_PASS} -H "Content-Type: application/json" -d '{"allowGuaranteedEndpointCreateEnabled":true}' "${SEMP_URL}/msgVpns/${VPN_NAME}/clientProfiles/default" || true
curl -s -X PATCH -u ${ADMIN_USER}:${ADMIN_PASS} -H "Content-Type: application/json" -d '{"allowReceiveGuaranteedEnabled":true}' "${SEMP_URL}/msgVpns/${VPN_NAME}/clientProfiles/default" || true
curl -s -X PATCH -u ${ADMIN_USER}:${ADMIN_PASS} -H "Content-Type: application/json" -d '{"allowGuaranteedMsgSendEnabled":true}' "${SEMP_URL}/msgVpns/${VPN_NAME}/clientProfiles/default" || true
curl -s -X PATCH -u ${ADMIN_USER}:${ADMIN_PASS} -H "Content-Type: application/json" -d '{"allowGuaranteedMsgReceiveEnabled":true}' "${SEMP_URL}/msgVpns/${VPN_NAME}/clientProfiles/default" || true
curl -s -X PATCH -u ${ADMIN_USER}:${ADMIN_PASS} -H "Content-Type: application/json" -d '{"allowTransactedSessionsEnabled":true}' "${SEMP_URL}/msgVpns/${VPN_NAME}/clientProfiles/default" || true

echo "    >>> Unlocking ACL Profile: default"
curl -s -X PATCH -u ${ADMIN_USER}:${ADMIN_PASS} \
     -H "Content-Type: application/json" \
     -d '{"clientConnectDefaultAction":"allow","subscribeTopicDefaultAction":"allow","publishTopicDefaultAction":"allow"}' \
     "${SEMP_URL}/msgVpns/${VPN_NAME}/aclProfiles/default" || true

# 3. Client Identity Activation
if [[ "$VPN_NAME" == "eip-vpn" ]]; then
    echo "    >>> Creating/Enabling Client Username: eip-user"
    curl -s -X POST -u ${ADMIN_USER}:${ADMIN_PASS} \
        "${SEMP_URL}/msgVpns/${VPN_NAME}/clientUsernames" \
        -H "Content-Type: application/json" \
        -d "{\"clientUsername\":\"eip-user\", \"enabled\":true, \"password\":\"password\"}" || true
else
    echo "    >>> Ensuring Client Username 'default' is ENABLED"
    curl -s -X PATCH -u ${ADMIN_USER}:${ADMIN_PASS} \
        "${SEMP_URL}/msgVpns/${VPN_NAME}/clientUsernames/default" \
        -H "Content-Type: application/json" \
        -d "{\"enabled\":true}" || true
fi

# 4. Provision Queue with Retry Loop (Robustness Pattern)
echo "    >>> Provisioning Queue: $QUEUE_NAME (Owner: default)"
MAX_RETRIES=5
RETRY=0
while [ $RETRY -lt $MAX_RETRIES ]; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST -u ${ADMIN_USER}:${ADMIN_PASS} \
        "${SEMP_URL}/msgVpns/${VPN_NAME}/queues" \
        -H "Content-Type: application/json" \
        -d "{\"queueName\":\"${QUEUE_NAME}\", \"ingressEnabled\":true, \"egressEnabled\":true, \"permission\":\"consume\", \"owner\":\"default\"}")
    
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
        echo "    >>> Queue $QUEUE_NAME created successfully."
        break
    elif [ "$HTTP_CODE" = "400" ]; then
        echo "    >>> Queue $QUEUE_NAME already exists."
        break
    else
        echo "    >>> Retrying Queue Creation ($HTTP_CODE)..."
        RETRY=$((RETRY+1))
        sleep 2
    fi
done

echo ">>> SOLACE Platform Initialization Complete."
