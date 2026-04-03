package com.gasthaus.config;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * One-time compatibility migration for the Java schema.
 *
 * Context:
 * Reviews moved from item-level to order-level, so reviews.menu_item_id must be
 * nullable. Some existing databases still have the old NOT NULL constraint.
 *
 * Why this class exists even with ddl-auto=update:
 * Hibernate's schema update does not reliably relax column nullability in every
 * database/version combination. This migration makes the change explicit and
 * idempotent at startup.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class SchemaCompatibilityMigration {

    private final JdbcTemplate jdbcTemplate;

    @Value("${spring.jpa.properties.hibernate.default_schema:public}")
    private String configuredSchema;

    @EventListener(ApplicationReadyEvent.class)
    public void migrateReviewsTableForOrderLevelReviews() {
        String schema = resolveSafeSchema(configuredSchema);
        relaxMenuItemNullability(schema);
        dropLegacyItemBasedUniqueConstraint(schema);
        ensureOrderLevelUniqueConstraint(schema);
    }

    private void relaxMenuItemNullability(String schema) {
        List<String> nullableFlags = jdbcTemplate.query(
                """
                SELECT is_nullable
                FROM information_schema.columns
                WHERE table_schema = ?
                  AND table_name = 'reviews'
                  AND column_name = 'menu_item_id'
                """,
                (rs, rowNum) -> rs.getString(1),
                schema
        );

        if (nullableFlags.isEmpty()) {
            log.info("[schema-migration] Column {}.reviews.menu_item_id not found; skipping", schema);
            return;
        }

        if ("YES".equalsIgnoreCase(nullableFlags.get(0))) {
            return;
        }

        try {
            jdbcTemplate.execute("ALTER TABLE " + schema + ".reviews ALTER COLUMN menu_item_id DROP NOT NULL");
            log.info("[schema-migration] Updated {}.reviews.menu_item_id to nullable", schema);
        } catch (DataAccessException ex) {
            log.warn("[schema-migration] Failed to relax {}.reviews.menu_item_id nullability: {}",
                    schema,
                    ex.getMostSpecificCause() != null
                            ? ex.getMostSpecificCause().getMessage()
                            : ex.getMessage());
        }
    }

    private void ensureOrderLevelUniqueConstraint(String schema) {
        Integer existing = jdbcTemplate.queryForObject(
                """
                SELECT COUNT(*)
                FROM information_schema.table_constraints
                WHERE table_schema = ?
                  AND table_name = 'reviews'
                  AND constraint_type = 'UNIQUE'
                  AND constraint_name = 'uk_review_customer_order'
                """,
                Integer.class,
                schema
        );

        if (existing != null && existing > 0) {
            return;
        }

        try {
            jdbcTemplate.execute(
                    "ALTER TABLE " + schema
                            + ".reviews ADD CONSTRAINT uk_review_customer_order UNIQUE (customer_id, order_id)"
            );
            log.info("[schema-migration] Added unique constraint uk_review_customer_order on {}.reviews", schema);
        } catch (DataAccessException ex) {
            log.warn("[schema-migration] Failed to add uk_review_customer_order on {}.reviews: {}",
                    schema,
                    ex.getMostSpecificCause() != null
                            ? ex.getMostSpecificCause().getMessage()
                            : ex.getMessage());
        }
    }

    private void dropLegacyItemBasedUniqueConstraint(String schema) {
        Integer existing = jdbcTemplate.queryForObject(
                """
                SELECT COUNT(*)
                FROM information_schema.table_constraints
                WHERE table_schema = ?
                  AND table_name = 'reviews'
                  AND constraint_type = 'UNIQUE'
                  AND constraint_name = 'uk_review_customer_item_order'
                """,
                Integer.class,
                schema
        );

        if (existing == null || existing == 0) {
            return;
        }

        try {
            jdbcTemplate.execute(
                    "ALTER TABLE " + schema
                            + ".reviews DROP CONSTRAINT uk_review_customer_item_order"
            );
            log.info("[schema-migration] Dropped legacy constraint uk_review_customer_item_order on {}.reviews", schema);
        } catch (DataAccessException ex) {
            log.warn("[schema-migration] Failed to drop uk_review_customer_item_order on {}.reviews: {}",
                    schema,
                    ex.getMostSpecificCause() != null
                            ? ex.getMostSpecificCause().getMessage()
                            : ex.getMessage());
        }
    }

    private String resolveSafeSchema(String schema) {
        if (schema == null || schema.isBlank()) {
            return "public";
        }

        String trimmed = schema.trim();

        // Allow only simple unquoted identifiers to avoid SQL injection risk.
        if (trimmed.matches("[A-Za-z_][A-Za-z0-9_]*")) {
            return trimmed;
        }

        log.warn("[schema-migration] Unsupported schema identifier '{}'; falling back to public", trimmed);
        return "public";
    }
}
