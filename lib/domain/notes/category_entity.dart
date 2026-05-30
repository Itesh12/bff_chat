class CategoryEntity {
  final String id;
  final String name;
  final String colorHex;
  final int displayOrder;
  final DateTime createdAt;

  const CategoryEntity({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.displayOrder,
    required this.createdAt,
  });

  CategoryEntity copyWith({
    String? id,
    String? name,
    String? colorHex,
    int? displayOrder,
    DateTime? createdAt,
  }) {
    return CategoryEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
