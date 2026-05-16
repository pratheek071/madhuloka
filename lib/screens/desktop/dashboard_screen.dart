import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../models/order_model.dart';
import '../../models/table_model.dart';
import 'billing_service.dart';
import 'package:provider/provider.dart';
import '../../providers/restaurant_provider.dart';
import '../../models/menu_item_model.dart';
import '../../models/category_model.dart';
import 'menu_management_view.dart';
import 'sales_reports_view.dart';
import 'takeaway_view.dart';
import 'qr_code_view.dart';
import 'digital_menu_view.dart';

class DesktopDashboard extends StatefulWidget {
  const DesktopDashboard({super.key});

  @override
  State<DesktopDashboard> createState() => _DesktopDashboardState();
}

class _DesktopDashboardState extends State<DesktopDashboard> {
  final SupabaseService _service = SupabaseService();
  OrderModel? _selectedOrder;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          title: const Text('Madhuloka Dining', 
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          bottom: TabBar(
            isScrollable: true,
            labelColor: Colors.deepOrange,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.deepOrange,
            indicatorWeight: 3,
            tabs: const [
              Tab(icon: Icon(Icons.list_alt), text: 'Live Orders'),
              Tab(icon: Icon(Icons.shopping_bag), text: 'Takeaway'),
              Tab(icon: Icon(Icons.qr_code), text: 'QR Codes'),
              Tab(icon: Icon(Icons.restaurant_menu), text: 'Manage Menu'),
              Tab(icon: Icon(Icons.menu_book), text: 'Digital Menu'),
              Tab(icon: Icon(Icons.bar_chart), text: 'Sales Reports'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => context.read<RestaurantProvider>().fetchData(),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: TabBarView(
          children: [
            _buildLiveOrdersView(),
            const TakeawayView(),
            const QrCodeView(),
            const MenuManagementView(),
            const DigitalMenuView(),
            const SalesReportsView(),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveOrdersView() {
    return Consumer<RestaurantProvider>(
      builder: (context, provider, child) {
        return Row(
          children: [
            // Sidebar: List of Active Orders
            Container(
              width: 400,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.centerLeft,
                    child: const Text('Active Sessions', 
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: StreamBuilder<List<OrderModel>>(
                      stream: _service.watchActiveOrders(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        final orders = snapshot.data ?? [];
                        if (orders.isEmpty) {
                          return _buildEmptyState('No active orders');
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: orders.length,
                          itemBuilder: (context, index) {
                            final order = orders[index];
                            final isSelected = _selectedOrder?.id == order.id;
                            
                            // Table Name Lookup
                            String tableName = 'Table';
                            if (order.isParcel) {
                              tableName = "PARCEL: ${order.customerInfo ?? 'Guest'}";
                            } else {
                              final table = provider.tables.firstWhere(
                                (t) => t.id == order.tableId,
                                orElse: () => RestaurantTable(id: '', name: 'Table', status: ''),
                              );
                              tableName = table.name == 'Table' ? 'Table ${order.tableId?.substring(0,4) ?? "Unk"}' : table.name;
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _OrderSidebarCard(
                                order: order,
                                tableName: tableName,
                                isSelected: isSelected,
                                onTap: () async {
                                  final details = await _service.getOrderDetails(order.id);
                                  setState(() {
                                    _selectedOrder = details;
                                  });
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            // Main View: Order Details & Billing
            Expanded(
              child: _selectedOrder == null
                  ? _buildEmptyState('Select an order to view details')
                  : _OrderDetailsView(
                      order: _selectedOrder!,
                      onStatusUpdate: () {
                        setState(() {
                          _selectedOrder = null;
                        });
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
        ],
      ),
    );
  }
}

class _OrderSidebarCard extends StatelessWidget {
  final OrderModel order;
  final String tableName;
  final bool isSelected;
  final VoidCallback onTap;

  const _OrderSidebarCard({
    required this.order,
    required this.tableName,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepOrange.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.deepOrange.shade200 : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [BoxShadow(color: Colors.deepOrange.withOpacity(0.05), blurRadius: 10)] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(tableName, 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                ),
                Text('₹${order.totalAmount.toStringAsFixed(0)}', 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(DateFormat('hh:mm a').format(order.createdAt),
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  ],
                ),
                if (order.isCustomerOrder)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Text('WEB ORDER', 
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderDetailsView extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onStatusUpdate;

  const _OrderDetailsView({required this.order, required this.onStatusUpdate});

  void _showEditOrderDialog(BuildContext context, OrderModel order) {
    final provider = context.read<RestaurantProvider>();
    final menuItems = provider.menuItems;
    
    List<Map<String, dynamic>> editedItems = order.items.map((item) => {
      'menu_item_id': item.menuItemId,
      'quantity': item.quantity,
      'price': item.price,
      'name': item.itemName,
      'item_type': item.itemType,
    }).toList();

    String? selectedMenuItemId = menuItems.isNotEmpty ? menuItems.first.id : null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Edit Order #${order.id.substring(0,8)}'),
          content: SizedBox(
            width: 600,
            height: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedMenuItemId,
                        items: menuItems.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))).toList(),
                        onChanged: (val) => setState(() => selectedMenuItemId = val),
                        decoration: const InputDecoration(labelText: 'Select Item to Add'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () {
                        if (selectedMenuItemId != null) {
                          final item = menuItems.firstWhere((m) => m.id == selectedMenuItemId);
                          setState(() {
                            final existingIndex = editedItems.indexWhere((i) => i['menu_item_id'] == item.id);
                            if (existingIndex >= 0) {
                              editedItems[existingIndex]['quantity'] += 1;
                            } else {
                              editedItems.add({
                                'menu_item_id': item.id,
                                'quantity': 1,
                                'price': item.price,
                                'name': item.name,
                                'item_type': item.itemType,
                              });
                            }
                          });
                        }
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView.builder(
                    itemCount: editedItems.length,
                    itemBuilder: (context, index) {
                      final item = editedItems[index];
                      return ListTile(
                        title: Text(item['name'] ?? 'Unknown'),
                        subtitle: Text('₹${item['price']} x ${item['quantity']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: () {
                                setState(() {
                                  if (item['quantity'] > 1) {
                                    item['quantity'] -= 1;
                                  } else {
                                    editedItems.removeAt(index);
                                  }
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                setState(() {
                                  item['quantity'] += 1;
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  editedItems.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final double newTotal = editedItems.fold(0.0, (sum, item) {
                  double itemPrice = item['price'] * item['quantity'];
                  if (item['item_type'].toString().toLowerCase() == 'food') {
                    itemPrice *= 1.05;
                  }
                  return sum + itemPrice;
                });
                final itemsToSave = editedItems.map((item) => {
                  'order_id': order.id,
                  'menu_item_id': item['menu_item_id'],
                  'quantity': item['quantity'],
                  'price': item['price'],
                }).toList();
                
                await SupabaseService().updateOrderItems(order.id, itemsToSave, newTotal);
                provider.fetchData();
                Navigator.pop(context);
                onStatusUpdate();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentMethodDialog(BuildContext context, OrderModel order, {bool shouldPrint = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Payment Method'),
        content: const Text('How would you like to settle this bill?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              if (shouldPrint) await BillingService.printInvoice(order);
              await SupabaseService().updateOrderStatus(order.id, 'paid', tableId: order.tableId, paymentMethod: 'Cash');
              onStatusUpdate();
            },
            icon: const Icon(Icons.money),
            label: const Text('Cash'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              if (shouldPrint) await BillingService.printInvoice(order);
              await SupabaseService().updateOrderStatus(order.id, 'paid', tableId: order.tableId, paymentMethod: 'Online');
              onStatusUpdate();
            },
            icon: const Icon(Icons.payment),
            label: const Text('Online'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = SupabaseService();

    return Padding(
      padding: const EdgeInsets.all(48.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Detailed Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.isParcel 
                      ? "Parcel: ${order.customerInfo ?? 'Takeaway'}"
                      : (order.tableName ?? 'Table Order'), 
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _InfoBadge(label: 'Order ID: ${order.id.substring(0,8)}', icon: Icons.tag),
                      const SizedBox(width: 12),
                      _InfoBadge(label: 'Placed: ${DateFormat('hh:mm a').format(order.createdAt)}', icon: Icons.schedule),
                      const SizedBox(width: 12),
                      _InfoBadge(
                        label: order.orderSource.toUpperCase(), 
                        icon: order.isCustomerOrder ? Icons.phone_android : Icons.person,
                        color: order.isCustomerOrder ? Colors.blue : Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _ActionButton(
                    onPressed: () => _showEditOrderDialog(context, order),
                    icon: Icons.edit_outlined,
                    label: 'Edit Order',
                    color: Colors.orange,
                  ),
                  _ActionButton(
                    onPressed: () async {
                      final provider = context.read<RestaurantProvider>();
                      final foodItems = order.items.where((item) {
                        final menuItem = provider.menuItems.firstWhere((m) => m.id == item.menuItemId, orElse: () => MenuItem(id: '', categoryId: '', name: '', price: 0, itemType: 'food'));
                        return menuItem.itemType.toLowerCase() == 'food';
                      }).toList();
                      
                      // Fallback: If no items are categorized as drinks, print all items as food
                      final hasDrinks = order.items.any((item) {
                        final menuItem = provider.menuItems.firstWhere((m) => m.id == item.menuItemId, orElse: () => MenuItem(id: '', categoryId: '', name: '', price: 0, itemType: 'food'));
                        return menuItem.itemType.toLowerCase() == 'drink';
                      });
                      
                      final itemsToPrint = !hasDrinks ? order.items : foodItems;
                      
                      await BillingService.printInvoice(order, title: 'KOT - FOOD', customItems: itemsToPrint);
                    },
                    icon: Icons.restaurant,
                    label: 'Print Food',
                    color: Colors.brown,
                  ),
                  _ActionButton(
                    onPressed: () async {
                      final provider = context.read<RestaurantProvider>();
                      final drinkItems = order.items.where((item) {
                        final menuItem = provider.menuItems.firstWhere((m) => m.id == item.menuItemId, orElse: () => MenuItem(id: '', categoryId: '', name: '', price: 0, itemType: 'food'));
                        return menuItem.itemType.toLowerCase() == 'drink';
                      }).toList();
                      await BillingService.printInvoice(order, title: 'BOT - DRINKS', customItems: drinkItems);
                    },
                    icon: Icons.local_bar,
                    label: 'Print Drinks',
                    color: Colors.purple,
                  ),
                  _ActionButton(
                    onPressed: () => _showPaymentMethodDialog(context, order, shouldPrint: true),
                    icon: Icons.print_outlined,
                    label: 'Print & Settle',
                    color: Colors.blue,
                  ),
                  _ActionButton(
                    onPressed: () => _showPaymentMethodDialog(context, order),
                    icon: Icons.check_circle_outline,
                    label: 'Mark Paid',
                    color: Colors.green,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 48),
          
          // Items List Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('ITEM DESCRIPTION', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                Expanded(child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                Expanded(child: Text('PRICE', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                Expanded(child: Text('TOTAL', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
              ],
            ),
          ),
          
          // Items List
          Expanded(
            child: ListView.builder(
              itemCount: order.items.length,
              itemBuilder: (context, index) {
                final item = order.items[index];
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text(item.itemName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500))),
                      Expanded(child: Text('x ${item.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18))),
                      Expanded(child: Text('₹${item.price}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 18))),
                      Expanded(child: Text('₹${(item.price * item.quantity).toStringAsFixed(2)}', 
                        textAlign: TextAlign.right, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Totals Section
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Builder(
              builder: (context) {
                final foodTotal = order.items.where((item) => item.itemType.toLowerCase() == 'food')
                    .fold(0.0, (sum, item) => sum + (item.price * item.quantity));
                final drinkTotal = order.items.where((item) => item.itemType.toLowerCase() == 'drink')
                    .fold(0.0, (sum, item) => sum + (item.price * item.quantity));
                
                final gstAmount = foodTotal * 0.05;
                final subtotal = foodTotal + drinkTotal;

                return Column(
                  children: [
                    _TotalRow(label: 'Subtotal', value: subtotal),
                    const SizedBox(height: 8),
                    _TotalRow(label: 'CGST (2.5%)', value: gstAmount / 2),
                    const SizedBox(height: 8),
                    _TotalRow(label: 'SGST (2.5%)', value: gstAmount / 2),
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Grand Total', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        Text('₹${(subtotal + gstAmount).toStringAsFixed(2)}', 
                          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.black)),
                      ],
                    ),
                  ],
                );
              }
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;

  const _InfoBadge({required this.label, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: (color ?? Colors.grey).withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color ?? Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color color;

  const _ActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double value;

  const _TotalRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, color: Colors.grey)),
        Text('₹${value.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
