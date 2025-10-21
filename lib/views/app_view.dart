import 'package:flutter/material.dart';
import 'package:tile_patcher/views/views.dart';

class TilePatcherApp extends StatelessWidget {
  const TilePatcherApp({
    required this.theme,
    super.key,
  });

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: theme,
      home: const TilesetPatcherHome(),
    );
  }
}
