import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/table_model.dart';
import '../models/category_model.dart';
import '../models/menu_item_model.dart';
import '../models/order_model.dart';

class SupabaseService {
  static final SupabaseClient client = Supabase.instance.client;

  // Tables
  Future<List<RestaurantTable>> getTables() async {
    final response = await client.from('tables').select().order('name');
    return (response as List).map((t) => RestaurantTable.fromJson(t)).toList();
  }

  Stream<List<RestaurantTable>> watchTables() {
    return client
        .from('tables')
        .stream(primaryKey: ['id'])
        .order('name')
        .map((data) => data.map((json) => RestaurantTable.fromJson(json)).toList());
  }

  // Categories
  Future<List<Category>> getCategories() async {
    final response = await client.from('categories').select().order('name');
    return (response as List).map((c) => Category.fromJson(c)).toList();
  }

  // Menu Items
  Future<List<MenuItem>> getMenuItems() async {
    final response = await client.from('menu_items').select().order('name');
    return (response as List).map((m) => MenuItem.fromJson(m)).toList();
  }

  // --- CRUD for Menu Management ---

  Future<void> addCategory(String name) async {
    await client.from('categories').insert({'name': name});
  }

  Future<void> updateCategory(String id, String name) async {
    await client.from('categories').update({'name': name}).eq('id', id);
  }

  Future<void> deleteCategory(String id) async {
    await client.from('categories').delete().eq('id', id);
  }

  Future<void> addMenuItem(String categoryId, String name, double price, String? description, String itemType) async {
    await client.from('menu_items').insert({
      'category_id': categoryId,
      'name': name,
      'price': price,
      'description': description,
      'item_type': itemType,
    });
  }

  Future<void> updateMenuItem(String id, String categoryId, String name, double price, String? description, String itemType) async {
    await client.from('menu_items').update({
      'category_id': categoryId,
      'name': name,
      'price': price,
      'description': description,
      'item_type': itemType,
    }).eq('id', id);
  }

  Future<void> deleteMenuItem(String id) async {
    await client.from('menu_items').delete().eq('id', id);
  }

  Stream<List<OrderModel>> watchActiveOrders() {
    return client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => OrderModel.fromJson(json)).toList());
  }

  Stream<OrderModel?> watchActiveOrderForTable(String tableId) {
    return client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('table_id', tableId)
        .map((data) {
          // Filter by status manually as stream only supports one .eq()
          final activeOrders = data.where((json) => json['status'] == 'pending').toList();
          if (activeOrders.isEmpty) return null;
          return OrderModel.fromJson(activeOrders.first);
        });
  }

  // Full Order Details (including items)
  Future<OrderModel> getOrderDetails(String orderId) async {
    final response = await client
        .from('orders')
        .select('*, tables(name), order_items(*, menu_items(name))')
        .eq('id', orderId)
        .single();
    return OrderModel.fromJson(response);
  }

  // Place Order
  Future<void> placeOrder(String tableId, List<Map<String, dynamic>> items, double total) async {
    // 1. Create Order
    final orderResponse = await client.from('orders').insert({
      'table_id': tableId,
      'total_amount': total,
      'status': 'pending',
      'order_source': 'waiter',
    }).select().single();

    final orderId = orderResponse['id'];

    // 2. Create Order Items
    final orderItems = items.map((item) => {
      'order_id': orderId,
      'menu_item_id': item['menu_item_id'],
      'quantity': item['quantity'],
      'price': item['price'],
    }).toList();

    await client.from('order_items').insert(orderItems);

    // 3. Update Table Status
    await client.from('tables').update({'status': 'occupied'}).eq('id', tableId);
  }

  // Update Order Status
  Future<void> updateOrderStatus(String orderId, String status, {String? tableId, String? paymentMethod}) async {
    final Map<String, dynamic> updates = {'status': status};
    if (status == 'paid') {
      updates['completed_at'] = DateTime.now().toIso8601String();
      if (paymentMethod != null) {
        updates['payment_method'] = paymentMethod;
      }
    }
    
    await client.from('orders').update(updates).eq('id', orderId);
    
    // If paid/cancelled, free up the table
    if ((status == 'paid' || status == 'cancelled') && tableId != null) {
      await client.from('tables').update({'status': 'available'}).eq('id', tableId);
    }
  }

  // --- New Methods for Phase 2 ---

  Future<OrderModel?> getActiveOrderForTable(String tableId) async {
    final response = await client
        .from('orders')
        .select('*, tables(name), order_items(*, menu_items(name))')
        .eq('table_id', tableId)
        .eq('status', 'pending')
        .maybeSingle();
    
    if (response == null) return null;
    return OrderModel.fromJson(response);
  }

  Future<void> appendItemsToOrder(String orderId, List<Map<String, dynamic>> items, double additionalTotal) async {
    // 1. Get current order to get current total
    final orderData = await client.from('orders').select('total_amount').eq('id', orderId).single();
    final double currentTotal = (orderData['total_amount'] as num).toDouble();

    // 2. Insert new items
    final orderItems = items.map((item) => {
      'order_id': orderId,
      'menu_item_id': item['menu_item_id'],
      'quantity': item['quantity'],
      'price': item['price'],
    }).toList();

    await client.from('order_items').insert(orderItems);

    // 3. Update Order Total
    await client.from('orders').update({
      'total_amount': currentTotal + additionalTotal,
    }).eq('id', orderId);
  }

  Future<void> placeParcelOrder(List<Map<String, dynamic>> items, double total, String? customerInfo) async {
    try {
      print("Starting placeParcelOrder...");
      print("Data: total=$total, customer_info=$customerInfo");
      
      // 1. Create Order
      final orderResponse = await client.from('orders').insert({
        'total_amount': total,
        'status': 'pending',
        'is_parcel': true,
        'customer_info': customerInfo,
        'order_source': 'waiter',
      }).select().single();

      final orderId = orderResponse['id'];
      print("Order created with ID: $orderId");

      // 2. Insert items
      final orderItems = items.map((item) => {
        'order_id': orderId,
        'menu_item_id': item['menu_item_id'],
        'quantity': item['quantity'],
        'price': item['price'],
      }).toList();

      await client.from('order_items').insert(orderItems);
      print("Items inserted successfully.");
    } catch (e) {
      print("CRITICAL ERROR in placeParcelOrder: $e");
      rethrow;
    }
  }

  Future<List<OrderModel>> getCompletedOrders({DateTime? start, DateTime? end}) async {
    var query = client
        .from('orders')
        .select('*, tables(name), order_items(*, menu_items(name))')
        .eq('status', 'paid');
    
    if (start != null) {
      query = query.gte('completed_at', start.toIso8601String());
    }
    if (end != null) {
      query = query.lte('completed_at', end.toIso8601String());
    }

    final response = await query.order('completed_at', ascending: false);
    
    return (response as List).map((o) => OrderModel.fromJson(o)).toList();
  }

  // --- Table Management ---

  Future<void> addTable(String name) async {
    final response = await client.from('tables').select().eq('name', name).maybeSingle();
    if (response != null) {
      throw Exception('Table with name "$name" already exists!');
    }
    await client.from('tables').insert({
      'name': name,
      'status': 'available',
    });
  }

  Future<void> updateTable(String id, String name) async {
    await client.from('tables').update({'name': name}).eq('id', id);
  }

  Future<void> deleteTable(String id) async {
    await client.from('tables').delete().eq('id', id);
  }

  Future<void> updateOrderItems(String orderId, List<Map<String, dynamic>> items, double totalAmount) async {
    // 1. Delete old items
    await client.from('order_items').delete().eq('order_id', orderId);
    
    // 2. Insert new items
    await client.from('order_items').insert(items);

    // 3. Update the order total
    await client.from('orders').update({
      'total_amount': totalAmount,
    }).eq('id', orderId);
  }
}
