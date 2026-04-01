import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/category.dart';
import '../../core/models/menu_item.dart';
import '../../core/services/api_service.dart';
import '../../core/services/socket_service.dart';

// MenuProvider manages all state for the menu screen.
//
// It uses the Provider pattern (ChangeNotifier) — a simple, Flutter-idiomatic
// way to share state across widgets without needing a full state management
// library. Think of ChangeNotifier as an observable object: when you call
// notifyListeners(), every widget that called context.watch<MenuProvider>()
// will rebuild with the latest data.
class MenuProvider extends ChangeNotifier {
  List<Category> _categories = [];

  // null means "All" — no category filter is active.
  // Using null instead of a special sentinel string is more explicit.
  String? _selectedCategoryId;

  String _searchQuery = '';
  bool _isLoading = false;
  String? _error;

  // Timer drives the 60-second polling fallback.
  // It fires loadMenu() periodically in case a WebSocket event was missed
  // (e.g. the app was backgrounded, or the connection dropped briefly).
  Timer? _pollTimer;

  // Public read-only getters. The underscore (_) prefix on the fields means
  // they're private — callers can only read via these getters, not mutate.
  List<Category> get categories => _categories;
  String? get selectedCategoryId => _selectedCategoryId;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Calling loadMenu() from the constructor kicks off the API fetch as soon
  // as the provider is created. This is a common Flutter pattern — the
  // constructor doesn't need to be async; the async work happens inside
  // the method that returns a Future.
  MenuProvider() {
    loadMenu();
    _subscribeToMenuUpdates();
    _startPolling();
  }

  // Subscribe to /topic/menu WebSocket events.
  // The backend broadcasts to this topic after any menu mutation (add/edit/
  // delete/toggle). We simply call loadMenu() on receipt — no need to parse
  // the payload since it's just a "something changed" signal.
  void _subscribeToMenuUpdates() {
    SocketService.instance.subscribeToMenu(() {
      // Reload silently — don't show the loading spinner for background refreshes
      // so the existing menu stays visible while the new data loads.
      _silentReload();
    });
  }

  // Start a 60-second polling timer as a fallback for missed WebSocket events.
  // This covers cases where:
  //   - The WebSocket wasn't connected when a menu change happened
  //   - The app was backgrounded (Flutter may pause timers/sockets)
  //   - The STOMP frame was lost due to a transient network issue
  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _silentReload();
    });
  }

  // Reload the menu without showing the loading skeleton.
  // Used for background refreshes (WebSocket push or polling) so the user
  // doesn't see the shimmer flash on data they already have on screen.
  Future<void> _silentReload() async {
    try {
      final response = await ApiService.instance.dio.get('/menu/categories');
      final data = response.data as List;
      _categories = data
          .map((c) => Category.fromJson(c as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (_) {
      // Silently ignore errors on background refreshes — the user already
      // has menu data on screen. Errors during manual loadMenu() still show.
    }
  }

  // dispose() is called when the provider is removed from the widget tree.
  // We must cancel the timer and WebSocket subscription to avoid memory leaks.
  // In Flutter, any resource that lives outside the widget tree (timers,
  // streams, subscriptions) must be cleaned up in dispose().
  @override
  void dispose() {
    _pollTimer?.cancel();
    SocketService.instance.unsubscribeFromMenu();
    super.dispose();
  }

  Future<void> loadMenu() async {
    _isLoading = true;
    _error = null;
    // Notify immediately so the UI shows a loading spinner right away.
    notifyListeners();

    try {
      // GET /menu/categories returns a JSON array of categories, each
      // containing a `menuItems` array. The Category.fromJson handles this.
      final response = await ApiService.instance.dio.get('/menu/categories');
      final data = response.data as List;
      _categories = data
          .map((c) => Category.fromJson(c as Map<String, dynamic>))
          .toList();
    } on Exception catch (e) {
      _error = e is ApiException ? e.message : 'Failed to load menu.';
    } finally {
      _isLoading = false;
      // Always notify at the end, even on error, so the UI stops showing
      // the spinner and can show the error state instead.
      notifyListeners();
    }
  }

  // Called when the user taps a category chip.
  // Passing null resets to "All".
  void selectCategory(String? categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  // Called on every keystroke in the search bar.
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // All menu items across every category — used to pass full menu context to
  // the AI endpoint, which needs the complete list regardless of active filters.
  List<MenuItem> get allItems => _categories.expand((c) => c.items).toList();

  // A computed getter — not stored state, just derived from existing state.
  // In Dart, getters are accessed like properties: provider.filteredItems
  // This is equivalent to a computed property in Swift or a @computed in MobX.
  List<MenuItem> get filteredItems {
    // Start with all items or just the selected category's items.
    List<MenuItem> items;
    if (_selectedCategoryId == null) {
      // expand() is Dart's flatMap — it flattens a list of lists into one list.
      items = _categories.expand((c) => c.items).toList();
    } else {
      items = _categories
          .where((c) => c.id == _selectedCategoryId)
          .expand((c) => c.items)
          .toList();
    }

    // Apply search filter if the user has typed something.
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items.where((i) => i.name.toLowerCase().contains(q)).toList();
    }

    return items;
  }
}
