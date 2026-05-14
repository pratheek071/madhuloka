class RestaurantTable {
  final String id;
  final String name;
  final String status; // available, occupied

  RestaurantTable({
    required this.id,
    required this.name,
    required this.status,
  });

  factory RestaurantTable.fromJson(Map<String, dynamic> json) {
    return RestaurantTable(
      id: json['id'],
      name: json['name'],
      status: json['status'] ?? 'available',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
    };
  }
}
