#!/bin/bash
# ======================================================================
#                ORACLE TCPS LISTENER CONFIGURATOR
# ======================================================================
# This script runs INSIDE the oracle-platform container as user 'oracle'.
# It creates an Oracle Autologin Wallet from the host-generated PKCS12
# and configures the listener for TCPS on port 2484.

set -e

echo ">>> ORACLE TCPS: Configuring Secure Listener..."

# --- Dynamic Discovery ---
ORACLE_HOME=$(find /opt/oracle/product -name dbhomeFree -type d | head -n 1)
export ORACLE_HOME
export PATH=$ORACLE_HOME/bin:$PATH
TNS_ADMIN="${ORACLE_HOME}/network/admin"
WALLET_DIR="/opt/oracle/oradata/dbconfig/FREE/wallet"

# --- 1. Create Oracle Wallet from Host-Generated PKCS12 ---
echo "    >>> Creating Oracle Autologin Wallet..."
mkdir -p $WALLET_DIR
rm -rf $WALLET_DIR/*

orapki wallet create -wallet $WALLET_DIR -pwd EipPass123! -auto_login
orapki wallet import_pkcs12 -wallet $WALLET_DIR -pkcs12file /mnt/certs/ewallet.p12 -pkcs12pwd EipPass123! -pwd EipPass123!
# Add Root CA trust (idempotent - ignore if already imported via PKCS12)
orapki wallet add -wallet $WALLET_DIR -trusted_cert -cert /mnt/certs/ca-cert.pem -pwd EipPass123! || true

echo "    >>> Wallet contents:"
orapki wallet display -wallet $WALLET_DIR -pwd EipPass123!

# Strict permissions
chmod 700 $WALLET_DIR
chmod 600 $WALLET_DIR/*
chown -R oracle:oinstall $WALLET_DIR

# --- 2. Determine Client Auth Mode ---
if [[ "$MODE" == "tcps-oracle" ]]; then
    CLIENT_AUTH="TRUE"
else
    CLIENT_AUTH="FALSE"
fi

# --- 3. Write listener.ora ---
DB_CONFIG="/opt/oracle/oradata/dbconfig/FREE"
echo "    >>> Writing listener.ora to native persistent storage..."
cat > $DB_CONFIG/listener.ora <<EOF
SSL_CLIENT_AUTHENTICATION = $CLIENT_AUTH
SSL_VERSION = 1.2
SSL_CIPHER_SUITES = (SSL_RSA_WITH_AES_256_GCM_SHA384, SSL_RSA_WITH_AES_128_GCM_SHA256, SSL_RSA_WITH_AES_256_CBC_SHA, SSL_RSA_WITH_AES_128_CBC_SHA)

WALLET_LOCATION =
  (SOURCE =
    (METHOD = FILE)
    (METHOD_DATA =
      (DIRECTORY = $WALLET_DIR)
    )
  )

LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1))
      (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521))
      (ADDRESS = (PROTOCOL = TCPS)(HOST = 0.0.0.0)(PORT = 2484))
    )
  )
EOF

# --- 4. Write sqlnet.ora ---
echo "    >>> Writing sqlnet.ora to native persistent storage..."
cat > $DB_CONFIG/sqlnet.ora <<EOF
WALLET_LOCATION =
  (SOURCE =
    (METHOD = FILE)
    (METHOD_DATA =
      (DIRECTORY = $WALLET_DIR)
    )
  )

SSL_CLIENT_AUTHENTICATION = $CLIENT_AUTH
SSL_VERSION = 1.2
SSL_CIPHER_SUITES = (SSL_RSA_WITH_AES_256_GCM_SHA384, SSL_RSA_WITH_AES_128_GCM_SHA256, SSL_RSA_WITH_AES_256_CBC_SHA, SSL_RSA_WITH_AES_128_CBC_SHA)
EOF

# Force symlink mapping for immediate awareness without rebooting container
ln -sf $DB_CONFIG/listener.ora $TNS_ADMIN/listener.ora
ln -sf $DB_CONFIG/sqlnet.ora $TNS_ADMIN/sqlnet.ora


# --- 5. Restart Listener ---
echo "    >>> Restarting Oracle Listener..."
lsnrctl stop > /dev/null 2>&1 || true
sleep 2
lsnrctl start

# --- 6. Force Dynamic Service Registration ---
echo "    >>> Forcing database service registration..."
sqlplus -s / as sysdba <<EOSQL
ALTER SYSTEM REGISTER;
EXIT;
EOSQL

# Wait for registration to propagate
sleep 5
echo "    >>> Verifying service registration..."
lsnrctl status

echo ">>> ORACLE TCPS: Secure Listener initialized."
