plugins {
    `java-library`
    `maven-publish`
    id("org.kordamp.gradle.jandex") version "2.1.0"
}

group = "com.pratyush.eip"
version = "1.0.0-SNAPSHOT"

java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

repositories {
    mavenCentral()
}

dependencies {
    api(platform("io.quarkus:quarkus-bom:3.34.0"))
    api(platform("org.apache.camel.quarkus:camel-quarkus-bom:3.33.0"))
    api("org.apache.camel.quarkus:camel-quarkus-core")
    api("org.apache.camel:camel-api:4.18.1")
    api("org.apache.camel:camel-support:4.18.1")
    api("org.apache.camel.quarkus:camel-quarkus-mongodb")
    api("org.apache.camel.quarkus:camel-quarkus-microprofile-health")
    api("io.quarkus:quarkus-resteasy")
    api("io.quarkus:quarkus-reactive-routes")

    // Spring transaction abstraction
    api("org.springframework:spring-tx")
    api("org.springframework:spring-beans:6.1.12")
    api("io.quarkus:quarkus-narayana-jta:3.34.3")
    // Quarkus Liquibase extension
    api("io.quarkus:quarkus-liquibase")
    // Jayway JsonPath — used by JsonPathEncryptionProcessor for selective field encryption
    api("com.jayway.jsonpath:json-path:2.9.0")
    // Redis (for RedisCamelRegistrar factory bridge)
    implementation("org.springframework:spring-context:6.1.12")
    implementation("org.springframework.data:spring-data-redis:3.1.5")
    implementation("redis.clients:jedis:4.4.3")

}

publishing {
    publications {
        create<MavenPublication>("maven") {
            from(components["java"])
        }
    }
    repositories {
        mavenLocal()
    }
}
