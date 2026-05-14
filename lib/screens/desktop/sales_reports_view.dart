import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/restaurant_provider.dart';
import '../../models/order_model.dart';

class SalesReportsView extends StatefulWidget {
  const SalesReportsView({super.key});

  @override
  State<SalesReportsView> createState() => _SalesReportsViewState();
}

class _SalesReportsViewState extends State<SalesReportsView> {
  DateTimeRange _selectedRange = DateTimeRange(
    start: DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0),
    end: DateTime.now().copyWith(hour: 23, minute: 59, second: 59, millisecond: 999, microsecond: 999),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Filter
          _buildHeader(context),
          const SizedBox(height: 32),
          
          // Summary Cards
          _buildSummaryCards(context),
          const SizedBox(height: 32),
          
          // Table Section
          Expanded(
            child: _buildSalesTable(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final provider = context.read<RestaurantProvider>();
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sales History', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  '${DateFormat('dd MMM yyyy').format(_selectedRange.start)} - ${DateFormat('dd MMM yyyy').format(_selectedRange.end)}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _selectDateRange,
              icon: const Icon(Icons.date_range),
              label: const Text('Change Date Range'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: () => _exportReport(context),
              icon: const Icon(Icons.download),
              label: const Text('Export to CSV'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    return FutureBuilder<List<OrderModel>>(
      future: context.read<RestaurantProvider>().getCompletedOrders(
        start: _selectedRange.start,
        end: _selectedRange.end,
      ),
      builder: (context, snapshot) {
        final orders = snapshot.data ?? [];
        final totalRevenue = orders.fold(0.0, (sum, o) => sum + o.totalAmount);
        final totalOrders = orders.length;

        return Row(
          children: [
            _SummaryCard(
              title: 'Total Revenue',
              value: '₹${totalRevenue.toStringAsFixed(2)}',
              icon: Icons.account_balance_wallet,
              color: Colors.deepOrange,
            ),
            const SizedBox(width: 24),
            _SummaryCard(
              title: 'Total Orders',
              value: totalOrders.toString(),
              icon: Icons.receipt_long,
              color: Colors.blue,
            ),
            const SizedBox(width: 24),
            _SummaryCard(
              title: 'Average Order',
              value: totalOrders > 0 ? '₹${(totalRevenue / totalOrders).toStringAsFixed(2)}' : '₹0.00',
              icon: Icons.analytics,
              color: Colors.purple,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSalesTable(BuildContext context) {
    return FutureBuilder<List<OrderModel>>(
      future: context.read<RestaurantProvider>().getCompletedOrders(
        start: _selectedRange.start,
        end: _selectedRange.end,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data ?? [];
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
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SingleChildScrollView(
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                columnSpacing: 24,
                columns: const [
                  DataColumn(label: Text('TIME', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('TABLE / INFO', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('SOURCE', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('ITEMS', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('AMOUNT', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: orders.asMap().entries.map((entry) {
                  final index = entry.key;
                  final order = entry.value;
                  final isEven = index % 2 == 0;

                  return DataRow(
                    color: WidgetStateProperty.all(isEven ? Colors.white : Colors.grey.shade50),
                    cells: [
                      DataCell(Text(DateFormat('HH:mm, dd MMM').format(order.completedAt ?? order.createdAt))),
                      DataCell(Text(order.isParcel 
                        ? 'Parcel: ${order.customerInfo ?? "N/A"}' 
                        : (order.tableName ?? 'Table'))),
                      DataCell(_SourceBadge(source: order.orderSource)),
                      DataCell(Text('${order.items.length} items')),
                      DataCell(Text('₹${order.totalAmount.toStringAsFixed(2)}', 
                        style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('PAID', style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedRange,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.deepOrange,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedRange) {
      setState(() {
        _selectedRange = DateTimeRange(
          start: picked.start.copyWith(hour: 0, minute: 0, second: 0),
          end: picked.end.copyWith(hour: 23, minute: 59, second: 59),
        );
      });
    }
  }

  Future<void> _exportReport(BuildContext context) async {
    final provider = context.read<RestaurantProvider>();
    final orders = await provider.getCompletedOrders(
      start: _selectedRange.start,
      end: _selectedRange.end,
    );
    
    final path = await provider.exportSalesToCSV(orders);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report exported to: $path')),
      );
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
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
