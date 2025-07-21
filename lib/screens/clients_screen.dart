import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:rental_system/modals/clients.dart';
import 'package:rental_system/modals/rental.dart';
import 'package:rental_system/modals/rental_item.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Client> _filteredClients = [];
  List<Client> _allClients = [];
  String _lastSearchQuery = '';
  Timer? _debounce;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _filteredClients = [];
    _allClients = [];
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
    if (query != _lastSearchQuery) {
      _debounce = Timer(const Duration(milliseconds: 600), () {
        setState(() {
          _lastSearchQuery = query;
          _filteredClients = _allClients
              .where((client) =>
                  client.name.toLowerCase().contains(query) ||
                  client.email.toLowerCase().contains(query) ||
                  client.phone.contains(query))
              .toList();
        });
        print(
            'Search query: "$query", filtered clients: ${_filteredClients.length}');
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

  Future<void> _addClient(
      String name, String email, String phone, String address) async {
    print('Adding client: $name');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user logged in');
      _showAnimatedSnackBar(
        SnackBar(
          content: const Text('Please sign in to add clients'),
          backgroundColor: Colors.red,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
          elevation: 6.0,
        ),
      );
      return;
    }

    final client = Client(
      id: FirebaseFirestore.instance.collection('clients').doc().id,
      name: name,
      email: email,
      phone: phone,
      address: address,
      totalRentals: 0,
      activeRentals: 0,
      joinDate: DateTime.now(),
      userId: user.uid,
    );

    try {
      await FirebaseFirestore.instance
          .collection('clients')
          .doc(client.id)
          .set(client.toMap());
      print('Client added to Firestore: ${client.name}');
      _showAnimatedSnackBar(
        SnackBar(
          content: Text('${client.name} added!'),
          backgroundColor: Colors.green,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
          elevation: 6.0,
        ),
      );
    } catch (e) {
      print('Error adding client to Firestore: $e');
      _showAnimatedSnackBar(
        SnackBar(
          content: Text('Error adding client: $e'),
          backgroundColor: Colors.red,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
          elevation: 6.0,
        ),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchActiveRentals(
      String clientId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('rentals')
          .where('clientId', isEqualTo: clientId)
          .where('status', whereIn: ['active', 'upcoming']).get();

      final rentals = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        final rental = Rental.fromMap(doc.data()..['id'] = doc.id);
        final itemDoc = await FirebaseFirestore.instance
            .collection('rental_items')
            .doc(rental.itemId)
            .get();
        final itemName = itemDoc.exists
            ? RentalItem.fromMap(itemDoc.data()!).name
            : 'Unknown';
        rentals.add({
          'rental': rental,
          'itemName': itemName,
        });
      }
      print('Fetched ${rentals.length} active rentals for client $clientId');
      return rentals;
    } catch (e) {
      print('Error fetching active rentals for client $clientId: $e');
      return [];
    }
  }

  void _showActiveRentalsDialog(BuildContext context, Client client) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: Text('${client.name}\'s Active Rentals'),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(dialogContext).size.height * 0.6,
              maxWidth: MediaQuery.of(dialogContext).size.width * 0.8,
            ),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchActiveRentals(client.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  print('Error fetching active rentals: ${snapshot.error}');
                  return const Text('Error loading active rentals');
                }
                final rentals = snapshot.data!;
                if (rentals.isEmpty) {
                  return const Text('No active rentals found');
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: rentals.length,
                  itemBuilder: (context, index) {
                    final rentalData = rentals[index];
                    final rental = rentalData['rental'] as Rental;
                    final itemName = rentalData['itemName'] as String;
                    return ListTile(
                      title: Text(itemName),
                      subtitle: Text(
                          'Qty: ${rental.quantity} | ${rental.startDate.day}/${rental.startDate.month} - ${rental.endDate.day}/${rental.endDate.month}'),
                      trailing: Text(
                        '\$${rental.totalAmount}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                print('Closing active rentals dialog');
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
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
            child: const Text('Please sign in to view clients'),
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
          'Client Management',
          style: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue[900],
        onPressed: () {
          print('Floating action button pressed to open add client dialog');
          _showAddClientDialog(context);
        },
        child: const Icon(Icons.person_add, color: Colors.white),
        tooltip: 'Add New Client',
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clients')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print('Firestore stream error: ${snapshot.error}');
            return const Center(child: Text('Error loading clients'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No clients found'));
          }

          _allClients = snapshot.data!.docs
              .map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                data['id'] = doc.id;
                try {
                  return Client.fromMap(data);
                } catch (e) {
                  print('Error parsing Firestore client: $e, data: $data');
                  return null;
                }
              })
              .where((client) => client != null)
              .cast<Client>()
              .toList();

          if (_searchController.text.isEmpty) {
            _filteredClients = _allClients;
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
                  key: const ValueKey('searchClientTextField'),
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Search clients...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey[400]),
                            onPressed: () {
                              _searchController.clear();
                              _searchFocusNode.requestFocus();
                              setState(() {
                                _filteredClients = _allClients;
                                _lastSearchQuery = '';
                              });
                              print(
                                  'Cleared search, reset to ${_filteredClients.length} clients');
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
                        title: 'Total Clients',
                        value: _allClients.length.toString(),
                        icon: Icons.people,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatsCard(
                        title: 'Active Rentals',
                        value: _allClients
                            .fold(
                                0, (sum, client) => sum + client.activeRentals)
                            .toString(),
                        icon: Icons.assignment,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _filteredClients.isEmpty
                    ? const Center(
                        child: Text(
                          'No clients found',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: _filteredClients.length,
                        itemBuilder: (context, index) {
                          final client = _filteredClients[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: _ClientCard(
                              client: client,
                              onTap: () =>
                                  _showClientDetailsDialog(context, client),
                              onActiveRentalsTap: () =>
                                  _showActiveRentalsDialog(context, client),
                            ),
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

  void _showAddClientDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: const Text('Add New Client'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                print('Cancel button pressed in add client dialog');
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: Text('Add', style: TextStyle(color: Colors.blue[900])),
              onPressed: () async {
                print('Add button pressed in add client dialog');
                if (nameController.text.trim().isEmpty ||
                    emailController.text.trim().isEmpty ||
                    phoneController.text.trim().isEmpty ||
                    addressController.text.trim().isEmpty) {
                  print('Validation failed: empty fields');
                  _showAnimatedSnackBar(
                    SnackBar(
                      content: const Text('Please fill all fields'),
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                      duration: const Duration(seconds: 2),
                      elevation: 6.0,
                    ),
                  );
                  return;
                }
                await _addClient(
                  nameController.text.trim(),
                  emailController.text.trim(),
                  phoneController.text.trim(),
                  addressController.text.trim(),
                );
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showClientDetailsDialog(BuildContext context, Client client) {
    print('Opening client details dialog for: ${client.name}');
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: Text(client.name),
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
                  Text('Email: ${client.email}'),
                  const SizedBox(height: 8),
                  Text('Phone: ${client.phone}'),
                  const SizedBox(height: 8),
                  Text('Address: ${client.address}'),
                  const SizedBox(height: 8),
                  Text('Total Rentals: ${client.totalRentals}'),
                  const SizedBox(height: 8),
                  Text('Active Rentals: ${client.activeRentals}'),
                  const SizedBox(height: 8),
                  Text(
                      'Member Since: ${client.joinDate.day}/${client.joinDate.month}/${client.joinDate.year}'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                print('Closing client details dialog');
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

class _ClientCard extends StatelessWidget {
  final Client client;
  final VoidCallback onTap;
  final VoidCallback onActiveRentalsTap;

  const _ClientCard({
    required this.client,
    required this.onTap,
    required this.onActiveRentalsTap,
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
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15.0),
            color: Colors.white,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.blue[900],
                child: Text(
                  client.name.split(' ').map((n) => n[0]).take(2).join(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      client.email,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      client.phone,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: client.activeRentals > 0 ? onActiveRentalsTap : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: client.activeRentals > 0
                            ? Colors.green
                            : Colors.grey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${client.activeRentals} Active',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${client.totalRentals} Total',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
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
