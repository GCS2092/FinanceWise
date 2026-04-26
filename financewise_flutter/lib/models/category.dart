class Category {
  final int id;
  final String name;
  final String type;
  final String? icon;
  final String? color;
  final bool isSystem;

  Category({
    required this.id,
    required this.name,
    required this.type,
    this.icon,
    this.color,
    this.isSystem = false,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      type: json['type'] ?? 'expense',
      icon: json['icon'],
      color: json['color'],
      isSystem: json['is_system'] ?? false,
    );
  }
}
