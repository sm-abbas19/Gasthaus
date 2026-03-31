class OrderItem {
  final String id;
  final String menuItemId;
  final String menuItemName;
  final String? menuItemImage;
  final double price;
  final int quantity;

  const OrderItem({
    required this.id,
    required this.menuItemId,
    required this.menuItemName,
    this.menuItemImage,
    required this.price,
    required this.quantity,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id']?.toString() ?? '',
      menuItemId: json['menuItemId']?.toString() ?? '',
      menuItemName: json['menuItemName'] ?? '',
      menuItemImage: json['menuItemImage'],
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      quantity: json['quantity'] as int? ?? 1,
    );
  }

  double get total => price * quantity;
}

class Order {
  final String id;
  final String orderNumber;
  final String status;
  final int tableNumber;
  final List<OrderItem> items;
  final double totalAmount;
  final String? notes;
  final DateTime createdAt;

  const Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.tableNumber,
    required this.items,
    required this.totalAmount,
    this.notes,
    required this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final rawItems = json['orderItems'] ?? json['items'] ?? [];
    return Order(
      id: json['id']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? json['id']?.toString() ?? '',
      status: json['status'] ?? 'PENDING',
      tableNumber: json['tableNumber'] as int? ?? 0,
      items: (rawItems as List)
          .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
          .toList(),
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  // SERVED means the food has been delivered to the table — done from the
  // customer's perspective. Only in-kitchen statuses count as "active".
  bool get isActive =>
      ['PENDING', 'CONFIRMED', 'PREPARING', 'READY'].contains(status);

  // SERVED and COMPLETED both represent a finished order to the customer.
  bool get isCompleted => status == 'COMPLETED' || status == 'SERVED';

  bool get isCancelled => status == 'CANCELLED';
}
