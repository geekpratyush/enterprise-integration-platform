# Implementation Plan - v2 GitOps Provisioning & Initialization

Restructure `eip-core-environment` to follow a strict separation of concerns between infrastructure orchestration (Provisioning) and platform setup (Initialization).

## User Review Required

> [!IMPORTANT]
> - **State Management**: Docker volumes will be mapped to a local `provisioning/volumes/` directory to ensure persistence across restarts.
> - **Unified Secrets**: Certificates and passwords will be centrally managed in `initialization/certs/` and passed to the consumer via a generated `.env` file.
> - **Multi-Target Support**: The provisioning engine will allow starting a single container (e.g., `postgres`) or a whole stack.

## 1. New Directory Structure

### `provisioning/` (Infrastructure as Code)
- `docker/`: Modular Docker Compose files for each technology.
- `scripts/`: `infra.sh` - Standard CLI for `start`, `stop`, `cleanup`, and `status`.
- `volumes/`: Local persistent storage for DBs and Brokers.

### `initialization/` (Platform as Code)
- `certs/`: Automated PKI/mTLS generation.
- `db/`: Liquibase definitions (Tables, Indexes, Stored Procedures).
- `kafka/`: Logic for automatic Topic creation and ACLs.
- `mq/`: Logic for MQSC (Queues, Channels) and SSL refreshes.

---

## 2. Proposed Changes

### [NEW] Provisioning Engine
#### [NEW] [infra.sh](file:///home/pratyush/software/eip-core-integration/eip-core-environment/provisioning/scripts/infra.sh)
- The primary GitOps CLI for the platform.
- Usage: `./infra.sh start postgres` or `./infra.sh clean all`.

### [NEW] Initialization Modules
#### [NEW] [v2-audit-db.yaml](file:///home/pratyush/software/eip-core-integration/eip-core-environment/initialization/db/v2-audit-db.yaml)
- Liquibase changelog for the Audit schema.
#### [NEW] [provision-kafka.sh](file:///home/pratyush/software/eip-core-integration/eip-core-environment/initialization/kafka/provision-kafka.sh)
- Logic to create topics in a running Kafka container.

### [NEW] v2 Kamelets & Routes
#### [NEW] [eip-v2-adapter-action.kamelet.yaml](file:///home/pratyush/software/eip-core-integration/eip-core-environment/platform/kamelets/eip-v2-adapter-action.kamelet.yaml)
- The core audit transformation logic.

---

## 3. Workflow Example: Starting Auditing v2

1. **User runs**: `./startAuditing.sh postgres v2`.
2. **Phase 1 (Provisioning)**: `infra.sh` starts the Postgres container with a volume mapping to `provisioning/volumes/postgres`.
3. **Phase 2 (Initialization)**:
   - `initialization/certs/` generates certificates if missing.
   - `initialization/db/` runs Liquibase to create the `audit_log` table and indexes.
4. **Phase 3 (Runtime)**:
   - The Consumer starts with `EIP_AUDIT_URI=direct:eip-v2-audit-adapter`.
   - The `eip-v2-adapter` Kamelet uses the generic `relational-sink` to persist data.

## 4. Verification Plan

- **Persistence**: Start Postgres, add data, restart, and verify data still exists in `provisioning/volumes`.
- **Modularity**: Start *only* Kafka and verify the provisioning engine creates the topics without requiring a DB.
- **Security**: Verify that the `.env` file passed to the consumer correctly points to the certificates in `initialization/certs`.

## Open Questions

- **Volume Path**: Should we use absolute paths in the workspace or something relative like `./volumes`?
    - **Proposal**: Use relative paths under `provisioning/volumes` to keep the environment self-contained.
