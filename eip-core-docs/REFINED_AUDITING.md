# Refined EIP Auditing System (Kamelet-Driven)

The auditing system has been simplified from a complex directory structure into a metadata-driven approach using a single universal Kamelet: `eip-audit-action`.

## 1. The Audit Kamelet: `eip-audit-action`

**Location**: `eip-core-environment/platform/kamelets/eip-audit-action.kamelet.yaml`

This Kamelet reshapes the message body into a standard audit envelope and applies optional encryption. It returns a JSON string that can be sent to any sink.

### Parameters
| Parameter | Default | Description |
|---|---|---|
| `encryption` | `NONE` | Encryption mode: `NONE`, `BASE64`, or `AES`. |
| `cryptoBean` | `auditEncryptionProcessor` | The CDI bean used for AES encryption. |

### Encryption Configuration (AES)
When `encryption=AES` is selected, the system uses the `auditEncryptionProcessor` bean. This bean derives its key from the platform environment:
*   **Property/Variable**: `EIP_AUDIT_ENCRYPTION_KEY`
*   **Source**: Typically set in your `.env` profile or injected via Vault.

## 2. Standard Pattern: Wire-Tap + Sink

The new standard for auditing is to use a `wireTap` to a dedicated audit route, ensuring ZERO latency impact on the business logic.

### Example: Audit to SQL (Oracle/Postgres/MySQL)
```yaml
- from: "timer:trigger?period=10s"
  steps:
    - setBody: { constant: "Sensitive Business Data" }
    - wireTap:
        uri: "direct:standard-audit"

- from:
    uri: "direct:standard-audit"
    steps:
      # 1. Generate encrypted JSON envelope
      - to: "kamelet:eip-audit-action?encryption=AES"
      # 2. Persist to DB using standardized SQL Sink
      - to:
          uri: "kamelet:eip-sql-sink"
          parameters:
            connectionBean: "eip"
            table: "AUDIT_EVENTS"
```

### Example: Audit to Console
```yaml
- from: "direct:simple-log"
  steps:
    - to: "kamelet:eip-audit-action?encryption=BASE64"
    - to: "log:audit-traffic?showAll=true"
```

## 3. SQL Source Kamelet

For polling operations, use the `eip-sql-source` Kamelet.

### Example: Polling for Audit Review
```yaml
- from:
    uri: "kamelet:eip-sql-source"
    parameters:
      connectionBean: "eip"
      table: "AUDIT_EVENTS"
      delay: 30000
  steps:
    - log: "New Audit Event detected: ${body}"
```

## 4. Standard Audit Envelope
The JSON produced by `eip-audit-action` follows this structure:

```json
{
  "auditId": "AUD-a1b2...",
  "timestamp": "2026-04-24T19:26:00.000",
  "correlationId": "EVENT-id",
  "routeId": "business-route",
  "payload": "Base64OrAESCiphertext",
  "isEncrypted": true
}
```

## 4. Why this is better
*   **Zero-Code**: No hand-written JSON serialization in your business routes.
*   **Flexible**: Move from DB logging to Kafka or Console just by changing the second `to:` step.
*   **Lean**: Replaces 1000s of lines of legacy route YAML with a single reusable component.
