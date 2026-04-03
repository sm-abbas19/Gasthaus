import 'package:flutter/material.dart';

import '../../core/models/order.dart';
import '../../core/services/api_service.dart';

// OrdersProvider manages both the order list and the set of order IDs that the
// customer has already reviewed. Knowing review status upfront (at fetch time)
// lets the UI hide "Leave Review" immediately — no per-order API call needed.
class OrdersProvider extends ChangeNotifier {
  List<Order> _orders = [];
  String _selectedFilter = 'all';
  bool _isLoading = false;
  String? _error;

  // IDs of orders that already have a review from this customer.
  // Populated alongside fetchOrders() by calling GET /reviews/my.
  // Using a Set<String> for O(1) lookup in isReviewed().
  Set<String> _reviewedOrderIds = {};

  List<Order> get orders        => _orders;
  String get selectedFilter     => _selectedFilter;
  bool get isLoading            => _isLoading;
  String? get error             => _error;

  // Returns true if the given orderId already has a review from this customer.
  // Called per card in the orders list — O(1) Set lookup, not an API call.
  bool isReviewed(String orderId) =>
      _reviewedOrderIds.contains(_normalizeOrderId(orderId));

  List<Order> get filteredOrders {
    switch (_selectedFilter) {
      case 'active':
        return _orders.where((o) => o.isActive).toList();
      case 'completed':
        return _orders.where((o) => o.isCompleted).toList();
      case 'cancelled':
        return _orders.where((o) => o.isCancelled).toList();
      default:
        return List.unmodifiable(_orders);
    }
  }

  void setFilter(String filter) {
    if (_selectedFilter == filter) return;
    _selectedFilter = filter;
    notifyListeners();
  }

  Future<void> fetchOrders() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Fetch orders — this is the critical call; if it fails we show an error.
      final ordersResponse = await ApiService.instance.dio.get('/orders/my');

      // Parse orders
      final rawOrders = ordersResponse.data as List<dynamic>;
      _orders = rawOrders
          .map((json) => Order.fromJson(json as Map<String, dynamic>))
          .toList();
      _orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Fetch reviewed order IDs using a resilient strategy:
      // 1) Fast path: GET /reviews/my (bulk ids)
      // 2) Fallback: GET /reviews/order/:id for each completed order
      //
      // Why fallback exists:
      // If /reviews/my fails (temporary backend issue, older backend shape,
      // auth edge case), we still need to suppress "Leave Review" for orders that
      // were already reviewed. Without fallback, users see the button and hit a
      // duplicate-review error when submitting.
      _reviewedOrderIds = await _loadReviewedOrderIds(_orders);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Called after a review is successfully submitted so the UI updates
  // immediately without a full re-fetch.
  void markReviewed(String orderId) {
    _reviewedOrderIds = {..._reviewedOrderIds, _normalizeOrderId(orderId)};
    notifyListeners();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Reviewed-order detection helpers
  // ───────────────────────────────────────────────────────────────────────────

  // Normalizes IDs to avoid case-mismatch bugs across different backend
  // serializers (some UUID outputs are uppercase, some lowercase).
  String _normalizeOrderId(String id) => id.trim().toLowerCase();

  // Attempts to resolve reviewed order IDs with a bulk call first, then falls
  // back to per-order checks for completed orders only.
  Future<Set<String>> _loadReviewedOrderIds(List<Order> orders) async {
    final bulkResult = await _tryLoadReviewedOrderIdsBulk();
    if (bulkResult != null) {
      return bulkResult;
    }

    // Fallback checks only terminal orders because only those can show
    // "Leave Review" in the UI, keeping network usage bounded.
    final completedOrderIds = orders
        .where((order) => order.isCompleted)
        .map((order) => _normalizeOrderId(order.id))
        .toSet();

    if (completedOrderIds.isEmpty) {
      return <String>{};
    }

    final reviewedIds = <String>{};

    await Future.wait(completedOrderIds.map((orderId) async {
      try {
        final response = await ApiService.instance.dio.get('/reviews/order/$orderId');
        final data = response.data;

        // Expected shape: a List<Review>. Non-empty means this order was reviewed.
        if (data is List && data.isNotEmpty) {
          reviewedIds.add(orderId);
        }
      } catch (_) {
        // Ignore per-order failures so one bad response does not block the rest.
      }
    }));

    return reviewedIds;
  }

  // Returns null when bulk resolution fails, signaling that fallback should run.
  Future<Set<String>?> _tryLoadReviewedOrderIdsBulk() async {
    try {
      final response = await ApiService.instance.dio.get('/reviews/my');
      return _parseReviewedOrderIds(response.data);
    } catch (_) {
      return null;
    }
  }

  // Supports multiple payload shapes for forward/backward compatibility:
  // - ["uuid1", "uuid2"]
  // - [{"orderId": "uuid1"}, {"orderId": "uuid2"}]
  // - {"reviewedOrderIds": [...]} or {"orderIds": [...]} wrappers
  Set<String> _parseReviewedOrderIds(dynamic payload) {
    Iterable<dynamic> raw = const [];

    if (payload is List) {
      raw = payload;
    } else if (payload is Map<String, dynamic>) {
      final wrapped = payload['reviewedOrderIds'] ??
          payload['orderIds'] ??
          payload['data'];
      if (wrapped is List) {
        raw = wrapped;
      }
    }

    return raw
        .map((entry) {
          if (entry is Map<String, dynamic>) {
            final nested = entry['orderId'] ?? entry['id'];
            return nested?.toString() ?? '';
          }
          return entry.toString();
        })
        .map(_normalizeOrderId)
        .where((id) => id.isNotEmpty)
        .toSet();
  }
}
