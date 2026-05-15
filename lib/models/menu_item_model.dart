class MenuItem {
  final String id;
  final String categoryId;
  final String name;
  final double price;
  final String? imageUrl;
  final String? description;
  final String itemType; // 'food' or 'drink'

  MenuItem({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.price,
    this.imageUrl,
    this.description,
    required this.itemType,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'],
      categoryId: json['category_id'],
      name: json['name'],
      price: (json['price'] as num).toDouble(),
      imageUrl: json['image_url'],
      description: json['description'],
      itemType: json['item_type'] ?? 'food',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_id': categoryId,
      'name': name,
      'price': price,
      'image_url': imageUrl,
      'description': description,
      'item_type': itemType,
    };
  }
}
