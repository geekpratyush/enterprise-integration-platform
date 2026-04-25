#!/bin/bash
# ======================================================================
#                POSTGRES PKI AUTOMATION
# ======================================================================

set -e
MODE=${MODE:-ssl-postgres}
BASE_DIR="/home/pratyush/software/eip-core-integration/eip-core-environment/demo/postgres"
CERT_DIR="${BASE_DIR}/02_initialization/certs/${MODE}"

mkdir -p "$CERT_DIR"
cd "$CERT_DIR"
rm -f *.pem *.p12 *.srl *.csr *.req

echo ">>> POSTGRES PKI: Generating Certificates ($MODE)..."

# 1. ROOT CA
openssl genrsa -out ca-key.pem 2048
openssl req -x509 -new -nodes -key ca-key.pem -days 3650 -out ca-cert.pem -subj "/CN=postgres-ca"

# 2. SERVER CERT
openssl genrsa -out server-key.pem 2048
openssl req -new -key server-key.pem -out server-req.pem -subj "/CN=postgres-platform"
openssl x509 -req -in server-req.pem -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial -out server-cert.pem -days 365

# 3. CLIENT CERT (For EIP Platform)
openssl genrsa -out client-key.pem 2048
openssl req -new -key client-key.pem -out client-req.pem -subj "/CN=postgres-client"
openssl x509 -req -in client-req.pem -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial -out client-cert.pem -days 365

# 4. Packaging for Java (EIP Platform)
echo "    >>> Converting Client Key to PKCS#8 (For JDBC)..."
openssl pkcs8 -topk8 -inform PEM -outform DER -in client-key.pem -out client-key.pk8 -nocrypt

echo "    >>> Creating Truststore for EIP Platform..."
openssl pkcs12 -export -in client-cert.pem -inkey client-key.pem -out client-keystore.p12 -name "postgres-client" -passout pass:changeit
keytool -importcert -alias postgres-ca -file ca-cert.pem -keystore postgres-truststore.p12 -storetype PKCS12 -storepass changeit -noprompt

# 5. Fix permissions for Postgres Container
chmod 600 server-key.pem
chmod 644 server-cert.pem ca-cert.pem

echo ">>> POSTGRES PKI: Generation Complete."
ls -l
