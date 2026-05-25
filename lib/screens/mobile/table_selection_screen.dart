import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/restaurant_provider.dart';
import '../../services/supabase_service.dart';
import '../../models/table_model.dart';
import '../../models/order_model.dart';
import 'menu_screen.dart';

class TableSelectionScreen extends StatefulWidget {
  const TableSelectionScreen({super.key});

  @override
  State<TableSelectionScreen> createState() => _TableSelectionScreenState();
}

class _TableSelectionScreenState extends State<TableSelectionScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<RestaurantProvider>().fetchData());
  }

  void _showAddTableDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Table'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Table Name (e.g., 1.1 or 10)'),
          keyboardType: TextInputType.text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                try {
                  await SupabaseService().addTable(name);
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding table: $e')),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showDeleteTableConfirmation(BuildContext context, RestaurantTable table) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Table?'),
        content: Text('Are you sure you want to delete "${table.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await SupabaseService().deleteTable(table.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Table "${table.name}" deleted successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete table: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showCustomerNameDialog(BuildContext context, RestaurantTable table) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Customer Name - ${table.name}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter customer name (optional)',
            prefixIcon: Icon(Icons.person),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MenuScreen(table: table),
                ),
              );
            },
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MenuScreen(
                    table: table,
                    customerName: name.isNotEmpty ? name : null,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Table'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<RestaurantTable>>(
        stream: SupabaseService().watchTables(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final tables = snapshot.data ?? [];
          tables.sort((a, b) {
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

          if (tables.isEmpty) {
            return const Center(child: Text('No tables found. Check Supabase connection.'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            itemCount: tables.length,
            itemBuilder: (context, index) {
              final table = tables[index];
              final isOccupied = table.status == 'occupied';

              return Stack(
                children: [
                  InkWell(
                    onTap: () {
                      if (isOccupied) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MenuScreen(table: table),
                          ),
                        );
                      } else {
                        _showCustomerNameDialog(context, table);
                      }
                    },
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: Card(
                        color: isOccupied ? Colors.orange.shade100 : Colors.green.shade100,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.restaurant,
                              size: 40,
                              color: isOccupied ? Colors.orange.shade800 : Colors.green.shade800,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              table.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isOccupied ? Colors.orange.shade900 : Colors.green.shade900,
                              ),
                            ),
                            if (isOccupied)
                              StreamBuilder<OrderModel?>(
                                stream: SupabaseService().watchActiveOrderForTable(table.id),
                                builder: (context, orderSnapshot) {
                                  if (orderSnapshot.hasData && orderSnapshot.data?.customerInfo != null && orderSnapshot.data!.customerInfo!.isNotEmpty) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        orderSnapshot.data!.customerInfo!,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade800,
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            Text(
                              isOccupied ? 'Occupied' : 'Available',
                              style: TextStyle(
                                color: isOccupied ? Colors.orange.shade700 : Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _showDeleteTableConfirmation(context, table),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTableDialog(context),
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }
}
