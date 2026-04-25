package com.pratyush.eip.core.lib.audit;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import org.apache.camel.CamelContext;
import org.apache.camel.NamedNode;
import org.apache.camel.Processor;
import org.apache.camel.builder.RouteBuilder;
import org.apache.camel.spi.InterceptStrategy;
import org.jboss.logging.Logger;

@ApplicationScoped
public class GlobalAuditInterceptor implements InterceptStrategy {

    private static final Logger LOG = Logger.getLogger(GlobalAuditInterceptor.class);

    @Inject
    @Named("eipAuditGlobal")
    boolean isGlobalAuditEnabled;

    @Inject
    AuditProcessor auditProcessor;

    @Override
    public Processor wrapProcessorInInterceptors(CamelContext context, NamedNode definition,
            Processor target, Processor nextTarget) throws Exception {

        // Only apply if global auditing is enabled in the environment
        if (!isGlobalAuditEnabled) {
            return target;
        }

        // We wrap the processor with our audit logic
        return exchange -> {
            // Log that a global audit is occurring for this node
            LOG.debugf("Global Audit interceptor for node: %s", definition.getId());

            // Invoke the audit processor
            auditProcessor.process(exchange);

            // Proceed to the original target
            target.process(exchange);
        };
    }
}
