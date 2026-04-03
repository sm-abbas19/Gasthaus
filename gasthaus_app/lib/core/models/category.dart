import 'menu_item.dart';

class Category {
  final String id;
  final String name;
  final List<MenuItem> items;

  const Category({
    required this.id,
    required this.name,
    required this.items,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    final rawItems = json['menuItems'] ?? json['items'] ?? [];
    return Category(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      items: (rawItems as List)
          .map((i) => MenuItem.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}
