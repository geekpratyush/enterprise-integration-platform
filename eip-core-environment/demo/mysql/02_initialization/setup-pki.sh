#!/bin/bash
# setup-pki.sh (MySQL Edition)
# MISSION: Generate SSL certificates for MySQL secure track
# ----------------------------------------------------------------------

set -e

BASE_CERT_DIR="/home/pratyush/software/eip-core-integration/eip-core-environment/demo/mysql/02_initialization/certs"
CERT_DIR="${BASE_CERT_DIR}/${MODE:-ssl-mysql}"
mkdir -p "$CERT_DIR"

echo ">>> MYSQL PKI: Generating Certificates (${MODE:-ssl-mysql})..."

# 0. Clean Slate
rm -rf $CERT_DIR/*.pem $CERT_DIR/*.p12 $CERT_DIR/*.pk8

# 1. Generate Root CA
openssl genrsa 2048 > $CERT_DIR/ca-key.pem
openssl req -new -x509 -nodes -days 3650 \
    -key $CERT_DIR/ca-key.pem \
    -out $CERT_DIR/ca-cert.pem \
    -subj "/CN=mysql-root-ca"

# 2. Generate Server Certificate
openssl req -newkey rsa:2048 -nodes \
    -keyout $CERT_DIR/server-key.pem \
    -out $CERT_DIR/server-req.pem \
    -subj "/CN=mysql-platform"

openssl rsa -in $CERT_DIR/server-key.pem -out $CERT_DIR/server-key.pem

openssl x509 -req -in $CERT_DIR/server-req.pem -days 3650 \
    -CA $CERT_DIR/ca-cert.pem -CAkey $CERT_DIR/ca-key.pem \
    -set_serial 01 -out $CERT_DIR/server-cert.pem

# 3. Generate Client Certificate (for Java App / mTLS)
openssl req -newkey rsa:2048 -nodes \
    -keyout $CERT_DIR/client-key.pem \
    -out $CERT_DIR/client-req.pem \
    -subj "/CN=mysql-client"

openssl rsa -in $CERT_DIR/client-key.pem -out $CERT_DIR/client-key.pem

openssl x509 -req -in $CERT_DIR/client-req.pem -days 3650 \
    -CA $CERT_DIR/ca-cert.pem -CAkey $CERT_DIR/ca-key.pem \
    -set_serial 02 -out $CERT_DIR/client-cert.pem

# 4. Packaging for Java (EIP Platform)
echo "    >>> Converting Client Key to PKCS#8 (For JDBC)..."
openssl pkcs8 -topk8 -inform PEM -outform DER -in $CERT_DIR/client-key.pem -out $CERT_DIR/client-key.pk8 -nocrypt

echo "    >>> Creating Truststore and Keystore for EIP Platform..."
# Truststore (for verify-ca)
keytool -importcert -alias mysql-ca -file $CERT_DIR/ca-cert.pem \
    -keystore $CERT_DIR/mysql-truststore.p12 -storetype PKCS12 \
    -storepass changeit -noprompt

# Client Keystore (for mTLS identity) - Synchronized to 'mysql-keystore.p12'
openssl pkcs12 -export -in $CERT_DIR/client-cert.pem -inkey $CERT_DIR/client-key.pem \
    -out $CERT_DIR/mysql-keystore.p12 -name "mysql-client" \
    -passout pass:changeit

# 5. Fix permissions for MySQL container
chmod 644 $CERT_DIR/*.pem $CERT_DIR/*.p12 $CERT_DIR/*.pk8 2>/dev/null || true

echo ">>> MYSQL PKI: Generation Complete."
ls -l $CERT_DIR
