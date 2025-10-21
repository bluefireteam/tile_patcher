import 'package:flutter/material.dart';
import 'package:nes_ui/nes_ui.dart';
import 'package:tile_patcher/views/views.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final theme = flutterNesTheme();
  runApp(
    TilePatcherApp(
      theme: theme,
    ),
  );
}
