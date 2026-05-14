import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/restaurant_provider.dart';

class MenuManagementView extends StatelessWidget {
  const MenuManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();

    return Row(
      children: [
        // Categories Sidebar
        SizedBox(
          width: 250,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: () => _showCategoryDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Category'),
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: provider.categories.length,
                  itemBuilder: (context, index) {
                    final category = provider.categories[index];
                    return ListTile(
                      title: Text(category.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _showCategoryDialog(context, category: category),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                            onPressed: () => provider.deleteCategory(category.id),
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
        const VerticalDivider(width: 1),
        // Menu Items Main View
        Expanded(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('All Menu Items', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    ElevatedButton.icon(
                      onPressed: provider.categories.isEmpty 
                        ? null 
                        : () => _showMenuItemDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add New Item'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.menuItems.length,
                  itemBuilder: (context, index) {
                    final item = provider.menuItems[index];
                    final category = provider.categories.firstWhere((c) => c.id == item.categoryId, orElse: () => throw Exception('Category not found'));

                    return Card(
                      child: ListTile(
                        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Category: ${category.name}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('₹${item.price}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showMenuItemDialog(context, item: item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => provider.deleteMenuItem(item.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCategoryDialog(BuildContext context, {dynamic category}) {
    final nameController = TextEditingController(text: category?.name ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(category == null ? 'Add Category' : 'Edit Category'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Category Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (category == null) {
                context.read<RestaurantProvider>().addCategory(nameController.text);
              } else {
                context.read<RestaurantProvider>().updateCategory(category.id, nameController.text);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showMenuItemDialog(BuildContext context, {dynamic item}) {
    final provider = context.read<RestaurantProvider>();
    final nameController = TextEditingController(text: item?.name ?? '');
    final priceController = TextEditingController(text: item?.price.toString() ?? '');
    String? selectedCategoryId = item?.categoryId ?? provider.categories.first.id;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(item == null ? 'Add Menu Item' : 'Edit Menu Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedCategoryId,
                items: provider.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                onChanged: (val) => setState(() => selectedCategoryId = val),
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Item Name'),
              ),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (item == null) {
                  provider.addMenuItem(selectedCategoryId!, nameController.text, double.parse(priceController.text));
                } else {
                  provider.updateMenuItem(item.id, selectedCategoryId!, nameController.text, double.parse(priceController.text));
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
