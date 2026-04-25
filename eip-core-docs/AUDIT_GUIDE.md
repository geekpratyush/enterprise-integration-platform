# EIP Core Platform: Auditing & State Tracking Guide

## 2. Auditing Strategies

The platform supports two modes of operation:

### Strategy A: Selective Auditing (Manual)
In your Kaoto YAML DSL, you can invoke the auditor at specific business steps:
```yaml
- to: "bean:auditProcessor"
```

### Strategy B: Global Auditing (Automatic)
To capture **every** message entering the platform without modifying your routes, set:
```bash
EIP_AUDIT_GLOBAL=true
```
When this is enabled, the EIP engine's internal interceptor will automatically audit all events before they continue on their defined routes.

## 3. Configuration Examples (No-Code)

### Option A: MongoDB (Unstructured)
To audit to a MongoDB collection, set the following environment variable:
```bash
EIP_AUDIT_URI=mongodb:auditSvc?database=eip_audit&collection=audit_log&operation=insert
```
*Note: Ensure your consumer includes `implementation("org.apache.camel.quarkus:camel-quarkus-mongodb")` if you choose this.*

### Option B: SQL / Relational (Structured)
To audit to a PostgreSQL or Oracle table, set:
```bash
EIP_AUDIT_URI=sql:INSERT INTO EIP_AUDIT (ID, PAYLOAD, TS) VALUES (:#${body[auditId]}, :#${body[payload]}, :#${body[timestamp]})
```
*Note: Ensure your consumer includes `implementation("org.apache.camel.quarkus:camel-quarkus-sql")` and the appropriate JDBC driver.*

### Option C: Kafka (Data Lake / Event Hub)
To stream audits to a global auditing topic:
```bash
EIP_AUDIT_URI=kafka:global.audit.events?brokers={{env:KAFKA_BROKERS}}
```
*Note: Ensure your consumer includes `implementation("org.apache.camel.quarkus:camel-quarkus-kafka")`.*

## 3. Disabling Auditing
If `EIP_AUDIT_URI` is not provided (or is empty), auditing is automatically disabled, and the platform remains in its "Quiet" zero-connectivity state.

## 4. How to Use in Routes
In your Kaoto routes, you can invoke the auditor by calling the platform bean:
```yaml
- to: "bean:auditProcessor"
```
Or use it as an `interceptFrom` in your global configuration to audit every single incoming message automatically.
