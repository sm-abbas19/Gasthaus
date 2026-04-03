package com.gasthaus.service;

import com.gasthaus.dto.ai.InsightsRequest;
import com.gasthaus.dto.ai.ReviewSummaryRequest;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Proxies AI requests to the FastAPI service at localhost:8000.
 *
 * NestJS equivalent: AiService in src/ai/ai.service.ts
 *
 * ─── NestJS HttpService  vs  Spring RestClient ───────────────────────────────
 *
 * NestJS AiService uses HttpService (Axios wrapper from @nestjs/axios).
 * Axios returns a Promise, but @nestjs/axios wraps it in an RxJS Observable.
 * firstValueFrom() converts Observable → Promise for async/await usage:
 *
 *   const { data } = await firstValueFrom(
 *     this.httpService.post(url, body)   ← Observable<AxiosResponse>
 *   );
 *   return data;  // ← the JSON response body
 *
 * Spring's RestClient is simpler — no Observable wrapper:
 *
 *   return restClient.post()
 *       .uri("/ai/recommend")
 *       .body(payload)
 *       .retrieve()
 *       .body(Object.class);  // ← the JSON response body directly
 *
 * Both are synchronous from the caller's perspective (blocking the thread).
 * NestJS runs on Node.js event loop so the thread isn't blocked, but the
 * coroutine equivalent is the same: wait for the HTTP response, return data.
 *
 * ─── Error handling ──────────────────────────────────────────────────────────
 *
 * NestJS:
 *   catch (error) {
 *     throw new HttpException(
 *       error.response?.data?.detail || 'AI service unavailable',
 *       error.response?.status || 503
 *     );
 *   }
 *
 * Spring RestClient throws RestClientResponseException on non-2xx responses.
 * We catch it and rethrow as ResponseStatusException with the FastAPI status code,
 * mirroring NestJS's pass-through of the upstream status.
 * A generic exception (network failure, DNS, etc.) maps to 503 Service Unavailable.
 */
@Service
public class AiService {

    private final RestClient fastApiClient;

    /**
     * @Qualifier("fastApiClient") — selects the specific RestClient bean by name,
     * since there could be multiple RestClient beans in the context.
     * NestJS equivalent: private httpService: HttpService injected via DI.
     */
    public AiService(@Qualifier("fastApiClient") RestClient fastApiClient) {
        this.fastApiClient = fastApiClient;
    }

    // ─── Recommend ────────────────────────────────────────────────

    /**
     * NestJS:
     *   async getRecommendation(userId, message, menuItems) {
     *     const { data } = await firstValueFrom(
     *       this.httpService.post(`${fastApiUrl}/ai/recommend`, { userId, message, menuItems })
     *     );
     *     return data;
     *   }
     *
     * The payload adds userId (from the auth token) to the message + menuItems from the DTO.
     * Map.of() creates an immutable Map — Jackson serializes it to JSON automatically.
     */
    public Object getRecommendation(UUID userId, String message, List<Object> menuItems) {
        Map<String, Object> payload = Map.of(
                "userId",    userId.toString(),
                "message",   message,
                "menuItems", menuItems
        );
        return proxyPost("/ai/recommend", payload);
    }

    // ─── Insights ─────────────────────────────────────────────────

    /**
     * NestJS:
     *   async getInsights(insightsData: any) {
     *     const { data } = await firstValueFrom(
     *       this.httpService.post(`${fastApiUrl}/ai/insights`, insightsData)
     *     );
     *     return data;
     *   }
     *
     * The whole InsightsRequest DTO is forwarded as the body.
     * Jackson serializes it to JSON (same fields FastAPI expects).
     */
    public Object getInsights(InsightsRequest dto) {
        return proxyPost("/ai/insights", dto);
    }

    // ─── Review Summary ───────────────────────────────────────────

    /**
     * NestJS:
     *   async getReviewSummary(menuItemName, reviews) {
     *     const { data } = await firstValueFrom(
     *       this.httpService.post(`${fastApiUrl}/ai/review-summary`, { menuItemName, reviews })
     *     );
     *     return data;
     *   }
     */
    public Object getReviewSummary(ReviewSummaryRequest dto) {
        return proxyPost("/ai/review-summary", dto);
    }

    // ─── Clear Session ────────────────────────────────────────────

    /**
     * NestJS:
     *   async clearSession(userId) {
     *     const { data } = await firstValueFrom(
     *       this.httpService.delete(`${fastApiUrl}/ai/session/${userId}`)
     *     );
     *     return data;
     *   }
     */
    public Object clearSession(UUID userId) {
        try {
            return fastApiClient.delete()
                    .uri("/ai/session/{userId}", userId)
                    .retrieve()
                    .body(Object.class);
        } catch (RestClientResponseException e) {
            throw new ResponseStatusException(
                    HttpStatus.valueOf(e.getStatusCode().value()),
                    extractErrorMessage(e));
        } catch (Exception e) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                    "AI service unavailable");
        }
    }

    // ─── Shared proxy helper ──────────────────────────────────────

    /**
     * Sends a POST to the FastAPI service and returns the response body.
     *
     * Centralising the try/catch here avoids repeating it in every method.
     * NestJS repeats the try/catch in each method — Spring's extraction is cleaner.
     *
     * retrieve() — tells RestClient to read and validate the response.
     *   If the FastAPI returns 4xx/5xx, RestClient throws RestClientResponseException.
     * body(Object.class) — deserializes the JSON response to a plain Java object
     *   (Map/List/String/Number depending on the JSON structure).
     *   We return Object because FastAPI's response shape varies per endpoint.
     */
    private Object proxyPost(String path, Object body) {
        try {
            return fastApiClient.post()
                    .uri(path)
                    .body(body)
                    .retrieve()
                    .body(Object.class);
        } catch (RestClientResponseException e) {
            // Pass through the FastAPI status code and error message.
            // NestJS: throw new HttpException(error.response?.data?.detail || '...', error.response?.status)
            throw new ResponseStatusException(
                    HttpStatus.valueOf(e.getStatusCode().value()),
                    extractErrorMessage(e));
        } catch (Exception e) {
            // Network failure, timeout, DNS — FastAPI is not reachable.
            // NestJS: || 503 fallback
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                    "AI service unavailable");
        }
    }

    /**
     * Extracts the error detail from FastAPI's error response body.
     *
     * FastAPI uses { "detail": "..." } for error messages.
     * NestJS: error.response?.data?.detail || 'AI service unavailable'
     *
     * RestClientResponseException.getResponseBodyAsString() gives the raw JSON.
     * We return it as-is — the ResponseStatusException message will include it.
     */
    private String extractErrorMessage(RestClientResponseException e) {
        String body = e.getResponseBodyAsString();
        return (body != null && !body.isBlank()) ? body : "AI service error";
    }
}
