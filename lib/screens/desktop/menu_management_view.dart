import 'package:flutter/material.dart';
import 'package:provider/provider';
import '../../providers/restaurant_provider.dart';
import '../../models/category_model.dart';

class MenuManagementView extends StatefulWidget {
  const MenuManagementView({super.key});

  @override
  State<MenuManagementView> createState() => _MenuManagementViewState();
}

class _MenuManagementViewState extends State<MenuManagementView> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();

    final filteredMenuItems = provider.menuItems.where((item) {
      return item.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Row(
      children: [
        // Categories Sidebar
        SizedBox(
          width: 250,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: () => _showCategoryDialog(context),
                  child: const Text('Add Category'),
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
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () => _showCategoryDialog(context, category: category),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                            onPressed: () => _showDeleteConfirmation(
                              context, 
                              title: 'Delete Category?',
                              message: 'Are you sure you want to delete "${category.name}"? This will remove all items in this category.',
                              onConfirm: () => provider.deleteCategory(category.id),
                            ),
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
                    ElevatedButton(
                      onPressed: provider.categories.isEmpty 
                        ? null 
                        : () => _showMenuItemDialog(context),
                      child: const Text('Add New Item'),
                    ),
                  ],
                ),
              ),
              
              // Search Input Field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search menu items...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
              ),

              Expanded(
                child: filteredMenuItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const Text('No items match your search', style: TextStyle(color: Colors.grey, fontSize: 18)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredMenuItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredMenuItems[index];
                        final category = provider.categories.firstWhere(
                          (c) => c.id == item.categoryId, 
                          orElse: () => Category(id: '', name: 'Unassigned')
                        );

                        return Card(
                          child: ListTile(
                            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Category: ${category.name}'),
                                if (item.description != null && item.description!.isNotEmpty)
                                  Text('Desc: ${item.description}', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('₹${item.price}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 16),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _showMenuItemDialog(context, item: item),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _showDeleteConfirmation(
                                    context, 
                                    title: 'Delete Item?',
                                    message: 'Are you sure you want to delete "${item.name}"?',
                                    onConfirm: () => provider.deleteMenuItem(item.id),
                                  ),
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

  void _showCategoryDialog(BuildContext context, {Category? category}) {
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
    final descriptionController = TextEditingController(text: item?.description ?? '');
    String? selectedCategoryId = item?.categoryId ?? (provider.categories.isNotEmpty ? provider.categories.first.id : null);
    String selectedItemType = item?.itemType ?? 'food';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(item == null ? 'Add Menu Item' : 'Edit Menu Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (provider.categories.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: selectedCategoryId,
                  items: provider.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                  onChanged: (val) => setState(() => selectedCategoryId = val),
                  decoration: const InputDecoration(labelText: 'Category'),
                )
              else
                const Text('Please add a category first!', style: TextStyle(color: Colors.red)),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Item Name'),
              ),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description (Optional)'),
              ),
              DropdownButtonFormField<String>(
                value: selectedItemType,
                items: const [
                  DropdownMenuItem(value: 'food', child: Text('Food')),
                  DropdownMenuItem(value: 'drink', child: Text('Drink (Soft)')),
                  DropdownMenuItem(value: 'cocktail', child: Text('Cocktail')),
                  DropdownMenuItem(value: 'mocktail', child: Text('Mocktail')),
                ],
                onChanged: (val) => setState(() => selectedItemType = val!),
                decoration: const InputDecoration(labelText: 'Item Type'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (selectedCategoryId == null) return;
                if (item == null) {
                  provider.addMenuItem(selectedCategoryId!, nameController.text, double.parse(priceController.text), descriptionController.text, selectedItemType);
                } else {
                  provider.updateMenuItem(item.id, selectedCategoryId!, nameController.text, double.parse(priceController.text), descriptionController.text, selectedItemType);
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

  void _showDeleteConfirmation(BuildContext context, {required String title, required String message, required VoidCallback onConfirm}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
