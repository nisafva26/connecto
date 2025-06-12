import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: Color(0xFF03FFE2),
      fontFamily: 'SFPRO',
      useMaterial3: true,
      
      scaffoldBackgroundColor: Color(0xFF001311),
      colorScheme: ColorScheme.dark(
        primary: Color(0xFF03FFE2),
        secondary: Color(0xFF00F0C2),
        tertiary: Color(0xff091F1E)
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF03FFE2),
          foregroundColor: Colors.black,
          textStyle: TextStyle(fontSize: 16,fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white70),
      ),
    );
  }
}