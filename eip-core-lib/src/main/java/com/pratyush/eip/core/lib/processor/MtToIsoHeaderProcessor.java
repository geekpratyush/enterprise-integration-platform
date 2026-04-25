package com.pratyush.eip.core.lib.processor;

import org.apache.camel.Exchange;
import org.apache.camel.Processor;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Named;

@ApplicationScoped
@Named("mtToIsoHeaderProcessor")
public class MtToIsoHeaderProcessor implements Processor {

    @Override
    public void process(Exchange exchange) throws Exception {
        // Sample transformation of MT headers to ISO 20022 equivalent
        String oldHeader = exchange.getIn().getHeader("CamelFileName", String.class);
        exchange.getIn().setHeader("EipTargetFormat", "ISO20022");
        exchange.getIn().setHeader("EipOriginalSource", oldHeader);
    }
}
