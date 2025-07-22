import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:rental_system/modals/rental_item.dart';
import 'package:rental_system/utils/snackbar.dart';
import 'dart:async';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<RentalItem> _filteredItems = [];
  List<RentalItem> _allItems = [];
  String _sortBy = 'name';
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _filteredItems = [];
    _allItems = [];
    // Debounce search input to prevent excessive rebuilds
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    // Cancel previous debounce timer
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    // Set new debounce timer for 500ms
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _filterAndSortItems();
      });
    });
  }

  void _filterAndSortItems() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredItems = _allItems
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

  Future<String?> _uploadImageToCloudinary(XFile image) async {
    print('Starting Cloudinary upload for image: ${image.path}');
    final apiKey = dotenv.env['CLOUDINARY_API_KEY']!;
    final apiSecret = dotenv.env['CLOUDINARY_API_SECRET']!;
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME']!;

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

  Future<bool> _deleteImageFromCloudinary(String imageUrl) async {
    print('Deleting image from Cloudinary: $imageUrl');
    final apiKey = dotenv.env['CLOUDINARY_API_KEY']!;
    final apiSecret = dotenv.env['CLOUDINARY_API_SECRET']!;
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME']!;

    // Extract public_id from imageUrl (e.g., https://res.cloudinary.com/<cloud_name>/image/upload/v1234567890/<public_id>.jpg)
    final uriSegments = Uri.parse(imageUrl).pathSegments;
    final publicId =
        uriSegments.isNotEmpty ? uriSegments.last.split('.').first : null;
    if (publicId == null) {
      print('Invalid image URL, cannot extract public_id');
      return false;
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final signature = sha1
        .convert(
            utf8.encode('public_id=$publicId&timestamp=$timestamp$apiSecret'))
        .toString();

    final uri =
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/destroy');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'public_id': publicId,
        'api_key': apiKey,
        'timestamp': timestamp,
        'signature': signature,
      }),
    );

    print('Cloudinary delete response status: ${response.statusCode}');
    if (response.statusCode == 200) {
      print('Image deleted successfully from Cloudinary');
      return true;
    } else {
      print('Failed to delete image from Cloudinary: ${response.body}');
      return false;
    }
  }

  Future<XFile?> _pickImage() async {
    print('1. Entering _pickImage function');
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
          errorSnackbarwidget.show(context, 'No image was selected');
          return null;
        }
      } catch (e) {
        print('8. Error in image picker: $e');
        errorSnackbarwidget.show(context, 'Failed to pick image: $e');
        return null;
      }
    } else if (status.isDenied) {
      print('5. Permission denied');
      errorSnackbarwidget.show(context,
          'Photo library access is required. Please enable it in settings.');
      return null;
    } else if (status.isPermanentlyDenied) {
      print('5. Permission permanently denied');
      errorSnackbarwidget.show(context,
          'Photo library access is permanently denied. Please enable it in settings.');
      return null;
    } else if (status.isRestricted || status.isLimited) {
      print('5. Permission restricted or limited');
      errorSnackbarwidget.show(context,
          'Photo library access is restricted or limited by device settings.');
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
      errorSnackbarwidget.show(context, 'Please sign in to add items');
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
      errorSnackbarwidget.show(context, 'Error adding item: $e');
    }
  }

  Future<void> _updateItem(RentalItem item, String name, int quantity,
      String price, String category, String? imageUrl) async {
    print('Updating item: ${item.name} to new name: $name');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user logged in');
      errorSnackbarwidget.show(context, 'Please sign in to update items');
      return;
    }

    final updatedItem = RentalItem(
      id: item.id,
      name: name,
      quantity: quantity,
      availableQuantity: quantity >= item.quantity - item.availableQuantity
          ? quantity - (item.quantity - item.availableQuantity)
          : item.availableQuantity, // Preserve rented quantity
      price: price,
      imageUrl: imageUrl ?? item.imageUrl,
      available: quantity > 0,
      category: category,
      userId: user.uid,
    );

    try {
      await FirebaseFirestore.instance
          .collection('rental_items')
          .doc(item.id)
          .update(updatedItem.toMap());
      print('Item updated in Firestore: ${updatedItem.name}');
    } catch (e) {
      print('Error updating item in Firestore: $e');
      errorSnackbarwidget.show(context, 'Error updating item: $e');
    }
  }

  Future<void> _deleteItem(RentalItem item) async {
    print('Deleting item: ${item.name}');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user logged in');
      errorSnackbarwidget.show(context, 'Please sign in to delete items');
      return;
    }

    try {
      // Delete image from Cloudinary if it's not the default placeholder
      if (item.imageUrl != 'https://via.placeholder.com/150') {
        final success = await _deleteImageFromCloudinary(item.imageUrl);
        if (!success) {
          print(
              'Failed to delete image from Cloudinary, proceeding with Firestore deletion');
        }
      }

      // Delete item from Firestore
      await FirebaseFirestore.instance
          .collection('rental_items')
          .doc(item.id)
          .delete();
      print('Item deleted from Firestore: ${item.name}');
    } catch (e) {
      print('Error deleting item: $e');
      errorSnackbarwidget.show(context, 'Error deleting item: $e');
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
        backgroundColor: Colors.blue.shade900,
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

          _allItems = snapshot.data!.docs
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
          _filteredItems = _allItems
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
                        value: _allItems.length.toString(),
                        icon: Icons.inventory,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatsCard(
                        title: 'Available',
                        value: _allItems
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
                        value: _allItems
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
            print('Building add item dialog UI');
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
                                Snackbarwidget.show(
                                    context, 'Image selected successfully');
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
                      errorSnackbarwidget.show(
                          context, 'Please fill all fields');
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
                          errorSnackbarwidget.show(
                              context, 'Failed to upload image');
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
                      Snackbarwidget.show(
                          context, '${nameController.text.trim()} added!');
                    } catch (e) {
                      print('Error in add item process: $e');
                      errorSnackbarwidget.show(
                          context, 'Error adding item: $e');
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

  void _showEditItemDialog(BuildContext context, RentalItem item) {
    final nameController = TextEditingController(text: item.name);
    final quantityController =
        TextEditingController(text: item.quantity.toString());
    final priceController = TextEditingController(text: item.price);
    final categoryController = TextEditingController(text: item.category);
    bool isPickingImage = false;

    print('Opening edit item dialog for: ${item.name}');
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            print('Building edit item dialog UI');
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0)),
              title: const Text('Edit Item'),
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
                              print('A. Pick Image button pressed for edit');
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
                                Snackbarwidget.show(
                                    context, 'Image selected successfully');
                              }
                            },
                      child: Text(isPickingImage
                          ? 'Picking...'
                          : _selectedImage == null
                              ? 'Change Image'
                              : 'New Image Selected'),
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
                    if (_selectedImage == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Image.network(
                          item.imageUrl,
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            print('Error displaying current image: $error');
                            return const Text('Error loading current image');
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
                  child:
                      Text('Update', style: TextStyle(color: Colors.blue[900])),
                  onPressed: () async {
                    print('Update button pressed');
                    if (nameController.text.trim().isEmpty ||
                        quantityController.text.trim().isEmpty ||
                        priceController.text.trim().isEmpty ||
                        categoryController.text.trim().isEmpty) {
                      print('Validation failed: empty fields');
                      errorSnackbarwidget.show(
                          context, 'Please fill all fields');
                      return;
                    }

                    try {
                      final quantity =
                          int.parse(quantityController.text.trim());
                      print('Parsed quantity: $quantity');
                      String? imageUrl;
                      if (_selectedImage != null) {
                        print('Uploading new image to Cloudinary');
                        imageUrl =
                            await _uploadImageToCloudinary(_selectedImage!);
                        if (imageUrl == null) {
                          print('Image upload failed');
                          errorSnackbarwidget.show(
                              context, 'Failed to upload image');
                          return;
                        }
                        print('New image uploaded, URL: $imageUrl');
                        // Delete old image if it's not the default
                        if (item.imageUrl !=
                            'https://via.placeholder.com/150') {
                          await _deleteImageFromCloudinary(item.imageUrl);
                        }
                      }
                      print('Calling _updateItem');
                      await _updateItem(
                        item,
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
                      Snackbarwidget.show(
                          context, '${nameController.text.trim()} updated!');
                    } catch (e) {
                      print('Error in update item process: $e');
                      errorSnackbarwidget.show(
                          context, 'Error updating item: $e');
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
              child: const Text('Edit', style: TextStyle(color: Colors.blue)),
              onPressed: () {
                print('Edit button pressed for: ${item.name}');
                Navigator.of(context).pop();
                _showEditItemDialog(context, item);
              },
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                print('Delete button pressed for: ${item.name}');
                Navigator.of(context).pop();
                await _deleteItem(item);
                Snackbarwidget.show(context, '${item.name} deleted!');
              },
            ),
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
