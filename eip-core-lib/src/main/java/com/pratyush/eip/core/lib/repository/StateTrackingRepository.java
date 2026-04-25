package com.pratyush.eip.core.lib.repository;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import org.apache.camel.ProducerTemplate;
import java.util.Map;

@ApplicationScoped
public class StateTrackingRepository {

    @Inject
    ProducerTemplate producerTemplate;

    @Inject
    @Named("eipAuditUri")
    String auditUri;

    public void track(Map<String, Object> state) {
        if (auditUri == null || auditUri.isEmpty()) {
            return; // Auditing disabled
        }
        // Dispatches the state to any configured Camel component (Mongo, SQL, Kafka, etc.)
        producerTemplate.sendBody(auditUri, state);
    }
}
