package com.gasthaus.controller;

import com.gasthaus.dto.ai.InsightsRequest;
import com.gasthaus.dto.ai.RecommendRequest;
import com.gasthaus.dto.ai.ReviewSummaryRequest;
import com.gasthaus.entity.User;
import com.gasthaus.service.AiService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Proxies AI requests to the FastAPI service.
 *
 * NestJS equivalent: AiController in src/ai/ai.controller.ts
 *
 * NestJS applies @UseGuards(JwtAuthGuard) at the class level — all routes need auth.
 * In Spring, SecurityConfig's .anyRequest().authenticated() covers all non-public routes.
 * SecurityConfig also explicitly .permitAll() for POST /ai/review-summary.
 *
 * Route auth summary:
 *   POST /ai/recommend      → CUSTOMER (adds userId from auth token to payload)
 *   POST /ai/insights       → MANAGER
 *   POST /ai/review-summary → public (no auth, already in SecurityConfig.permitAll)
 *   DELETE /ai/session      → CUSTOMER
 */
@RestController
@RequestMapping("/ai")
@RequiredArgsConstructor
public class AiController {

    private final AiService aiService;

    /**
     * POST /api/ai/recommend — CUSTOMER only
     *
     * NestJS:
     *   @Post('recommend') @Roles(Role.CUSTOMER) @UseGuards(RolesGuard)
     *   recommend(@Request() req, @Body() dto: RecommendDto) {
     *     return this.aiService.getRecommendation(req.user.id, dto.message, dto.menuItems);
     *   }
     *
     * userId is taken from the authenticated principal — never from the request body.
     * The client sends only { message, menuItems }; the service adds userId before
     * forwarding to FastAPI.
     */
    @PostMapping("/recommend")
    @PreAuthorize("hasRole('CUSTOMER')")
    public Object recommend(@AuthenticationPrincipal User user,
                            @Valid @RequestBody RecommendRequest dto) {
        return aiService.getRecommendation(user.getId(), dto.getMessage(), dto.getMenuItems());
    }

    /**
     * POST /api/ai/insights — MANAGER only
     *
     * NestJS:
     *   @Post('insights') @Roles(Role.MANAGER) @UseGuards(RolesGuard)
     *   insights(@Body() dto: InsightsDto) { return this.aiService.getInsights(dto); }
     *
     * The whole InsightsRequest is forwarded to FastAPI as the body.
     */
    @PostMapping("/insights")
    @PreAuthorize("hasRole('MANAGER')")
    public Object insights(@Valid @RequestBody InsightsRequest dto) {
        return aiService.getInsights(dto);
    }

    /**
     * POST /api/ai/review-summary — public (no auth required)
     *
     * NestJS: @Post('review-summary') reviewSummary(@Body() dto: ReviewSummaryDto)
     * No @UseGuards override — but NestJS class has @UseGuards(JwtAuthGuard) at class level.
     * In our SecurityConfig we explicitly .permitAll() this route, matching the CLAUDE.md spec.
     *
     * No @PreAuthorize here — SecurityConfig already handles it.
     */
    @PostMapping("/review-summary")
    public Object reviewSummary(@Valid @RequestBody ReviewSummaryRequest dto) {
        return aiService.getReviewSummary(dto);
    }

    /**
     * DELETE /api/ai/session — CUSTOMER only
     *
     * NestJS:
     *   @Delete('session') @Roles(Role.CUSTOMER) @UseGuards(RolesGuard)
     *   clearSession(@Request() req) { return this.aiService.clearSession(req.user.id); }
     *
     * Clears the customer's conversation history from the FastAPI service.
     * userId is from the auth token — not the request body.
     */
    @DeleteMapping("/session")
    @PreAuthorize("hasRole('CUSTOMER')")
    public Object clearSession(@AuthenticationPrincipal User user) {
        return aiService.clearSession(user.getId());
    }
}
