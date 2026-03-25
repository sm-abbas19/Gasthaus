package com.gasthaus.dto.tables;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

/**
 * Request body for POST /tables (MANAGER only).
 *
 * NestJS equivalent: CreateTableDto
 *   @IsInt() @IsPositive() tableNumber: number
 */
public class CreateTableRequest {

    @NotNull(message = "Table number is required")
    @Min(value = 1, message = "Table number must be positive")
    private Integer tableNumber;

    public Integer getTableNumber() { return tableNumber; }
    public void setTableNumber(Integer tableNumber) { this.tableNumber = tableNumber; }
}
