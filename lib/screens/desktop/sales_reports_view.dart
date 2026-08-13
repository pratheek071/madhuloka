import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/restaurant_provider.dart';
import '../../models/order_model.dart';
import 'billing_service.dart';

class SalesReportsView extends StatefulWidget {
  const SalesReportsView({super.key});

  @override
  State<SalesReportsView> createState() => _SalesReportsViewState();
}

class _SalesReportsViewState extends State<SalesReportsView> with AutomaticKeepAliveClientMixin {
  DateTimeRange _selectedRange = DateTimeRange(
    start: DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0),
    end: DateTime.now().copyWith(hour: 23, minute: 59, second: 59, millisecond: 999, microsecond: 999),
  );
  String _paymentFilter = 'All';
  late Future<List<OrderModel>> _ordersFuture;
  TabController? _tabController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newController = DefaultTabController.of(context);
    if (newController != _tabController) {
      _tabController?.removeListener(_handleTabSelection);
      _tabController = newController;
      _tabController?.addListener(_handleTabSelection);
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_handleTabSelection);
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController != null && _tabController!.index == 5) {
      if (!_tabController!.indexIsChanging) {
        setState(() {
          _fetchOrders();
        });
      }
    }
  }

  void _fetchOrders() {
    _ordersFuture = context.read<RestaurantProvider>().getCompletedOrders(
      start: _selectedRange.start,
      end: _selectedRange.end,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<OrderModel>>(
      future: _ordersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allOrders = snapshot.data ?? [];
        final filteredOrders = allOrders.where((order) {
          if (_paymentFilter == 'All') return true;
          return order.paymentMethod?.toLowerCase() == _paymentFilter.toLowerCase();
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Filter
              _buildHeader(context),
              const SizedBox(height: 12),
              _buildQuickFilters(context),
              const SizedBox(height: 16),
              
              // Summary Cards
              _buildSummaryCards(filteredOrders),
              const SizedBox(height: 16),
              
              // Table and Item Breakdown
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildSalesTable(filteredOrders)),
                    const SizedBox(width: 20),
                    Expanded(child: _buildItemBreakdown(filteredOrders)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sales History', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  '${DateFormat('dd MMM yyyy').format(_selectedRange.start)} - ${DateFormat('dd MMM yyyy').format(_selectedRange.end)}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'All',
                  icon: Icon(Icons.all_inclusive, size: 14),
                  label: Text('All'),
                ),
                ButtonSegment<String>(
                  value: 'Cash',
                  icon: Icon(Icons.money, size: 14),
                  label: Text('Cash'),
                ),
                ButtonSegment<String>(
                  value: 'Online',
                  icon: Icon(Icons.payment, size: 14),
                  label: Text('Online'),
                ),
              ],
              selected: {_paymentFilter},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _paymentFilter = newSelection.first;
                });
              },
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: Colors.deepOrange,
                selectedForegroundColor: Colors.white,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _selectDateRange,
              icon: const Icon(Icons.date_range, size: 16),
              label: const Text('Change Date'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _exportReport(context),
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Export CSV'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _exportReportPDF(context),
              icon: const Icon(Icons.picture_as_pdf, size: 16),
              label: const Text('Summary PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _downloadAllSplitBillsPDF(context),
              icon: const Icon(Icons.receipt_long, size: 16),
              label: const Text('All Bills (Split PDF)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickFilters(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _QuickFilterButton(
            label: 'Today',
            onTap: () => _updateRange(
              DateTime.now().copyWith(hour: 0, minute: 0, second: 0),
              DateTime.now().copyWith(hour: 23, minute: 59, second: 59),
            ),
          ),
          _QuickFilterButton(
            label: 'Yesterday',
            onTap: () {
              final yesterday = DateTime.now().subtract(const Duration(days: 1));
              _updateRange(
                yesterday.copyWith(hour: 0, minute: 0, second: 0),
                yesterday.copyWith(hour: 23, minute: 59, second: 59),
              );
            },
          ),
          _QuickFilterButton(
            label: 'This Week',
            onTap: () {
              final now = DateTime.now();
              final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
              _updateRange(
                startOfWeek.copyWith(hour: 0, minute: 0, second: 0),
                now.copyWith(hour: 23, minute: 59, second: 59),
              );
            },
          ),
          _QuickFilterButton(
            label: 'This Month',
            onTap: () {
              final now = DateTime.now();
              _updateRange(
                DateTime(now.year, now.month, 1),
                now.copyWith(hour: 23, minute: 59, second: 59),
              );
            },
          ),
          _QuickFilterButton(
            label: 'Last Month',
            onTap: () {
              final now = DateTime.now();
              final firstOfLastMonth = DateTime(now.year, now.month - 1, 1);
              final lastOfLastMonth = DateTime(now.year, now.month, 0, 23, 59, 59);
              _updateRange(firstOfLastMonth, lastOfLastMonth);
            },
          ),
          _QuickFilterButton(
            label: 'This Year',
            onTap: () {
              final now = DateTime.now();
              _updateRange(
                DateTime(now.year, 1, 1),
                now.copyWith(hour: 23, minute: 59, second: 59),
              );
            },
          ),
        ],
      ),
    );
  }

  void _updateRange(DateTime start, DateTime end) {
    setState(() {
      _selectedRange = DateTimeRange(start: start, end: end);
      _fetchOrders();
    });
  }

  Widget _buildSummaryCards(List<OrderModel> orders) {
    final totalRevenue = orders.fold(0.0, (sum, o) => sum + o.finalAmount);
    final totalOrders = orders.length;
    final totalItems = orders.fold(0, (sum, o) => sum + o.items.fold(0, (isum, i) => isum + i.quantity));
    final averageOrder = totalOrders > 0 ? (totalRevenue / totalOrders) : 0.0;

    // Discount Analytics
    final totalDiscounts = orders.fold(0.0, (sum, o) => sum + o.discountAmount);
    final discountedOrdersCount = orders.where((o) => o.discount > 0).length;
    final avgDiscountPercent = discountedOrdersCount > 0 
        ? orders.where((o) => o.discount > 0).fold(0.0, (sum, o) => sum + o.discount) / discountedOrdersCount
        : 0.0;

    return Row(
      children: [
        _SummaryCard(
          title: 'Total Revenue',
          value: '₹${totalRevenue.toStringAsFixed(2)}',
          icon: Icons.account_balance_wallet,
          color: Colors.deepOrange,
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          title: 'Total Orders',
          value: totalOrders.toString(),
          icon: Icons.receipt_long,
          color: Colors.blue,
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          title: 'Discounts Given',
          value: '₹${totalDiscounts.toStringAsFixed(2)}',
          icon: Icons.percent,
          color: Colors.purple,
          subtitle: '${discountedOrdersCount} orders • ${avgDiscountPercent.toStringAsFixed(1)}% avg',
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          title: 'Items Sold',
          value: totalItems.toString(),
          icon: Icons.inventory_2,
          color: Colors.teal,
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          title: 'Average Order',
          value: '₹${averageOrder.toStringAsFixed(2)}',
          icon: Icons.analytics,
          color: Colors.indigo,
        ),
      ],
    );
  }

  Widget _buildSalesTable(List<OrderModel> orders) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('No sales found for this period.', style: TextStyle(color: Colors.grey, fontSize: 18)),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 64,
                    headingRowHeight: 48,
                    headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                    columnSpacing: 20,
                    horizontalMargin: 16,
                    columns: const [
                      DataColumn(label: Text('BILL NO', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('TIME', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('TABLE / INFO', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('SOURCE', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('ITEMS', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('DISCOUNT', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('AMOUNT', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('PAYMENT', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('DETAILS', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
            rows: orders.asMap().entries.map((entry) {
              final index = entry.key;
              final order = entry.value;
              final isEven = index % 2 == 0;

              return DataRow(
                color: WidgetStateProperty.all(isEven ? Colors.white : Colors.grey.shade50),
                cells: [
                  DataCell(Text(order.billNo != null 
                    ? 'REG-${order.billNo.toString().padLeft(4, '0')}' 
                    : 'N/A', 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey))),
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('hh:mm a').format(order.completedAt ?? order.createdAt),
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('dd MMM yyyy').format(order.completedAt ?? order.createdAt),
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  DataCell(Text(order.isParcel 
                    ? 'Parcel: ${order.customerInfo ?? "N/A"}' 
                    : (order.tableName ?? 'Table'))),
                  DataCell(_SourceBadge(source: order.orderSource)),
                  DataCell(Text('${order.items.length} items')),
                  DataCell(Text('₹${order.discountAmount.toStringAsFixed(2)}', 
                    style: const TextStyle(color: Colors.red))),
                  DataCell(Text('₹${order.finalAmount.toStringAsFixed(2)}', 
                    style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(
                    PopupMenuButton<String>(
                      tooltip: 'Change Payment Method',
                      onSelected: (String newMethod) async {
                        if (order.paymentMethod?.toLowerCase() != newMethod.toLowerCase()) {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Change Payment Method'),
                              content: Text(
                                'Are you sure you want to change the payment method of bill '
                                '${order.billNo != null ? "REG-${order.billNo.toString().padLeft(4, '0')}" : "N/A"} '
                                'from ${order.paymentMethod ?? "PAID"} to ${newMethod.toUpperCase()}?'
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepOrange,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Confirm'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Updating payment method...')),
                            );
                            try {
                              await context.read<RestaurantProvider>().updateOrderPaymentMethod(order.id, newMethod);
                              
                              if (!mounted) return;
                              _fetchOrders();
                              setState(() {});

                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Payment method updated successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to update payment method: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'cash',
                          child: Row(
                            children: [
                              Icon(Icons.money, color: Colors.green, size: 18),
                              SizedBox(width: 8),
                              Text('Cash'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'online',
                          child: Row(
                            children: [
                              Icon(Icons.payment, color: Colors.blue, size: 18),
                              SizedBox(width: 8),
                              Text('Online'),
                            ],
                          ),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (order.paymentMethod?.toLowerCase() == 'online') ? Colors.blue.shade50 : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300, width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              (order.paymentMethod ?? 'PAID').toUpperCase(), 
                              style: TextStyle(
                                color: (order.paymentMethod?.toLowerCase() == 'online') ? Colors.blue.shade700 : Colors.green.shade700, 
                                fontSize: 12, 
                                fontWeight: FontWeight.bold
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_drop_down,
                              size: 14,
                              color: (order.paymentMethod?.toLowerCase() == 'online') ? Colors.blue.shade700 : Colors.green.shade700,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  DataCell(IconButton(
                    icon: const Icon(Icons.visibility, color: Colors.deepOrange),
                    onPressed: () => _showOrderDetailsDialog(context, order),
                  )),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  },
),
),
);
  }

  Widget _buildItemBreakdown(List<OrderModel> orders) {
    final Map<String, int> itemCounts = {};
    
    for (var order in orders) {
      for (var item in order.items) {
        itemCounts[item.itemName] = (itemCounts[item.itemName] ?? 0) + item.quantity;
      }
    }
    
    final sortedItems = itemCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Best Selling Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                ElevatedButton.icon(
                  onPressed: sortedItems.isEmpty 
                      ? null 
                      : () => BillingService.printBestSellingItemsReport(
                            _selectedRange.start,
                            _selectedRange.end,
                            sortedItems,
                            context: context,
                          ),
                  icon: const Icon(Icons.print, size: 16),
                  label: const Text('Print Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: sortedItems.isEmpty 
              ? const Center(child: Text('No data'))
              : ListView.separated(
                  padding: const EdgeInsets.all(0),
                  itemCount: sortedItems.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = sortedItems[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: Colors.deepOrange.withOpacity(0.1),
                        child: Text('${index + 1}', style: const TextStyle(color: Colors.deepOrange, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(item.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${item.value} sold', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

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

  void _showOrderDetailsDialog(BuildContext context, OrderModel order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(order.isParcel ? 'Parcel Details' : 'Table: ${order.tableName}'),
            Text(DateFormat('dd MMM, hh:mm a').format(order.completedAt ?? order.createdAt), 
                 style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(),
              ...order.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w500))),
                    Expanded(child: Text('x${item.quantity}', textAlign: TextAlign.center)),
                    Expanded(child: Text('₹${item.price}', textAlign: TextAlign.right)),
                    Expanded(child: Text('₹${(item.price * item.quantity).toStringAsFixed(2)}', 
                             textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
              )),
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Payment Method:', style: TextStyle(color: Colors.grey)),
                  Text((order.paymentMethod ?? 'Cash').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              if (order.discount > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal:', style: TextStyle(color: Colors.grey)),
                    Text('₹${order.totalAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Discount (${order.discount.toStringAsFixed(0)}%):', style: const TextStyle(color: Colors.red)),
                    Text('-₹${order.discountAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('₹${order.finalAmount.toStringAsFixed(2)}', 
                       style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _safePrint(context, () => BillingService.printKotAndBot(order, context: context, forcePrintAll: true)),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Print KOT & BOT'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.brown,
                    side: const BorderSide(color: Colors.brown),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => BillingService.showPrintOptionsDialog(context, order),
                  icon: const Icon(Icons.print),
                  label: const Text('Print Bill'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

  Future<void> _selectDateRange() async {
    final startController = TextEditingController(
      text: DateFormat('dd/MM/yyyy').format(_selectedRange.start),
    );
    final endController = TextEditingController(
      text: DateFormat('dd/MM/yyyy').format(_selectedRange.end),
    );

    final formKey = GlobalKey<FormState>();

    DateTime? parseDate(String value) {
      try {
        final parts = value.split('/');
        if (parts.length != 3) return null;
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);
        if (day == null || month == null || year == null) return null;
        final date = DateTime(year, month, day);
        if (date.year != year || date.month != month || date.day != day) return null;
        return date;
      } catch (_) {
        return null;
      }
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E), // Match Slate dark theme
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Enter Date Range',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange.shade100,
                ),
              ),
              content: SizedBox(
                width: 400,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Format: DD/MM/YYYY',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: startController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Start Date',
                                labelStyle: const TextStyle(color: Colors.grey),
                                border: const OutlineInputBorder(),
                                enabledBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.grey),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.deepOrange),
                                ),
                                errorStyle: const TextStyle(color: Colors.redAccent),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.calendar_today, size: 20, color: Colors.deepOrange),
                                  onPressed: () async {
                                    final currentVal = parseDate(startController.text) ?? DateTime.now();
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: currentVal,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme: const ColorScheme.dark(
                                              primary: Colors.deepOrange,
                                              onPrimary: Colors.white,
                                              surface: Color(0xFF1E1E1E),
                                              onSurface: Colors.white,
                                            ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (picked != null) {
                                      setDialogState(() {
                                        startController.text = DateFormat('dd/MM/yyyy').format(picked);
                                      });
                                    }
                                  },
                                ),
                              ),
                              keyboardType: TextInputType.datetime,
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Required';
                                }
                                if (parseDate(val) == null) {
                                  return 'Use DD/MM/YYYY';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: endController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'End Date',
                                labelStyle: const TextStyle(color: Colors.grey),
                                border: const OutlineInputBorder(),
                                enabledBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.grey),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.deepOrange),
                                ),
                                errorStyle: const TextStyle(color: Colors.redAccent),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.calendar_today, size: 20, color: Colors.deepOrange),
                                  onPressed: () async {
                                    final currentVal = parseDate(endController.text) ?? DateTime.now();
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: currentVal,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme: const ColorScheme.dark(
                                              primary: Colors.deepOrange,
                                              onPrimary: Colors.white,
                                              surface: Color(0xFF1E1E1E),
                                              onSurface: Colors.white,
                                            ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (picked != null) {
                                      setDialogState(() {
                                        endController.text = DateFormat('dd/MM/yyyy').format(picked);
                                      });
                                    }
                                  },
                                ),
                              ),
                              keyboardType: TextInputType.datetime,
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Required';
                                }
                                final endD = parseDate(val);
                                if (endD == null) {
                                  return 'Use DD/MM/YYYY';
                                }
                                final startD = parseDate(startController.text);
                                if (startD != null && endD.isBefore(startD)) {
                                  return 'End before Start';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      final startD = parseDate(startController.text)!;
                      final endD = parseDate(endController.text)!;
                      setState(() {
                        _selectedRange = DateTimeRange(
                          start: startD.copyWith(hour: 0, minute: 0, second: 0),
                          end: endD.copyWith(hour: 23, minute: 59, second: 59),
                        );
                        _fetchOrders();
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportReport(BuildContext context) async {
    final provider = context.read<RestaurantProvider>();
    final orders = await provider.getCompletedOrders(
      start: _selectedRange.start,
      end: _selectedRange.end,
    );
    
    final filteredOrders = orders.where((order) {
      if (_paymentFilter == 'All') return true;
      return order.paymentMethod?.toLowerCase() == _paymentFilter.toLowerCase();
    }).toList();
    
    final path = await provider.exportSalesToCSV(filteredOrders);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report exported to: $path')),
      );
    }
  }

  Future<void> _exportReportPDF(BuildContext context) async {
    final provider = context.read<RestaurantProvider>();
    final orders = await provider.getCompletedOrders(
      start: _selectedRange.start,
      end: _selectedRange.end,
    );
    
    final filteredOrders = orders.where((order) {
      if (_paymentFilter == 'All') return true;
      return order.paymentMethod?.toLowerCase() == _paymentFilter.toLowerCase();
    }).toList();
    
    if (context.mounted) {
      try {
        final path = await BillingService.saveSalesReport(
          _selectedRange.start,
          _selectedRange.end,
          filteredOrders,
          _paymentFilter,
        );
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Report saved and opened: $path'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save PDF: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _downloadAllSplitBillsPDF(BuildContext context) async {
    final provider = context.read<RestaurantProvider>();
    final orders = await provider.getCompletedOrders(
      start: _selectedRange.start,
      end: _selectedRange.end,
    );
    
    final filteredOrders = orders.where((order) {
      if (_paymentFilter == 'All') return true;
      return order.paymentMethod?.toLowerCase() == _paymentFilter.toLowerCase();
    }).toList();

    if (filteredOrders.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No orders found for the selected date range and filter.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      try {
        final path = await BillingService.saveAllSplitBillsPdf(
          _selectedRange.start,
          _selectedRange.end,
          filteredOrders,
          _paymentFilter,
        );
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('All split bills saved and opened: $path'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to download split bills PDF: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: TextStyle(color: Colors.grey.shade500, fontSize: 10), overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final String source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final isCustomer = source == 'customer';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isCustomer ? Colors.blue.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isCustomer ? Colors.blue.shade100 : Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isCustomer ? Icons.phone_android : Icons.person, 
               size: 12, color: isCustomer ? Colors.blue.shade700 : Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            isCustomer ? 'WEB' : 'WAITER',
            style: TextStyle(
              fontSize: 10, 
              fontWeight: FontWeight.bold, 
              color: isCustomer ? Colors.blue.shade700 : Colors.grey.shade700
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickFilterButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickFilterButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ActionChip(
        label: Text(label),
        onPressed: onTap,
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey.shade200),
        ),
      ),
    );
  }
}
