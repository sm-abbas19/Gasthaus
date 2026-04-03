import 'package:flutter/material.dart';

import '../../core/models/order.dart';
import '../../core/services/api_service.dart';

// OrdersProvider manages the "My Orders" screen state.
// It follows the same ChangeNotifier pattern as other providers in this app:
// fetch data, update state, call notifyListeners() so the UI rebuilds.
// Unlike MenuProvider (which loads once), orders change frequently —
// the screen calls fetchOrders() on every visit via initState.
class OrdersProvider extends ChangeNotifier {
  List<Order> _orders = [];

  // selectedFilter drives which filter chip is active and which orders are shown.
  // 'all' is the default — no filtering applied.
  String _selectedFilter = 'all';

  bool _isLoading = false;
  String? _error;

  // Public getters — the UI reads these, never writes to the private fields directly.
  List<Order> get orders => _orders;
  String get selectedFilter => _selectedFilter;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // filteredOrders is a computed getter — it derives a value from existing state
  // rather than storing a separate list. This avoids the risk of the two lists
  // going out of sync. Flutter's build() method calls this on every rebuild,
  // which is fine because list filtering is cheap.
  List<Order> get filteredOrders {
    switch (_selectedFilter) {
      case 'active':
        // isActive covers PENDING, CONFIRMED, PREPARING, READY, SERVED
        return _orders.where((o) => o.isActive).toList();
      case 'completed':
        return _orders.where((o) => o.isCompleted).toList();
      case 'cancelled':
        return _orders.where((o) => o.isCancelled).toList();
      default:
        return List.unmodifiable(_orders); // 'all' — no filter
    }
  }

  // setFilter is called when the user taps a filter chip.
  // notifyListeners() triggers a rebuild so filteredOrders is re-evaluated.
  void setFilter(String filter) {
    if (_selectedFilter == filter) return; // no-op if already selected
    _selectedFilter = filter;
    notifyListeners();
  }

  Future<void> fetchOrders() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // GET /orders/my returns orders for the currently authenticated customer.
      // The JWT in the Authorization header identifies the user server-side —
      // no userId param needed.
      final response = await ApiService.instance.dio.get('/orders/my');

      // The backend returns a JSON array: [ { id, status, items, ... }, ... ]
      final rawList = response.data as List<dynamic>;
      _orders = rawList
          .map((json) => Order.fromJson(json as Map<String, dynamic>))
          .toList();

      // Sort newest first so the most recent order appears at the top.
      // DateTime comparison: a.isAfter(b) means a is more recent.
      _orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
