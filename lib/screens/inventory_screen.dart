import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:rental_system/modals/rental_item.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<RentalItem> _filteredItems = [];
  String _sortBy = 'name';
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  @override
  void initState() {
    super.initState();
    _filteredItems = [];
    _searchController.addListener(_filterAndSortItems);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterAndSortItems);
    _searchController.dispose();
    super.dispose();
  }

  void _filterAndSortItems() {
    setState(() {
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

  Future<String?> _uploadImageToCloudinary(XFile image) async {
    print('Starting Cloudinary upload for image: ${image.path}');
    const apiKey = '646126543915612';
    const apiSecret = 'D3rmUdiJyJLTDRUksV8UZf3ftD4';
    const cloudName = 'ddtivketd'; // REPLACE WITH YOUR CLOUDINARY CLOUD NAME
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final signature =
        sha1.convert(utf8.encode('timestamp=$timestamp$apiSecret')).toString();
    final uri =
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['api_key'] = apiKey
      ..fields['timestamp'] = timestamp
      ..fields['signature'] = signature
      ..files.add(await http.MultipartFile.fromPath('file', image.path));

    try {
      final response = await request.send();
      print('Cloudinary response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonData = jsonDecode(responseData);
        print('Cloudinary upload successful: ${jsonData['secure_url']}');
        return jsonData['secure_url'];
      } else {
        print('Cloudinary upload failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error uploading to Cloudinary: $e');
      return null;
    }
  }

  Future<XFile?> _pickImage() async {
    print(
        '1. Entering _pickImage function'); // Check platform-specific permissions
    PermissionStatus status;
    if (Platform.isAndroid) {
      print('2. Platform is Android, checking API level');
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        print('3. Android API >= 33, requesting READ_MEDIA_IMAGES');
        status = await Permission.photos.request();
      } else {
        print('3. Android API < 33, requesting storage permission');
        status = await Permission.storage.request();
      }
    } else {
      print('2. Platform is iOS, requesting photos permission');
      status = await Permission.photos.request();
    }

    print('4. Permission status: $status');

// Handle different permission states
    if (status.isGranted) {
      print('5. Permission granted, opening image picker');
      try {
        print('6. Initializing image picker');
        final image = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 800,
          maxHeight: 800,
        );
        if (image != null) {
          print('7. Image selected successfully: ${image.path}');
          return image;
        } else {
          print('7. No image selected (user canceled)');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No image was selected')),
          );
          return null;
        }
      } catch (e) {
        print('8. Error in image picker: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
        return null;
      }
    } else if (status.isDenied) {
      print('5. Permission denied');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Photo library access is required. Please enable it in settings.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () {
              print('6. Opening app settings for permission');
              openAppSettings();
            },
          ),
        ),
      );
      return null;
    } else if (status.isPermanentlyDenied) {
      print('5. Permission permanently denied');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Photo library access is permanently denied. Please enable it in settings.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () {
              print('6. Opening app settings for permission');
              openAppSettings();
            },
          ),
        ),
      );
      return null;
    } else if (status.isRestricted || status.isLimited) {
      print('5. Permission restricted or limited');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Photo library access is restricted or limited by device settings.'),
        ),
      );
      return null;
    }
    print('5. Unexpected permission status: $status');
    return null;
  }

  Future<void> _addItem(String name, int quantity, String price,
      String category, String? imageUrl) async {
    print('Adding item: $name');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user logged in');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to add items')),
      );
      return;
    }
    final item = RentalItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      quantity: quantity,
      availableQuantity: quantity,
      price: price,
      imageUrl: imageUrl ?? 'https://via.placeholder.com/150',
      available: true,
      category: category,
      userId: user.uid,
    );

    try {
      await FirebaseFirestore.instance
          .collection('rental_items')
          .doc(item.id)
          .set(item.toMap());
      print('Item added to Firestore: ${item.name}');
    } catch (e) {
      print('Error adding item to Firestore: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding item: $e')),
      );
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
            child: const Text('Please sign in to view inventory'),
          ),
        ),
      );
    }

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
        onPressed: () {
          print('Floating action button pressed to open add item dialog');
          _showAddItemDialog(context);
        },
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Add New Item',
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rental_items')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print('Firestore stream error: ${snapshot.error}');
            return const Center(child: Text('Error loading items'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No items found'));
          }

          final items = snapshot.data!.docs
              .map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                try {
                  return RentalItem.fromMap(data);
                } catch (e) {
                  print('Error parsing Firestore item: $e, data: $data');
                  return null;
                }
              })
              .where((item) => item != null)
              .cast<RentalItem>()
              .toList();

          final query = _searchController.text.trim().toLowerCase();
          _filteredItems = items
              .where((item) => item.name.toLowerCase().contains(query))
              .toList();
          _sortItems();

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 12.0),
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
              Container(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatsCard(
                        title: 'Total Items',
                        value: items.length.toString(),
                        icon: Icons.inventory,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatsCard(
                        title: 'Available',
                        value: items
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
                        value: items
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
          );
        },
      ),
    );
  }

  void _showAddItemDialog(BuildContext context) {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    final priceController = TextEditingController();
    final categoryController = TextEditingController();
    bool isPickingImage = false;
    print('Opening add item dialog');
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            print('Building dialog UI');
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0)),
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
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: isPickingImage
                          ? null
                          : () async {
                              print('A. Pick Image button pressed');
                              setDialogState(() {
                                print('B. Setting isPickingImage to true');
                                isPickingImage = true;
                              });
                              print('C. Calling _pickImage');
                              final image = await _pickImage();
                              print(
                                  'D. _pickImage returned, image: ${image?.path}');
                              setDialogState(() {
                                print(
                                    'E. Setting isPickingImage to false, updating _selectedImage');
                                isPickingImage = false;
                                _selectedImage = image;
                              });
                              if (image != null) {
                                print('F. Showing success snackbar');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Image selected successfully')),
                                );
                              }
                            },
                      child: Text(isPickingImage
                          ? 'Picking...'
                          : _selectedImage == null
                              ? 'Pick Image'
                              : 'Image Selected'),
                    ),
                    if (_selectedImage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Image.file(
                          File(_selectedImage!.path),
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            print('Error displaying image: $error');
                            return const Text('Error loading image');
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    print('Cancel button pressed, clearing _selectedImage');
                    setState(() {
                      _selectedImage = null;
                    });
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text('Add', style: TextStyle(color: Colors.blue[900])),
                  onPressed: () async {
                    print('Add button pressed');
                    if (nameController.text.trim().isEmpty ||
                        quantityController.text.trim().isEmpty ||
                        priceController.text.trim().isEmpty ||
                        categoryController.text.trim().isEmpty) {
                      print('Validation failed: empty fields');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill all fields')),
                      );
                      return;
                    }

                    try {
                      final quantity =
                          int.parse(quantityController.text.trim());
                      print('Parsed quantity: $quantity');
                      String? imageUrl;
                      if (_selectedImage != null) {
                        print('Uploading image to Cloudinary');
                        imageUrl =
                            await _uploadImageToCloudinary(_selectedImage!);
                        if (imageUrl == null) {
                          print('Image upload failed');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Failed to upload image')),
                          );
                          return;
                        }
                        print('Image uploaded, URL: $imageUrl');
                      }
                      print('Calling _addItem');
                      await _addItem(
                        nameController.text.trim(),
                        quantity,
                        priceController.text.trim(),
                        categoryController.text.trim(),
                        imageUrl,
                      );
                      print('Clearing _selectedImage and closing dialog');
                      setState(() {
                        _selectedImage = null;
                      });
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text('${nameController.text.trim()} added!')),
                      );
                    } catch (e) {
                      print('Error in add item process: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error adding item: $e')),
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

  void _showItemDetailsDialog(
      BuildContext context, RentalItem item, int index) {
    print('Opening item details dialog for: ${item.name}');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: Text(item.name),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 150,
                    width: MediaQuery.of(context).size.width * 0.8,
                    child: Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.image_not_supported,
                        size: 100,
                        color: Colors.grey,
                      ),
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
              onPressed: () {
                print('Closing item details dialog');
                Navigator.of(context).pop();
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
