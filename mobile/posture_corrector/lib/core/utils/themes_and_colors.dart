import 'package:flutter/material.dart';

const lightColorScheme = ColorScheme.light(

  primary: Color(0xFF00C4B4),
  onPrimary: Color(0xFFFFFFFF),

  primaryContainer: Color(0xFFD1F4F1),
  onPrimaryContainer: Color(
    0xFF003B36,
  ),

  secondary: Color(0xFFFF8A65),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color.fromARGB(255, 215, 215, 215),
  onSecondaryContainer: Color.fromARGB(255, 255, 255, 255),

  error: Color(0xFFBA1A1A),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFFDAD6),
  onErrorContainer: Color(0xFF410002),

  surface: Color(0xFFFFFFFF),
  onSurface: Color(0xFF2D3142),
  surfaceContainerHighest: Color(0xFFE7ECEF),
);

const darkColorScheme = ColorScheme.dark(

  primary: Color(0xFF20E3B2),
  onPrimary: Color(0xFF00382A),
  primaryContainer: Color(0xFF1D3E41),
  onPrimaryContainer: Color(0xFF7EFCDB),

  secondary: Color(0xFF20E3B2),
  onSecondary: Color(0xFF00382A),
  secondaryContainer: Color(0xFF2D3243),
  onSecondaryContainer: Color(0xFFE2E8F0),

  error: Color(0xFFFFB74D),
  onError: Color(0xFF4B2800),
  errorContainer: Color(0xFF6B3B00),
  onErrorContainer: Color(0xFFFFDDB3),

  surface: Color(0xFF1C212E),
  onSurface: Color(0xFFE2E8F0),
  surfaceContainerHighest: Color(0xFF282D3D),
);

final lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: lightColorScheme,
  scaffoldBackgroundColor: const Color(0xFFF8F9FA),
);

final darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: darkColorScheme,
  scaffoldBackgroundColor: const Color(0xFF121620),
);
