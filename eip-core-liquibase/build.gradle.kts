// eip-core-liquibase — standalone Liquibase migration runner
//
// Builds a fat (shadow) JAR that bundles Liquibase core, every JDBC driver, and the
// MongoDB + Cassandra extensions. The JAR is invoked directly from initialize.sh:
//
//   java [JAVA_TOOL_OPTIONS] -jar eip-core-liquibase.jar \
//       --search-path=$EIP_LB_SEARCH_PATH   \
//       --changelog-file=$EIP_LB_CHANGELOG  \
//       --url=$EIP_LB_URL                   \
//       --username=$EIP_LB_USERNAME         \
//       --password=$EIP_LB_PASSWORD         \
//       update
//
// All values come from environment variables — no hard-coded connection strings.

plugins {
    java
    id("com.gradleup.shadow") version "8.3.6"
}

group = "com.pratyush.eip"
version = "1.0.0-SNAPSHOT"

repositories {
    mavenCentral()
}

val liquibaseVersion = "4.33.0"

dependencies {
    // ── Liquibase core ──────────────────────────────────────────────────────
    implementation("org.liquibase:liquibase-core:$liquibaseVersion")
    implementation("info.picocli:picocli:4.7.5")          // required by Liquibase CLI

    // ── JDBC drivers ────────────────────────────────────────────────────────
    implementation("org.postgresql:postgresql:42.7.5")
    implementation("com.mysql:mysql-connector-j:9.3.0")
    implementation("com.oracle.database.jdbc:ojdbc11:23.7.0.25.01")
    implementation("com.microsoft.sqlserver:mssql-jdbc:12.8.1.jre11")

    // ── NoSQL extensions ────────────────────────────────────────────────────
    // MongoDB: liquibase-mongodb bundles its own MongoDB Java driver subset.
    implementation("org.liquibase.ext:liquibase-mongodb:$liquibaseVersion")
    // Cassandra: liquibase-cassandra uses the DataStax OSS driver.
    implementation("org.liquibase.ext:liquibase-cassandra:$liquibaseVersion")
    implementation("com.datastax.oss:java-driver-core:4.17.0")
}

java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

// ── Shadow (fat) JAR ─────────────────────────────────────────────────────────
tasks.shadowJar {
    archiveBaseName.set("eip-core-liquibase")
    archiveClassifier.set("")   // no "-all" suffix
    archiveVersion.set("")      // version-free name: eip-core-liquibase.jar
    manifest {
        attributes["Main-Class"] = "liquibase.integration.commandline.LiquibaseCommandLine"
    }
    // Merge service descriptors so Liquibase's SPI auto-discovery still works inside
    // the fat JAR (drivers, change-log parsers, extension entry points).
    mergeServiceFiles()
    // Exclude signature files from bundled JARs — they are invalid in a fat JAR and
    // cause SecurityException at runtime.
    exclude("META-INF/*.SF", "META-INF/*.DSA", "META-INF/*.RSA")
}

// Make the default 'build' task produce the fat JAR.
tasks.build {
    dependsOn(tasks.shadowJar)
}
