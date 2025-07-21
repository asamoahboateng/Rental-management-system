import 'package:flutter/material.dart';
import 'package:rental_system/utils/snackbar.dart';

class RentalItem {
  final String name;
  final int quantity;
  final String price;
  final String imageUrl;
  final bool available;

  RentalItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.imageUrl,
    required this.available,
  });
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final TextEditingController _searchController = TextEditingController();
  final List<RentalItem> _rentalItems = [
    RentalItem(
      name: 'Plates',
      quantity: 200,
      price: 'gHC 1/unit',
      imageUrl: 'https://via.placeholder.com/150',
      available: true,
    ),
    RentalItem(
      name: 'Chiavari Chairs',
      quantity: 150,
      price: ' Ghc 5/unit',
      imageUrl: 'https://via.placeholder.com/150',
      available: true,
    ),
    RentalItem(
      name: 'Chafing Dish',
      quantity: 50,
      price: 'Ghc 15/unit',
      imageUrl: 'https://via.placeholder.com/150',
      available: false,
    ),
  ];
  List<RentalItem> _filteredItems = [];
  String _sortBy = 'name'; // Default sort by name

  @override
  void initState() {
    super.initState();
    _filteredItems = List.from(_rentalItems);
    _sortItems();
    _searchController.addListener(_filterAndSortItems);
  }

  @override
  void dispose() {
    _searchController
        .removeListener(_filterAndSortItems); // Prevent memory leak
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

  void _addItem(String name, int quantity, String price, bool available) {
    // Validate price format (basic check for $X/unit)
    if (!RegExp(r'^\$\d+(\.\d{1,2})?\/unit$').hasMatch(price)) {
      /*  ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Price must be in \$X/unit format')),
      ); */
      errorSnackbarwidget.show(context, 'Price must be in \$X/unit format');
      return;
    }
    setState(() {
      _rentalItems.add(RentalItem(
        name: name,
        quantity: quantity,
        price: price,
        imageUrl: 'https://via.placeholder.com/150',
        available: available,
      ));
      _filterAndSortItems();
    });
  }

  void _editItem(int filteredIndex, String name, int quantity, String price,
      bool available) {
    // Validate price format
    if (!RegExp(r'^\$\d+(\.\d{1,2})?\/unit$').hasMatch(price)) {
      /*    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Price must be in \$X/unit format')),
      ); */
      errorSnackbarwidget.show(context, 'Price must be in \$X/unit format');
      return;
    }
    // Map filteredIndex to rentalItems index
    int originalIndex = _rentalItems
        .indexWhere((item) => item == _filteredItems[filteredIndex]);
    setState(() {
      _rentalItems[originalIndex] = RentalItem(
        name: name,
        quantity: quantity,
        price: price,
        imageUrl: _rentalItems[originalIndex].imageUrl,
        available: available,
      );
      _filterAndSortItems();
    });
  }

  void _toggleAvailability(int filteredIndex) {
    // Map filteredIndex to rentalItems index
    int originalIndex = _rentalItems
        .indexWhere((item) => item == _filteredItems[filteredIndex]);
    setState(() {
      _rentalItems[originalIndex] = RentalItem(
        name: _rentalItems[originalIndex].name,
        quantity: _rentalItems[originalIndex].quantity,
        price: _rentalItems[originalIndex].price,
        imageUrl: _rentalItems[originalIndex].imageUrl,
        available: !_rentalItems[originalIndex].available,
      );
      _filterAndSortItems();
    });
  }

  void _deleteItem(int filteredIndex) {
    // Map filteredIndex to rentalItems index
    int originalIndex = _rentalItems
        .indexWhere((item) => item == _filteredItems[filteredIndex]);
    setState(() {
      _rentalItems.removeAt(originalIndex);
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
          'Rentals',
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
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            tooltip: 'Rental History',
            onPressed: () => _showRentalHistory(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue[900],
        onPressed: () => _showAddItemDialog(context),
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Add New Item',
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide:
                        BorderSide(color: Colors.purple[900]!, width: 2.0),
                  ),
                ),
                style: const TextStyle(fontFamily: 'Roboto'),
              ),
            ),
            const SizedBox(height: 20),
            // Rental Items List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Inventory',
                    style: TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _filteredItems.isEmpty
                      ? const Center(
                          child: Text(
                            'No items found',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: _RentalCard(
                                item: item,
                                onTap: () => _showItemDetailsDialog(
                                    context, item, index),
                                onToggleAvailability: () =>
                                    _toggleAvailability(index),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddItemDialog(BuildContext context) {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    final priceController = TextEditingController();
    bool available = true;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: const Text(
            'Add New Item',
            style: TextStyle(fontFamily: 'PlayfairDisplay'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Item Name',
                    labelStyle: TextStyle(fontFamily: 'Roboto'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    labelStyle: TextStyle(fontFamily: 'Roboto'),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Price (e.g., \$5/unit)',
                    labelStyle: TextStyle(fontFamily: 'Roboto'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          actions: [
            TextButton(
              child:
                  const Text('Cancel', style: TextStyle(fontFamily: 'Roboto')),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(
                'Add',
                style:
                    TextStyle(color: Colors.purple[900], fontFamily: 'Roboto'),
              ),
              onPressed: () {
                if (nameController.text.trim().isEmpty ||
                    quantityController.text.trim().isEmpty ||
                    priceController.text.trim().isEmpty) {
                  /*    ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  ); */
                  errorSnackbarwidget.show(context, 'Please fill all fields');
                  return;
                }
                try {
                  final quantity = int.parse(quantityController.text.trim());
                  if (quantity < 0) {
                    /*  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Quantity must be non-negative')),
                    ); */
                    errorSnackbarwidget.show(
                        context, 'Quantity must be non-negative');
                    return;
                  }
                  _addItem(
                    nameController.text.trim(),
                    quantity,
                    priceController.text.trim(),
                    available,
                  );
                  Navigator.of(context).pop();
                  /*   ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('${nameController.text.trim()} added!')),
                  ); */
                  Snackbarwidget.show(
                      context, '${nameController.text.trim()} added!');
                } catch (e) {
                  /*  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid quantity format')),
                  ); */
                  errorSnackbarwidget.show(context, 'Invalid quantity format');
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showItemDetailsDialog(
      BuildContext context, RentalItem item, int filteredIndex) {
    final nameController = TextEditingController(text: item.name);
    final quantityController =
        TextEditingController(text: item.quantity.toString());
    final priceController = TextEditingController(text: item.price);
    bool available = item.available;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: Text(
            item.name,
            style: const TextStyle(fontFamily: 'PlayfairDisplay'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Item Name',
                    labelStyle: TextStyle(fontFamily: 'Roboto'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    labelStyle: TextStyle(fontFamily: 'Roboto'),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Price (e.g., Ghc 5/unit)',
                    labelStyle: TextStyle(fontFamily: 'Roboto'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                /*  SwitchListTile(
                  title: const Text('Available',
                      style: TextStyle(fontFamily: 'Roboto')),
                  value: available,
                  activeColor: Colors.purple[900],
                  onChanged: (value) =>
                      setState(() => available = value), // Update dialog state
                ), */
              ],
            ),
          ),
          actions: [
            TextButton(
              child:
                  const Text('Cancel', style: TextStyle(fontFamily: 'Roboto')),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(
                'Save',
                style:
                    TextStyle(color: Colors.purple[900], fontFamily: 'Roboto'),
              ),
              onPressed: () {
                if (nameController.text.trim().isEmpty ||
                    quantityController.text.trim().isEmpty ||
                    priceController.text.trim().isEmpty) {
                  /*   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  ); */
                  errorSnackbarwidget.show(context, 'Please fill all fields');
                  return;
                }
                try {
                  final quantity = int.parse(quantityController.text.trim());
                  if (quantity < 0) {
                    /*   ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Quantity must be non-negative')),
                    ); */
                    errorSnackbarwidget.show(
                        context, 'Quantity must be non-negative');
                    return;
                  }
                  _editItem(
                    filteredIndex,
                    nameController.text.trim(),
                    quantity,
                    priceController.text.trim(),
                    available,
                  );
                  Navigator.of(context).pop();
                  /*   ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text('${nameController.text.trim()} updated!')),
                  ); */
                  Snackbarwidget.show(
                      context, '${nameController.text.trim()} updated!');
                } catch (e) {
                  /*  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid quantity format')),
                  ); */
                  errorSnackbarwidget.show(context, 'Invalid quantity format');
                }
              },
            ),
            TextButton(
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red, fontFamily: 'Roboto'),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.0)),
                    title: const Text('Confirm Delete',
                        style: TextStyle(fontFamily: 'PlayfairDisplay')),
                    content:
                        Text('Are you sure you want to delete ${item.name}?'),
                    actions: [
                      TextButton(
                        child: const Text('Cancel',
                            style: TextStyle(fontFamily: 'Roboto')),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      TextButton(
                        child: const Text(
                          'Delete',
                          style: TextStyle(
                              color: Colors.red, fontFamily: 'Roboto'),
                        ),
                        onPressed: () {
                          _deleteItem(filteredIndex);
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                          /*   ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${item.name} deleted!')),
                          ); */
                          Snackbarwidget.show(context, '${item.name} deleted!');
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showRentalHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: const Text(
            'Rental History',
            style: TextStyle(fontFamily: 'PlayfairDisplay'),
          ),
          content: const Text(
            'No rental history available. Integrate with a backend to track rentals.',
            style: TextStyle(fontFamily: 'Roboto'),
          ),
          actions: [
            TextButton(
              child:
                  const Text('Close', style: TextStyle(fontFamily: 'Roboto')),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}

class _RentalCard extends StatelessWidget {
  final RentalItem item;
  final VoidCallback onTap;
  final VoidCallback onToggleAvailability;

  const _RentalCard({
    required this.item,
    required this.onTap,
    required this.onToggleAvailability,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 6,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15.0),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Image
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15.0),
                  bottomLeft: Radius.circular(15.0),
                ),
                child: Image.network(
                  item.imageUrl,
                  width: 130,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback to a blank container if no placeholder asset is available
                    return Container(
                      width: 130,
                      height: double.infinity,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported,
                          color: Colors.grey),
                    );
                  },
                ),
              ),
              // Details
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
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Price: ${item.price}',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.purple[900],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Qty: ${item.quantity}',
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 14,
                              color: Colors.black54,
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
