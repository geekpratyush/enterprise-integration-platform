package com.pratyush.eip.core.lib.filter;

import java.io.IOException;
import java.nio.file.*;
import java.nio.file.attribute.BasicFileAttributes;
import java.util.*;
import java.util.regex.Pattern;

public class EipIgnoreEngine {

    private final List<Pattern> ignorePatterns = new ArrayList<>();

    public EipIgnoreEngine(Path rootDir) {
        // Platform Global: If MongoDB is not explicitly enabled, skip all mongo-related
        // config
        String mongoEnabled = System.getenv("MONGO_ENABLED");
        if (mongoEnabled == null || !mongoEnabled.equalsIgnoreCase("true")) {
            ignorePatterns.add(createPattern("*mongo*"));
        }

        Path ignoreFile = rootDir.resolve(".eipignore");
        if (Files.exists(ignoreFile)) {
            try {
                List<String> lines = Files.readAllLines(ignoreFile);
                for (String line : lines) {
                    line = line.trim();
                    if (!line.isEmpty() && !line.startsWith("#")) {
                        ignorePatterns.add(createPattern(line));
                    }
                }
            } catch (IOException e) {
                System.err.println("Failed to read .eipignore: " + e.getMessage());
            }
        }
    }

    private Pattern createPattern(String glob) {
        // Narrow glob: ensure *mongo* only matches 'mongo' as a segment if possible
        String regex = glob.replace(".", "\\.")
                .replace("*", ".*")
                .replace("?", ".")
                .replace("/", "[\\\\/]");
        return Pattern.compile("^" + regex + "$|.*[\\\\/]" + regex + "$|.*[\\\\/]" + regex + "[\\\\/].*",
                Pattern.CASE_INSENSITIVE);
    }

    public boolean isIgnored(Path path, Path rootDir) {
        // Relativize to ensure we don't accidentally match parent directories (like
        // /software/ or /ssl-jms/)
        String pathStr = rootDir.relativize(path).toString();
        for (Pattern pattern : ignorePatterns) {
            if (pattern.matcher(pathStr).matches()) {
                return true;
            }
        }
        return false;
    }

    public List<Path> scanConfigDirectory(Path configDir) throws IOException {
        System.out.printf(">>> EIP Platform: [V6] Scanning directory: %s%n", configDir);
        List<Path> validYamlFiles = new ArrayList<>();
        Files.walkFileTree(configDir, new SimpleFileVisitor<>() {
            @Override
            public FileVisitResult preVisitDirectory(Path dir, BasicFileAttributes attrs) {
                if (dir.equals(configDir)) {
                    return FileVisitResult.CONTINUE;
                }
                if (isIgnored(dir, configDir)) {
                    System.out.printf(">>> EIP Platform: [V6 IGNORE] Skipping directory: %s%n", dir);
                    return FileVisitResult.SKIP_SUBTREE;
                }
                return FileVisitResult.CONTINUE;
            }

            @Override
            public FileVisitResult visitFile(Path file, BasicFileAttributes attrs) {
                String fileStr = file.toString().toLowerCase();
                if (!isIgnored(file, configDir)) {
                    if (fileStr.endsWith(".yaml") || fileStr.endsWith(".yml")) {
                        System.out.printf(">>> EIP Platform: [V6 ACCEPT] Found YAML: %s%n", file.getFileName());
                        validYamlFiles.add(file);
                    } else {
                        System.out.printf(">>> EIP Platform: [V6 SKIP] Non-YAML file: %s%n", file.getFileName());
                    }
                } else {
                    System.out.printf(">>> EIP Platform: [V6 IGNORE] Skipping file: %s%n", file.getFileName());
                }
                return FileVisitResult.CONTINUE;
            }
        });
        System.out.printf(">>> EIP Platform: [V6] Scan completed. Found %d valid files.%n", validYamlFiles.size());
        return validYamlFiles;
    }
}
