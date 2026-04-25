# EIP Infrastructure - Credentials & Connectivity Guide

This document provides a central reference for all provisioned services in the GitOps environment, with a focus on what is **actually practical and easy** to implement for local development.

## 1. Quick Reference Table

| Service | Protocol | Host/Port | Auth | Security Mode | Notes |
|---------|----------|-----------|------|---------------|-------|
| **PostgreSQL** | JDBC | `localhost:5432` | SCRAM-SHA-256 + cert (verify-ca) | **mTLS** | CN=eip-consumer; server uses verify-ca so CN need not match DB user |
| **MySQL** | JDBC | `localhost:3306` | caching_sha2_password | **TLS → mTLS** | `requireSSL=true`, `verifyServerCertificate=true` |
| **Oracle** | JDBC | `localhost:1521/FREEPDB1` | system / admin | **Easy Mode** | Standard TCP; TLS/2484 disabled for local dev stability |
| **SQL Server** | JDBC | `localhost:1433` | sa / Password123! | **Easy Mode** | `encrypt=true;trustServerCertificate=true` (skips validation) |
| **MongoDB** | URI | `localhost:27017` | admin / admin | **Easy Mode** | Non-TLS; TLS/SSL disabled for local dev stability |
| **Cassandra** | CQL | `localhost:9042` | cassandra / cassandra | **Easy Mode** | Standard port 9042; SSL entrypoint disabled |
| **IBM MQ** | JMS/SSL | `localhost(1414)` | channel auth + cert DN | **mTLS** | Keep as-is |
| **Kafka** | SASL_SSL | `localhost:9093` | SASL_SSL (SCRAM) or mTLS-only | **mTLS** | Protocol label corrected (was SMF/SSL) |
| **ActiveMQ** | JMS/SSL | `localhost:61617` | JAAS | **TLS → mTLS** | Easy via `transportConnector` |
| **Solace** | SMF/SSL | `localhost:55443` | client-username or cert | **TLS → mTLS** | Keep as-is |

---

## 2. Certificate & Store Secrets (PKI)

For local development, we standardized on a set of certificates generated specifically for auditing silos.

| Asset | File Path (Relative to `audit/config/assets/certs/`) | Password | Key Alias |
|-------|-----------|----------|-----------|
| **TrustStore** | `audit-truststore.p12` | `password` | `root-ca` |
| **KeyStore** | `audit-keystore.p12` | `password` | `eip-client` |
| **Server P12** | `mqserver.p12` | `changeit` | `mqserver` |
| **Root CA** | `root.crt` | N/A (Plain PEM) | N/A |
| **Client Cert** | `client.crt` | N/A (Plain PEM) | N/A |
| **Client Key (PKCS8 DER)** | `client.pk8` | N/A (unencrypted) | N/A |

> [!IMPORTANT]
> **Password Standardization**: For the Auditing Engine (Silos), the password is `password`. IBM MQ server stores use `changeit`. Always verify the `.env` metadata for the specific silo.
>
> **Cert directory**: All silo certs live in `audit/config/assets/certs/` and are referenced at runtime via `$EIP_CERT_DIR`, which is exported by `startAuditing.sh` **before** the sink `.env` file is loaded so that `${EIP_CERT_DIR}` placeholders expand correctly.

## 3. Implementation Notes

### SSL mechanism per sink

| Sink | Client-side mechanism | Server-side mechanism |
|---|---|---|
| PostgreSQL | `sslcert`/`sslkey`/`sslrootcert` JDBC params | `ssl=on` + `pg_hba.conf` `hostssl clientcert=verify-ca` |
| MySQL | `sslMode=VERIFY_CA` + PKCS12 truststore/keystore JDBC params | `--ssl-ca/cert/key --require_secure_transport=ON` |
| Oracle | `JAVA_TOOL_OPTIONS` → `javax.net.ssl.*` (thin driver reads JVM system props) | `oracle-tcps-init.sh` builds wallet + configures `listener.ora` on port 2484 |
| SQL Server | `encrypt=true;trustServerCertificate=false;trustStore=...` in JDBC URL | `mssql.conf` `[network]` `tlscert`/`tlskey`/`forceencryption=1` |
| MongoDB | `?tls=true&tlsCAFile=...` in URI | `mongod --tlsMode requireTLS --tlsCertificateKeyFile mongodb.pem` |
| Cassandra | `QUARKUS_CASSANDRA_*` DataStax driver env vars + `JAVA_TOOL_OPTIONS` fallback | `cassandra-ssl-entrypoint.sh` patches `cassandra.yaml` `client_encryption_options` |

### Oracle TCPS caveat
`oracle-tcps-init.sh` runs from `container-entrypoint-initdb.d/` after the DB initialises. It tries `mkstore` to create `cwallet.sso` (auto-login wallet). If `mkstore` is absent from the image, the wallet falls back to password-protected (`ewallet.p12` only) and the listener may not auto-load TLS on container restart — re-run the init script manually in that case.

### The Metadata Rule
**The Consumer Shell is Immutable.** Do not inject `-Djavax.net.ssl` properties directly into the code or build script. All SSL configuration is driven by the env files in `audit/config/assets/envs/`. `EIP_CERT_DIR` is exported by `startAuditing.sh` **before** the env file is loaded so `${EIP_CERT_DIR}` placeholders expand correctly via `envsubst`.

---
> [!NOTE]
> All passwords above are the **default developer credentials** for the local environment. Use standard GitOps patterns to override these in higher environments.
