class Review {
  final String id;
  final String menuItemId;
  final String menuItemName;
  final String? orderId;
  final int rating;
  final String? comment;
  final String userName;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.menuItemId,
    required this.menuItemName,
    this.orderId,
    required this.rating,
    this.comment,
    required this.userName,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id']?.toString() ?? '',
      menuItemId: json['menuItemId']?.toString() ?? '',
      menuItemName: json['menuItemName'] ?? '',
      orderId: json['orderId']?.toString(),
      rating: json['rating'] as int? ?? 5,
      comment: json['comment'],
      userName: json['userName'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
