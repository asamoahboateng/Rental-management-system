import 'package:flutter/material.dart';
import 'package:rental_system/modals/rental_item.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<RentalItem> _rentalItems = [
    RentalItem(
      id: '1',
      name: 'Plates',
      quantity: 200,
      availableQuantity: 150,
      price: 'GHC 1/unit',
      imageUrl: 'https://via.placeholder.com/150',
      available: true,
      category: 'Tableware',
    ),
    RentalItem(
      id: '2',
      name: 'Chiavari Chairs',
      quantity: 150,
      availableQuantity: 100,
      price: 'GHC 5/unit',
      imageUrl: 'https://via.placeholder.com/150',
      available: true,
      category: 'Furniture',
    ),
    RentalItem(
      id: '3',
      name: 'Chafing Dish',
      quantity: 50,
      availableQuantity: 0,
      price: 'GHC 15/unit',
      imageUrl: 'https://via.placeholder.com/150',
      available: false,
      category: 'Catering',
    ),
    RentalItem(
      id: '4',
      name: 'Round Tables',
      quantity: 80,
      availableQuantity: 60,
      price: 'GHC 10/unit',
      imageUrl: 'https://via.placeholder.com/150',
      available: true,
      category: 'Furniture',
    ),
    RentalItem(
      id: '5',
      name: 'Sound System',
      quantity: 20,
      availableQuantity: 15,
      price: 'GHC 50/unit',
      imageUrl: 'https://via.placeholder.com/150',
      available: true,
      category: 'Electronics',
    ),
  ];

  List<RentalItem> _filteredItems = [];
  String _sortBy = 'name';

  @override
  void initState() {
    super.initState();
    _filteredItems = List.from(_rentalItems);
    _sortItems();
    _searchController.addListener(_filterAndSortItems);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterAndSortItems);
    _searchController.dispose();
    super.dispose();
  }

  void _filterAndSortItems() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredItems = _rentalItems
          .where((item) => item.name.toLowerCase().contains(query))
          .toList();
      _sortItems();
    });
  }

  void _sortItems() {
    _filteredItems.sort((a, b) {
      if (_sortBy == 'name') {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      } else if (_sortBy == 'quantity') {
        return a.quantity.compareTo(b.quantity);
      } else {
        return a.available == b.available ? 0 : (a.available ? -1 : 1);
      }
    });
  }

  void _addItem(String name, int quantity, String price, String category) {
    setState(() {
      _rentalItems.add(RentalItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        quantity: quantity,
        availableQuantity: quantity,
        price: price,
        imageUrl: 'https://via.placeholder.com/150',
        available: true,
        category: category,
      ));
      _filterAndSortItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blue.shade900,
        elevation: 0,
        title: const Text(
          'Inventory Management',
          style: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort, color: Colors.white),
            onSelected: (value) {
              setState(() {
                _sortBy = value;
                _sortItems();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'name', child: Text('Sort by Name')),
              const PopupMenuItem(
                  value: 'quantity', child: Text('Sort by Quantity')),
              const PopupMenuItem(
                  value: 'availability', child: Text('Sort by Availability')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue[900],
        onPressed: () => _showAddItemDialog(context),
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Add New Item',
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            color: Colors.blue.shade900,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search items...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[400]),
                        onPressed: () {
                          _searchController.clear();
                          _filterAndSortItems();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 15.0, horizontal: 20.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // Stats Cards
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: _StatsCard(
                    title: 'Total Items',
                    value: _rentalItems.length.toString(),
                    icon: Icons.inventory,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatsCard(
                    title: 'Available',
                    value: _rentalItems
                        .where((item) => item.available)
                        .length
                        .toString(),
                    icon: Icons.check_circle,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatsCard(
                    title: 'Out of Stock',
                    value: _rentalItems
                        .where((item) => !item.available)
                        .length
                        .toString(),
                    icon: Icons.warning,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
          // Items List
          Expanded(
            child: _filteredItems.isEmpty
                ? const Center(
                    child: Text(
                      'No items found',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _InventoryCard(
                          item: item,
                          onTap: () =>
                              _showItemDetailsDialog(context, item, index),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog(BuildContext context) {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    final priceController = TextEditingController();
    final categoryController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: const Text('Add New Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Item Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Price (e.g., GHC 5/unit)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Add', style: TextStyle(color: Colors.blue[900])),
              onPressed: () {
                if (nameController.text.trim().isEmpty ||
                    quantityController.text.trim().isEmpty ||
                    priceController.text.trim().isEmpty ||
                    categoryController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                  return;
                }
                try {
                  final quantity = int.parse(quantityController.text.trim());
                  _addItem(
                    nameController.text.trim(),
                    quantity,
                    priceController.text.trim(),
                    categoryController.text.trim(),
                  );
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('${nameController.text.trim()} added!')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid quantity format')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showItemDetailsDialog(
      BuildContext context, RentalItem item, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: Text(item.name),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height *
                  0.6, // Limit dialog height
              maxWidth:
                  MediaQuery.of(context).size.width * 0.8, // Limit dialog width
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Horizontally scrollable icons with one item visible at a time
                  SizedBox(
                    height: 150, // Fixed height for PageView
                    width: MediaQuery.of(context).size.width *
                        0.8, // Explicit width
                    child: PageView.builder(
                      itemCount:
                          5, // Replace with actual number of images/icons
                      itemBuilder: (context, index) => Center(
                        child: Container(
                          width: 120, // Explicit size for item
                          height: 120,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Icon(
                            Icons.image, // Placeholder icon
                            size: 100, // Slightly smaller to fit container
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      controller: PageController(
                        viewportFraction: 0.8, // Adjusted for better visibility
                      ),
                      physics:
                          const BouncingScrollPhysics(), // Smooth scrolling
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Category: ${item.category}'),
                  const SizedBox(height: 8),
                  Text('Total Quantity: ${item.quantity}'),
                  const SizedBox(height: 8),
                  Text('Available: ${item.availableQuantity}'),
                  const SizedBox(height: 8),
                  Text('Rented: ${item.quantity - item.availableQuantity}'),
                  const SizedBox(height: 8),
                  Text('Price: ${item.price}'),
                  const SizedBox(height: 8),
                  Text(
                      'Status: ${item.available ? "Available" : "Out of Stock"}'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatsCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  final RentalItem item;
  final VoidCallback onTap;

  const _InventoryCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 6,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15.0),
            color: Colors.white,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15.0),
                  bottomLeft: Radius.circular(15.0),
                ),
                child: Image.network(
                  item.imageUrl,
                  width: 100,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 100,
                      height: double.infinity,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported,
                          color: Colors.grey),
                    );
                  },
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.category,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Price: ${item.price}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Available: ${item.availableQuantity}/${item.quantity}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.available ? Colors.green : Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              item.available ? 'Available' : 'Out of Stock',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
