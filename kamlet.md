# EIP Kamlet Platform Development Roadmap

## Objective
Create a metadata-driven Kamlet extension library (`eip-kamlet-extn`) and a corresponding consumer shell (`eip-kamlet-consumer`) to provide resilient, multi-tenant IBM MQ connectivity.

## Project Structure
- `eip-kamlet-extn`: Library containing Kamlet definitions (YAML) and potentially any required custom Java beans.
- `eip-kamlet-consumer`: Quarkus + Camel application that consumes these Kamlets.

## 1. Phase 1: IBM MQ Kamlet (`ibmmq-connector`)
### Features
- [ ] Support for all standard IBM MQ parameters (hostname, port, channel, queueManager).
- [ ] Multi-tenant support via parameterized environment variables.
- [ ] Support for various connection modes (Non-SSL, SSL/TLS).
- [ ] Transaction support (Local/XA).
- [ ] Polling/Consumer parameters (concurrentConsumers, maxMessagesPerTask, etc.).
- [ ] Resilient error handling (Retry, Backoff) using industry standards.

### Dependencies
- `com.ibm.mq:com.ibm.mq.jakarta.client:9.4.5.0`
- `camel-quarkus-jms`
- `camel-quarkus-yaml-dsl` (for Kamlet definitions)

## 2. Phase 2: Consumer Application (`eip-kamlet-consumer`)
### Features
- [ ] Empty Quarkus shell powered by `eip-kamlet-extn`.
- [ ] Template routes demonstrating the usage of the IBM MQ Kamlet.
- [ ] Integration with environment variables for multi-tenancy.
- [ ] Resilient routing patterns (Circuit Breaker, Dead Letter Channel).

## 3. Implementation Log
- [ ] Create folder structure for `eip-kamlet-extn`.
- [ ] Create folder structure for `eip-kamlet-consumer`.
- [ ] Define `ibmmq-source.kamelet.yaml`.
- [ ] Define `ibmmq-sink.kamelet.yaml`.
- [ ] Setup `build.gradle.kts` for both projects.
- [ ] Create sample route in `eip-kamlet-consumer`.
