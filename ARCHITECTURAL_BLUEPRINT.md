# Architectural Blueprint: EIP Core Platform
**Enterprise Integration Pattern (EIP) Chassis Specification**

**Author:** Pratyush Ranjan Mishra  
**Target Stack:** Java 17+, Quarkus 3.x, Apache Camel 4.x, Gradle 8.x+

---

## 1. Project Objective
The EIP Core Platform is designed to provide a production-ready, microservices-based integration architecture that is completely externalized and metadata-driven. The platform serves as a **clean, immutable container shell** where all operational parameters—connections, credentials, certificates, routes, and bean configurations—are injected via environment variables and mounted volumes at runtime.

### Core Architectural Pillars:
*   **Zero-Code / Low-Code**: Integration logic is decoupled from the runtime, existing purely in external YAML DSLs and Kamelets.
*   **Strict Isolation**: The core application contains no business logic, following a strict "Fuel-to-Engine" model for maximum reusability.
*   **Security by Default**: Native mTLS/SSL support is integrated into the core, enabled through externalized TLS registries and PKI orchestration.

---

## 2. The Core Engine: `eip-core-lib`
This library provides the dynamic bootstrapping capabilities required to build the Chassis.
- **Dynamic Connection Registry**: Automatically scans environment variables to register `MongoClients`, `ConnectionFactories` (JMS), and `DataSources` (SQL) into the Camel Registry at runtime.
- **Recursive Discovery Engine**: Implements a `.eipignore` filter to intelligently skip routes or beans based on infrastructure availability in specific environments.
- **Agnostic Data Layer**: Provides a unified JSON-to-DB mapping protocol for seamless CRUD operations across MongoDB, Oracle, Postgres, and MySQL.
- **Liquibase Lifecycle Hook**: Treats mounted changelogs as the source of truth for all database schema initializations.

---

## 3. Operational Standard: The 4-Phase Lifecycle
To ensure deployment consistency, every scenario must follow the standardized orchestration sequence:

1.  **Phase 1: Provisioning**: Deployment of isolated infrastructure (Docker) without reliance on DevServices.
2.  **Phase 2: Initialization**: Automated PKI orchestration for certificate generation and Liquibase-driven schema initialization.
3.  **Phase 3: Environment Configuration**: Mapping of identities and credentials into the runtime environment profile (`.env`).
4.  **Phase 4: Route Loading**: Dynamic execution of YAML-based integration logic and Kamelet calls.

---

## 4. Repository Specifications

### Layer 1: `eip-core-lib` (The Foundation)
*   **Structure**: `audit`, `config`, `crypto`, `filter`, `platform`, `processor`, `repository`, `util`.
*   **Distribution**: Published as a library to serve as the integration backbone for consumers.

### Layer 2: `eip-core-consumer` (The Shell)
*   **Nature**: An empty, immutable Quarkus application shell.
*   **Runtime**: Loads all configuration dynamically via environment variables and externalized profiles.

### Layer 3: `eip-core-environment` (Operation Control)
*   **Role**: Orchestrates the 4-phase lifecycle and maintains the platform-wide Kamelet library.
*   **Master Script**: `start-eip.sh` (The end-to-end automation master).

---

## 5. Technology Matrix
The platform is engineered to support the following enterprise standards:
- **Messaging**: IBM MQ, Kafka (mTLS), Solace, ActiveMQ.
- **Persistence**: MongoDB, Oracle, Postgres, MySQL, SQLServer.
- **Transformations**: Smooks (v2.x), XSLT (3.0), Jackson, Flatpack.
- **Security**: mTLS, Kerberos, AES-256 Payload Encryption.

---

**© 2024 Pratyush Ranjan Mishra. All rights reserved.**
