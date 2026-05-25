import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/restaurant_provider.dart';
import '../../models/table_model.dart';
import '../../models/order_model.dart';
import '../../models/order_item_model.dart';
import '../../services/supabase_service.dart';
import 'cart_screen.dart';

class MenuScreen extends StatefulWidget {
  final RestaurantTable table;
  final String? customerName;

  const MenuScreen({super.key, required this.table, this.customerName});

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
            if (!_isSearching && widget.table.status == 'occupied')
              IconButton(
                icon: const Icon(Icons.swap_horiz),
                tooltip: 'Transfer Table',
                onPressed: () async {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(child: CircularProgressIndicator()),
                  );
                  try {
                    final activeOrder = await SupabaseService().getActiveOrderForTable(widget.table.id);
                    if (!context.mounted) return;
                    Navigator.pop(context); // Dismiss loading indicator
                    if (activeOrder == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No active order found on this table.')),
                      );
                      return;
                    }
                    _showTransferDialog(context, activeOrder);
                  } catch (e) {
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                },
              ),
            if (!_isSearching)
              Builder(
                builder: (context) {
                  return IconButton(
                    icon: const Icon(Icons.receipt_long),
                    tooltip: 'Ordered Items',
                    onPressed: () {
                      DefaultTabController.of(context).animateTo(provider.categories.length);
                    },
                  );
                },
              ),
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
          bottom: _isSearching
              ? null
              : TabBar(
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
        body: (_isSearching && _searchQuery.isNotEmpty)
            ? Builder(
                builder: (context) {
                  final items = provider.menuItems.where((m) {
                    return m.name.toLowerCase().contains(_searchQuery);
                  }).toList();

                  if (items.isEmpty) {
                    return const Center(child: Text('No matching items found.'));
                  }

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
                },
              )
            : TabBarView(
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
            ? Builder(
                builder: (context) => FloatingActionButton.extended(
                  onPressed: () async {
                    final didPlaceOrder = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CartScreen(table: widget.table, customerName: widget.customerName),
                      ),
                    );
                    if (didPlaceOrder == true && context.mounted) {
                      DefaultTabController.of(context).animateTo(provider.categories.length);
                    }
                  },
                  label: Text('View Order (${provider.cart.length})'),
                  icon: const Icon(Icons.shopping_basket),
                ),
              )
            : null,
      ),
    );
  }

  Future<void> _updateOrderedItemQuantity(OrderModel order, OrderItem targetItem, int newQuantity) async {
    final List<Map<String, dynamic>> itemsToSave = [];
    double newTotal = 0.0;

    for (var item in order.items) {
      int quantity = item.id == targetItem.id ? newQuantity : item.quantity;
      if (quantity <= 0) continue; // Deleted/omitted

      final int origPrinted = item.printedQuantity;
      final int finalPrinted = origPrinted > quantity ? quantity : origPrinted;

      itemsToSave.add({
        'order_id': order.id,
        'menu_item_id': item.menuItemId,
        'quantity': quantity,
        'printed_quantity': finalPrinted,
        'price': item.price,
        'instructions': item.instructions ?? '',
      });

      double itemPrice = item.price * quantity;
      final type = item.itemType.toLowerCase();
      if (type == 'food' || type == 'cocktail' || type == 'mocktail') {
        itemPrice *= 1.05;
      }
      newTotal += itemPrice;
    }

    try {
      if (itemsToSave.isEmpty) {
        // If all items are deleted, cancel the order and free table
        await SupabaseService().updateOrderStatus(order.id, 'cancelled', tableId: order.tableId);
      } else {
        await SupabaseService().updateOrderItems(order.id, itemsToSave, newTotal);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order updated successfully!')),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update order: $e')),
        );
      }
    }
  }

  void _showTransferDialog(BuildContext context, OrderModel activeOrder) {
    final provider = Provider.of<RestaurantProvider>(context, listen: false);
    final availableTables = provider.tables.where((t) => t.status == 'available').toList();

    bool isNewTable = false;
    RestaurantTable? selectedTable = availableTables.isNotEmpty ? availableTables.first : null;
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Transfer Table ${widget.table.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select transfer destination type:'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Existing Table'),
                        selected: !isNewTable,
                        onSelected: (val) {
                          if (val) {
                            setState(() => isNewTable = false);
                          }
                        },
                      ),
                      ChoiceChip(
                        label: const Text('New Table'),
                        selected: isNewTable,
                        onSelected: (val) {
                          if (val) {
                            setState(() => isNewTable = true);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!isNewTable) ...[
                    const Text('Destination Table:'),
                    const SizedBox(height: 8),
                    if (availableTables.isEmpty)
                      const Text(
                        'No available tables. Create a new table.',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<RestaurantTable>(
                            value: selectedTable,
                            isExpanded: true,
                            items: availableTables.map((t) {
                              return DropdownMenuItem<RestaurantTable>(
                                value: t,
                                child: Text(t.name),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() => selectedTable = val);
                            },
                          ),
                        ),
                      ),
                  ] else ...[
                    const Text('New Table Name:'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: textController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Table 12',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    String? targetTableId;
                    String targetTableName = '';
                    
                    if (isNewTable) {
                      final name = textController.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a table name')),
                        );
                        return;
                      }
                      targetTableName = name;
                    } else {
                      if (selectedTable == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a destination table')),
                        );
                        return;
                      }
                      targetTableId = selectedTable!.id;
                      targetTableName = selectedTable!.name;
                    }

                    // Show a progress indicator
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(child: CircularProgressIndicator()),
                    );

                    try {
                      if (isNewTable) {
                        // Create the new table first
                        targetTableId = await SupabaseService().addTable(targetTableName);
                      }

                      // Execute the transfer
                      await SupabaseService().transferOrder(activeOrder.id, widget.table.id, targetTableId!);
                      
                      // Refresh the tables lists
                      await provider.fetchData();

                      if (context.mounted) {
                        // Pop progress dialog
                        Navigator.pop(context);
                        // Pop transfer dialog
                        Navigator.pop(dialogContext);
                        // Pop MenuScreen since the table is no longer occupied / order transferred!
                        Navigator.pop(context);
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Order transferred to $targetTableName successfully!')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        // Pop progress dialog
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error transferring order: $e')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Transfer'),
                ),
              ],
            );
          },
        );
      },
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
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        elevation: 1,
                        child: ListTile(
                          title: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('₹${item.price.toStringAsFixed(2)} each\nTotal: ₹${(item.price * item.quantity).toStringAsFixed(2)}'),
                              if (item.instructions != null && item.instructions!.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Note: ${item.instructions}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.orange),
                                onPressed: () => _updateOrderedItemQuantity(fullOrder, item, item.quantity - 1),
                              ),
                              Text('${item.quantity}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                onPressed: () => _updateOrderedItemQuantity(fullOrder, item, item.quantity + 1),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _updateOrderedItemQuantity(fullOrder, item, 0),
                              ),
                            ],
                          ),
                        ),
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
