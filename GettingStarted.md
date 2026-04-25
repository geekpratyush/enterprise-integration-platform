# EIP Core Platform: Getting Started Guide (The "Fuel-to-Engine" Model)

## 1. Architectural Philosophy: Engine vs. Fuel

The EIP Core Platform is designed as an **immutable integration engine**. The architecture strictly separates the **Chassis (The Engine)** from the **Metadata (The Fuel)**.

*   **The Engine (`eip-core-lib` & `eip-core-consumer`)**: Contains the cross-cutting concerns (Audit, Security, Dynamic Connectivity, Liquibase Executor). It has **zero business logic**. It is a clean shell that knows how to read environment variables and execute YAML DSL.
*   **The Fuel (`eip-core-environment`)**: Contains the routes, connection parameters, certificates, and database schemas. This is the only part that changes between one business case and another.

> [!IMPORTANT]
> To change an integration logic or connect to a new database, you **never recompile the code**. You simply "refuel" the engine with new environment variables and mounted YAML files.

---

## 2. Using the Demo Tracks (The 4-Phase Roadmap)

Every integration scenario (e.g., PostgreSQL, IBMMQ, Kafka) follows a standardized **4-Phase Lifecycle**. This is your blueprint for creating any new integration.

### Phase 1: Provisioning (`01_provisioning/`)
*   **Goal**: Create an isolated infrastructure using Docker.
*   **Action**: Use scenario-specific `docker-compose` files. These files use `${MODE}` variables to dynamically mount certificates and configuration volumes.

### Phase 2: Initialization (`02_initialization/`)
*   **Goal**: Prime the environment.
*   **Action**: 
    1.  **PKI Automation**: Run `setup-pki.sh` to generate the mTLS/SSL assets (Root CA, Server/Client certs).
    2.  **Persistence**: Run `setup-db.sh` which uses the **Liquibase Fat JAR** to build standardized tables (e.g., `audit_log`) across any RDBMS.

### Phase 3: Environment Setup (`03_environment/`)
*   **Goal**: Map infrastructure identities to application variables.
*   **Action**: Use `.env` profiles (e.g., `ssl-oneway.env`) to export variables like `QUARKUS_DATASOURCE_JDBC_URL` or `CAMEL_KAMELET_...`.

### Phase 4: Route Orchestration (`04_routes/`)
*   **Goal**: Execute the integration logic.
*   **Action**: Mount the YAML routes to the engine. The engine auto-discovers them and starts the Camel Context.

---

## 3. Connectivity by Environment Variables

The platform uses a "Convention over Configuration" approach to bind external connections to the Engine's registry.

### Relational Databases (JDBC)
Instead of hardcoding a `DataSource`, the platform listens for:
```bash
# Example for PostgreSQL SSL
export QUARKUS_DATASOURCE_JDBC_URL="jdbc:postgresql://127.0.0.1:5432/eip_db?ssl=true&sslmode=verify-full&sslrootcert=path/to/ca.pem"
export QUARKUS_DATASOURCE_USERNAME=eip_user
export QUARKUS_DATASOURCE_PASSWORD=Password123!
```
The `eip-core-lib` detects these, instantiates the driver, and registers it as the "default" or "named" datasource.

### Managed Security (TLS Registry)
The platform uses an externalized TLS Registry. You provide the paths via env vars, and the engine builds the SSL context dynamically:
```bash
export QUARKUS_TLS_EIP_KEY_STORE_PATH=${EIP_CERT_DIR}/keystore.p12
export QUARKUS_TLS_EIP_KEY_STORE_PASSWORD=changeit
export QUARKUS_TLS_EIP_TRUST_STORE_PATH=${EIP_CERT_DIR}/truststore.p12
```

---

## 4. The Kamelet Strategy: Catalog vs. Custom

Kamelets are the "Lego blocks" of this platform. They allow you to hide complex connectivity details (like SSL parameters or retry logic) behind a simple interface.

### Catalog Kamelets
These are the standard blocks provided by the Apache Camel community (e.g., `postgresql-sink`, `kafka-source`).
*   **Accessibility**: If you include the `camel-kamelets` dependency in your `build.gradle.kts`, all 300+ catalog Kamelets are instantly available to your routes.

### Custom Kamelets (`eip-core-kamelets`)
For enterprise-specific requirements (e.g., a "Standardized Audit Sink" or "Legacy Billing Source"), you should create Custom Kamelets.

*   **Where to put them?**:
    *   **External (Recommended)**: Keep them in `eip-core-environment/platform/kamelets`. This keeps the engine truly immutable.
    *   **Library (The `eip-core-lib` approach)**: It is a great idea for **Shared Corporate Standards**. If you build an `eip-core-kamelet-lib.jar`, you ensure every microservice in the company uses the same "Audit Sink."
*   **Co-existence**: If you include both the Catalog dependency and your Custom dependency, **both are accessible**. Camel scans its classpath and its external resource paths (`camel.component.kamelet.location`) and merges them into a single unified catalog.

---

## 5. How to add a New Integration (e.g., MS Dynamics or SAP)

To build a new track (e.g., `demo/sap/`):
1.  **Copy the 4-Phase Folders**: Clone the `postgres` directory structure as a template.
2.  **Define Provisioning**: Update `docker-compose` to pull the SAP mock/container.
3.  **Refine PKI**: Update `setup-pki.sh` if the target requires specific formats (e.g., `.jks` vs `.p12`).
4.  **Write the Route**: Create a YAML route in `04_routes/` using the SAP Kamelet.
5.  **Inject the Fuel**: Create a `.env` profile that points to the SAP host/credentials.

---

## 6. System Architecture Fit

In a production environment (Kubernetes/OpenShift):
1.  The **Container Image** is your `eip-core-consumer`. It is built once and never changed.
2.  The **Routes** and **Kamelets** are mounted via **ConfigMaps**.
3.  The **Secrets** and **Certificates** are mounted via **Secrets**.
4.  The **Environment Variables** are injected via the Deployment spec.

This results in a system where the integration team manages **YAML and Env Vars**, while the platform team manages the **Java/Quarkus Chassis**, providing true separation of duties.
