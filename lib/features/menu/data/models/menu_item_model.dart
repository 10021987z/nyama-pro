// ─── MenuItemModel ────────────────────────────────────────────────────────────

class MenuItemModel {
  final String id;
  final String name;
  final String? description;
  final int priceXaf;
  final String category;
  final String? imageUrl;
  final bool isAvailable;
  final bool isDailySpecial;
  final int? prepTimeMin;
  final int? stockRemaining;
  final DateTime createdAt;

  const MenuItemModel({
    required this.id,
    required this.name,
    this.description,
    required this.priceXaf,
    required this.category,
    this.imageUrl,
    this.isAvailable = true,
    this.isDailySpecial = false,
    this.prepTimeMin,
    this.stockRemaining,
    required this.createdAt,
  });

  factory MenuItemModel.fromJson(Map<String, dynamic> json) => MenuItemModel(
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        priceXaf: (json['priceXaf'] as num?)?.toInt() ??
            (json['price'] as num?)?.toInt() ??
            0,
        category: json['category'] as String? ?? 'Plats',
        imageUrl: json['imageUrl'] as String? ?? json['image'] as String?,
        isAvailable: json['isAvailable'] as bool? ?? true,
        isDailySpecial: json['isDailySpecial'] as bool? ?? false,
        prepTimeMin: (json['prepTimeMin'] as num?)?.toInt(),
        stockRemaining: (json['stockRemaining'] as num?)?.toInt(),
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  MenuItemModel copyWith({
    String? name,
    String? description,
    int? priceXaf,
    String? category,
    String? imageUrl,
    bool? isAvailable,
    bool? isDailySpecial,
    int? prepTimeMin,
    int? stockRemaining,
  }) =>
      MenuItemModel(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        priceXaf: priceXaf ?? this.priceXaf,
        category: category ?? this.category,
        imageUrl: imageUrl ?? this.imageUrl,
        isAvailable: isAvailable ?? this.isAvailable,
        isDailySpecial: isDailySpecial ?? this.isDailySpecial,
        prepTimeMin: prepTimeMin ?? this.prepTimeMin,
        stockRemaining: stockRemaining ?? this.stockRemaining,
        createdAt: createdAt,
      );
}
