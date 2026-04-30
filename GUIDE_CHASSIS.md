# Platform Architecture: The EIP Chassis
**A "Fuel-to-Engine" Integration Model**

---

## 1. The Core Philosophy
Traditional integration platforms often bundle business logic with the application runtime. This platform breaks that bond by treating the application as a **Hardened Chassis** and the integration logic as **Externalized Fuel**.

### Key Principles:
*   **Immutability**: The core engine is never recompiled for a new route.
*   **Zero-Invasive Configuration**: No code changes required for security hardening or protocol switching.
*   **Metadata Discovery**: The engine recursively scans environment variables and mounted volumes to build its context at runtime.

---

## 2. Component Breakdown

### Repository 1: `eip-core-lib` (The Engine)
This is the heart of the platform. It provides the dynamic bootstrapping capabilities and agnostic utilities.
- **Dynamic Connection Registry**: Scans environment variables (Dot and ENV notation) to register `MongoClients`, `ConnectionFactories` (JMS), and `DataSources` (SQL) into the Camel Registry at runtime, bypassing CDI pruning.
- **The `.eipignore` Engine**: A recursive discovery filter that skips routes or beans based on local infrastructure availability.
- **Agnostic Data Layer**: Unified JSON-to-DB mapping for insert/update/retrieve across MongoDB, SQL (Oracle/MySQL/Postgres), and NoSQL.
- **Security Utilities**: Built-in `EipSslSocketFactory` for zero-restart certificate rotation and mTLS orchestration.

### Repository 2: `eip-core-consumer` (The Shell)
An empty, immutable Quarkus application that serves as the runtime container.
- **Runtime Discovery**: Uses `-Dquarkus.profile=prod` to load externalized environment variables.
- **Resource Loading**: Automatically loads Kamelets and Routes from the classpath and mounted volumes.

### Repository 3: `eip-core-environment` (Operation Control)
The orchestrator containing the lifecycle scripts and platform-wide assets.
- **PKI Automation**: Scripts for generating Root-CA, Server, and Client certificates.
- **Platform Kamelets**: A centralized library of enterprise integration patterns (e.g., `ibmmq-sink`, `eip-audit-action`).

---

## 3. Dynamic Configuration Logic
The platform uses a "Snake-to-Camel" mapping logic for environment variables. 
Example:
`CAMEL_KAMELET_IBMMQ_SINK_HOSTNAME=mqserver` 
is automatically mapped to the `hostname` property of the `ibmmq-sink` Kamelet.

This allows operations teams to configure complex integration patterns purely through `.env` files or Kubernetes Secrets.

---

## 4. Discovery Engine (.eipignore)
To prevent startup failures in heterogeneous environments, the platform uses a `.eipignore` file. This works similarly to `.gitignore`, allowing you to exclude specific routes or configuration beans if the underlying infrastructure (like a specific IBM MQ manager) is not available in the current environment.

---

**Author:** Pratyush Ranjan Mishra
