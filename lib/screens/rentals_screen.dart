import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:rental_system/modals/clients.dart';
import 'package:rental_system/modals/rental.dart';
import 'package:rental_system/modals/rental_item.dart';
import 'package:rental_system/screens/add_rentals.dart';

class RentalsScreen extends StatefulWidget {
  const RentalsScreen({super.key});

  @override
  State<RentalsScreen> createState() => _RentalsScreenState();
}

class _RentalsScreenState extends State<RentalsScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Rental> _filteredRentals = [];
  List<Rental> _allRentals = [];
  RentalStatus? _statusFilter;
  String _lastSearchQuery = '';
  RentalStatus? _lastStatusFilter;
  Timer? _debounce;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _filteredRentals = [];
    _allRentals = [];
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(() {
      print('Search TextField focus changed: ${_searchFocusNode.hasFocus}');
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    // Only update if query or filter has changed
    if (query != _lastSearchQuery || _statusFilter != _lastStatusFilter) {
      _debounce = Timer(const Duration(milliseconds: 600), () {
        setState(() {
          _lastSearchQuery = query;
          _lastStatusFilter = _statusFilter;
          _filteredRentals = _allRentals.where((rental) {
            final matchesSearch = query.isEmpty ||
                rental.clientId.toLowerCase().contains(query) ||
                rental.itemId.toLowerCase().contains(query);
            final matchesStatus =
                _statusFilter == null || rental.status == _statusFilter;
            return matchesSearch && matchesStatus;
          }).toList();
        });
        print(
            'Search query: "$query", status filter: ${_statusFilter?.name ?? 'All'}, filtered rentals: ${_filteredRentals.length}');
      });
    }
  }

  void _showAnimatedSnackBar(SnackBar snackBar) {
    print('Showing animated snackbar: ${snackBar.content}');
    final controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    final animation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
    ));

    final snackBarKey = GlobalKey();
    final snackBarWidget = SlideTransition(
      position: animation,
      child: Container(
        key: snackBarKey,
        child: snackBar,
      ),
    );

    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: snackBarWidget,
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: snackBar.duration,
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
      ),
    );

    controller.forward().then((_) {
      print('Snackbar animation completed');
      Future.delayed(snackBar.duration, () {
        controller.reverse().then((_) {
          print('Snackbar dismissed');
          controller.dispose();
        });
      });
    });
  }

  Future<void> _markAsReturned(Rental rental) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final rentalRef =
          FirebaseFirestore.instance.collection('rentals').doc(rental.id);
      final itemRef = FirebaseFirestore.instance
          .collection('rental_items')
          .doc(rental.itemId);

      // Update rental status to completed
      batch.update(rentalRef, {'status': RentalStatus.completed.name});

      // Increment availableQuantity in rental_items
      final itemDoc = await itemRef.get();
      if (itemDoc.exists) {
        final item = RentalItem.fromMap(itemDoc.data()!);
        batch.update(itemRef, {
          'availableQuantity': item.availableQuantity + rental.quantity,
        });
      } else {
        throw Exception('Item ${rental.itemId} not found');
      }

      await batch.commit();
      _showAnimatedSnackBar(
        const SnackBar(content: Text('Rental marked as returned')),
      );
      print(
          'Rental ${rental.id} marked as returned, updated item ${rental.itemId}');
    } catch (e) {
      _showAnimatedSnackBar(
        SnackBar(content: Text('Error marking rental as returned: $e')),
      );
      print('Error marking rental ${rental.id} as returned: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () {
              print('Navigating to login screen');
              Navigator.pushNamed(context, '/login');
            },
            child: const Text('Please sign in to view rentals'),
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldMessengerKey,
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
                _onSearchChanged();
              });
              print('Status filter set to: ${status?.name ?? 'All'}');
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('All Rentals')),
              const PopupMenuItem(
                  value: RentalStatus.active, child: Text('Active')),
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
        onPressed: () {
          print('Navigating to AddRentalScreen');
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddRentalScreen()),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Add New Rental',
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rentals')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print('Firestore stream error: ${snapshot.error}');
            return const Center(child: Text('Error loading rentals'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No rentals found'));
          }

          _allRentals = snapshot.data!.docs
              .map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                data['id'] = doc.id; // Ensure ID is included
                try {
                  return Rental.fromMap(data);
                } catch (e) {
                  print('Error parsing Firestore rental: $e, data: $data');
                  return null;
                }
              })
              .where((rental) => rental != null)
              .cast<Rental>()
              .toList();

          // Update filtered rentals only if necessary
          if (_searchController.text.isEmpty && _statusFilter == null) {
            _filteredRentals = _allRentals;
          } else {
            _onSearchChanged();
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 12.0),
                color: Colors.blue.shade900,
                child: TextField(
                  key: const ValueKey('searchRentalTextField'),
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Search rentals...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey[400]),
                            onPressed: () {
                              _searchController.clear();
                              _searchFocusNode.requestFocus();
                              setState(() {
                                _filteredRentals = _allRentals;
                                _lastSearchQuery = '';
                              });
                              print(
                                  'Cleared search, reset to ${_filteredRentals.length} rentals');
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
              Container(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatsCard(
                        title: 'Active',
                        value: _allRentals
                            .where((r) => r.status == RentalStatus.active)
                            .length
                            .toString(),
                        icon: Icons.play_circle,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    /*   Expanded(
                      child: _StatsCard(
                        title: 'Upcoming',
                        value: _allRentals
                            .where((r) => r.status == RentalStatus.upcoming)
                            .length
                            .toString(),
                        icon: Icons.schedule,
                        color: Colors.blue,
                      ),
                    ), */
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatsCard(
                        title: 'Completed',
                        value: _allRentals
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
                        value: _allRentals
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
                          return FutureBuilder<Map<String, dynamic>>(
                            future: _fetchRentalDetails(rental),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.only(bottom: 12.0),
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (snapshot.hasError || !snapshot.hasData) {
                                print(
                                    'Error fetching rental details: ${snapshot.error}');
                                return const SizedBox.shrink();
                              }
                              final details = snapshot.data!;
                              final clientName =
                                  details['clientName'] as String;
                              final itemName = details['itemName'] as String;
                              final clientPhone =
                                  details['clientPhone'] as String;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: _RentalCard(
                                  rental: rental,
                                  clientName: clientName,
                                  itemName: itemName,
                                  clientPhone: clientPhone,
                                  onTap: () => _showRentalDetailsDialog(
                                      context,
                                      rental,
                                      clientName,
                                      itemName,
                                      clientPhone),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _fetchRentalDetails(Rental rental) async {
    try {
      final clientDoc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(rental.clientId)
          .get();
      final itemDoc = await FirebaseFirestore.instance
          .collection('rental_items')
          .doc(rental.itemId)
          .get();
      final client =
          clientDoc.exists ? Client.fromMap(clientDoc.data()!) : null;
      final item = itemDoc.exists ? RentalItem.fromMap(itemDoc.data()!) : null;
      print(
          'Fetched details for rental ${rental.id}: client=${client?.name}, item=${item?.name}');
      return {
        'clientName': client?.name ?? 'Unknown Client',
        'clientPhone': client?.phone ?? 'Unknown Phone',
        'itemName': item?.name ?? 'Unknown Item',
      };
    } catch (e) {
      print('Error fetching rental details for ${rental.id}: $e');
      return {
        'clientName': 'Unknown Client',
        'clientPhone': 'Unknown Phone',
        'itemName': 'Unknown Item',
      };
    }
  }

  void _showRentalDetailsDialog(BuildContext context, Rental rental,
      String clientName, String itemName, String clientPhone) {
    print('Opening rental details dialog for: ${rental.id}');
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: Text('Rental Details'),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(dialogContext).size.height * 0.6,
              maxWidth: MediaQuery.of(dialogContext).size.width * 0.8,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Client: $clientName'),
                  const SizedBox(height: 8),
                  Text('Phone: $clientPhone'),
                  const SizedBox(height: 8),
                  Text('Item: $itemName'),
                  const SizedBox(height: 8),
                  Text('Quantity: ${rental.quantity}'),
                  const SizedBox(height: 8),
                  Text(
                      'Start Date: ${rental.startDate.day}/${rental.startDate.month}/${rental.startDate.year}'),
                  const SizedBox(height: 8),
                  Text(
                      'End Date: ${rental.endDate.day}/${rental.endDate.month}/${rental.endDate.year}'),
                  const SizedBox(height: 8),
                  Text('Total Amount: \$${rental.totalAmount}'),
                  const SizedBox(height: 8),
                  Text('Status: ${rental.status.name.toUpperCase()}'),
                ],
              ),
            ),
          ),
          actions: [
            if (rental.status != RentalStatus.completed &&
                rental.status != RentalStatus.overdue)
              TextButton(
                child: const Text('Mark as Returned'),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _markAsReturned(rental);
                },
              ),
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                print('Closing rental details dialog');
                Navigator.of(dialogContext).pop();
              },
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
  final String clientName;
  final String itemName;
  final String clientPhone;
  final VoidCallback onTap;

  const _RentalCard({
    required this.rental,
    required this.clientName,
    required this.itemName,
    required this.clientPhone,
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
                    clientName,
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
                itemName,
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
                    '\$${rental.totalAmount}',
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
