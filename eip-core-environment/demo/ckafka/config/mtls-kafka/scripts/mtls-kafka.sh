#!/bin/bash
# mtls-kafka.sh - Setup mTLS Kafka Environment (Audit PKCS12 Pattern + Confluent 7.4.0)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
CONFIG_DIR="$(cd "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"

echo -e "\033[36m>>> Provisioning Kafka mTLS Environment (Audit Pattern)...\033[0m"

CERT_DIR="$CONFIG_DIR/certs"
# Clean up ALL old certs if we need to regenerate to prevent signature mismatches
if [ "$1" == "--force" ] || [ ! -f "$CERT_DIR/audit-keystore.p12" ]; then
    echo ">>> Cleaning and Generating Kafka Certificates (Audit Pattern PKCS12)..."
    rm -rf "$CERT_DIR"
    mkdir -p "$CERT_DIR"
    
    # 1. Root CA
    openssl genrsa -out "$CERT_DIR/root.key" 2048
    openssl req -x509 -new -nodes -key "$CERT_DIR/root.key" -sha256 -days 3650 -out "$CERT_DIR/root.crt" -subj "/CN=EIP-Root-CA"

    # 2. Server Key/Cert with SAN
    openssl genrsa -out "$CERT_DIR/server.key" 2048
    openssl req -new -key "$CERT_DIR/server.key" -out "$CERT_DIR/server.csr" -subj "/CN=localhost"
    
    cat <<EOF > "$CERT_DIR/server_ext.conf"
subjectAltName = DNS:localhost,DNS:kafka-mtls,IP:127.0.0.1
EOF
    openssl x509 -req -in "$CERT_DIR/server.csr" -CA "$CERT_DIR/root.crt" -CAkey "$CERT_DIR/root.key" -CAcreateserial -out "$CERT_DIR/server.crt" -days 365 -sha256 -extfile "$CERT_DIR/server_ext.conf"
    
    # Export Server Keystore (PKCS12)
    openssl pkcs12 -export -in "$CERT_DIR/server.crt" -inkey "$CERT_DIR/server.key" -certfile "$CERT_DIR/root.crt" -out "$CERT_DIR/audit-keystore.p12" -name eip-server -passout pass:password

    # 3. Server TrustStore (PKCS12)
    keytool -import -trustcacerts -alias root-ca -file "$CERT_DIR/root.crt" -keystore "$CERT_DIR/audit-truststore.p12" -storetype PKCS12 -storepass password -noprompt

    # 4. Client Key/Cert (for mTLS)
    openssl genrsa -out "$CERT_DIR/client.key" 2048
    openssl req -new -key "$CERT_DIR/client.key" -out "$CERT_DIR/client.csr" -subj "/CN=client"
    openssl x509 -req -in "$CERT_DIR/client.csr" -CA "$CERT_DIR/root.crt" -CAkey "$CERT_DIR/root.key" -CAcreateserial -out "$CERT_DIR/client.crt" -days 365 -sha256
    
    # Export Client Keystore (PKCS12)
    openssl pkcs12 -export -in "$CERT_DIR/client.crt" -inkey "$CERT_DIR/client.key" -certfile "$CERT_DIR/root.crt" -out "$CERT_DIR/client.keystore.p12" -name eip-client -passout pass:password
    cp "$CERT_DIR/client.keystore.p12" "$CERT_DIR/client.truststore.p12"

    # 5. Fix Permissions
    chmod 644 "$CERT_DIR/"*
fi

# 8. Admin Client Properties & Password
echo -n "password" > "$CERT_DIR/password"
if [ ! -f "$CERT_DIR/client-admin.properties" ]; then
    cat <<EOF > "$CERT_DIR/client-admin.properties"
security.protocol=SSL
ssl.truststore.location=/etc/kafka/secrets/audit-truststore.p12
ssl.truststore.password=password
ssl.truststore.type=PKCS12
ssl.keystore.location=/etc/kafka/secrets/client.keystore.p12
ssl.keystore.password=password
ssl.keystore.type=PKCS12
ssl.endpoint.identification.algorithm=
EOF
fi

# Ensure container setup is clean
docker compose -f "$CONFIG_DIR/container/kafka-isolated.yaml" down -v --remove-orphans 2>/dev/null
docker compose -f "$CONFIG_DIR/container/kafka-isolated.yaml" up -d

echo -e "\033[33m>>> [1/2] Waiting for Broker (15s)...\033[0m"
sleep 15
docker exec kafka-mtls /usr/bin/kafka-topics --bootstrap-server localhost:9095 --command-config /etc/kafka/secrets/client-admin.properties --create --if-not-exists --topic demo-topic-mtls --partitions 1 --replication-factor 1
docker exec kafka-mtls /usr/bin/kafka-topics --bootstrap-server localhost:9095 --command-config /etc/kafka/secrets/client-admin.properties --create --if-not-exists --topic demo-topic-mtls-out --partitions 1 --replication-factor 1

echo -e "\033[32m>>> Kafka KRaft mTLS Started on Port 9095 (Audit Pattern)\033[0m"

