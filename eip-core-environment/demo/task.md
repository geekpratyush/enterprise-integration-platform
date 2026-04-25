# EIP Platform: Integration Roadmap & Verification Tasklist

This document tracks the standardization and verification of all connectors within the eip-core-integration platform. 
Every scenario follows the **4-Phase Lifecycle**: 
1. Provisioning -> 2. Initialization -> 3. Environment -> 4. Routes/Verification.

## 1. IBMMQ (Messages)
| ID | Mode | Security | Transaction | AI Verified | USER Verified | Status |
| :-- | :--- | :--- | :--- | :---: | :---: | :--- |
| 1 | non-ssl-no-auth | No Auth | None | [x] | [x] | COMPLETE |
| 2 | non-ssl-user-auth | User Auth| None | [x] | [x] | COMPLETE |
| 3 | ssl-oneway | User/Cert | Local-TX | [x] | [x] | COMPLETE |
| 4 | mtls | Mutual Cert | Local-TX | [x] | [x] | COMPLETE |
| 5 | mtls-auth-mfa | MFA | Local-TX | [x] | [x] | COMPLETE |
| 6 | kerberos | GSSAPI | Local-TX | [x] | [x] | COMPLETE |
| 7 | mtls-xa | Global Auth | Global JTA | [x] | [x] | COMPLETE |

## 2. MongoDB (Document Store)
| ID | Mode | Security | Database | AI Verified | USER Verified | Status |
| :-- | :--- | :--- | :--- | :---: | :---: | :--- |
| 1 | non-ssl-mongo | No Auth | eip_db | [x] | [x] | COMPLETE |
| 2 | non-ssl-user-mongo | SCRAM-SHA | eip_db | [x] | [x] | COMPLETE |
| 3 | ssl-oneway | User Auth | eip_db | [x] | [x] | COMPLETE |
| 4 | mtls-mongo | Certificate | eip_db | [x] | [x] | COMPLETE |
| 5 | change-stream-mongo | ReplicaSet | eip_db | [x] | [x] | COMPLETE |

## 3. Confluent Kafka (Streaming) [Folder: ckafka]
| ID | Mode | Security | Topic | AI Verified | USER Verified | Status |
| :-- | :--- | :--- | :--- | :---: | :---: | :--- |
| 1 | non-ssl-kafka | PLAINTEXT | audit_log | [x] | [x] | COMPLETE |
| 2 | mtls-kafka | mTLS | audit_log | [x] | [x] | COMPLETE |

## 4. Solace (Event Broker)
| ID | Mode | Security | VPN | AI Verified | USER Verified | Status |
| :-- | :--- | :--- | :--- | :---: | :---: | :--- |
| 1 | tcp-noauth | No Auth | default | [x] | [x] | COMPLETE |
| 2 | tcp-auth | User Auth | eip-vpn | [x] | [x] | COMPLETE |
| 3 | ssl-oneway | User Auth/SSL | eip-vpn | [x] | [x] | COMPLETE |
| 4 | mtls | Mutual TLS | eip-vpn | [x] | [x] | COMPLETE |
|   |            |            |         |     |     |          |
|   |            |            |         |     |     |          |
## 5. Redis (In-Memory Key/Value)
| ID | Mode | Security | Instance | AI Verified | USER Verified | Status |
| :-- | :--- | :--- | :--- | :---: | :---: | :--- |
| 1 | redis-noauth   | No Auth     | Standalone   | [x] | [x] | COMPLETE |
| 2 | redis-pass     | Legacy Pass | Auth-Identity| [x] | [x] | COMPLETE |
| 3 | redis-acl      | ACL (User)  | Auth-Identity| [x] | [x] | COMPLETE |
| 4 | redis-tls      | mTLS (Certs)| TLS-Identity | [x] | [x] | COMPLETE |
| 5 | redis-sentinel | Cluster     | HA-Topology  | [x] | [x] | COMPLETE |

## 5. Relational Databases (SQL)

### 5.1 MySQL
| ID | Mode | Security | Schema | AI Verified | USER Verified | Status |
| :-- | :--- | :--- | :--- | :---: | :---: | :--- |
| 1 | non-ssl-mysql | User Auth | eip_db | [x] | [x] | COMPLETE |
| 2 | ssl-oneway    | Server SSL| eip_db | [x] | [x] | COMPLETE |
| 3 | ssl-mysql     | Mutual SSL| eip_db | [x] | [x] | COMPLETE |

### 5.2 PostgreSQL
| ID | Mode | Security | Schema | AI Verified | USER Verified | Status |
| :-- | :--- | :--- | :--- | :---: | :---: | :--- |
| 1 | non-ssl-postgres| User Auth | eip_db| [x] | [x] | COMPLETE |
| 2 | ssl-oneway      | Server SSL| eip_db| [x] | [x] | COMPLETE |
| 3 | ssl-postgres    | Mutual SSL| eip_db| [x] | [x] | COMPLETE |

### 5.3 Oracle (Enterprise)
| ID | Mode | Security | Schema | AI Verified | USER Verified | Status |
| :-- | :--- | :--- | :--- | :---: | :---: | :--- |
| 1 | non-ssl-oracle | User Auth | eip_db | [x] | [x] | COMPLETE (Agnostic) |
| 2 | ssl-oneway    | Server SSL| eip_db | [x] | [x] | COMPLETE (Agnostic) |
| 3 | tcps-oracle    | Mutual TLS| eip_db | [x] | [x] | COMPLETE (Agnostic) |

### 5.4 SQLServer
| ID | Mode | Security | Schema | AI Verified | USER Verified | Status |
| :-- | :--- | :--- | :--- | :---: | :---: | :--- |
| 1 | non-ssl-sqlserver| User Auth | eip_db | [ ] | [ ] | Pending |
| 2 | ssl-oneway       | Server SSL| eip_db | [ ] | [ ] | Pending |
| 3 | ssl-sqlserver    | Mutual TLS| eip_db | [ ] | [ ] | Pending |

## 5. Agnostic Features (Cross-Platform Utilities)
| Status | Feature | Protocol | Verification |
| :--- | :--- | :--- | :--- |
| 🟢 | Liquibase Executor | Multi-Dialect | [SQL](file:///home/pratyush/software/eip-core-integration/eip-core-environment/demo/mysql/02_initialization/) / [NoSQL](#liquibase-mongodb) |
| 🟢 | Agnostic Data Layer | JSON-to-DB | [Implemented (Kamelets)](#agnostic-db-suite) |
| ⚪ | Dynamic Cert Injector | PKI | TBD |

---

<a name="liquibase-mongodb"></a>
### 🍃 Liquibase for NoSQL (MongoDB Example)
Treating MongoDB collections as versioned infrastructure.
```yaml
databaseChangeLog:
  - changeSet:
      id: 1
      author: pratyush
      changes:
        - createCollection:
            collectionName: audit_trail
        - createIndex:
            collectionName: audit_trail
            columns:
              - column:
                  name: txn_id
```

---

<a name="agnostic-data-layer-blueprint"></a>
### 🛠️ Agnostic Data Layer: Unified Metadata Protocol (Blueprint)

**Objective**: Decouple business logic from DB-specific dialects. Use a BSON-compatible JSON structure to perform identical operations across MongoDB, MySQL, Postgres, and Cassandra.

#### 1. Unified JSON Schema (The Universal Command)
```json
{
  "header": {
    "operation": "UPSERT",      // INSERT, UPDATE, UPSERT, DELETE, FIND, COUNT
    "collection": "audit_logs", // Table or Collection Name
    "provider": "AUTO"          // SQL, MONGODB, CASSANDRA, or AUTO (dynamic detection)
  },
  "payload": {
    "txn_id": "TX-9988",
    "status": "PROCESSED",
    "metadata": { "region": "EU", "priority": 1 }
  },
  "filter": {
    "txn_id": "TX-9988"         // Used for UPDATE/FIND/DELETE/UPSERT
  },
  "context": {
    "headers": { "X-Correlation-ID": "...", "X-Tenant": "..." },
    "audit": true
  }
}
```

#### 2. Features & Integration Logic
*   **JSON-to-Route Migration**: The structure can be placed inside a Kafka Topic or IBMMQ Queue. The `eip-core-lib` repository listener will pick it up and route it to the correct DB bean.
*   **Change Data Capture (CDC) Integration**: 
    *   **MongoDB**: Listen to `ChangeStream` -> Convert to Unified JSON -> Push to Kafka.
    *   **SQL**: Polling or Debezium -> Convert to Unified JSON -> Push to Kafka.
*   **Header Manipulation**: Includes a built-in `MetadataMapper` that can append, remove, or alter fields in the `context.headers` map without breaking the core payload.

#### 3. Verification Roadmap
*   [ ] Implement `AgnosticRepository` in `eip-core-lib`.
*   [ ] Add `JsonToDbProcessor` for Camel Route integration.
*   [ ] Verify "Upsert" logic consistency across MySQL and MongoDB.

## 6. Agnostic Features
| Feature | Description | Status |
| :--- | :--- | :--- |
| Total Audit | MongoDB Logging | Pending |
| XSLT Multi-SRU| Versioned SWIFT | Pending |
| Kamelet Injection| CAMEL_KAMELET_* | [x] Verified |

---

## 7. Configuration Master Switches
The platform behavior is toggled purely via these metadata parameters:

| Feature | Param (Sink/Source) | Value | Description |
| :--- | :--- | :--- | :--- |
| **SSL/TLS** | `...SSLCIPHERSUITE` | `TLS_...` or `*` | Non-empty triggers SSL layer |
| **Mutual TLS**| `...KEYSTOREPATH` | `/path/*.p12` | Presence triggers certificate presentation |
| **Transaction** | `...TRANSACTED` | `true` | Enables transactionality logic |
| **XA (Global)**| `...USE_XA` | `true` | Enlists session in Global JTA (Narayana) |
| **Auth** | `...MQCSP` | `true/false`| Toggles Modern vs Compatibility auth |
