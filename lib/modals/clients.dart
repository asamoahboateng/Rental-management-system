class Client {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final int totalRentals;
  final int activeRentals;
  final DateTime joinDate;
  final String userId; // Added to associate with user

  Client({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.totalRentals,
    required this.activeRentals,
    required this.joinDate,
    required this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'totalRentals': totalRentals,
      'activeRentals': activeRentals,
      'joinDate': joinDate.toIso8601String(),
      'userId': userId,
    };
  }

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String,
      address: map['address'] as String,
      totalRentals: map['totalRentals'] as int,
      activeRentals: map['activeRentals'] as int,
      joinDate: DateTime.parse(map['joinDate'] as String),
      userId: map['userId'] as String,
    );
  }
}
