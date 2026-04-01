import 'dart:async';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import 'auth_storage.dart';

// SocketService wraps the STOMP WebSocket connection to the Spring Boot backend.
//
// Why STOMP, not Socket.io?
//   Spring Boot's WebSocket support (spring-websocket) uses the STOMP protocol
//   over WebSocket. STOMP is a text-based messaging protocol that adds a
//   publish/subscribe layer on top of raw WebSocket frames.
//   Socket.io is a different protocol with its own handshake — it only works
//   with a Socket.io server, which Spring Boot doesn't run.
//   The `stomp_dart_client` package implements the STOMP client for Dart.
//
// Comparison to NestJS version:
//   NestJS used socket.io-client ↔ @nestjs/platform-socket.io on the server.
//   Spring Boot uses stomp_dart_client ↔ spring-websocket on the server.
//
// This service is used as a singleton (like ApiService) so the single
// connection is shared across all screens that need real-time updates.
class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  // Spring Boot WebSocket endpoint — configured in WebSocketConfig.java
  static const String _wsUrl = 'ws://10.0.2.2:8080/ws';

  StompClient? _client;
  bool _isConnected = false;

  // Active subscriptions keyed by their destination path.
  // Kept so we can re-subscribe after a reconnect.
  final Map<String, StompUnsubscribe> _subscriptions = {};

  // Reconnect attempt count — used to calculate exponential backoff delay.
  int _reconnectAttempts = 0;

  bool get isConnected => _isConnected;

  // connect() establishes the STOMP connection authenticated with the JWT.
  // Call this when the user logs in or when a screen that needs real-time
  // updates is opened.
  Future<void> connect() async {
    if (_isConnected) return; // already connected — no-op

    // Read the JWT from secure storage to include in STOMP connect headers.
    // Spring Boot's WebSocket security filter validates this token on the
    // CONNECT frame, the same way the HTTP filter validates Authorization headers.
    final token = await AuthStorage.instance.getToken();
    if (token == null) return; // not logged in — skip

    _client = StompClient(
      config: StompConfig.sockJS(
        // SockJS is a fallback transport layer Spring Boot uses by default.
        // It tries WebSocket first, then falls back to HTTP long-polling.
        // StompConfig.sockJS wraps the URL in the SockJS handshake format.
        url: _wsUrl,
        onConnect: _onConnect,
        onDisconnect: _onDisconnect,
        onStompError: _onError,
        onWebSocketError: _onError,
        // JWT sent in the STOMP CONNECT frame headers.
        // Spring Security reads this from the STOMP headers in the
        // ChannelInterceptor configured in the backend's WebSocketConfig.
        // In stomp_dart_client v3, this is stompConnectHeaders (not connectHeaders).
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        // Heartbeat keeps the connection alive through NAT/firewalls.
        // Flutter background mode may also pause WebSocket connections,
        // so heartbeats let the server detect a dead client quickly.
        heartbeatOutgoing: const Duration(seconds: 10),
        heartbeatIncoming: const Duration(seconds: 10),
      ),
    );

    _client!.activate();
  }

  void _onConnect(StompFrame frame) {
    _isConnected = true;
    _reconnectAttempts = 0; // reset backoff on successful connect
  }

  void _onDisconnect(StompFrame frame) {
    _isConnected = false;
    _scheduleReconnect();
  }

  void _onError(dynamic error) {
    _isConnected = false;
    _scheduleReconnect();
  }

  // Exponential backoff: wait 2^n seconds before reconnecting (max 30s).
  // This avoids hammering the server when it's temporarily unavailable,
  // e.g. during a restart or a brief network outage.
  void _scheduleReconnect() {
    final delay = Duration(
      seconds: (1 << _reconnectAttempts).clamp(1, 30),
    );
    _reconnectAttempts++;
    Timer(delay, connect);
  }

  // subscribeToOrder subscribes to status updates for a specific order.
  // Spring Boot publishes to `/topic/orders/{orderId}` whenever the kitchen
  // changes an order's status via PATCH /orders/:id/status.
  //
  // The callback receives the new status string (e.g. "READY").
  // Call this from OrderTrackingScreen.initState() to get live updates.
  void subscribeToOrder(String orderId, void Function(String status) onStatus) {
    final destination = '/topic/orders/$orderId';
    if (_subscriptions.containsKey(destination)) return; // already subscribed

    // subscribe() returns an unsubscribe function — we store it so we can
    // cancel the subscription when the screen is disposed.
    final unsubscribe = _client?.subscribe(
      destination: destination,
      callback: (frame) {
        // The body is a JSON string like: {"status":"READY","orderId":"..."}
        // We parse only the status field — that's all the UI needs.
        final body = frame.body ?? '';
        final statusMatch = RegExp(r'"status"\s*:\s*"([^"]+)"').firstMatch(body);
        if (statusMatch != null) {
          onStatus(statusMatch.group(1)!);
        }
      },
    );

    if (unsubscribe != null) {
      _subscriptions[destination] = unsubscribe;
    }
  }

  // subscribeToOrderReady subscribes to the user-specific queue that fires
  // when ANY of the user's orders become ready.
  // Spring Boot sends to `/user/queue/order-ready` using SimpMessagingTemplate's
  // convertAndSendToUser(), which routes to the authenticated user's session only.
  void subscribeToOrderReady(void Function(String orderId) onReady) {
    const destination = '/user/queue/order-ready';
    if (_subscriptions.containsKey(destination)) return;

    final unsubscribe = _client?.subscribe(
      destination: destination,
      callback: (frame) {
        final body = frame.body ?? '';
        final idMatch = RegExp(r'"orderId"\s*:\s*"([^"]+)"').firstMatch(body);
        if (idMatch != null) {
          onReady(idMatch.group(1)!);
        }
      },
    );

    if (unsubscribe != null) {
      _subscriptions[destination] = unsubscribe;
    }
  }

  // subscribeToMenu subscribes to menu change broadcasts.
  // The backend sends to /topic/menu after any create/update/delete/toggle.
  // The callback receives no meaningful data — it's just a signal to re-fetch.
  void subscribeToMenu(void Function() onMenuChanged) {
    const destination = '/topic/menu';
    if (_subscriptions.containsKey(destination)) return;

    final unsubscribe = _client?.subscribe(
      destination: destination,
      callback: (_) => onMenuChanged(),
    );

    if (unsubscribe != null) {
      _subscriptions[destination] = unsubscribe;
    }
  }

  void unsubscribeFromMenu() {
    _subscriptions['/topic/menu']?.call(unsubscribeHeaders: {});
    _subscriptions.remove('/topic/menu');
  }

  // unsubscribeFromOrder cancels a specific order subscription.
  // Call this in OrderTrackingScreen.dispose() to avoid memory leaks
  // and unnecessary messages after the screen is removed.
  void unsubscribeFromOrder(String orderId) {
    final destination = '/topic/orders/$orderId';
    _subscriptions[destination]?.call(unsubscribeHeaders: {});
    _subscriptions.remove(destination);
  }

  // disconnect cleanly shuts down the STOMP connection.
  // Call this on logout so the server-side session is released.
  void disconnect() {
    _client?.deactivate();
    _isConnected = false;
    _subscriptions.clear();
  }
}
