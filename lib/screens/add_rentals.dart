import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:rental_system/modals/rental.dart';
import 'package:rental_system/modals/clients.dart';
import 'package:rental_system/modals/rental_item.dart';

class AddRentalScreen extends StatefulWidget {
  const AddRentalScreen({super.key});

  @override
  State<AddRentalScreen> createState() => _AddRentalScreenState();
}

class _AddRentalScreenState extends State<AddRentalScreen> {
  final TextEditingController _clientSearchController = TextEditingController();
  final TextEditingController _itemSearchController = TextEditingController();
  Client? _selectedClient;
  Map<String, int> _selectedQuantities = {};
  List<Client> _filteredClients = [];
  List<RentalItem> _filteredItems = [];
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _clientSearchController.addListener(_onClientSearchChanged);
    _itemSearchController.addListener(_onItemSearchChanged);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _filterClients('', user.uid);
      await _filterItems('', user.uid);
    }
  }

  void _onClientSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _filterClients(_clientSearchController.text, user.uid);
      }
    });
  }

  void _onItemSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _filterItems(_itemSearchController.text, user.uid);
      }
    });
  }

  @override
  void dispose() {
    _clientSearchController.removeListener(_onClientSearchChanged);
    _itemSearchController.removeListener(_onItemSearchChanged);
    _clientSearchController.dispose();
    _itemSearchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 20),
              Text('Authentication Required',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              const Text('Please sign in to manage rentals'),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Sign In'),
                onPressed: () => Navigator.pushNamed(context, '/login'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('1. Select Client'),
              _buildClientSearchField(user.uid),
              const SizedBox(height: 8),
              _buildClientList(user.uid),
              const SizedBox(height: 24),
              _buildSectionHeader('2. Select Rental Items'),
              _buildItemSearchField(user.uid),
              const SizedBox(height: 8),
              _buildItemList(user.uid),
              const SizedBox(height: 24),
              _buildSectionHeader('3. Rental Period'),
              _buildDatePickers(),
              const SizedBox(height: 32),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() => AppBar(
        title: const Text('New Rental',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      );

  Widget _buildSectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
          ),
        ),
      );

  Widget _buildClientSearchField(String userId) => TextField(
        controller: _clientSearchController,
        decoration: InputDecoration(
          labelText: 'Search clients...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[100],
          suffixIcon: _clientSearchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _clientSearchController.clear();
                      _filterClients('', userId);
                    });
                  },
                )
              : null,
        ),
      );

  Widget _buildItemSearchField(String userId) => TextField(
        controller: _itemSearchController,
        decoration: InputDecoration(
          labelText: 'Search items...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[100],
          suffixIcon: _itemSearchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _itemSearchController.clear();
                      _filterItems('', userId);
                    });
                  },
                )
              : null,
        ),
      );

  Future<void> _filterClients(String query, String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('clients')
          .where('userId', isEqualTo: userId)
          .get();
      setState(() {
        _filteredClients = snapshot.docs
            .map((doc) => Client.fromMap(doc.data()..['id'] = doc.id))
            .where((client) =>
                client.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading clients: $e')),
      );
    }
  }

  Future<void> _filterItems(String query, String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('rental_items')
          .where('userId', isEqualTo: userId)
          .where('available', isEqualTo: true)
          .get();
      setState(() {
        _filteredItems = snapshot.docs
            .map((doc) => RentalItem.fromMap(doc.data()..['id'] = doc.id))
            .where(
                (item) => item.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading items: $e')),
      );
    }
  }

  Widget _buildClientList(String userId) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        constraints: const BoxConstraints(maxHeight: 200),
        child: _filteredClients.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No clients found'),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredClients.length,
                itemBuilder: (context, index) {
                  final client = _filteredClients[index];
                  return InkWell(
                    onTap: () => setState(() => _selectedClient = client),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: index < _filteredClients.length - 1
                              ? BorderSide(color: Colors.grey[200]!, width: 1)
                              : BorderSide.none,
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[50],
                          child: Text(
                            client.name.isNotEmpty
                                ? client.name.substring(0, 1).toUpperCase()
                                : '?',
                            style: const TextStyle(color: Colors.blue),
                          ),
                        ),
                        title: Text(
                          client.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(client.email),
                        trailing: _selectedClient?.id == client.id
                            ? const Icon(Icons.check_circle,
                                color: Colors.green)
                            : null,
                      ),
                    ),
                  );
                },
              ),
      );

  Widget _buildItemList(String userId) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        constraints: const BoxConstraints(maxHeight: 200),
        child: _filteredItems.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No available items found'),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredItems.length,
                itemBuilder: (context, index) {
                  final item = _filteredItems[index];
                  final isSelected = _selectedQuantities[item.id] != null &&
                      _selectedQuantities[item.id]! > 0;
                  return Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: index < _filteredItems.length - 1
                            ? BorderSide(color: Colors.grey[200]!, width: 1)
                            : BorderSide.none,
                      ),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue[50] : Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: item.imageUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(
                                    _getItemIcon(item.category),
                                    color:
                                        isSelected ? Colors.blue : Colors.grey,
                                  ),
                                ),
                              )
                            : Icon(
                                _getItemIcon(item.category),
                                color: isSelected ? Colors.blue : Colors.grey,
                              ),
                      ),
                      title: Text(
                        item.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.blue[800] : Colors.black,
                        ),
                      ),
                      subtitle: Text(
                        'Available: ${item.availableQuantity} | Price: \$${item.price}',
                        style: TextStyle(
                          color:
                              isSelected ? Colors.blue[600] : Colors.grey[600],
                        ),
                      ),
                      trailing: isSelected
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                QuantitySelector(
                                  value: _selectedQuantities[item.id] ?? 1,
                                  max: item.availableQuantity,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedQuantities[item.id] = value;
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _selectedQuantities.remove(item.id);
                                    });
                                  },
                                ),
                              ],
                            )
                          : IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: item.availableQuantity > 0
                                  ? () {
                                      setState(() {
                                        _selectedQuantities[item.id] = 1;
                                      });
                                    }
                                  : null,
                            ),
                    ),
                  );
                },
              ),
      );

  IconData _getItemIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'electronics':
        return Icons.devices;
      case 'tools':
        return Icons.build;
      case 'vehicle':
        return Icons.directions_car;
      case 'furniture':
        return Icons.chair;
      default:
        return Icons.category;
    }
  }

  Widget _buildDatePickers() => Row(
        children: [
          Expanded(
            child: _buildDatePicker(
              label: 'Start Date',
              date: _startDate,
              onDateSelected: (date) => setState(() => _startDate = date),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildDatePicker(
              label: 'End Date',
              date: _endDate,
              onDateSelected: (date) => setState(() => _endDate = date),
              firstDate: _startDate,
              lastDate: DateTime.now().add(const Duration(days: 365)),
            ),
          ),
        ],
      );

  Widget _buildDatePicker({
    required String label,
    required DateTime date,
    required Function(DateTime) onDateSelected,
    required DateTime firstDate,
    required DateTime lastDate,
  }) =>
      InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: date,
            firstDate: firstDate,
            lastDate: lastDate,
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Colors.blue,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black,
                  ),
                  dialogBackgroundColor: Colors.white,
                ),
                child: child!,
              );
            },
          );
          if (picked != null && picked != date) {
            onDateSelected(picked);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 20, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MMM dd, yyyy').format(date),
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _buildSaveButton() => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _submitRental,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[800],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Create Rental',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
        ),
      );

  Future<void> _submitRental() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a client')),
      );
      return;
    }

    if (_selectedQuantities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one item')),
      );
      return;
    }

    if (_endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date cannot be before start date')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final batch = FirebaseFirestore.instance.batch();
      double totalAmount = 0;

      // Fetch selected items to calculate total amount and validate quantities
      final itemDocs = await Future.wait(
        _selectedQuantities.keys.map((itemId) => FirebaseFirestore.instance
            .collection('rental_items')
            .doc(itemId)
            .get()),
      );

      for (var doc in itemDocs) {
        if (doc.exists) {
          final item = RentalItem.fromMap(doc.data()!);
          final quantity = _selectedQuantities[doc.id]!;
          if (quantity > item.availableQuantity) {
            throw Exception('Insufficient quantity for ${item.name}');
          }
          final price = double.tryParse(item.price) ?? 0.0;
          totalAmount += price * quantity;
          batch.update(
            FirebaseFirestore.instance.collection('rental_items').doc(doc.id),
            {
              'availableQuantity': item.availableQuantity - quantity,
              'quantity': item.quantity, // Preserve original quantity
            },
          );
        } else {
          throw Exception('Item ${doc.id} not found');
        }
      }

      // Create a single rental record per item
      for (var entry in _selectedQuantities.entries) {
        final itemId = entry.key;
        final quantity = entry.value;
        final itemDoc = itemDocs.firstWhere((doc) => doc.id == itemId);
        final item = RentalItem.fromMap(itemDoc.data()!);
        final itemTotal = (double.tryParse(item.price) ?? 0.0) * quantity;
        final rentalDays =
            _endDate.difference(_startDate).inDays.clamp(1, double.infinity);
        final rental = Rental(
          id: FirebaseFirestore.instance.collection('rentals').doc().id,
          userId: user.uid,
          clientId: _selectedClient!.id,
          itemId: itemId,
          quantity: quantity,
          startDate: _startDate,
          endDate: _endDate,
          totalAmount: (itemTotal * rentalDays).toStringAsFixed(2),
          status: _startDate.isAfter(DateTime.now())
              ? RentalStatus.upcoming
              : RentalStatus.active,
          //  createdAt: DateTime.now(),
        );

        batch.set(
          FirebaseFirestore.instance.collection('rentals').doc(rental.id),
          rental.toMap(),
        );
      }

      // Commit the batch
      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rental created successfully!')),
      );

      // Clear form and reset state
      setState(() {
        _selectedClient = null;
        _selectedQuantities.clear();
        _clientSearchController.clear();
        _itemSearchController.clear();
        _startDate = DateTime.now();
        _endDate = DateTime.now().add(const Duration(days: 1));
        _filterClients('', user.uid);
        _filterItems('', user.uid);
      });

      // Navigate back to RentalsScreen
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating rental: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }
}

class QuantitySelector extends StatelessWidget {
  final int value;
  final int max;
  final Function(int) onChanged;

  const QuantitySelector({
    super.key,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove, size: 18),
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey[200],
            padding: EdgeInsets.zero,
            minimumSize: const Size(32, 32),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('$value',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        IconButton(
          icon: const Icon(Icons.add, size: 18),
          onPressed: value < max ? () => onChanged(value + 1) : null,
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey[200],
            padding: EdgeInsets.zero,
            minimumSize: const Size(32, 32),
          ),
        ),
      ],
    );
  }
}
