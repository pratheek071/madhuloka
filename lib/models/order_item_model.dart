class OrderItem {
  final String id;
  final String orderId;
  final String menuItemId;
  final String itemName; // Added for convenience in UI/Receipt
  final int quantity;
  final double price;
  final String itemType;

  OrderItem({
    required this.id,
    required this.orderId,
    required this.menuItemId,
    required this.itemName,
    required this.quantity,
    required this.price,
    this.itemType = 'food',
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'],
      orderId: json['order_id'],
      menuItemId: json['menu_item_id'],
      itemName: json['menu_items']?['name'] ?? 'Unknown Item',
      quantity: json['quantity'],
      price: (json['price'] as num).toDouble(),
      itemType: json['menu_items']?['item_type'] ?? 'food',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'menu_item_id': menuItemId,
      'quantity': quantity,
      'price': price,
    };
  }
}
