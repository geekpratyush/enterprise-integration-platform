plugins {
    java
    id("io.quarkus") version "3.34.0"
}

group = "com.pratyush.eip"
version = "1.0.0-SNAPSHOT"

repositories {
    mavenCentral()
    mavenLocal()
}

// Global resolution strategy to force Spring version alignment
configurations.all {
    resolutionStrategy.eachDependency {
        if (requested.group == "org.springframework") {
            useVersion("6.1.13")
            because("Enforcing consistent Spring version to prevent NoSuchMethodErrors between core and jdbc")
        }
    }
}

dependencies {
    // Quarkus BOM
    implementation(platform("io.quarkus:quarkus-bom:3.34.0"))
    implementation(platform("org.apache.camel.quarkus:camel-quarkus-bom:3.33.0"))

    // Force consistent Spring versions across all modules to prevent NoSuchMethodErrors
    val springVersion: String by project
    implementation(platform("org.springframework:spring-framework-bom:${springVersion}"))

    implementation("com.pratyush.eip:eip-core-lib:1.0.0-SNAPSHOT")
    // implementation("org.pratyush.eip:eip-transformer-ui:1.0.0-SNAPSHOT")
    implementation("org.apache.camel.quarkus:camel-quarkus-yaml-dsl")
    implementation("org.apache.camel.quarkus:camel-quarkus-kafka")
    implementation("org.apache.camel.quarkus:camel-quarkus-ftp")
    implementation("org.apache.camel.quarkus:camel-quarkus-sql")
    implementation("org.apache.camel.quarkus:camel-quarkus-elasticsearch")
    implementation("org.apache.camel.quarkus:camel-quarkus-mongodb")
    // implementation("io.quarkus:quarkus-mongodb-client")
    implementation("org.apache.camel.quarkus:camel-quarkus-jsonpath")
    implementation("org.apache.camel.quarkus:camel-quarkus-cassandraql")
    implementation("org.apache.camel.quarkus:camel-quarkus-redis")
    implementation("org.apache.camel:camel-spring-redis")

    // implementation("org.apache.groovy:groovy:5.0.5")
    implementation("io.quarkiverse.groovy:quarkus-groovy:3.34.3")
    // JOOR-based inline Java expression language (used by intelligent-sink-adapter-action)
    implementation("org.apache.camel.quarkus:camel-quarkus-joor")
    // DataSonnet JSON-to-JSON mapping language (used by intelligent-sink-adapter-action)
    // Must be on classpath even when inlineScript is empty: Camel validates all choice
    // branches eagerly at route creation time regardless of runtime conditions.
    implementation("org.apache.camel.quarkus:camel-quarkus-datasonnet")

    // Solace Messaging (Jakarta-native client verified to work in this environment)
    implementation("com.solacesystems:sol-jms-jakarta:10.29.1")

    // Relational Drivers (Quarkus-managed JDBC extensions)
    implementation("io.quarkus:quarkus-jdbc-postgresql")
    implementation("io.quarkus:quarkus-jdbc-mysql")
    implementation("io.quarkus:quarkus-jdbc-mssql")
    implementation("io.quarkus:quarkus-jdbc-oracle")

    implementation("io.quarkus:quarkus-tls-registry:3.34.3")
    implementation("com.datasonnet:datasonnet-mapper:3.0.1.1") {
        exclude(group = "ch.qos.logback", module = "logback-classic")
        exclude(group = "ch.qos.logback", module = "logback-core")
    }


    // NoSQL Drivers
    implementation("org.apache.camel.quarkus:camel-quarkus-file")
    implementation("org.apache.activemq:artemis-jakarta-client:2.36.0")
    implementation("org.apache.camel.quarkus:camel-quarkus-jms")
    implementation("org.apache.camel.quarkus:camel-quarkus-jta")
    implementation("org.apache.camel.quarkus:camel-quarkus-jackson")
    implementation("org.apache.camel.quarkus:camel-quarkus-timer")
    implementation("org.apache.camel:camel-core-catalog:4.18.1")
    implementation("org.apache.camel.quarkus:camel-quarkus-kamelet")
    implementation("org.apache.camel.kamelets:camel-kamelets")
    implementation("org.apache.camel.quarkus:camel-quarkus-catalog")
    implementation("org.apache.camel.quarkus:camel-quarkus-direct")
    implementation("org.apache.camel.quarkus:camel-quarkus-seda")
    implementation("org.apache.camel.quarkus:camel-quarkus-microprofile-fault-tolerance")
    implementation("org.apache.camel.quarkus:camel-quarkus-groovy")
    implementation("org.apache.camel.quarkus:camel-quarkus-http")
    implementation("org.apache.camel.quarkus:camel-quarkus-rest")
    implementation("com.ibm.mq:com.ibm.mq.jakarta.client:9.4.5.0")
    // implementation("io.hawt:hawtio-quarkus:5.0.1")

    // Generic JMS provider
    implementation("org.apache.commons:commons-dbcp2:2.12.0")
    implementation("org.messaginghub:pooled-jms:3.1.2")

    // Spring Dependencies for spring-redis support
    implementation("org.springframework:spring-expression")
    implementation("org.springframework:spring-context")
    implementation("org.springframework.data:spring-data-redis:3.3.4")

    testImplementation("io.quarkus:quarkus-junit5")
}

// NOTE: All Liquibase migrations are handled by eip-core-liquibase (fat JAR).
// initialize.sh invokes that JAR before starting the consumer — no Liquibase tasks here.

java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

// ── Java Modularity Opens for Netty on Java 17/21 ────────────────────────────
// Required for Netty's direct buffer cleaners to work on modern JDKs.
val modularityOpens = listOf(
    "--add-opens=java.base/java.nio=ALL-UNNAMED",
    "--add-opens=java.base/jdk.internal.ref=ALL-UNNAMED",
    "--add-opens=java.base/sun.nio.ch=ALL-UNNAMED"
)

tasks.withType<io.quarkus.gradle.tasks.QuarkusDev> {
    jvmArguments.addAll(modularityOpens)
    jvmArguments.addAll(
        "-Dquarkus.console.enabled=true",
        "-Dquarkus.console.color=true",
        "-Dquarkus.console.basic=false"
    )
}
