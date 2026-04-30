#!/bin/bash
# 02_initialization/setup-pki.sh - CONFLUENT KAFKA SECURITY PREP

EIP_INIT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CERT_DIR=~/.eip/certs/ckafka
PASSWORD="password"

echo -e "\033[36m>>> CONFLUENT KAFKA: Initializing PKI Infrastructure...\033[0m"

# Deep Clean the target directory
mkdir -p "$CERT_DIR"
rm -f "$CERT_DIR"/*.key "$CERT_DIR"/*.crt "$CERT_DIR"/*.p12 "$CERT_DIR"/*.conf "$CERT_DIR"/*.srl

# 1. Root CA
openssl genrsa -out "$CERT_DIR/root.key" 2048
openssl req -x509 -new -nodes -key "$CERT_DIR/root.key" -sha256 -days 3650 -out "$CERT_DIR/root.crt" -subj "/CN=EIP-Root-CA"

# 2. Server Key/Cert (for mTLS bound to 127.0.0.1 and container name)
openssl genrsa -out "$CERT_DIR/server.key" 2048
openssl req -new -key "$CERT_DIR/server.key" -out "$CERT_DIR/server.csr" -subj "/CN=localhost"
cat <<EOF > "$CERT_DIR/server_ext.conf"
subjectAltName = DNS:localhost,DNS:ckafka-platform,IP:127.0.0.1
EOF
openssl x509 -req -in "$CERT_DIR/server.csr" -CA "$CERT_DIR/root.crt" -CAkey "$CERT_DIR/root.key" -CAcreateserial -out "$CERT_DIR/server.crt" -days 365 -sha256 -extfile "$CERT_DIR/server_ext.conf"

# Export Server Keystore (PKCS12)
openssl pkcs12 -export -in "$CERT_DIR/server.crt" -inkey "$CERT_DIR/server.key" -certfile "$CERT_DIR/root.crt" -out "$CERT_DIR/audit-keystore.p12" -name eip-server -passout pass:$PASSWORD

# Server TrustStore (Import Root CA)
keytool -import -trustcacerts -alias root-ca -file "$CERT_DIR/root.crt" -keystore "$CERT_DIR/audit-truststore.p12" -storetype PKCS12 -storepass $PASSWORD -noprompt

# 3. Client Key/Cert (for mTLS)
openssl genrsa -out "$CERT_DIR/client.key" 2048
openssl req -new -key "$CERT_DIR/client.key" -out "$CERT_DIR/client.csr" -subj "/CN=client"
openssl x509 -req -in "$CERT_DIR/client.csr" -CA "$CERT_DIR/root.crt" -CAkey "$CERT_DIR/root.key" -CAcreateserial -out "$CERT_DIR/client.crt" -days 365 -sha256

# Export Client Keystore (PKCS12)
openssl pkcs12 -export -in "$CERT_DIR/client.crt" -inkey "$CERT_DIR/client.key" -certfile "$CERT_DIR/root.crt" -out "$CERT_DIR/client.keystore.p12" -name eip-client -passout pass:$PASSWORD

# 4. Finalize Permissions (Ensures Docker and User can both Read/Write)
echo "$PASSWORD" > "$CERT_DIR/password"
chmod 666 "$CERT_DIR"/*
echo -e "\033[32m>>> CONFLUENT KAFKA PKI assets generated successfully.\033[0m"
