package com.pratyush.eip.core.lib.jta;

import io.quarkus.arc.lookup.LookupIfProperty;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Produces;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import jakarta.transaction.TransactionManager;
import jakarta.transaction.UserTransaction;
import org.springframework.transaction.jta.JtaTransactionManager;

/**
 * CDI producer that bridges Quarkus Narayana JTA into a Spring JtaTransactionManager.
 *
 * Why this exists:
 *   Camel's JmsComponent requires a Spring PlatformTransactionManager to coordinate
 *   JMS transactions. In Quarkus the JTA implementation is Narayana, which exposes
 *   its UserTransaction and TransactionManager as CDI beans.
 *   This producer wraps them into Spring's JtaTransactionManager so YAML-DSL infra
 *   beans can reference it via:
 *
 *     transactionManager: "#jtaTxManager"
 *
 * Activation:
 *   The produced bean is ONLY visible in the Camel registry (and CDI programmatic
 *   lookups) when the runtime property eip.jta.enabled=true.  Set it via env var:
 *
 *     EIP_JTA_ENABLED=true   (used by start-mq-ssl-narayana-tx.ps1)
 *
 *   When the property is absent or false the bean is invisible, so ssl/ and
 *   non-ssl/ environments are unaffected even though this class is always on
 *   the classpath.
 *
 * How the JTA route works:
 *   1. camel-quarkus-jta extension auto-registers PROPAGATION_REQUIRED as a Camel
 *      TransactionPolicy bean (org.apache.camel.spi.Policy).
 *   2. The transacted(ref=PROPAGATION_REQUIRED) EIP step starts a Narayana JTA tx.
 *   3. The JMS component, configured with this JtaTransactionManager, enlists the
 *      IBM MQ XA session as an XA participant in the global JTA transaction.
 *   4. Any other @Transactional CDI bean called in the same route automatically
 *      joins the same transaction — all commit or roll back atomically.
 *
 * Dependency required in build.gradle.kts:
 *   implementation("org.apache.camel.quarkus:camel-quarkus-jta")
 */
@ApplicationScoped
public class EipNarayanaTransactionProducer {

    @Inject
    UserTransaction userTransaction;

    @Inject
    TransactionManager transactionManager;

    /**
     * Produces a Spring JtaTransactionManager backed by Narayana.
     * Named "jtaTxManager" so YAML beans can reference it as "#jtaTxManager".
     * Registered in the Camel registry via Quarkus CDI → Camel bridge.
     *
     * @LookupIfProperty makes this bean invisible to programmatic CDI lookups
     * (and therefore the Camel registry) unless eip.jta.enabled=true at runtime.
     * Direct @Inject still works regardless, but nothing in this codebase
     * injects JtaTransactionManager directly.
     */
    @Produces
    @Named("jtaTxManager")
    @ApplicationScoped
    @LookupIfProperty(name = "eip.jta.enabled", stringValue = "true")
    public JtaTransactionManager jtaTransactionManager() {
        System.out.println(">>> EIP Platform: [V6] JTA Producer activated (eip.jta.enabled=true).");
        
        if (userTransaction == null || transactionManager == null) {
            System.err.println(">>> EIP Platform: [V6 ERROR] Narayana beans missing despite JTA activation!");
            throw new IllegalStateException("Narayana JTA beans (UserTransaction/TransactionManager) are not available.");
        }

        JtaTransactionManager jtaTm = new JtaTransactionManager();
        jtaTm.setUserTransaction(userTransaction);
        jtaTm.setTransactionManager(transactionManager);
        // Validates that both UserTransaction and TransactionManager are usable.
        jtaTm.afterPropertiesSet();
        
        System.out.println(">>> EIP Platform: [V6] Spring JtaTransactionManager successfully produced.");
        return jtaTm;
    }
}
