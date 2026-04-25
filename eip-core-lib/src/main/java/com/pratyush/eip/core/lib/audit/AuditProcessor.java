package com.pratyush.eip.core.lib.audit;

import com.pratyush.eip.core.lib.repository.StateTrackingRepository;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.apache.camel.Exchange;
import org.apache.camel.Processor;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

@ApplicationScoped
public class AuditProcessor implements Processor {

    @Inject
    StateTrackingRepository repository;

    @Override
    public void process(Exchange exchange) throws Exception {
        Map<String, Object> auditRecord = new HashMap<>();
        
        // Generate generic audit metadata
        auditRecord.put("auditId", UUID.randomUUID().toString());
        auditRecord.put("timestamp", LocalDateTime.now().toString());
        auditRecord.put("correlationId", exchange.getIn().getHeader("breadcrumbId", String.class));
        auditRecord.put("routeId", exchange.getFromRouteId());
        
        // Optionally capture payload (if needed by platform design)
        auditRecord.put("payload", exchange.getIn().getBody(String.class));
        
        // Send to the repository (which uses the dynamic EIP_AUDIT_URI)
        repository.track(auditRecord);
    }
}
