import 'package:flutter/material.dart';

import '../../core/services/api_service.dart';

// ChatMessage is a plain data class — no Flutter dependency needed.
// It's defined here (same file as the provider) because it's only ever
// used by AiChatProvider and AiWaiterScreen. No need for a separate model file.
class ChatMessage {
  // role distinguishes who sent the message:
  //   'user' = customer typed this
  //   'ai'   = backend AI responded with this
  final String role;
  final String text;
  final DateTime timestamp;

  const ChatMessage({
    required this.role,
    required this.text,
    required this.timestamp,
  });

  bool get isUser => role == 'user';
}

// AiChatProvider manages the full state of the Gustav AI chat.
// It uses the ChangeNotifier pattern: mutate state, then call notifyListeners()
// to let the UI rebuild. This is equivalent to React's useState + useReducer
// but simpler — there's one class that owns all related state.
class AiChatProvider extends ChangeNotifier {
  // _messages is the source of truth for the displayed conversation.
  // It's private so the UI can't append messages directly — it must
  // go through sendMessage(), which enforces the correct message flow.
  final List<ChatMessage> _messages = [];

  // isTyping shows the three-dot "AI is thinking" indicator in the UI.
  // It's true between the user sending a message and the AI responding.
  bool _isTyping = false;

  // Public getters expose immutable views so the UI can read but not mutate.
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isTyping => _isTyping;
  bool get isEmpty => _messages.isEmpty;

  // sendMessage sends a user message to the AI and appends the response.
  //
  // menuItems must be the current menu list so the AI has context about
  // what dishes are available to recommend. The backend's RecommendRequest
  // DTO has a @NotNull menuItems field — omitting it causes a 400 validation
  // error. We pass a list of plain maps (id, name, description, price,
  // categoryName) — only the fields the AI needs for recommendations.
  Future<void> sendMessage(
    String text, {
    List<Map<String, dynamic>> menuItems = const [],
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // 1. Append the user's message immediately so the UI responds instantly.
    //    This "optimistic update" pattern keeps the chat feeling responsive
    //    even before the network request completes.
    _messages.add(ChatMessage(
      role: 'user',
      text: trimmed,
      timestamp: DateTime.now(),
    ));
    _isTyping = true;
    notifyListeners(); // triggers a rebuild — user bubble appears, dots appear

    try {
      // POST /ai/recommend — CUSTOMER only.
      // The backend maintains conversation history per session using the JWT,
      // so we only send the latest message, not the full history.
      // Body: { message: String, menuItems: List }
      final response = await ApiService.instance.dio.post(
        '/ai/recommend',
        data: {'message': trimmed, 'menuItems': menuItems},
      );

      // FastAPI returns { "reply": String, "sessionId": String }.
      // The Spring Boot backend proxies this unchanged, so we read "reply".
      final data = response.data as Map<String, dynamic>;
      final aiText = data['reply']?.toString() ??
          data['response']?.toString() ??
          data['message']?.toString() ??
          'Sorry, I couldn\'t understand that. Could you try rephrasing?';

      // 2. Append the AI response once the network call succeeds.
      _messages.add(ChatMessage(
        role: 'ai',
        text: aiText,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      // On error, add a friendly error message as an AI bubble so the
      // chat doesn't look broken — the user sees something rather than silence.
      _messages.add(ChatMessage(
        role: 'ai',
        text: 'Sorry, I\'m having trouble connecting right now. Please try again.',
        timestamp: DateTime.now(),
      ));
    } finally {
      // 3. Always clear the typing indicator, whether the request succeeded or failed.
      _isTyping = false;
      notifyListeners(); // triggers rebuild — dots disappear, AI bubble appears
    }
  }

  Future<void> clearSession() async {
    // Clear the local list immediately for instant UI feedback.
    _messages.clear();
    _isTyping = false;
    notifyListeners();

    try {
      // DELETE /ai/session tells the backend to clear the server-side
      // conversation history, so the next message starts a fresh context.
      // We fire-and-forget: even if this fails, the local state is cleared.
      await ApiService.instance.dio.delete('/ai/session');
    } catch (_) {
      // Silently ignore errors — the local clear already happened.
      // The session will expire server-side eventually even without this call.
    }
  }
}
