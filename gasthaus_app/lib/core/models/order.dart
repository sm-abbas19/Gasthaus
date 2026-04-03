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
    // Spring Boot serializes OrderItem with a nested `menuItem` object
    // (because the entity has a @ManyToOne MenuItem field) and stores the
    // price snapshot as `unitPrice` (the entity field name).
    //
    // NestJS/Prisma flattened these into top-level `menuItemName`, `menuItemImage`,
    // and `price` keys. We try both shapes so the model works against either backend.
    final menuItem = json['menuItem'] as Map<String, dynamic>?;
    return OrderItem(
      id: json['id']?.toString() ?? '',
      menuItemId: menuItem?['id']?.toString() ?? json['menuItemId']?.toString() ?? '',
      menuItemName: menuItem?['name'] as String? ?? json['menuItemName'] as String? ?? '',
      menuItemImage: menuItem?['imageUrl'] as String? ?? json['menuItemImage'] as String?,
      // Spring Boot: `unitPrice` — NestJS: `price`
      price: (json['unitPrice'] as num?)?.toDouble() ?? (json['price'] as num?)?.toDouble() ?? 0.0,
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
      // Spring Boot: table number is nested under `table.tableNumber`
      // NestJS: flat `tableNumber` field at the top level
      tableNumber: json['tableNumber'] as int?
          ?? (json['table'] as Map<String, dynamic>?)?['tableNumber'] as int?
          ?? 0,
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

  // SERVED means food is at the table but payment is still pending —
  // still active from the customer's perspective.
  // Only PAID (or legacy COMPLETED) is truly done.
  bool get isActive =>
      ['PENDING', 'CONFIRMED', 'PREPARING', 'READY', 'SERVED'].contains(status);

  // PAID is the new terminal state. COMPLETED kept for legacy order compatibility.
  bool get isCompleted => status == 'PAID' || status == 'COMPLETED';

  bool get isCancelled => status == 'CANCELLED';
}
