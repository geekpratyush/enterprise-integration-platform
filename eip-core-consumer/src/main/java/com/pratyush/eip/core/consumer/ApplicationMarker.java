package com.pratyush.eip.core.consumer;

import jakarta.enterprise.context.ApplicationScoped;

/**
 * Marker class to ensure the eip-core-consumer's build and quarkusDev loop
 * are initialized when no other source files are present.
 */
@ApplicationScoped
public class ApplicationMarker {
}
