import 'package:flutter/material.dart';

import '../../core/models/category.dart';
import '../../core/models/menu_item.dart';
import '../../core/services/api_service.dart';

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
