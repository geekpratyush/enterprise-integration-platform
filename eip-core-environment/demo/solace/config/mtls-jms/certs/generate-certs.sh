#!/bin/bash
# config/mtls-jms/certs/generate-certs.sh

CERT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

echo "Generating mTLS Certificates for Solace Demo..."
rm -f "$CERT_DIR"/*.p12 "$CERT_DIR"/*.crt "$CERT_DIR"/*.key "$CERT_DIR"/*.csr "$CERT_DIR"/*.srl

# 1. Generate CA
openssl genrsa -out "$CERT_DIR/ca.key" 2048
openssl req -x509 -new -nodes -key "$CERT_DIR/ca.key" -sha256 -days 365 \
    -out "$CERT_DIR/ca.crt" -subj "/CN=SolaceDemoCA"

# 2. Generate Server Cert (signed by CA, CN=localhost for local demo)
#    The broker presents this cert during the TLS handshake.
openssl genrsa -out "$CERT_DIR/server.key" 2048
openssl req -new -key "$CERT_DIR/server.key" -out "$CERT_DIR/server.csr" \
    -subj "/C=US/ST=Demo/L=Demo/O=EIP/CN=localhost"
openssl x509 -req -in "$CERT_DIR/server.csr" -CA "$CERT_DIR/ca.crt" -CAkey "$CERT_DIR/ca.key" \
    -CAcreateserial -out "$CERT_DIR/server.crt" -days 365 -sha256

# 3. Generate Client Cert (signed by CA, CN=worldgeek — broker validates this)
openssl genrsa -out "$CERT_DIR/client.key" 2048
openssl req -new -key "$CERT_DIR/client.key" -out "$CERT_DIR/client.csr" \
    -subj "/CN=worldgeek"
openssl x509 -req -in "$CERT_DIR/client.csr" -CA "$CERT_DIR/ca.crt" -CAkey "$CERT_DIR/ca.key" \
    -CAcreateserial -out "$CERT_DIR/client.crt" -days 365 -sha256

# 4. Create Client KeyStore (PKCS12) — client presents this to the broker
openssl pkcs12 -export -in "$CERT_DIR/client.crt" -inkey "$CERT_DIR/client.key" \
    -out "$CERT_DIR/client-key.p12" -name client-cert -passout pass:changeit

# 5. Create Client TrustStore (PKCS12 containing CA) — client uses this to validate broker's server cert
keytool -import -trustcacerts -alias solace-ca -file "$CERT_DIR/ca.crt" \
    -keystore "$CERT_DIR/client-trust.p12" -storepass changeit -noprompt -storetype PKCS12

echo "Certificates generated in $CERT_DIR"
