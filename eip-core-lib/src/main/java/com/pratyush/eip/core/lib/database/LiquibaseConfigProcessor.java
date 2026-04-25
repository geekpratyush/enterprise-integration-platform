package com.pratyush.eip.core.lib.database;

// import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Instance;
import jakarta.inject.Inject;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import io.quarkus.liquibase.LiquibaseFactory;
import liquibase.Liquibase;
// import liquibase.database.Database;
// import liquibase.database.DatabaseFactory;
// import liquibase.database.jvm.JdbcConnection;
// import liquibase.resource.ClassLoaderResourceAccessor;
import org.jboss.logging.Logger;

/**
 * Multi-Database and Multi-Tenant Liquibase Configuration Processor
 * Handles initialization of Liquibase migrations across multiple database types
 * and tenants
 */
@ApplicationScoped
public class LiquibaseConfigProcessor {

    private static final Logger LOG = Logger.getLogger(LiquibaseConfigProcessor.class);

    @Inject
    Instance<LiquibaseFactory> liquibaseFactory;

    @ConfigProperty(name = "eip.liquibase.enabled", defaultValue = "false")
    boolean liquibaseEnabled;

    @ConfigProperty(name = "eip.liquibase.migrate-at-start", defaultValue = "false")
    boolean migrateAtStart;

    @ConfigProperty(name = "eip.liquibase.migration-paths", defaultValue = "")
    String migrationPaths;

    @ConfigProperty(name = "eip.liquibase.database-types", defaultValue = "")
    String databaseTypes;

    /**
     * Initialize Liquibase migrations for configured database types and migration
     * paths
     * Supports multiple tenants and database types
     */
    public void initializeMigrations() {
        if (!liquibaseEnabled) {
            LOG.info("Liquibase is disabled. Skipping migrations.");
            return;
        }

        if (!migrateAtStart) {
            LOG.info("Liquibase migrate-at-start is disabled. Migrations can be run manually.");
            return;
        }

        try {
            List<String> paths = parseMigrationPaths();
            List<String> dbTypes = parseDatabaseTypes();

            LOG.infof("Starting Liquibase migrations for %d paths and %d database types",
                    paths.size(), dbTypes.size());

            // Run migrations for each path
            for (String path : paths) {
                runMigrationsForPath(path, dbTypes);
            }

            LOG.info("Liquibase migrations completed successfully");
        } catch (Exception e) {
            LOG.errorf("Failed to initialize Liquibase migrations: %s", e.getMessage());
            throw new RuntimeException("Liquibase migration failed", e);
        }
    }

    /**
     * Run migrations for a specific path and database types
     * 
     * @param migrationPath Path to migration files
     * @param databaseTypes List of database types to migrate
     */
    private void runMigrationsForPath(String migrationPath, List<String> databaseTypes)
            throws Exception {
        LOG.infof("Running migrations for path: %s", migrationPath);

        if (liquibaseFactory.isUnsatisfied()) {
            LOG.info("No LiquibaseFactory available (no datasource configured). Skipping migrations.");
            return;
        }

        try {
            Liquibase liquibase = liquibaseFactory.get().createLiquibase();

            if (liquibase != null) {
                LOG.infof("Executing Liquibase changelog: %s", migrationPath);
                liquibase.update("liquibase-context:" + String.join(",", databaseTypes));
                LOG.infof("Migration completed for path: %s", migrationPath);
            } else {
                LOG.warnf("Liquibase instance is null for path: %s", migrationPath);
            }
        } catch (Exception e) {
            LOG.errorf("Error running migrations for path %s: %s", migrationPath, e.getMessage());
            throw e;
        }
    }

    /**
     * Parse and validate migration paths from configuration
     * Format: path1,path2,path3
     * 
     * @return List of valid migration paths
     */
    private List<String> parseMigrationPaths() {
        if (migrationPaths == null || migrationPaths.trim().isEmpty()) {
            LOG.debug("No migration paths configured, using default path");
            return List.of("db/changelog/db.changelog-main.yaml");
        }

        return List.of(migrationPaths.split(","))
                .stream()
                .map(String::trim)
                .filter(path -> !path.isEmpty())
                .collect(Collectors.toList());
    }

    /**
     * Parse and validate database types from configuration
     * Format: postgres,mysql,oracle,sqlserver
     * 
     * @return List of valid database types
     */
    private List<String> parseDatabaseTypes() {
        if (databaseTypes == null || databaseTypes.trim().isEmpty()) {
            LOG.debug("No specific database types configured, will use all");
            return List.of("postgresql", "mysql", "oracle", "mssql");
        }

        return List.of(databaseTypes.split(","))
                .stream()
                .map(String::trim)
                .filter(type -> !type.isEmpty())
                .collect(Collectors.toList());
    }

    /**
     * Check if Liquibase is properly configured
     * 
     * @return true if Liquibase can be used, false otherwise
     */
    public boolean isConfigured() {
        return liquibaseEnabled;
    }

    /**
     * Get current configuration status
     * 
     * @return Configuration summary
     */
    public String getConfigurationStatus() {
        StringBuilder status = new StringBuilder();
        status.append("Liquibase Configuration Status:\n");
        status.append("  Enabled: ").append(liquibaseEnabled).append("\n");
        status.append("  Migrate at Start: ").append(migrateAtStart).append("\n");
        status.append("  Migration Paths: ").append(migrationPaths.isEmpty() ? "default" : migrationPaths).append("\n");
        status.append("  Database Types: ").append(databaseTypes.isEmpty() ? "all supported" : databaseTypes)
                .append("\n");
        return status.toString();
    }
}
