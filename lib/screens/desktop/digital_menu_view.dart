import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/restaurant_provider.dart';
import '../../models/menu_item_model.dart';
import '../../models/category_model.dart';

class DigitalMenuView extends StatefulWidget {
  const DigitalMenuView({super.key});

  @override
  State<DigitalMenuView> createState() => _DigitalMenuViewState();
}

class _DigitalMenuViewState extends State<DigitalMenuView> {
  String _selectedType = 'food'; // 'food' or 'drink'
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();
    
    // Filter categories that have items of the selected type
    final relevantCategories = provider.categories.where((cat) {
      return provider.menuItems.any((item) => 
        item.categoryId == cat.id && 
        item.itemType.toLowerCase() == _selectedType.toLowerCase()
      );
    }).toList();

    // Reset selected category if it's no longer relevant
    if (_selectedCategoryId != null && !relevantCategories.any((c) => c.id == _selectedCategoryId)) {
      _selectedCategoryId = null;
    }

    // Filter items based on type and category
    final filteredItems = provider.menuItems.where((item) {
      final typeMatch = item.itemType.toLowerCase() == _selectedType.toLowerCase();
      final categoryMatch = _selectedCategoryId == null || item.categoryId == _selectedCategoryId;
      return typeMatch && categoryMatch;
    }).toList();

    return Row(
      children: [
        // Sidebar: Categories
        Container(
          width: 280,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Column(
            children: [
              // Type Toggle
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _TypeButton(
                        label: 'FOOD',
                        isSelected: _selectedType == 'food',
                        onTap: () => setState(() {
                          _selectedType = 'food';
                          _selectedCategoryId = null;
                        }),
                      ),
                      _TypeButton(
                        label: 'DRINKS',
                        isSelected: _selectedType == 'drink',
                        onTap: () => setState(() {
                          _selectedType = 'drink';
                          _selectedCategoryId = null;
                        }),
                      ),
                      _TypeButton(
                        label: 'COCKTAILS',
                        isSelected: _selectedType == 'cocktail',
                        onTap: () => setState(() {
                          _selectedType = 'cocktail';
                          _selectedCategoryId = null;
                        }),
                      ),
                      _TypeButton(
                        label: 'MOCKTAILS',
                        isSelected: _selectedType == 'mocktail',
                        onTap: () => setState(() {
                          _selectedType = 'mocktail';
                          _selectedCategoryId = null;
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              
              const Divider(height: 1),
              
              // Category List
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  children: [
                    ListTile(
                      leading: Icon(Icons.all_inclusive, 
                        color: _selectedCategoryId == null ? Colors.deepOrange : Colors.grey),
                      title: Text('All Categories', 
                        style: TextStyle(
                          fontWeight: _selectedCategoryId == null ? FontWeight.bold : FontWeight.normal,
                          color: _selectedCategoryId == null ? Colors.deepOrange : Colors.black87,
                        )),
                      selected: _selectedCategoryId == null,
                      onTap: () => setState(() => _selectedCategoryId = null),
                    ),
                    ...relevantCategories.map((cat) => ListTile(
                      leading: Icon(Icons.chevron_right, 
                        color: _selectedCategoryId == cat.id ? Colors.deepOrange : Colors.grey),
                      title: Text(cat.name, 
                        style: TextStyle(
                          fontWeight: _selectedCategoryId == cat.id ? FontWeight.bold : FontWeight.normal,
                          color: _selectedCategoryId == cat.id ? Colors.deepOrange : Colors.black87,
                        )),
                      selected: _selectedCategoryId == cat.id,
                      onTap: () => setState(() => _selectedCategoryId = cat.id),
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Main Content: Items Grid
        Expanded(
          child: Container(
            color: Colors.grey.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Row(
                    children: [
                      Text(
                        _selectedCategoryId == null 
                          ? 'All ${_selectedType.toUpperCase()}S' 
                          : relevantCategories.firstWhere((c) => c.id == _selectedCategoryId).name,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('${filteredItems.length} items', 
                          style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.restaurant_menu, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            const Text('No items found in this category', style: TextStyle(color: Colors.grey, fontSize: 18)),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 300,
                          mainAxisExtent: 180,
                          crossAxisSpacing: 24,
                          mainAxisSpacing: 24,
                        ),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return _MenuItemCard(item: item);
                        },
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeButton({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.deepOrange : Colors.grey,
              fontSize: 12,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final MenuItem item;
  const _MenuItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                item.itemType.toLowerCase() == 'food' ? Icons.restaurant : Icons.local_bar,
                size: 20,
                color: item.itemType.toLowerCase() == 'cocktail' ? Colors.purple : (item.itemType.toLowerCase() == 'mocktail' ? Colors.pink : Colors.grey.shade400),
              ),
              Text(
                '₹${item.price}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            item.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          if (item.description != null && item.description!.isNotEmpty)
            Text(
              item.description!,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}
