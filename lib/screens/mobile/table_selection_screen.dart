import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/restaurant_provider.dart';
import '../../services/supabase_service.dart';
import '../../models/table_model.dart';
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

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MenuScreen(table: table),
                    ),
                  );
                },
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
                      Text(
                        isOccupied ? 'Occupied' : 'Available',
                        style: TextStyle(
                          color: isOccupied ? Colors.orange.shade700 : Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
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
