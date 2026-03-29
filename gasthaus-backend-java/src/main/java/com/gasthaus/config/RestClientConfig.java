package com.gasthaus.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestClient;

/**
 * Configures a RestClient bean pre-wired to the FastAPI base URL.
 *
 * NestJS equivalent: HttpModule.register({ baseURL: fastApiUrl }) in AiModule,
 * which provides an HttpService (Axios wrapper) pre-configured with the base URL.
 *
 * RestClient (Spring Boot 3.2+) is the modern synchronous HTTP client:
 *   - Replaces the deprecated RestTemplate
 *   - Fluent builder API: restClient.post().uri(...).body(...).retrieve().body(...)
 *   - Does NOT require the reactive stack (unlike WebClient from spring-webflux)
 *
 * NestJS's HttpService uses Axios under the hood and returns RxJS Observables.
 * NestJS code wraps them with firstValueFrom() to make them async/await compatible.
 * RestClient is simpler — no Observable wrapper, direct synchronous return.
 *
 * The @Bean is a named "fastApiClient" so it doesn't conflict with any other
 * RestClient beans that might be added later.
 */
@Configuration
public class RestClientConfig {

    /**
     * Creates a RestClient pre-configured with the FastAPI base URL.
     * AiService injects this bean and calls it without needing the URL itself.
     *
     * NestJS equivalent:
     *   constructor(private httpService: HttpService, private config: ConfigService) {
     *     this.fastApiUrl = this.config.get('FASTAPI_URL') || 'http://localhost:8000';
     *   }
     */
    @Bean("fastApiClient")
    public RestClient fastApiClient(
            @Value("${app.fastapi.url}") String fastApiUrl,
            @Value("${app.fastapi.internal-key}") String internalKey) {
        return RestClient.builder()
                .baseUrl(fastApiUrl)
                .defaultHeader("Content-Type", "application/json")
                .defaultHeader("X-Internal-Key", internalKey)
                .build();
    }
}
