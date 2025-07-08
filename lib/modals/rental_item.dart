class RentalItem {
  final String id;
  final String name;
  final int quantity;
  final int availableQuantity;
  final String price;
  final String imageUrl;
  final bool available;
  final String category;

  RentalItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.availableQuantity,
    required this.price,
    required this.imageUrl,
    required this.available,
    required this.category,
  });
}
