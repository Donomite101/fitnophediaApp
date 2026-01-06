import 'package:flutter/material.dart';

class AppTheme {
  // 🎨 Brand Colors
  static const Color primaryGreen = Color(0xFF00C853);
  static const Color accentGreen = Color(0xFF1B5E20);

  // 🟢 Custom Fitness Colors
  static const Color fitnessOrange = Color(0xFFFF9800);
  static const Color fitnessgreen = Color(0xFF00E676);
  static const Color alertRed = Color(0xFFE53935);

  // 🌞 Light Theme
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryGreen,
    scaffoldBackgroundColor: const Color(0xFFFFFFFF), // <-- exact white background
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black),
      titleTextStyle: TextStyle(
        color: Colors.black,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    cardColor: Colors.white,
    shadowColor: Colors.grey,
    colorScheme: const ColorScheme.light(
      primary: primaryGreen,
      secondary: accentGreen,
      surface: Colors.white,
      error: alertRed,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      labelStyle: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      contentTextStyle: TextStyle(fontWeight: FontWeight.w600),
    ),
  );


  // 🌚 Dark Theme
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryGreen,
    scaffoldBackgroundColor: Color(0xFF121212),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF121212),
      foregroundColor: Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    cardColor: Color(0xFF1E1E1E),
    shadowColor: Colors.black,
    colorScheme: const ColorScheme.dark(
      primary: primaryGreen,
      secondary: accentGreen,
      surface: Color(0xFF1E1E1E),
      error: alertRed,
    ),
  );
}
