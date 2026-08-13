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
  String? _selectedOrderId;
  int _detailsRefreshCounter = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RestaurantProvider>().fetchData();
    });
  }

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
              onPressed: () {
                context.read<RestaurantProvider>().fetchData();
                setState(() {
                  _detailsRefreshCounter++;
                });
              },
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
            SalesReportsView(key: ValueKey('SalesReport-$_detailsRefreshCounter')),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveOrdersView() {
    return Consumer<RestaurantProvider>(
      builder: (context, provider, child) {
        return StreamBuilder<List<OrderModel>>(
          key: ValueKey('Stream-$_detailsRefreshCounter'),
          stream: _service.watchActiveOrders(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final orders = snapshot.data ?? [];
            
            // Auto-clear selection if the selected order is no longer pending/active
            if (_selectedOrderId != null && !orders.any((o) => o.id == _selectedOrderId)) {
              _selectedOrderId = null;
            }

            return Row(
              children: [
                // Sidebar: List of Active Orders
                Container(
                  width: 320,
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
                        child: orders.isEmpty
                            ? _buildEmptyState('No active orders')
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: orders.length,
                                itemBuilder: (context, index) {
                                  final order = orders[index];
                                  final isSelected = _selectedOrderId == order.id;
                                  
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
                                      onTap: () {
                                        setState(() {
                                          _selectedOrderId = order.id;
                                        });
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                
                // Main View: Order Details & Billing
                Expanded(
                  child: _selectedOrderId == null
                      ? _buildEmptyState('Select an order to view details')
                      : FutureBuilder<OrderModel>(
                          key: ValueKey('$_selectedOrderId-$_detailsRefreshCounter-${orders.map((o) => "${o.totalAmount}-${o.discount}").join("-")}'),
                          future: _service.getOrderDetails(_selectedOrderId!),
                          builder: (context, detailsSnapshot) {
                            if (detailsSnapshot.hasError) {
                              print("ERROR FETCHING ORDER DETAILS: ${detailsSnapshot.error}");
                              return _buildEmptyState('Error loading details: ${detailsSnapshot.error}');
                            }
                            if (detailsSnapshot.connectionState == ConnectionState.waiting && !detailsSnapshot.hasData) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (!detailsSnapshot.hasData) {
                              return _buildEmptyState('Select an order to view details');
                            }
                            final detailedOrder = detailsSnapshot.data!;
                            print("DETAILED ORDER ID: ${detailedOrder.id}, ITEMS COUNT: ${detailedOrder.items.length}");
                            for (var item in detailedOrder.items) {
                              print("  - ITEM: ${item.itemName}, QTY: ${item.quantity}, PRICE: ${item.price}");
                            }
                            return _OrderDetailsView(
                              order: detailedOrder,
                               onStatusUpdate: () {
                                 setState(() {
                                   _selectedOrderId = null;
                                   _detailsRefreshCounter++;
                                 });
                               },
                              onRefresh: () {
                                setState(() {
                                  _detailsRefreshCounter++;
                                });
                              },
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tableName, 
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                      if (order.billNo != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Text(
                            'BILL PENDING',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
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
  final VoidCallback? onRefresh;

  const _OrderDetailsView({
    required this.order, 
    required this.onStatusUpdate,
    this.onRefresh,
  });

  Future<void> _safePrint(BuildContext context, Future<void> Function() printFn) async {
    try {
      await printFn();
    } catch (e) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Printing Failed'),
            content: Text('Could not complete printing: $e\n\nPlease ensure your printer is connected, configured, and turned on.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showDiscountDialog(BuildContext context, OrderModel order) {
    final controller = TextEditingController(
      text: order.discount > 0 ? order.discount.toStringAsFixed(0) : '',
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Discount (%)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter discount percentage (e.g. 10 for 10% discount):'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Discount Percentage',
                suffixText: '%',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await SupabaseService().updateOrderDiscount(order.id, 0.0);
              if (context.mounted) {
                context.read<RestaurantProvider>().fetchData();
                Navigator.pop(context);
              }
            },
            child: const Text('Remove Discount', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              final double discount = double.tryParse(controller.text) ?? 0.0;
              if (discount < 0 || discount > 100) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a value between 0 and 100')),
                );
                return;
              }
              await SupabaseService().updateOrderDiscount(order.id, discount);
              if (context.mounted) {
                context.read<RestaurantProvider>().fetchData();
                Navigator.pop(context);
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showEditOrderDialog(BuildContext context, OrderModel order) {
    showDialog(
      context: context,
      builder: (context) => _EditOrderDialog(
        order: order,
        onStatusUpdate: onRefresh ?? () {},
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
              if (shouldPrint) {
                try {
                  await BillingService.printInvoice(order, context: context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Settle succeeded but print failed: $e. Check printer connection.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                }
              }
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
              if (shouldPrint) {
                try {
                  await BillingService.printInvoice(order, context: context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Settle succeeded but print failed: $e. Check printer connection.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                }
              }
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
    final provider = context.watch<RestaurantProvider>();

    // Friendly Table Name Lookup
    String displayTableName = 'Table Order';
    if (order.isParcel) {
      displayTableName = "Parcel: ${order.customerInfo ?? 'Takeaway'}";
    } else {
      final table = provider.tables.firstWhere(
        (t) => t.id == order.tableId,
        orElse: () => RestaurantTable(id: '', name: 'Table Order', status: ''),
      );
      displayTableName = table.name == 'Table Order' ? 'Table ${order.tableId?.substring(0,4) ?? "Unk"}' : table.name;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(48.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Detailed Header
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(displayTableName, 
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _InfoBadge(label: 'Order ID: ${order.id.substring(0,8)}', icon: Icons.tag),
                  _InfoBadge(label: 'Placed: ${DateFormat('hh:mm a').format(order.createdAt)}', icon: Icons.schedule),
                  _InfoBadge(
                    label: order.orderSource.toUpperCase(), 
                    icon: order.isCustomerOrder ? Icons.phone_android : Icons.person,
                    color: order.isCustomerOrder ? Colors.blue : Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 24),
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
                    onPressed: () => _showDiscountDialog(context, order),
                    icon: Icons.percent,
                    label: 'Add Discount',
                    color: Colors.purple,
                  ),
                  _ActionButton(
                    onPressed: () => _safePrint(context, () => BillingService.printKotAndBot(order, context: context, onPrintComplete: onRefresh)),
                    icon: Icons.receipt_long,
                    label: 'Print KOT & BOT',
                    color: Colors.brown,
                  ),
                  _ActionButton(
                    onPressed: () => BillingService.showPrintOptionsDialog(context, order, onPrintComplete: onRefresh),
                    icon: Icons.print,
                    label: 'Print Bill',
                    color: Colors.teal,
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
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
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
          const SizedBox(height: 32),
          
          // Totals Section
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Builder(
              builder: (context) {
                final taxableTotal = order.items.where((item) {
                    final type = item.itemType.toLowerCase();
                    return type == 'food' || type == 'cocktail' || type == 'mocktail';
                  }).fold(0.0, (sum, item) => sum + (item.price * item.quantity));
                  
                final nonTaxableTotal = order.items.where((item) => item.itemType.toLowerCase() == 'drink')
                    .fold(0.0, (sum, item) => sum + (item.price * item.quantity));
                
                final gstAmount = taxableTotal * 0.05;
                final subtotal = taxableTotal + nonTaxableTotal;
                final total = subtotal + gstAmount;
                final discountPercent = order.discount;
                final discountAmount = total * (discountPercent / 100);
                final finalTotal = total - discountAmount;

                return Column(
                  children: [
                    _TotalRow(label: 'Subtotal', value: subtotal),
                    const SizedBox(height: 8),
                    _TotalRow(label: 'CGST (2.5%)', value: gstAmount / 2),
                    const SizedBox(height: 8),
                    _TotalRow(label: 'SGST (2.5%)', value: gstAmount / 2),
                    if (discountPercent > 0) ...[
                      const SizedBox(height: 8),
                      _TotalRow(label: 'Total after Tax', value: total),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Discount (${discountPercent.toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 16, color: Colors.purple, fontWeight: FontWeight.w500)),
                          Text('-₹${discountAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.purple)),
                        ],
                      ),
                    ],
                    const Divider(height: 32),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('Grand Total', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        Text('₹${finalTotal.toStringAsFixed(2)}', 
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black)),
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
          Flexible(
            child: Text(
              label, 
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color ?? Colors.grey.shade600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
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

class _EditOrderDialog extends StatefulWidget {
  final OrderModel order;
  final VoidCallback onStatusUpdate;

  const _EditOrderDialog({
    required this.order,
    required this.onStatusUpdate,
  });

  @override
  State<_EditOrderDialog> createState() => _EditOrderDialogState();
}

class _EditOrderDialogState extends State<_EditOrderDialog> {
  List<Map<String, dynamic>> _editedItems = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSaving = false;
  bool _isLoadingItems = true;

  @override
  void initState() {
    super.initState();
    _loadLatestItems();
  }

  Future<void> _loadLatestItems() async {
    try {
      final latestOrder = await SupabaseService().getOrderDetails(widget.order.id);
      if (mounted) {
        setState(() {
          _editedItems = latestOrder.items.map((item) => <String, dynamic>{
            'menu_item_id': item.menuItemId,
            'quantity': item.quantity,
            'printed_quantity': item.printedQuantity,
            'price': item.price,
            'name': item.itemName,
            'item_type': item.itemType,
            'instructions': item.instructions ?? '',
          }).toList();
          _isLoadingItems = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading latest items for edit order: $e");
      if (mounted) {
        setState(() {
          _editedItems = widget.order.items.map((item) => <String, dynamic>{
            'menu_item_id': item.menuItemId,
            'quantity': item.quantity,
            'printed_quantity': item.printedQuantity,
            'price': item.price,
            'name': item.itemName,
            'item_type': item.itemType,
            'instructions': item.instructions ?? '',
          }).toList();
          _isLoadingItems = false;
        });
      }
    }
  }

  Map<String, double> _calculateTotals() {
    double subtotal = 0;
    double gstAmount = 0;
    
    for (var item in _editedItems) {
      double itemPrice = (item['price'] as num).toDouble();
      final type = (item['item_type'] as String).toLowerCase();
      final qty = (item['quantity'] as num).toInt();
      
      final linePrice = itemPrice * qty;
      subtotal += linePrice;
      
      if (type == 'food' || type == 'cocktail' || type == 'mocktail') {
        gstAmount += linePrice * 0.05;
      }
    }
    
    final totalBeforeDiscount = subtotal + gstAmount;
    final discountPercent = widget.order.discount;
    final discountAmount = totalBeforeDiscount * (discountPercent / 100);
    final finalTotal = totalBeforeDiscount - discountAmount;
    
    return {
      'subtotal': subtotal,
      'gst': gstAmount,
      'discount': discountAmount,
      'finalTotal': finalTotal,
    };
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();
    final menuItems = provider.menuItems;

    final searchResults = _searchQuery.isEmpty
        ? <MenuItem>[]
        : menuItems.where((item) =>
            item.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return AlertDialog(
      title: Text('Edit Order #${widget.order.id.substring(0, 8)}'),
      content: SizedBox(
        width: 600,
        height: 450,
        child: _isLoadingItems
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.deepOrange),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
            // Search Input
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search items by name...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
            
            // Search Results
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: searchResults.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: Text('No matching items found', style: TextStyle(color: Colors.grey))),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final item = searchResults[index];
                          return ListTile(
                            dense: true,
                            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('₹${item.price} • ${item.itemType}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle, color: Colors.deepOrange),
                              onPressed: () {
                                setState(() {
                                  final existingIndex = _editedItems.indexWhere((i) => i['menu_item_id'] == item.id);
                                  if (existingIndex >= 0) {
                                    _editedItems[existingIndex]['quantity'] += 1;
                                  } else {
                                    _editedItems.add(<String, dynamic>{
                                      'menu_item_id': item.id,
                                      'quantity': 1,
                                      'printed_quantity': 0,
                                      'price': item.price,
                                      'name': item.name,
                                      'item_type': item.itemType,
                                      'instructions': '',
                                    });
                                  }
                                  // Clear search query after adding
                                  _searchQuery = '';
                                  _searchController.clear();
                                });
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Items List
            Expanded(
              child: _editedItems.isEmpty
                  ? const Center(child: Text('No items in this order.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _editedItems.length,
                      itemBuilder: (context, index) {
                        final item = _editedItems[index];
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
                                      _editedItems.removeAt(index);
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
                                    _editedItems.removeAt(index);
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Builder(
                builder: (context) {
                  final totals = _calculateTotals();
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Items: ${_editedItems.fold(0, (sum, item) => sum + (item['quantity'] as num).toInt())}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (widget.order.discount > 0) ...[
                            Text(
                              'Subtotal (with tax): ₹${(totals['subtotal']! + totals['gst']!).toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                            Text(
                              'Discount (${widget.order.discount.toStringAsFixed(0)}%): -₹${totals['discount']!.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.purple, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                          Text(
                            'Grand Total: ₹${totals['finalTotal']!.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                          ),
                        ],
                      ),
                    ],
                  );
                }
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving
              ? null
              : () async {
                  setState(() => _isSaving = true);
                  try {
                    double newTotal = 0;
                    final itemsToSave = _editedItems.map((item) {
                      double itemPrice = (item['price'] as num).toDouble();
                      final type = (item['item_type'] as String).toLowerCase();
                      if (type == 'food' || type == 'cocktail' || type == 'mocktail') {
                        itemPrice *= 1.05;
                      }
                      newTotal += itemPrice * (item['quantity'] as num).toInt();
                      
                      final int newQty = (item['quantity'] as num).toInt();
                      final int origPrinted = (item['printed_quantity'] as num?)?.toInt() ?? 0;
                      final int finalPrinted = origPrinted > newQty ? newQty : origPrinted;

                      return {
                        'order_id': widget.order.id,
                        'menu_item_id': item['menu_item_id'],
                        'quantity': newQty,
                        'printed_quantity': finalPrinted,
                        'price': item['price'],
                        'instructions': item['instructions'] ?? '',
                      };
                    }).toList();

                    await SupabaseService().updateOrderItems(widget.order.id, itemsToSave, newTotal);
                    provider.fetchData();
                    if (context.mounted) Navigator.pop(context);
                    widget.onStatusUpdate();
                  } finally {
                    if (context.mounted) setState(() => _isSaving = false);
                  }
                },
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}

