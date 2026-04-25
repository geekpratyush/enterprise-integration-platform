#!/bin/bash
# setup-pki.sh
# Purpose: Generates SAN-compliant, Java-compatible PKI assets for MongoDB SSL/mTLS scenarios.

SCENARIO=$1
if [ -z "$SCENARIO" ]; then
    echo "Usage: $0 <scenario-name>"
    exit 1
fi

EIP_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CERT_DIR="${EIP_SCRIPT_DIR}/certs/${SCENARIO}"
mkdir -p "$CERT_DIR"

echo ">>> MONGODB: Initializing PKI assets for [${SCENARIO}]..."

# 1. Create CA
if [ ! -f "$CERT_DIR/root.crt" ]; then
    openssl genrsa -out "$CERT_DIR/root.key" 2048 > /dev/null 2>&1
    openssl req -x509 -new -nodes -key "$CERT_DIR/root.key" -sha256 -days 1024 -out "$CERT_DIR/root.crt" -subj "/CN=EIP-Platform-Root-CA" > /dev/null 2>&1
fi

# 2. Server Certificate (SAN Compliant + Java Friendly KeyUsage)
openssl genrsa -out "${CERT_DIR}/mongodb.key" 2048 > /dev/null 2>&1

cat > "${CERT_DIR}/mongodb.cnf" <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no
[req_distinguished_name]
CN = 127.0.0.1
[v3_req]
keyUsage = critical, digitalSignature, keyEncipherment, keyAgreement
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = localhost
IP.1 = 127.0.0.1
EOF

openssl req -new -key "${CERT_DIR}/mongodb.key" -out "${CERT_DIR}/mongodb.csr" -config "${CERT_DIR}/mongodb.cnf" > /dev/null 2>&1
openssl x509 -req -in "${CERT_DIR}/mongodb.csr" -CA "${CERT_DIR}/root.crt" -CAkey "${CERT_DIR}/root.key" \
  -CAcreateserial -out "${CERT_DIR}/mongodb.crt" -days 365 -sha256 -extfile "${CERT_DIR}/mongodb.cnf" -extensions v3_req > /dev/null 2>&1

# Create MongoDB PEM (Cert + Key)
cat "${CERT_DIR}/mongodb.crt" "${CERT_DIR}/mongodb.key" > "${CERT_DIR}/mongodb.pem"

# 3. Client Certificate (for mTLS Scenarios)
if [[ "$SCENARIO" == *"mtls"* ]]; then
    openssl genrsa -out "$CERT_DIR/client.key" 2048 > /dev/null 2>&1
    
    cat > "${CERT_DIR}/client.cnf" <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no
[req_distinguished_name]
CN = eip-client
[v3_req]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
EOF

    openssl req -new -key "$CERT_DIR/client.key" -out "$CERT_DIR/client.csr" -config "${CERT_DIR}/client.cnf" > /dev/null 2>&1
    openssl x509 -req -in "$CERT_DIR/client.csr" -CA "$CERT_DIR/root.crt" -CAkey "$CERT_DIR/root.key" \
        -CAcreateserial -out "$CERT_DIR/client.crt" -days 365 -sha256 -extfile "${CERT_DIR}/client.cnf" -extensions v3_req > /dev/null 2>&1

    # Export to P12 for Java/Quarkus
    openssl pkcs12 -export -in "$CERT_DIR/client.crt" -inkey "$CERT_DIR/client.key" \
        -out "$CERT_DIR/client.p12" -name "mongodb-client" -passout pass:changeit > /dev/null 2>&1
fi

# 4. Java TrustStore (Standard JKS/P12 for Liquibase/CLI)
if [[ "$SCENARIO" == *"ssl"* ]] || [[ "$SCENARIO" == *"mtls"* ]]; then
    # Delete existing truststore if it exists to avoid duplicate entries
    rm -f "$CERT_DIR/truststore.p12"
    # Use keytool to import the Root CA as a Trusted Certificate
    keytool -importcert -trustcacerts -file "$CERT_DIR/root.crt" \
        -keystore "$CERT_DIR/truststore.p12" -storetype PKCS12 \
        -alias "root-ca" -storepass changeit -noprompt > /dev/null 2>&1
fi

# Hardening permissions
chmod 644 "${CERT_DIR}/mongodb.pem" "${CERT_DIR}/root.crt"
if [ -f "$CERT_DIR/client.p12" ]; then chmod 644 "$CERT_DIR/client.p12"; fi
if [ -f "$CERT_DIR/truststore.p12" ]; then chmod 644 "$CERT_DIR/truststore.p12"; fi

echo "    PKI Generation Complete. Assets ready in certs/${SCENARIO}"

if [[ "$SCENARIO" == *"change-stream"* ]]; then
    openssl rand -base64 756 > "${CERT_DIR}/replica.key"
    chmod 644 "${CERT_DIR}/replica.key"
fi
