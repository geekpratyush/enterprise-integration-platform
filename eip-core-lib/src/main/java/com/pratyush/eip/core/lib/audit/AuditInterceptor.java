package com.pratyush.eip.core.lib.audit;

import jakarta.enterprise.context.ApplicationScoped;
import org.jboss.logging.Logger;

@ApplicationScoped
public class AuditInterceptor {
    private static final Logger LOG = Logger.getLogger(AuditInterceptor.class);

    public void audit(String action, Object details) {
        LOG.infof("AUDIT: Action=%s, Details=%s", action, details);
    }
}
