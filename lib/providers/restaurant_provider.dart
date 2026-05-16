import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../models/table_model.dart';
import '../models/menu_item_model.dart';
import '../models/category_model.dart';
import '../services/supabase_service.dart';

class RestaurantProvider with ChangeNotifier {
  final SupabaseService _service = SupabaseService();

  List<RestaurantTable> _tables = [];
  List<Category> _categories = [];
  List<MenuItem> _menuItems = [];
  
  bool _isLoading = false;

  List<RestaurantTable> get tables => _tables;
  List<Category> get categories => _categories;
  List<MenuItem> get menuItems => _menuItems;
  bool get isLoading => _isLoading;

  Future<void> fetchData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _tables = await _service.getTables();
      _categories = await _service.getCategories();
      _menuItems = await _service.getMenuItems();
    } catch (e) {
      debugPrint("Error fetching data: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Cart State (Temporary local state for mobile order taking)
  final Map<String, int> _cart = {}; // menuItemId -> quantity

  Map<String, int> get cart => _cart;

  void addToCart(String itemId) {
    print("Adding to cart: $itemId");
    _cart[itemId] = (_cart[itemId] ?? 0) + 1;
    print("New Cart State: $_cart");
    notifyListeners();
  }

  void removeFromCart(String itemId) {
    print("Removing from cart: $itemId");
    if (_cart.containsKey(itemId)) {
      if (_cart[itemId]! > 1) {
        _cart[itemId] = _cart[itemId]! - 1;
      } else {
        _cart.remove(itemId);
      }
      print("New Cart State: $_cart");
      notifyListeners();
    }
  }

  void clearCart() {
    print("Clearing cart");
    _cart.clear();
    notifyListeners();
  }

  double get cartTotal {
    double total = 0;
    _cart.forEach((itemId, qty) {
      final item = _menuItems.firstWhere((m) => m.id == itemId);
      double itemTotal = item.price * qty;
      if (item.itemType.toLowerCase() == 'food') {
        itemTotal *= 1.05; // Add 5% tax on top for food
      }
      total += itemTotal;
    });
    return total;
  }

  Future<void> submitOrder(String tableId) async {
    List<Map<String, dynamic>> items = [];
    _cart.forEach((itemId, qty) {
      final item = _menuItems.firstWhere((m) => m.id == itemId);
      items.add({
        'menu_item_id': itemId,
        'quantity': qty,
        'price': item.price,
      });
    });

    // Check if table is occupied to decide between New or Append
    final activeOrder = await _service.getActiveOrderForTable(tableId);

    if (activeOrder != null) {
      await _service.appendItemsToOrder(activeOrder.id, items, cartTotal);
    } else {
      await _service.placeOrder(tableId, items, cartTotal);
    }
    
    clearCart();
    await fetchData(); // Refresh tables status
  }

  Future<void> submitParcelOrder(String? customerInfo) async {
    List<Map<String, dynamic>> items = [];
    _cart.forEach((itemId, qty) {
      final item = _menuItems.firstWhere((m) => m.id == itemId);
      items.add({
        'menu_item_id': itemId,
        'quantity': qty,
        'price': item.price,
      });
    });

    await _service.placeParcelOrder(items, cartTotal, customerInfo);
    clearCart();
    await fetchData();
  }

  // --- Sales Reporting ---

  Future<List<OrderModel>> getCompletedOrders({DateTime? start, DateTime? end}) async {
    return await _service.getCompletedOrders(start: start, end: end);
  }

  Future<String> exportSalesToCSV(List<OrderModel> orders) async {
    List<List<dynamic>> rows = [];
    // Header
    rows.add(["Date", "Table", "Total Items", "Total Amount", "Status"]);

    for (var order in orders) {
      rows.add([
        DateFormat('yyyy-MM-dd HH:mm').format(order.createdAt),
        order.tableName,
        order.items.fold(0, (sum, item) => (sum as int) + item.quantity),
        order.totalAmount,
        order.status,
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);
    
    // For Desktop, we can save to a file. For Mobile, it's trickier but we'll save to App Docs.
    final directory = await getApplicationDocumentsDirectory();
    final path = "${directory.path}/sales_report_${DateTime.now().millisecondsSinceEpoch}.csv";
    final file = File(path);
    await file.writeAsString(csvData);
    
    return path;
  }

  // --- Menu Management Actions ---

  Future<void> addCategory(String name) async {
    await _service.addCategory(name);
    await fetchData();
  }

  Future<void> updateCategory(String id, String name) async {
    await _service.updateCategory(id, name);
    await fetchData();
  }

  Future<void> deleteCategory(String id) async {
    await _service.deleteCategory(id);
    await fetchData();
  }

  Future<void> addMenuItem(String categoryId, String name, double price, String? description, String itemType) async {
    try {
      await _service.addMenuItem(categoryId, name, price, description, itemType);
      await fetchData();
    } catch (e) {
      debugPrint("Error adding menu item: $e");
    }
  }

  Future<void> updateMenuItem(String id, String categoryId, String name, double price, String? description, String itemType) async {
    try {
      await _service.updateMenuItem(id, categoryId, name, price, description, itemType);
      await fetchData();
    } catch (e) {
      debugPrint("Error updating menu item: $e");
    }
  }

  Future<void> deleteMenuItem(String id) async {
    await _service.deleteMenuItem(id);
    await fetchData();
  }

  // --- Table Management Actions ---

  Future<void> addTable(String name) async {
    await _service.addTable(name);
    await fetchData();
  }

  Future<void> updateTable(String id, String name) async {
    await _service.updateTable(id, name);
    await fetchData();
  }

  Future<void> deleteTable(String id) async {
    await _service.deleteTable(id);
    await fetchData();
  }
}
