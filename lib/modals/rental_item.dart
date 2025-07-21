class RentalItem {
  final String id;
  final String name;
  final int quantity;
  final int availableQuantity;
  final String price;
  final String imageUrl;
  final bool available;
  final String category;
  final String userId; // Ensure userId is included

  RentalItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.availableQuantity,
    required this.price,
    required this.imageUrl,
    required this.available,
    required this.category,
    required this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'availableQuantity': availableQuantity,
      'price': price,
      'imageUrl': imageUrl,
      'available': available,
      'category': category,
      'userId': userId, // Include userId in serialization
    };
  }

  factory RentalItem.fromMap(Map<String, dynamic> map) {
    return RentalItem(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      quantity: map['quantity'] as int? ?? 0,
      availableQuantity: map['availableQuantity'] as int? ?? 0,
      price: map['price'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? 'https://via.placeholder.com/150',
      available: map['available'] as bool? ?? false,
      category: map['category'] as String? ?? '',
      userId:
          map['userId'] as String? ?? '', // Handle missing userId gracefully
    );
  }
}
