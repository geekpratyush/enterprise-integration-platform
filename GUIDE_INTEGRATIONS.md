# Integration Reference: Patterns & Protocols
**A Comprehensive Guide to Supported Connectors and Utilities**

---

## 1. Messaging Middleware

### IBM MQ
*   **Modes**: Non-SSL, SSL One-Way, mTLS, Kerberos (GSSAPI).
*   **Features**: Connection pooling via `JmsPoolConnectionFactory`, Local and Global (XA) transaction support.
*   **Kamelets**: `ibmmq-source`, `ibmmq-sink`.

### Confluent Kafka
*   **Security**: SASL/PLAIN, mTLS.
*   **Integrations**: Direct Camel-Kafka component with auto-configuration via environment variables.

---

## 2. Database & Persistence

### Agnostic Data Layer (JSON-to-DB)
The platform supports a unified protocol for database operations, allowing you to perform CRUD actions using a single JSON schema across multiple providers.
- **Supported DBs**: MongoDB, Oracle, Postgres, MySQL, SQLServer.
- **Pattern**: Push a JSON payload with `operation` and `payload` headers to the database sink Kamelets.

### Liquibase Integration
All database schemas are version-controlled via Liquibase.
- **SQL**: Standard JDBC changelogs.
- **NoSQL**: MongoDB-specific Liquibase extensions for managing collections and indexes as infrastructure-as-code.

---

## 3. Auditing & Security

### Standardized Auditing (`eip-audit-action`)
A platform-wide audit mechanism that reshapes messages into a standard "Audit Envelope" JSON structure.
- **Fields**: `audit_id`, `timestamp`, `correlation_id`, `route_id`, `payload`.
- **Encryption**: Supports `BASE64` and `AES-256` encryption for sensitive payloads.

### Cryptography & PKI
- **`EipSslSocketFactory`**: A custom factory for dynamic SSL context initialization.
- **Zero-Restart Cert Rotation**: The engine can be configured to reload certificates from disk at specific intervals without restarting the container.

---

## 4. Operational Status Roadmap
| Component | Status | Security Modes |
| :--- | :--- | :--- |
| **IBM MQ** | 🟢 Production Ready | mTLS, Kerberos, XA |
| **MongoDB** | 🟢 Production Ready | mTLS, Change Streams |
| **Kafka** | 🟢 Production Ready | mTLS, SASL |
| **MySQL/Postgres**| 🟢 Production Ready | mTLS, SSL |
| **Oracle** | 🟢 Production Ready | TCPS (mTLS) |
| **Redis** | 🟡 Testing | ACL, mTLS |

---

**Author:** Pratyush Ranjan Mishra
