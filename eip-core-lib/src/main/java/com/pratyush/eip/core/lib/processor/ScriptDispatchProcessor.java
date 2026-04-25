package com.pratyush.eip.core.lib.processor;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import org.apache.camel.CamelContext;
import org.apache.camel.Exchange;
import org.apache.camel.Expression;
import org.apache.camel.Processor;
import org.apache.camel.spi.Language;
import org.jboss.logging.Logger;

/**
 * Runtime script dispatcher for the {@code intelligent-sink-adapter-action} Kamelet.
 *
 * <p>Camel's YAML DSL compiles every language expression eagerly at route creation time,
 * even inside a {@code choice} branch whose condition can never be true at runtime (e.g.
 * when {@code inlineScript} is empty). This causes DataSonnet and JOOR to throw parse
 * exceptions on empty strings before the first message is processed.
 *
 * <p>This processor solves that by deferring language resolution and expression compilation
 * entirely to message-processing time:
 * <ol>
 *   <li>The Kamelet sets {@code scriptLanguage} and {@code inlineScript} as Exchange
 *       properties before calling this processor.</li>
 *   <li>This processor reads those properties, resolves the Camel {@link Language} from
 *       the {@link CamelContext}, compiles the expression, evaluates it against the
 *       exchange, and writes the result back to the body.</li>
 *   <li>When {@code inlineScript} is blank the processor is a no-op.</li>
 * </ol>
 *
 * <p>Supported {@code scriptLanguage} values: {@code datasonnet}, {@code groovy}, {@code java}
 * (JOOR). Any Camel language present on the classpath can be used — the name must match
 * the Camel language component identifier.
 */
@ApplicationScoped
@Named("scriptDispatchProcessor")
public class ScriptDispatchProcessor implements Processor {

    private static final Logger LOG = Logger.getLogger(ScriptDispatchProcessor.class);

    static final String PROP_SCRIPT   = "inlineScript";
    static final String PROP_LANGUAGE = "scriptLanguage";

    @Inject
    CamelContext camelContext;

    @Override
    public void process(Exchange exchange) throws Exception {
        String script   = exchange.getProperty(PROP_SCRIPT,   "", String.class);
        String language = exchange.getProperty(PROP_LANGUAGE, "groovy", String.class);

        if (script == null || script.isBlank()) {
            // Nothing to evaluate — fast path, body unchanged.
            return;
        }

        // Resolve the language at runtime — no eager compilation in YAML.
        Language lang = camelContext.resolveLanguage(language);
        if (lang == null) {
            throw new IllegalStateException(
                "ScriptDispatchProcessor: unknown script language '" + language +
                "'. Ensure camel-quarkus-" + language + " is on the classpath.");
        }

        LOG.debugf("ScriptDispatchProcessor: evaluating %s script (%d chars)", language, script.length());

        Expression expr = lang.createExpression(script);
        expr.init(camelContext);

        Object result = expr.evaluate(exchange, Object.class);
        exchange.getIn().setBody(result);

        LOG.debugf("ScriptDispatchProcessor: body replaced with %s result",
                   result == null ? "null" : result.getClass().getSimpleName());
    }
}
