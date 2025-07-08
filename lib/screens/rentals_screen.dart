import 'package:flutter/material.dart';
import 'package:rental_system/modals/rental.dart';

class RentalsScreen extends StatefulWidget {
  const RentalsScreen({super.key});

  @override
  State<RentalsScreen> createState() => _RentalsScreenState();
}

class _RentalsScreenState extends State<RentalsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<Rental> _rentals = [
    Rental(
      id: '1',
      clientName: 'John Doe',
      itemName: 'Chiavari Chairs',
      quantity: 50,
      startDate: DateTime.now().subtract(const Duration(days: 2)),
      endDate: DateTime.now().add(const Duration(days: 3)),
      totalAmount: 'GHC 250',
      status: RentalStatus.active,
      clientPhone: '+233 24 123 4567',
    ),
    Rental(
      id: '2',
      clientName: 'Jane Smith',
      itemName: 'Round Tables',
      quantity: 10,
      startDate: DateTime.now().subtract(const Duration(days: 5)),
      endDate: DateTime.now().subtract(const Duration(days: 1)),
      totalAmount: 'GHC 100',
      status: RentalStatus.completed,
      clientPhone: '+233 20 987 6543',
    ),
    Rental(
      id: '3',
      clientName: 'Michael Johnson',
      itemName: 'Sound System',
      quantity: 2,
      startDate: DateTime.now().add(const Duration(days: 1)),
      endDate: DateTime.now().add(const Duration(days: 4)),
      totalAmount: 'GHC 200',
      status: RentalStatus.upcoming,
      clientPhone: '+233 26 555 0123',
    ),
    Rental(
      id: '4',
      clientName: 'Sarah Wilson',
      itemName: 'Plates',
      quantity: 100,
      startDate: DateTime.now().subtract(const Duration(days: 1)),
      endDate: DateTime.now().add(const Duration(days: 2)),
      totalAmount: 'GHC 100',
      status: RentalStatus.active,
      clientPhone: '+233 27 444 5678',
    ),
    Rental(
      id: '5',
      clientName: 'David Brown',
      itemName: 'Chafing Dish',
      quantity: 5,
      startDate: DateTime.now().subtract(const Duration(days: 10)),
      endDate: DateTime.now().subtract(const Duration(days: 8)),
      totalAmount: 'GHC 75',
      status: RentalStatus.overdue,
      clientPhone: '+233 24 111 2222',
    ),
  ];

  List<Rental> _filteredRentals = [];
  RentalStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _filteredRentals = List.from(_rentals);
    _searchController.addListener(_filterRentals);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterRentals);
    _searchController.dispose();
    super.dispose();
  }

  void _filterRentals() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredRentals = _rentals.where((rental) {
        final matchesSearch = rental.clientName.toLowerCase().contains(query) ||
            rental.itemName.toLowerCase().contains(query);
        final matchesStatus =
            _statusFilter == null || rental.status == _statusFilter;
        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  void _addRental(String clientName, String clientPhone, String itemName,
      int quantity, DateTime startDate, DateTime endDate, String totalAmount) {
    setState(() {
      _rentals.add(Rental(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        clientName: clientName,
        clientPhone: clientPhone,
        itemName: itemName,
        quantity: quantity,
        startDate: startDate,
        endDate: endDate,
        totalAmount: totalAmount,
        status: startDate.isAfter(DateTime.now())
            ? RentalStatus.upcoming
            : RentalStatus.active,
      ));
      _filterRentals();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blue.shade900,
        title: const Text(
          'Rental Management',
          style: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<RentalStatus?>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onSelected: (status) {
              setState(() {
                _statusFilter = status;
                _filterRentals();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('All Rentals')),
              const PopupMenuItem(
                  value: RentalStatus.active, child: Text('Active')),
              const PopupMenuItem(
                  value: RentalStatus.upcoming, child: Text('Upcoming')),
              const PopupMenuItem(
                  value: RentalStatus.completed, child: Text('Completed')),
              const PopupMenuItem(
                  value: RentalStatus.overdue, child: Text('Overdue')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue[900],
        onPressed: () => _showAddRentalDialog(context),
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Add New Rental',
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
                hintText: 'Search rentals...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[400]),
                        onPressed: () {
                          _searchController.clear();
                          _filterRentals();
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
          // Stats
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: _StatsCard(
                    title: 'Active',
                    value: _rentals
                        .where((r) => r.status == RentalStatus.active)
                        .length
                        .toString(),
                    icon: Icons.play_circle,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatsCard(
                    title: 'Upcoming',
                    value: _rentals
                        .where((r) => r.status == RentalStatus.upcoming)
                        .length
                        .toString(),
                    icon: Icons.schedule,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatsCard(
                    title: 'Completed',
                    value: _rentals
                        .where((r) => r.status == RentalStatus.completed)
                        .length
                        .toString(),
                    icon: Icons.check_circle,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatsCard(
                    title: 'Overdue',
                    value: _rentals
                        .where((r) => r.status == RentalStatus.overdue)
                        .length
                        .toString(),
                    icon: Icons.warning,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
          // Rentals List
          Expanded(
            child: _filteredRentals.isEmpty
                ? const Center(
                    child: Text(
                      'No rentals found',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: _filteredRentals.length,
                    itemBuilder: (context, index) {
                      final rental = _filteredRentals[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _RentalCard(
                          rental: rental,
                          onTap: () =>
                              _showRentalDetailsDialog(context, rental),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddRentalDialog(BuildContext context) {
    final clientNameController = TextEditingController();
    final clientPhoneController = TextEditingController();
    final itemNameController = TextEditingController();
    final quantityController = TextEditingController();
    final totalAmountController = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 1));

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0)),
              title: const Text('Add New Rental'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: clientNameController,
                      decoration: const InputDecoration(
                        labelText: 'Client Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: clientPhoneController,
                      decoration: const InputDecoration(
                        labelText: 'Client Phone',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: itemNameController,
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
                      controller: totalAmountController,
                      decoration: const InputDecoration(
                        labelText: 'Total Amount (e.g., GHC 100)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: startDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                              );
                              if (date != null) {
                                setState(() {
                                  startDate = date;
                                });
                              }
                            },
                            child: Text(
                                'Start: ${startDate.day}/${startDate.month}/${startDate.year}'),
                          ),
                        ),
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: endDate,
                                firstDate: startDate,
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                              );
                              if (date != null) {
                                setState(() {
                                  endDate = date;
                                });
                              }
                            },
                            child: Text(
                                'End: ${endDate.day}/${endDate.month}/${endDate.year}'),
                          ),
                        ),
                      ],
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
                    if (clientNameController.text.trim().isEmpty ||
                        clientPhoneController.text.trim().isEmpty ||
                        itemNameController.text.trim().isEmpty ||
                        quantityController.text.trim().isEmpty ||
                        totalAmountController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill all fields')),
                      );
                      return;
                    }
                    try {
                      final quantity =
                          int.parse(quantityController.text.trim());
                      _addRental(
                        clientNameController.text.trim(),
                        clientPhoneController.text.trim(),
                        itemNameController.text.trim(),
                        quantity,
                        startDate,
                        endDate,
                        totalAmountController.text.trim(),
                      );
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Rental added successfully!')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Invalid quantity format')),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRentalDetailsDialog(BuildContext context, Rental rental) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: Text('Rental #${rental.id}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Client: ${rental.clientName}'),
              const SizedBox(height: 8),
              Text('Phone: ${rental.clientPhone}'),
              const SizedBox(height: 8),
              Text('Item: ${rental.itemName}'),
              const SizedBox(height: 8),
              Text('Quantity: ${rental.quantity}'),
              const SizedBox(height: 8),
              Text(
                  'Start Date: ${rental.startDate.day}/${rental.startDate.month}/${rental.startDate.year}'),
              const SizedBox(height: 8),
              Text(
                  'End Date: ${rental.endDate.day}/${rental.endDate.month}/${rental.endDate.year}'),
              const SizedBox(height: 8),
              Text('Total Amount: ${rental.totalAmount}'),
              const SizedBox(height: 8),
              Text('Status: ${rental.status.name.toUpperCase()}'),
            ],
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
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RentalCard extends StatelessWidget {
  final Rental rental;
  final VoidCallback onTap;

  const _RentalCard({
    required this.rental,
    required this.onTap,
  });

  Color _getStatusColor(RentalStatus status) {
    switch (status) {
      case RentalStatus.active:
        return Colors.green;
      case RentalStatus.upcoming:
        return Colors.blue;
      case RentalStatus.completed:
        return Colors.grey;
      case RentalStatus.overdue:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 6,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15.0),
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    rental.clientName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(rental.status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      rental.status.name.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                rental.itemName,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue[900],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Qty: ${rental.quantity}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${rental.startDate.day}/${rental.startDate.month} - ${rental.endDate.day}/${rental.endDate.month}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    rental.totalAmount,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
