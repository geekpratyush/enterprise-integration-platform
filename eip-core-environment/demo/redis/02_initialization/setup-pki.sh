#!/bin/bash
# setup-pki.sh
# Industrialized Certificate Generator for Redis TLS
# Usage: Expects $MODE to be exported (e.g., redis-tls)
# ----------------------------------------------------------------------

set -e

BASE_CERT_DIR=~/software/eip-core-integration/eip-core-environment/demo/redis/02_initialization/certs
CERT_DIR="${BASE_CERT_DIR}/${MODE:-redis-tls}"
mkdir -p "$CERT_DIR"

echo ">>> REDIS PKI: Generating Certificates (${MODE:-redis-tls})..."

# 0. Clean Slate
rm -rf $CERT_DIR/*.crt $CERT_DIR/*.key $CERT_DIR/*.p12 $CERT_DIR/*.csr $CERT_DIR/*.srl

# 1. Create Root CA
openssl genrsa -out $CERT_DIR/ca.key 4096
openssl req -x509 -new -nodes -sha256 -key $CERT_DIR/ca.key -days 3650 \
    -subj "/CN=Redis-CA" -out $CERT_DIR/ca.crt

# 2. Create Redis Server Cert
openssl genrsa -out $CERT_DIR/redis.key 2048
openssl req -new -sha256 -key $CERT_DIR/redis.key \
    -subj "/CN=redis-platform" -out $CERT_DIR/redis.csr
openssl x509 -req -in $CERT_DIR/redis.csr -CA $CERT_DIR/ca.crt -CAkey $CERT_DIR/ca.key \
    -CAcreateserial -out $CERT_DIR/redis.crt -days 365 -sha256

# 3. Create Client Truststore for Java (P12)
echo "    >>> Packaging Truststore for EIP Platform..."
keytool -import -trustcacerts -alias redis-ca -file $CERT_DIR/ca.crt \
    -keystore $CERT_DIR/redis-truststore.p12 -storetype PKCS12 \
    -storepass changeit -noprompt

# 4. Create Client Keystore (P12) for mTLS
echo "    >>> Packaging Client Keystore for mTLS..."
openssl pkcs12 -export -in $CERT_DIR/redis.crt -inkey $CERT_DIR/redis.key \
    -out $CERT_DIR/redis-client.p12 -name redis-client \
    -CAfile $CERT_DIR/ca.crt -caname redis-ca -passout pass:changeit

# 5. Permissions Fix for Docker
echo "    >>> Fixing permissions for Docker volume mounts..."
chmod 644 $CERT_DIR/*.crt
chmod 644 $CERT_DIR/*.key
chmod 644 $CERT_DIR/*.p12

echo ">>> REDIS PKI: Generation Complete (${MODE:-redis-tls})."
ls -l $CERT_DIR
