package com.gasthaus.config;

import com.fasterxml.jackson.annotation.JsonTypeInfo;
import com.fasterxml.jackson.databind.DatabindContext;
import com.fasterxml.jackson.databind.JavaType;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.databind.cfg.MapperConfig;
import com.fasterxml.jackson.databind.jsontype.NamedType;
import com.fasterxml.jackson.databind.jsontype.PolymorphicTypeValidator;
import com.fasterxml.jackson.databind.jsontype.TypeIdResolver;
import com.fasterxml.jackson.databind.jsontype.impl.LaissezFaireSubTypeValidator;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.cache.RedisCacheConfiguration;
import org.springframework.data.redis.serializer.GenericJackson2JsonRedisSerializer;
import org.springframework.data.redis.serializer.RedisSerializationContext;
import org.springframework.data.redis.serializer.StringRedisSerializer;

import java.io.IOException;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Collection;

/**
 * Redis cache configuration.
 *
 * By default, Spring's RedisCacheManager uses JdkSerializationRedisSerializer,
 * which requires all cached objects to implement Serializable. Our JPA entities
 * don't, and we don't want to couple them to Java serialization.
 *
 * NestJS equivalent: cache-manager-redis-store serializes values as JSON strings
 * automatically — no configuration needed. Spring requires explicit setup to do
 * the same.
 *
 * GenericJackson2JsonRedisSerializer writes JSON with a type hint:
 *   ["com.gasthaus.entity.MenuCategory", { "id": "...", "name": "Pizzas", ... }]
 * The type hint lets Jackson deserialize back to the correct class without
 * requiring a fixed return type at config time.
 */
@Configuration
public class RedisConfig {

    /**
     * Custom TypeResolverBuilder that intercepts Hibernate collection types.
     *
     * Problem: activateDefaultTyping(NON_FINAL) writes the RUNTIME type of every
     * non-final value into Redis. @OneToMany fields are wrapped by Hibernate in
     * PersistentBag/PersistentList/PersistentSet at runtime. These types are written
     * as type IDs in Redis JSON. On deserialization outside a Hibernate session,
     * accessing those collections triggers LazyInitializationException.
     *
     * Root cause: Jackson resolves the type ID "org.hibernate.collection.spi.PersistentBag"
     * back to PersistentBag.class, then tries to create/populate a PersistentBag — which
     * requires a Hibernate session that no longer exists.
     *
     * Fix: Override the TypeIdResolver so that type IDs in the "org.hibernate.collection"
     * package are redirected to ArrayList during deserialization. The JSON array contents
     * are correct (fully loaded elements) — we just need a session-free collection class
     * to hold them.
     *
     * NestJS equivalent: Prisma returns plain JS objects/arrays with no proxy wrappers,
     * so cache-manager-redis-store never encounters this issue.
     */
    private static class HibernateAwareTypeResolverBuilder
            extends ObjectMapper.DefaultTypeResolverBuilder {

        HibernateAwareTypeResolverBuilder() {
            super(ObjectMapper.DefaultTyping.NON_FINAL, LaissezFaireSubTypeValidator.instance);
        }

        @Override
        protected TypeIdResolver idResolver(MapperConfig<?> config,
                                            JavaType baseType,
                                            PolymorphicTypeValidator subtypeValidator,
                                            Collection<NamedType> subtypes,
                                            boolean forSer,
                                            boolean forDeser) {
            TypeIdResolver delegate = super.idResolver(
                    config, baseType, subtypeValidator, subtypes, forSer, forDeser);

            // Wrap the resolver so that Hibernate collection class names map to ArrayList.
            // We only need this for deserialization, but wrapping for both is safe.
            return new TypeIdResolver() {
                @Override
                public void init(JavaType bt) { delegate.init(bt); }

                @Override
                public String idFromValue(Object value) {
                    return delegate.idFromValue(value);
                }

                @Override
                public String idFromValueAndType(Object value, Class<?> suggestedType) {
                    return delegate.idFromValueAndType(value, suggestedType);
                }

                @Override
                public String idFromBaseType() { return delegate.idFromBaseType(); }

                @Override
                public JavaType typeFromId(DatabindContext context, String id) throws IOException {
                    // Redirect any Hibernate collection type → ArrayList.
                    // The JSON array content is fully populated; we just need a plain
                    // Java collection to hold the deserialized elements.
                    if (id != null && id.startsWith("org.hibernate.collection")) {
                        return context.constructType(ArrayList.class);
                    }
                    return delegate.typeFromId(context, id);
                }

                @Override
                public String getDescForKnownTypeIds() { return delegate.getDescForKnownTypeIds(); }

                @Override
                public JsonTypeInfo.Id getMechanism() { return delegate.getMechanism(); }
            };
        }
    }

    @Bean
    public RedisCacheConfiguration redisCacheConfiguration() {

        // ObjectMapper configured for Redis:
        // - JavaTimeModule: handles LocalDateTime (createdAt, updatedAt on entities)
        // - WRITE_DATES_AS_TIMESTAMPS disabled: stores dates as ISO-8601 strings
        // - setDefaultTyping with HibernateAwareTypeResolverBuilder: embeds the Java
        //   class name so Jackson knows what to deserialize into on cache reads,
        //   but remaps Hibernate collection class names → ArrayList on deserialization.
        HibernateAwareTypeResolverBuilder typeResolver = new HibernateAwareTypeResolverBuilder();
        typeResolver.init(JsonTypeInfo.Id.CLASS, null);
        typeResolver.inclusion(JsonTypeInfo.As.PROPERTY);

        ObjectMapper mapper = new ObjectMapper()
                .registerModule(new JavaTimeModule())
                .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS)
                .setDefaultTyping(typeResolver);

        GenericJackson2JsonRedisSerializer jsonSerializer =
                new GenericJackson2JsonRedisSerializer(mapper);

        return RedisCacheConfiguration.defaultCacheConfig()
                // Keys stored as plain strings: "menu:categories"
                .serializeKeysWith(
                        RedisSerializationContext.SerializationPair
                                .fromSerializer(new StringRedisSerializer()))
                // Values stored as JSON — no Serializable needed on entities
                .serializeValuesWith(
                        RedisSerializationContext.SerializationPair
                                .fromSerializer(jsonSerializer))
                // NestJS cache-manager default TTL is typically set per-registration.
                // We use 10 minutes here; override per-cache via @Cacheable(cacheNames, ...)
                // or CacheManagerCustomizer if different TTLs are needed per cache.
                .entryTtl(Duration.ofMinutes(10))
                // Don't cache null values — avoids caching "not found" results
                .disableCachingNullValues();
    }
}
