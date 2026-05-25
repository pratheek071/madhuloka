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
      _tables.sort((a, b) {
        final List<String> segsA = a.name.split(RegExp(r'[\.\-\s]+'));
        final List<String> segsB = b.name.split(RegExp(r'[\.\-\s]+'));
        for (int i = 0; i < segsA.length && i < segsB.length; i++) {
          final String sA = segsA[i];
          final String sB = segsB[i];
          if (sA != sB) {
            final int? intA = int.tryParse(sA);
            final int? intB = int.tryParse(sB);
            if (intA != null && intB != null) {
              return intA.compareTo(intB);
            }
            return sA.toLowerCase().compareTo(sB.toLowerCase());
          }
        }
        return segsA.length.compareTo(segsB.length);
      });
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
  final Map<String, String> _cartInstructions = {}; // menuItemId -> instructions
  bool _isSubmitting = false;

  Map<String, int> get cart => _cart;
  bool get isSubmitting => _isSubmitting;

  String getCartInstruction(String itemId) {
    return _cartInstructions[itemId] ?? '';
  }

  void updateCartInstruction(String itemId, String instruction) {
    _cartInstructions[itemId] = instruction;
    notifyListeners();
  }

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
        _cartInstructions.remove(itemId);
      }
      print("New Cart State: $_cart");
      notifyListeners();
    }
  }

  void deleteFromCart(String itemId) {
    print("Deleting from cart: $itemId");
    if (_cart.containsKey(itemId)) {
      _cart.remove(itemId);
      _cartInstructions.remove(itemId);
      notifyListeners();
    }
  }

  void clearCart() {
    print("Clearing cart");
    _cart.clear();
    _cartInstructions.clear();
    notifyListeners();
  }

  double get cartTotal {
    double total = 0;
    _cart.forEach((itemId, qty) {
      final item = _menuItems.firstWhere((m) => m.id == itemId);
      double itemTotal = item.price * qty;
      final type = item.itemType.toLowerCase();
      if (type == 'food' || type == 'cocktail' || type == 'mocktail') {
        itemTotal *= 1.05; // Add 5% tax on top
      }
      total += itemTotal;
    });
    return total;
  }

  Future<void> submitOrder(String tableId, {String? customerInfo}) async {
    if (_isSubmitting) return;
    
    _isSubmitting = true;
    notifyListeners();
    
    try {
      List<Map<String, dynamic>> items = [];
      _cart.forEach((itemId, qty) {
        final item = _menuItems.firstWhere((m) => m.id == itemId);
        items.add({
          'menu_item_id': itemId,
          'quantity': qty,
          'price': item.price,
          'instructions': _cartInstructions[itemId] ?? '',
        });
      });

      // Check if table is occupied to decide between New or Append
      final activeOrder = await _service.getActiveOrderForTable(tableId);

      if (activeOrder != null) {
        await _service.appendItemsToOrder(activeOrder.id, items, cartTotal);
      } else {
        await _service.placeOrder(tableId, items, cartTotal, customerInfo: customerInfo);
      }
      
      clearCart();
      await fetchData(); // Refresh tables status
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> submitParcelOrder(String? customerInfo) async {
    if (_isSubmitting) return;
    
    _isSubmitting = true;
    notifyListeners();

    try {
      List<Map<String, dynamic>> items = [];
      _cart.forEach((itemId, qty) {
        final item = _menuItems.firstWhere((m) => m.id == itemId);
        items.add({
          'menu_item_id': itemId,
          'quantity': qty,
          'price': item.price,
          'instructions': _cartInstructions[itemId] ?? '',
        });
      });

      await _service.placeParcelOrder(items, cartTotal, customerInfo);
      clearCart();
      await fetchData();
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  // --- Sales Reporting ---

  Future<List<OrderModel>> getCompletedOrders({DateTime? start, DateTime? end}) async {
    return await _service.getCompletedOrders(start: start, end: end);
  }

  Future<String> exportSalesToCSV(List<OrderModel> orders) async {
    List<List<dynamic>> rows = [];
    // Header
    rows.add(["Bill No", "Date", "Table", "Total Items", "Discount", "Total Amount", "Payment Method", "Status"]);

    for (var order in orders) {
      rows.add([
        order.billNo != null ? 'REG-${order.billNo.toString().padLeft(4, '0')}' : 'N/A',
        DateFormat('yyyy-MM-dd HH:mm').format(order.createdAt),
        order.tableName,
        order.items.fold(0, (sum, item) => (sum as int) + item.quantity),
        order.discountAmount,
        order.finalAmount,
        order.paymentMethod ?? 'N/A',
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

  Future<void> updateOrderPaymentMethod(String orderId, String paymentMethod) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _service.updateOrderPaymentMethod(orderId, paymentMethod);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
