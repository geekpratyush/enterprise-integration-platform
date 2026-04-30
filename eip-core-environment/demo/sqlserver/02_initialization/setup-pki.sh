#!/bin/bash
# setup-pki.sh (SQL Server Edition)
set -e

EIP_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
MODE=${MODE:-ssl-sqlserver}
CERT_DIR="${EIP_SCRIPT_DIR}/02_initialization/certs/${MODE}"

mkdir -p "$CERT_DIR"
cd "$CERT_DIR"
rm -f *.pem *.p12 *.pfx *.srl *.csr *.req

echo ">>> SQLSERVER PKI: Generating Certificates ($MODE)..."

# 1. ROOT CA
openssl genrsa -out ca-key.pem 2048
openssl req -x509 -new -nodes -key ca-key.pem -days 3650 -out ca-cert.pem -subj "/CN=sqlserver-ca"

# 2. SERVER CERT (Must have SAN for SQL Server JDBC)
openssl genrsa -out server-key.pem 2048
openssl req -new -key server-key.pem -out server-req.pem -subj "/CN=localhost" \
  -addext "subjectAltName = DNS:localhost, IP:127.0.0.1"
openssl x509 -req -in server-req.pem -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial \
  -out server-cert.pem -days 365 -copy_extensions copyall

# 3. CLIENT CERT (For Mutual TLS)
openssl genrsa -out client-key.pem 2048
openssl req -new -key client-key.pem -out client-req.pem -subj "/CN=sqlserver-client"
openssl x509 -req -in client-req.pem -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial -out client-cert.pem -days 365

# 4. Packaging for SQL Server (PFX for Container)
openssl pkcs12 -export -out mssql.pfx -inkey server-key.pem -in server-cert.pem -passout pass:changeit

# 5. Packaging for Java (EIP Trust/Key)
keytool -importcert -alias sqlserver-ca -file ca-cert.pem \
    -keystore sqlserver-truststore.p12 -storetype PKCS12 \
    -storepass changeit -noprompt

openssl pkcs12 -export -in client-cert.pem -inkey client-key.pem \
    -out client-keystore.p12 -name "sqlserver-client" \
    -passout pass:changeit

# 6. Generate mssql.conf for SQL Server to pick up SSL
echo "[network]
forceencryption = 1
certificate = /etc/ssl/sqlserver/mssql.pfx
key = /etc/ssl/sqlserver/mssql.pfx" > mssql.conf

# 7. Permissions
chmod 644 * 2>/dev/null || true

echo ">>> SQLSERVER PKI: Generation Complete."
ls -l
