import 'package:flutter/material.dart';

const Color _seed = Color(0xFF10B981);

ThemeData buildTheme(Brightness brightness) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: brightness),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(centerTitle: true),
  );
}
