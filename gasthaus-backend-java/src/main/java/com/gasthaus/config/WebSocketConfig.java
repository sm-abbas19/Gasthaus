package com.gasthaus.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

/**
 * Configures STOMP-over-WebSocket message brokering.
 *
 * ─── Protocol difference: Socket.io (NestJS) vs STOMP (Spring) ───────────────
 *
 * NestJS uses Socket.io, which has its own binary protocol on top of WebSocket
 * and includes features like rooms, namespaces, and automatic reconnect.
 *
 * Spring Boot uses STOMP (Simple Text Oriented Messaging Protocol) over raw WebSocket.
 * STOMP is a simpler, standardized protocol — think of it as HTTP for messaging.
 *
 * IMPLICATION: The Next.js frontend (which uses socket.io-client) CANNOT connect
 * to this Spring WebSocket endpoint as-is. It would need to be updated to use
 * @stomp/stompjs + sockjs-client instead. This is a known trade-off when porting.
 *
 * NestJS event names → Spring STOMP topic mapping:
 *   'order:new'    → /topic/order.new    (: replaced by . — STOMP convention)
 *   'order:status' → /topic/order.status
 *   'order:ready'  → /topic/order.ready
 *
 * ─── Architecture ─────────────────────────────────────────────────────────────
 *
 * This config sets up a simple in-process message broker (no RabbitMQ/ActiveMQ needed).
 * For production, swap enableSimpleBroker() for enableStompBrokerRelay() with a real broker.
 *
 * @EnableWebSocketMessageBroker — activates the STOMP message broker infrastructure.
 * NestJS equivalent: WebSocketGateway decorator + socket.io server auto-setup.
 */
@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    /**
     * Registers the WebSocket endpoint clients connect to.
     *
     * NestJS equivalent: @WebSocketGateway({ cors: { origin: '*' } }) — Socket.io
     * auto-registers an endpoint at the root path.
     *
     * Here clients connect to ws://localhost:8080/api/ws (with context-path prefix).
     * .withSockJS() adds a SockJS fallback for browsers that don't support raw WebSocket.
     * SockJS is compatible with @stomp/stompjs's SockJS transport option.
     */
    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        registry.addEndpoint("/ws")
                .setAllowedOriginPatterns("*")
                .withSockJS();
    }

    /**
     * Configures the message broker routing rules.
     *
     * enableSimpleBroker("/topic"):
     *   Any message sent to a destination starting with /topic is handled by the
     *   in-memory broker and broadcast to all subscribed clients.
     *   NestJS equivalent: this.server.emit('event', data) → broadcasts to all.
     *
     * setApplicationDestinationPrefixes("/app"):
     *   Messages sent by clients to /app/... are routed to @MessageMapping methods
     *   (controller handlers). We don't use client-to-server messages in this phase,
     *   but the prefix is needed if we add them later.
     *   NestJS equivalent: @SubscribeMessage('event') on the gateway class.
     */
    @Override
    public void configureMessageBroker(MessageBrokerRegistry config) {
        config.enableSimpleBroker("/topic");
        config.setApplicationDestinationPrefixes("/app");
    }
}
