package com.gasthaus.dto.tables;

/**
 * Response for GET /tables/stats.
 *
 * NestJS equivalent: { total, occupied, available } returned by TablesService.getTableStats()
 */
public record TableStatsResponse(long total, long occupied, long available) {
}
