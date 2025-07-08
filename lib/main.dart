import 'package:flutter/material.dart';
import 'screens/main_screen.dart';

void main() {
  runApp(const RentalApp());
}

class RentalApp extends StatelessWidget {
  const RentalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rental Management System',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue.shade900,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.blue.shade900,
          foregroundColor: Colors.white,
        ),
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
