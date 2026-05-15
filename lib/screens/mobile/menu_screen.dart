import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/restaurant_provider.dart';
import '../../models/table_model.dart';
import '../../models/order_model.dart';
import '../../services/supabase_service.dart';
import 'cart_screen.dart';

class MenuScreen extends StatefulWidget {
  final RestaurantTable table;

  const MenuScreen({super.key, required this.table});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();
    
    return DefaultTabController(
      length: provider.categories.length + 1,
      child: Scaffold(
        appBar: AppBar(
          title: _isSearching 
              ? TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search items...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.black54),
                  ),
                  style: const TextStyle(color: Colors.black),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase();
                    });
                  },
                )
              : Text('Menu - ${widget.table.name}'),
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) _searchQuery = '';
                });
              },
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              ...provider.categories.map((c) => Tab(text: c.name)),
              const Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long, size: 16),
                    SizedBox(width: 8),
                    Text('Ordered Items'),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ...provider.categories.map((category) {
              final items = provider.menuItems.where((m) {
                final matchesCategory = m.categoryId == category.id;
                final matchesSearch = m.name.toLowerCase().contains(_searchQuery);
                return matchesCategory && matchesSearch;
              }).toList();
              
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final quantity = provider.cart[item.id] ?? 0;

                  return ListTile(
                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.description != null && item.description!.isNotEmpty)
                          Text(item.description!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        Text('₹${item.price.toStringAsFixed(2)}'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (quantity > 0) ...[
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                            onPressed: () => context.read<RestaurantProvider>().removeFromCart(item.id),
                          ),
                          Text('$quantity', style: const TextStyle(fontSize: 16)),
                        ],
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                          onPressed: () => context.read<RestaurantProvider>().addToCart(item.id),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
            _buildOrderedItemsTab(),
          ],
        ),
        floatingActionButton: provider.cart.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CartScreen(table: widget.table),
                    ),
                  );
                },
                label: Text('View Order (${provider.cart.length})'),
                icon: const Icon(Icons.shopping_basket),
              )
            : null,
      ),
    );
  }

  Widget _buildOrderedItemsTab() {
    return StreamBuilder<OrderModel?>(
      stream: SupabaseService().watchActiveOrderForTable(widget.table.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final order = snapshot.data;
        if (order == null) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_basket_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No active orders for this table.', style: TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }

        // Since the basic stream doesn't have items, we fetch details
        return FutureBuilder<OrderModel>(
          future: SupabaseService().getOrderDetails(order.id),
          builder: (context, detailsSnapshot) {
            if (!detailsSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final fullOrder = detailsSnapshot.data!;
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.orange.shade50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Order Status: ${fullOrder.status.toUpperCase()}', 
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                      Text('Total: ₹${fullOrder.totalAmount.toStringAsFixed(2)}', 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: fullOrder.items.length,
                    itemBuilder: (context, index) {
                      final item = fullOrder.items[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.shade100,
                          child: Text('${item.quantity}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('₹${item.price} each'),
                        trailing: Text('₹${(item.price * item.quantity).toStringAsFixed(2)}', 
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
