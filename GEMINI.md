# Project Architectural Blueprint: EIP Core Platform (Enterprise Integration Pattern Chassis)

**Author:** Pratyush Ranjan Mishra
**Email:** pratyush.ranjan.mishra@gmail.com
**Target Stack:** Java 17+ (Baseline LTS), Quarkus 3.x, Apache Camel Quarkus 3.x, Gradle 8.x+ (Kotlin DSL).

## 1. Project Objective
Generate a complete, production-ready microservices architecture for a completely externalized, metadata-driven integration platform. The platform is a clean, immutable container shell. All connections, credentials, certificates, routes, and bean configurations are injected purely via environment variables and mounted YAML files at runtime.

### The "Magic" of the Chassis:
- **Zero-Code / Low-Code**: Logic exists in external YAML DSL and Kamelets.
- **Strict Isolation**: Core app never contains business logic; it is a "Fuel-to-Engine" model.
- **Security Agnostic**: Full mTLS/SSL support enabled via externalized TLS Registries.

---

## 2. Core Framework: `eip-core-lib` (The Engine)
This library provides the dynamic bootstrapping capabilities and agnostic utilities.
- **Dynamic Connection Registry**: Scans environment variables (Dot and ENV notation) to register `MongoClients`, `ConnectionFactories` (JMS), and `DataSources` (SQL) into the Camel Registry at runtime, bypassing CDI pruning.
- **The `.eipignore` Engine**: Recursive discovery filter to skip routes or beans based on local infrastructure availability.
- **Agnostic Data Layer**: Unified JSON-to-DB mapping for insert/update/retrieve across MongoDB, SQL (Oracle/MySQL/Postgres), and NoSQL.
- **Liquibase Executor**: A built-in lifecycle hook that treats mounted changelogs as the source of truth for DB schema initialization.

---

## 3. Demo Standard: The 4-Phase Lifecycle
Every scenario (MongoDB, Kafka, IBMMQ) must follow the standardized orchestration sequence in `eip-core-environment/demo/`:

1.  **Phase 1: Provisioning (`01_provisioning/`)**
    - Isolated Docker containers without DevServices. Standardized port mapping (e.g., 27020 for Mongo).
2.  **Phase 2: Initialization (`02_initialization/`)**
    - **Security**: Automated PKI scripts for cert generation (root-ca, server, client-p12).
    - **Persistence**: Database schema initialization via Liquibase changelogs.
3.  **Phase 3: Environment (`03_environment/`)**
    - Scenario-specific profiles (`.env`) that map the identities and credentials from Phase 1 & 2 into the application runtime.
4.  **Phase 4: Routes (`04_routes/`)**
    - The YAML-based integration logic and Kamelet calls that demonstrate the end-to-end flow.

---

## 4. Repository Specifications

### Repository 1: `eip-core-lib`
- Organized into packages: `audit`, `config`, `crypto`, `filter`, `platform`, `processor`, `repository`, `util`.
- **Target**: Published to `mavenLocal` or Nexus to serves as the "Module-As-A-Library" for the Consumer.

### Repository 2: `eip-core-consumer` (The Shell)
- An empty, immutable Quarkus application.
- **Runtime Discovery**: Uses `-Dquarkus.profile=prod` to load externalized environment variables via Vault, Secrets, or `.env` files.
- **No DevServices**: `quarkus.devservices.enabled=false`.

### Repository 3: `eip-core-environment` (Operation Control)
- The orchestrator repository containing the `demo/` folders and `platform/kamelets/`.
- Includes `start-eip.sh`: A master script that walks through the 1-2-3-4 folder sequence.

### Repository 4: `eip-core-docs`
- Shared templates for `connections.yaml`, `.env.template`, and Kaoto-compatible route samples.

---

## 5. Technology Coverage
The platform is designed to support:
- **Messaging**: IBMMQ, Kafka (mTLS), Solace, ActiveMQ.
- **Databases**: MongoDB, Oracle, Postgres, MySQL.
- **Transformations**: Flatpack (Fixed length), XSLT (XML), Jackson (JSON).
- **Audit**: Agnostic state tracking via MongoDB/SQL.