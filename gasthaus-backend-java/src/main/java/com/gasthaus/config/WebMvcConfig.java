package com.gasthaus.config;

import com.gasthaus.security.LoginRateLimitInterceptor;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Configuration;
import org.springframework.lang.NonNull;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * MVC interceptor registration.
 *
 * NestJS equivalent: APP_GUARD / APP_INTERCEPTOR providers registered globally,
 * or @UseGuards / @UseInterceptors scoped to a specific controller or method.
 *
 * Spring's addInterceptors lets us apply an interceptor to specific URL patterns
 * without touching the controller class — clean separation of concerns.
 */
@Configuration
@RequiredArgsConstructor
public class WebMvcConfig implements WebMvcConfigurer {

    private final LoginRateLimitInterceptor loginRateLimitInterceptor;

    /**
     * Registers LoginRateLimitInterceptor only for POST /auth/login.
     *
     * addPathPatterns: equivalent to NestJS applying @Throttle only to the login method.
     * The context-path (/api) is stripped before interceptors see the path, so we match
     * /auth/login not /api/auth/login.
     */
    @Override
    public void addInterceptors(@NonNull InterceptorRegistry registry) {
        registry.addInterceptor(loginRateLimitInterceptor)
                .addPathPatterns("/auth/login");
    }
}
