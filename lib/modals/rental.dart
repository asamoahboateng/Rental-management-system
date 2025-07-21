enum RentalStatus { active, upcoming, completed, overdue }

class Rental {
  final String id;
  final String clientId;
  final String itemId;
  final int quantity;
  final DateTime startDate;
  final DateTime endDate;
  final String totalAmount;
  final RentalStatus status;
  final String userId;

  Rental({
    required this.id,
    required this.clientId,
    required this.itemId,
    required this.quantity,
    required this.startDate,
    required this.endDate,
    required this.totalAmount,
    required this.status,
    required this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientId': clientId,
      'itemId': itemId,
      'quantity': quantity,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'totalAmount': totalAmount,
      'status': status.toString().split('.').last,
      'userId': userId,
    };
  }

  factory Rental.fromMap(Map<String, dynamic> map) {
    return Rental(
      id: map['id'] as String,
      clientId: map['clientId'] as String,
      itemId: map['itemId'] as String,
      quantity: map['quantity'] as int,
      startDate: DateTime.parse(map['startDate'] as String),
      endDate: DateTime.parse(map['endDate'] as String),
      totalAmount: map['totalAmount'] as String,
      status: RentalStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => RentalStatus.active,
      ),
      userId: map['userId'] as String,
    );
  }
}
