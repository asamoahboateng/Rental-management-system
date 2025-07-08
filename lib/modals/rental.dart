enum RentalStatus {
  active,
  upcoming,
  completed,
  overdue,
}

class Rental {
  final String id;
  final String clientName;
  final String clientPhone;
  final String itemName;
  final int quantity;
  final DateTime startDate;
  final DateTime endDate;
  final String totalAmount;
  final RentalStatus status;

  Rental({
    required this.id,
    required this.clientName,
    required this.clientPhone,
    required this.itemName,
    required this.quantity,
    required this.startDate,
    required this.endDate,
    required this.totalAmount,
    required this.status,
  });
}
