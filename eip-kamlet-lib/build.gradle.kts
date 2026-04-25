plugins {
    `java-library`
    `maven-publish`
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

// No Java sources — this library is a pure Kamlet resource JAR.
// The kamelets/ directory under src/main/resources is picked up
// automatically by camel-quarkus-kamelet on any consumer classpath.

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
