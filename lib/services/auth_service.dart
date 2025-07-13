class AuthService {
  // Hardcoded users for demo purposes
  static final List<Map<String, String>> _users = [
    {
      'name': 'Admin User',
      'email': 'admin@rental.com',
      'phone': '+233 24 000 0000',
      'password': 'admin123',
    },
    {
      'name': 'John Manager',
      'email': 'john@rental.com',
      'phone': '+233 24 111 1111',
      'password': 'john123',
    },
  ];

  static Map<String, String>? _currentUser;

  // Login method
  Future<bool> login(String email, String password) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    try {
      final user = _users.firstWhere(
        (user) => user['email'] == email && user['password'] == password,
      );
      _currentUser = user;
      return true;
    } catch (e) {
      return false;
    }
  }

  // Signup method
  Future<bool> signup(
      String name, String email, String phone, String password) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Check if email already exists
    final existingUser = _users.where((user) => user['email'] == email);
    if (existingUser.isNotEmpty) {
      return false;
    }

    // Add new user
    final newUser = {
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
    };

    _users.add(newUser);
    _currentUser = newUser;
    return true;
  }

  // Logout method
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = null;
  }

  // Get current user
  Map<String, String>? getCurrentUser() {
    return _currentUser;
  }

  // Check if user is logged in
  bool isLoggedIn() {
    return _currentUser != null;
  }

  // Get user name
  String getUserName() {
    return _currentUser?['name'] ?? 'User';
  }

  // Get user email
  String getUserEmail() {
    return _currentUser?['email'] ?? '';
  }

  // Get user phone
  String getUserPhone() {
    return _currentUser?['phone'] ?? '';
  }

  // Change password
  Future<bool> changePassword(
      String currentPassword, String newPassword) async {
    await Future.delayed(const Duration(seconds: 1));

    if (_currentUser == null) {
      return false;
    }

    if (_currentUser!['password'] != currentPassword) {
      return false;
    }

    // Update password in the users list
    final userIndex =
        _users.indexWhere((user) => user['email'] == _currentUser!['email']);
    if (userIndex != -1) {
      _users[userIndex]['password'] = newPassword;
      _currentUser!['password'] = newPassword;
      return true;
    }

    return false;
  }

  // Update profile
  Future<bool> updateProfile(String name, String phone) async {
    await Future.delayed(const Duration(seconds: 1));

    if (_currentUser == null) {
      return false;
    }

    // Update user info in the users list
    final userIndex =
        _users.indexWhere((user) => user['email'] == _currentUser!['email']);
    if (userIndex != -1) {
      _users[userIndex]['name'] = name;
      _users[userIndex]['phone'] = phone;
      _currentUser!['name'] = name;
      _currentUser!['phone'] = phone;
      return true;
    }

    return false;
  }

  // Reset password (demo implementation)
  Future<bool> resetPassword(String email) async {
    await Future.delayed(const Duration(seconds: 1));

    final userExists = _users.any((user) => user['email'] == email);
    return userExists;
  }
}
