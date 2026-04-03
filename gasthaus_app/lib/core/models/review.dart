// Review model — represents an order-level review left by a customer.
// A review covers the whole order experience (not an individual menu item).
// The backend serialises orderId as a top-level field so we can display a
// consistent order reference string without loading the full Order object.
class Review {
  final String id;
  final String? orderId;    // UUID of the order this review belongs to
  final int rating;         // 1–5 stars
  final String? comment;   // optional written comment
  final String? userName;  // customer display name
  final DateTime createdAt;

  const Review({
    required this.id,
    this.orderId,
    required this.rating,
    this.comment,
    this.userName,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id']?.toString() ?? '',
      // orderId is now a @JsonProperty on the Review entity — always present
      // for new reviews; may be null for very old legacy data.
      orderId: json['orderId']?.toString(),
      rating: json['rating'] as int? ?? 5,
      comment: json['comment'],
      // customer name may come nested as customer.name or flat as userName
      userName: (json['customer'] as Map<String, dynamic>?)?['name'] as String?
          ?? json['userName'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  // Convenience: display the first 8 chars of the order UUID as a reference ID.
  // e.g. orderId "550e8400-e29b-41d4-a716-..." → "#550E8400"
  String get displayOrderId {
    if (orderId == null) return '—';
    return '#${orderId!.replaceAll('-', '').substring(0, 8).toUpperCase()}';
  }
}
