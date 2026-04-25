# IBM MQ Kamelet Suite (v3.0.x)

This directory contains a suite of high-performance, production-ready Kamelets for integrating with **IBM MQ**. These components are designed for the EIP Core Platform and support advanced enterprise features including Mutual TLS (mTLS), MQCSP authentication, and JTA/XA distributed transactions.

## Kamelet Variants

| Kamelet | Type | Transaction Mode | Ideal For |
| :--- | :--- | :--- | :--- |
| **`ibmmq-source`** | Source | Local JMS Session | High-throughput consumption where local-only rollback is sufficient. |
| **`ibmmq-sink`** | Sink | Local JMS Session | Standard message publishing within a single transaction boundary. |
| **`ibmmq-xa-source`** | Source | **JTA (Narayana)** | Mission-critical consumption required to participate in distributed XA transactions (e.g., MQ + Database). |
| **`ibmmq-xa-sink`** | Sink | **JTA (Narayana)** | Mission-critical publishing required to participate in distributed XA transactions. |

## Key Features

### 1. Robust Connectivity & Performance
- **Built-in Pooling**: Powered by `JmsPoolConnectionFactory` (Local) and `JmsPoolXAConnectionFactory` (XA) for optimized resource reuse.
- **Self-Contained Beans**: Each Kamelet instance manages its own scoped ConnectionFactory and JmsComponent beans to prevent global registry pollution.

### 2. Strategic Authentication (Orthogonal)
The suite supports three primary authentication patterns:
- **Anonymous**: Default mode. Connects without credentials.
- **MQCSP (User/Pass)**: Enable by setting `authenticationMQCSP: true` and providing `username`/`password`.
- **mTLS (Certificate-based)**: Provide `sslCipherSuite` and the necessary KeyStore/TrustStore paths. This can be combined with MQCSP if required by the broker.

### 3. Mutual TLS (mTLS) Support
Full support for JSSE-standard mutual authentication. The suite uses the `EipSslSocketFactory` to dynamically load:
- **TrustStore**: To verify the MQ Server certificate.
- **KeyStore**: To present a client certificate to the MQ Server.

## Configuration Parameters

### Mandatory Parameters (Typical)
- `queueName`: The target IBM MQ queue.
- `mqHost`: Broker hostname (Default: `localhost`).
- `mqPort`: Broker port (Default: `1414` for Local, `1418` for XA).
- `mqQueueManager`: Name of the IBM MQ Queue Manager (Default: `QM1`).
- `mqChannel`: SVRCONN channel name (Default: `DEV.APP.SVRCONN`).

### Advanced Parameters (Optional)
- `mqComponent`: Unique ID for the internal Camel component (Default: `ibmmq` or `jms`). **CRITICAL: Change this if using multiple MQ routes in the same context.**
- `sslCipherSuite`: Set this (e.g., `TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384`) to activate TLS.
- `authenticationMQCSP`: Set `true` to enable Credential-based authentication.

## Transaction Safeguards (XA Contract)

The `ibmmq-xa-*` variants follow a strict XA contract to ensure consistency with IBM MQ and Narayana:
- `transacted` is set to `false` (JTA manages the boundary).
- `cacheLevelName` is forced to `CACHE_NONE` (XA sessions cannot be cached/reused across transaction boundaries).
- `concurrentConsumers` defaults to `1` to prevent XA session contention (scale with caution).

---
*Created by Antigravity AI for the EIP Core Platform.*
