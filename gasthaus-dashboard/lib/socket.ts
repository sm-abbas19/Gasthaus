/**
 * STOMP-over-SockJS client for the Spring Boot backend.
 *
 * Spring Boot uses STOMP (RFC 6455) over a SockJS transport instead of Socket.io.
 * SockJS provides a fallback stack (xhr-streaming, etc.) for environments that
 * block raw WebSocket.
 *
 * Connection endpoint: http://localhost:8080/api/ws  (context-path /api + /ws)
 * Server topics:
 *   /topic/order.new    — new order placed
 *   /topic/order.status — order status changed
 *   /topic/order.ready  — order ready for pickup
 */
import { Client } from '@stomp/stompjs'
import SockJS from 'sockjs-client'

const WS_URL = process.env.NEXT_PUBLIC_WS_URL ?? 'http://localhost:8080/api/ws'

export function createStompClient(): Client {
  return new Client({
    // SockJS factory — called by @stomp/stompjs when it needs a transport.
    webSocketFactory: () => new SockJS(WS_URL) as WebSocket,
    reconnectDelay: 5000,
  })
}

// Topic constants — avoids magic strings scattered across pages.
export const TOPICS = {
  ORDER_NEW: '/topic/order.new',
  ORDER_STATUS: '/topic/order.status',
  ORDER_READY: '/topic/order.ready',
} as const
