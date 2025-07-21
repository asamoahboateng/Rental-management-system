import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:rental_system/modals/profile.dart';
import 'package:rental_system/screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  void _showAnimatedSnackBar(String message, {bool isError = false}) {
    print('Showing animated snackbar: $message');
    final controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    final animation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
    ));

    final snackBarKey = GlobalKey();
    final snackBarWidget = SlideTransition(
      position: animation,
      child: Container(
        key: snackBarKey,
        child: SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
          elevation: 6.0,
        ),
      ),
    );

    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: snackBarWidget,
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
      ),
    );

    controller.forward().then((_) {
      print('Snackbar animation completed');
      Future.delayed(const Duration(seconds: 2), () {
        controller.reverse().then((_) {
          print('Snackbar dismissed');
          controller.dispose();
        });
      });
    });
  }

  Future<void> _updateProfile(String name, String? profileImageUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showAnimatedSnackBar('Please sign in to update profile', isError: true);
      return;
    }

    try {
      final userProfile = UserProfile(
        uid: user.uid,
        name: name,
        email: user.email ?? '',
        profileImageUrl: profileImageUrl,
      );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userProfile.toMap());
      _showAnimatedSnackBar('Profile updated successfully');
      print('Profile updated for user ${user.uid}: ${userProfile.toMap()}');
    } catch (e) {
      _showAnimatedSnackBar('Error updating profile: $e', isError: true);
      print('Error updating profile for user ${user.uid}: $e');
    }
  }

  Future<void> _changePassword(
      String currentPassword, String newPassword) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showAnimatedSnackBar('Please sign in to change password', isError: true);
      return;
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      _showAnimatedSnackBar('Password changed successfully');
      print('Password changed for user ${user.uid}');
    } catch (e) {
      _showAnimatedSnackBar('Error changing password: $e', isError: true);
      print('Error changing password for user ${user.uid}: $e');
    }
  }

  Future<Map<String, dynamic>> _fetchBusinessStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);

      final rentalsSnapshot = await FirebaseFirestore.instance
          .collection('rentals')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'completed')
          .where('endDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('endDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      double totalRevenue = 0;
      for (var doc in rentalsSnapshot.docs) {
        final rental = doc.data();
        totalRevenue +=
            double.tryParse(rental['totalAmount']?.toString() ?? '0.0') ?? 0.0;
      }

      final activeRentalsSnapshot = await FirebaseFirestore.instance
          .collection('rentals')
          .where('userId', isEqualTo: user.uid)
          .where('status', whereIn: ['active', 'upcoming']).get();
      final activeRentalsCount = activeRentalsSnapshot.docs.length;

      final clientsSnapshot = await FirebaseFirestore.instance
          .collection('clients')
          .where('userId', isEqualTo: user.uid)
          .get();
      final totalClients = clientsSnapshot.docs.length;

      final itemsSnapshot = await FirebaseFirestore.instance
          .collection('rental_items')
          .where('userId', isEqualTo: user.uid)
          .get();
      final inventoryItems = itemsSnapshot.docs.length;

      print(
          'Fetched business stats: revenue=$totalRevenue, activeRentals=$activeRentalsCount, clients=$totalClients, items=$inventoryItems');

      return {
        'totalRevenue': totalRevenue,
        'activeRentals': activeRentalsCount,
        'totalClients': totalClients,
        'inventoryItems': inventoryItems,
      };
    } catch (e) {
      print('Error fetching business stats: $e');
      return {
        'totalRevenue': 0.0,
        'activeRentals': 0,
        'totalClients': 0,
        'inventoryItems': 0,
      };
    }
  }

  void _showEditProfileDialog(UserProfile? userProfile) {
    final nameController = TextEditingController(text: userProfile?.name ?? '');
    final imageUrlController =
        TextEditingController(text: userProfile?.profileImageUrl ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: const Text('Edit Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: imageUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Profile Image URL (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  _showAnimatedSnackBar('Name cannot be empty', isError: true);
                  return;
                }
                await _updateProfile(
                  nameController.text.trim(),
                  imageUrlController.text.trim().isEmpty
                      ? null
                      : imageUrlController.text.trim(),
                );
                Navigator.of(context).pop();
              },
              child: Text('Save', style: TextStyle(color: Colors.blue[900])),
            ),
          ],
        );
      },
    );
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
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text('Please sign in to view profile'),
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldMessengerKey,
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blue.shade900,
        title: const Text(
          'Profile & Settings',
          style: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          /*   IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () async {
              final userProfileDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get();
              final userProfile = userProfileDoc.exists
                  ? UserProfile.fromMap(userProfileDoc.data()!)
                  : UserProfile(
                      uid: user.uid,
                      name: user.displayName ?? 'User',
                      email: user.email ?? '',
                    );
              _showEditProfileDialog(userProfile);
            },
          ), */
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (userSnapshot.hasError) {
            print('Error in userSnapshot: ${userSnapshot.error}');
            return const Center(child: Text('Error loading profile'));
          }

          UserProfile userProfile;
          if (userSnapshot.hasData && userSnapshot.data!.exists) {
            try {
              userProfile = UserProfile.fromMap(
                  userSnapshot.data!.data()! as Map<String, dynamic>);
              print('User profile loaded: ${userProfile.toMap()}');
            } catch (e) {
              print(
                  'Error parsing user profile: $e, data: ${userSnapshot.data!.data()}');
              userProfile = UserProfile(
                uid: user.uid,
                name: user.displayName ?? 'User',
                email: user.email ?? 'No email',
              );
            }
          } else {
            print('No user profile document found, using default values');
            userProfile = UserProfile(
              uid: user.uid,
              name: user.displayName ?? 'User',
              email: user.email ?? 'No email',
            );
            // Optionally, create the user profile document
            FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set(userProfile.toMap())
                .then((_) =>
                    print('Created default user profile for ${user.uid}'))
                .catchError(
                    (e) => print('Error creating default user profile: $e'));
          }

          return FutureBuilder<Map<String, dynamic>>(
            future: _fetchBusinessStats(),
            builder: (context, statsSnapshot) {
              if (statsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (statsSnapshot.hasError) {
                print('Error in statsSnapshot: ${statsSnapshot.error}');
                return const Center(child: Text('Error loading stats'));
              }

              final stats = statsSnapshot.data ??
                  {
                    'totalRevenue': 0.0,
                    'activeRentals': 0,
                    'totalClients': 0,
                    'inventoryItems': 0,
                  };

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Profile Card
                    Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.blue[900],
                              backgroundImage: userProfile.profileImageUrl !=
                                          null &&
                                      userProfile.profileImageUrl!.isNotEmpty
                                  ? NetworkImage(userProfile.profileImageUrl!)
                                  : null,
                              child: userProfile.profileImageUrl == null ||
                                      userProfile.profileImageUrl!.isEmpty
                                  ? Text(
                                      userProfile.name.isNotEmpty
                                          ? userProfile.name
                                              .split(' ')
                                              .map((n) =>
                                                  n.isNotEmpty ? n[0] : '')
                                              .take(2)
                                              .join()
                                          : 'U',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              userProfile.name.isNotEmpty
                                  ? userProfile.name
                                  : 'User',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              userProfile.email.isNotEmpty
                                  ? userProfile.email
                                  : 'No email',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Business Stats
                    Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15.0)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Business Overview for this Month',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _StatItem(
                                    title: 'Total Revenue for this month',
                                    value:
                                        'GHC ${stats['totalRevenue'].toStringAsFixed(2)}',
                                    icon: Icons.attach_money,
                                    color: Colors.green,
                                  ),
                                ),
                                Expanded(
                                  child: _StatItem(
                                    title: 'Active Rentals',
                                    value: stats['activeRentals'].toString(),
                                    icon: Icons.assignment,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _StatItem(
                                    title: 'Total Clients',
                                    value: stats['totalClients'].toString(),
                                    icon: Icons.people,
                                    color: Colors.orange,
                                  ),
                                ),
                                Expanded(
                                  child: _StatItem(
                                    title: 'Inventory Items',
                                    value: stats['inventoryItems'].toString(),
                                    icon: Icons.inventory,
                                    color: Colors.purple,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Settings Options
                    Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15.0)),
                      child: Column(
                        children: [
                          _SettingsItem(
                            icon: Icons.lock,
                            title: 'Change Password',
                            subtitle: 'Update your account password',
                            onTap: () {
                              _showChangePasswordDialog();
                            },
                          ),
                          const Divider(height: 1),
                          _SettingsItem(
                            icon: Icons.info,
                            title: 'About',
                            subtitle: 'App version and information',
                            onTap: () {
                              _showAboutDialog(context);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Logout Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          _showLogoutDialog(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Change', style: TextStyle(color: Colors.blue[900])),
              onPressed: () async {
                if (newPasswordController.text !=
                    confirmPasswordController.text) {
                  _showAnimatedSnackBar('Passwords do not match',
                      isError: true);
                  return;
                }
                if (newPasswordController.text.length < 6) {
                  _showAnimatedSnackBar(
                      'New password must be at least 6 characters',
                      isError: true);
                  return;
                }
                await _changePassword(
                  currentPasswordController.text,
                  newPasswordController.text,
                );
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: const Text('About Rental Manager'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Version: 1.0.0'),
              SizedBox(height: 8),
              Text(
                  'A comprehensive rental management system for managing inventory, clients, and rentals.'),
              SizedBox(height: 8),
              Text('© 2025 Rental Manager. All rights reserved.'),
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

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                try {
                  await FirebaseAuth.instance.signOut();
                  print('User logged out');
                  Navigator.of(context).pop();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                } catch (e) {
                  _showAnimatedSnackBar('Error logging out: $e', isError: true);
                  print('Error logging out: $e');
                }
              },
            ),
          ],
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
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
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue[900]),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}
