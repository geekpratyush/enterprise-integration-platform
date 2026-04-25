#!/bin/bash
# Solace PKI Initializer
# Generates Root CA, Server Certificate, and Client Identity (P12)

set -e

# Use provided directory or default to ./02_initialization/certs
CERT_DIR=${1:-"./02_initialization/certs"}
mkdir -p "${CERT_DIR}"

echo ">>> SOLACE: Initializing PKI Infrastructure..."

# 1. Generate Root CA
openssl genrsa -out ${CERT_DIR}/root-ca.key 4096
openssl req -x509 -new -nodes -key ${CERT_DIR}/root-ca.key -sha256 -days 3650 -out ${CERT_DIR}/root-ca.crt -subj "/CN=Solace-Root-CA"

# 2. Generate Server Key & CSR (localhost)
openssl genrsa -out ${CERT_DIR}/server.key 2048
openssl req -new -key ${CERT_DIR}/server.key -out ${CERT_DIR}/server.csr -subj "/CN=localhost"

# 3. Sign Server Certificate
openssl x509 -req -in ${CERT_DIR}/server.csr -CA ${CERT_DIR}/root-ca.crt -CAkey ${CERT_DIR}/root-ca.key -CAcreateserial -out ${CERT_DIR}/server.crt -days 365 -sha256

# 4. Generate Client Identity (PKCS12) for Camel
openssl genrsa -out ${CERT_DIR}/client.key 2048
openssl req -new -key ${CERT_DIR}/client.key -out ${CERT_DIR}/client.csr -subj "/CN=eip-user"
openssl x509 -req -in ${CERT_DIR}/client.csr -CA ${CERT_DIR}/root-ca.crt -CAkey ${CERT_DIR}/root-ca.key -CAcreateserial -out ${CERT_DIR}/client.crt -days 365 -sha256

openssl pkcs12 -export -in ${CERT_DIR}/client.crt -inkey ${CERT_DIR}/client.key -name "client-identity" -out ${CERT_DIR}/client-key.p12 -passout pass:changeit

# 5. Create Client Truststore containing Root CA
keytool -import -trustcacerts -alias root-ca -file ${CERT_DIR}/root-ca.crt -keystore ${CERT_DIR}/client-trust.p12 -storetype PKCS12 -storepass changeit -noprompt

echo ">>> SOLACE PKI assets generated successfully in ${CERT_DIR}"
chmod 600 ${CERT_DIR}/*.key
