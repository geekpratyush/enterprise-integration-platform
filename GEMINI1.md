# Project Architectural Blueprint: EIP Core Platform (Enterprise Integration Pattern Chassis)

**Author:** Pratyush Ranjan Mishra
**Email:** pratyush.ranjan.mishra@gmail.com
**Target Stack:** Java 17+ (Baseline LTS), Quarkus 3.x, Apache Camel Quarkus 3.x, Gradle 8.x+ (Kotlin DSL).

## 1. Project Objective
Generate a complete, production-ready microservices architecture for a completely externalized, metadata-driven integration platform. The platform is designed so the core application is a clean, immutable container shell. All connections, credentials, certificates, routes, and bean configurations are injected purely via environment variables and mounted YAML files at runtime. 

To maintain strict domain isolation, version control, and backward compatibility with enterprise Java 17 environments, the system is split across four independent repositories.

---

## 2. Repository Architecture

1. **`eip-core-lib`**: The underlying dynamic loading engine (Framework Library).
2. **`eip-core-consumer`**: The containerized Quarkus service shell.
3. **`eip-core-environment`**: Infrastructure scripts and selective Docker Compose setups.
4. **`eip-core-docs`**: Sample configuration "fuel" (YAMLs, `.eipignore`, env templates).

---

## 3. Repository Specifications

### Repository 1: `eip-core-lib` (The Engine)
This standalone library provides the dynamic bootstrapping capabilities. It contains no business logic.
* **Build Configuration:** `java-library` using Gradle 8.x (Kotlin DSL) targeting Java 17 (`sourceCompatibility = JavaVersion.VERSION_17`). Apply `org.kordamp.gradle.jandex` for Quarkus bean discovery.
* **The `.eipignore` Engine:** * Implement a recursive directory scanner that reads a `.eipignore` file at the root of the provided configuration directory.
    * The engine must parse this file to support exact names, folder names, and wildcards (e.g., `*ssl*`, `ibm-mq/`).
    * Any `.yaml` file (route or bean definition) matching the `.eipignore` rules must be strictly excluded from being loaded into `CamelContext.getRoutesLoader()`.
* **Configuration Extractor:** Utility beans to resolve environment variables explicitly for Camel components dynamically.
* **Publishing:** Configured with the `maven-publish` plugin to publish the artifact locally (or to a corporate Nexus/Artifactory) so consumers can pull it.

### Repository 2: `eip-core-consumer` (The Service Shell)
This is an empty, immutable Quarkus application running in a container, compiled for Java 17.
* **Strict Constraints:** * Absolutely NO hardcoded connections, beans, or routes in the source code.
    * Quarkus DevServices MUST be strictly disabled (`quarkus.devservices.enabled=false`).
    * Integration testing uses Testcontainers. Ensure the containers run as independent pods/jobs (e.g., post-deployment hook), not as sidecars.
* **The "Fuel" Mechanism:** The application behavior is driven entirely by environment variables defining:
    * `EIP_CONFIG_DIR`: Path to the folder containing all YAMLs (routes, beans).
    * `EIP_CERT_DIR`: Path to mounted certificates (TrustStores/KeyStores).
    * Connection strings, usernames, passwords, and secrets.
* **Dependencies:** Depends on the published `eip-core-lib` artifact, `camel-quarkus-yaml-dsl`, and generic connectors (JMS, Kafka, MongoDB, SQL, SFTP).
* **Data Handling Policy:** MongoDB is utilized strictly for lightweight state-tracking. The application must not persist raw incoming Kafka messages or REST API payloads into the database.

### Repository 3: `eip-core-environment` (Infrastructure Operations)
A dedicated operations repository for developer environment management.
* **Cleanup & Initialization Scripts:** Cross-platform scripts (`setup.sh`, `setup.ps1`, `setup.bat`) to:
    * Clean/prune old, dangling Docker images and containers.
    * Pull required base images.
    * Create local directories for persistent volume mounting (simulating the container mounts).
* **Selective Startup:** * Modular `docker-compose` files or profiles allowing the developer to spin up only what is needed (e.g., just `kafka-ssl` and `mongo-auth`, or just `ibmmq-ssl`).
    * The developer dictates what the consumer app connects to by adjusting the environment variables and the `.eipignore` file to ignore routes pointing to offline infrastructure.

### Repository 4: `eip-core-docs` (The Configuration Fuel)
This holds the externalized configuration that will be mounted into the consumer container.
* **`connections.yaml`**: Defines beans for MQ, Kafka, and Databases relying entirely on `{{env:VAR_NAME}}` syntax.
* **`routes.yaml`**: Sample Kaoto-compatible routes (e.g., reading a SWIFT MT103 from SFTP, transforming to ISO 20022 pacs.008, and routing to Kafka).
* **`.eipignore`**: A sample ignore file demonstrating how to skip the `ibmmq-ssl.yaml` routes when testing locally without MQ.
* **`.env.template`**: A template file listing all required environment variables the consumer expects.