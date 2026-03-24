package com.gasthaus;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Application entry point — equivalent to NestJS's main.ts + bootstrap().
 *
 * @SpringBootApplication is a meta-annotation that combines three things:
 *   1. @Configuration      — this class can define @Bean methods
 *   2. @EnableAutoConfiguration — Spring Boot scans classpath and auto-configures
 *                                 (e.g., sees PostgreSQL driver → creates DataSource,
 *                                  sees spring-boot-starter-web → starts Tomcat)
 *   3. @ComponentScan      — scans this package and all sub-packages for
 *                            @Service, @Repository, @Controller, @Component etc.
 *
 * In NestJS terms: @SpringBootApplication = AppModule + NestFactory.create() combined.
 */
@SpringBootApplication
public class GasthausApplication {

    public static void main(String[] args) {
        // SpringApplication.run() = NestFactory.create(AppModule).then(app.listen())
        // It starts the IoC container, auto-configures everything, and boots Tomcat.
        SpringApplication.run(GasthausApplication.class, args);
    }
}
