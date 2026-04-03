package com.gasthaus.websocket;

import com.gasthaus.entity.Order;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Component;

/**
 * Publishes real-time order events to connected WebSocket clients.
 *
 * NestJS equivalent: OrdersGateway in src/orders/orders.gateway.ts
 *
 * NestJS used socket.io's server.emit() to broadcast to all connected clients.
 * Spring uses SimpMessagingTemplate.convertAndSend() to send to a STOMP topic,
 * which the in-process broker then fans out to all subscribers of that topic.
 *
 * SimpMessagingTemplate — "Simple Messaging Template":
 *   The Spring equivalent of socket.io's Server object.
 *   convertAndSend(destination, payload) serializes payload to JSON (via Jackson)
 *   and delivers it to all clients subscribed to that STOMP destination.
 *
 * NestJS event → STOMP destination mapping:
 *   this.server.emit('order:new', order)    → /topic/order.new
 *   this.server.emit('order:status', order) → /topic/order.status
 *   this.server.emit('order:ready', order)  → /topic/order.ready
 *
 * Frontend update needed:
 *   Replace socket.io-client with @stomp/stompjs + sockjs-client.
 *   Instead of: socket.on('order:new', handler)
 *   Use:        stompClient.subscribe('/topic/order.new', handler)
 */
@Component
@RequiredArgsConstructor
public class OrdersGateway {

    /**
     * Spring's messaging abstraction — injected automatically because we
     * annotated WebSocketConfig with @EnableWebSocketMessageBroker.
     * NestJS equivalent: @WebSocketServer() server: Server
     */
    private final SimpMessagingTemplate messaging;

    /**
     * NestJS: this.server.emit('order:new', order)
     * Broadcasts a new order to all staff dashboard subscribers.
     */
    public void emitNewOrder(Order order) {
        messaging.convertAndSend("/topic/order.new", order);
    }

    /**
     * NestJS: this.server.emit('order:status', order)
     * Broadcasts a status change — all clients (staff + customer) listen.
     *
     * Two destinations are sent:
     * 1. /topic/order.status — generic topic for the staff dashboard (subscribes to all orders)
     * 2. /topic/orders/{orderId} — per-order topic for the Flutter customer app.
     *    The Flutter OrderTrackingScreen subscribes to this specific destination so it only
     *    receives updates for the order it is currently showing.
     */
    @SuppressWarnings("NullableProblems")
    public void emitOrderStatusUpdate(Order order) {
        messaging.convertAndSend("/topic/order.status", order);
        messaging.convertAndSend("/topic/orders/" + order.getId(), order);
    }

    /**
     * NestJS: this.server.emit('order:ready', order)
     * Broadcasts order-ready notification — primarily for the customer.
     */
    public void emitOrderReady(Order order) {
        messaging.convertAndSend("/topic/order.ready", order);
    }
}
