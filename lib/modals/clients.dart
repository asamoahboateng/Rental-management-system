class Client {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final int totalRentals;
  final int activeRentals;
  final DateTime joinDate;

  Client({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.totalRentals,
    required this.activeRentals,
    required this.joinDate,
  });
}
