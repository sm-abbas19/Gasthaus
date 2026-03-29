package com.gasthaus.dto.ai;

import jakarta.validation.constraints.NotNull;

import java.util.List;

/**
 * Request body for POST /ai/insights (MANAGER only).
 *
 * NestJS equivalent: InsightsDto
 *   @IsInt() totalOrders: number
 *   @IsNumber() totalRevenue: number
 *   @IsArray() topItems: any[]
 *   @IsOptional() @IsString() busiestHour?: string
 *   @IsOptional() @IsArray() complaints?: string[]
 *
 * The whole DTO is forwarded as-is to FastAPI — same as NestJS's
 * this.httpService.post(`${fastApiUrl}/ai/insights`, insightsData)
 * where insightsData is the full dto object.
 */
public class InsightsRequest {

    @NotNull(message = "Total orders is required")
    private Integer totalOrders;

    @NotNull(message = "Total revenue is required")
    private Double totalRevenue;

    private List<Object> topItems;

    /** Optional — nullable if not provided */
    private String busiestHour;

    private List<String> complaints;

    public Integer getTotalOrders() { return totalOrders; }
    public void setTotalOrders(Integer totalOrders) { this.totalOrders = totalOrders; }

    public Double getTotalRevenue() { return totalRevenue; }
    public void setTotalRevenue(Double totalRevenue) { this.totalRevenue = totalRevenue; }

    public List<Object> getTopItems() { return topItems; }
    public void setTopItems(List<Object> topItems) { this.topItems = topItems; }

    public String getBusiestHour() { return busiestHour; }
    public void setBusiestHour(String busiestHour) { this.busiestHour = busiestHour; }

    public List<String> getComplaints() { return complaints; }
    public void setComplaints(List<String> complaints) { this.complaints = complaints; }
}
