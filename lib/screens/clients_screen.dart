import 'package:flutter/material.dart';
import 'package:rental_system/modals/clients.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<Client> _clients = [
    Client(
      id: '1',
      name: 'John Doe',
      email: 'john.doe@email.com',
      phone: '+233 24 123 4567',
      address: '123 Main St, Accra',
      totalRentals: 5,
      activeRentals: 2,
      joinDate: DateTime(2023, 1, 15),
    ),
    Client(
      id: '2',
      name: 'Jane Smith',
      email: 'jane.smith@email.com',
      phone: '+233 20 987 6543',
      address: '456 Oak Ave, Kumasi',
      totalRentals: 12,
      activeRentals: 1,
      joinDate: DateTime(2022, 8, 22),
    ),
    Client(
      id: '3',
      name: 'Michael Johnson',
      email: 'michael.j@email.com',
      phone: '+233 26 555 0123',
      address: '789 Pine Rd, Tamale',
      totalRentals: 8,
      activeRentals: 0,
      joinDate: DateTime(2023, 3, 10),
    ),
    Client(
      id: '4',
      name: 'Sarah Wilson',
      email: 'sarah.wilson@email.com',
      phone: '+233 27 444 5678',
      address: '321 Elm St, Cape Coast',
      totalRentals: 15,
      activeRentals: 3,
      joinDate: DateTime(2022, 11, 5),
    ),
  ];

  List<Client> _filteredClients = [];

  @override
  void initState() {
    super.initState();
    _filteredClients = List.from(_clients);
    _searchController.addListener(_filterClients);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterClients);
    _searchController.dispose();
    super.dispose();
  }

  void _filterClients() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredClients = _clients
          .where((client) =>
              client.name.toLowerCase().contains(query) ||
              client.email.toLowerCase().contains(query) ||
              client.phone.contains(query))
          .toList();
    });
  }

  void _addClient(String name, String email, String phone, String address) {
    setState(() {
      _clients.add(Client(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        email: email,
        phone: phone,
        address: address,
        totalRentals: 0,
        activeRentals: 0,
        joinDate: DateTime.now(),
      ));
      _filterClients();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        onPressed: () => _showAddClientDialog(context),
        child: const Icon(Icons.person_add, color: Colors.white),
        tooltip: 'Add New Client',
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
                hintText: 'Search clients...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[400]),
                        onPressed: () {
                          _searchController.clear();
                          _filterClients();
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
                    title: 'Total Clients',
                    value: _clients.length.toString(),
                    icon: Icons.people,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatsCard(
                    title: 'Active Rentals',
                    value: _clients
                        .fold(0, (sum, client) => sum + client.activeRentals)
                        .toString(),
                    icon: Icons.assignment,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          // Clients List
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
                        ),
                      );
                    },
                  ),
          ),
        ],
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
      builder: (BuildContext context) {
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
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                  // maxLines: 2,
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
                    emailController.text.trim().isEmpty ||
                    phoneController.text.trim().isEmpty ||
                    addressController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                  return;
                }
                _addClient(
                  nameController.text.trim(),
                  emailController.text.trim(),
                  phoneController.text.trim(),
                  addressController.text.trim(),
                );
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('${nameController.text.trim()} added!')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showClientDetailsDialog(BuildContext context, Client client) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: Text(client.name),
          content: Column(
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

class _ClientCard extends StatelessWidget {
  final Client client;
  final VoidCallback onTap;

  const _ClientCard({
    required this.client,
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
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          client.activeRentals > 0 ? Colors.green : Colors.grey,
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
