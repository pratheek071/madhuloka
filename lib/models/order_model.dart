import 'order_item_model.dart';

class OrderModel {
  final String id;
  final String? tableId;
  final String? tableName;
  final double totalAmount;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final List<OrderItem> items;
  final bool isParcel;
  final String? customerInfo;
  final String orderSource; // 'waiter' or 'customer'
  final String? paymentMethod;

  OrderModel({
    required this.id,
    this.tableId,
    this.tableName,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.completedAt,
    required this.items,
    this.isParcel = false,
    this.customerInfo,
    this.orderSource = 'waiter',
    this.paymentMethod,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'],
      tableId: json['table_id'],
      tableName: json['tables'] != null ? json['tables']['name'] : null,
      totalAmount: (json['total_amount'] as num).toDouble(),
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      isParcel: json['is_parcel'] ?? false,
      customerInfo: json['customer_info'],
      orderSource: json['order_source'] ?? 'waiter',
      paymentMethod: json['payment_method'],
      items: (json['order_items'] as List?)
              ?.map((item) => OrderItem.fromJson(item))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'table_id': tableId,
      'total_amount': totalAmount,
      'status': status,
      'is_parcel': isParcel,
      'customer_info': customerInfo,
      'order_source': orderSource,
      'payment_method': paymentMethod,
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  bool get isCustomerOrder => orderSource == 'customer';
}
