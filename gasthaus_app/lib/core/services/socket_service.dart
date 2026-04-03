import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import 'auth_storage.dart';

// SocketService wraps the STOMP WebSocket connection to the Spring Boot backend.
//
// Why STOMP, not Socket.io?
//   Spring Boot's WebSocket support uses STOMP (Simple Text Oriented Messaging
//   Protocol) over WebSocket. Socket.io is a different protocol that only works
//   with a Socket.io server. stomp_dart_client implements STOMP for Dart.
//
// Key design: the StompClient is created ONCE per login session.
//   stomp_dart_client has its OWN built-in reconnect mechanism, triggered by
//   onWebSocketDone. Our job is to:
//     1. Create and activate the client once.
//     2. Re-subscribe to all topics in onConnect (fires after every connect/reconnect).
//     3. Track connection state via onConnect / onWebSocketDone / onDisconnect.
//   We must NOT manually call activate() or create new clients on disconnect —
//   that races with the library's own reconnect and corrupts the internal handler.
//
// ─── Subscription architecture ────────────────────────────────────────────────
//
// There are TWO layers:
//
// Layer 1 — connectListeners (Map<String, VoidCallback>):
//   Callbacks that run whenever the STOMP connection becomes ready.
//   Used by long-lived providers (e.g. MenuProvider) that are created at app
//   startup — before login — and cannot call subscribeToX() immediately because
//   the connection doesn't exist yet.
//
//   When a connectListener fires, _isConnected is already true, so subscribeToX()
//   calls _doSubscribe() directly. This is the same code path as OrderTrackingScreen
//   calling subscribeToOrder() from initState() — which is why orders work instantly.
//
//   connectListeners also fire on every reconnect, which re-establishes subscriptions
//   after a connection drop without needing any extra code.
//
// Layer 2 — _callbacks (Map<destination, StompCallback>):
//   The actual STOMP message handlers, keyed by destination string.
//   Set inside subscribeToX() and iterated in _onConnect as a belt-and-suspenders
//   fallback. For subscriptions registered via connectListeners this map is still
//   populated (subscribeToX() always writes to it), so reconnects work correctly.
//
// Why does the order screen work without connectListeners?
//   OrderTrackingScreen.initState() runs when the screen is shown — always AFTER
//   the user has logged in and _isConnected is true. So subscribeToOrder() hits the
//   `if (_isConnected)` branch and calls _doSubscribe() immediately. No waiting.
//
//   MenuProvider is created at app startup (before login), so _isConnected is false
//   at construction time. Without connectListeners, the subscription only went into
//   _callbacks and relied on _onConnect iterating them. But stomp_dart_client's
//   subscribe() behaves differently when called *from inside* the onConnect callback
//   vs. called after onConnect has returned — the former can silently fail to register
//   with the server. connectListeners fire AFTER _onConnect sets _isConnected=true,
//   ensuring subscribeToX() takes the direct path every time.
class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  // Spring Boot WebSocket endpoint — raw WebSocket, NOT SockJS.
  //
  // Why raw WebSocket instead of SockJS?
  //   SockJS was designed for browser clients where raw WebSocket may be blocked
  //   by corporate firewalls or browser security policies. It negotiates the best
  //   transport available (WebSocket → XHR streaming → XHR long-polling).
  //
  //   Flutter is a native app with first-class WebSocket support and does NOT
  //   need SockJS. More importantly, SockJS's long-polling fallback has a critical
  //   flaw for persistent subscriptions: each HTTP long-poll delivers ONE message
  //   and then closes the connection. The client must re-open a new poll to receive
  //   the next message. If re-polling is delayed or races with a push, subsequent
  //   messages are silently dropped — exactly why menu pushes only worked once.
  //
  //   Raw WebSocket maintains a persistent bidirectional connection for the entire
  //   session. Every message is delivered reliably without re-polling.
  //
  // URL scheme: ws:// for raw WebSocket (not http:// — that was the SockJS scheme).
  // /ws-native is a dedicated endpoint in WebSocketConfig that omits .withSockJS().
  // /api prefix is required: server.servlet.context-path=/api applies to ALL paths.
  static const String _wsUrl = 'ws://10.0.2.2:8080/api/ws-native';

  StompClient? _client;
  bool _isConnected = false;

  // connectListeners: keyed by a caller-chosen name (e.g. 'menu').
  //   Fired by _onConnect after _isConnected is set to true.
  //   Each listener calls subscribeToX(), which then hits `if (_isConnected)` and
  //   goes straight to _doSubscribe() — the same code path as OrderTrackingScreen.
  //   Survives reconnects: _onConnect fires again → listeners fire again →
  //   subscriptions re-established on the new connection.
  final Map<String, VoidCallback> _connectListeners = {};

  // _callbacks: STOMP message handlers, keyed by destination.
  //   Populated by subscribeToX(). Used as belt-and-suspenders in _onConnect.
  // _subscriptions: active StompUnsubscribe handles for the current session.
  //   Cleared on every disconnect so _onConnect always re-registers cleanly.
  final Map<String, void Function(StompFrame)> _callbacks = {};
  final Map<String, StompUnsubscribe> _subscriptions = {};

  bool get isConnected => _isConnected;

  // ─── Connect listener API ────────────────────────────────────────────────────

  // addConnectListener stores a callback under the given key.
  // If already connected, the callback fires immediately (covers the case where
  // the provider is created after login, e.g. on a hot-reload).
  // The key is used to remove the listener later (see removeConnectListener).
  void addConnectListener(String key, VoidCallback listener) {
    _connectListeners[key] = listener;
    // Fire immediately if the connection is already up.
    // This mirrors initState() on a screen opened after login — no waiting.
    if (_isConnected) {
      debugPrint('[STOMP] addConnectListener "$key": already connected, firing immediately.');
      listener();
    }
  }

  // removeConnectListener is called in dispose() to prevent callbacks from
  // running on a provider that has been garbage-collected.
  void removeConnectListener(String key) {
    _connectListeners.remove(key);
  }

  // ─── Connection lifecycle ────────────────────────────────────────────────────

  // connect() creates the StompClient once and activates it.
  // The library's built-in reconnectDelay handles subsequent reconnects —
  // we never call activate() again after the initial call.
  Future<void> connect() async {
    if (_client != null) return; // already created — library manages lifecycle

    final token = await AuthStorage.instance.getToken();
    if (token == null) return;

    _client = StompClient(
      // StompConfig() (not StompConfig.sockJS()) connects over raw WebSocket.
      // The URL uses ws:// because raw WebSocket doesn't need an HTTP handshake.
      // StompConfig.sockJS() was the previous config — it required http:// and went
      // through SockJS negotiation, which caused the "only first push works" bug.
      config: StompConfig(
        url: _wsUrl,
        // reconnectDelay: library auto-reconnects after this delay when the
        // WebSocket drops. Default in stomp_dart_client is 5s. We use 3s for
        // faster recovery. This is the ONLY reconnect mechanism — we do not
        // manually call activate() to avoid racing with the library's own handler.
        reconnectDelay: const Duration(seconds: 3),
        onConnect: _onConnect,
        onDisconnect: _onDisconnect,
        onWebSocketDone: _onWebSocketDone,
        onWebSocketError: _onWebSocketError,
        onStompError: _onStompError,
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        // Heartbeats: client sends every 10s so the server knows we're alive.
        // Incoming set to zero — we don't ask the server for heartbeats.
        heartbeatOutgoing: const Duration(seconds: 10),
        heartbeatIncoming: Duration.zero,
      ),
    );

    _client!.activate();
  }

  void _onConnect(StompFrame frame) {
    _isConnected = true;
    debugPrint('[STOMP] *** CONNECTED ***');

    // Clear stale subscription handles — they belong to the previous connection.
    _subscriptions.clear();

    // ── Step 1: Fire connectListeners ───────────────────────────────────────
    // Each listener calls subscribeToX() with _isConnected=true, so _doSubscribe()
    // is called immediately — the same path as OrderTrackingScreen.initState().
    // This is the primary subscription mechanism for long-lived providers.
    debugPrint('[STOMP] Firing ${_connectListeners.length} connectListener(s): ${_connectListeners.keys.toList()}');
    for (final entry in _connectListeners.entries) {
      debugPrint('[STOMP] → connectListener "${entry.key}"');
      entry.value();
    }

    // ── Step 2: Belt-and-suspenders — iterate _callbacks ────────────────────
    // Covers subscriptions not managed by connectListeners (e.g. subscribeToOrder
    // called from initState when _isConnected was already true, or any subscription
    // that was set up without a connectListener). After Step 1 populated
    // _subscriptions for the listener-managed topics, this only subscribes topics
    // not yet in _subscriptions.
    debugPrint('[STOMP] _callbacks fallback: ${_callbacks.length} callback(s) — ${_callbacks.keys.toList()}');
    for (final entry in _callbacks.entries) {
      _doSubscribe(entry.key, entry.value);
    }
  }

  // Called when the WebSocket transport closes (network drop, emulator sleep, etc.).
  // The library's own onWebSocketDone wrapper schedules reconnect automatically.
  // Our only job: update connection state and clear stale subscription handles.
  void _onWebSocketDone() {
    debugPrint('[STOMP] WebSocket closed — waiting for library reconnect.');
    _isConnected = false;
    _subscriptions.clear();
  }

  // Called when a clean STOMP DISCONNECT frame is received (server-initiated).
  // Less common than _onWebSocketDone but needs the same state reset.
  void _onDisconnect(StompFrame frame) {
    debugPrint('[STOMP] DISCONNECT frame received.');
    _isConnected = false;
    _subscriptions.clear();
  }

  void _onWebSocketError(dynamic error) {
    // State reset only — library schedules reconnect via onWebSocketDone.
    debugPrint('[STOMP] WebSocket error: $error');
    _isConnected = false;
    _subscriptions.clear();
  }

  void _onStompError(StompFrame frame) {
    debugPrint('[STOMP] STOMP error frame: ${frame.body}');
    _isConnected = false;
    _subscriptions.clear();
  }

  // Calls _client.subscribe() and stores the unsubscribe handle.
  // Only called when _isConnected is true (either from subscribeToX() directly,
  // or from _onConnect after connectListeners have been fired).
  void _doSubscribe(String destination, void Function(StompFrame) callback) {
    if (_subscriptions.containsKey(destination)) {
      debugPrint('[STOMP] _doSubscribe: already subscribed to $destination, skipping.');
      return;
    }
    try {
      final unsub = _client!.subscribe(
        destination: destination,
        callback: callback,
      );
      _subscriptions[destination] = unsub;
      debugPrint('[STOMP] _doSubscribe: SUBSCRIBED to $destination. '
          'Active: ${_subscriptions.keys.toList()}');
    } catch (e) {
      debugPrint('[STOMP] _doSubscribe ERROR for $destination: $e');
    }
  }

  // ─── Public subscription API ──────────────────────────────────────────────

  // subscribeToMenu listens for menu change broadcasts.
  // Backend sends to /topic/menu after any create/update/delete/toggle.
  // Callback receives no meaningful payload — it is a "reload" signal only.
  //
  // IMPORTANT: call this from a connectListener, NOT directly from a constructor
  // that runs before login. That ensures _isConnected=true when this method runs,
  // so _doSubscribe() is called immediately (same path as OrderTrackingScreen).
  void subscribeToMenu(void Function() onMenuChanged) {
    const destination = '/topic/menu';
    debugPrint('[STOMP] subscribeToMenu called. isConnected=$_isConnected');
    _callbacks[destination] = (frame) {
      final ts = DateTime.now().millisecondsSinceEpoch;
      debugPrint('[STOMP] *** PUSH RECEIVED *** on /topic/menu at $ts ms. '
          'Frame body: "${frame.body}".');
      onMenuChanged();
    };
    if (_isConnected) {
      _doSubscribe(destination, _callbacks[destination]!);
    }
  }

  // subscribeToOrder listens for status updates on a specific order.
  // Backend publishes to /topic/orders/{orderId} on every status change.
  void subscribeToOrder(String orderId, void Function(String status) onStatus) {
    final destination = '/topic/orders/$orderId';
    _callbacks[destination] = (frame) {
      final body = frame.body ?? '';
      final match = RegExp(r'"status"\s*:\s*"([^"]+)"').firstMatch(body);
      if (match != null) onStatus(match.group(1)!);
    };
    if (_isConnected) _doSubscribe(destination, _callbacks[destination]!);
  }

  // subscribeToOrderReady listens on the user-specific queue for order-ready events.
  // Backend uses convertAndSendToUser() so only the authenticated user receives it.
  void subscribeToOrderReady(void Function(String orderId) onReady) {
    const destination = '/user/queue/order-ready';
    _callbacks[destination] = (frame) {
      final body = frame.body ?? '';
      final match = RegExp(r'"orderId"\s*:\s*"([^"]+)"').firstMatch(body);
      if (match != null) onReady(match.group(1)!);
    };
    if (_isConnected) _doSubscribe(destination, _callbacks[destination]!);
  }

  void unsubscribeFromMenu() {
    _subscriptions['/topic/menu']?.call(unsubscribeHeaders: {});
    _subscriptions.remove('/topic/menu');
    _callbacks.remove('/topic/menu');
  }

  void unsubscribeFromOrder(String orderId) {
    final destination = '/topic/orders/$orderId';
    _subscriptions[destination]?.call(unsubscribeHeaders: {});
    _subscriptions.remove(destination);
    _callbacks.remove(destination);
  }

  // disconnect is called on logout. Deactivating stops the library's reconnect
  // timer and closes the WebSocket. _client is nulled so the next login's
  // connect() creates a fresh client with the new user's JWT.
  void disconnect() {
    _client?.deactivate();
    _client = null;
    _isConnected = false;
    _subscriptions.clear();
    _callbacks.clear();
    _connectListeners.clear();
  }
}
