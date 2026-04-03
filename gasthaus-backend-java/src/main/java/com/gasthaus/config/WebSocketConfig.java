package com.gasthaus.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.scheduling.TaskScheduler;
import org.springframework.scheduling.concurrent.ThreadPoolTaskScheduler;
import org.springframework.context.annotation.Bean;
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
    @SuppressWarnings("NullableProblems")
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        // SockJS endpoint — used by the Next.js browser dashboard.
        // SockJS performs an HTTP negotiation handshake before upgrading to WebSocket,
        // which works around browser restrictions on raw WebSocket in some environments.
        registry.addEndpoint("/ws")
                .setAllowedOriginPatterns("*")
                .withSockJS();

        // Raw WebSocket endpoint — used by the Flutter mobile app.
        // Native Flutter has first-class WebSocket support and does NOT need SockJS.
        // SockJS on a native client can fall back to HTTP long-polling, which only
        // delivers one message per poll cycle and misses subsequent pushes.
        // Raw WebSocket maintains a persistent bidirectional connection that delivers
        // every message reliably — this is the correct transport for Flutter.
        registry.addEndpoint("/ws-native")
                .setAllowedOriginPatterns("*");
    }

    /**
     * Configures the message broker routing rules.
     *
     * enableSimpleBroker("/topic"):
     *   Any message sent to a destination starting with /topic is handled by the
     *   in-memory broker and broadcast to all subscribed clients.
     *   NestJS equivalent: this.server.emit('event', data) → broadcasts to all.
     *
     * setTaskScheduler() — required for the simple broker to send STOMP heartbeat
     *   frames to connected clients. Without a TaskScheduler, the broker cannot
     *   schedule the periodic heartbeat task, so it never sends heartbeats.
     *   STOMP clients that request incoming heartbeats (heartbeatIncoming > 0)
     *   will declare the connection dead when no heartbeat arrives, causing
     *   constant reconnect cycles and missed push notifications.
     *   NestJS/Socket.io handles this automatically via its ping/pong mechanism.
     *
     * setApplicationDestinationPrefixes("/app"):
     *   Messages sent by clients to /app/... are routed to @MessageMapping methods.
     *   NestJS equivalent: @SubscribeMessage('event') on the gateway class.
     */
    @Override
    @SuppressWarnings("NullableProblems")
    public void configureMessageBroker(MessageBrokerRegistry config) {
        config.enableSimpleBroker("/topic", "/queue")
              .setHeartbeatValue(new long[]{10000, 10000})
              .setTaskScheduler(brokerTaskScheduler());
        config.setApplicationDestinationPrefixes("/app");
    }

    /**
     * Dedicated scheduler for the STOMP message broker's heartbeat task.
     *
     * NestJS equivalent: none needed — Socket.io handles ping/pong internally.
     *
     * Why a separate scheduler?
     *   Spring's simple broker needs a scheduled thread to send heartbeat frames
     *   at a fixed interval. Without one, setHeartbeatValue() is ignored and no
     *   heartbeats are ever sent. A pool size of 1 is enough — heartbeats are
     *   lightweight and infrequent (one frame per client per 10 seconds).
     */
    @Bean
    @SuppressWarnings("NullableProblems")
    public TaskScheduler brokerTaskScheduler() {
        ThreadPoolTaskScheduler scheduler = new ThreadPoolTaskScheduler();
        scheduler.setPoolSize(1);
        scheduler.setThreadNamePrefix("ws-heartbeat-");
        scheduler.initialize();
        return scheduler;
    }
}
