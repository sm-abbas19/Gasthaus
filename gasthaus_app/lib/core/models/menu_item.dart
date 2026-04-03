class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final bool available;
  final String categoryId;
  final String categoryName;
  final double? averageRating;
  final int? reviewCount;

  const MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
    required this.available,
    required this.categoryId,
    required this.categoryName,
    this.averageRating,
    this.reviewCount,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['imageUrl'],
      // Backend field is `isAvailable` (Java Boolean with Lombok @Getter →
      // getter is getIsAvailable() → Jackson serializes key as "isAvailable").
      // Falling back to json['available'] covers any future API normalisation.
      available: json['isAvailable'] ?? json['available'] ?? true,
      categoryId: json['categoryId']?.toString() ?? '',
      categoryName: json['categoryName'] ?? '',
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      reviewCount: json['reviewCount'] as int?,
    );
  }
}
