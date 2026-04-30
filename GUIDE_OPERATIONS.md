# Operations Handbook: The 4-Phase Lifecycle
**Standardized Deployment and Verification Orchestration**

---

## 1. Introduction
To ensure production-grade reliability, every scenario in the EIP Platform follows a standardized **4-Phase Lifecycle**. This ensures that security, persistence, and connectivity are validated before any integration logic is executed.

---

## 2. Phase 1: Provisioning (`01_provisioning/`)
In this phase, we deploy the isolated infrastructure required for the integration.
- **Tools**: Docker Compose.
- **Constraints**: We disable `Quarkus DevServices` to ensure we are testing against real, configured containers that mimic production environments.
- **Execution**: `docker compose up -d`

---

## 3. Phase 2: Initialization (`02_initialization/`)
This is the most critical phase where security and persistence layers are established.
- **Security (PKI)**: Automated scripts generate the necessary certificate chains (Root-CA -> Server -> Client). These are stored in a dedicated `certs/` directory and mounted into containers.
- **Persistence (Liquibase)**: Database schemas are initialized using versioned changelogs. This ensures that tables, collections, and indexes exist before the consumer starts.
- **Tools**: OpenSSL, Liquibase CLI.

---

## 4. Phase 3: Environment Setup (`03_environment/`)
This phase maps the "identities" and "credentials" from Phases 1 & 2 into the application runtime.
- **Environment Profiles**: Scenarios use `.env` files to define connection strings, SSL cipher suites, and credential paths.
- **Variables**: Use `set -a` to export variables from profiles into the shell before launching the consumer.

---

## 5. Phase 4: Execution & Verification (`04_routes/`)
The final phase where the `eip-core-consumer` is launched and the integration routes are loaded.
- **Route Loading**: Camel DSL files are scanned from the specified route directory.
- **Verification**: Logs are monitored to ensure successful connection to brokers and databases.
- **Execution**: `./gradlew quarkusDev -Dquarkus.profile=prod`

---

## 6. Orchestration Script: `start-eip.sh`
Each demo category includes a `start-eip.sh` script that automates the transition between these four phases. It provides a menu-driven interface to select security modes (e.g., Plaintext vs mTLS vs Kerberos).

### Example Workflow:
1. Select Scenario (e.g., `mtls`)
2. Script purges old environment.
3. Script provisions containers.
4. Script generates new PKI certs.
5. Script sources the `.env` profile.
6. Script launches the Quarkus consumer.

---

**Author:** Pratyush Ranjan Mishra
