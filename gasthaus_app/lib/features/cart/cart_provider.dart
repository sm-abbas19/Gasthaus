import 'package:flutter/material.dart';
import '../../core/models/cart_item.dart';
import '../../core/models/menu_item.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  int? _tableNumber;
  String? _notes;

  List<CartItem> get items => List.unmodifiable(_items);
  int? get tableNumber => _tableNumber;
  String? get notes => _notes;

  int get itemCount => _items.fold(0, (sum, i) => sum + i.quantity);

  double get subtotal => _items.fold(0.0, (sum, i) => sum + i.total);

  double get tax => subtotal * 0.05;

  double get total => subtotal + tax;

  void setTableNumber(int table) {
    _tableNumber = table;
    notifyListeners();
  }

  void setNotes(String notes) {
    _notes = notes;
  }

  void addItem(MenuItem menuItem) {
    final index = _items.indexWhere((i) => i.menuItem.id == menuItem.id);
    if (index >= 0) {
      _items[index].quantity++;
    } else {
      _items.add(CartItem(menuItem: menuItem));
    }
    notifyListeners();
  }

  void removeItem(String menuItemId) {
    _items.removeWhere((i) => i.menuItem.id == menuItemId);
    notifyListeners();
  }

  void updateQuantity(String menuItemId, int quantity) {
    if (quantity <= 0) {
      removeItem(menuItemId);
      return;
    }
    final index = _items.indexWhere((i) => i.menuItem.id == menuItemId);
    if (index >= 0) {
      _items[index].quantity = quantity;
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    _notes = null;
    notifyListeners();
  }
}
