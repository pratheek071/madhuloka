import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/restaurant_provider.dart';
import '../../models/menu_item_model.dart';

class TakeawayView extends StatefulWidget {
  const TakeawayView({super.key});

  @override
  State<TakeawayView> createState() => _TakeawayViewState();
}

class _TakeawayViewState extends State<TakeawayView> with AutomaticKeepAliveClientMixin {
  final TextEditingController _customerController = TextEditingController();
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _customerController.dispose();
    super.dispose();
  }

  Widget _buildItemsList(List<MenuItem> items, RestaurantProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final qty = provider.cart[item.id] ?? 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('₹${item.price}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (qty > 0) ...[
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () => provider.removeFromCart(item.id),
                  ),
                  Text('$qty', style: const TextStyle(fontSize: 16)),
                ],
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                  onPressed: () => provider.addToCart(item.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<RestaurantProvider>();
    print("TakeawayView Build: Cart Size = ${provider.cart.length}");

    if (provider.categories.isEmpty) {
      return const Center(child: Text('No categories found. Add them in Manage Menu.'));
    }

    return DefaultTabController(
      length: provider.categories.length,
      child: Row(
        children: [
          // Left Side: Tabbed Menu or Global Search Results
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                    decoration: const InputDecoration(
                      hintText: 'Search Menu...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                
                if (_searchQuery.isEmpty) ...[
                  TabBar(
                    isScrollable: true,
                    labelColor: Colors.deepOrange,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.deepOrange,
                    tabs: provider.categories.map((c) => Tab(text: c.name)).toList(),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: provider.categories.map((category) {
                        final items = provider.menuItems.where((m) => 
                          m.categoryId == category.id
                        ).toList();

                        if (items.isEmpty) {
                          return const Center(child: Text('No items in this category.'));
                        }

                        return _buildItemsList(items, provider);
                      }).toList(),
                    ),
                  ),
                ] else ...[
                  // Show single search results list irrespective of category
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final items = provider.menuItems.where((m) => 
                          m.name.toLowerCase().contains(_searchQuery)
                        ).toList();

                        if (items.isEmpty) {
                          return const Center(child: Text('No matching items found.'));
                        }

                        return _buildItemsList(items, provider);
                      }
                    ),
                  ),
                ],
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          // Right Side: Cart Summary
          SizedBox(
            width: 400,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Parcel Summary', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _customerController,
                    decoration: const InputDecoration(
                      labelText: 'Customer Name / Phone',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: ListView(
                      children: provider.cart.entries.map((entry) {
                        final item = provider.menuItems.firstWhere((m) => m.id == entry.key);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.name),
                          subtitle: Text('₹${item.price} x ${entry.value}'),
                          trailing: Text('₹${(item.price * entry.value).toStringAsFixed(2)}'),
                        );
                      }).toList(),
                    ),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('₹${provider.cartTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: (provider.cart.isEmpty || provider.isSubmitting)
                        ? null 
                        : () async {
                            await provider.submitParcelOrder(_customerController.text);
                            _customerController.clear();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Parcel order created! Check Live Orders.')),
                              );
                            }
                          },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                      ),
                      child: provider.isSubmitting 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Confirm Parcel Order', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
