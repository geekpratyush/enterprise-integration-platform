#!/bin/bash
SCENARIO=$1
if [[ -z "$SCENARIO" ]]; then
    echo "ERROR: Scenario name required for PKI initialization."
    exit 1
fi

EIP_INIT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CERT_DIR=~/.eip/certs/ibmmq/$SCENARIO
STORE_PASS="changeit"

echo -e "\033[36m>>> IBMMQ: Initializing PKI assets for [$SCENARIO]...\033[0m"

# 1. SCENARIO DIRECTORY PREP
mkdir -p "$CERT_DIR"

# 2. GENERATE PKCS12 ASSETS (HOST SIDE)
echo "    Generating MQ Server Identity (audit-keystore.p12)..."
keytool -genkeypair -alias mqserver -keyalg RSA -keysize 2048 -validity 365 \
  -keystore "$CERT_DIR/audit-keystore.p12" -storepass $STORE_PASS -storetype PKCS12 \
  -dname "CN=localhost, OU=EIP, O=EipPlatform" -ext "SAN=dns:localhost,ip:127.0.0.1" -noprompt

echo "    Generating Client Identity (client-key.p12)..."
keytool -genkeypair -alias mqclient -keyalg RSA -keysize 2048 -validity 365 \
  -keystore "$CERT_DIR/client-key.p12" -storepass $STORE_PASS -storetype PKCS12 \
  -dname "CN=EipClient, OU=CoreIntegration" -noprompt

# 3. MQ CONTAINER READINESS
echo ">>> Waiting for IBMMQ container bootstrap (QM1)..."
for i in {1..20}; do
    if docker exec ibmmq-platform dspmq 2>/dev/null | grep -q "Running"; then
        echo -e "\033[32m>>> MQ is READY.\033[0m"
        break
    fi
    sleep 5
done

# 4. INTERNAL DIRECTORY FORCE-PREP
echo "    Preparing internal certs directory (Scenario: $SCENARIO)..."
docker exec -u root ibmmq-platform bash -c "mkdir -p /var/mqm/ssl-certs && chown 888:888 /var/mqm/ssl-certs && chmod 777 /var/mqm/ssl-certs"

# 5. INITIALIZE KEY DATABASE (CMS Format)
echo "    Creating Key Database inside container..."
docker exec -u root ibmmq-platform runmqakm -keydb -create -db /var/mqm/ssl-certs/mqserver.kdb -pw $STORE_PASS -type cms -stash
docker exec -u root ibmmq-platform runmqakm -cert -import -db /var/mqm/ssl-certs/audit-keystore.p12 -pw $STORE_PASS -type pkcs12 -target /var/mqm/ssl-certs/mqserver.kdb -target_pw $STORE_PASS -target_type cms -label mqserver

# 5.1 MUTUAL TLS: Import Client into MQ Trust
if [[ "$SCENARIO" == *"mtls"* ]]; then
    echo "    [mTLS] Importing Client Cert into MQ Trust..."
    docker exec -u root ibmmq-platform runmqakm -cert -import -db /var/mqm/ssl-certs/client-key.p12 -pw $STORE_PASS -type pkcs12 -target /var/mqm/ssl-certs/mqserver.kdb -target_pw $STORE_PASS -target_type cms -label mqclient
fi

# Final permission fix-up
docker exec -u root ibmmq-platform bash -c "chown 888:888 /var/mqm/ssl-certs/* && chmod 644 /var/mqm/ssl-certs/*"

# 6. VERIFICATION
echo ">>> Verifying Internal MQ Certificates:"
docker exec ibmmq-platform runmqakm -cert -list -db /var/mqm/ssl-certs/mqserver.kdb -stashed

# 7. APPLY MQSC POLICIES
echo ">>> Applying SSL Policies to QM1 (Scenario: $SCENARIO)..."
SSL_AUTH="OPTIONAL"
[[ "$SCENARIO" == *"mtls"* ]] && SSL_AUTH="REQUIRED"

docker exec -i ibmmq-platform runmqsc QM1 << MQSC
ALTER QMGR SSLKEYR('/var/mqm/ssl-certs/mqserver') CERTLABL('mqserver')
ALTER CHANNEL(DEV.APP.SVRCONN) CHLTYPE(SVRCONN) SSLCIPH(ECDHE_RSA_AES_256_GCM_SHA384) SSLCAUTH($SSL_AUTH)
SET CHLAUTH(DEV.APP.SVRCONN) TYPE(ADDRESSMAP) ADDRESS('*') USERSRC(CHANNEL) ACTION(REPLACE)
DEFINE QLOCAL(DEV.QUEUE.1) DEFPSIST(YES) REPLACE
REFRESH SECURITY TYPE(SSL)
MQSC

echo -e "\033[32m>>> IBMMQ security initialization complete.\033[0m"
